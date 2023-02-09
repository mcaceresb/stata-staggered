{smcl}
{* *! version 0.2.1 09Feb2023}{...}
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
Stata version of the Staggered R package, which implements xx.

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
xx

{synoptset 27 tabbed}{...}
{marker table_options}{...}
{synopthdr}
{synoptline}
{syntab :Options}
{synopt :{opt i(varname)}} Individual{p_end}
{synopt :{opt t(varname)}} Time{p_end}
{synopt :{opt g(varname)}} Cohort{p_end}
{synopt :{opt estimand(str)}} Estimand: simple, cohort, calendar, eventstudy (not yet coded).{p_end}
{synopt :{opt skip_data_check}} Not yet coded.{p_end}
{synopt :{opt eventTime(numlist)}}Not yet coded.{p_end}
{synopt :{opt num_fisher_permutations(int)}} Not yet coded.{p_end}
{synopt :{opt return_full_vcv}} Not yet coded.{p_end}
{synopt :{opt use_last_treated_only}} Not yet coded.{p_end}
{synopt :{opt compute_fisher}} Not yet coded.{p_end}
{synopt :{opt vce(str)}} Either 'conservative' or 'adjusted' (default){p_end}

{p2colreset}{...}
{p 4 6 2}

{marker description}{...}
{title:Description}

{pstd}
See the {browse "https://github.com/mcaceresb/stata-staggered#readme":online examples} for details or refer to the examples below.

{marker example}{...}
{title:Example 1: xx}

{pstd}
xx

{title:Example 2: xx}

{pstd}
xx

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:staggered} stores the following in {cmd:e()}:

{synoptset 23 tabbed}{...}
{p2col 5 23 26 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}

{p2col 5 23 26 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:staggered}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(depvar)}}name of dependent variable{p_end}
{synopt:{cmd:e(individual)}}name of variable identifying individuals{p_end}
{synopt:{cmd:e(time)}}name of variable identifying the time period{p_end}
{synopt:{cmd:e(cohort)}}name of variable identifying cohort (when treated){p_end}
{synopt:{cmd:e(vce)}}variance computed (conservative, adjusted){p_end}
{synopt:{cmd:e(vcetype)}}same as vce but capitalized{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}
{synopt:{cmd:e(mata)}}name of mata object where results are stored (see below){p_end}

{p2col 5 23 26 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient of interest (theta){p_end}
{synopt:{cmd:e(V)}}variance of theta{p_end}

{p2col 5 23 26 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks estimation sample{p_end}
{p2colreset}{...}

{marker mata}{...}
{pstd}
The following data are available in {cmd:e(mata)} (default name: StaggeredResults):

        real scalar N
            number of observations used in estimation

        real scalar Nt
            number of time periods

        real scalar Ng
            number of cohorts

        real scalar preperiods
            number of pre-periods (i.e. before first cohort treated)

        real scalar thetastar
            estimated coefficient of interest

        real scalar betastar
            estimated \beta^*

        real scalar Xhat
            estimate of \hat{X}

        real scalar V_X
            estimate of V_{\hat{X}} (variance of \hat{X})

        real scalar V_thetaX
            covariance of \hat{X} and \hat{\theta} (estimate of V_{\hat{\theta}, \hat{X}})

        real scalar V_theta
            estimate of V_{\hat{\theta}} (variance of \hat{\theta})

        real matrix A_theta
            auxiliary matrix with rows containing A_{theta, g}

        real matrix A_0
            auxiliary matrix with rows containing A_{0, g}

        real scalar se_conservative 
            estimate of 'conservative' SE

        real scalar se_adjusted     
            estimate of 'adjusted' SE

{marker references}{...}
{title:References}

{pstd}
See the paper by {browse "https://arxiv.org/pdf/2102.01291.pdf":Roth and Sant’Anna (2021)}.
