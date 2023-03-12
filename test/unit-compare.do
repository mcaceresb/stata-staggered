capture program drop stagtest_comparison
program stagtest_comparison
    qui stagtest_genbalanced 100 10
    cap matrix drop stagtest_results
    save /tmp/tmpa.dta, replace
    use /tmp/tmpa.dta, clear
    qui {
        staggered y, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(500)
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered w, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(500)
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(500) cs
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(500) sa
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
    }

    qui stagtest_genasync 1000 10
    save /tmp/tmpb.dta, replace
    use /tmp/tmpb.dta, clear
    qui {
        staggered y, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(100)
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered w, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(100)
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(100) cs
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(100) sa
        matrix stagtest_results = nullmat(stagtest_results) \ e(results)
    }

    forvalues i = 0 / 3 {
        use /tmp/tmpb.dta if mod(i, 4) == `i', clear
        qui {
            staggered y, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(100)
            matrix stagtest_results = nullmat(stagtest_results) \ e(results)
            staggered w, i(i) t(t) g(g) estimand(_all) eventTime(-3/3) num_fisher(100)
            matrix stagtest_results = nullmat(stagtest_results) \ e(results)
            staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(100) cs
            matrix stagtest_results = nullmat(stagtest_results) \ e(results)
            staggered y, i(i) t(t) g(g) estimand(simple eventstudy) eventTime(-3/3) num_fisher(100) sa
            matrix stagtest_results = nullmat(stagtest_results) \ e(results)
        }
    }

    matlist stagtest_results
    mata stagtest_savemat("/tmp/tmp.bin", st_matrix("stagtest_results"))
end

cap mata mata drop stagtest_savemat()
mata
void stagtest_savemat(string scalar fname, real matrix mat) {
    real scalar fh
    colvector C
    fh = fopen(fname, "rw")
    C  = bufio()
    fbufput(C, fh, "%4bu", cols(mat))
    fbufput(C, fh, "%4bu", rows(mat))
    fbufput(C, fh, "%8z", mat)
    fclose(fh)
}
end
