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
    real matrix    cohort_size

    // info
    string scalar  varlist
    string scalar  touse
    real scalar    N
    real scalar    Nt
    real scalar    Ng
    real scalar    preperiods

    // options
    real scalar    skip_data_check
    real vector    eventTime
    real scalar    num_fisher_permutations
    real scalar    return_full_vcv
    real scalar    use_last_treated_only
    real scalar    compute_fisher
    string scalar  estimand
                   
    // results     
    real matrix    A_theta
    real matrix    A_0
    real scalar    betastar
    real scalar    thetastar
    real scalar    betahat
    real scalar    thetahat0
    real scalar    V_X
    real scalar    V_thetaX
    real scalar    V_theta
    real scalar    Xhat
    real scalar    adjustmentFactor
    real scalar    var_conservative
    real scalar    se_conservative 
    real scalar    var_adjusted    
    real scalar    se_adjusted     

    // functions
    void new()
    void init()
    void clear()
    void check_caller()
    void update_selection()
    void post()
    void estimate()

    void setup_encode_i()
    void setup_balance_df()
    void setup_flag_singletons()
    void setup_eventstudy()

    void compute_Ag_simple()
    void compute_Ag_cohort()
    void compute_Ag_calendar()
    void compute_Ag_eventstudy()
    void compute_estimand()
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
    this.skip_data_check         = (st_local("StagOpt_skip_data_check")         != "")
    this.eventTime               = strtoreal(tokens(st_local("StagOpt_eventTime")))
    this.num_fisher_permutations = strtoreal(st_local("StagOpt_num_fisher_permutations"))
    this.return_full_vcv         = (st_local("StagOpt_return_full_vcv")         != "")
    this.use_last_treated_only   = (st_local("StagOpt_use_last_treated_only")   != "")
    this.compute_fisher          = (st_local("StagOpt_compute_fisher")          != "")
    this.estimand                = st_local("StagOpt_estimand")
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
    this.cohort_size = .
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

    if ( length(this.eventTime) > 1 ) this.setup_eventstudy()
}

void function Staggered::estimate()
{
    // If estimand is provided, calculate the appropriate A_theta_list
    if ( this.estimand == "simple" ){
        this.compute_Ag_simple()
    }
    else if ( this.estimand == "cohort" ){
        this.compute_Ag_cohort()
    }
    else if ( this.estimand == "calendar" ){
        this.compute_Ag_calendar()
    }
    else if ( this.estimand == "eventstudy" ){
        this.compute_Ag_eventstudy()
    }
    else {
        errprintf("no valid estimand provided: \n", this.estimand)
        _error(198)
    }
    this.compute_estimand()

    // can be inside compute_fisher
    // Do FRT, if specified
    // xx permuteTreatment <- function(df,i_g_table, seed) {
    // xx     // This function takes a data.frame with columns i and g, and permutes the values of g assigned to i
    // xx     // The input i_g_table has the unique combinations of (i,g) in df, and is calculated outside for speed improvements
    // xx
    // xx     // Draw a random permutation of the elements of first_period_df
    // xx     set.seed(seed)
    // xx     n = NROW(i_g_table)
    // xx     randIndex <-
    // xx     sample.int(n = n,
    // xx     size = n,
    // xx     replace = F)
    // xx
    // xx     // Replace first_period_df$g with a permuted version based on randIndex
    // xx     i_g_table$g <- i_g_table$g[randIndex]
    // xx
    // xx     // Merge the new treatment assignments back with the original
    // xx     df$g <- NULL
    // xx     df <- dplyr::left_join(df,
    // xx     i_g_table,
    // xx     by = c("i"))
    // xx     return(df)
    // xx }

    // xx if(compute_fisher){
    // xx
    // xx   #Find unique pairs of (i,g). This will be used for computing the permutations
    // xx   # i_g_table <- df %>%
    // xx   #              dplyr::filter(t == min(t)) %>%
    // xx   #              dplyr::select(i,g)
    // xx
    // xx   i_g_table <- df %>%
    // xx     dplyr::filter(t == min(t))
    // xx   i_g_table <- i_g_table[,c("i","g")]
    // xx
    // xx   #Now, we compute the FRT for each seed, permuting treatment for each one
    // xx     #We catch any errors in the FRT simulations, and throw a warning if at least one has an error (using the remaining draws to calculate frt)
    // xx   FRTResults <-
    // xx     purrr::map(.x = 1:num_fisher_permutations,
    // xx                .f = purrr::possibly(
    // xx                  .f =~ staggered::staggered(df = permuteTreatment(df, i_g_table, seed = .x),
    // xx                                             estimand = NULL,
    // xx                                             beta = user_input_beta,
    // xx                                             A_theta_list = A_theta_list,
    // xx                                             A_0_list = A_0_list,
    // xx                                             eventTime = eventTime,
    // xx                                             return_full_vcv = F,
    // xx                                             return_matrix_list = F,
    // xx                                             compute_fisher = F,
    // xx                                             skip_data_check = T) %>% mutate(seed = .x),
    // xx                  otherwise = NULL)
    // xx     ) %>%
    // xx     purrr::discard(base::is.null) %>%
    // xx     purrr::reduce(.f = dplyr::bind_rows)
    // xx
    // xx   successful_frt_draws <- NROW(FRTResults)
    // xx   if(successful_frt_draws < num_fisher_permutations){
    // xx     warning("There was an error in at least one of the FRT simulations. Removing the problematic draws.")
    // xx   }
    // xx
    // xx   resultsDF$fisher_pval <- mean( abs(resultsDF$estimate/resultsDF$se) < abs(FRTResults$estimate/FRTResults$se) )
    // xx   resultsDF$fisher_pval_se_neyman <- mean( abs(resultsDF$estimate/resultsDF$se_neyman) < abs(FRTResults$estimate/FRTResults$se_neyman) )
    // xx   resultsDF$num_fisher_permutations <- successful_frt_draws
    // xx
    // xx }
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
    this.i = runningsum(this.i)
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

    real scalar i, g_map, N_total
    real matrix A_0_w

    // List of all 'candidate' g, t (cohort, period)
    // - t is a candidate if any g will be treated at g, except the last g
    // - g is a candidate if it will be treated at any t, except the last t
    g_all  = this.g[cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all)  :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex((min(t_list) :<= g_all) :& (g_all :< max(g_all)))
    g_list = g_all[g_sel]
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
        i_sel   = selectindex(g_all :>  t_list[i])
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
        i_sel = selectindex(g_all :> t_list[i])
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

    real scalar i, g_map, t_tot, N_total
    real matrix A_0_w

    // This is more or less the same as the simple version, except the
    // weight at each pair is different:
    // - N_g/(sum_g N_g) for a given g
    // - 1/(# t >= g and < max_g) across t for a given g

    g_all  = this.g[cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all) :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex((g_all :< max(g_all)) :& (g_all :<= max(t_all)))
    g_list = g_all[g_sel]
    this.preperiods = sum(t_all :< min(g_all))

    // A_theta; scaling changes a decent amount but overall similar
    g_scale = J(this.Ng, 1, 1)
    for(i = 1; i <= length(g_list); i++) {
        g_scale[g_sel[i]] = sum(t_list :>= g_list[i])
    }

    N_total = sum(this.cohort_size[g_sel])
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel   = selectindex(g_all :>  t_list[i])
        i_inv   = selectindex(g_all :<= t_list[i])
        t_tot   = sum(g_list :<= t_list[i])
        g_wgt   = this.cohort_size[1::t_tot] :/ g_scale[1::t_tot]
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
        i_sel = selectindex(g_all :> t_list[i])
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
    real scalar i
    real matrix A_0_w

    g_all  = this.g[cohort_info[., 1]]
    t_all  = this.t[1::this.Nt]
    t_sel  = selectindex((min(g_all) :<= t_all) :& (t_all :< max(g_all)))
    t_list = t_all[t_sel]
    g_sel  = selectindex(g_all :<= max(t_sel))
    g_list = g_all[g_sel]
    this.preperiods = sum(t_all :< min(g_all))

    // A_theta; scaling changes a decent amount but overall similar
    this.A_theta = J(this.Ng, this.Nt, 0)
    Ng_control = sum(this.cohort_size) :- runningsum(this.cohort_size)
    for(i = 1; i <= length(t_list); i++) {
        i_sel = selectindex(g_all :>  t_list[i])
        i_inv = selectindex(g_all :<= t_list[i])
        g_wgt = this.cohort_size[i_inv] :/ sum(this.cohort_size[i_inv])
        this.A_theta[i_sel, t_sel[i]] = - J(1, length(g_wgt), this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]) * g_wgt
        this.A_theta[i_inv, t_sel[i]] = g_wgt
    }
    this.A_theta = this.A_theta :/ length(t_list)

    // A_0; scaling changes a decent amount but overall similar
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
        i_sel = selectindex(g_all :> t_list[i])
        this.A_0[i_sel, t_sel[i]] = this.cohort_size[i_sel] :/ Ng_control[i_sel[1]-1]
    }

    this.A_0 = - this.A_0 * A_0_w
    for(i = 1; i <= length(g_list); i++) {
        this.A_0[i, g_map[i]] = sum(A_0_w[t_sel[selectindex(t_list :> g_map[i])], g_map[i]])
    }
    this.A_0 = this.A_0 :/ length(t_list)
}

void function Staggered::compute_Ag_eventstudy()
{
    errprintf("compute_Ag_eventstudy() not yet implemented; xx rawwwr\n")
    _error(198)
}

void function Staggered::compute_estimand()
{
    real scalar i
    real colvector preindex
    real rowvector Y_sum, A0_g, At_g
    real matrix Y_g, S_g, S_preperiod

    // This computes \beta^star and the variance of (\hat{theta}_0, \hat{X})
    // as presented under Proposition 2.1
    //
    // - S_g is defined the prior page as, basically, the vcov of Y_g
    // - I don't really know how the A_g were defined but I got it from
    //   the code; see the compute_Ag_* functions above
    // - S_\theta is defined but I haven't invested time into parsing it out;
    //   I also got it from the code and I'm 90% sure it's the adjustmentFactor

    preindex    = 1::this.preperiods
    V_X         = 0
    V_thetaX    = 0
    V_theta     = 0
    thetahat0   = 0
    Xhat        = 0
    betahat     = J(this.preperiods, 1, 0)
    S_preperiod = J(this.preperiods, this.preperiods, 0)
    for(i = 1; i <= this.Ng; i++) {

        Y_g   = colshape(panelsubmatrix(this.y, i, this.cohort_info), this.Nt)
        S_g   = variance(Y_g)
        Y_sum = colsum(Y_g)
        A0_g  = this.A_0[i, .]
        At_g  = this.A_theta[i, .]

        this.V_X       = this.V_X       + (A0_g * S_g * A0_g') / this.cohort_size[i]
        this.V_thetaX  = this.V_thetaX  + (A0_g * S_g * At_g') / this.cohort_size[i]
        this.V_theta   = this.V_theta   + (At_g * S_g * At_g') / this.cohort_size[i]
        this.thetahat0 = this.thetahat0 + Y_sum * At_g' / this.cohort_size[i]
        this.Xhat      = this.Xhat      + Y_sum * A0_g' / this.cohort_size[i]
        this.betahat   = this.betahat  :+ pinv(S_g[preindex, preindex]) * S_g[preindex, .] * At_g'

        S_preperiod = S_preperiod + S_g[preindex, preindex]
    }
    this.adjustmentFactor = (this.betahat' * (S_preperiod / this.Ng) * this.betahat) / sum(this.cohort_size)
    this.betastar         = this.V_thetaX / this.V_X
    this.thetastar        = this.thetahat0 - this.Xhat * this.betastar
    this.var_conservative = this.V_theta - this.V_thetaX * this.betastar
    this.se_conservative  = this.var_conservative > 0? sqrt(this.var_conservative): 0
    this.var_adjusted     = this.var_conservative - this.adjustmentFactor
    this.se_adjusted      = this.var_adjusted > 0? sqrt(this.var_adjusted): 0

    if ( any((this.var_conservative, this.var_adjusted) :< 0) ) {
        errprintf("Calculated variance is less than 0. Setting SE to 0.\n")
    }
}

// If eventTime is a vector, call staggered for each event-time and combine the results
void function Staggered::setup_eventstudy()
{
    if ( this.estimand != "eventstudy" ) {
        errprintf("You provided a vector fpr eventTime but estimand is not set to\n")
        errprintf("'eventstudy'. Did you mean to set estimand = 'eventstudy'?\n")
        _error(198)
    }
}

void function Staggered::post(string scalar b, string scalar V,| string scalar vce)
{
    if ( args() < 3 ) vce = "adjusted"
    string vector rownames, eqnames
    eqnames  = ""
    rownames = tokens(this.varlist)[3]
    st_matrix(b, this.thetastar)
    st_matrixcolstripe(b, (eqnames, rownames))
    st_matrixrowstripe(b, ("", tokens(this.varlist)[4]))

    st_matrix(V, (vce == "conservative"? this.se_conservative: this.se_adjusted)^2)
    st_matrixcolstripe(V, (eqnames, rownames))
    st_matrixrowstripe(V, (eqnames, rownames))
}
end
