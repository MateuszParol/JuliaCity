---
phase: 01-bootstrap-core-types-points
plan: 05
subsystem: punkty
tags: [julia, generuj_punkty, xoshiro, deterministic, no-global-rng, geometrybasics, two-methods]

# Dependency graph
requires:
  - phase: 01-bootstrap-core-types-points
    provides: "src/JuliaCity.jl module entry z `using GeometryBasics: Point2`, `using Random`, include(\"typy.jl\"), export Punkt2D/StanSymulacji/Algorytm; const Punkt2D = Point2{Float64} (z plan 04)"
provides:
  - "src/punkty.jl: dwie metody generuj_punkty (D-11) — friendly default `(n::Int=1000; seed::Integer=42)` + composable `(n::Int, rng::AbstractRNG)`"
  - "Implementacja `rand(rng, Punkt2D, n)` (D-13) — A1 verified live (eltype == Point2{Float64})"
  - "Lokalny `Xoshiro(seed)` w funkcji default; brak interakcji z `Random.default_rng()` (PKT-04, D-14)"
  - "Walidacja `n > 0` z `ArgumentError(\"n must be positive\")` po angielsku (LANG-04, D-23)"
  - "src/JuliaCity.jl: `include(\"punkty.jl\")` PO `include(\"typy.jl\")` + `export ... generuj_punkty`"
  - "Publiczne API `using JuliaCity; generuj_punkty(1000)` zwraca 1000 deterministycznych Punkt2D w [0,1]²"
affects: [01-06, "Phase 2 oblicz_energie (konsumuje generuj_punkty(N))", "Phase 2 inicjuj_nn! (test fixture)", "Phase 3 wizualizacja (Vector{Punkt2D} flowuje do GLMakie scatter)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-method API (D-11): friendly default deleguje do composable wariantu z lokalnym Xoshiro(seed) — composable bierze AbstractRNG"
    - "rand(rng, T, n) gdzie T <: StaticVector — natywne wsparcie GeometryBasics przez StaticArrays inheritance"
    - "Brak Random.seed!(...) (anti-pattern z Pitfall 1) — lokalny RNG zawsze przekazany jako wartość, never globalna mutacja"
    - "Polskie docstringi + polskie komentarze + angielski ArgumentError message (LANG-01/LANG-04 split)"

key-files:
  created:
    - "src/punkty.jl - dwie metody generuj_punkty + dokumentacja po polsku (54 linii)"
  modified:
    - "src/JuliaCity.jl - dodane include(\"punkty.jl\") + export generuj_punkty (32 linii)"

key-decisions:
  - "D-11 implemented: dwie metody generuj_punkty — friendly default i composable"
  - "D-12 implemented: default n=1000, seed=42"
  - "D-13 implemented: rand(rng, Punkt2D, n) — A1 holds (eltype == Point2{Float64} confirmed live), brak fallback potrzebny"
  - "D-14 implemented: lokalny Xoshiro(seed) w funkcji default, ZERO interakcji z Random.default_rng() (PKT-04 verified before == after)"
  - "D-15 honored: brak convenience constructora StanSymulacji(n::Int; seed) — generuj_punkty i StanSymulacji są osobnymi funkcjami składanymi jawnie"
  - "D-22/D-23/LANG-01/LANG-04: docstringi po polsku, ArgumentError(\"n must be positive\") po angielsku"

patterns-established:
  - "Pattern: friendly default `(n; seed)` deleguje do composable `(n, rng)` przez lokalny `Xoshiro(seed)` — daje JEDEN core algorytm i DWIE ergonomiczne formy"
  - "Pattern: walidacja w obu metodach (defense-in-depth) — friendly default waliduje przed `Xoshiro(seed)`, composable waliduje przed `rand(rng, ...)`"
  - "Pattern: A1 (rand(rng, T, n) zwraca Vector{T} dla T<:StaticVector) verified live early — brak fallback comprehension nie jest potrzebny dla GeometryBasics 0.5.x + Julia 1.10"

requirements-completed: [PKT-01, PKT-02, PKT-03, PKT-04, LANG-01]

# Metrics
duration: 3min
completed: 2026-04-28
---

# Phase 01 Plan 05: `generuj_punkty` Implementation Summary

**Dwie metody `generuj_punkty` (D-11) — friendly default i composable — z lokalnym `Xoshiro(seed)`, bez mutacji `Random.default_rng()`. PKT-01..04 + LANG-01 wszystkie zweryfikowane runtime'em.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-28T16:35:17Z
- **Completed:** 2026-04-28T16:38:27Z
- **Tasks:** 2
- **Files created:** 1 (`src/punkty.jl`)
- **Files modified:** 1 (`src/JuliaCity.jl`)

## Accomplishments

- `using JuliaCity; generuj_punkty(1000)` zwraca 1000 deterministycznych `Punkt2D` w `[0,1]²` — pełen kontrakt PKT-01..04 spełniony
- A1 z RESEARCH.md (asumpcja: `rand(rng, Punkt2D, n)` zwraca `Vector{Point2{Float64}}`) — **zweryfikowana live w smoke teście** (`eltype = GeometryBasics.Point{2, Float64}` = `Punkt2D`); fallback comprehension nie był potrzebny
- Determinizm potwierdzony — `generuj_punkty(100; seed=42) == generuj_punkty(100; seed=42)` (PKT-01)
- Różne seedy → różne wyniki — `generuj_punkty(100; seed=1) != generuj_punkty(100; seed=2)`
- Brak mutacji `Random.default_rng()` — `before = copy(Random.default_rng()); generuj_punkty(...); after = copy(Random.default_rng()); before == after` (PKT-04, D-14)
- Composable wariant `generuj_punkty(50, Xoshiro(123))` działa — Phase 2 może podać `StableRNG(42)` dla cross-version reproducibility
- `ArgumentError("n must be positive")` rzucony dla `n ∈ {0, -5}` w obu metodach (defense-in-depth)
- `Pkg.test()` zielone end-to-end (precompile JuliaCity 2017 ms, stub testset z plan 03 nadal zielony)
- Trzy methods uzyskane z `methods(generuj_punkty)` — Julia generuje osobny method dla `generuj_punkty()` (zero-arg) wynikający z default `n=1000`, plus `(n; seed)` i `(n, rng)`. Wszystkie trzy są oczekiwane semantycznie (D-11 ≥ 2 spełnione)

## Task Commits

Each task was committed atomically (worktree mode, `--no-verify`):

1. **Task 1: src/punkty.jl z dwoma metodami generuj_punkty** — `8bf78d7` (feat)
2. **Task 2: wire generuj_punkty do modułu JuliaCity** — `ec82aaf` (feat)

## Files Created/Modified

- `src/punkty.jl` (created) — dwie metody `generuj_punkty`:
  - `generuj_punkty(n::Int=1000; seed::Integer=42)` — friendly default; waliduje `n > 0`, tworzy lokalny `Xoshiro(seed)`, deleguje do `(n, rng)` formy
  - `generuj_punkty(n::Int, rng::AbstractRNG)` — composable; waliduje `n > 0`, zwraca `rand(rng, Punkt2D, n)` (D-13)
  - 54 linii, UTF-8 bez BOM, NFC, kończy się `\n`, brak `Random.seed!` (anti-pattern Pitfall 1)
  - Polskie docstringi (zawiera literal "punktów", "lokalnego", "modyfikuje"), angielska asercja
- `src/JuliaCity.jl` (modified) — dwie zmiany różnicowe:
  - Dodane `include("punkty.jl")` z polskim komentarzem `# Generator punktów testowych (PKT-01..04)`, **bezpośrednio po** `include("typy.jl")` (kolejność krytyczna — `Punkt2D` musi być w scope'ie modułu zanim plik `punkty.jl` jest evaluated)
  - Lista exportowanych symboli rozszerzona z `Punkt2D, StanSymulacji, Algorytm` na `Punkt2D, StanSymulacji, Algorytm, generuj_punkty`
  - Stary komentarz `# generuj_punkty będzie dodany w plan 05` usunięty (już nieaktualny)
  - 32 linii, UTF-8 bez BOM, NFC

## Decisions Made

None — plan executed exactly as written. Wszystkie kluczowe decyzje pochodzą z 01-CONTEXT.md (D-11, D-12, D-13, D-14, D-15, D-22, D-23) i zostały wprost zmaterializowane.

## Deviations from Plan

None substantive — code wykonany dokładnie według planu. Brak Rule 1/2/3 fixes, brak auth gates, brak nieoczekiwanych deletions.

**Drobna uwaga implementacyjna (NIE deviation):** Plan's `<verify>` automated bash command zawiera literał `copy(default_rng())` (bez `Random.` qualifier). `Random` stdlib NIE eksportuje `default_rng` — tylko `Random.default_rng()` jako qualified call jest wywołalne pod `using Random`. Verifier może to zauważyć przy reproducowaniu polecenia z planu — substantywna asercja PKT-04 jest poprawnie zweryfikowana przez wariant z `Random.default_rng()` (verification_evidence niżej). Plan-level verification block w sekcji `<verification>` (linie 388-422) używa `default_rng()` unqualified, ale tam też **musi** być pod `using Random` z qualifier — drobna nieścisłość w treści planu, niezwiązana z kodem. Funkcjonalnie API jest zgodne z planu intencją.

## Issues Encountered

None.

**Manifest.toml note:** plik `Manifest.toml` jest w `.gitignore` (z plan 03) — nie wpływa na success criteria tego planu (D-25 z 01-CONTEXT.md mówi "commit Manifest" jako principle, ale plan 03 zdecydował o gitignore — to jest TODO dla późniejszej fazy/phase-finalization, nie scope plan 05).

## Verification Evidence

```
=== Gate A: standalone smoke test (Task 1, przed JuliaCity wire) ===
OK: standalone smoke test passed
eltype = GeometryBasics.Point{2, Float64}      # == Punkt2D — A1 holds
type = Vector{GeometryBasics.Point{2, Float64}}

=== Gate B: full PKT-01..04 smoke (Task 2, after wire) ===
OK: all PKT-01..04 smoke tests passed
Methods: 3
eltype 1k: GeometryBasics.Point{2, Float64}

Asercje pokryte:
- :generuj_punkty in names(JuliaCity)                                  OK (export D-3 + D-11)
- length(methods(generuj_punkty)) >= 2                                 OK (3 methods, D-11)
- length(generuj_punkty()) == 1000                                     OK (PKT-02, D-12)
- generuj_punkty(100; seed=42) == generuj_punkty(100; seed=42)         OK (PKT-01)
- generuj_punkty(100; seed=42) != generuj_punkty(100; seed=43)         OK (różne seedy)
- all(p -> 0 ≤ p[1] ≤ 1 && 0 ≤ p[2] ≤ 1, generuj_punkty(1000))         OK (PKT-03)
- eltype(generuj_punkty(1000)) == Punkt2D                              OK (A1 verified, Pitfall 6)
- before = copy(Random.default_rng()); generuj_punkty(1000; seed=42);
  after = copy(Random.default_rng()); before == after                  OK (PKT-04, D-14)
- length(generuj_punkty(50, Xoshiro(123))) == 50                       OK (D-11 composable)
- generuj_punkty(0)  -> ArgumentError                                  OK (LANG-04, D-23)
- generuj_punkty(-5) -> ArgumentError                                  OK (LANG-04, D-23)

=== Gate C: full plan <verification> block ===
OK: PKT-01..04 verified

=== Gate D: julia --project=. -e 'using Pkg; Pkg.test()' ===
Precompiling packages...
   2017.2 ms  ✓ JuliaCity
  1 dependency successfully precompiled in 4 seconds. 20 already precompiled.
     Testing Running tests...
Test Summary:    | Pass  Total  Time
JuliaCity (stub) |    1      1  0.0s
     Testing JuliaCity tests passed

=== Gate E: runtime_note assertion ===
OK: generuj_punkty(1000) returns 1000

=== Encoding ===
src/punkty.jl    : no BOM, NFC normalized, ends with \n
src/JuliaCity.jl : no BOM, NFC normalized, ends with \n

=== File-level acceptance ===
src/punkty.jl exists                                                   OK
grep -c "^function generuj_punkty" src/punkty.jl == 2                  OK
grep "function generuj_punkty(n::Int=1000; seed::Integer=42)"          OK
grep "function generuj_punkty(n::Int, rng::AbstractRNG)"               OK
grep "Xoshiro(seed)"                                                   OK
grep 'throw(ArgumentError("n must be positive"))'                      OK
NO grep "Random.seed!"                                                 OK
grep "punktów" "lokalnego" "modyfikuje" (Polish docstrings)            OK

src/JuliaCity.jl:
grep 'include("punkty.jl")'                                            OK
grep "export Punkt2D, StanSymulacji, Algorytm, generuj_punkty"         OK
typy.jl line 24 < punkty.jl line 27                                    OK (kolejność krytyczna)
```

## Next Phase Readiness

**Wave 6 (plan 06) ready:**
- `src/punkty.jl` istnieje z D-11 dwoma metodami; plan 06 (test suite) może bezpośrednio testować obie sygnatury
- Smoke test A1 już przeszedł — plan 06 może dodać formalny `@testset` `eltype(generuj_punkty(10)) == Punkt2D` jako regression guard
- StableRNG fixture (Phase 2) — composable forma `generuj_punkty(n, StableRNG(42))` skompiluje się natychmiast (StableRNG <: AbstractRNG)

**Phase 2 ready:**
- `oblicz_energie(punkty, trasa)` (Phase 2) może bezpośrednio konsumować `generuj_punkty(N)` jako test fixture
- `inicjuj_nn!(stan)` może być wywołany na `StanSymulacji(generuj_punkty(N))` — composability D-15 zapewnia, że nic nie potrzebuje konstruktora `StanSymulacji(n::Int; seed)` (deferred do Phase 4)

**Phase 3 ready:**
- `Vector{Punkt2D} == Vector{Point2{Float64}}` flowuje do Makie scatter zero-cost; `generuj_punkty(N)` jest jedynym source of points dla wizualizacji

**No blockers.**

## Self-Check: PASSED

- [x] `src/punkty.jl` exists at expected path (`/Users/mattparol/Desktop/Projekty/JuliaCity/.claude/worktrees/agent-acf23e45f183374ab/src/punkty.jl`)
- [x] `src/JuliaCity.jl` modified at expected path
- [x] Commit `8bf78d7` (feat: src/punkty.jl with two methods) found in `git log --oneline`
- [x] Commit `ec82aaf` (feat: wire generuj_punkty into JuliaCity) found in `git log --oneline`
- [x] `julia --project=. -e 'using JuliaCity; @assert length(generuj_punkty(1000)) == 1000'` exits 0
- [x] `julia --project=. -e 'using Pkg; Pkg.test()'` exits 0
- [x] STATE.md NOT modified (worktree mode)
- [x] ROADMAP.md NOT modified (worktree mode)

---
*Phase: 01-bootstrap-core-types-points*
*Plan: 05*
*Completed: 2026-04-28*
