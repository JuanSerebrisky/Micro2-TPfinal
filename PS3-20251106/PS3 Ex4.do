* Microeconometria 2 
* UTDT

* Problem set 3 - Ej. 4
* DiD

clear all
set more off

*Cargamos el dataset*
use "C:\Users\maior\OneDrive\2016\Documentos\2022\MAECO - MICROECONOMETRIA II 2023\Microeconometria II - Practicas 2023 - PS 3/hospdd.dta"

*Veamos como se estructura*
sum
des
br
tab procedure
tab month procedure
tab hospital procedure

* Acá se ve claro que estamos comparando una selección de 18 hospitales que tuvieron visitas bajo la nueva procedure.

* Notar que es un cross-section repetido, no un panel.

* Genero una dummy de tratamiento
bysort hospital: egen treated = max(procedure)

* Podriamos agregar & !missing(procedure)

* Genero una dummy de tiempo (antes/despues del tratamiento)
gen post = month>3 & !missing(procedure)
tab treated
tab proc treated
didregress (satis i.treated i.post)(procedure), group(hospital) time(month)

