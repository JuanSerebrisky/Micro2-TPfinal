/**********************/

**** Directorio y abrimos la base

cd "C:\Users\maior\OneDrive\2016\Documentos\2022\MAECO - MICROECONOMETRIA II 2023\Microeconometria II - Practicas 2023 - PS 3"

clear all

set more off

use Panel101.dta

gen Y = y/1000000000

describe
summarize

**** Generamos variable dummmy cuando el tratamiento comienza. Asumimos comienza en 1994
gen time = (year>=1994) & !missing(year) 

**** Generamos variable del grupo de tratados. Asumimos que pa|ises 1-4 no fueron tratados y 5-7 si
gen treated = (country>4) & !missing(country)

**** Creamos la interaccion entre ambos
gen did = time*treated	

**** Le indicamos a stata que trabajamos con un panel
**# Bookmark #1
xtset country year

**** Regresion para DiD: y(it)=b0+b1*T+b2*D+b3*T*D donde d es el efecto promedio de tratamiento sobre los tratados. Incluimos efectos fijos por individuo

* Con reg
reg Y time treated did

* Con xtreg
xtreg Y time treated did, fe 

* Forma alternativa:
xtreg Y time##treated, fe 


**** Paquete diff: nos hace todo esto sin escribir las regresiones

ssc install diff // Lo instalamos 

diff Y, t(treated) p(time)



