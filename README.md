Staggered
=========

`version 0.8.0 02Feb2025` | [Background](#background) | [Installation](#installation) | [Examples](#examples)

## Background

The staggered package computes the efficient estimator for settings
with randomized treatment timing, based on the theoretical results in
[Roth and Sant'Anna (2023)](https://psantanna.com/files/Roth_SantAnna_Staggered.pdf). If
units are randomly (or quasi-randomly) assigned to begin treatment at
different dates, the efficient estimator can potentially offer
substantial gains over methods that only impose parallel trends. The
package also allows for calculating the generalized
difference-in-differences estimators of [Callaway and Sant'Anna
(2020)](https://psantanna.com/files/Roth_SantAnna_Staggered.pdf)
and [Sun and Abraham
(2020)](https://www.sciencedirect.com/science/article/abs/pii/S030440762030378X)
and the simple-difference-in-means as special cases. This is the Stata
version of the [R package of the same name](https://github.com/jonathandroth/staggered)

## Installation

The package may be installed by using `net install`:

```stata
local github https://raw.githubusercontent.com
net install staggered, from(`github'/mcaceresb/stata-staggered/main) replace
```

You can also clone or download the code manually, e.g. to
`stata-staggered-main`, and install from a local folder:

```stata
cap noi net uninstall staggered
net install staggered, from(`c(pwd)'/stata-staggered-main)
```

## Examples

We now illustrate how to use the package by re-creating some of the
results in the application section of [Roth and Sant'Anna
(2023)](https://psantanna.com/files/Roth_SantAnna_Staggered.pdf). Our data contains a
balanced panel of police officers in Chicago who were randomly given a
procedural justice training on different dates.

### Loading the package and the data

```stata
* load the officer data
use https://github.com/mcaceresb/stata-staggered/raw/main/test/pj_officer_level_balanced.dta, clear
```

### Simple aggregate parameters

We now can call the function `staggered` to
calculate the efficient estimator. With staggered treatment timing,
there are several ways to aggregate treatment effects across cohorts and
time periods. The following block of code calculates the simple,
calendar-weighted, and cohort-weighted average treatment effects (see
Section 2.3 of [Roth and Sant'Anna
(2023)](https://psantanna.com/files/Roth_SantAnna_Staggered.pdf) for more about different
aggregation schemes).

```stata
* Calculate efficient estimator for the simple weighted average
staggered complaints, i(uid) t(period) g(first_trained) estimand(simple)

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |   -.001127   .0021152    -0.53   0.594    -.0052727    .0030187
* -------------------------------------------------------------------------------
```

```stata
* Calculate efficient estimator for the cohort weighted average
staggered complaints, i(uid) t(period) g(first_trained) estimand(cohort)

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |  -.0010847    .002261    -0.48   0.631    -.0055162    .0033468
* -------------------------------------------------------------------------------
```

```stata
* Calculate efficient estimator for the calendar weighted average
staggered complaints, i(uid) t(period) g(first_trained) estimand(calendar)

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |   -.001872   .0025586    -0.73   0.464    -.0068868    .0031428
* -------------------------------------------------------------------------------
```

### Event-study Parameters

We can also calculate an \`\`event-study’’ that computes the
average-treatment effect at each lag since treatment.

```stata
* Calculate event-study coefficients for the first 24 months (month 0 is
* instantaneous effect)
staggered complaints, i(uid) t(period) g(first_trained) estimand(eventstudy) eventTime(0/23)

* Staggered Treatment Effect Estimate
* (warning: e(V) is a diagonal matrix of SEs, not a full vcov matrix)
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |
*            0  |   .0003084   .0026453     0.12   0.907    -.0048764    .0054931
*            1  |   .0025917   .0026146     0.99   0.322    -.0025328    .0077161
*            2  |  -.0000487   .0026226    -0.02   0.985     -.005189    .0050916
*            3  |   .0020434   .0027157     0.75   0.452    -.0032792    .0073661
*            4  |   .0029771   .0026539     1.12   0.262    -.0022245    .0081787
*            5  |    .000798   .0027218     0.29   0.769    -.0045366    .0061326
*            6  |  -.0011258     .00267    -0.42   0.673    -.0063589    .0041073
*            7  |  -.0009272   .0025673    -0.36   0.718     -.005959    .0041045
*            8  |   .0017472   .0028273     0.62   0.537    -.0037943    .0072887
*            9  |    .001914   .0027965     0.68   0.494    -.0035671    .0073951
*           10  |  -.0007877   .0028429    -0.28   0.782    -.0063596    .0047842
*           11  |   .0034772   .0028943     1.20   0.230    -.0021956      .00915
*           12  |   .0007197   .0028958     0.25   0.804    -.0049558    .0063953
*           13  |   .0056697   .0030634     1.85   0.064    -.0003344    .0116738
*           14  |  -.0039899   .0029068    -1.37   0.170    -.0096871    .0017073
*           15  |  -.0045102   .0029322    -1.54   0.124    -.0102572    .0012368
*           16  |  -.0032093   .0029698    -1.08   0.280    -.0090299    .0026113
*           17  |    .001199   .0034736     0.35   0.730    -.0056091    .0080071
*           18  |  -.0052488   .0032339    -1.62   0.105    -.0115871    .0010896
*           19  |  -.0066283   .0031432    -2.11   0.035    -.0127888   -.0004678
*           20  |   -.001109   .0034117    -0.33   0.745    -.0077959    .0055778
*           21  |  -.0043286   .0034154    -1.27   0.205    -.0110227    .0023654
*           22  |  -.0032829   .0037605    -0.87   0.383    -.0106533    .0040876
*           23  |  -.0014868   .0035378    -0.42   0.674    -.0084208    .0054471
* -------------------------------------------------------------------------------
```

```stata
* Create event-study plot from the results of the event-study

* ssc install coefplot
tempname CI b
mata st_matrix("`CI'", st_matrix("r(table)")[5::6, .])
mata st_matrix("`b'",  st_matrix("e(b)"))
matrix colnames `CI' = `:rownames e(thetastar)'
matrix colnames `b'  = `:rownames e(thetastar)'
coefplot matrix(`b'), ci(`CI') vertical yline(0)
* graph export test/StaggeredEventStudy.png, replace
```

<img src="test/StaggeredEventStudy.png" width="100%" />

### Permutation tests

The staggered package also allows you to calculate p-values using
permutation tests, also known as Fisher Randomization Tests. These tests
are based on a studentized statistic, and thus are finite-sample exact
for the null of no treatment effects *and* asymptotically correct for
the null of no average treatment effects.

```stata
* Calculate efficient estimator for the simple weighted average
* Use Fisher permutation test with 500 permutation draws
staggered complaints, i(uid) t(period) g(first_trained) estimand(simple) num_fisher(500)

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*    complaints |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |   -.001127   .0021152    -0.53   0.594    -.0052727    .0030187
* -------------------------------------------------------------------------------

* All results are also saved in a matrix called e(results)
matlist e(results)

*              | first_t~d  se_adju~d  se_neyman  fisher_~n  fisher_~d 
* -------------+-------------------------------------------------------
*   complaints |  -.001127   .0021152   .0021192        .61        .61 
```

### Multiple Estimands

Any combination of the aforementioned estimands and tests can be requested. For instance,

```stata
staggered complaints, i(uid) t(period) g(first_trained) estimand(eventstudy simple) eventTime(0/4) num_fisher(500)

* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* simple        |
* first_trained |   -.001127   .0021152    -0.53   0.594    -.0052727    .0030187
* --------------+----------------------------------------------------------------
* eventstudy    |
* first_trained |
*            0  |   .0003084   .0026453     0.12   0.907    -.0048764    .0054931
*            1  |   .0025917   .0026146     0.99   0.322    -.0025328    .0077161
*            2  |  -.0000487   .0026226    -0.02   0.985     -.005189    .0050916
*            3  |   .0020434   .0027157     0.75   0.452    -.0032792    .0073661
*            4  |   .0029771   .0026539     1.12   0.262    -.0022245    .0081787
* -------------------------------------------------------------------------------

matlist e(results)

*              | first_t~d  se_adju~d  se_neyman  fisher_~n  fisher_~d 
* -------------+-------------------------------------------------------
* simple       |                                                       
* first_trai~d |  -.001127   .0021152   .0021192        .61        .61 
* -------------+-------------------------------------------------------
* eventstudy   |                                                       
* 0.first_tr~d |  .0003084   .0026453    .002651       .924       .924 
* 1.first_tr~d |  .0025917   .0026146   .0026215       .358       .354 
* 2.first_tr~d | -.0000487   .0026226   .0026236       .984       .984 
* 3.first_tr~d |  .0020434   .0027157   .0027205       .432       .432 
* 4.first_tr~d |  .0029771   .0026539   .0026596        .25        .25 
```

### Other Estimators

Our package also allows for the calculation of several other estimators
proposed in the literature. For convenience we provide special functions
for implementing the estimators proposed by Callaway & Sant'Anna and Sun
& Abraham. The syntax is nearly identical to that for the efficient
estimator:

```stata
* Calculate Callaway and Sant'Anna estimator for the simple weighted average
staggered complaints, i(uid) t(period) g(first_trained) estimand(simple) cs

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |  -.0051768   .0039287    -1.32   0.188     -.012877    .0025234
* -------------------------------------------------------------------------------
```

```stata
* Calculate Sun and Abraham estimator for the simple weighted average
staggered complaints, i(uid) t(period) g(first_trained) estimand(simple) sa

* Staggered Treatment Effect Estimate
* -------------------------------------------------------------------------------
*               |              Adjusted
*               |      Coef.   Std. Err.      z    P>|z|     [95% Conf. Interval]
* --------------+----------------------------------------------------------------
* first_trained |   .0115385   .0173016     0.67   0.505     -.022372     .045449
* -------------------------------------------------------------------------------
```

The Callaway and Sant'Anna estimator corresponds with calling the
staggered function with option `beta(1)`, and the
Sun and Abraham estimator corresponds with calling staggered with option `beta(1)`
and `use_last_treated_only`. If one is interested in the simple
difference-in-means, one can call the staggered function with option
`beta(0)`.

Note that the standard errors returned in the se column are based on the
design-based approach in Roth & Sant'Anna, and thus will differ somewhat
from those returned by the did package. The standard errors in
`se_neyman` should be very similar to those returned by the did package,
although not identical in finite samples.
