# Wyniki benchmarków JuliaCity

Wygenerowane przez `bench/run_all.jl` (D-06). Reprodukuj komendą:

```bash
bash bench/uruchom.sh
# lub na Windows:
pwsh bench/uruchom.ps1
```

## Środowisko

- Julia: 1.12.6
- OS: NT
- CPU: 13th Gen Intel(R) Core(TM) i7-1355U
- Wątki: 12
- Data: 2026-05-04T08:06:41.242

## Microbenchmarki

Pomiary `BenchmarkTools.@benchmark` (evals=1, fresh-per-sample setup) — median z 200 probek.

| Funkcja | Median time (μs) | Memory (B) | Alokacje |
| --- | --- | --- | --- |
| `oblicz_energie (3-arg, N=1000)` | 289.500 | 5024 | 64 |
| `symuluj_krok! (SA-2-opt, N=1000)` | 0.600 | 0 | 0 |

## Jakość trasy (bench_jakosc)

Aggregate po 5 seedach × N=1000 × 50000 kroków SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).

**Headline:** SA znajduje trasę średnio 4.4% krótszą niż NN baseline.

| Statystyka | Wartość |
| --- | --- |
| mean ratio | 0.9559 |
| std ratio | 0.0179 |
| min ratio | 0.9289 |
| max ratio | 0.9743 |

Per-seed:

- seed=42: 0.9672
- seed=123: 0.9482
- seed=456: 0.9607
- seed=789: 0.9289
- seed=2025: 0.9743

