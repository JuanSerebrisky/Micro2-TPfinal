* Microeconometria 2
* PS4 - Ex 3

*ssc install drdid
*ssc install csdid

cd "C:\Users\maior\OneDrive\2016\Documentos\2022\MAECO - MICROECONOMETRIA II 2023\Microeconometria II - Practicas 2023 - PS 4"

** Abrimos y describimos la base
use mpdta.dta, clear

describe
summarize


** Estimamos por Callaway & Sant'Anna
** Sintaxis: csdid resultado explicativas, ivar(id corte transveral) gvar(variable de grupos tratados) method(metodo a eleccion)
csdid lemp, ivar(countyreal) time(year) gvar(first_treat) method(dripw)
eststo csdid1 
** Tendencias previas y graficos
estat pretrend

*csdid_plot, group(2004)
*csdid_plot, group(2006)
*csdid_plot, group(2007)


** Efectos agregados

*** Efecto agregado simple
estat simple 


*** Efecto ``estudio de evento'': efecto promedio del tratamiento en s periodos tras el otorgamiento
estat event
*csdid_plot


*** Efecto promedio por grupo de tratados
estat group 
*csdid_plot


*** Efecto promedio por cada periodo (aca: efecto en cada valor de year)
estat calendar
*csdid_plot




* Replicamos con una explicativa:


csdid lemp lpop, ivar(countyreal) time(year) gvar(first_treat) method(dripw)
eststo csdid2

** Tendencias previas y graficos
estat pretrend

*csdid_plot, group(2004)
*csdid_plot, group(2006)
*csdid_plot, group(2007)


** Efectos agregados

*** Efecto agregado simple
estat simple 


*** Efecto ``estudio de evento'': efecto promedio del tratamiento en s periodos tras el otorgamiento
estat event
*csdid_plot


*** Efecto promedio por grupo de tratados
estat group 
*csdid_plot


*** Efecto promedio por cada periodo (aca: efecto en cada valor de year)
estat calendar
*csdid_plot




* Replicamos con no tratados todavía (not yet treated):


csdid lemp, ivar(countyreal) time(year) gvar(first_treat) method(dripw) notyet 
eststo csdid3

** Tendencias previas y graficos
estat pretrend

*csdid_plot, group(2004)
*csdid_plot, group(2006)
*csdid_plot, group(2007)


** Efectos agregados

*** Efecto agregado simple
estat simple 


*** Efecto ``estudio de evento'': efecto promedio del tratamiento en s periodos tras el otorgamiento
estat event
*csdid_plot


*** Efecto promedio por grupo de tratados
estat group 
*csdid_plot


*** Efecto promedio por cada periodo (aca: efecto en cada valor de year)
estat calendar
*csdid_plot



csdid lemp lpop, ivar(countyreal) time(year) gvar(first_treat) method(dripw) notyet 
eststo csdid4

** Tendencias previas y graficos
estat pretrend

*csdid_plot, group(2004)
*csdid_plot, group(2006)
*csdid_plot, group(2007)


** Efectos agregados

*** Efecto agregado simple
estat simple 


*** Efecto ``estudio de evento'': efecto promedio del tratamiento en s periodos tras el otorgamiento
estat event
*csdid_plot


*** Efecto promedio por grupo de tratados
estat group 
*csdid_plot


*** Efecto promedio por cada periodo (aca: efecto en cada valor de year)
estat calendar
*csdid_plot



** TWFE 


*** Static
gen D = (first_treat <= year) & (treat == 1)

reghdfe lemp D, absorb(countyreal year) vce(cluster countyreal)
eststo twfe1 



*** Dynamic 

* Para Dynamic TWFE: Dummies for time relative to treatment

* k periodos post tratamiento
forvalues k = 1/3{
	gen Tp`k' = (year - first_treat == `k') if treat==1
	replace Tp`k' = 0 if Tp`k'==.
}

* Periodo del tratamiento
gen Tp0 = (year - first_treat==0) if treat==1
replace Tp0=0 if Tp0==.

* k periodos pre tratamiento 
forvalues k = 1/4{
	gen Tm`k' = (year - first_treat == -`k') if treat==1
	replace Tm`k'=0 if Tm`k'==.
}

order Tm4 Tm3 Tm2 Tm1 Tp0 Tp1 Tp2 Tp3, last


reghdfe lemp Tm4 Tm3 Tm2 Tm1 Tp1 Tp2 Tp3, absorb(countyreal year) vce(cluster countyreal)
eststo twfe2 


* Comparamos todos los resultados

esttab csdid1 csdid2 csdid3 csdid4, se  /// 
		mtitles("Never" "Never - X" "Not yet" "Not yet - X" )

		