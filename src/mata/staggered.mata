cap mata mata drop StaggeredNew()
cap mata mata drop Staggered()
// map ,,p mm<A-a>:s/this\.//g<CR>`m
// map ,,p mm<A-a>:s/this\./`Staggered'./g<CR>`m

mata:
class Staggered
{
    // data
    real colvector i
    real colvector t
    real colvector g
    real colvector y
    real colvector index
    real colvector sel
    real matrix    info
    real matrix    cohort_info

    // info
    string scalar  varlist
    string scalar  touse
    real scalar    N
    real scalar    Ni
    real scalar    Nt
    real scalar    Ng
    real scalar    nestimands
    real scalar    multiest
    real scalar    multievent
    real scalar    anyfisher
    real colvector times
    real colvector cohorts
    real matrix    cohort_size

    // options
    real vector    eventTime
    real scalar    num_fisher
    string vector  estimand
    real vector    user_beta
    real scalar    skip_data_check
    real scalar    use_last_treated_only
    real scalar    drop_treated_beforet
    real scalar    return_full_vcv

    // results
    real matrix    A_theta
    real matrix    A_0
    real matrix    betastar
    real colvector thetastar
    real colvector thetahat0
    real matrix    V_X
    real matrix    V_thetaX
    real matrix    V_theta
    real colvector Xhat
    real colvector Xhat_t
    real colvector adjustmentFactor
    real colvector var_neyman
    real colvector se_neyman
    real colvector var_adjusted
    real colvector se_adjusted
    real matrix    full_neyman
    real matrix    full_adjusted

    real colvector fisher_adjusted
    real colvector fisher_neyman
    real scalar    fisher_supt_pval
    real matrix    Wald_test

    // functions
    void new()
    void init()
    void clear()
    void check_caller()
    void update_selection()
    void estimate()
    void post()
    void results()
    void permute_cohort()

    void setup_encode_i()
    void setup_balance_df()
    void setup_flag_singletons()
    void setup_eventstudy()

    void compute_Ag_simple()
    void compute_Ag_cohort()
    void compute_Ag_calendar()
    void compute_Ag_eventstudy()
    void compute_estimand()
    void compute_fisher()
}

class Staggered scalar function StaggeredNew(string scalar _varlist, string scalar _touse)
{
    class Staggered scalar StaggeredObj
    StaggeredObj.init(_varlist, _touse)
    return(StaggeredObj)
}

void function Staggered::new()
{
    this.clear()
    this.eventTime             = strtoreal(tokens(st_local("StagOpt_eventTime")))
    this.num_fisher            = strtoreal(st_local("StagOpt_num_fisher"))
    this.estimand              = tokens(st_local("StagOpt_estimand"))
    this.user_beta             = strtoreal(tokens(st_local("StagOpt_beta")))
    this.skip_data_check       = (st_local("StagOpt_skip_data_check")       != "")
    this.use_last_treated_only = (st_local("StagOpt_use_last_treated_only") != "")
    this.drop_treated_beforet  = (st_local("StagOpt_drop_treated_beforet")  != "")
    this.return_full_vcv       = (st_local("StagOpt_return_full_vcv")       != "")
}

void function Staggered::clear()
{
    this.i     = .
    this.t     = .
    this.g     = .
    this.y     = .
    this.index = .
    this.sel   = .
    this.info  = .
    this.cohort_info = .
    // this.cohort_size = .
}

void function Staggered::init(string vector _varlist, string scalar _touse)
{
    string rowvector vars
    this.check_caller()

    vars         = tokens(_varlist)
    this.varlist = _varlist
    this.touse   = _touse

    this.setup_encode_i(vars[1], vars[4])   // reads i, y
    this.setup_balance_df(vars[2], vars[3]) // reads t, g
    this.setup_flag_singletons(vars[3])

    if ( length(this.eventTime) ) {
        this.setup_eventstudy()
    }
    else if ( any(this.estimand :== "eventstudy") ) {
        this.eventTime = 0
    }

    this.multiest      = length(this.estimand)  > 1
    this.multievent    = length(this.eventTime) > 1
    this.nestimands    = length(this.estimand) :+ ((length(this.eventTime)-1) * any(this.estimand :== "eventstudy"))
    this.anyfisher     = this.num_fisher>0
    this.times         = this.t[1::this.Nt]
    this.cohorts       = this.g[this.cohort_info[., 1]]
    this.A_theta       = J(0, this.Nt, .)
    this.A_0           = J(0, this.Nt, .)
    this.full_neyman   = J(this.return_full_vcv * this.nestimands, this.return_full_vcv * this.return_full_vcv * this.nestimands, 0)
    this.full_adjusted = full_neyman

    if ( length(this.user_beta) & (length(this.user_beta) != this.nestimands) ) {
        if ( length(this.user_beta) == 1 ) {
            this.user_beta = J(this.nestimands, 1, this.user_beta)
        }
        else {
            errprintf("beta() must be either be a scalar or the same length as the number of estimands requested\n")
            _error(198)
        }
    }
}

void function Staggered::estimate()
{
    real scalar done, event

    // Initialize all the outcome vectors; they're vectors in case the
    // user requests multiple events with estimand eventtime; otherwise
    // they're a single scalar

    this.V_X                 = J(this.nestimands * (this.anyfisher + 1), this.nestimands, .)
    this.V_theta             = J(this.nestimands * (this.anyfisher + 1), this.nestimands, .)
    this.V_thetaX            = J(this.nestimands * (this.anyfisher + 1), this.nestimands, .)
    this.Xhat                = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.Xhat_t              = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.adjustmentFactor    = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.betastar            = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.se_neyman           = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.se_adjusted         = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.thetahat0           = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.thetastar           = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.var_neyman          = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.var_adjusted        = J(this.nestimands * (this.anyfisher + 1), 1, .)
    this.Wald_test           = J(this.anyfisher + 1, 2, .)
    this.fisher_adjusted     = J(this.nestimands, 1, .)
    this.fisher_neyman       = J(this.nestimands, 1, .)
    this.fisher_supt_pval    = .

    // If estimand is provided, calculate the appropriate A_theta_list
    done = 0
    if ( any(this.estimand :== "simple") ) {
        this.compute_Ag_simple()
        done = 1
    }

    if ( any(this.estimand :== "cohort") ) {
        this.compute_Ag_cohort()
        done = 1
    }

    if ( any(this.estimand :== "calendar") ) {
        this.compute_Ag_calendar()
        done = 1
    }

    if ( any(this.estimand :== "eventstudy") ) {
        for(event = 1; event <= length(this.eventTime); event++) {
            this.compute_Ag_eventstudy(this.eventTime[event])
        }
        done = 1
    }

    if ( done == 0 ) {
        errprintf("no valid estimand provided:\n")
        _error(198)
    }

    this.compute_estimand()
    this.compute_fisher()
    if ( this.anyfisher ) {
        this.V_X              = this.V_X             [1::this.nestimands,.]
        this.V_theta          = this.V_theta         [1::this.nestimands,1]
        this.V_thetaX         = this.V_thetaX        [1::this.nestimands,1]
        this.Xhat             = this.Xhat            [1::this.nestimands,.]
        this.Xhat_t           = this.Xhat_t          [1::this.nestimands,.]
        this.adjustmentFactor = this.adjustmentFactor[1::this.nestimands,.]
        this.betastar         = this.betastar        [1::this.nestimands,.]
        this.se_neyman        = this.se_neyman       [1::this.nestimands,.]
        this.se_adjusted      = this.se_adjusted     [1::this.nestimands,.]
        this.thetahat0        = this.thetahat0       [1::this.nestimands,.]
        this.thetastar        = this.thetastar       [1::this.nestimands,.]
        this.var_neyman       = this.var_neyman      [1::this.nestimands,.]
        this.var_adjusted     = this.var_adjusted    [1::this.nestimands,.]
        this.Wald_test        = this.Wald_test       [1,.]
    }
}

void function Staggered::check_caller()
{
    if ( st_local("StagOpt_Caller") != "staggered" ) {
        errprintf("internal function Staggered() should not be called from outside -staggered-\n")
        _error(198)
    }
}

void function Staggered::setup_encode_i(string scalar ivar, string scalar yvar)
{
    string colvector svar
    real colvector rvar

    if ( strpos(st_vartype(ivar), "str") ) {
        svar       = st_sdata(., ivar, this.touse)
        this.N     = length(svar)
        this.index = order(svar, 1)
        this.info  = panelsetup(svar[this.index], 1)
    }
    else {
        rvar       = st_data(., ivar, this.touse)
        this.N     = length(rvar)
        this.index = order(rvar, 1)
        this.info  = panelsetup(rvar[this.index], 1)
    }
    this.i   = J(this.N, 1, 0)
    this.i[this.info[., 1]] = J(rows(this.info), 1, 1)
    this.Ni  = rows(this.info)
    this.i   = runningsum(this.i)
    this.sel = J(this.N, 1, 1)
    this.y   = st_data(., yvar, this.touse)[this.index]
}

//// This function creates a balanced panel as needed for our analysis
//
// It first checks if rows of the data are uniquely characterized by (i,t)
// If there are multiple observations per (i,t), it throws an error
// It also removes observations with missing y
//
// It then removes observations i for which data is not available for all t
// (i.e. force a balanced panel)
void function Staggered::setup_balance_df(string scalar tvar, string scalar gvar)
{
    real scalar j, minmaxt
    real colvector numPeriods, dropPeriods
    real rowvector sub

    this.t      = st_data(., tvar, this.touse)[this.index]
    this.g      = st_data(., gvar, this.touse)[this.index]
    this.index  = order((this.g, this.i, this.t), (1, 2, 3))
    this.i      = this.i[this.index]
    this.t      = this.t[this.index]
    this.g      = this.g[this.index]
    this.y      = this.y[this.index]
    minmaxt     = minmax(this.t)

    this.info   = panelsetup(this.i, 1)
    numPeriods  = this.info[., 2] :- this.info[., 1] :+ 1
    this.Nt     = minmaxt[2] - minmaxt[1] + 1
    dropPeriods = selectindex(numPeriods :< this.Nt)

    if ( this.Ni != rows(this.info) ) {
        errprintf("One or more individuals belong to multiple cohorts\n")
        _error(198)
    }

    if ( this.Nt < 2 ) {
        errprintf("All individuals appear in only one period; aborting\n")
        _error(2000)
    }

    if ( this.skip_data_check ) return

    // Ensure balanced panel
    if ( length(dropPeriods) ) {
        for(j = 1; j <= length(dropPeriods); j++) {
            sub = this.info[dropPeriods[j], .]'
            this.sel[|sub|] = J(sub[2] - sub[1] + 1, 1, 0)
        }
        this.update_selection(" after balancing panel")
    }

    // This only works because (i, t) is sorted and each i has 2+ periods
    if ( any(this.t[|2 \ this.N|] :== this.t[|1 \ this.N-1|]) | any(numPeriods :> this.Nt) ) {
        errprintf("There are multiple observations with the same (i,t) values\n")
        errprintf("The panel should have a unique outcome for each (i, t) value\n")
        _error(459)
    }

    if ( length(dropPeriods) ) {
        errprintf("\nPanel is unbalanced (or has missing values) for some observations. Will")
        errprintf("\ndrop observations with missing values of Y_{it} for any time periods. If")
        errprintf("\nyou wish to include these observations, provide staggered with a balanced")
        errprintf("\ndata set with imputed outcomes.")
        errprintf("\n\n")
    }
}

void function Staggered::setup_flag_singletons(string scalar gvar)
{
    real scalar j
    real colvector flag_singleton
    real rowvector sub
    string scalar gfmt

    // Compute number of units per cohort
    this.cohort_info = panelsetup(this.g, 1)
    this.cohort_size = (this.cohort_info[., 2] :- this.cohort_info[., 1] :+ 1) :/ this.Nt
    this.Ng          = rows(this.cohort_info)

    // Flag for singleton cohorts
    flag_singleton = selectindex(this.cohort_size :== 1)
    // Drop cohorts which are singleton
    if ( length(flag_singleton) ) {
        if ( length(flag_singleton) > 1 ) {
            errprintf("Treatment cohorts found with a single cross-sectional unit. We drop these cohorts.\n")
            for(j = 1; j <= length(flag_singleton); j++) {
                gfmt = sprintf(st_varformat(gvar), this.g[this.cohort_info[flag_singleton[j], 1]])
                errprintf("\tg = %s\n", gfmt)
            }
        }
        else {
            gfmt = strtrim(sprintf(st_varformat(gvar), this.g[this.cohort_info[flag_singleton[1], 1]]))
            errprintf("Treatment cohort g = %s has a single cross-sectional unit. We drop this cohort.\n", gfmt)
        }

        this.sel = J(this.N, 1, 1)
        for(j = 1; j <= length(flag_singleton); j++) {
            sub = this.cohort_info[flag_singleton[j], .]'
            this.sel[|sub|] = J(sub[2] - sub[1] + 1, 1, 0)
        }
        this.update_selection(" after dropping singleton cohorts")
    }
}

void function Staggered::update_selection(| string scalar msg)
{
    if ( args() < 1 ) msg = ""
    real colvector keep
    if ( this.sel == . ) return
    if ( all(this.sel) ) return

    keep = selectindex(this.sel)
    this.N = length(keep)
    if ( this.N ) {
        if ( this.i     != .  ) this.i     = this.i[keep]
        if ( this.t     != .  ) this.t     = this.t[keep]
        if ( this.y     != .  ) this.y     = this.y[keep]
        if ( this.info  != .  ) this.info  = panelsetup(this.i, 1)
        if ( this.info  != .  ) this.Ni    = rows(this.info)
        if ( (this.touse != "") & (this.index != .) ) {
            st_store(., this.touse, this.touse, this.sel[order(this.index, 1)])
            this.index = this.index[keep]
        }
        if ( this.g     != .  ) {
            this.g           = this.g[keep]
            this.cohort_info = panelsetup(this.g, 1)
            this.Ng          = rows(this.cohort_info)
            this.cohort_size = (this.cohort_info[., 2] :- this.cohort_info[., 1] :+ 1) :/ this.Nt
        }
        this.sel = J(this.N, 1, 1)
    }
    else {
        errprintf("no observations%s; halting execution\n", sprintf(msg))
        _error(2000)
    }
}

void function Staggered::compute_Ag_simple()
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, g_wgt, Ng_control

    real scalar i, g_map, g_max, N_total
    real matrix A_0_w, A_theta, A_0

    // List of all 'candidate' g, t (cohort, period)
    // - t is a candidate if any g will be treated at g, except the last g
    // - g is a candidate if it will be treated at any t, except the last t
    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all)  :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex(g_all :<= max(t_all))
    g_list = g_all[g_sel]
    g_max  = max(g_all)

    // It's easier to expain the A_theta matrix in terms of a loop for g, t pairs
    //
    // - Consider all candidate g, t pairs
    // - Loop each g; loop each t
    // - For a given g, t
    //     - Generate a vector
    //     - 1 in the gth row
    //     - (-N_g' / (sum_g' N_g')) in the rows g': g' > t
    //     - g' are control cohorts, which are not-yet-treated and never-treated cohorts
    //     - scale the vector by N_g
    //
    // Two ways to think about the result:
    // A. sum across g and palce in gth row of G x T matrix
    // B. Place g, t vector in t-th column of G x T matrix of otherwise 0s, then sum across g, t
    //
    // Finally, divide by total treated (i.e. total individuals
    // in candidate periods). The below does the same thing but
    // semi-vectorized for ease of computation.

    N_total = 0
    A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel   = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv   = selectindex(g_all :<= t_list[i])
        g_wgt   = this.cohort_size[g_sel[selectindex(g_list :<= t_list[i])]]
        N_total = N_total + sum(g_wgt)
        A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        A_theta[i_inv, t_sel[i]] = this.cohort_size[i_inv]
    }
    A_theta = A_theta :/ N_total

    // This is very similar to the above, thinking of the result via method
    // B.  Instead of placing the vector in the t-th column, place it in the
    // column t: t = g-1, then sum across g, t (and divide by N_total).  The
    // below does this but, again, semi-vectorized for ease of computation.
    A_0   = J(this.Ng, this.Nt, 0)
    A_0_w = J(this.Nt, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = selectindex(t_all :>= g_list[i])
        if ( length(g_map) & length(i_sel) ) {
            A_0_w[i_sel, g_map] = J(length(i_sel), 1, this.cohort_size[i])
        }
    }

    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    A_0 = - A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        if ( length(g_map) ) {
            A_0[i, g_map] = sum((t_all :>= g_list[i]) :& (t_all :< max(g_all))) * this.cohort_size[i]
        }
    }
    A_0 = A_0 :/ N_total

    this.A_0     = this.A_0     \ A_0
    this.A_theta = this.A_theta \ A_theta
}

void function Staggered::compute_Ag_cohort()
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, g_wgt, g_scale, Ng_control

    real scalar i, g_map, g_max, t_tot, N_total
    real matrix A_0_w, A_theta, A_0

    // This is more or less the same as the simple version, except the
    // weight at each pair is different:
    // - N_g/(sum_g N_g) for a given g
    // - 1/(# t >= g and < max_g) across t for a given g

    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all) :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex((g_all :< max(g_all)) :& (g_all :<= max(t_all)))
    g_list = g_all[g_sel]
    g_max  = max(g_all)

    // A_theta; scaling changes a decent amount but overall similar
    // TODO: xx explain loop and mapping to weighting here
    g_scale = J(this.Ng, 1, 1)
    for(i = 1; i <= length(g_list); i++) {
        g_scale[g_sel[i]] = sum(t_list :>= g_list[i])
    }

    N_total = sum(this.cohort_size[g_sel])
    A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= t_list[i])
        t_tot = sum(g_list :<= t_list[i])
        g_wgt = this.cohort_size[1::t_tot] :/ g_scale[1::t_tot]
        A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        A_theta[i_inv, t_sel[i]] = this.cohort_size[i_inv] :/ g_scale[i_inv]
    }
    A_theta = A_theta :/ N_total

    // A_0; almost identical (just adds g_scale)
    A_0   = J(this.Ng, this.Nt, 0)
    A_0_w = J(this.Nt, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = selectindex(t_all :>= g_list[i])
        if ( length(g_map) & length(i_sel) ) {
            A_0_w[i_sel, g_map] = J(length(i_sel), 1, this.cohort_size[i] / g_scale[i])
        }
    }

    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    A_0 = - A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        if ( length(g_map) ) {
            A_0[i, g_map] = sum((t_all :>= g_list[i]) :& (t_all :< max(g_all))) * this.cohort_size[i] / g_scale[i]
        }
    }
    A_0 = A_0 :/ N_total

    this.A_0     = this.A_0     \ A_0
    this.A_theta = this.A_theta \ A_theta
}

void function Staggered::compute_Ag_calendar()
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, g_wgt, Ng_control

    real rowvector g_map, g_cnt
    real scalar i, g_max
    real matrix A_0_w, A_theta, A_0

    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all) :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex(g_all :<= max(t_list))
    g_list = g_all[g_sel]
    g_max  = max(g_all)

    // A_theta; scaling changes a decent amount but overall similar
    // TODO: xx explain loop and mapping to weighting here
    A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- (0 \ (this.Ng-1? runningsum(this.cohort_size)[1..(this.Ng-1)]: J(0, 1, 0)))
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= t_list[i])
        g_wgt = this.cohort_size[i_inv] :/ sum(this.cohort_size[i_inv])
        A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]]) * g_wgt
        A_theta[i_inv, t_sel[i]] = g_wgt
    }
    A_theta = A_theta :/ length(t_list)

    // A_0; same idea but scaling changes a _lot_, actually
    // 1. For each t: (t >= min g) and (t < max g) (scale by sum_t 1)
    // 2. For each g <= t (scale by N_g / sum_g N_g)
    //     - t' is the position in the time vector equal to g - 1
    //     - for each g' > t, add N_g' / sum N_g' to g', t'
    //     - add 1 to g, t'
    // 3. For each g <= t (scale by N_g / sum_g N_g)
    //
    // Think of the G x T matrix A_0
    // - Since t is fixed within each t and across g, this basically
    //   creates the same vector from min g: g > t through max g: g <= max t
    //   equal to N_g / sum N_g
    // - The point are the weights. Here I first create an intermediate G x T
    //   matrix; the t-th column has this vector in the requisite position.
    // - It should be the case that only the columns where t equals some
    //   g-1 are populated. For each such column t', we need to sum all
    //   the columns of the intermediate matrix if t' is smaller than
    //   some t. For example,
    //     - t = 1 to 5
    //     - g = 2 to 5
    //     - if t = 3; we add the vector in the t-th column of the intermediate
    //       matrix to columns 1, 2 (g-1) of the final output matrix
    //     - if t = 4; we add the vector in the t-th column of the intermediate
    //       matrix to columns 1, 2, 3 (g-1) of the final output matrix
    //     - In general, the t'-th coumn of the output matrix will be the sum
    //       of all t columns of the intermediate matrix if t = g-1 and t > t'
    // - The final sticking point is scaling, since each column of the intermediate
    //   matrix is scaled differently depending on the output. In particular,
    //   even though the base vector from the intermediary matix is the same,
    //   each is by sum_g: g <= t N_g and multiplied by N_g. Hence we have a
    //   weighting matrix where each row is a vector N_g / sum_g N_g. The result
    //   is the intermedie matrix times this vector.
    // - The last piece of the puzzle is the 1 at g, t', but we can just sum
    //   the adequate rows of the weighting  matrix to get it!

    A_0   = J(this.Ng, this.Nt, 0)
    A_0_w = J(this.Nt, this.Nt, 0)
    g_map = J(1,       this.Ng, 0)
    for(i = 1; i <= length(g_list); i++) {
        i_sel = selectindex(t_all :== (g_list[i]-1))
        if ( length(i_sel) ) {
            g_map[i] = i_sel
        }
    }
    for(i = 1; i <= length(t_all); i++) {
        i_sel = selectindex(g_list :<= t_all[i])
        g_cnt = this.cohort_size[g_sel[i_sel]]' / sum(this.cohort_size[g_sel[i_sel]])
        i_sel = selectindex(g_map[i_sel] :!= 0)
        A_0_w[i, g_map[i_sel]] = g_cnt[i_sel]
    }
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]]
    }
    A_0 = - A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        if ( g_map[i] ) {
            A_0[i, g_map[i]] = sum(A_0_w[t_sel[selectindex(t_list :> g_map[i])], g_map[i]])
        }
    }
    A_0 = A_0 :/ length(t_list)

    this.A_0     = this.A_0     \ A_0
    this.A_theta = this.A_theta \ A_theta
}

void function Staggered::compute_Ag_eventstudy(real scalar event)
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, Ng_control

    real scalar i, g_map, g_max, x_map, N_total
    real matrix A_0_w, A_theta, A_0

    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    g_sel  = selectindex(((g_all :+ event) :< max(g_all)) :& ((g_all :+ event) :<= max(t_all)))
    if( length(g_sel) == 0 ){
        errprintf("There are no comparison cohorts for the given eventTime (%g)\n", event)
        _error(198)
    }

    g_list = g_all[g_sel]
    t_list = g_list :+ event
    g_max  = max(g_all)

    t_sel = J(1, length(t_list), 0)
    x_map = J(1, length(t_list), 0)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = selectindex(t_all :== t_list[i])
        if ( length(i_sel) ) {
            t_sel[i] = selectindex(t_all :== t_list[i])
        }
        i_sel = selectindex((g_all :+ event) :== t_list[i])
        if ( length(i_sel) ) {
            x_map[i] = i_sel
        }
    }

    // A_theta
    // TODO: xx explain loop and mapping to weighting here
    N_total    = sum(this.cohort_size[g_sel])
    A_theta    = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- (0 \ (this.Ng-1? runningsum(this.cohort_size)[1..(this.Ng-1)]: J(0, 1, 0)))
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= g_list[i])
        if ( t_sel[i] ) {
            A_theta[i_sel, t_sel[i]] = - this.cohort_size[x_map[i]] :* this.cohort_size[i_sel] :/ Ng_control[i_sel[1]]
            A_theta[i_inv[length(i_inv)], t_sel[i]] = A_theta[i_inv[length(i_inv)], t_sel[i]] + this.cohort_size[x_map[i]]
        }
    }
    A_theta = A_theta :/ N_total

    // A_0
    // 1. The eligible cohorts (g_list) are all s.t.
    //     - g': g' + event < min max g, t
    // 2. For each eligible g', in the G x T matrix A_0
    //     - t' is the position in the time vector equal to g' - 1
    //     - Add 1 to the g', t' column
    //     - for each g'': g'' > g' + event
    //         - Add - N_g'' / sum_g'' N_g'' to g'', t'
    // 3. Scale each row by g' / sum N_g'
    A_0_w = J(this.Nt, this.Nt, 0)
    A_0   = J(this.Ng, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        if ( length(g_map) ) {
            A_0_w[g_map, g_map] = this.cohort_size[x_map[i]]
        }
    }
    for(i = 1; i <= length(t_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        if ( length(g_map) & length(i_sel) ) {
            A_0[i_sel, g_map] = - this.cohort_size[i_sel] :/ Ng_control[i_sel[1]]
        }
        if ( length(g_map) & x_map[i] ) {
            A_0[x_map[i], g_map] = A_0[x_map[i], g_map] + 1
        }
    }
    A_0 = A_0 * A_0_w / N_total

    this.A_0     = this.A_0     \ A_0
    this.A_theta = this.A_theta \ A_theta
}

void function Staggered::compute_estimand(|real scalar offset)
{
    if ( args() < 1 ) offset = 0

    real scalar i, j, t_min, npreperiods
    real colvector g_all, g_zero, g_min, g_minsel, preperiods, preindex
    real rowvector t_all, g_sel, g_zerosel, g_ng
    real colvector betahat, sel1, sel2, selecti
    real colvector Y_sum
    real matrix M, Y_g, S_g, S_g1, S_g2, S_g3, S_preperiod, A0_g, At_g, Ac_g

    // R translation notes
    //     varhat_conservative <-> var_neyman
    //     Xvar                <-> V_X
    //     X_theta_cov         <-> V_thetaX
    //     all this is simplified for scalars but R writes it all for
    //     matrices (though AFAIK it's all scalars)

    // TODO: xx Metrics notes
    //     The way the paper is written, \hat{\theta} is one-dimensional and A_{\theta,g}
    //     is 1 x T (p.15). Hence Cov(\hat{\theta}, \hat{X}) is M x 1 and V_{\hat{\theta}}
    //     is a scalar. When multiple estimands are requested, I can compute V_theta et al
    //     as if it was a full vcov matrix and adjust after.
    //
    //     The confusion, however, is that if X-hat is a vector then V_X is a matrix and
    //     betastar, even if it's a vector, would change depending on which estimates are
    //     requested, causing thetastar _and_ its variance to change as well. No?

    // This computes \beta^star and the variance of (\hat{theta}_0, \hat{X})
    // as presented under Proposition 2.1
    //
    // - S_g is defined the prior page as, basically, the vcov of Y_g
    // - I don't really know how the A_g were defined but I got it from
    //   the code; see the compute_Ag_* functions above
    // - S_\theta is defined but I haven't invested time into parsing it out;
    //   I also got it from the code and I'm 90% sure it's the adjustmentFactor

    selecti = this.Ng :* (0::(this.nestimands-1))
    g_all   = this.g[this.cohort_info[., 1]]
    t_all   = this.t[1::this.Nt]'
    t_min   = min(t_all)
    g_sel   = selectindex(colmax(abs(this.A_theta)) :> 0)
    g_sel   = length(g_sel)? g_sel[1]: 1
    g_min   = J(this.nestimands, 1, g_all[1])
    g_zero  = rowmax(abs(this.A_theta)) :== 0
    if ( any(g_zero) ) {
        for(i = 1; i <= this.nestimands; i++) {
            sel1 = this.Ng * (i - 1) + 1
            sel2 = this.Ng * i
            if ( all(g_zero[|sel1 \ sel2|]) ) {
                errprintf("No eligible cohorts with non-zero weight\n")
                _error(198)
            }
            else if ( any(g_zero[|sel1 \ sel2|]) ) {
                g_min[i] = g_all[min(selectindex(!g_zero[|sel1 \ sel2|]))]
            }
        }
    }
    preperiods  = rowsum(t_all :< J(1, this.Nt, g_min))
    preindex    = selectindex(preperiods)
    npreperiods = length(preindex)
    g_ng = npreperiods? colsum(g_min[preindex]' :<= J(1, npreperiods, g_all)): 0
    M    = J(sum(preperiods), this.Nt * npreperiods, 0)
    sel1 = 1
    sel2 = 0
    for(i = 1; i <= this.nestimands; i++) {
        if ( preperiods[i] ) {
            M[|(sel1, sel2+1)\(sel1+preperiods[i]-1, sel2+preperiods[i])|] = I(preperiods[i])
            sel1 = sel1 + preperiods[i]
            sel2 = sel2 + this.Nt
        }
    }
    sel1 = offset + 1
    sel2 = offset + this.nestimands

    this.V_X      [|(sel1,1)\(sel2,.)|] = J(this.nestimands, this.nestimands, 0)
    this.V_thetaX [|(sel1,1)\(sel2,.)|] = J(this.nestimands, this.nestimands, 0)
    this.V_theta  [|(sel1,1)\(sel2,.)|] = J(this.nestimands, this.nestimands, 0)
    this.thetahat0[|(sel1,1)\(sel2,.)|] = J(this.nestimands, 1, 0)
    this.Xhat     [|(sel1,1)\(sel2,.)|] = J(this.nestimands, 1, 0)
    betahat     = npreperiods? J(sum(preperiods), this.nestimands, 0): J(1, this.nestimands, 0)
    S_preperiod = npreperiods? J(sum(preperiods), sum(preperiods), 0): 0
    for(i = 1; i <= this.Ng; i++) {
        Y_g   = colshape(panelsubmatrix(this.y, i, this.cohort_info), this.Nt)
        S_g   = variance(Y_g)
        Y_sum = colsum(Y_g)'
        A0_g  = this.A_0[selecti :+ i, .]
        At_g  = this.A_theta[selecti :+ i, .]

        this.V_X      [|(sel1,1)\(sel2,.)|] = this.V_X      [|(sel1,1)\(sel2,.)|] + (A0_g * S_g * A0_g') / this.cohort_size[i]
        this.V_thetaX [|(sel1,1)\(sel2,.)|] = this.V_thetaX [|(sel1,1)\(sel2,.)|] + (A0_g * S_g * At_g') / this.cohort_size[i]
        this.V_theta  [|(sel1,1)\(sel2,.)|] = this.V_theta  [|(sel1,1)\(sel2,.)|] + (At_g * S_g * At_g') / this.cohort_size[i]
        this.thetahat0[|(sel1,1)\(sel2,.)|] = this.thetahat0[|(sel1,1)\(sel2,.)|] + At_g * Y_sum / this.cohort_size[i]
        this.Xhat     [|(sel1,1)\(sel2,.)|] = this.Xhat     [|(sel1,1)\(sel2,.)|] + A0_g * Y_sum / this.cohort_size[i]

        if ( npreperiods ) {
            S_g1 = M * (I(npreperiods)#S_g)
            S_g2 = S_g1 * M'
            S_g3 = I(0)
            g_zerosel = (g_min[preindex] :<= g_all[i])'
            betahat[.,preindex] = betahat[.,preindex] :+ ((pinv(S_g2) * S_g1) * (I(npreperiods)#J(this.Nt, 1, 1) :* J(npreperiods, 1, At_g[preindex,.]')) :* g_zerosel)
            for(j = 1; j <= npreperiods; j++) {
                S_g3 = blockdiag(S_g3, I(preperiods[preindex[j]]) * g_zerosel[j] / g_ng[j])
            }
            S_preperiod = S_preperiod + S_g2 * S_g3
        }
    }

    this.V_X      [|(sel1,1)\(sel2,.)|] = makesymmetric(this.V_X [|(sel1,1)\(sel2,.)|])
    this.V_thetaX [|(sel1,1)\(sel2,1)|] = diagonal(this.V_thetaX [|(sel1,1)\(sel2,.)|])
    this.V_theta  [|(sel1,1)\(sel2,1)|] = diagonal(this.V_theta  [|(sel1,1)\(sel2,.)|])

    this.adjustmentFactor[|(sel1,1)\(sel2,.)|] = diagonal(betahat' * S_preperiod * betahat) / sum(this.cohort_size)
    this.betastar        [|(sel1,1)\(sel2,.)|] = all(this.user_beta :!= .)? colshape(this.user_beta, 1): (invsym(diag(this.V_X[|(sel1,1)\(sel2,.)|])) * this.V_thetaX[|(sel1,1)\(sel2,1)|])
    this.thetastar       [|(sel1,1)\(sel2,.)|] = this.thetahat0[|(sel1,1)\(sel2,.)|] - this.betastar[|(sel1,1)\(sel2,.)|] :* this.Xhat[|(sel1,1)\(sel2,.)|]
    this.var_neyman      [|(sel1,1)\(sel2,.)|] = this.V_theta[|(sel1,1)\(sel2,1)|] +
                                                 this.betastar[|(sel1,1)\(sel2,.)|] :* diagonal(this.V_X[|(sel1,1)\(sel2,.)|]) :* this.betastar[|(sel1,1)\(sel2,.)|] -
                                                 2 * this.V_thetaX[|(sel1,1)\(sel2,1)|] :* this.betastar[|(sel1,1)\(sel2,.)|]
    this.se_neyman       [|(sel1,1)\(sel2,.)|] = editmissing(sqrt(this.var_neyman[|(sel1,1)\(sel2,.)|]), 0)
    this.var_adjusted    [|(sel1,1)\(sel2,.)|] = this.var_neyman[|(sel1,1)\(sel2,.)|] - this.adjustmentFactor[|(sel1,1)\(sel2,.)|]
    this.se_adjusted     [|(sel1,1)\(sel2,.)|] = editmissing(sqrt(this.var_adjusted[|(sel1,1)\(sel2,.)|]), 0)
    this.Xhat_t          [|(sel1,1)\(sel2,.)|] = this.Xhat[|(sel1,1)\(sel2,.)|] :/ sqrt(diagonal(this.V_X[|(sel1,1)\(sel2,.)|]))

    this.Wald_test[1+(offset>0), 1] = this.Xhat[|(sel1,1)\(sel2,.)|]' * invsym(this.V_X[|(sel1,1)\(sel2,.)|]) * this.Xhat[|(sel1,1)\(sel2,.)|]
    this.Wald_test[1+(offset>0), 2] = chi2tail(this.nestimands, this.Wald_test[1, 1])

    if ( any((this.se_neyman[|(sel1,1)\(sel2,.)|] \ this.se_adjusted[|(sel1,1)\(sel2,.)|]) :== 0) ) {
        errprintf("Some estimated variances < 0; setting to 0 as applicable.\n")
    }

    // TODO: xx there's a possible issue here if g_min varies by
    // estimand, or without pre-periods
    if ( this.return_full_vcv ) {
        for(i = 1; i <= Ng; i++) {
            Y_g  = colshape(panelsubmatrix(y, i, cohort_info), Nt)
            S_g  = variance(Y_g)
            A0_g = A_0[selecti :+ i, .]
            At_g = A_theta[selecti :+ i, .]
            Ac_g = At_g :- this.betastar[|(sel1,1)\(sel2,.)|] :* A0_g
            this.full_neyman = this.full_neyman + (Ac_g * S_g * Ac_g') / cohort_size[i]
        }
        M           = J(npreperiods, 1, 1)#I(min(preperiods))
        betahat     = M' * betahat
        S_preperiod = S_preperiod[|1, 1 \ min(preperiods), min(preperiods)|]
        this.full_adjusted = this.full_neyman - betahat' * S_preperiod * betahat / sum(cohort_size)
    }
}

// Randomly permute the treatmnet timing (cohort) at the individual level
// at each iteration and record the estimand and se (for t-stat)
//
// Note permuting the cohorts at the individual level means the cohort
// sizes, etc. remain the same. Since the panel is forced to be balanced,
// the only thing that changes is the outcome; in other words, Y_it
// is permuted, but everything else is static.
void function Staggered::compute_fisher()
{
    real scalar sel1, sel2, cached_vcv
    real matrix _thetastar
    real matrix _se_adjusted
    real matrix _se_neyman
    real matrix _t_stat

    if ( !this.anyfisher ) return

    sel1 = this.nestimands+1; sel2 = this.nestimands*2
    _thetastar   = J(num_fisher, this.nestimands, .)
    _se_adjusted = J(num_fisher, this.nestimands, .)
    _se_neyman   = J(num_fisher, this.nestimands, .)
    _t_stat      = J(num_fisher, this.nestimands, .)

    cached_vcv = this.return_full_vcv
    this.return_full_vcv = 0
    for(i = 1; i <= num_fisher; i++) {
        this.permute_cohort(i)
        this.compute_estimand(this.nestimands)
        _thetastar[i,.]   = this.thetastar[|(sel1,1)\(sel2,.)|]'
        _se_adjusted[i,.] = this.se_adjusted[|(sel1,1)\(sel2,.)|]'
        _se_neyman[i,.]   = this.se_neyman[|(sel1,1)\(sel2,.)|]'
        _t_stat[i,.]      = this.Xhat_t[|(sel1,1)\(sel2,.)|]'
    }
    this.return_full_vcv = cached_vcv

    sel1 = 1; sel2 = this.nestimands
    this.fisher_adjusted  = mean(abs(this.thetastar :/ this.se_adjusted)[|(sel1,1)\(sel2,.)|]' :< abs(_thetastar :/ _se_adjusted))'
    this.fisher_neyman    = mean(abs(this.thetastar :/ this.se_neyman)[|(sel1,1)\(sel2,.)|]'   :< abs(_thetastar :/ _se_neyman))'
    this.fisher_supt_pval = mean(max(abs(this.Xhat_t[|(sel1,1)\(sel2,.)|])) :< rowmax(abs(_t_stat)))
}

// Shuffle outcome y; note it's the only thing we need to shuffle
// and we don't need to unshuffle it even though it becomes out of
// sync with i because:
// - This is the last thing we run
// - The panel is balanced so re-shuffling without unshuffling
//   should be conceptually equivalent (even if not identical)
void function Staggered::permute_cohort(real scalar seed)
{
    real scalar i, fr, to, rseedcache
    real matrix info
    real colvector shuffle

    rseedcache = rseed()
    rseed(seed)

    info    = jumble(this.info)
    shuffle = J(this.N, 1, .)
    fr      = 1
    to      = 0
    for(i = 1; i <= this.Ni; i++) {
        to = to + this.Nt
        shuffle[|fr\to|] = info[i, 1]::info[i, 2]
        fr = fr + this.Nt
    }

    this.y = this.y[shuffle]
    rseed(rseedcache)
}

// If eventTime is a vector, call staggered for each event-time and combine the results
void function Staggered::setup_eventstudy()
{
    // So the idea here is to just look over all the event times and return
    // all the coefficients and SEs. I do that in the computation step;
    // nothing really to do here, but leave function as is just in case.
    if ( !any(this.estimand :== "eventstudy") ) {
        errprintf("You provided a vector for eventTime but estimand does not include\n")
        errprintf("'eventstudy'. Did you mean to include estimand(eventstudy)?\n")
        _error(198)
    }
}

void function Staggered::post(string scalar b, string scalar V,| string scalar vce)
{
    if ( args() < 3 ) vce = "adjusted"

    real scalar nextra
    string vector rownames, eqnames

    nextra   = (length(this.eventTime)-1) * any(this.estimand :== "eventstudy")
    eqnames  = colshape(this.estimand, 1) \ J(nextra, 1, "eventstudy")
    rownames = J(length(this.estimand)-any(this.estimand :== "eventstudy"), 1, tokens(this.varlist)[3])

    if ( any(this.estimand :== "eventstudy") ) {
        if ( min(this.eventTime) >= 0 ) {
            rownames = rownames \ strofreal(this.eventTime') :+ ("." :+ tokens(this.varlist)[3])
        }
        else {
            rownames = rownames \ ((tokens(this.varlist)[3] :+ " ") \ J(length(this.eventTime)-1, 1, "")) :+ strofreal(this.eventTime')
        }
    }

    st_matrix(b, rowshape(this.thetastar, 1))
    st_matrixcolstripe(b, (eqnames, rownames))
    st_matrixrowstripe(b, ("", tokens(this.varlist)[4]))

    if ( this.return_full_vcv ) {
        st_matrix(V, vce == "neyman"? this.full_neyman: this.full_adjusted)
        st_matrixcolstripe(V, (eqnames, rownames))
        st_matrixrowstripe(V, (eqnames, rownames))
    }
    else {
        if ( this.nestimands > 1 ) {
            printf("(warning: e(V) is a diagonal matrix of SEs, not a full vcov matrix)\n")
        }
        st_matrix(V, vce == "neyman"? diag(this.var_neyman): diag(this.var_adjusted))
        st_matrixcolstripe(V, (eqnames, rownames))
        st_matrixrowstripe(V, (eqnames, rownames))
    }
}

void function Staggered::results()
{
    real matrix results
    real scalar nextra
    string vector colnames, rownames, eqnames
    nextra   = (length(this.eventTime)-1) * any(this.estimand :== "eventstudy")
    eqnames  = colshape(this.estimand, 1) \ J(nextra, 1, "eventstudy")
    rownames = J(length(this.estimand)-any(this.estimand :== "eventstudy"), 1, tokens(this.varlist)[3])

    if ( any(this.estimand :== "eventstudy") ) {
        if ( min(this.eventTime) >= 0 ) {
            rownames = rownames \ strofreal(this.eventTime') :+ ("." :+ tokens(this.varlist)[3])
        }
        else {
            rownames = rownames \ ((tokens(this.varlist)[3] :+ " ") \ J(length(this.eventTime)-1, 1, "")) :+ strofreal(this.eventTime')
        }
    }

    if ( this.multievent ) {
        st_matrix("e(eventTime)", colshape(this.eventTime, 1))
        st_matrixcolstripe("e(eventTime)", ("", tokens(this.varlist)[2]))
    }

    if ( this.nestimands > 1 ) {
        st_matrix("e(thetastar)", this.thetastar)
        st_matrixcolstripe("e(thetastar)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(thetastar)", (eqnames, rownames))

        st_matrix("e(se_neyman)", this.se_neyman)
        st_matrixcolstripe("e(se_neyman)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(se_neyman)", (eqnames, rownames))

        st_matrix("e(se_adjusted)", this.se_adjusted)
        st_matrixcolstripe("e(se_adjusted)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(se_adjusted)", (eqnames, rownames))
    }

    st_matrix("e(Wald_test)", this.Wald_test)
    st_matrixcolstripe("e(Wald_test)", (("" \ ""), ("Wald Statistic" \ "p-value")))
    st_matrixrowstripe("e(Wald_test)", ("", "X-hat"))

    if ( this.anyfisher ) {
        st_matrix("e(fisher_neyman)", this.fisher_neyman)
        st_matrixrowstripe("e(fisher_neyman)", (eqnames, rownames))

        st_matrix("e(fisher_adjusted)", this.fisher_adjusted)
        st_matrixrowstripe("e(fisher_adjusted)", (eqnames, rownames))

        st_numscalar("e(fisher_supt_pval)", this.fisher_supt_pval)
    }

    colnames = tokens(this.varlist)[3] \ "se_adjusted" \ "se_neyman"
    results  = this.thetastar, this.se_adjusted, this.se_neyman
    if ( this.anyfisher ) {
        colnames = colnames \ "fisher_pval_neyman" \ "fisher_pval_adjusted"
        results  = results, this.fisher_neyman, this.fisher_adjusted
    }
    st_matrix("e(results)", results)
    st_matrixcolstripe("e(results)", (J(length(colnames), 1, ""), colnames))
    st_matrixrowstripe("e(results)", (eqnames, rownames))
}
end
