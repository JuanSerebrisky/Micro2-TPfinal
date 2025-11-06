* Microeconometria 2
* PS4 - Ex 2

causaldata organ_donations.dta, use clear download

* Describo 
des
summ 

* Genero variable de id numerica porque sino no puedo usar xtset
egen stateid = group(state)

* El tratamiento es otorgado solo en California 
gen California = (state == "California")


* ===== Efectos dinamicos =============================

* Regresion de TWFE 
reghdfe rate California##ib3.quarter_num, ///
    absorb(state quarter_num) vce(cluster state)

* There's a way to graph this in one line using coefplot
* But it gets stubborn and tricky, so we'll just do it by hand
* Pull out the coefficients and SEs
g coef = .
g se = .
forvalues i = 1(1)6 {
    replace coef = _b[1.California#`i'.quarter_num] if quarter_num == `i'
    replace se = _se[1.California#`i'.quarter_num] if quarter_num == `i'
}

* Make confidence intervals
g ci_top = coef+1.96*se
g ci_bottom = coef - 1.96*se

* Limit ourselves to one observation per quarter
keep quarter_num coef se ci_*
duplicates drop

* Create connected scatterplot of coefficients
* with CIs included with rcap 
* and a line at 0 from function
twoway (sc coef quarter_num, connect(line)) ///
  (rcap ci_top ci_bottom quarter_num) ///
    (function y = 0, range(1 6)), xtitle("Quarter") ///
    caption("95% Confidence Intervals Shown")


* ===== Parte 2: Test de Placebo =============================
causaldata organ_donations.dta, use clear download

* Use only pre-treatment data
keep if quarter_num <= 3

* Create fake treatment variables
g FakeTreat1 = state == "California" & inlist(quarter, "Q12011","Q22011")
g FakeTreat2 = state == "California" & quarter == "Q22011"

* Run the same model as before
* But with our fake treatment
reghdfe rate FakeTreat1, a(state quarter) vce(cluster state)
reghdfe rate FakeTreat2, a(state quarter) vce(cluster state)

 
 
 
 


