"""Simulaciones de Monte Carlo para el Ejercicio 2 del examen.

Implementa el estimador de Propensity Score Matching (vecino más cercano 1:1 con
reemplazo) para N = 100 y N = 200 usando 1,000 réplicas. Calcula sesgo, varianza,
MSE y cobertura de intervalos de confianza al 95% utilizando errores estándar
bootstrap con 200 remuestras por réplica.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from numpy.linalg import LinAlgError
from scipy.special import expit
from joblib import Parallel, delayed

TRUE_ATE = 4.0
REPLICATIONS = 1_000
BOOTSTRAP_REPS = 200
SAMPLE_SIZES = (100, 200)
SEED = 12345  # reemplazar por los últimos 5 dígitos del documento si se desea reproducir otro escenario


@dataclass
class SimulationSummary:
    bias: float
    variance: float
    mse: float
    coverage: float


def simulate_sample(n: int, rng: np.random.Generator) -> tuple[np.ndarray, ...]:
    """Genera una muestra del DGP del ejercicio 2."""
    x1 = rng.normal(loc=0.0, scale=1.0, size=n)
    x2 = rng.binomial(n=1, p=0.5, size=n)

    logits = 0.5 + x1 + 2 * x2
    propensity = 1.0 / (1.0 + np.exp(-logits))
    d = rng.binomial(n=1, p=propensity)

    u = rng.normal(loc=0.0, scale=1.0, size=n)
    y = 1 + 4 * d + x1 + 3 * x2 + u
    return x1, x2, d, y


def estimate_propensity_scores(x1: np.ndarray, x2: np.ndarray, d: np.ndarray) -> np.ndarray:
    """Ajusta un modelo Logit mediante Newton-Raphson para obtener los propensity scores."""
    if np.unique(d).size < 2:
        raise ValueError("No es posible ajustar el logit: la muestra contiene una sola clase.")

    X = np.column_stack([np.ones_like(x1), x1, x2])
    beta = np.zeros(X.shape[1], dtype=float)

    for _ in range(50):
        z = X @ beta
        p = expit(z)
        w = p * (1.0 - p)
        # Evita pesos exactamente nulos
        w = np.clip(w, 1e-6, None)

        grad = X.T @ (d - p)
        hessian = X.T @ (w[:, None] * X) + 1e-6 * np.eye(X.shape[1])

        try:
            delta = np.linalg.solve(hessian, grad)
        except LinAlgError as exc:
            raise RuntimeError("Fallo al invertir la matriz Hessiana en el logit.") from exc

        beta += delta

        if np.linalg.norm(delta, ord=np.inf) < 1e-6:
            break

    propensity = expit(X @ beta)
    return propensity


def nearest_neighbor_matching(y: np.ndarray, d: np.ndarray, ps: np.ndarray) -> float:
    """Calcula el estimador de matching 1:1 con reemplazo."""
    treated_idx = np.where(d == 1)[0]
    control_idx = np.where(d == 0)[0]

    if treated_idx.size == 0 or control_idx.size == 0:
        raise ValueError("La muestra no contiene ambos grupos necesarios para el matching.")

    treated_ps = ps[treated_idx]
    control_ps = ps[control_idx]

    order = np.argsort(control_ps)
    sorted_control_ps = control_ps[order]
    sorted_control_idx = control_idx[order]

    positions = np.searchsorted(sorted_control_ps, treated_ps, side="left")
    left_pos = np.clip(positions - 1, 0, sorted_control_ps.size - 1)
    right_pos = np.clip(positions, 0, sorted_control_ps.size - 1)

    left_diff = np.abs(treated_ps - sorted_control_ps[left_pos])
    right_diff = np.abs(treated_ps - sorted_control_ps[right_pos])
    use_right = right_diff < left_diff
    chosen_positions = np.where(use_right, right_pos, left_pos)
    matched_controls = sorted_control_idx[chosen_positions]

    diffs = y[treated_idx] - y[matched_controls]
    return float(diffs.mean())


def estimate_ate(x1: np.ndarray, x2: np.ndarray, d: np.ndarray, y: np.ndarray) -> float:
    ps = estimate_propensity_scores(x1, x2, d)
    return nearest_neighbor_matching(y, d, ps)


def bootstrap_se(x1: np.ndarray, x2: np.ndarray, d: np.ndarray, y: np.ndarray, rng: np.random.Generator) -> float:
    estimates = []
    n = y.size
    attempts = 0
    while len(estimates) < BOOTSTRAP_REPS and attempts < BOOTSTRAP_REPS * 10:
        sample_idx = rng.integers(0, n, size=n)
        if np.unique(d[sample_idx]).size < 2:
            attempts += 1
            continue
        try:
            estimates.append(estimate_ate(x1[sample_idx], x2[sample_idx], d[sample_idx], y[sample_idx]))
        except ValueError:
            attempts += 1
            continue
    if len(estimates) < 2:
        raise RuntimeError("No se pudo calcular un error estándar bootstrap válido tras múltiples intentos.")
    return float(np.std(estimates, ddof=1))


def _single_replication(seed: int, n: int) -> tuple[float, bool]:
    rng = np.random.default_rng(seed)
    while True:
        x1, x2, d, y = simulate_sample(n, rng)
        if np.unique(d).size < 2:
            continue
        try:
            ate_hat = estimate_ate(x1, x2, d, y)
            bootstrap_seed = rng.integers(0, 2**32 - 1)
            bootstrap_rng = np.random.default_rng(bootstrap_seed)
            se_hat = bootstrap_se(x1, x2, d, y, bootstrap_rng)
        except (ValueError, RuntimeError):
            continue
        break

    ci_lower = ate_hat - 1.96 * se_hat
    ci_upper = ate_hat + 1.96 * se_hat
    coverage = ci_lower <= TRUE_ATE <= ci_upper
    return ate_hat, coverage


def run_simulation(n: int, base_rng: np.random.Generator) -> SimulationSummary:
    seeds = base_rng.integers(0, 2**32 - 1, size=REPLICATIONS)
    outputs = Parallel(n_jobs=-1, backend="loky")(
        delayed(_single_replication)(int(seed), n) for seed in seeds
    )

    ate_estimates = np.fromiter((o[0] for o in outputs), dtype=float, count=REPLICATIONS)
    coverage_flags = np.fromiter((o[1] for o in outputs), dtype=bool, count=REPLICATIONS)

    bias = ate_estimates.mean() - TRUE_ATE
    variance = ate_estimates.var(ddof=1)
    mse = np.mean((ate_estimates - TRUE_ATE) ** 2)
    coverage = coverage_flags.mean()

    return SimulationSummary(bias=bias, variance=variance, mse=mse, coverage=coverage)


def main() -> None:
    rng = np.random.default_rng(SEED)
    rows = []
    for n in SAMPLE_SIZES:
        summary = run_simulation(n, rng)
        rows.append({
            "N": n,
            "Bias": summary.bias,
            "Variance": summary.variance,
            "MSE": summary.mse,
            "Coverage": summary.coverage,
        })

    df = pd.DataFrame(rows)
    print("Resultados del Ejercicio 2 (Propensity Score Matching):")
    print(df.to_string(index=False, float_format=lambda x: f"{x:0.4f}"))


if __name__ == "__main__":
    main()
