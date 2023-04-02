*! version 0.7.0 01Apr2023 Mauricio Caceres Bravo, mauricio.caceres.bravo@gmail.com
*! staggered R to Stata translation

capture program drop staggered
program staggered, eclass
    version 14.1
    if replay() {
        Replay `0'
        exit 0
    }

    local 0bak: copy local 0
    syntax varname(numeric)                 /// depvar
           [if] [in],                       /// subset, weights
           i(varname) t(varname) g(varname) ///
           estimand(str)                    /// estimand: simple, cohort, calendar, eventstudy
    [                                       ///
           vce(str)                         /// SEs to be displayed
           MATAsave(str)                    /// save resulting mata object
           eventTime(numlist)               /// event study times (default 0 with estimand eventstudy)
           num_fisher(int 0)                /// fisher permutations (if > 0)
           cs sa                            /// Callway & Sant'Anna (cs) or Sun & Abraham (sa) estimators
           beta(str)                        /// user input beta (use insntead of betastar)
           skip_data_check                  /// do not check if data balanced
           drop_treated_beforet             /// drop all cohorts treated before first time period
           use_last_treated_only            /// only use last cohort as control
           return_full_vcv                  /// return full vcov matrix (for event study estimands)
           `options'                        ///
    ]

    * ---------------------
    * Parse all the options
    * ---------------------

    if ( ("`cs'" != "") & ("`sa'" != "") ) {
        disp as err "unable to use both options -cs- and -sa-"
        exit 198
    }
    else if ( "`cs'`sa'" != "" ) {
        if "`cs'" != "" local use_last_treated_only
        if "`sa'" != "" local use_last_treated_only use_last_treated_only

        local drop_treated_beforet drop_treated_beforet
        if ( "`beta'" != "" ) {
            disp as txt "Option -`cs'`sa'- is an alias for beta(1) `drop_treated_beforet' `use_last_treated_only';"
            disp as txt "user options will be overriden by -`cs'`sa'-"
        }
        local beta 1
    }

    local estimand = trim(lower(`"`estimand'"'))
    local estimand: list uniq estimand
    local vce      = trim(lower(`"`vce'"'))

    if "`vce'" == "" local vce adjusted
    if !inlist("`vce'", "neyman", "adjusted") {
        disp as err "vce() option `vce' not known"
        exit 198
    }

    local estimands simple cohort calendar eventstudy _all
    local unknown: list estimand - estimands
    if ( `:list sizeof unknown' ) {
        disp as err `"estimand '`unknown'' not known; provide any combination of: `estimands'"'
        exit 198
    }

    if ( `:list posof "_all" in estimand' ) {
        if ( `:list sizeof estimand' > 1 ) {
            disp as txt "warning: multiple estimands requested with estimand(_all)"
        }
        local estimand simple cohort calendar eventstudy
    }
    local estimand: list estimands & estimand

    local options skip_data_check eventTime num_fisher estimand beta use_last_treated_only drop_treated_beforet return_full_vcv
    foreach opt of local options {
        local StagOpt_`opt': copy local `opt'
    }

    if "`beta'" != "" {
        cap confirm number `beta'
        if _rc {
            disp as err "option beta() must be numeric"
            exit 7
        }
    }

    cap confirm numeric variable `t' `g'
    if ( _rc ) {
        disp as err "t() and g() must be numeric (preferably integers) and in the same units"
        exit 7
    }

    * ----------------------
    * Compute the estimation
    * ----------------------

    local y: copy local varlist
    local varlist `i' `t' `g' `varlist'
    marksample touse, strok

    * Drop units with g =< min(t); for cs and sa, ATT(t,g) is not identified for these units
    if ( "`drop_treated_beforet'" != "" ) {
        qui sum `t', meanonly
        local min = r(min)
        qui count  if `g' <= `min'
        if ( `r(N)' ) {
            disp as txt "Dropping units who were treated in the first period or earlier."
            if ( "`cs'`sa'" != "" ) {
                disp as txt `"Otherwise `=upper("`cs'`sa'")' estimator is not defined (and ATT(t,g) not identified under parallel trends)."'
            }
        }
        qui replace `touse' = 0 if `g' <= `min'
    }

    local StagOpt_Caller staggered
    local Staggered StaggeredResults
    if "`matasave'" != "" local Staggered: copy local matasave
    mata `Staggered' = StaggeredNew(st_local("varlist"), st_local("touse"))
    mata `Staggered'.estimate()
    mata `Staggered'.clear()

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
    if !inlist("`vce'", "neyman", "adjusted") {
        disp as err "vce() option `vce' not known; defaulting to 'adjusted'"
    }

    FreeMatrix b V
    mata `namelist'.post("`b'", "`V'", "`vce'")
    mata st_local("N", strofreal(`namelist'.N))
    if "`repost'" == "repost" {
        ereturn repost b = `b' V = `V'
    }
    else {
        ereturn post `b' `V', esample(`touse') obs(`N')
    }
    mata `namelist'.results()
    ereturn local vcetype = proper("`vce'")
    ereturn local vce `vce'
    _coef_table_header, nomodeltest title(Staggered Treatment Effect Estimate)
    disp ""
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
            cap confirm matrix Staggered`++FreeCounter'
            c_local `FM' Staggered`FreeCounter'
        }
    }
end
