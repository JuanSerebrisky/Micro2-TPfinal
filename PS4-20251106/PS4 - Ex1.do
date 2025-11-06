* Microeconometria 2
* PS4 - Ex 1

*ssc install causaldata
*ssc install reghdfe

causaldata organ_donations.dta, use clear download

des
sum

*egen stateid = group(state)

xtset stateid quarter_num

tab state
tab quarter_num 

* Create treatment variable
gen Treated = (state == "California")  
gen Post = inlist(quarter, "Q32011","Q42011","Q12012")
gen D = Treated*Post

* Evaluemos esto
tab D 
tab state D
tab quarter_num D 

  
* TWFE (nuevo comando para regresion con muchos efectos fijos)
* Cpm reghdfe no hace falta setear xtset 
reghdfe rate D, absorb(state quarter) vce(cluster state)

* Si lo hicieramos con xtreg
xtset stateid quarter_num
xtreg rate i.quarter_num D, fe 




