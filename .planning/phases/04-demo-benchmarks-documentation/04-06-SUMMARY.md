---
phase: 04-demo-benchmarks-documentation
plan: 06
subsystem: benchmarks
tags: [bench, orchestrator, wrappers, module-isolation, phase-4]
requires:
  - "bench/bench_energia.jl (plan 04-04)"
  - "bench/bench_krok.jl (plan 04-04)"
  - "bench/bench_jakosc.jl (plan 04-05)"
  - "BenchmarkTools w Project.toml [extras] + [targets].test (plan 04-01)"
provides:
  - "bench/run_all.jl - orchestrator z module-isolated includes (BLOCKER #3 fix)"
  - "bench/uruchom.sh + bench/uruchom.ps1 - canonical runtime path z BenchmarkTools resolverem (BLOCKER #4 fix)"
  - "bench/wyniki.md - pierwszy snapshot empirycznych wynikow (BENCH-05)"
  - "Headline number `mean_ratio = 0.9559 (~4% krotsza niz NN)` dla README plan 04-08"
affects:
  - "README.md (plan 04-08) - konsumuje headline z bench/wyniki.md"
tech-stack:
  added: []
  patterns:
    - "Module isolation pattern: m = Module(:_BenchSandbox); Base.include(m, sciezka); Base.invokelatest(m.main) - kazdy bench script w osobnym anonimowym module, by Main.main orchestratora nie byl nadpisany"
    - "Throwaway env wrapper: Pkg.activate(temp=true) + Pkg.develop(path='.') + Pkg.add('BenchmarkTools') - D-10 honored (no bench/Project.toml)"
    - "Auto-detect resolver: julia --project=. -e 'using BenchmarkTools' check; direct invocation lub fallback do temp-env"
    - "Stable alphabetical microbench order: sort(collect(keys(wyniki))) - oblicz_energie < symuluj_krok! gwarantowane (Warning #3 fix)"
key-files:
  created:
    - "bench/run_all.jl"
    - "bench/uruchom.sh"
    - "bench/uruchom.ps1"
    - "bench/wyniki.md"
  modified: []
decisions:
  - "BLOCKER #3 fix przez Module isolation w _uruchom_bench: kazdy bench script w osobnym anonimowym module zapobiega nadpisaniu Main.main. Base.invokelatest konieczne dla world age semantics."
  - "BLOCKER #4 fix przez wrapper z auto-detect: julia --project=. nie widzi BenchmarkTools z [targets].test; fallback temp-env (Pkg.activate(temp=true) + Pkg.develop + Pkg.add) honoruje D-10 (no commitowany bench/Project.toml)."
  - "Warning #3 fix przez sort(collect(keys)): Dict iteration order jest niestabilny; alfabetyczny order gwarantuje stabilne diffy w bench/wyniki.md miedzy regen."
  - "Empiryczny mean_ratio = 0.9559 (4.4% krotsza), std_ratio = 0.0179 (≤ 0.02 - stabilne) - mieszczacy sie w D-08 ekstrapolacji 0.85-0.97 sanity range."
  - "Per-seed ratios stabilne: min=0.9289 (seed=789), max=0.9743 (seed=2025), spread ~5pp - akceptowalny dla N=1000 + 50k krokow SA."
metrics:
  duration: "Tasks 0+1 wykonane w worktree (commits f76b034, f498200, merge e6f396c); Task 2 (regen) wykonany lokalnie przez devela na Win11+Julia 1.12.6, 12-watkowy i7-1355U; ~5-10 min wallclock dominowanego przez bench_jakosc"
  completed-date: "2026-05-04"
  tasks: 3
  files-touched: 4
  commits: 4
---

# Phase 04 Plan 06: bench/run_all.jl + wrappery + wyniki.md Summary

Wave 3 dostarczyla orchestrator `bench/run_all.jl` (z module-isolated includes — BLOCKER #3 fix), dwa wrappery `bench/uruchom.{sh,ps1}` (z throwaway env recipe — BLOCKER #4 fix), oraz pierwszy empiryczny snapshot `bench/wyniki.md` z headline `mean_ratio = 0.9559` (~4% krotsza niz NN baseline) konsumowanym przez plan 04-08 README.

## Wykonane zadania

| Task | Name                                                          | Commit              | Files                                  |
| ---- | ------------------------------------------------------------- | ------------------- | -------------------------------------- |
| 0    | Utworz bench/uruchom.sh + bench/uruchom.ps1 (BLOCKER #4)      | f76b034             | bench/uruchom.sh, bench/uruchom.ps1    |
| 1    | Utworz bench/run_all.jl orchestrator (BLOCKER #3)             | f498200             | bench/run_all.jl                       |
| 2    | Pierwsza regeneracja bench/wyniki.md przez wrapper (human)    | cb51bce             | bench/wyniki.md                        |

Worktree merge: `e6f396c` (Tasks 0+1).

## Co zostalo dostarczone

### `bench/uruchom.sh` (POSIX wrapper)

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if julia --project=. -e 'using BenchmarkTools' >/dev/null 2>&1; then
    exec julia --project=. --threads=auto bench/run_all.jl
else
    exec julia --threads=auto --project=. -e '
        import Pkg
        Pkg.activate(temp=true)
        Pkg.develop(path=".")
        Pkg.add("BenchmarkTools")
        include("bench/run_all.jl")
    '
fi
```

Equivalentny `bench/uruchom.ps1` dla PowerShell (Windows + cross-platform Core).

### `bench/run_all.jl` orchestrator

Public contract — `function main()`:
1. `microbench = Dict{String, BenchmarkTools.Trial}()`
2. Sekwencyjnie: `_uruchom_bench("bench/bench_energia.jl")`, `_uruchom_bench("bench/bench_krok.jl")`, `_uruchom_bench("bench/bench_jakosc.jl")` — kazdy w osobnym anonimowym module.
3. Render do `bench/wyniki.md` przez 3 helpery: `_zbierz_metadane`, `_renderuj_microbench_tabele`, `_renderuj_jakosc_sekcje`.

Module isolation (BLOCKER #3 fix):

```julia
function _uruchom_bench(sciezka::String)
    m = Module(:_BenchSandbox)
    Base.include(m, sciezka)
    return Base.invokelatest(m.main)
end
```

Stable alphabetical microbench order (Warning #3 fix):

```julia
for nazwa in sort(collect(keys(wyniki)))
    f = _formatuj_trial(wyniki[nazwa])
    ...
end
```

### `bench/wyniki.md` (empiryczny snapshot)

Header + 3 sekcje:
- `## Środowisko` — Julia 1.12.6 / OS: NT / CPU: 13th Gen i7-1355U / Wątki: 12 / Data: 2026-05-04
- `## Microbenchmarki` — alfabetyczny order: `oblicz_energie (3-arg, N=1000)` 289.500 μs / 5024 B / 64 alloc; `symuluj_krok! (SA-2-opt, N=1000)` 0.600 μs / 0 B / 0 alloc
- `## Jakość trasy (bench_jakosc)` — headline: SA srednio 4.4% krotsza niz NN. Aggregate (mean/std/min/max) + per-seed listing.

Per-seed ratios:

| seed | ratio  |
| ---- | ------ |
| 42   | 0.9672 |
| 123  | 0.9482 |
| 456  | 0.9607 |
| 789  | 0.9289 |
| 2025 | 0.9743 |

mean=0.9559, std=0.0179 (≤ 0.02 → stabilne), min=0.9289, max=0.9743.

## Weryfikacja akceptacyjna

Wszystkie kryteria z `<acceptance_criteria>` planu spelnione:

| Check                                                               | Status |
| ------------------------------------------------------------------- | ------ |
| `bench/uruchom.sh` istnieje + `set -euo pipefail` + auto-detect     | PASS   |
| `bench/uruchom.ps1` istnieje + `$ErrorActionPreference = 'Stop'`    | PASS   |
| `Pkg.activate(temp=true)` + `Pkg.develop(path=".")` + `Pkg.add`     | PASS   |
| `include("bench/run_all.jl")` w fallback                            | PASS   |
| `bench/run_all.jl` istnieje + 5 helperow `_*`                       | PASS   |
| `Module(`, `Base.include(m,`, `Base.invokelatest(m.main)` (BLK #3)  | PASS   |
| 3 wywolania `_uruchom_bench(joinpath(@__DIR__, ...))`               | PASS   |
| `using BenchmarkTools`, `Statistics: median`, `Dates: now`          | PASS   |
| `Sys.cpu_info()[1].model` w try/catch                               | PASS   |
| `T_zero=0.001` w bench_jakosc opisie                                | PASS   |
| `(1 - j.mean_ratio) * 100` headline computation                     | PASS   |
| `## Środowisko`, `Wątki`, `## Jakość trasy` (polskie diakrytyki)    | PASS   |
| `sort(collect(keys` w `_renderuj_microbench_tabele` (Warning #3)    | PASS   |
| `bash bench/uruchom.sh` w komendzie reprodukcji w wyniki.md         | PASS   |
| 1 top-level `main()` call                                           | PASS   |
| `bench/wyniki.md` istnieje, scommitowany, 3 sekcje                  | PASS   |
| Microbench rows alfabetycznie (oblicz_energie < symuluj_krok!)      | PASS   |
| Headline z `%` w sekcji Jakosc                                      | PASS   |
| `mean_ratio ∈ [0.85, 0.97]` (D-08 sanity)                           | PASS (0.9559) |
| BOM-free, LF, final newline na wszystkich plikach                   | PASS   |

## Pokryte wymagania

- **BENCH-01** — Microbench `oblicz_energie` (3-arg, threaded) w `bench/wyniki.md`.
- **BENCH-02** — Microbench `symuluj_krok!` (SA-2-opt + Metropolis) w `bench/wyniki.md`.
- **BENCH-03** — Quality benchmark SA vs NN baseline w `bench/wyniki.md` (5 seedow aggregate).
- **BENCH-05** — Wyniki tabelaryczne, plik commitowany.
- **LANG-02** — Polski w komentarzach, `@info`, naglowkach `## Środowisko / ## Microbenchmarki / ## Jakość trasy`.

## Decyzje techniczne i pulapki

### Module isolation pattern (BLOCKER #3 fix)

Sekwencyjny `include(bench_*.jl)` w Main scope nadpisuje `Main.main` przy kazdym kolejnym bench scripte. Po 3 includach top-level `main()` orchestratora wywolaloby ostatnio-zaladowany bench main, NIE orchestrator. Module isolation rozwiazuje:

```julia
m = Module(:_BenchSandbox)        # nowy anonimowy module per call
Base.include(m, sciezka)          # bench main definiowany w m, nie Main
return Base.invokelatest(m.main)  # invokelatest dla world age fix
```

`Base.invokelatest` jest konieczne — `Base.include` definiuje `m.main` w runtime, a wywolanie z orchestrator main wymaga forced re-dispatch (Julia world age semantics).

### Throwaway env (BLOCKER #4 fix)

`julia --project=. bench/run_all.jl` zglasza `Package BenchmarkTools not found in current path` poniewaz BenchmarkTools jest w `Project.toml [extras] + [targets].test`, a plain script execution NIE aktywuje target.test scope. Wrapper omija ograniczenie przez throwaway env z runtime install:

```julia
Pkg.activate(temp=true)        # /tmp/jl_XXXX/Project.toml — GC po wyjsciu z Julia
Pkg.develop(path=".")          # JuliaCity dostepny lokalnie, nie przez registry
Pkg.add("BenchmarkTools")      # tylko w throwaway env, NIE persistowane
include("bench/run_all.jl")
```

D-10 LOCKED honored: zaden `bench/Project.toml` nie jest commitowany.

### Auto-detect direct path

Wrapper sprawdza `julia --project=. -e 'using BenchmarkTools'` exit 0 PRZED throwaway env. Pozwala uniknac ~30s setup overhead Pkg.add jesli BenchmarkTools przypadkiem juz dostepny (np. po `Pkg.test()` ktory wciagnal go do project).

### Alphabetical microbench order (Warning #3 fix)

Dict iteration order w Julii NIE jest stabilny miedzy uruchomieniami. Alfabetyczny order (`sort(collect(keys(wyniki)))`) gwarantuje:
- `oblicz_energie (3-arg, N=1000)` ZAWSZE pojawia sie PRZED `symuluj_krok! (SA-2-opt, N=1000)`
- Diff bench/wyniki.md miedzy regen pokazuje TYLKO realne zmiany czasow, nie permutacje wierszy
- README plan 04-08 moze polegac na pozycji wierszy

### Empiryczny headline (mean_ratio = 0.9559)

5 seedow aggregate dal mean_ratio 0.9559, std_ratio 0.0179. Headline sformulowany w bench/wyniki.md jako `4.4% krotsza`. README plan 04-08 zaokraglil do `~4%` (per Warning #2 guard: std ≤ 0.02 → integer rounding OK).

Sanity: `mean_ratio ∈ [0.85, 0.97]` z D-08 — PASS. Per-seed spread 5pp (0.9289..0.9743) akceptowalny dla 50k krokow SA na N=1000 (LOCKED z plan 02-14 erratum T_zero=0.001).

## Deviations from Plan

**Task 2 (regen wyniki.md) wykonany przez human, NIE agent.** Plan oznaczył Task 2 jako `checkpoint:human-action gate="blocking"` z uzasadnieniem `~5-10 min wallclock`. Developer uruchomil `bash bench/uruchom.sh` lokalnie i scommitowal `bench/wyniki.md` w cb51bce. Zgodne z planem — checkpoint wymagal RECZNEGO uruchomienia wrappera.

Brak deviations w Task 0 i Task 1 (oba auto, wykonane przez executor agenta w worktree).

## Self-Check: PASSED

Verified post-execution:
- `bench/run_all.jl` FOUND (5 helperow `_*`, Module isolation, alphabetical sort)
- `bench/uruchom.sh` + `bench/uruchom.ps1` FOUND (auto-detect + temp-env fallback)
- `bench/wyniki.md` FOUND (3 sekcje, polskie naglowki, alphabetical microbench)
- Commits f76b034, f498200, cb51bce FOUND in `git log`
- Empiryczny mean_ratio 0.9559 ∈ D-08 sanity range [0.85, 0.97]
- Encoding: UTF-8 NFC, LF, BOM-free, final newline na wszystkich 4 plikach

## Threat Flags

None — wszystkie threats z `<threat_model>` planu mitigated lub accepted:
- T-04-06-01 (BLOCKER #3 module isolation) — mitigated, acceptance criteria sprawdza obecnosc 3 sygnatur.
- T-04-06-02 (BLOCKER #4 resolver path) — mitigated, wrapper auto-detect + fallback.
- T-04-06-03 (sysinfo disclosure) — accepted, public info per D-07.
- T-04-06-04 (~5 min DoS) — accepted, offline regen per D-06.

## Next Steps

1. **Plan 04-08** — README.md konsumuje headline `~4%` i embed `bench/wyniki.md` link.
2. **Verifier** — phase-level VERIFICATION.md po wszystkich Wave 4 commits.
