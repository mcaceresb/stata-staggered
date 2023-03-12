version 14.1
set seed 1729
qui do test/unit-tests-basic.do
qui do test/unit-compare.do

capture program drop main
program main
    qui stagtest_genbalanced 100 10
    unit_test: basic_checks

    qui stagtest_genasync 1000 10
    unit_test: basic_checks
    forvalues i = 0/3 {
        unit_test: basic_checks if mod(i, 4) == `i'
    }

    unit_test: stagtest_comparison
    unit_test: basic_failures
end

capture program drop stagtest_genbalanced
program stagtest_genbalanced
    args ni nt offset
    if "`offset'" == "" local offset = 123
    clear
    set obs `nt'
    gen t = _n + `offset'
    expand `ni'
    bys t: gen i = _n
    gen g = `offset' + runiform() * `nt'
    sort i t, stable
    by i (t): replace g = ceil(g[_N])
    gen y = (t >= g) + rnormal() * 3
    gen w = (t <= g) + rnormal() * 3
end

capture program drop stagtest_genasync
program stagtest_genasync
    args ni nt offset
    if "`offset'" == "" local offset = 123
    clear
    set obs `ni'
    gen i = _n
    gen Nt = `nt' + ceil(runiform() * `nt')
    expand Nt
    bys i: gen t = _n + `offset'
    gen g = .
    replace g = `offset' + runiform() * Nt / 2 + Nt/3 if mod(i, 4) == 0
    replace g = `offset' + runiform() * Nt * 2 - Nt/2 if mod(i, 4) == 1
    replace g = `offset' + runiform() * Nt     + Nt/2 if mod(i, 4) == 2
    replace g = `offset' + runiform() * Nt     - Nt/2 if mod(i, 4) == 3
    sort i t, stable
    by i (t): replace g = ceil(g[_N])
    * tab t g if mod(i, 4) == 0
    * tab t g if mod(i, 4) == 1
    * tab t g if mod(i, 4) == 2
    * tab t g if mod(i, 4) == 3
    gen y = (t >= g) + rnormal() * 3
    gen w = (t <= g) + rnormal() * 3
end

capture program drop unit_test
program unit_test
    _on_colon_parse `0'
    local 0 `r(before)'
    local cmd `s(after)'
    syntax, [NOIsily tab(int 4) *]
    cap `noisily' `cmd'
    if ( _rc ) {
        di as error _col(`=`tab'+1') `"test(failed): `cmd'"'
        exit _rc
    }
    else di as txt _col(`=`tab'+1') `"test(passed): `cmd'"'
end

main
