* Juan S. Serebrisky
*--------------------------------------------------------------------------------------------------------------
*Micoreconometria II - Examen final 2025
*--------------------------------------------------------------------------------------------------------------
clear all
set more off
set seed 14286


****Inciso 1

local reps = 1000
scalar ATE_true = 3

foreach N in 100 200 {
    tempname P
    postfile `P' rep N ybar1 ybar0 diff using "mc_dm_sum_N`N'.dta", replace

    forvalues r = 1/`reps' {
        drop _all
        set obs `N'
        gen X = rnormal()
        gen e = rnormal()
        gen D = (X + e > 0)
        gen u = rnormal()
        gen Y = 2 + 3*D + 2*X + u

        quietly summarize Y if D==1
        scalar y1 = r(mean)
        quietly summarize Y if D==0
        scalar y0 = r(mean)
        scalar dt = y1 - y0

        if mod(`r',100)==0 di "Rep: `r'"
        post `P' (`r') (`N') (y1) (y0) (dt)
    }
    postclose `P'

    use "mc_dm_sum_N`N'.dta", clear
    export excel using "C:\Users\JSerebrisky\Documents\mc_dm_sum_N`N'.xlsx", ///
        firstrow(variables) replace
    di as res "Excel exportado: C:\Users\JSerebrisky\Documents\mc_dm_sum_N`N'.xlsx"

    clear
    di as text "---- Finalizado N=`N' ----"
}

***Calculo de metricas (con 100): 
foreach N in 100 {
    import excel using "mc_dm_sum_N`N'.xlsx", firstrow clear

    quietly summarize diff
    scalar mean_b = r(mean)
    scalar var_b  = r(Var)
    scalar sd_b   = r(sd)
    scalar bias   = mean_b - ATE_true
    scalar MSE    = var_b + bias^2

    di as text "--------------------------------------------"
    di as text "Resultados Monte Carlo - Diferencia de medias"
    di as text "Tamaño muestral N = `N'"
    di as res  "Media estimador:   " %9.4f mean_b
    di as res  "Sesgo (mean-3):    " %9.4f bias
    di as res  "Varianza:          " %9.4f var_b
    di as res  "Desv.Est.:         " %9.4f sd_b
    di as res  "MSE:               " %9.4f MSE
    di as text "--------------------------------------------"
   
}

***Calculo de metricas (con 200): 
foreach N in 200 {
    import excel using "mc_dm_sum_N`N'.xlsx", firstrow clear

    quietly summarize diff
    scalar mean_b = r(mean)
    scalar var_b  = r(Var)
    scalar sd_b   = r(sd)
    scalar bias   = mean_b - ATE_true
    scalar MSE    = var_b + bias^2

    di as text "--------------------------------------------"
    di as text "Resultados Monte Carlo - Diferencia de medias"
    di as text "Tamaño muestral N = `N'"
    di as res  "Media estimador:   " %9.4f mean_b
    di as res  "Sesgo (mean-3):    " %9.4f bias
    di as res  "Varianza:          " %9.4f var_b
    di as res  "Desv.Est.:         " %9.4f sd_b
    di as res  "MSE:               " %9.4f MSE
    di as text "--------------------------------------------"
   
}

***Calcular la cobertura

scalar z95 = invnormal(0.975)

foreach N in 100 200 {
    import excel using "mc_dm_sum_N`N'.xlsx", firstrow clear

    * suponemos n1≈n0≈N/2 (asignación balanceada)
    gen n1 = `N'/2
    gen n0 = `N'/2

    * estimar varianza intra-grupo de forma proxy con varianza entre réplicas (si no la tenés guardada)
    * usamos la varianza de diff como proxy del se promedio
    quietly summarize diff
    scalar sd_diff = r(sd)
    gen se = sd_diff   // mismo se para todas las réplicas (proxy global)
    
    * construir IC por réplica y chequear si contiene el valor verdadero (3)
    gen lo = diff - z95*se
    gen hi = diff + z95*se
    gen cover = (ATE_true >= lo & ATE_true <= hi)

    quietly summarize cover
    scalar cover95 = r(mean)

    di as text "--------------------------------------------"
    di as text "Cobertura 95% - Diferencia de medias"
    di as text "Tamaño muestral N = `N'"
    di as res  "Proporción de ICs que contienen 3: " %6.3f cover95
    di as text "--------------------------------------------"
}

****Inciso 2
clear 

local reps = 1000
scalar ATE_true = 3
scalar z95 = invnormal(0.975)

foreach N in 100 200 {
    tempname P
    postfile `P' rep N b_hat se_hat lo hi cover using "mc_OLSX_N`N'.dta", replace

    forvalues r = 1/`reps' {
        drop _all
        set obs `N'
        gen X = rnormal()
        gen e = rnormal()
        gen D = (X + e > 0)
        gen u = rnormal()
        gen Y = 2 + 3*D + 2*X + u

        regress Y D X, vce(robust)
        scalar b  = _b[D]
        scalar se = _se[D]
        scalar lo = b - z95*se
        scalar hi = b + z95*se
        scalar cv = (ATE_true>=lo & ATE_true<=hi)

        if mod(`r',100)==0 di "Rep: `r'"
        post `P' (`r') (`N') (b) (se) (lo) (hi) (cv)
    }
    postclose `P'

    use "mc_OLSX_N`N'.dta", clear
    quietly summarize b_hat
    scalar mean_b = r(mean)
    scalar var_b  = r(Var)
    scalar sd_b   = r(sd)
    scalar bias   = mean_b - ATE_true
    scalar MSE    = var_b + bias^2
    quietly summarize cover
    scalar cover95 = r(mean)

    di as text "--------------------------------------------"
    di as text "OLS con X | N=`N' | reps=`reps'"
    di as res  "Media: " %9.4f mean_b "  Sesgo: " %9.4f bias "  Var: " %9.4f var_b "  SD: " %9.4f sd_b
    di as res  "MSE:   " %9.4f MSE    "  Cobertura 95%: " %6.3f cover95
    di as text "--------------------------------------------"
}

***
clear
cd "C:\Users\JSerebrisky\Documents"

local reps = 1000
scalar ATE_true = 3
scalar z95 = invnormal(0.975)

tempfile acc
clear
set obs 0
gen N=.
gen mean_b=.
gen bias=.
gen var=.
gen sd=.
gen MSE=.
gen cover95=.
save `acc', replace

**ESTE LOOP FUNCIONA SOLO CON UN N A LA VEZ, CORRER DOBLE

foreach N in 100 {
    tempname P
    postfile `P' rep N b_hat se_hat lo hi cover using "mc2_OLSX_N`N'.dta", replace

    forvalues r = 1/`reps' {
        drop _all
        set obs `N'
        gen X = rnormal()
        gen e = rnormal()
        gen D = (X + e > 0)
        gen u = rnormal()
        gen Y = 2 + 3*D + 2*X + u

        regress Y D X, vce(robust)
        scalar b  = _b[D]
        scalar se = _se[D]
        scalar lo = b - z95*se
        scalar hi = b + z95*se
        scalar cv = (ATE_true>=lo & ATE_true<=hi)

        if mod(`r',100)==0 di "Rep: `r'"
        post `P' (`r') (`N') (b) (se) (lo) (hi) (cv)
    }
    postclose `P'

    use "mc2_OLSX_N`N'.dta", clear
    export excel using "mc2_OLSX_N`N'.xlsx", firstrow(variables) replace

    quietly summarize b_hat
    scalar mean_b = r(mean)
    scalar var_b  = r(Var)
    scalar sd_b   = r(sd)
    scalar bias   = mean_b - ATE_true
    scalar MSE    = var_b + bias^2
    quietly summarize cover
    scalar cover95 = r(mean)

    di as text "--------------------------------------------"
    di as text "OLS con X | N=`N' | reps=`reps'"
    di as res  "Media: " %9.4f mean_b "  Sesgo: " %9.4f bias "  Var: " %9.4f var_b "  SD: " %9.4f sd_b
    di as res  "MSE:   " %9.4f MSE    "  Cobertura 95%: " %6.3f cover95
    di as text "--------------------------------------------"

    preserve
        use `acc', clear
        expand 1
        replace N = `N' in L
        replace mean_b = mean_b in L
        replace bias   = bias   in L
        replace var    = var_b  in L
        replace sd     = sd_b   in L
        replace MSE    = MSE    in L
        replace cover95= cover95 in L
        save `acc', replace
    restore
}

use `acc', clear
order N mean_b bias var sd MSE cover95
export excel using "mc2_OLSX_summary.xlsx", firstrow(variables) replace
