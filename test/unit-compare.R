# Run 
#
#     stata14-mp -b do test/unit-tests.do && mv unit-tests.log test/unit-tests.do.log
#     Rscript --no-save --no-restore --verbose test/unit-compare.R > test/unit-compare.R.log 2>&1
#
# remove.packages("staggered")
# install.packages(".", repos=NULL, type="source")

library(haven)
library(staggered)
sel <- c("estimate", "se", "se_neyman")
df <- read_dta('/tmp/tmpa.dta')
    resa <- rbind(
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "cohort")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "calendar")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "simple")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "cohort")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "calendar")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel]
    )
df <- read_dta('/tmp/tmpb.dta')
    resb <- rbind(
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "cohort")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "calendar")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "simple")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "cohort")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "calendar")[,sel],
        staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
        staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
        staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel]
    )

for (m in 0:3) {
    df <- subset(read_dta('/tmp/tmpb.dta'), i %% 4 == m)
        resb <- rbind(
            resb,
            staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "cohort")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "calendar")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "simple")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "cohort")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "calendar")[,sel],
            staggered(df = df, i = "i", t = "t", g = "g", y = "w", estimand = "eventstudy", eventTime=-3:3)[,sel],
            staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
            staggered_cs(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel],
            staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "simple")[,sel],
            staggered_sa(df = df, i = "i", t = "t", g = "g", y = "y", estimand = "eventstudy", eventTime=-3:3)[,sel]
        )
}

.roundeps <- function(x, eps = .Machine$double.eps^(3/4)) {
    x[abs(x[,1]) < eps,] = 0
    return(x)
}

.loadmat <- function(inf) {
    con <- file(inf, 'rb')
    on.exit(close(con))
    nc <- readBin(con, "int", size=4)
    nr <- readBin(con, "int", size=4)
    mat <- matrix(readBin(con, "numeric", nr * nc), ncol=nc, nrow=nr, byrow=TRUE)
    flush(con)
    return(mat)
}
M <- as.matrix(.roundeps(rbind(resa, resb)) / .roundeps(.loadmat("/tmp/tmp.bin")))
cbind(.roundeps(rbind(resa, resb)), .roundeps(.loadmat("/tmp/tmp.bin")))
M
all(na.omit(((c(M)-1) < 1e-12) | (abs(c(M)) == Inf)))
