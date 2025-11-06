clear all

set obs 100
set seed 2703

********************************************************************************
* Efectos de tratamiento constantes. ATE=20
********************************************************************************

** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)


** Resultado potencial si recibe tratamiento 
gen te = 20
gen y1 = y0 + te + rnormal(0,10)


** Tratamiento otorgado aleatoriamente
drawnorm random 
gen D = (random>0)


** Variable observada 
gen y = D*y1 + (1-D)*y0


** Testeo 
bys D: summ y

** ATE Muestral
gen U = 1-D
ttest y, by(U)


** Calculo los verdaderos efectos (poblacional)

** ATE
summ te 

** ATT 
summ te if D==1 

** ATU
summ te if D==0



********************************************************************************
* Efectos de tratamiento constantes. ATE=20 pero TE~N(20,10)
********************************************************************************
clear all

set obs 100
*set seed 2703

* Efectos de tratamiento provenientes de una distribucion con ATE=20

** Resultado potencial si no recibe tratamiento 
gen y0 = rnormal(100,30)


** Resultado potencial si recibe tratamiento 
gen te = rnormal(20,10)
gen y1 = y0 + te + rnormal(0,10)


** Tratamiento otorgado aleatoriamente
drawnorm random 
gen A = (random>0) // Asignacion 

** Que tipo de individuo es? 
gen random2 = runiform(0,1)

gen alwaystaker = (random2<0.25)
gen nevertaker = (random2>=0.25 & random2<0.5)
gen defier = (random2>=0.5 & random2<0.75)
gen complier = (random2>0.75)

** Que hace cada individuo? 
gen D=0
replace D=1 if alwaystaker==1 
replace D=0 if nevertaker==1 
replace D=A if complier==1
replace D=(1-A) if defier==1 

** Variable observada 
gen y = D*y1 + (1-D)*y0


** Testeo 
bys A: summ y // lo que fue asignado
bys D: summ y // lo que resulto ser la asignacion

regress y D
ivregress y (D=A)

gen U = 1-D
ttest y, by(U)


** Calculo los verdaderos efectos 

** ATE
summ te 

** ATT 
summ te if D==1 

** ATU
summ te if D==0



