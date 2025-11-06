** Microeconometria II **
** PS 1 - Ej. 2


clear all

* Empezamos cargando el dataset. 

    clear
	
    drop _all
	
    set obs 10
	
	gen id = _n 

* Resultados potenciales
    gen     y1 = 7 in 1
    replace y1 = 5 in 2
    replace y1 = 5 in 3
    replace y1 = 7 in 4
    replace y1 = 4 in 5
    replace y1 = 10 in 6
    replace y1 = 1 in 7
    replace y1 = 5 in 8
    replace y1 = 3 in 9
    replace y1 = 9 in 10

    gen     y0 = 1 in 1
    replace y0 = 6 in 2
    replace y0 = 1 in 3
    replace y0 = 8 in 4
    replace y0 = 2 in 5
    replace y0 = 1 in 6
    replace y0 = 10 in 7
    replace y0 = 6 in 8
    replace y0 = 7 in 9
    replace y0 = 8 in 10

* a) Calculo el verdadero ATE

summ y1
scalar define ybar1 = r(mean)

summ y0
scalar define ybar0 = r(mean)

scalar true_ate = ybar1-ybar0
scalar list true_ate

* b) Aleatorizamos. Una vez a mano.
* Sacamos 1 valor de una normal estándar para cada obs.
	drawnorm random
* Ordenamos con esa variable aleatoria.
    sort random

* c) Generar var. de otorgamiento	
* Otorgamos el tratamiento a los primeros 5 ordenados.
    gen     d=1 in 1/5
    replace d=0 in 6/10

* d) Compute la diferencia de medias en los promedios muestrales	
* Computamos el valor de la variable outcome observado.
    gen     y=d*y1 + (1-d)*y0

* Computamos la diferencia de medias en los promedios muestrales

summ y if d==1
scalar define ybar1=r(mean)

summ y if d==0
scalar define ybar0=r(mean)

scalar define estim_ate=ybar1-ybar0
scalar list estim_ate


* Forma alternativa:

	gen te=y1-y0

	* ATE
	summ te
	
	* ATT
	sum te if d==1
	scalar att=r(mean)
	* ATU
	sum te if d==0
	scalar atu=r(mean)
	
	* ATE (lo podés pensar como un promedio ponderado por la cant de personas que asignaste a cada grupo)
	scalar att2 = 1/2*att+1/2*atu
	scalar list att2

* e) Realizar 1000 simulaciones y calcular la dif de medias.
		
program define gap, rclass

    *version 14.2
    syntax [, obs(integer 1) mu(real 0) sigma(real 1) ]
    clear
    drop _all
    set obs 10
	
	gen id = _n 
	
    gen     y1 = 7 in 1
    replace y1 = 5 in 2
    replace y1 = 5 in 3
    replace y1 = 7 in 4
    replace y1 = 4 in 5
    replace y1 = 10 in 6
    replace y1 = 1 in 7
    replace y1 = 5 in 8
    replace y1 = 3 in 9
    replace y1 = 9 in 10

    gen     y0 = 1 in 1
    replace y0 = 6 in 2
    replace y0 = 1 in 3
    replace y0 = 8 in 4
    replace y0 = 2 in 5
    replace y0 = 1 in 6
    replace y0 = 10 in 7
    replace y0 = 6 in 8
    replace y0 = 7 in 9
    replace y0 = 8 in 10

    
	drawnorm random
    sort random

    gen     d=1 in 1/5
    replace d=0 in 6/10
    gen     y=d*y1 + (1-d)*y0
    egen ybar1 = mean(y) if d==1
    egen ybar0 = mean(y) if d==0          
    collapse (mean) ybar1 ybar0
    gen dif = ybar1 - ybar0
    keep dif
    summarize dif
    gen mean = r(mean)
    end

simulate mean, reps(10000): gap
summ _sim_1 

*Notar que el promedio me da 0.58 y el posta era 0.6 así que GOD
help collapse 

