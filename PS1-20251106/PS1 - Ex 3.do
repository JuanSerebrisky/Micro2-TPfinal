** Microeconometria II **
** PS 1 - Ej. 3

clear all

** Inciso 3 - Inicializamos muestra de 100 observaciones
set obs 100
set seed 2703

** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)

** Inciso 4 - Efectos de tratamiento constantes TE=20
** Resultado potencial si recibe tratamiento 
gen te = 20

*Genera el resultado potencial del treatment como el reposo + TE + ruido para que no queden todos iguales.
gen y1 = y0 + te + rnormal(0,10)


** Tratamiento otorgado aleatoriamente
drawnorm random 
sort random /*no hace falta ordenar dijo*/
gen D = (random>0)


** Variable observada 
gen y = D*y1 + (1-D)*y0


** Testeo (Muestral)
bys D: summ y

** Por como funciona el test-t, calculamos una dummy que es no-recibir el tratamiento
gen U = 1-D

** Entonces al correr el t-test, esto nos devuelve la diferencia de medias
** que nos interesa: mean0-mean1, donde 0 representa "recibir el tratamiento"y 1 "no recibir el tratamiento".

*OJO- cero es tratamiento*
ttest y, by(U)


** Calculo los verdaderos efectos (Poblacional - Trivial porque nosotros dijimos que valia 20 el efecto!) 

** ATE
summ te 

** ATT 
summ te if D==1 

** ATU
summ te if D==0


** Inciso 5 - Efectos de tratamiento constantes. ATE=20 pero TE~N(20,10)

clear all
set obs 100
set seed 2703

* Efectos de tratamiento provenientes de una distribucion con ATE=20

** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)


** Resultado potencial si recibe tratamiento 
gen te = rnormal(20,10)
gen y1 = y0 + te + rnormal(0,10)


** Tratamiento otorgado aleatoriamente
drawnorm random 
sort random 
gen D = (random>0)


** Variable observada 
gen y = D*y1 + (1-D)*y0


** Testeo 
bys D: summ y
gen U = 1-D
ttest y, by(U)

** Calculo los verdaderos efectos 
** ATE
summ te 

** ATT 
summ te if D==1 

** ATU
summ te if D==0

** Inciso 6 - Efectos de tratamiento heterogeneos en funcion de si recibe o no el tratamiento
* Es decir ATT != ATU
* Similar al caso del "médico perfecto"

clear all
set obs 100
set seed 2703
** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)

** Genero variable aleatoria de la cual dependen los TE
drawnorm random 
sort random 
gen W = (random>0)


** Resultado potencial si recibe tratamiento 
gen te=.
replace te = rnormal(20,10) if W==1 
replace te = rnormal(10,10) if W==0

gen y1 = y0 + te + rnormal(0,10)

** Variable observada 
gen y = W*y1 + (1-W)*y0

** Testeo 
bys W: summ y

gen U = 1-W
ttest y, by(U)

** Calculo los verdaderos efectos 

** ATT 
summ te if W==1 
scalar define att=r(mean)
** ATU
summ te if W==0
scalar define atu=r(mean)

** Ponderadores 
summ W 
scalar define pi=r(mean) 
scalar ate_calc = pi*att+(1-pi)*atu
scalar list ate_calc

** ATE - Es un promedio ponderado.
summ te 



** Inciso 7 - Efectos de tratamiento heterogeneos en funcion de si recibe o no el tratamiento
* Es decir ATT != ATU
* No hay sesgo de seleccion porque el tratamiento se otorga aleatoriamente 
* Efectos de tratamiento provenientes de una distribucion con TE=20

clear all

set obs 100
*set seed 2703
** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)

** Genero variable aleatoria de la cual dependen los TE
drawnorm random 
sort random 
gen W = (random>0)

** Resultado potencial si recibe tratamiento 
gen te=.
replace te = rnormal(20,10) if W==1 
replace te = rnormal(10,10) if W==0

gen y1 = y0 + te + rnormal(0,10)

** Tratamiento otorgado aleatoriamente
drawnorm random2
sort random2
gen D = (random2>0)


** Variable observada 
gen y = D*y1 + (1-D)*y0

** Testeo 
bys D: summ y
gen U = 1-D
ttest y, by(U)

** Calculo los verdaderos efectos 

** ATE
summ te 

** ATT 
summ te if D==1 
scalar define att=r(mean)
** ATU
summ te if D==0
scalar define atu=r(mean)

** Ponderadores 
summ D
scalar define pi=r(mean) 
scalar ate_calc = pi*att+(1-pi)*atu
scalar list ate_calc

** ATE
summ te 

* Inciso 8

/* Cuando usamos la diferencia en medias para intentar identificar el ATE ,
este procedimiento va a ser correcto siempre y cuando la selección sea aleatoria y no haya heterogeneidad en el tratamiento. 
Cuando hay heterogeneidad en el trat queda distinto. Tmb cuando hay sesgo de selección.
