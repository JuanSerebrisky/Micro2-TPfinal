/***********************/
*  Microeconometria II  *
*     PS 2 - Ej. 3      *
/***********************/

**** Directorio y abrimos la base

cd "C:\Users\iaral\OneDrive - Universidad Torcuato Di Tella\Clases\MAECO_Microeconometria II\PS2"


findit psestimate
findit psmatch2
findit pscore
findit rbounds
findit nnmatch

clear all

set more off

use cattaneo2.dta

**** 1. Compruebe si los grupos de control y de tratamiento est´an balanceados

bys mbsmoke: sum mmarried mhisp foreign alcohol deadkids mage medu nprenatal monthslb order mrace prenatal fbaby prenatal1 


twoway (kdensity mmarried if mbsmoke==0) (kdensity mmarried if mbsmoke==1) 
 

** Pruebas de medias

foreach i of varlist  mmarried mhisp foreign alcohol deadkids mage medu nprenatal monthslb order mrace prenatal fbaby prenatal1 {
	display "Test de diferencia de medias para `i'"
	ttest `i', by(mbsmoke) une
}


reg bweight mbsmoke

**** 2. Estimamos el Propensity score

** 2.1 Primero necesito una muestra más balanceada

psestimate mbsmoke, t(mmarried deadkids nprenatal monthslb prenatal fbaby alcohol) 

* psestimate mbsmoke mhisp mrace mage medu , t(mmarried deadkids nprenatal monthslb prenatal fbaby alcohol) 

** Uso el comando return para verificar los resultados 
return list

** Guardo el psestimate_var como global porque estamos corriendo de a 1 partecita a la vez. Caso contrario podemos guardarlo como local
global psestimate_var = r(h)
/** The psestimate command estimates the propensity score proposed by Imbens and Rubin (2015).  (...) The main purpose of the program is to select a linear or quadratic function of covariates to include in the estimation function of the propensity score.
**/

** Corremos el logit de la variable mbsmoke (fumar o no fumar) contra las variables seleccionadas por el algoritmo.
logit mbsmoke $psestimate_var

** Guardo en e_x los puntajes, los propensity scores.
predict e_x

** Descartamos los valores bajos y altos del propensity score utilizando optselect

optselect e_x

drop if e_x < r(bound)
drop if e_x > 1 - r(bound)

*  Matching sin reposición 

psmatch2 mbsmoke, pscore(e_x) noreplacement

* Nos quedamos con las observaciones matcheadas así tenemos una muestra un poco más balanceada

keep if _weight == 1

drop e_x

** 2.2 Estimamos el propensity score y chequeamos la propiedad de balance

pscore mbsmoke mhisp mrace mage medu mmarried nprenatal monthslb prenatal fbaby alcohol, pscore(e_x) blockid(blockid)

**** 3. Hacemos de nuevo las pruebas de balance

bys mbsmoke: sum mmarried mhisp foreign alcohol deadkids mage medu nprenatal monthslb order mrace prenatal fbaby prenatal1 

** pruebas de medias **

foreach i of varlist  mmarried mhisp foreign alcohol deadkids mage medu nprenatal monthslb order mrace prenatal fbaby prenatal1 {
	display "Test de diferencia de medias para `i'"
	ttest `i', by(mbsmoke) une
}

**** 4. Estimamos el efecto medio de tratamiendo usando propensity score matching

** 4.1 Nearest neighbor matching

attnw bweight mbsmoke, pscore(e_x) // Mismo peso a matching hacia arriba y hacia abajo

attnd bweight mbsmoke, pscore(e_x) // Se selecciona al azar uno de los dos matching
attnd bweight mbsmoke, pscore(e_x) bootstrap reps(10)
** 4.2 Radius matching

attr bweight mbsmoke, pscore(e_x)

attr bweight mbsmoke, pscore(e_x)  radius(0.05)

attr bweight mbsmoke, pscore(e_x)  radius(0.2)

** 4.3 Kernel matching

attk bweight mbsmoke, pscore(e_x)

attk bweight mbsmoke, pscore(e_x) bootstrap reps(10)

** 4.4 Stratification matching

atts bweight mbsmoke, pscore(e_x) blockid(blockid)

**** 5. Estimamos el efecto medio de tratamiento usando matching 

nnmatch bweight mbsmoke e_x , biasadj(mhisp mrace medu mage alcohol fbaby)

**** 6. Estimamos el efecto medio de tratamiento usando otros métodos

** 6.1 Ajuste por regresión 

teffects ra (bweight mhisp mrace medu mage alcohol fbaby, linear) (mbsmoke), ate
teffects ra (bweight mhisp mrace medu mage alcohol fbaby, linear) (mbsmoke), atet


//----------------------------------------
** 6.2 IPW

teffects ipw (bweight) (mbsmoke mhisp mrace mage medu mmarried nprenatal monthslb prenatal fbaby alcohol , logit)

** 6.3 Doblemente robusto

teffects aipw (bweight mhisp mrace medu mage alcohol fbaby, linear) (mbsmoke mhisp mrace mage medu mmarried nprenatal monthslb prenatal fbaby alcohol, logit)

