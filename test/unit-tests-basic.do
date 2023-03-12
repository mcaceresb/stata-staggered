capture program drop basic_checks
program basic_checks
    syntax [if] [in], [*]
    foreach est in simple cohort calendar eventstudy _all {
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est')
        staggered, vce(neyman)
        staggered, vce(adjusted)
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est') cs
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est') sa
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est') beta(-1.234)
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est') beta(9.876)
        staggered y `if' `in', i(i) t(t) g(g) estimand(`est') drop_treated_beforet use_last_treated_only
        if inlist("`est'", "eventstudy", "_all") {
            staggered y `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(2/4)
            staggered y `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(-2)
            staggered w `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(0/4)   num_fisher(100)
            staggered w `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(-3/-1) num_fisher(100)
            staggered y `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(-2 2)
            staggered w `if' `in', i(i) t(t) g(g) estimand(`est') eventTime(-3/4)  num_fisher(100)
        }
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') num_fisher(100)
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') cs num_fisher(100)
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') sa num_fisher(100)
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') beta(-1.234) num_fisher(100)
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') beta(9.876)  num_fisher(100)
        staggered w `if' `in', i(i) t(t) g(g) estimand(`est') drop_treated_beforet use_last_treated_only num_fisher(100)
    }
end

capture program drop basic_failures
program basic_failures
    syntax, [*]

    clear
    set obs 10
    gen i = _n
    expand 3
    bys i: gen t = _n
    gen g = 2
    expand 2
    gen y = runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 459

    clear
    set obs 10
    gen i = _n
    expand 3
    bys i: gen t = _n
    gen g = i
    gen y = runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 2000

    clear
    set obs 10
    gen i = _n
    bys i: gen t = _n
    gen g = i
    gen y = runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 2000

    clear
    set obs 10
    gen i = _n
    expand 5
    bys i: gen t = _n * 2
    gen g = 5
    gen y = (t >= g) + runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 2000

    clear
    set obs 100
    gen i = _n
    expand 5
    bys i: gen t = _n
    gen g = mod(_n, 2) + 3
    gen y = (t >= g) + runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 198

    clear
    set obs 10
    gen i = _n
    expand 5
    bys i: gen t = _n
    gen g = 3 + mod(i, 2)
    replace i = 1 if i == 10
    gen y = (t >= g) + runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 198

    clear
    set obs 10
    gen i = _n
    expand 5
    bys i: gen t = _n
    gen g = 3 + mod(i, 2)
    replace i = 1 if i == 9
    gen y = (t >= g) + runiform()
    cap staggered y, i(i) t(t) g(g) estimand(simple)
    assert _rc == 459
end
