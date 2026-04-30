---
phase: 04-demo-benchmarks-documentation
plan: 05
subsystem: benchmarks
tags: [bench, quality, sa, nn-baseline, multi-seed, phase-4]
requires:
  - "JuliaCity.uruchom_sa! (Phase 2)"
  - "JuliaCity.SimAnnealing(stan; T_zero) constructor (Phase 2)"
  - "JuliaCity.inicjuj_nn! (Phase 2 baselines.jl)"
  - "JuliaCity.generuj_punkty (Phase 1)"
  - "JuliaCity.StanSymulacji (Phase 1)"
  - "JuliaCity.Parametry (Phase 1)"
  - "Statistics stdlib (mean, std)"
  - "Random stdlib (Xoshiro)"
provides:
  - "bench/bench_jakosc.jl - quality benchmark SA vs NN baseline (5 seedow aggregate)"
  - "Headline number dla README D-15 sekcja 7 (mean ratio z 5 seedow x N=1000)"
  - "NamedTuple{seeds, ratios, mean_ratio, std_ratio, min_ratio, max_ratio, n, liczba_krokow} kontrakt dla bench/run_all.jl orchestrator"
affects:
  - "bench/run_all.jl (Wave 3) - planned consumer of main() return value"
  - "README.md (plan 04-08) - planned consumer of headline mean_ratio"
tech-stack:
  added: []
  patterns:
    - "Multi-seed SA benchmark fixture: for seed in SEEDS -> StanSymulacji(rng=Xoshiro(seed)) -> inicjuj_nn! -> capture energia_nn -> SimAnnealing(T_zero=0.001) -> uruchom_sa! -> ratio"
    - "Phase 2 plan 02-14 erratum reproduction (T_zero=0.001 hardcoded override)"
    - "function main() wrapper z 'if abspath(PROGRAM_FILE) == @__FILE__' standalone guard (no top-level main() call - orchestrator-friendly)"
    - "@info po polsku - 3 lokalizacje (start banner + per-seed log + final aggregate)"
key-files:
  created:
    - "bench/bench_jakosc.jl"
  modified: []
decisions:
  - "T_zero=0.001 HARDCODED w SimAnnealing(stan; T_zero=0.001) - Phase 2 plan 02-14 erratum LOCKED. Bez tego override default 2sigma kalibracja wyrzuca SA z basena NN-start, ratio rosnie do ~0.97 (regresja jakosci). Threat T-04-05-01 mitigated."
  - "SEEDS = [42, 123, 456, 789, 2025] - exact list z D-08, NIE losowy. Threat T-04-05-02 mitigated."
  - "params = Parametry(liczba_krokow=50_000) - patience early-stop moze zakonczyc wczesniej; raportujemy stan.iteracja jako rzeczywisty count w @info."
  - "NamedTuple return type z polami seeds/ratios/mean_ratio/std_ratio/min_ratio/max_ratio/n/liczba_krokow - pelny kontrakt dla orchestrator (Wave 3 plan 04-06)."
  - "ASCII-only komentarze + brak diakrytykow w literalach @info (LANG-02 satisfied; format messages bez gwarancji typografii)."
  - "Brak top-level main() call - orchestrator wywola przez include + manual Main.main() bez side effects."
  - "Standalone-runnable przez 'if abspath(PROGRAM_FILE) == @__FILE__' guard z println summary (60-col separator)."
metrics:
  duration: "~10 min wallclock (planning context load + write + verify + commit)"
  completed-date: "2026-04-30"
  tasks: 1
  files-touched: 1
  commits: 1
---

# Phase 04 Plan 05: bench_jakosc.jl Summary

Quality benchmark `bench/bench_jakosc.jl` mierzy jakosc trasy SA vs NN baseline na 5 seedach x N=1000 x 50_000 krokow z `T_zero=0.001` override (Phase 2 plan 02-14 erratum lock); zwraca NamedTuple z mean/std/min/max ratio dla orchestratora i headline number README.

## Wykonane zadania

| Task | Name                                | Commit  | Files                       |
| ---- | ----------------------------------- | ------- | --------------------------- |
| 1    | Utworz bench/bench_jakosc.jl        | aa8c24d | bench/bench_jakosc.jl (NEW) |

## Co zostalo dostarczone

### `bench/bench_jakosc.jl` (83 linii)

**Public contract:** `function main()::NamedTuple` z polami:
- `seeds::Vector{Int}` = `[42, 123, 456, 789, 2025]`
- `ratios::Vector{Float64}` (5 wartosci, kazdy ratio = stan.energia / energia_nn po SA)
- `mean_ratio::Float64` (Statistics.mean)
- `std_ratio::Float64` (Statistics.std)
- `min_ratio::Float64` (minimum)
- `max_ratio::Float64` (maximum)
- `n::Int` = 1000
- `liczba_krokow::Int` = 50_000

**Fixture pattern per seed (loop body):**
```julia
punkty = generuj_punkty(N; seed=seed)
stan = StanSymulacji(punkty; rng=Xoshiro(seed))
inicjuj_nn!(stan)
energia_nn = stan.energia                          # capture PRZED SA
alg = SimAnnealing(stan; T_zero=0.001)             # erratum lock (Phase 2 plan 02-14)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=50_000)           # D-08 budget
uruchom_sa!(stan, params, alg)                     # patience early-stop
ratio = stan.energia / energia_nn
```

**Standalone uruchomienie:**
```bash
julia --project=. --threads=auto bench/bench_jakosc.jl
```
Drukuje 60-col formatowane podsumowanie do stdout (mean / std / min / max ratio).

**Orchestrator uruchomienie (Wave 3):**
```julia
include("bench/bench_jakosc.jl")
wynik = Main.main()  # NamedTuple
```

## Weryfikacja akceptacyjna

Wszystkie kryteria z `<acceptance_criteria>` planu spelnione:

| Check                                                         | Status |
| ------------------------------------------------------------- | ------ |
| `bench/bench_jakosc.jl` istnieje                              | PASS   |
| Literalna lista `[42, 123, 456, 789, 2025]` (D-08)            | PASS   |
| Literalny string `T_zero=0.001` (Phase 2 erratum lock)        | PASS   |
| Literalny string `uruchom_sa!` (NIE goly `symuluj_krok!` loop)| PASS   |
| Literalny string `inicjuj_nn!` (NN baseline init)             | PASS   |
| `using Statistics: mean, std`                                 | PASS   |
| `LICZBA_KROKOW = 50_000` (D-08 budget)                        | PASS   |
| `function main()`                                             | PASS   |
| Pola NamedTuple `mean_ratio` + `std_ratio` (grep)             | PASS   |
| Header docstring zaczyna od `# bench/bench_jakosc.jl`         | PASS   |
| `@info` count >= 3 (start, per-seed, final)                   | PASS (3) |
| Brak top-level `main()` call                                  | PASS   |
| BOM-free (head -c 3 = `# b`, NIE `0xEF 0xBB 0xBF`)            | PASS   |
| LF only (no CRLF)                                             | PASS   |
| Final newline                                                 | PASS   |
| ASCII-only identyfikatory + komentarze                        | PASS   |

## Pokryte wymagania

- **BENCH-03** — Quality benchmark SA vs NN baseline (multi-seed aggregate); skrypt zwraca metryki `mean_ratio`, `std_ratio`, `min_ratio`, `max_ratio`.
- **BENCH-04** — Reproducible benchmark protocol; uzywa Phase 2 plan 02-14 erratum fixture (T_zero=0.001, 5 fixed seeds, deterministyczny RNG=Xoshiro per seed).

## Decyzje techniczne i pulapki

### LOCKED erratum reproduction (Phase 2 plan 02-14)

Kluczowa decyzja: `SimAnnealing(stan; T_zero=0.001)` HARDCODED, NIE default kalibracji 2sigma. Default kalibracja `kalibruj_T0(...)` daje T_zero rzedu sigmy delty energii (typowo ~0.04+ dla N=1000), co wyrzuca SA z basena NN-start (Metropolis akceptuje wzrosty energii) i konsekwentny ratio rosnie do ~0.97 (regresja zamiast poprawy). Phase 2 TEST-05 lock na ratio=0.9408 byl osiagniety wlasnie z T_zero=0.001 - low-temp local search 2-opt nad NN-start.

### NamedTuple zamiast Dict

Return type to immutable NamedTuple - type-stable, zero-alloc dla pola access (`wynik.mean_ratio`), brak boxingu w orchestrator consume site. Kontrakt staly dla Wave 3.

### `inicjuj_nn!` automatycznie ustawia `stan.energia`

Phase 2 D-08 invariant: po `inicjuj_nn!(stan)`, `stan.energia == oblicz_energie(stan.D, stan.trasa)`. Wystarczy `energia_nn = stan.energia` po init, bez re-computing. Skrot zachowany, brak duplikacji.

### `stan.iteracja` jako rzeczywisty count

`uruchom_sa!` z patience early-stop (Phase 2) moze zakonczyc symulacje przed `liczba_krokow=50_000`. Per-seed `@info` raportuje `iter=$(stan.iteracja)` pokazujac faktyczna liczbe krokow - debugging hook dla bench/wyniki.md (Wave 3) jesli aggregate ratio wykazuje anomalie.

## Deviations from Plan

None - plan executed exactly as written.

Wszystkie acceptance criteria spelnione bez zmian. Plan dostarczyl pelny kod do skopiowania w `<action>` block, ktory zostal uzyty 1:1 (z drobna zamiana `±` na `+/-` w @info string dla pelnej ASCII-safety - ale plan explicit instruowal "bez diakrytykow" w komentarzach + literalach).

## Self-Check: PASSED

Verified post-write:
- `bench/bench_jakosc.jl` FOUND (file exists, 83 linii)
- Commit `aa8c24d` FOUND in `git log` (feat(04-05): add bench/bench_jakosc.jl...)
- All 16 acceptance checks PASS (see table above)
- Encoding: ASCII-only, LF, BOM-free, final newline confirmed via `file` + `od`

## Threat Flags

None - plan execution did not introduce security-relevant surface beyond plan's `<threat_model>`. Threats T-04-05-01 (T_zero tampering) and T-04-05-02 (seed list tampering) explicitly mitigated via literal acceptance checks. T-04-05-03 (~5 min wallclock DoS) accepted per plan disposition.

## Empiryczna weryfikacja (deferred)

Plan instructs verification through `bench/uruchom.sh` / `pwsh bench/uruchom.ps1` wrapper (tworzony w plan 04-06 Task 0). Standalone `julia --project=. bench/bench_jakosc.jl` smoke test NIE byl uruchamiany w tym planie (~5 min wallclock + Wave 2 parallel execution). Empiryczne `mean_ratio ≈ 0.94 ± 0.01` (extrapolacja TEST-05 lock 0.9408) zostanie zwerifikowane w Wave 3 plan 04-06 (run_all.jl) lub plan 04-08 (README headline regen).

## Next Steps

1. **Wave 3 plan 04-06** - `bench/run_all.jl` orchestrator wywola `include("bench/bench_jakosc.jl"); Main.main()` i skonsumuje NamedTuple do markdown table render.
2. **Wave 3 plan 04-08** - README.md headline `"SA znajduje trase srednio ~6% krotsza niz NN baseline (5 seedow x N=1000)"` regenerowany na podstawie `wynik.mean_ratio` z `bench/wyniki.md`.
3. **Walidacja empiryczna** - dev uruchamia `bash bench/uruchom.sh` (po plan 04-06 Task 0) celem regen `bench/wyniki.md` i potwierdzenia mean_ratio < 0.96.
