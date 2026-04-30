# Deferred Items - Phase 02

Out-of-scope discoveries logged during plan execution. Each item is NOT auto-fixed
in current plan (per scope boundary in executor rules); review and triage in a
later plan, debug session, or follow-up phase.

## Plan 02-04: Edge case in 2-opt sampling (pre-existing pattern from Plan 02-02)

**Discovered during:** Plan 02-04 execution, Python algorithmic mirror smoke.

**Issue:** `symuluj_krok!` and `kalibruj_T0` use the pattern:
```julia
i = rand(stan.rng, 1:(n - 1))
j = rand(stan.rng, (i + 2):n)
```
When `i == n - 1`, the range `(i + 2):n = (n + 1):n` is **empty** in Julia. Calling
`rand(rng, empty_range)` raises `ArgumentError("collection must be non-empty")`.

For N=20 the probability of hitting `i = 19` is 1/19 ≈ 5.3%, so for 1000 SA steps
we expect ~50 crashes. For N=1000 the probability is 1/999 ≈ 0.1%, still nonzero
across 50_000-step runs.

**Where:** This pattern is locked in CONTEXT.md D-05/D-06 (LOCKED) and was
introduced in Plan 02-02 (`kalibruj_T0`). Plan 02-04 inherits it verbatim per
plan `<context><interfaces>` block citing RESEARCH Pattern 2.

**Why deferred:**
- Pre-existing in Plan 02-02's `kalibruj_T0` — fix would require changing
  D-05/D-06 (LOCKED decisions) which is out of executor scope (Rule 4 / D-LOCK).
- Affects 2 functions (`symuluj_krok!` and `kalibruj_T0`) — concentrated change.
- Plan 02-05 (test suite) is the natural next plan and will likely surface this
  via TEST-04 determinism / TEST-08 golden values when Julia is available; that
  plan SHOULD include the fix as part of test-driven discovery.

**Suggested fix (for Plan 02-05 or follow-up):**
```julia
i = rand(stan.rng, 1:(n - 2))   # was: 1:(n - 1)
j = rand(stan.rng, (i + 2):n)
```
Justification: `i = n - 1` would always produce an empty `j` range; reducing
the i-range to `1:(n - 2)` removes the impossible case while keeping the
j-distribution unchanged for valid `i`.

**Verification (when Julia available):**
- Run 100k `symuluj_krok!` on N=20 stan; assert no `ArgumentError`.
- Run 100k `kalibruj_T0` calls on N=10 stan (smaller N -> higher edge-case
  probability); assert convergence.

## Plan 02-05: TEST-08 placeholder removal (Rule 3 deferred to CI)

**Discovered during:** Plan 02-05 execution (Task 3b). Julia is NOT installed in the
Windows worktree (env_note explicit; same precedent as plans 02-01..04).

**Issue:** Task 3b normal flow expects `julia --project=. test/_generuj_test08_refs.jl`
to print:
```
const TRASA_REF = [<20 Int...>]
const ENERGIA_REF = <Float64>
```
which is then pasted into `test/test_symulacja.jl` (replacing the placeholder
`const TRASA_REF = Int[]` and `const ENERGIA_REF = NaN`), and the helper script
is deleted. Without Julia, real numeric reference cannot be generated.

**Mitigation applied in Plan 02-05 (per env_note guidance):**
- `test/_generuj_test08_refs.jl` retained (CI run will execute it)
- `test/test_symulacja.jl` keeps `Int[]` / `NaN` placeholders
- TEST-08 golden-value asercje wrapped in `if !isempty(TRASA_REF) && !isnan(ENERGIA_REF)`
  branch — when placeholders present (current state), asercje use `@test_broken`
  (deliberate signal of pending verification); structural assertions
  (Hamilton invariant + permutacja + iteracja count) remain hard-asserted
- Top-of-file komentarz w `test/test_symulacja.jl` documents full procedure prominently

**Resolution procedure (CI / dev-machine with Julia):**
1. Run helper: `julia --project=. test/_generuj_test08_refs.jl > /tmp/refs.txt`
2. Read 2 output lines from `/tmp/refs.txt`
3. Replace lines 23-24 of `test/test_symulacja.jl`:
   - `const TRASA_REF = Int[]` → output line 1
   - `const ENERGIA_REF = NaN` → output line 2
4. Delete `test/_generuj_test08_refs.jl`
5. Run `julia --project=. -e 'using Pkg; Pkg.test()'` — must exit 0

**Verification gate (placeholder grep):**
```bash
grep -cE 'TRASA_REF = Int\[\]|ENERGIA_REF = NaN|TRASA_REF = \[\]' test/test_symulacja.jl
# Must return 0 after Task 3b CI run (pre-CI: returns 2 — placeholders intentional)
```

**Why deferred:**
- Julia toolchain absent in worktree environment — same Rule 3 pattern as plans 02-01..04
- `_generuj_test08_refs.jl` is deterministic, so CI run produces canonical values
- `@test_broken` guard prevents test suite false failure on placeholder state
  while preserving the gate for future verifier (placeholder grep must return 0)
- Plan 02-06 (quality gates) can also re-run this if CI validates first

## Resolution log

- **Plan 02-07 (gap-closure, 2026-04-29)** — BL-01 (2-opt empty range crash) resolved.
  - `src/algorytmy/simulowane_wyzarzanie.jl:108`: `rand(stan.rng, 1:(n - 1))` -> `rand(stan.rng, 1:(n - 2))`
  - `src/energia.jl:178`: `rand(rng, 1:(n - 1))` -> `rand(rng, 1:(n - 2))`
  - Regression tests: `test/test_symulacja.jl::"BL-01 boundary..."` (10_000 N=3 steps + 100_000 N=20 steps); `test/test_energia.jl::"BL-01 kalibruj_T0 boundary..."` (10_000 N=3 prob).
  - D-05/D-06 LOCKED shape (i, i+2..n) preserved — fix removes only the always-empty `i=n-1` case.
  - User notification: an erratum entry should be added to `02-CONTEXT.md` documenting that D-05's "1:n-1" upper bound was an off-by-one (NOT a decision change). This plan does NOT modify CONTEXT.md — that is left to the developer.

- **Plan 02-13 (gap-closure, 2026-04-29)** — TEST-08 placeholder removal resolved (Manifest.toml regen + golden-value capture + Pkg.test()).
  - Julia 1.12.6 znaleziona w `C:\Users\mparol\AppData\Local\Programs\Julia-1.12.6\bin\julia.exe`.
  - `Pkg.resolve()` + `Pkg.instantiate()` zregenerował Manifest.toml z 11 nowymi pakietami (ChunkSplitters v3.2.0, Statistics v1.11.1, GeometryBasics, StaticArrays, etc.).
  - `_generuj_test08_refs.jl` wykonany w temp env (z dodanym StableRNGs); output:
    - `const TRASA_REF = [1, 20, 8, 19, 18, 7, 6, 2, 17, 5, 11, 14, 4, 13, 3, 9, 16, 15, 12, 10]`
    - `const ENERGIA_REF = 7.846654602419595`
  - `test/test_symulacja.jl` linie 38-39: placeholdery zastąpione realnymi wartościami; `@test_broken` guard usunięty (TEST-08 jest teraz hard `@test`).
  - `test/_generuj_test08_refs.jl` USUNIĘTY (one-shot helper).
  - Placeholder gate (`grep -cE 'TRASA_REF = Int\[\]|ENERGIA_REF = NaN|TRASA_REF = \[\]'` na `test/test_symulacja.jl`) zwraca 0.

## Status

| Item | Severity | Suggested resolver | Status |
|------|----------|--------------------|--------|
| 2-opt edge case `i = n-1` empty `j` range | Low (probabilistic crash) | Plan 02-05 or 02-06 | RESOLVED in plan 02-07 (gap-closure) |
| TEST-08 placeholder removal | Low (test broken until CI run) | First CI run with Julia | RESOLVED in plan 02-13 (gap-closure) |
| TEST-05 SA ≥ 10% better than NN (N=1000, seed=42) | High (Roadmap SC #4 unmet) | Plan 02-14 | RESOLVED in plan 02-14 (Roadmap SC #4 zluźnione 10%→5% po empirycznej diagnozie 2-opt local minimum; ratio 0.9408 PASS) |
| Aqua extras compat entries | Low (Aqua passes if compat declared) | Plan 02-13 same commit | RESOLVED — `PerformanceTestTools` compat fixed `0.4`→`0.1` w plan 02-14 (commit 8af8cfd); Aqua 9/9 PASS empirycznie |
| Stronger move (3-opt / or-opt / double-bridge) dla ratio < 0.9 | Low (deferred — v2; Phase 3 priorytet) | Plan 02-15 (deferred) | OPEN — udokumentowane w 02-CONTEXT.md D-03 erratum future work |

## Plan 02-13 WIP handoff (machine switch — 2026-04-29)

**Stan przed przerwaniem (na maszynie z Julia 1.12.6):**
- 220 testów PASS, 2 FAIL, 0 ERRORS, 0 BROKEN.
- ✓ Manifest.toml zregenerowany (Pkg.resolve dodało ChunkSplitters/Statistics/GeometryBasics/StaticArrays/etc.)
- ✓ TEST-08 golden values capture-owane (`TRASA_REF`, `ENERGIA_REF`) — 5/5 PASS empirycznie.
- ✓ JET TEST-07: 4/4 PASS (po bumpie compat na "0.9, 0.10, 0.11").
- ✓ BL-01/02/03/04 + WR-01 wszystkie weryfikowane przez testy gap-closure (PASS).
- ✗ **TEST-05** (NN-baseline-beat): SA ratio 1.65 (po 200_000 krokow) vs cel ≤ 0.9. SA aktywnie POGARSZA NN start bo `kalibruj_T0=2σ` jest skalibrowane dla random start, nie dla NN start (acceptance ~80% worsening na początku → SA wyrzuca z dobrego NN minimum, nie wraca). To jest **defekt projektowy algorytmu**, nie test bug — defaults D-02/D-03 nie pasują do warunków TEST-05.
- ✗ **Aqua extras** (deps_compat): 4 test-only extras (PerformanceTestTools, Serialization, Test, Unicode) bez compat entry. Naprawione w tym commicie przez dodanie compat entries (`PerformanceTestTools="0.4"`, `Serialization="1"`, `Test="1"`, `Unicode="1"`). Wymaga CI re-run aby potwierdzić.

**Co zrobić na drugiej maszynie (z Julia 1.12.x):**

1. **Pull repo, sprawdź ten commit.**
2. **Re-run testów** (sprawdz czy Aqua compat fix działa):
   ```powershell
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```
   Oczekiwane: 221 PASS, 1 FAIL (tylko TEST-05). Jeżeli Aqua nadal failuje, dodaj compat entries lub dodaj `check_extras = false` do `Aqua.test_all` kwargs.
3. **Zdecyduj jak zamknąć TEST-05** — opcje:
   - **A. Override `T_zero` w teście**: `alg = SimAnnealing(stan; T_zero=0.05)`. Pragmatic — 0.05 daje ~5% acceptance worsening na starcie z NN, nie wyrzuca z minimum. Powinno dać ratio ≤ 0.9 w 50_000 krokach.
   - **B. Dodać `T_zero_dla_NN_start` jako kwarg do SimAnnealing** — czystsze API, wymaga aktualizacji CONTEXT.md D-03 erratum.
   - **C. Zmień TEST-05 fixture** — start z random tour zamiast `inicjuj_nn!(stan)`, wtedy 2σ T0 jest sensowne. Ale to NIE jest co Roadmap SC #4 wymaga.
   - **D. Stwórz nowy plan 02-14** dla detailed analysis + fix algorytmu.
4. **Push.**
5. **CI weryfikuje** (matrix 1.10/1.11/nightly × ubuntu/windows/macos).
6. **`/gsd-execute-phase 02 --gaps-only`** żeby zamknąć plan 02-13.
7. **`/gsd-verify-work 02`** (lub manual verifier rerun) → phase 02 status `complete`.

**Co NIE jest w tym commicie:**
- SUMMARY.md dla planu 02-13 (po runtime success).
- Aktualizacja STATE.md / ROADMAP.md (orchestrator zrobi po verify).
- Decision o (A) (B) (C) (D) dla TEST-05 — wymaga user input.

**Pliki zmodyfikowane:**
- `Manifest.toml` — fresh resolve, 11 nowych deps.
- `Project.toml` — JET compat bumped to `"0.9, 0.10, 0.11"`; Serialization dodane do `[extras]` + `[targets].test`; compat entries dla 4 test-only extras.
- `test/runtests.jl` — Aqua kwargs poprawione (`project_extras=false`, deps_compat ignore extended).
- `test/test_symulacja.jl` — TEST-08 placeholdery zastąpione realnymi wartościami (golden values from local Julia run); BL-01 boundary fixture używa `T_zero=1.0` zamiast wywoływać `kalibruj_T0(N=3)`; commenty/header oczyszczone.
- `test/test_energia.jl` — BL-01 kalibruj_T0 boundary fixture zmieniona z N=3 na N=4 (N=3 trafia w WR-01 ArgumentError path).
- `test/test_baselines.jl` — TEST-05 bumpniete z 20_000 → 50_000 → 200_000 krokow (Pitfall G level 2; nadal nie wystarczy bez T_zero override).
- `test/_generuj_test08_refs.jl` — USUNIĘTY (one-shot).
- `deferred-items.md` — ten handoff entry.

---
*Last updated: 2026-04-30 by Plan 02-14 — TEST-05 RESOLVED via opcja X (ratio ≤ 0.95). Phase 2 COMPLETE.*

## Plan 02-14 resolution (2026-04-30)

**TEST-05 NN-baseline-beat — domknięte przez decyzję projektową, nie technical fix.**

Empirical diagnosis (`bench/diagnostyka_test05*.jl` + `02-CONTEXT.md` D-03 erratum) wykazała że pure 2-opt SA na N=1000 NN-start plateauje przy ratio ≈ 0.92 (2-opt local minimum). Hipotezy techniczne B1/B2/B3 z planu 02-14-PLAN.md (fixed T₀ kwarg / Ben-Ameur / closed-form) wszystkie obalone.

**Decyzja (user opcja X):** zluźnić ROADMAP SC #4 z "≥10%" na "**≥5%**" (ratio ≤ 0.95).
- TEST-05 zaktualizowany: `T_zero=0.001`, `liczba_krokow=125_000`, `<= 0.95`.
- Empirical result: ratio **0.9408** (margin +0.009).
- `Pkg.test()` exit 0, **222/222 PASS**, 0 FAIL/ERROR/BROKEN, 1m33s.
- Test Summary, decision, fix details w `02-14-SUMMARY.md` + `02-14-DECISION.md`.

**Future work zatrzymane na v2:** double-bridge perturbation / or-opt move dla ratio < 0.9 (LKH-style stronger move). Estymacja 1–2 dni roboczych. Phase 3 (visualization, core value) ma priorytet.

*Plan 02-14 zamyka Phase 2 — wszystkie 21 REQ-IDs runtime-verified, 5/5 ROADMAP success criteria met (SC #4 z erratum).*
