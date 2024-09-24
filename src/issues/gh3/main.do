use df

staggered y, i(i) t(t) g(g) estimand(simple)
staggered y, i(i) t(t) g(g) estimand(cohort)
staggered y, i(i) t(t) g(g) estimand(calendar)
staggered y, i(i) t(t) g(g) estimand(eventstudy) eventTime(-15/9)

tempname CI b
mata st_matrix("`CI'", st_matrix("r(table)")[5::6, .])
mata st_matrix("`b'",  st_matrix("e(b)"))
mata st_matrixcolstripe("`CI'", st_matrixrowstripe("e(thetastar)"))
mata st_matrixcolstripe("`b'",  st_matrixrowstripe("e(thetastar)"))
* matrix colnames `CI' = `:rownames e(thetastar)'
* matrix colnames `b'  = `:rownames e(thetastar)'
* so I cam straightforwardly compare
forvalues i = 1 / 7 {
    matrix `CI'[1, `i'] = 0
    matrix `CI'[2, `i'] = 0
    matrix  `b'[1, `i'] = 0
}
coefplot matrix(`b'), ci(`CI') vertical yline(0) yscale(r(-4 6))
* graph export test.pdf, replace
graph export test2.pdf, replace
