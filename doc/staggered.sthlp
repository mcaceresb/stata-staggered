{smcl}
{* *! version 0.7.0 01Apr2023}{...}
{viewerdialog staggered "dialog staggered"}{...}
{vieweralsosee "[R] staggered" "mansection R staggered"}{...}
{viewerjumpto "Syntax" "staggered##syntax"}{...}
{viewerjumpto "Description" "staggered##description"}{...}
{viewerjumpto "Options" "staggered##options"}{...}
{viewerjumpto "Examples" "staggered##examples"}{...}
{title:Title}

{p2colset 5 18 18 2}{...}
{p2col :{cmd:staggered} {hline 2}}Stata implementation of the Staggered R package{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{pstd}
Stata version of the Staggered R package, which implements the efficient
estimator for staggered rollout designs proposed by Roth and Sant'Anna (2023).

{p 8 15 2}
{cmd:staggered}
{it:depvar}
{cmd:,}
{opt i(individual)}
{opt t(time)}
{opt g(cohort)}
{opt estimand()}
[{it:{help staggered##table_options:options}}]

{pstd}
{opt i()} identifies each individual and can be of any type; however,
{opt t()} and {opt g()} must both be numeric and have the same units,
as they both indicate time periods. Further, at least one estimand must
be requested (and multiple estimands are allowed).

{synoptset 27 tabbed}{...}
{marker table_options}{...}
{synopthdr}
{synoptline}
{syntab :Options}
{synopt :{opt i(varname)}} Individual{p_end}
{synopt :{opt t(varname)}} Time{p_end}
{synopt :{opt g(varname)}} Cohort (i.e.the time period the individual enters treatment).{p_end}
{synopt :{opt estimand(str)}} Estimand; any combination of: simple, cohort, calendar, eventstudy.{p_end}
{synopt :{opt eventTime(numlist)}} Event times for estimand eventstudy (default 0).{p_end}
{synopt :{opt beta(real)}} User-input beta (to use instead of betastar).{p_end}
{synopt :{opt num_fisher(int)}} Number of fisher permutations (default 0).{p_end}
{synopt :{opt skip_data_check}} Do not balance data (warning: data must already be balanced).{p_end}
{synopt :{opt return_full_vcv}} Return full vcov matrix (for event study estimands).{p_end}
{synopt :{opt drop_treated_beforet}} Drop cohorts treated (weakly) before first time period.{p_end}
{synopt :{opt use_last_treated_only}} Only use last treated cohort as treatment.{p_end}
{synopt :{opt vce(str)}} Either 'neyman' or 'adjusted' (default){p_end}
{synopt :{opt sa}} Callaway and Sant'Anna estimator (alias for beta(1) drop_treated_beforet).{p_end}
{synopt :{opt sa}} Sun and Abraham estimator (alias for beta(1) drop_treated_beforet use_last_treated_only).{p_end}

{p2colreset}{...}
{p 4 6 2}

{marker description}{...}
{title:Description}

{pstd}
See the {browse "https://github.com/mcaceresb/stata-staggered#readme":online examples} for details or refer to the examples below.

{marker example}{...}
{title:Example 1: Basic Usage}

{phang2}{cmd:. local github https://github.com/mcaceresb/stata-staggered }{p_end}
{phang2}{cmd:. use `github'/raw/main/pj_officer_level_balanced.dta, clear}{p_end}
{phang2}{cmd:.                                                           }{p_end}
{phang2}{cmd:. local stagopts i(uid) t(period) g(first_trained)          }{p_end}
{phang2}{cmd:. staggered complaints, `stagopts' estimand(simple)         }{p_end}
{phang2}{cmd:. staggered complaints, `stagopts' estimand(eventstudy simple) eventTime(0/4) num_fisher(500)}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:staggered} stores the following in {cmd:e()}:

{synoptset 23 tabbed}{...}
{p2col 5 23 26 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(fisher_supt_pval)}}fisher p-value from sup-t-statistic (only with num_fisher)){p_end}

{p2col 5 23 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:staggered}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(depvar)}}name of dependent variable{p_end}
{synopt:{cmd:e(individual)}}name of variable identifying individuals{p_end}
{synopt:{cmd:e(time)}}name of variable identifying the time period{p_end}
{synopt:{cmd:e(cohort)}}name of variable identifying cohort (when treated){p_end}
{synopt:{cmd:e(vce)}}variance computed (neyman, adjusted){p_end}
{synopt:{cmd:e(vcetype)}}same as vce but capitalized{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}
{synopt:{cmd:e(mata)}}name of mata object where results are stored (see below){p_end}

{p2col 5 23 26 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient of interest (theta){p_end}
{synopt:{cmd:e(V)}}variance of theta (diagonal matrix unless {cmd:return_full_vcv} is requested){p_end}
{synopt:{cmd:e(eventTime)}}event times (only with multiple eventTime values){p_end}
{synopt:{cmd:e(thetastar)}}estimates (only with multiple estimates or eventTime values){p_end}
{synopt:{cmd:e(se_neyman)}}neyman SEs (only with multiple estimates or eventTime values){p_end}
{synopt:{cmd:e(se_adjusted)}}adjusted SEs (only with multiple estimates or eventTime values){p_end}
{synopt:{cmd:e(Wald_test)}}Wald statistic (column 1) and p-value (column 2){p_end}
{synopt:{cmd:e(fisher_neyman)}}neyman fisher p-value (only with num_fisher()){p_end}
{synopt:{cmd:e(fisher_adjusted)}}adjusted fisher p-value (only with num_fisher)){p_end}
{synopt:{cmd:e(results)}}single matrix consolidating all results (estimate and SEs){p_end}

{p2col 5 23 26 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks estimation sample{p_end}
{p2colreset}{...}

{marker mata}{...}
{pstd}
The following data are available in {cmd:e(mata)} (default name: StaggeredResults):

        real scalar N
            number of observations used in estimation

        real scalar Ni
            number of individuals

        real scalar Nt
            number of time periods

        real scalar Ng
            number of cohorts

        real colvector times
            vector of unique time periods (sorted)

        real colvector cohorts
            vector of unique cohorts (sorted)

        real colvector cohort_size
            vector of cohort sizes (as used internally in the estimation)

        real scalar num_fisher
            number of fisher permutations

        real colvector thetastar
            estimated coefficient of interest

        real colvector betastar
            estimated \beta^* (or user-provided beta)

        real colvector Xhat
            estimate of \hat{X}

        real colvector Xhat_t
            t-statistic, \hat{X} / diagonal(V_{\hat{X}})

        real matrix V_X
            estimate of V_{\hat{X}} (variance of \hat{X})

        real colvector V_thetaX
            covariance of \hat{X} and \hat{\theta} (estimate of V_{\hat{\theta}, \hat{X}})

        real colvector V_theta
            estimate of V_{\hat{\theta}} (variance of \hat{\theta})

        real matrix A_theta
            auxiliary matrix with rows containing A_{theta, g} (stacked for multiple estimates/event times)

        real matrix A_0
            auxiliary matrix with rows containing A_{0, g} (stacked for multiple estimates/event times)

        real colvector se_neyman
            estimate of 'neyman' SE

        real colvector se_adjusted
            estimate of 'adjusted' SE

        real matrix full_neyman
            estimate of 'neyman' vcov (only with return_full_vcv)

        real matrix full_adjusted
            estimate of 'adjusted' vcov (only with return_full_vcv)

        real rowvector Wald_test
            Wald statistic (column 1) and p-value (column 2)

        real colvector fisher_neyman
            simulated 'neyman' fisher p-value

        real colvector fisher_adjusted
            simulated 'adjusted' fisher p-value

        real scalar fisher_supt_pval
            simulated sup-t-statistic fisher p-value

{marker references}{...}
{title:References}

{pstd}
See the paper by {browse "https://psantanna.com/files/Roth_SantAnna_Staggered.pdf":Roth and Sant'Anna (2023)}.
