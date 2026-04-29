---
phase: 02-energy-sa-algorithm-test-suite
plan: 08
subsystem: test-orchestration
tags:
  - julia
  - aqua
  - test-orchestration
  - quality-gate
  - bug-fix
  - gap-closure
requires:
  - 02-06   # base Aqua testset wired up
provides:
  - Aqua-check_extras-correctly-configured
  - 4-future-use-extras-explicitly-ignored
affects:
  - test/runtests.jl
tech-stack:
  added: []
  patterns:
    - "Aqua.test_all top-level kwargs (check_extras separate from deps_compat)"
    - "Pattern D — ignore stdlib without compat entries (:Random, :Statistics)"
    - "Pattern: explicit-ignore extras intentionally absent from [targets].test"
key-files:
  created: []
  modified:
    - test/runtests.jl
decisions:
  - "Keep BenchmarkTools/GLMakie/Makie/Observables in Project.toml [extras] (per CONTEXT.md, future Phase 3/4 use)"
  - "Add the 4 extras to Aqua check_extras ignore list rather than removing from Project.toml"
  - "Hoist check_extras to top-level Aqua.test_all kwarg (was nested inside deps_compat — silently ignored by Aqua)"
metrics:
  duration: "~2 min"
  completed: 2026-04-29
requirements_completed:
  - TEST-06   # at code level — runtime confirmation deferred to plan 02-13
---

# Phase 02 Plan 08: BL-02 + IN-04 Gap Closure (Aqua check_extras) Summary

**One-liner:** Naprawiony testset Aqua w `test/runtests.jl` — `check_extras` przeniesione z zagniezdzonego pola w `deps_compat` na top-level kwarg, ignore list rozszerzona o 4 zamierzone-w-Phase-3/4 extras (BenchmarkTools, GLMakie, Makie, Observables).

## Objective

Domknac BLOCKER **BL-02** (Aqua `check_extras` zglosi 4 false-positives) razem z INFO **IN-04** (struktura wywolania `Aqua.test_all` ma `check_extras` zagniezdzone wewnatrz `deps_compat` — Aqua silently ignoruje misplaced sub-key i odpala `check_extras` z defaultami).

Per CONTEXT.md, czterech podejrzanych: `BenchmarkTools`, `GLMakie`, `Makie`, `Observables` jest **INTENCJONALNIE** w `Project.toml [extras]` — sa potrzebne w Phase 3 (wizualizacja GLMakie/Makie/Observables) oraz Phase 4 (BenchmarkTools dla microbenchmarks). Usuniecie ich z `Project.toml` byloby regresja wzgledem decyzji projektowych. Wlasciwy fix: dodac je do Aqua `check_extras` ignore list.

## What Was Done

### Aqua testset structure: BEFORE → AFTER

**BEFORE** (`test/runtests.jl:211-218`, malformed nested form):

```julia
@testset "Aqua.jl quality (TEST-06)" begin
    Aqua.test_all(JuliaCity;
        ambiguities = (recursive = false,),
        stale_deps = false,
        deps_compat = (ignore = [:Random, :Statistics],
                       check_extras = (ignore = [:Test, :Unicode],)),  # nested!
    )
end
```

`check_extras` jako sub-key w `deps_compat` NamedTuple — Aqua nie zna takiego pola w `deps_compat` i silently ignoruje. `check_extras` rusza z defaultami i zglasza 4 unused extras jako failure.

**AFTER** (`test/runtests.jl:211-223`, hoisted + extended):

```julia
@testset "Aqua.jl quality (TEST-06)" begin
    # BL-02 + IN-04 (gap-closure 02-08): check_extras hoisted from deps_compat
    # sub-tuple to top-level kwarg. Ignore list extended to BenchmarkTools/GLMakie/
    # Makie/Observables — INTENCJONALNIE w [extras] dla Phase 3 (viz) i Phase 4 (bench)
    # per CONTEXT.md, NIE usuwane z Project.toml. Pattern D: stdlib :Random/:Statistics
    # bez compat entry → deps_compat ignore.
    Aqua.test_all(JuliaCity;
        ambiguities = (recursive = false,),
        stale_deps = false,
        deps_compat = (ignore = [:Random, :Statistics],),
        check_extras = (ignore = [:Test, :Unicode, :BenchmarkTools, :GLMakie, :Makie, :Observables],),
    )
end
```

Strukturalne zmiany:
1. `deps_compat` zamkniete `,)` po `[:Random, :Statistics]` — staje sie 1-elementowym NamedTuple.
2. `check_extras` jest osobnym top-level kwarg-iem `Aqua.test_all` (nie sub-key `deps_compat`).
3. Ignore list `check_extras` rozszerzona z 2 → 6 symboli: `:Test, :Unicode, :BenchmarkTools, :GLMakie, :Makie, :Observables`.
4. Dodany 5-liniowy polski komentarz objasniajacy uzasadnienie (rationale).

### Ignore list rationale

| Symbol | W `[targets].test`? | Powod ignore |
|---|---|---|
| `:Test` | TAK | Aqua `check_extras` flaguje extras NIE w zadnym targecie. `:Test` jest w targecie, wiec ignore jest no-op. Zachowane dla bezpieczenstwa (defensive). |
| `:Unicode` | TAK | j.w. |
| `:BenchmarkTools` | NIE | Phase 4 (`bench/`) — pakiet zostanie uzyty dla microbenchmarks; nie dotyka test suite. |
| `:GLMakie` | NIE | Phase 3 (viz) — backend OpenGL dla animacji; nie dotyka test suite. |
| `:Makie` | NIE | Phase 3 (viz) — Plotting framework; nie dotyka test suite. |
| `:Observables` | NIE | Phase 3 (viz) — Observable-pattern dla animacji; nie dotyka test suite. |

`deps_compat` ignore list zostala **niezmieniona** (`[:Random, :Statistics]`) — Pattern D z Phase 1 (stdlib bez compat entries).

### Project.toml — niezmieniony

Zgodnie z must-haves planu, `Project.toml` NIE jest modyfikowany. `[extras]` zachowuje wszystkie 10 entries (Aqua, BenchmarkTools, GLMakie, JET, Makie, Observables, PerformanceTestTools, StableRNGs, Test, Unicode), `[targets].test` zachowuje 6 entries (Aqua, JET, PerformanceTestTools, StableRNGs, Test, Unicode).

## Verification

Wszystkie 7 acceptance criteria z planu spelniono (text-based + grep — Julia nie jest zainstalowana lokalnie):

| # | Criterion | Expected | Got |
|---|---|---:|---:|
| 1 | `check_extras = (ignore = [:Test, :Unicode, :BenchmarkTools, :GLMakie, :Makie, :Observables]` | 1 | **1** |
| 2 | `deps_compat = (ignore = [:Random, :Statistics],),` (3-token terminator) | 1 | **1** |
| 3 | `^\s*check_extras\s*=` (top-level only, no nested duplicates) | 1 | **1** |
| 4 | OLD malformed `check_extras = (ignore = [:Test, :Unicode],))` | 0 | **0** |
| 5 | JET TEST-07 testset still present | ≥1 | **2** |
| 6 | 3 includes preserved (test_energia.jl, test_baselines.jl, test_symulacja.jl) | 3 | **3** |
| 7 | Polish rationale comment `BL-02 + IN-04 (gap-closure 02-08)` | 1 | **1** |

`git status --short` po commit: clean (workspace). `git diff --diff-filter=D HEAD~1 HEAD`: pusty (no deletions). Project.toml `[extras]` `[compat]` linie dla 4 extras: 8 (4 + 4) — zachowane.

**Runtime verification deferred to plan 02-13** (final phase verification): wymaga `julia --project=. -e 'using Pkg; Pkg.test()'` — Julia nie jest zainstalowana w tym worktree.

## Tasks Completed

| # | Task | Commit | Files |
|---|---|---|---|
| 1 | Restructure Aqua testset — hoist check_extras + extend ignore list | `f8b0400` | `test/runtests.jl` (1 file, +7/-2 lines) |

## Deviations from Plan

**None — plan executed exactly as written.**

Jeden incident podczas wykonania (NIE deviation w sensie planu, ale warto udokumentowac dla post-mortem):

### Tooling artifact: parent-project spillover

Pierwsza proba Edit uzyla absolute path `C:\Users\mparol\...\JuliaCity\test\runtests.jl` (parent-project root) zamiast worktree-rooted `C:\Users\mparol\...\JuliaCity\.claude\worktrees\agent-afc15bacd36e56fec\test\runtests.jl`. Edit zaraportowal sukces, ale `git diff` w worktree byl pusty — zmiana wyladowala w **parent project**, nie w worktree.

To jest dokladnie symptom opisany w `<critical_tooling_note>` planu. Recovery:
1. `git checkout -- test/runtests.jl` w parent project (cofniecie spillover).
2. Re-Read worktree file uzywajac worktree-rooted absolute path.
3. Re-Edit z worktree-rooted absolute path → diff persistuje poprawnie.

NIE uzyto bypass-tooling-layer fallback (Python via Bash). Edit zadzialal poprawnie po podaniu wlasciwej sciezki.

## Threat Flags

Brak — modyfikacja jest test-only, nie wprowadza nowej powierzchni atakujacej (network endpoints, auth paths, schema changes). Aqua `check_extras` ignore list jest meta-config dla quality gate, nie kod produkcyjny.

## Self-Check: PASSED

- `test/runtests.jl` modified: FOUND (commit `f8b0400`)
- Commit `f8b0400` exists: FOUND (`git log --oneline | grep f8b0400`)
- All 7 acceptance criteria pass (verified via Grep)
- `Project.toml` not modified: VERIFIED (`git status --short` shows only test/runtests.jl)
- TEST-06 unblocked at code level: VERIFIED (text-based — runtime gated by Julia install in plan 02-13)
