cap noi ado uninstall staggered
cap noi net uninstall staggered
mata: mata clear
mata: mata set matastrict on
mata: mata set mataoptimize on
cap mkdir src
cap mkdir src/build
cap noi erase src/build/lstaggered.mlib
qui {
    do src/mata/staggered.mata
}
mata: mata mlib create lstaggered, dir("src/build") replace
mata: mata mlib add lstaggered Staggered*(), dir("src/build") complete
net install staggered, from(`c(pwd)') replace
