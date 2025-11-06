"""Simulación de Monte Carlo para el Ejercicio 3 del Examen Final 2T 2025.

El script replica el escenario de variables instrumentales descrito en el
Ejercicio 3 del examen. Se calculan 1,000 replicaciones de Monte Carlo (por
predeterminado) para muestras pequeñas (N = 100) bajo dos configuraciones de
instrumentos: uno fuerte (coeficiente 0.3) y otro débil (coeficiente 0.05).

Para cada réplica se estiman:
    * Mínimos Cuadrados Ordinarios (MCO) "ingenuo" controlando por X.
    * Mínimos Cuadrados en Dos Etapas (MC2E) usando Zi como instrumento.

Se reportan para cada estimador y escenario: sesgo, varianza, error cuadrático
medio y tasa de cobertura del intervalo de confianza del 95%, además del
estadístico F de la primera etapa en MC2E.

El código requiere únicamente NumPy y Pandas. Si SciPy está instalado, utiliza
cuantiles de la t-Student para construir intervalos de confianza; de lo
contrario emplea la aproximación normal estándar.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Iterable, List, Tuple

import numpy as np
import pandas as pd

try:  # SciPy es opcional
    from scipy.stats import t as student_t
except Exception:  # pragma: no cover - SciPy podría no estar disponible
    student_t = None

TRUE_ATE = 2.0
DEFAULT_REPS = 1_000
DEFAULT_N = 100
DEFAULT_STRENGTHS = (0.3, 0.05)


@dataclass
class SimulationRecord:
    """Resultados de una réplica para un estimador específico."""

    repetition: int
    estimator: str
    estimate: float
    std_error: float
    ci_lower: float
    ci_upper: float
    covered: bool
    first_stage_f: float | None


@dataclass
class ScenarioResult:
    """Contenedor de resultados detallados y resumen para un escenario."""

    strength: float
    label: str
    records: pd.DataFrame
    summary: pd.DataFrame


def critical_value(df: int, alpha: float = 0.05) -> float:
    """Obtiene el valor crítico bilateral para el nivel dado."""

    if df <= 0:
        return 1.96
    if student_t is not None:
        return float(student_t.ppf(1 - alpha / 2, df))
    # Aproximación normal si SciPy no está disponible
    return 1.959963984540054


def ols_with_controls(y: np.ndarray, d: np.ndarray, x: np.ndarray) -> Tuple[float, float, float, float]:
    """Estima Y sobre (1, D, X) y devuelve coeficiente, error estándar e IC."""

    n = y.shape[0]
    design = np.column_stack((np.ones(n), d, x))
    xtx = design.T @ design
    beta = np.linalg.solve(xtx, design.T @ y)
    residuals = y - design @ beta
    df = n - design.shape[1]
    sigma2 = float(residuals.T @ residuals) / df
    var_beta = sigma2 * np.linalg.inv(xtx)
    se = float(np.sqrt(var_beta[1, 1]))
    crit = critical_value(df)
    coef = float(beta[1])
    ci_lower = coef - crit * se
    ci_upper = coef + crit * se
    return coef, se, ci_lower, ci_upper


def two_stage_least_squares(y: np.ndarray, d: np.ndarray, x: np.ndarray, z: np.ndarray) -> Tuple[float, float, float, float, float]:
    """Ejecuta MC2E con instrumento z y devuelve coeficiente, se, IC y F."""

    n = y.shape[0]
    # Matrices para 2SLS: X incluye endógeno D y exógeno X; Z incluye exógenos + instrumento
    X_full = np.column_stack((np.ones(n), d, x))
    Z_full = np.column_stack((np.ones(n), x, z))

    ztz_inv = np.linalg.inv(Z_full.T @ Z_full)
    XPZ = X_full.T @ Z_full @ ztz_inv @ Z_full.T
    A = XPZ @ X_full
    A_inv = np.linalg.inv(A)
    beta = A_inv @ (XPZ @ y)

    residuals = y - X_full @ beta
    df = n - X_full.shape[1]
    sigma2 = float(residuals.T @ residuals) / df
    var_beta = sigma2 * A_inv
    se = float(np.sqrt(var_beta[1, 1]))
    crit = critical_value(df)
    coef = float(beta[1])
    ci_lower = coef - crit * se
    ci_upper = coef + crit * se

    # Estadístico F de la primera etapa para la relevancia de Z
    W_full = np.column_stack((np.ones(n), x, z))
    beta_full = np.linalg.solve(W_full.T @ W_full, W_full.T @ d)
    resid_full = d - W_full @ beta_full
    sse_full = float(resid_full.T @ resid_full)

    W_restricted = np.column_stack((np.ones(n), x))
    beta_restricted = np.linalg.solve(W_restricted.T @ W_restricted, W_restricted.T @ d)
    resid_restricted = d - W_restricted @ beta_restricted
    sse_restricted = float(resid_restricted.T @ resid_restricted)

    q = 1  # número de instrumentos excluidos
    k_full = W_full.shape[1]
    numerator = (sse_restricted - sse_full) / q
    denominator = sse_full / (n - k_full)
    first_stage_f = numerator / denominator if denominator > 0 else np.nan

    return coef, se, ci_lower, ci_upper, float(first_stage_f)


def simulate_scenario(n: int, reps: int, strength: float, seed: int) -> pd.DataFrame:
    """Ejecuta las simulaciones Monte Carlo para una fuerza del instrumento."""

    rng = np.random.default_rng(seed)
    records: List[SimulationRecord] = []

    for r in range(1, reps + 1):
        x = rng.normal(size=n)
        z = rng.binomial(1, 0.5, size=n)
        v = rng.normal(size=n)
        epsilon = rng.normal(size=n)

        d = 0.2 + strength * z + 0.5 * x + v
        u = 0.8 * v + epsilon
        y = 5 + 2.0 * d + x + u

        coef_ols, se_ols, ci_l_ols, ci_u_ols = ols_with_controls(y, d, x)
        records.append(
            SimulationRecord(
                repetition=r,
                estimator="MCO",
                estimate=coef_ols,
                std_error=se_ols,
                ci_lower=ci_l_ols,
                ci_upper=ci_u_ols,
                covered=ci_l_ols <= TRUE_ATE <= ci_u_ols,
                first_stage_f=None,
            )
        )

        coef_iv, se_iv, ci_l_iv, ci_u_iv, f_stat = two_stage_least_squares(y, d, x, z)
        records.append(
            SimulationRecord(
                repetition=r,
                estimator="MC2E",
                estimate=coef_iv,
                std_error=se_iv,
                ci_lower=ci_l_iv,
                ci_upper=ci_u_iv,
                covered=ci_l_iv <= TRUE_ATE <= ci_u_iv,
                first_stage_f=f_stat,
            )
        )

    df = pd.DataFrame([record.__dict__ for record in records])
    return df


def summarize_records(records: pd.DataFrame) -> pd.DataFrame:
    """Construye estadísticas de sesgo, varianza, MSE y cobertura."""

    def _summary(group: pd.DataFrame) -> pd.Series:
        mean_est = group["estimate"].mean()
        bias = mean_est - TRUE_ATE
        variance = group["estimate"].var(ddof=1)
        mse = bias**2 + variance
        coverage = group["covered"].mean()
        avg_se = group["std_error"].mean()
        avg_f = group["first_stage_f"].dropna().mean() if group["first_stage_f"].notna().any() else np.nan
        return pd.Series(
            {
                "Media": mean_est,
                "Sesgo": bias,
                "Varianza": variance,
                "MSE": mse,
                "Cobertura 95%": coverage,
                "Error estándar medio": avg_se,
                "F primera etapa (promedio)": avg_f,
            }
        )

    summaries = []
    indices = []
    for estimator, group in records.groupby("estimator", sort=False):
        summaries.append(_summary(group))
        indices.append(estimator)

    return pd.DataFrame(summaries, index=indices)


def format_strength_label(strength: float) -> str:
    if np.isclose(strength, 0.3):
        return "Instrumento fuerte (γ = 0.30)"
    if np.isclose(strength, 0.05):
        return "Instrumento débil (γ = 0.05)"
    return f"γ = {strength:.2f}"


def run_simulation(n: int, reps: int, strengths: Iterable[float], seed: int) -> List[ScenarioResult]:
    results: List[ScenarioResult] = []
    base_seed = seed

    for idx, strength in enumerate(strengths):
        scenario_seed = base_seed + idx * 10_000
        records = simulate_scenario(n, reps, strength, scenario_seed)
        summary = summarize_records(records)
        results.append(
            ScenarioResult(
                strength=strength,
                label=format_strength_label(strength),
                records=records,
                summary=summary,
            )
        )

    return results


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Simulaciones Monte Carlo para IV (Ejercicio 3 Examen 2T2025)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--n", type=int, default=DEFAULT_N, help="Tamaño muestral por réplica")
    parser.add_argument("--reps", type=int, default=DEFAULT_REPS, help="Número de replicaciones Monte Carlo")
    parser.add_argument(
        "--strengths",
        type=float,
        nargs="+",
        default=list(DEFAULT_STRENGTHS),
        help="Coeficientes del instrumento en la primera etapa (γ).",
    )
    parser.add_argument("--seed", type=int, default=12345, help="Semilla global de los generadores aleatorios")
    return parser.parse_args()


def main() -> None:
    args = parse_arguments()
    strengths = args.strengths
    results = run_simulation(args.n, args.reps, strengths, args.seed)

    pd.set_option("display.float_format", "{:.4f}".format)

    for scenario in results:
        print("=" * 80)
        print(scenario.label)
        print(f"Tamaño muestral: {args.n} | Réplicas: {args.reps} | Semilla base: {args.seed}")
        print(scenario.summary)
        if scenario.records["first_stage_f"].notna().any():
            f_stats = scenario.records.loc[scenario.records["estimator"] == "MC2E", "first_stage_f"]
            print("\nResumen del estadístico F de primera etapa (solo MC2E):")
            print(
                pd.Series(
                    {
                        "Promedio": f_stats.mean(),
                        "Mediana": f_stats.median(),
                        "Desv. estándar": f_stats.std(ddof=1),
                        "P5": f_stats.quantile(0.05),
                        "P95": f_stats.quantile(0.95),
                    }
                ).to_frame().T
            )
        print()


if __name__ == "__main__":
    main()
