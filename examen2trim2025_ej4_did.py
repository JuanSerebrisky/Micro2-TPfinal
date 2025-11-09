"""Simulación de Monte Carlo para el Ejercicio 4 (DiD) del Examen Final 2T 2025.

El script evalúa las propiedades de muestra finita de dos estimadores de
Diferencia-en-Diferencias (DiD) bajo dos escenarios:

1. Escenario base con tendencias paralelas válidas.
2. Escenario con violación de tendencias paralelas vía pre-tendencia en el
   grupo tratado.

Para cada escenario se generan réplicas de un panel balanceado con dos
períodos (pre y post) y la mitad de las unidades asignadas permanentemente al
tratamiento. Se estima el parámetro ATT (=1.5) empleando:

* DiD estándar (regresión con interacción tratamiento x post).
* DiD con efectos fijos de unidad y tiempo, controlando por la covariable X.

Ambos estimadores utilizan errores estándar agrupados por unidad. Se resumen
sesgo, varianza, MSE y cobertura de intervalos de confianza.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import sys
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd

try:  # SciPy es opcional, igual que en el ejercicio anterior
    from scipy.stats import t as student_t
except Exception:  # pragma: no cover - SciPy podría no estar disponible
    student_t = None

ATT_TRUE = 1.5
DEFAULT_REPS = 1_000
DEFAULT_N = 100
DEFAULT_SEED = 14286  # reemplazar por los últimos 5 dígitos del documento si se desea reproducir otro escenario


@dataclass
class EstimationRecord:
    """Resultado de una réplica para un estimador y escenario dados."""

    repetition: int
    n: int
    scenario: str
    estimator: str
    estimate: float
    std_error: float
    ci_lower: float
    ci_upper: float
    covered: bool


def critical_value(df: int, alpha: float = 0.05) -> float:
    """Obtiene el valor crítico bilateral para el nivel dado."""

    if df <= 0:
        return 1.96
    if student_t is not None:
        return float(student_t.ppf(1 - alpha / 2, df))
    return 1.959963984540054


def cluster_robust_se(X: np.ndarray, residuals: np.ndarray, clusters: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """Calcula varianzas cluster-robust (tipo Arellano) agrupando por unidad."""

    XtX = X.T @ X
    XtX_inv = np.linalg.inv(XtX)
    unique_clusters = np.unique(clusters)
    m = unique_clusters.shape[0]
    k = X.shape[1]
    S = np.zeros((k, k))
    for g in unique_clusters:
        mask = clusters == g
        Xg = X[mask]
        ug = residuals[mask][:, None]
        S += Xg.T @ ug @ ug.T @ Xg
    V = XtX_inv @ S @ XtX_inv
    n_obs = X.shape[0]
    if m > 1:
        correction = (m / (m - 1)) * ((n_obs - 1) / (n_obs - k))
        V *= correction
    return np.sqrt(np.diag(V)), V


def simulate_panel(n: int, rng: np.random.Generator, violation: bool) -> pd.DataFrame:
    """Genera un panel balanceado de dos períodos con o sin violación de tendencias."""

    units = np.arange(n)
    treated = np.zeros(n, dtype=int)
    treated[: n // 2] = 1
    rng.shuffle(treated)

    alpha_i = rng.normal(loc=0.0, scale=1.0, size=n)
    lambda_t = np.array([0.0, 0.5])  # componente común de tiempo
    periods = np.array([1, 2])
    post_indicator = np.array([0, 1])

    records: List[Dict[str, float]] = []
    for idx, unit in enumerate(units):
        for pos, t in enumerate(periods):
            x_it = rng.normal()
            u_it = rng.normal()
            dit = treated[idx] * post_indicator[pos]
            time_effect = lambda_t[pos]
            if violation and treated[idx]:
                time_effect += 0.5 * t
            y_it = alpha_i[idx] + time_effect + 1.5 * dit + 2.0 * x_it + u_it
            records.append(
                {
                    "unit": unit,
                    "time": int(t),
                    "treated": int(treated[idx]),
                    "post": int(post_indicator[pos]),
                    "did": int(dit),
                    "x": float(x_it),
                    "y": float(y_it),
                }
            )
    return pd.DataFrame.from_records(records)


def design_matrix_basic(df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Construye la matriz de diseño para el DiD básico."""

    intercept = np.ones((df.shape[0], 1))
    treat = df[["treated"]].to_numpy(dtype=float)
    post = df[["post"]].to_numpy(dtype=float)
    interaction = (df["treated"] * df["post"]).to_numpy(dtype=float).reshape(-1, 1)
    X = np.hstack((intercept, treat, post, interaction))
    y = df["y"].to_numpy(dtype=float)
    clusters = df["unit"].to_numpy()
    return X, y, clusters


def design_matrix_twfe(df: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Construye la matriz de diseño para el DiD con efectos fijos y X."""

    intercept = np.ones((df.shape[0], 1))
    post = df[["post"]].to_numpy(dtype=float)
    interaction = (df["treated"] * df["post"]).to_numpy(dtype=float).reshape(-1, 1)
    x = df[["x"]].to_numpy(dtype=float)

    unit_dummies = pd.get_dummies(df["unit"], drop_first=True, dtype=float)

    X = np.hstack(
        (
            intercept,
            post,
            interaction,
            x,
            unit_dummies.to_numpy(dtype=float),
        )
    )
    y = df["y"].to_numpy(dtype=float)
    clusters = df["unit"].to_numpy()
    return X, y, clusters


def estimate_model(X: np.ndarray, y: np.ndarray, clusters: np.ndarray, beta_index: int, df_clusters: int) -> Tuple[float, float, float, float]:
    """Ajusta MCO y devuelve coeficiente, se cluster, e intervalo de confianza."""

    beta = np.linalg.solve(X.T @ X, X.T @ y)
    residuals = y - X @ beta
    se_vec, _ = cluster_robust_se(X, residuals, clusters)
    se = float(se_vec[beta_index])
    coef = float(beta[beta_index])
    crit = critical_value(df_clusters)
    ci_lower = coef - crit * se
    ci_upper = coef + crit * se
    return coef, se, ci_lower, ci_upper


def run_replications(n: int, reps: int, violation: bool, base_seed: int, estimator_labels: Tuple[str, str]) -> List[EstimationRecord]:
    """Ejecuta las réplicas para un escenario específico."""

    scenario_rng = np.random.default_rng(base_seed)
    scenario_name = "violacion" if violation else "base"
    records: List[EstimationRecord] = []
    df_clusters = n - 1  # grados de libertad para SE clusterizados

    for r in range(1, reps + 1):
        panel = simulate_panel(n=n, rng=scenario_rng, violation=violation)

        # Estimador DiD básico
        X_basic, y_basic, clusters = design_matrix_basic(panel)
        coef, se, ci_l, ci_u = estimate_model(X_basic, y_basic, clusters, beta_index=3, df_clusters=df_clusters)
        records.append(
            EstimationRecord(
                repetition=r,
                n=n,
                scenario=scenario_name,
                estimator=estimator_labels[0],
                estimate=coef,
                std_error=se,
                ci_lower=ci_l,
                ci_upper=ci_u,
                covered=ci_l <= ATT_TRUE <= ci_u,
            )
        )

        # Estimador DiD con efectos fijos + X
        X_twfe, y_twfe, clusters_twfe = design_matrix_twfe(panel)
        # índice del coeficiente de interés (const, post, interaction, x, ...)
        coef_twfe, se_twfe, ci_l_twfe, ci_u_twfe = estimate_model(
            X_twfe,
            y_twfe,
            clusters_twfe,
            beta_index=2,
            df_clusters=df_clusters,
        )
        records.append(
            EstimationRecord(
                repetition=r,
                n=n,
                scenario=scenario_name,
                estimator=estimator_labels[1],
                estimate=coef_twfe,
                std_error=se_twfe,
                ci_lower=ci_l_twfe,
                ci_upper=ci_u_twfe,
                covered=ci_l_twfe <= ATT_TRUE <= ci_u_twfe,
            )
        )

    return records


def summarize_records(df: pd.DataFrame) -> pd.DataFrame:
    """Calcula estadísticos resumen para cada estimador y escenario."""

    grouped = df.groupby(["n", "scenario", "estimator"])
    summary = grouped.agg(
        mean_estimate=("estimate", "mean"),
        bias=("estimate", lambda s: float(s.mean() - ATT_TRUE)),
        variance=("estimate", "var"),
        mse=("estimate", lambda s: float(((s - ATT_TRUE) ** 2).mean())),
        mean_se=("std_error", "mean"),
        coverage=("covered", "mean"),
    )
    summary.reset_index(inplace=True)
    summary.sort_values(["n", "scenario", "estimator"], inplace=True)
    return summary


def parse_arguments(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simulación DiD - Examen Final 2T 2025 (Ejercicio 4)")
    parser.add_argument("--reps", type=int, default=DEFAULT_REPS, help="Número de réplicas de Monte Carlo (default: 1000)")
    parser.add_argument(
        "--n",
        type=int,
        nargs="+",
        default=[DEFAULT_N],
        help="Número(s) de unidades de corte transversal a simular (default: 100)",
    )
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED, help="Semilla maestra del generador aleatorio")
    parser.add_argument(
        "--labels",
        nargs=2,
        default=("did_basico", "did_twfe_x"),
        metavar=("BASIC", "TWFE"),
        help="Etiquetas para los dos estimadores reportados",
    )
    return parser.parse_known_args(argv)


def main(argv: Iterable[str]) -> None:
    args, unknown = parse_arguments(argv)
    if unknown:
        print(f"[advertencia] argumentos no reconocidos ignorados: {unknown}", file=sys.stderr)

    rng_master = np.random.default_rng(args.seed)
    all_records: List[EstimationRecord] = []

    for n in args.n:
        for violation in (False, True):
            scenario_seed = int(rng_master.integers(0, 2**63 - 1))
            records = run_replications(
                n=n,
                reps=args.reps,
                violation=violation,
                base_seed=scenario_seed,
                estimator_labels=tuple(args.labels),
            )
            all_records.extend(records)

    results_df = pd.DataFrame([record.__dict__ for record in all_records])
    summary_df = summarize_records(results_df)

    pd.set_option("display.float_format", lambda v: f"{v:0.4f}")
    print("=== Resumen de simulaciones (promedios sobre réplicas) ===")
    print(summary_df)


if __name__ == "__main__":
    main(sys.argv[1:])
