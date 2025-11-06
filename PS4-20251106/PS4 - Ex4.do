* Microeconometria 2
* PS4 - Ex 4

*ssc install drdid
*ssc install csdid
*ssc install hdfe

cd "C:\Users\maior\OneDrive\2016\Documentos\2022\MAECO - MICROECONOMETRIA II 2023\Microeconometria II - Practicas 2023 - PS 4"

** Abrimos y describimos la base
use mpdta.dta, clear

describe
summarize


codebook year countyreal

** Comando jwdid 

** Sin X 

*** never-treated observations as controls
jwdid  lemp , ivar(countyreal) tvar(year) gvar(first_treat) group never
eststo jwdid1
estat simple
estat group 
estat calendar 
estat event


*** individual fixed effect, year fixed effect and cohort variable 
jwdid  lemp , ivar(countyreal) tvar(year) gvar(first_treat)
eststo jwdid2
estat simple
estat group 
estat calendar 
estat event


** con X

*** never-treated observations as controls
jwdid  lemp lpop, ivar(countyreal) tvar(year) gvar(first_treat) group never
eststo jwdid3
estat simple
estat group 
estat calendar 
estat event

*** individual fixed effect, year fixed effect and cohort variable 
jwdid  lemp lpop, ivar(countyreal) tvar(year) gvar(first_treat) group
eststo jwdid4
estat simple
estat group 
estat calendar 
estat event


esttab jwdid1 jwdid2 jwdid3 jwdid4 using jwdidoutput.csv, b(%9.6f) replace
esttab jwdid1 jwdid2 jwdid3 jwdid4, se b(%9.6f) replace /// 
		mtitles("Never" "Never - X" "Not yet" "Not yet - X" )





** A mano 
** Quiero replicar el comando jwdid: DID a la Wooldridge

*** Genero dummies
***** d_q, ..., d_T = cohort dummies (T-q+2 en total)
tab first_treat, generate(d)

rename d4 d5
rename d3 d4

***** (fs)_t = I(s=t)
tab year, generate(f)

***** Interacciones d*fs
gen int22 = d2*f2 
gen int23 = d2*f3 
gen int24 = d2*f4
gen int25 = d2*f5

gen int44 = d4*f4
gen int45 = d4*f5

gen int55 = d5*f5


** Regresion 

reg lemp d2 d4 d5 f2 f3 f4 f5 int* //replica jwdid1 y jwdid2! 
eststo replic1 

xtset countyreal year
xtreg lemp d2 d4 d5 f2 f3 f4 f5 int*, fe
eststo replic2

reghdfe lemp int* i.year, absorb(countyreal)
eststo replic3 

esttab replic1 replic2 replic3

