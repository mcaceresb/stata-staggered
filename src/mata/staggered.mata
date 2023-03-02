cap mata mata drop StaggeredNew()
cap mata mata drop Staggered()
// map ,,p mm<A-a>:s/this\.//g<CR>`m

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
    real scalar    preperiods
    real scalar    multievent
    real scalar    anyfisher
    real colvector times
    real colvector cohorts
    real matrix    cohort_size

    // options
    real vector    eventTime
    real scalar    num_fisher
    string scalar  estimand
    real scalar    user_beta
    real scalar    skip_data_check
    real scalar    use_last_treated_only
    real scalar    drop_treated_beforet

    // results
    real matrix    A_theta
    real matrix    A_0
    real colvector betastar
    real colvector thetastar
    real colvector thetahat0
    real colvector V_X
    real colvector V_thetaX
    real colvector V_theta
    real colvector Xhat
    real colvector adjustmentFactor
    real colvector var_neyman
    real colvector se_neyman
    real colvector var_adjusted
    real colvector se_adjusted
    real colvector fisher_adjusted
    real colvector fisher_neyman
    real colvector fisher_supt_pval
    real matrix    Wald_test

    // functions
    void new()
    void init()
    void clear()
    void check_caller()
    void update_selection()
    void post()
    void events()
    void estimate()
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
    this.estimand              = st_local("StagOpt_estimand")
    this.user_beta             = strtoreal(st_local("StagOpt_beta"))
    this.skip_data_check       = (st_local("StagOpt_skip_data_check")       != "")
    this.use_last_treated_only = (st_local("StagOpt_use_last_treated_only") != "")
    this.drop_treated_beforet  = (st_local("StagOpt_drop_treated_beforet")  != "")
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

    this.setup_encode_i(vars[1])            // reads i
    this.setup_balance_df(vars[2], vars[3]) // reads t, g
    this.setup_flag_singletons()
    this.y = st_data(., vars[4], this.touse)[this.index]
    this.multievent = length(this.eventTime) > 1
    this.anyfisher  = this.num_fisher>0
    this.times      = this.t[1::this.Nt]
    this.cohorts    = this.g[this.cohort_info[., 1]]
}

void function Staggered::estimate()
{
    real scalar event

    // Initialize all the outcome vectors; they're vectors in case the
    // user requests multiple events with estimand eventtime; otherwise
    // they're a single scalar

    this.V_X                 = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.V_theta             = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.V_thetaX            = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.Xhat                = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.adjustmentFactor    = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.betastar            = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.se_adjusted         = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.se_neyman           = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.thetahat0           = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.thetastar           = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.var_adjusted        = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.var_neyman          = J(max((length(this.eventTime)\1))+this.anyfisher, 1, .)
    this.fisher_adjusted     = J(max((length(this.eventTime)\1)), 1, .)
    this.fisher_neyman       = J(max((length(this.eventTime)\1)), 1, .)
    this.fisher_supt_pval    = J(max((length(this.eventTime)\1)), 1, .)
    this.Wald_test           = J(max((length(this.eventTime)\1))+this.anyfisher, 2, .)

    // If estimand is provided, calculate the appropriate A_theta_list
    if ( this.estimand == "eventstudy" ) {
        if ( length(this.eventTime) ) {
            this.setup_eventstudy()
        }
        else {
            this.eventTime = 0
        }
        for(event = length(this.eventTime); event >= 1; event--) {
            this.compute_Ag_eventstudy(this.eventTime[event])
            this.compute_estimand(event)
            this.compute_fisher(event)
        }
    }
    else {
        if ( this.estimand == "simple" ) {
            this.compute_Ag_simple()
        }
        else if ( this.estimand == "cohort" ) {
            this.compute_Ag_cohort()
        }
        else if ( this.estimand == "calendar" ) {
            this.compute_Ag_calendar()
        }
        else {
            errprintf("no valid estimand provided: \n", this.estimand)
            _error(198)
        }
        this.compute_estimand()
        this.compute_fisher()
    }

    if ( this.anyfisher ) {
        this.V_X              = this.V_X             [1::(length(this.V_X             )-1)]
        this.V_theta          = this.V_theta         [1::(length(this.V_theta         )-1)]
        this.V_thetaX         = this.V_thetaX        [1::(length(this.V_thetaX        )-1)]
        this.Xhat             = this.Xhat            [1::(length(this.Xhat            )-1)]
        this.adjustmentFactor = this.adjustmentFactor[1::(length(this.adjustmentFactor)-1)]
        this.betastar         = this.betastar        [1::(length(this.betastar        )-1)]
        this.se_adjusted      = this.se_adjusted     [1::(length(this.se_adjusted     )-1)]
        this.se_neyman        = this.se_neyman       [1::(length(this.se_neyman       )-1)]
        this.thetahat0        = this.thetahat0       [1::(length(this.thetahat0       )-1)]
        this.thetastar        = this.thetastar       [1::(length(this.thetastar       )-1)]
        this.var_adjusted     = this.var_adjusted    [1::(length(this.var_adjusted    )-1)]
        this.var_neyman       = this.var_neyman      [1::(length(this.var_neyman      )-1)]
        this.Wald_test        = this.Wald_test       [1::(rows  (this.Wald_test       )-1), .]
    }
}

void function Staggered::check_caller()
{
    if ( st_local("StagOpt_Caller") != "staggered" ) {
        errprintf("internal function Staggered() should not be called from outside -staggered-\n")
        _error(198)
    }
}

void function Staggered::setup_encode_i(string scalar var)
{
    string colvector svar
    real colvector rvar

    if ( strpos(st_vartype(var), "str") ) {
        svar       = st_sdata(., var, this.touse)
        this.N     = length(svar)
        this.index = order(svar, 1)
        this.info  = panelsetup(svar[this.index], 1)
    }
    else {
        rvar       = st_data(., var, this.touse)
        this.N     = length(rvar)
        this.index = order(rvar, 1)
        this.info  = panelsetup(rvar[this.index], 1)
    }
    this.i = J(this.N, 1, 0)
    this.i[this.info[., 1]] = J(rows(this.info), 1, 1)
    this.Ni = rows(this.info)
    this.i  = runningsum(this.i)
    this.sel = J(this.N, 1, 1)
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
    real scalar j
    real colvector numPeriods, dropPeriods, cohort_ord
    real rowvector sub

    this.t      = st_data(., tvar, this.touse)[this.index]
    this.g      = st_data(., gvar, this.touse)[this.index]
    cohort_ord  = order((this.g, this.i, this.t), (1, 2, 3))
    this.index  = this.index[cohort_ord]
    this.i      = this.i[cohort_ord]
    this.t      = this.t[cohort_ord]
    this.g      = this.g[cohort_ord]

    numPeriods  = this.info[., 2] :- this.info[., 1] :+ 1
    this.Nt     = max(numPeriods)
    dropPeriods = selectindex(numPeriods :< this.Nt)

    if ( this.Nt < 2 ) {
        errprintf("All individuals appear in only one period; aborting\n")
        _error(2000)
    }

    if ( this.skip_data_check ) return

    // Ensure balanced panel
    if ( length(dropPeriods) ) {
        errprintf("\nPanel is unbalanced (or has missing values) for some observations. Will")
        errprintf("\ndrop observations with missing values of Y_{it} for any time periods. If")
        errprintf("\nyou wish to include these observations, provide staggered with a balanced")
        errprintf("\ndata set with imputed outcomes.")
        errprintf("\n\n")

        for(j = 1; j <= length(dropPeriods); j++) {
            sub = this.info[dropPeriods[j], .]'
            this.sel[|sub|] = J(sub[2] - sub[1] + 1, 1, 0)
        }
        this.update_selection()
    }

    // This only works because (i, t) is sorted and each i has 2+ periods
    if ( any(this.t[|2 \ this.N|] :== this.t[|1 \ this.N-1|]) ) {
        errprintf("The panel should have a unique outcome for each (i, t) value\n")
        _error(459)
    }
}

void function Staggered::setup_flag_singletons()
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
            gfmt = strtrim(sprintf(st_varformat(g), this.g[this.cohort_info[flag_singleton[1], 1]]))
            errprintf("Treatment cohort g = %s has a single cross-sectional unit. We drop this cohort.\n", gfmt)
        }
        else {
            errprintf("Treatment cohorts found with a single cross-sectional unit. We drop these cohorts.\n")
            for(j = 1; j <= length(flag_singleton); j++) {
                gfmt = sprintf(st_varformat(g), this.g[this.cohort_info[flag_singleton[j], 1]])
                errprintf("\tg = %s\n", gfmt)
            }
        }

        this.sel = J(this.N, 1, 1)
        for(j = 1; j <= length(flag_singleton); j++) {
            sub = cohort_info[flag_singleton[j], .]'
            this.sel[|sub|] = J(sub[2] - sub[1] + 1, 1, 0)
        }
        update_selection()
    }
}

void function Staggered::update_selection()
{
    real colvector keep
    if ( this.sel == . ) return
    if ( all(this.sel) ) return

    keep = selectindex(this.sel)
    this.N = length(keep)
    if ( this.N ) {
        if ( this.touse != "" ) st_store(., this.touse, this.sel)
        if ( this.i     != .  ) this.i     = this.i[keep]
        if ( this.t     != .  ) this.t     = this.t[keep]
        if ( this.y     != .  ) this.y     = this.y[keep]
        if ( this.index != .  ) this.index = this.index[keep]
        if ( this.info  != .  ) this.info  = panelsetup(this.i, 1)
        if ( this.info  != .  ) this.Ni    = rows(this.info)
        if ( this.g     != .  ) {
            this.g           = this.g[keep]
            this.cohort_info = panelsetup(this.g, 1)
            this.Ng          = rows(this.cohort_info)
            this.cohort_size = (this.cohort_info[., 2] :- this.cohort_info[., 1] :+ 1) :/ this.Nt
        }
        this.sel = J(N, 1, 1)
    }
    else {
        errprintf("no observations")
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
    real matrix A_0_w

    // List of all 'candidate' g, t (cohort, period)
    // - t is a candidate if any g will be treated at g, except the last g
    // - g is a candidate if it will be treated at any t, except the last t
    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all)  :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex((min(t_list) :<= g_all) :& (g_all :< max(g_all)))
    g_list = g_all[g_sel]
    g_max  = max(g_all)
    this.preperiods = sum(t_all :< min(g_all))

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
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel   = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv   = selectindex(g_all :<= t_list[i])
        g_wgt   = this.cohort_size[g_sel[selectindex(g_list :<= t_list[i])]]
        N_total = N_total + sum(g_wgt)
        this.A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        this.A_theta[i_inv, t_sel[i]] = this.cohort_size[i_inv]
    }
    this.A_theta = this.A_theta :/ N_total

    // This is very similar to the above, thinking of the result via method
    // B.  Instead of placing the vector in the t-th column, place it in the
    // column t: t = g-1, then sum across g, t (and divide by N_total).  The
    // below does this but, again, semi-vectorized for ease of computation.
    this.A_0 = J(this.Ng, this.Nt, 0)
    A_0_w    = J(this.Nt, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = selectindex(t_all :>= g_list[i])
        A_0_w[i_sel, g_map] = J(length(i_sel), 1, this.cohort_size[i])
    }

    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        this.A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    this.A_0 = - this.A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        this.A_0[i, g_map] = sum(t_all :> g_list[i]) * this.cohort_size[i]
    }
    this.A_0 = this.A_0 :/ N_total
}

void function Staggered::compute_Ag_cohort()
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, g_wgt, g_scale, Ng_control

    real scalar i, g_map, g_max, t_tot, N_total
    real matrix A_0_w

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
    this.preperiods = sum(t_all :< min(g_all))

    // A_theta; scaling changes a decent amount but overall similar
    // TODO: xx explain loop and mapping to weighting here
    g_scale = J(this.Ng, 1, 1)
    for(i = 1; i <= length(g_list); i++) {
        g_scale[g_sel[i]] = sum(t_list :>= g_list[i])
    }

    N_total = sum(this.cohort_size[g_sel])
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= t_list[i])
        t_tot = sum(g_list :<= t_list[i])
        g_wgt = this.cohort_size[1::t_tot] :/ g_scale[1::t_tot]
        this.A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        this.A_theta[i_inv, t_sel[i]] = this.cohort_size[i_inv] :/ g_scale[i_inv]
    }
    this.A_theta = this.A_theta :/ N_total

    // A_0; almost identical (just adds g_scale)
    this.A_0 = J(this.Ng, this.Nt, 0)
    A_0_w    = J(this.Nt, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = selectindex(t_all :>= g_list[i])
        A_0_w[i_sel, g_map] = J(length(i_sel), 1, this.cohort_size[i] / g_scale[i])
    }

    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        this.A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    this.A_0 = - this.A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        this.A_0[i, g_map] = sum(t_all :> g_list[i]) * this.cohort_size[i] / g_scale[i]
    }
    this.A_0 = this.A_0 :/ N_total
}

void function Staggered::compute_Ag_calendar()
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, g_wgt, Ng_control

    real rowvector g_map
    real scalar i, g_max
    real matrix A_0_w

    g_all  = this.g[this.cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all) :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex(g_all :<= max(t_sel))
    g_list = g_all[g_sel]
    g_max  = max(g_all)
    this.preperiods = sum(t_all :< min(g_all))

    // A_theta; scaling changes a decent amount but overall similar
    // TODO: xx explain loop and mapping to weighting here
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= t_list[i])
        g_wgt = this.cohort_size[i_inv] :/ sum(this.cohort_size[i_inv])
        this.A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        this.A_theta[i_inv, t_sel[i]] = g_wgt
    }
    this.A_theta = this.A_theta :/ length(t_list)

    // A_0; same idea but  scaling changes a _lot_, actually
    // TODO: xx explain loop and mapping to weighting here
    this.A_0 = J(this.Ng, this.Nt, 0)
    A_0_w    = J(this.Nt, this.Nt, 0)
    g_map    = J(1,       this.Ng, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map[i] = selectindex(t_all :== (g_list[i]-1))
    }
    for(i = 1; i <= length(t_all); i++) {
        i_sel = selectindex(g_list :<= t_all[i])
        A_0_w[i, g_map[i_sel]] = this.cohort_size[g_sel[i_sel]]' / sum(this.cohort_size[g_sel[i_sel]])
    }
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        this.A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    this.A_0 = - this.A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        this.A_0[i, g_map[i]] = sum(A_0_w[t_sel[selectindex(t_list :> g_map[i])], g_map[i]])
    }
    this.A_0 = this.A_0 :/ length(t_list)
}

void function Staggered::compute_Ag_eventstudy(real scalar event)
{
    real colvector g_all,  t_all
    real colvector g_sel,  t_sel
    real colvector g_list, t_list
    real colvector i_sel, i_inv, Ng_control

    real scalar i, g_map, g_max, x_map, N_total
    real matrix A_0_w
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
    this.preperiods = sum(t_all :< min(g_all))

    t_sel = J(1, length(t_list), 0)
    x_map = J(1, length(t_list), 0)
    for(i = 1; i <= length(t_list); i++) {
        t_sel[i] = selectindex(t_all :== t_list[i])
        x_map[i] = selectindex((g_all :+ event) :== t_list[i])
    }

    // A_theta
    // TODO: xx explain loop and mapping to weighting here
    N_total = sum(this.cohort_size[g_sel])
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        i_inv = selectindex(g_all :<= g_list[i])
        this.A_theta[i_sel, t_sel[i]] = - this.cohort_size[x_map[i]] :* this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
        this.A_theta[i_inv[length(i_inv)], t_sel[i]] = this.cohort_size[x_map[i]]
    }
    this.A_theta = this.A_theta :/ N_total

    // A_0
    // TODO: xx explain loop and mapping to weighting here
    this.A_0 = J(this.Ng, this.Nt, 0)
    A_0_w    = J(this.Nt, this.Nt, 0)
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_sel = selectindex(t_all :== (g_list[i]+event))
        A_0_w[i_sel, g_map] = this.cohort_size[x_map[i]]
    }
    for(i = 1; i <= length(t_list); i++) {
        i_sel = this.use_last_treated_only? selectindex((g_all :> t_list[i]) :& (g_all :== g_max)): selectindex(g_all :> t_list[i])
        this.A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }
    this.A_0 = - this.A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        g_map = selectindex(t_all :== (g_list[i]-1))
        i_inv = selectindex(g_all :<= g_list[i])
        this.A_0[i_inv[length(i_inv)], g_map] = this.cohort_size[x_map[i]]
    }
    this.A_0 = this.A_0 :/ N_total
}

void function Staggered::compute_estimand(|real scalar index)
{
    if ( args() < 1 ) index = 1

    real scalar i
    real colvector preindex, betahat
    real rowvector Y_sum, A0_g, At_g
    real matrix Y_g, S_g, S_preperiod

    // R translation notes
    //     varhat_conservative <-> var_neyman
    //     Xvar                <-> V_X
    //     X_theta_cov         <-> V_thetaX
    //     all this is simplified for scalars but R writes it all for
    //     matrices (though AFAIK it's all scalars)

    // This computes \beta^star and the variance of (\hat{theta}_0, \hat{X})
    // as presented under Proposition 2.1
    //
    // - S_g is defined the prior page as, basically, the vcov of Y_g
    // - I don't really know how the A_g were defined but I got it from
    //   the code; see the compute_Ag_* functions above
    // - S_\theta is defined but I haven't invested time into parsing it out;
    //   I also got it from the code and I'm 90% sure it's the adjustmentFactor

    preindex              = 1::this.preperiods
    this.V_X[index]       = 0
    this.V_thetaX[index]  = 0
    this.V_theta[index]   = 0
    this.thetahat0[index] = 0
    this.Xhat[index]      = 0
    betahat               = J(this.preperiods, 1, 0)
    S_preperiod           = J(this.preperiods, this.preperiods, 0)
    for(i = 1; i <= this.Ng; i++) {

        Y_g   = colshape(panelsubmatrix(this.y, i, this.cohort_info), this.Nt)
        S_g   = variance(Y_g)
        Y_sum = colsum(Y_g)
        A0_g  = this.A_0[i, .]
        At_g  = this.A_theta[i, .]

        this.V_X[index]      = this.V_X[index]          + (A0_g * S_g * A0_g') / this.cohort_size[i]
        this.V_thetaX[index] = this.V_thetaX[index]     + (A0_g * S_g * At_g') / this.cohort_size[i]
        this.V_theta[index]  = this.V_theta[index]      + (At_g * S_g * At_g') / this.cohort_size[i]
        this.thetahat0[index]= this.thetahat0[index]    + Y_sum * At_g' / this.cohort_size[i]
        this.Xhat[index]     = this.Xhat[index]         + Y_sum * A0_g' / this.cohort_size[i]

        betahat     = betahat :+ pinv(S_g[preindex, preindex]) * S_g[preindex, .] * At_g'
        S_preperiod = S_preperiod + S_g[preindex, preindex]
    }
    this.adjustmentFactor[index] = (betahat' * (S_preperiod / this.Ng) * betahat) / sum(this.cohort_size)
    this.betastar[index]         = (this.user_beta == .)? (this.V_thetaX[index] / this.V_X[index]): this.user_beta
    this.thetastar[index]        = this.thetahat0[index] - this.Xhat[index] * this.betastar[index]
    this.var_neyman[index]       = this.V_theta[index] + this.betastar[index]' * this.V_X[index] * this.betastar[index] - 2 * this.V_thetaX[index] * this.betastar[index]
    this.se_neyman[index]        = this.var_neyman[index] > 0? sqrt(this.var_neyman[index]): 0
    this.var_adjusted[index]     = this.var_neyman[index] - this.adjustmentFactor[index]
    this.se_adjusted[index]      = this.var_adjusted[index] > 0? sqrt(this.var_adjusted[index]): 0
    this.Wald_test[index, 1]     = this.Xhat[index]^2 / this.V_X[index]
    this.Wald_test[index, 2]     = chi2tail(1, this.Wald_test[index, 1])

    if ( any((this.var_neyman[index], this.var_adjusted[index]) :< 0) ) {
        errprintf("Calculated variance is less than 0. Setting SE to 0.\n")
    }
}

// Randomly permute the treatmnet timing (cohort) at the individual level
// at each iteration and record the estimand and se (for t-stat)
//
// Note permuting the cohorts at the individual level means the cohort
// sizes, etc. remain the same. Since the panel is forced to be balanced,
// the only thing that changes is the outcome; in other words, Y_it
// is permuted, but everything else is static.
void function Staggered::compute_fisher(|real scalar index)
{
    if ( args() < 1 ) index = 1

    real scalar dummy
    real colvector _thetastar
    real colvector _se_adjusted
    real colvector _se_neyman
    real colvector _Wald_stat

    if ( !this.anyfisher ) return

    dummy = length(this.thetastar)

    _thetastar       = J(num_fisher, 1, .)
    _se_adjusted     = J(num_fisher, 1, .)
    _se_neyman       = J(num_fisher, 1, .)
    _Wald_stat       = J(num_fisher, 1, .)
    for(i = 1; i <= num_fisher; i++) {
        this.permute_cohort(i)
        this.compute_estimand(dummy)
        _thetastar[i]      = this.thetastar[dummy]
        _se_adjusted[i]    = this.se_adjusted[dummy]
        _se_neyman[i]      = this.se_neyman[dummy]
        _Wald_stat[i]      = this.Wald_test[dummy, 1]
    }

    this.fisher_adjusted[index]  = mean(abs(this.thetastar[index] / this.se_adjusted[index]) :< abs(_thetastar :/ _se_adjusted))
    this.fisher_neyman[index]    = mean(abs(this.thetastar[index] / this.se_neyman[index])   :< abs(_thetastar :/ _se_neyman))
    this.fisher_supt_pval[index] = mean(this.Wald_test[index, 1] :< _Wald_stat)
}

// Shuffle outcome y; note it's the only thing we need to shuffle
// and we don't need to unshuffle it even though it becomes out of
// sync with i because:
// - This is the last thing we run
// - The panel is balanced so re-shuffling without unshuffling
//   should be conceptually equivalent (even if not identical)
void function Staggered::permute_cohort(real scalar seed)
{
    real scalar i, Ni, fr, to, rseedcache
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
    if ( this.estimand != "eventstudy" ) {
        errprintf("You provided a vector for eventTime but estimand is not set to\n")
        errprintf("'eventstudy'. Did you mean to set estimand = 'eventstudy'?\n")
        _error(198)
    }
}

void function Staggered::post(string scalar b, string scalar V,| string scalar vce, real scalar index)
{

    if ( args() < 3 ) vce = "adjusted"
    if ( args() < 4 ) index = 1

    string vector rownames, eqnames

    if ( this.multievent ) {
        printf("(warning: e(V) is a diagonal matrix of SEs, not a full vcov matrix)\n")
        if ( min(this.eventTime) >= 0 ) {
            rownames = strofreal(this.eventTime') :+ ("." :+ tokens(this.varlist)[3])
        }
        else {
            rownames = ((tokens(this.varlist)[3] :+ " ") \ J(length(this.eventTime)-1, 1, "")) :+ strofreal(this.eventTime')
            // rownames = strofreal(this.eventTime')
        }

        eqnames = J(length(this.eventTime), 1, "")
        st_matrix(b, rowshape(this.thetastar, 1))
        st_matrixcolstripe(b, (eqnames, rownames))
        st_matrixrowstripe(b, ("", tokens(this.varlist)[4]))

        st_matrix(V, diag(vce == "neyman"? this.se_neyman: this.se_adjusted):^2)
        st_matrixcolstripe(V, (eqnames, rownames))
        st_matrixrowstripe(V, (eqnames, rownames))
    }
    else {
        eqnames  = ""
        rownames = tokens(this.varlist)[3]
        st_matrix(b, this.thetastar[index])
        st_matrixcolstripe(b, (eqnames, rownames))
        st_matrixrowstripe(b, ("", tokens(this.varlist)[4]))

        st_matrix(V, (vce == "neyman"? this.se_neyman[index]: this.se_adjusted[index])^2)
        st_matrixcolstripe(V, (eqnames, rownames))
        st_matrixrowstripe(V, (eqnames, rownames))
    }
}

void function Staggered::events()
{
    if ( this.multievent ) {
        st_matrix("e(eventTime)", colshape(this.eventTime, 1))
        st_matrixcolstripe("e(eventTime)", ("", tokens(this.varlist)[2]))

        st_matrix("e(thetastar)", this.thetastar)
        st_matrixcolstripe("e(thetastar)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(thetastar)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

        st_matrix("e(se_neyman)", this.se_neyman)
        st_matrixcolstripe("e(se_neyman)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(se_neyman)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

        st_matrix("e(se_adjusted)", this.se_adjusted)
        st_matrixcolstripe("e(se_adjusted)", ("", tokens(this.varlist)[4]))
        st_matrixrowstripe("e(se_adjusted)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

        st_matrix("e(Wald_test)", this.Wald_test)
        st_matrixcolstripe("e(Wald_test)", (("" \ ""), ("Wald Statistic" \ "p-value")))
        st_matrixrowstripe("e(Wald_test)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

        if ( this.anyfisher ) {
            st_matrix("e(fisher_neyman)", this.fisher_neyman)
            st_matrixrowstripe("e(fisher_neyman)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

            st_matrix("e(fisher_adjusted)", this.fisher_adjusted)
            st_matrixrowstripe("e(fisher_adjusted)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))

            st_matrix("e(fisher_supt_pval)", this.fisher_supt_pval)
            st_matrixrowstripe("e(fisher_supt_pval)", (J(length(this.eventTime), 1, ""), strofreal(this.eventTime')))
        }
    }
    else {
        st_matrix("e(Wald_test)", this.Wald_test)
        st_matrixcolstripe("e(Wald_test)", (("" \ ""), ("Wald Statistic" \ "p-value")))
        st_matrixrowstripe("e(Wald_test)", ("", "X-hat"))

        if ( this.anyfisher ) {
            st_matrix("e(fisher_neyman)",    this.fisher_neyman)
            st_matrix("e(fisher_adjusted)",  this.fisher_adjusted)
            st_matrix("e(fisher_supt_pval)", this.fisher_supt_pval)
        }
    }
}

void function Staggered::results()
{
    real matrix results
    string vector colnames, rownames, eqnames

    if ( this.multievent ) {
        eqnames  = ""
        colnames = tokens(this.varlist)[3] \ "se_adjusted" \ "se_neyman"
        rownames = strofreal(this.eventTime')
        results  = this.thetastar, this.se_adjusted, this.se_neyman
        if ( this.anyfisher ) {
            colnames = colnames \ "fisher_pval_neyman" \ "fisher_pval_adjusted"
            results  = results, this.fisher_neyman, this.fisher_adjusted
        }
        st_matrix("e(results)", results)
        st_matrixcolstripe("e(results)", (J(length(colnames), 1, ""), colnames))
        st_matrixrowstripe("e(results)", (J(length(this.eventTime), 1, ""), rownames))
    }
    else {
        eqnames  = ""
        colnames = tokens(this.varlist)[3] \ "se_adjusted" \ "se_neyman"
        results  = this.thetastar[1], this.se_adjusted[1], this.se_neyman[1]
        if ( this.anyfisher ) {
            colnames = colnames \ "fisher_pval_neyman" \ "fisher_pval_adjusted"
            results  = results, this.fisher_neyman, this.fisher_adjusted
        }
        st_matrix("e(results)", results)
        st_matrixcolstripe("e(results)", (J(length(colnames), 1, ""), colnames))
        st_matrixrowstripe("e(results)", ("", tokens(this.varlist)[4]))
    }
}
end
