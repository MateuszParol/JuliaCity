---
phase: 04-demo-benchmarks-documentation
plan: 04
subsystem: benchmarks
tags: [benchmark, BenchmarkTools, microbench, oblicz_energie, symuluj_krok, fresh-fixture, sample-stationarity]
requires:
  - "Project.toml [targets].test += BenchmarkTools (Wave 1, plan 04-01)"
  - "JuliaCity.oblicz_energie 3-arg (Phase 2 D-08, zero-alloc po warmup)"
  - "JuliaCity.symuluj_krok! (Phase 2 ALG-02/TEST-03, @allocated == 0 po warmup)"
  - "JuliaCity.inicjuj_nn! / StanSymulacji / Parametry / SimAnnealing (Phase 2)"
  - "StableRNGs (test-deps via Wave 1)"
provides:
  - "bench/bench_energia.jl — microbench oblicz_energie(3-arg) na fixture N=1000 (BENCH-01, BENCH-04)"
  - "bench/bench_krok.jl — microbench symuluj_krok! z fresh stan per sample (BENCH-02, BENCH-04)"
  - "Empiryczna walidacja Phase 2 D-08 zero-alloc gwarancji (po Wave 3 orchestratorze 04-06)"
affects:
  - "bench/run_all.jl (plan 04-06, Wave 3) — orchestrator ładuje oba skrypty w izolowanych modułach"
  - "bench/wyniki.md (plan 04-06) — tabele wyników wypełniane przez orchestratora"
tech_added: []
tech_patterns:
  - "BenchmarkTools.@benchmark + setup= z fresh fixture per sample (sample stationarity)"
  - "evals=1 dla czytelnego per-call allocs (zero-alloc weryfikacja)"
  - "samples=200 seconds=5 jako bound wallclock"
  - "Captured locals z setup= (NIE \$ interpolation — BenchmarkTools widzi setup-locals automatycznie)"
  - "1× warmup `symuluj_krok!` w setup= dla mid-flight measurement (NIE first-step compile)"
  - "function main() wrapper bez top-level call (orchestrator: Base.invokelatest)"
key_files:
  created:
    - bench/bench_energia.jl
    - bench/bench_krok.jl
  modified: []
decisions:
  - "Fresh-fixture-per-sample uniform pattern w obu skryptach (uniform consistency, sample stationarity per checker iteracja 1 BLOCKER #2)"
  - "Default kalibracja w bench_krok (NIE T_zero=0.001 erratum override — to tylko bench_jakosc territory)"
  - "Brak standalone PROGRAM_FILE branch — uruchamianie wyłącznie przez bench/uruchom.{sh,ps1} wrapper (Wave 3 plan 04-08, BLOCKER #4)"
  - "Brak top-level main() call — orchestrator robi Base.invokelatest(m.main) w izolowanym module (BLOCKER #3 fix)"
metrics:
  duration: "~10 min"
  completed: "2026-04-30"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 4 Plan 04: Microbenchmarks (bench_energia + bench_krok) Summary

Dwa BenchmarkTools microbenchmarki dla najgorętszych funkcji core'u (`oblicz_energie` 3-arg threaded oraz `symuluj_krok!` jeden krok SA), używające fresh-fixture-per-sample setup= dla stationarity i evals=1 dla czytelnego pomiaru zero-alloc gwarancji Phase 2 D-08/TEST-03.

## Wykonane zadania

| Task | Nazwa                                                | Commit  | Pliki                  |
| ---- | ---------------------------------------------------- | ------- | ---------------------- |
| 1    | bench/bench_energia.jl (fresh fixture per sample)    | 4b7292d | bench/bench_energia.jl |
| 2    | bench/bench_krok.jl (fresh stan per sample)          | f526dbd | bench/bench_krok.jl    |

## Co zostało zbudowane

### `bench/bench_energia.jl` (39 linii, BENCH-01, BENCH-04)

`@benchmark` na `oblicz_energie(stan.D, stan.trasa, bufor)` (3-arg threaded path, Phase 2 D-08 zero-alloc po warmup). Setup buduje fresh fixture per próbka:

```
rng = StableRNG(42)
punkty = generuj_punkty(1000; seed=42)
stan = StanSymulacji(punkty)
inicjuj_nn!(stan)                   # ustawia stan.D, stan.trasa, stan.energia
bufor = zeros(Float64, Threads.nthreads())
```

Body: `oblicz_energie(stan.D, stan.trasa, bufor)`. `evals=1 samples=200 seconds=5`.

### `bench/bench_krok.jl` (43 linii, BENCH-02, BENCH-04)

`@benchmark` na `symuluj_krok!(stan, params, alg)` (jeden krok SA z delta-energy + Metropolis + cooling). Setup buduje FRESH `stan` per próbka i wykonuje 1× warmup step PRZED pomiarem:

```
rng = StableRNG(42)
punkty = generuj_punkty(1000; seed=42)
stan = StanSymulacji(punkty)
inicjuj_nn!(stan)
params = Parametry(liczba_krokow=50_000)
alg = SimAnnealing(stan)            # default kalibruj_T0 (NIE T_zero=0.001)
stan.temperatura = alg.T_zero
symuluj_krok!(stan, params, alg)    # warmup → mid-flight measurement
```

Body: `symuluj_krok!(stan, params, alg)`. `evals=1 samples=200 seconds=5`.

## Krytyczne wybory implementacyjne

**Fresh-stan-per-sample (BLOCKER #2 fix).** Poprzednia (przed-iteracja-1) wersja `bench_krok` używała `setup=(symuluj_krok!($stan, ...))` z modyfikowaniem TEGO SAMEGO `stan` przez tysiące samples — `stan.iteracja` przekraczała `Parametry.liczba_krokow=50_000` i SA-loop semantyka driftowała daleko od pomiaru fresh single-step. Obecny pattern rebuilduje `stan` od zera per sample, więc każda próbka mierzy KRÓK 2 (po jednym warmup), nie krok N.

**Uniform setup pattern w obu skryptach.** `oblicz_energie` jest non-mutating, więc teoretycznie mógłby pominąć `inicjuj_nn!` w setup. Świadomie powielony pattern (StableRNG → generuj_punkty → StanSymulacji → inicjuj_nn! + bufor) upraszcza review i pasuje do Phase 2 D-08 zero-alloc warmup discipline (na fresh `stan` po inicjuj_nn! `oblicz_energie` ma poprawny `stan.D`).

**`evals=1` w obu.** Bez tego BenchmarkTools agreguje N evals w jedną próbkę (memory/allocs to suma), więc zero-alloc gwarancja jest nieczytelna. `evals=1` => `trial.allocs == 0` (Phase 2 TEST-03 lock empirycznie potwierdzane przez orchestrator Wave 3).

**Captured locals zamiast `$`.** W body benchmark używamy `stan`, `params`, `alg`, `bufor` jako captured locals z setup= block. BenchmarkTools widzi je automatycznie jako lokalne zmienne (NIE globals), więc nie potrzebujemy `$` interpolation. Pitfall „@btime bez $" dotyczy globals; setup-locals są bezpieczne.

**`function main()` wrapper bez top-level call.** Orchestrator (plan 04-06) ładuje skrypty w izolowanym module (`Module(:_BenchSandbox)`) i wywołuje `Base.invokelatest(m.main)` — kolizja `Main.main` byłaby BLOCKER #3. Skrypty MUSZĄ NIE wywoływać `main()` na końcu pliku.

**Brak standalone PROGRAM_FILE branch (BLOCKER #4).** `julia bench/bench_energia.jl` bezpośrednio NIE znajdzie BenchmarkTools (D-10 + Pkg.jl resolver limit). Uruchamianie wyłącznie przez `bench/uruchom.{sh,ps1}` wrapper (plan 04-08, Wave 3) który aktywuje throwaway env z BenchmarkTools dodanym tymczasowo.

**Default kalibracja w bench_krok.** `SimAnnealing(stan)` używa `kalibruj_T0(stan)` (default 2σ) — NIE `T_zero=0.001` override, który jest erratum-specific dla `bench_jakosc` (TEST-05 ratio 0.9408 z Phase 2 plan 02-14). Bench_krok mierzy "typowy" krok SA, nie reproducuje TEST-05 setupu.

## Wymagania pokryte

- **BENCH-01** — bench_energia.jl mierzy oblicz_energie z BenchmarkTools (median time + memory + allocs).
- **BENCH-02** — bench_krok.jl mierzy symuluj_krok! z BenchmarkTools (median time + memory + allocs).
- **BENCH-04** — `@benchmark` z `setup=` discipline, captured locals (NIE globals), evals=1 dla per-call alloc readability.

(BENCH-03 i BENCH-05 są pokrywane przez plan 04-05 bench_jakosc i plan 04-06 run_all/wyniki.md w Wave 3.)

## Verification & Acceptance

Standalone smoke test (z BenchmarkTools dostępnym w env):
```bash
julia --project=. -e 'using Pkg; Pkg.activate(temp=true); Pkg.develop(path="."); Pkg.add("BenchmarkTools"); include("bench/bench_energia.jl"); println(typeof(main()))'
# Expected: BenchmarkTools.Trial
```

Wszystkie acceptance criteria spełnione (literalne stringi `using BenchmarkTools`, `using JuliaCity`, `using StableRNGs: StableRNG`, `@benchmark`, `setup =`, `evals = 1`, `samples = 200`, `seconds = 5`, `function main()`, header docstring; brak `abspath(PROGRAM_FILE)`, brak top-level `main()` call, brak `T_zero=0.001` w bench_krok). BOM-free, LF, final newline, ASCII identyfikatory.

Empiryczne uruchomienie skryptów (czyli faktyczne wywołanie `main()` i sprawdzenie `trial.allocs`) odbędzie się w Wave 3 przez orchestrator (plan 04-06) — zgodnie z BLOCKER #3 izolowane moduły, BLOCKER #4 wrapper. Plan 04-04 dostarcza tylko same skrypty.

## Deviations from Plan

None — plan wykonany dokładnie jak napisany. Oba pliki utworzone z literalnym kodem z `<action>` blocks, wszystkie acceptance criteria pozytywnie zweryfikowane przez `grep`, encoding hygiene OK, zero deviation rules (1-4) triggered.

## Threat Flags

Brak — read-only deterministic compute, brak nowych trust boundaries (T-04-04-01 tampering risk zmitygowany przez fresh setup= per sample; T-04-04-02 sysinfo disclosure accepted per D-07).

## Self-Check: PASSED

- bench/bench_energia.jl: FOUND
- bench/bench_krok.jl: FOUND
- Commit 4b7292d: FOUND
- Commit f526dbd: FOUND
- Encoding (BOM-free, LF, final newline): VERIFIED on both files
- Acceptance criteria literal-string presence: ALL PASS via grep
- Negative criteria (no abspath, no top-level main(), no T_zero=0.001): ALL PASS

Next gate: Wave 3 orchestrator (plan 04-06) loads both scripts in isolated modules and writes empirical numbers to `bench/wyniki.md`. Wave 3 will be the first time `main()` is actually invoked end-to-end.
