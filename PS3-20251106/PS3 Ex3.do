* Microeconometria 2 
* UTDT

* Problem set 3 - Ej. 3
* DiD


* Ejercicio: Card & Krueger (1994)


* Abrimos la base 
use "http://fmwww.bc.edu/repec/bocode/c/CardKrueger1994.dta", clear

* Descripcion 
describe
summarize

 
bysort treated: summarize
bysort treated t: summarize fte



* DiD sin variables de control
diff fte, t(treated) p(t)

* Bootstrapped std. err.:
diff fte, t(treated) p(t) bs rep(50)

* DiD con variables de control (covariates)
diff fte, t(treated) p(t) cov(bk kfc roys)
diff fte, t(treated) p(t) cov(bk kfc roys) report
diff fte, t(treated) p(t) cov(bk kfc roys) report bs

* DDD (bk como segundo tratamiento).
diff fte, t(treated) p(t) ddd(bk)

/*
gen T = treated
gen R = bk
gen I = t
gen TR = T*R
gen TI = T*I
gen RI = R*I
gen TRI = T*R*I

reg T R I TR TI RI TRI
xtreg T R I TR TI RI TRI,fe
*/

didregress (fte)(treated), group(t) 


** a mano 

use "http://fmwww.bc.edu/repec/bocode/c/CardKrueger1994.dta", clear

gen did = treated*t

reg fte t treated did
reg fte t treated did bk kfc roys

xtset id t 

* nos da error! hay una tienda que aparece en NJ y PA a la vez, probable error

duplicates list id t

replace id = 408 in 666
replace id = 408 in 668


xtset id t

xtreg fte t treated did, fe 


diff fte, t(treated) p(t) cov(bk kfc roys) report

reg fte t treated did bk kfc roys

xtreg fte t treated did bk kfc roys , fe robust