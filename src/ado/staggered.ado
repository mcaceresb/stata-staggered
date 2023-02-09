*! version 0.2.1 09Feb2023 Mauricio Caceres Bravo, mauricio.caceres.bravo@gmail.com
*! staggered R to Stata translation

capture program drop staggered
program staggered, eclass
    version 14.1
    if replay() {
        Replay `0'
        exit 0
    }

    local options skip_data_check         /// xx not yet coded
                  return_full_vcv         /// xx not yet coded
                  use_last_treated_only   /// xx not yet coded
                  compute_fisher          /// xx not yet coded

    local 0bak: copy local 0
    syntax varname(numeric)                 /// depvar
           [if] [in],                       /// subset, weights
           i(varname) t(varname) g(varname) ///
           estimand(str)                    /// estimand: simple, xx
    [                                       ///
           vce(str)                         /// SEs to be displayed
           MATAsave(str)                    /// save resulting mata object
           eventTime(numlist)               /// xx not yet coded
           num_fisher_permutations(int 500) /// xx not yet coded
           `options'                        ///
    ]

    local estimand = trim(lower(`"`estimand'"'))
    local vce      = trim(lower(`"`vce'"'))

    if "`vce'" == "" local vce adjusted
    if !inlist("`vce'", "conservative", "adjusted") {
        disp as err "vce() option `vce' not known"
        exit 198
    }

    if !inlist("`estimand'", "simple", "cohort", "calendar", "eventstudy") {
        disp as err "estimand() option `estimand' not known"
        exit 198
    }

    if inlist("`estimand'", "eventstudy") {
        disp as err "estimand 'eventstudy' not yet implemented; xx rawwwr"
    }

    foreach opt of local options {
        if "``opt''" != "" disp as err "warning: option `opt' not yet implemented; xx rawwwr"
    }

    local options `options' eventTime num_fisher_permutations estimand
    foreach opt of local options {
        local StagOpt_`opt': copy local `opt'
    }

    local y: copy local varlist
    local varlist `i' `t' `g' `varlist'
    marksample touse, strok

    local StagOpt_Caller staggered
    local Staggered StaggeredResults
    if "`matasave'" != "" local Staggered: copy local matasave
    mata `Staggered' = StaggeredNew(st_local("varlist"), st_local("touse"))
    mata `Staggered'.estimate()
    mata `Staggered'.clear()

    * TODO: xx make results table
    Display `Staggered', vce(`vce') touse(`touse')
    mata st_local("cmdline", "staggered " + st_local("0bak"))
    ereturn local cmdline: copy local cmdline
    ereturn local cmd        = "staggered"
    ereturn local depvar     = "`y'"
    ereturn local individual = "`i'"
    ereturn local time       = "`t'"
    ereturn local cohort     = "`g'"
    ereturn local mata       = "`Staggered'"
end

capture program drop Replay
program Replay, eclass
    syntax, [*]
    if (`"`e(cmd)'"' != "staggered") error 301
    Display `e(mata)', repost `options'
end

capture program drop Display
program Display, eclass
    syntax namelist(max = 1), [vce(str) touse(str) repost *]

    local vce = trim(lower(`"`vce'"'))
    if "`vce'" == "" local vce adjusted
    if !inlist("`vce'", "conservative", "adjusted") {
        disp as err "vce() option `vce' not known; defaulting to 'adjusted'"
    }

    mata printf("\nStaggered Treatment Effect Estimate\n")
    FreeMatrix b V
    mata `namelist'.post("`b'", "`V'", "`vce'")
    mata st_local("N", strofreal(`namelist'.N))
    if "`repost'" == "repost" {
        ereturn repost b = `b' V = `V'
    }
    else {
        ereturn post `b' `V', esample(`touse') obs(`N')
    }
    ereturn local vcetype = proper("`vce'")
    ereturn local vce `vce'
    _coef_table, noempty `options'
    //     level(95)
    //     bmatrix(`b')      // e(b)
    //     vmatrix(`V')      // e(V)
    //     dfmatrix(matname) // e(mi_df)
    //     ptitle(title)
    //     coeftitle(title)
    //     cititle(title)
    //     cformat(format)
    //     pformat(format)
    //     sformat(format)
end

capture program drop FreeMatrix
program FreeMatrix
    local FreeCounter 0
    local FreeMatrix
    foreach FM of local 0 {
        cap error 0
        while ( _rc == 0 ) {
            cap confirm matrix MulTE`++FreeCounter'
            c_local `FM' MulTE`FreeCounter'
        }
    }
end
