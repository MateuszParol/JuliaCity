# JuliaCity

Pakiet w języku Julia rozwiązujący problem komiwojażera (TSP) heurystyką
inspirowaną fizyką błony mydlanej. Cel: 1000 losowych punktów 2D, animowane
„zaciąganie" trasy o minimalnej energii.

> **Status:** Phase 1 (Bootstrap) — szkielet pakietu, encoding hygiene,
> parametryczny `StanSymulacji`, deterministyczny `generuj_punkty`. Pełna
> dokumentacja, demo GIF i benchmarki dochodzą w Phase 4.

## Wymagania

- Julia ≥ 1.10 (zalecane: 1.11 lub 1.12 — patrz `.github/workflows/CI.yml`)
- System: Linux / macOS / Windows

## Instalacja (deweloperska)

```julia
# W REPL Julii, w katalogu repo:
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## Quickstart

```julia
using JuliaCity

punkty = generuj_punkty(1000; seed=42)
@assert length(punkty) == 1000
```

Pełne demo (`examples/podstawowy.jl`) i animacja GLMakie dochodzą w Phase 3/4.

## Licencja

MIT — patrz `LICENSE`.
