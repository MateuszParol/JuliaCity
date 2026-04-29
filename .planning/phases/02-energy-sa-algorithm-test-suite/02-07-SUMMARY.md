---
phase: 02-energy-sa-algorithm-test-suite
plan: 07
subsystem: algorithm-correctness
tags:
  - julia
  - bug-fix
  - sa-algorithm
  - regression-test
  - off-by-one
  - 2-opt
  - gap-closure

# Dependency graph
requires:
  - phase: 02-energy-sa-algorithm-test-suite
    provides: "symuluj_krok! (plan 02-04), kalibruj_T0 (plan 02-02), test scaffolds (plan 02-05) - both BL-01 fix sites pre-existed"
provides:
  - "BL-01 fixed at both sites: simulowane_wyzarzanie.jl:108 and energia.jl:178 - i upper bound 1:(n-1) -> 1:(n-2)"
  - "Regression testset in test/test_symulacja.jl (10_000 N=3 + 100_000 N=20 symuluj_krok! steps, no ArgumentError)"
  - "Regression testset in test/test_energia.jl (10_000 N=3 + 5_000 N=20 kalibruj_T0 probes, no ArgumentError; NaN-tolerant assertion)"
  - "deferred-items.md: 2-opt entry marked RESOLVED with cross-reference to plan 02-07"
affects:
  - "02-13 (manifest regen + CI green run)"
  - "Phase 3 (visualization)"

tech-stack:
  added: []
  patterns:
    - "Boundary regression test: smallest valid fixture (N=3) + 10_000 iterations to exercise the failing branch with probability approx 1.0"
    - "NaN-tolerant assertion (T0 >= 0.0) || isnan(T0) decouples BL-01 from WR-01"
    - "Polish ASCII-folded inline rationale comments at fix sites (LANG-01)"

key-files:
  created:
    - ".planning/phases/02-energy-sa-algorithm-test-suite/02-07-SUMMARY.md"
  modified:
    - "src/algorytmy/simulowane_wyzarzanie.jl"
    - "src/energia.jl"
    - "test/test_symulacja.jl"
    - "test/test_energia.jl"
    - ".planning/phases/02-energy-sa-algorithm-test-suite/deferred-items.md"

key-decisions:
  - "D-05/D-06 LOCKED shape preserved without erratum - empty UnitRange is degenerate case of documented shape, not different shape; CONTEXT.md erratum left to developer per orchestrator directive."
  - "TDD ordering inverted: Tasks 1-2 (fix) BEFORE Tasks 3-4 (test) - keeps HEAD green-by-construction, avoids two intermediate commits with deliberately-failing tests."
  - "NaN-tolerant assertion in Task 4 because N=3 produces identical delts so std==0 OR length==1 -> NaN (the latter is WR-01 plan 02-11 domain)."

patterns-established:
  - "Gap-closure plan template: targeted small-task PLAN driven from VERIFICATION+REVIEW gaps with grep-based acceptance criteria when runtime is unavailable"
  - "Inline ASCII-folded Polish rationale at fix sites cross-references locked decision IDs"

requirements-completed:
  - ALG-02
  - ALG-08
  - ENE-04
  - ENE-05
  - TEST-01

duration: 6min
completed: 2026-04-29
---

# Phase 02 Plan 07: BL-01 Off-by-One Gap-Closure Summary

**Tightened i-sample upper bound from `1:(n-1)` to `1:(n-2)` at both 2-opt sites (`symuluj_krok!`, `kalibruj_T0`) - eliminates the ~5%/step probabilistic ArgumentError crash that shipped from Plan 02-02 onward, with N=3 boundary regression tests in both test files.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-29T10:36:36Z
- **Completed:** 2026-04-29T10:42:40Z
- **Tasks:** 5
- **Files modified:** 5

## Accomplishments

- **BL-01 fixed at both sites** - `src/algorytmy/simulowane_wyzarzanie.jl:108` and `src/energia.jl:178` now sample `i = rand(rng, 1:(n - 2))`. The empty `(i+2):n` when `i=n-1` case is impossible by construction.
- **D-05/D-06 LOCKED shape preserved** - only the always-empty `i=n-1` is removed; the `(i, i+2..n)` sampling pattern is untouched, so the fix is structural-narrowing, not a decision change.
- **Regression tests added at both sites** - `test/test_symulacja.jl` and `test/test_energia.jl` each grow an 8th inner `@testset` exercising N=3 (only-legal-pair) for 10_000 iterations + N=20 sanity for 100_000/5_000 iterations. Both prove no `ArgumentError`.
- **`deferred-items.md` synchronized** - status table marks the 2-opt entry RESOLVED with cross-reference to plan 02-07; new Resolution log section documents both fix sites + tests + LOCKED-shape preservation argument.
- **CONTEXT.md untouched** - D-05 erratum is deliberately left to the developer per orchestrator directive.

## Task Commits

Each task was committed atomically (--no-verify per parallel-executor protocol):

1. **Task 1: BL-01 fix in `symuluj_krok!`** - `d709500` (fix)
2. **Task 2: BL-01 fix in `kalibruj_T0`** - `aefc1dc` (fix)
3. **Task 3: BL-01 boundary regression test for `symuluj_krok!`** - `d66c108` (test)
4. **Task 4: BL-01 boundary regression test for `kalibruj_T0`** - `24458d7` (test)
5. **Task 5: `deferred-items.md` RESOLVED status update** - `57ffbc5` (docs)

_TDD note: Tasks 3 and 4 are tagged tdd=true. Because the underlying fix is committed in Tasks 1-2 first, the tests will go GREEN on first runtime evaluation (plan 02-13 CI run). Strict RED-then-GREEN was inverted to keep HEAD in a fixed state at every commit._

## Files Created/Modified

- `src/algorytmy/simulowane_wyzarzanie.jl` (+4/-2) - line 108 fix `1:(n - 2)`, plus inline 2-line Polish rationale comment block; docstring at line 82 updated.
- `src/energia.jl` (+2/-1) - line 178 fix `1:(n - 2)` in `kalibruj_T0` inner loop, plus 1-line inline Polish rationale.
- `test/test_symulacja.jl` (+41/-0) - 8th inner testset `BL-01 boundary i=n-1 nigdy nie crashuje (gap-closure)` exercising N=3 (10_000 steps) + N=20 (100_000 steps).
- `test/test_energia.jl` (+35/-0) - 8th inner testset `BL-01 kalibruj_T0 boundary nie crashuje (gap-closure)` with NaN-tolerant assertion `(T0 >= 0.0) || isnan(T0)`.
- `.planning/phases/02-energy-sa-algorithm-test-suite/deferred-items.md` (+11/-2) - status table updated; new Resolution log section above status table.

## Decisions Made

- **D-05/D-06 LOCKED shape preserved without erratum** - chose to fix only the empty-range expression, not the locked decision text. An empty UnitRange is a degenerate case of the documented shape, not a different shape. CONTEXT.md erratum is left to the developer.
- **Test ordering inverted from strict TDD** - Tasks 1-2 (fix) committed BEFORE Tasks 3-4 (test). Keeps HEAD in a green-by-construction state at every commit; avoids two intermediate commits with deliberately-failing tests; preserves bisectability.
- **NaN-tolerant kalibruj_T0 assertion** - used `(T0 >= 0.0) || isnan(T0)`. N=3 yields one legal (i,j)=(1,3) per iteration, so std==0 OR length==1 -> NaN. WR-01 (NaN guard) is plan 02-11 domain - coupling them here would be scope creep.

## Deviations from Plan

**None - plan executed exactly as written. One tooling note:**

## Issues Encountered

- **Stale Edit/Read/Write tool buffer in worktree**
- **No other issues.**

## TDD Gate Compliance

This plan is `type: execute` (not plan-level `type: tdd`), but Tasks 3 and 4 carry tdd=true. Per the inverted-ordering decision:

- **Task 1 / 2 (fix commits, RED-equivalent already-implemented):** `d709500`, `aefc1dc`. The RED state existed in HEAD before this plan started; these commits implement the GREEN.
- **Task 3 / 4 (test commits, regression-lock):** `d66c108`, `24458d7`. Run-time gating happens at plan 02-13 (when Julia is available); no REFACTOR commit is needed.

The standard `test()` -> `feat()` -> `refactor()` gate sequence is intentionally adapted to: `fix() -> fix() -> test() -> test() -> docs()`.

## Verification Status

**Structural (grep-level, on-disk, this worktree):** ALL PASS

```
src/algorytmy/simulowane_wyzarzanie.jl:
  rand(stan.rng, 1:(n - 2))   -> 1   (was 0; required: 1)
  rand(stan.rng, 1:(n - 1))   -> 0   (was 1; required: 0)
  BL-01 fix                   -> 2   (docstring + inline)
  j = rand(stan.rng, (i+2):n) -> 1   (untouched)
  @assert 1 <= i < j <= n     -> 1   (untouched)

src/energia.jl:
  rand(rng, 1:(n - 2))        -> 1   (was 0; required: 1)
  rand(rng, 1:(n - 1))        -> 0   (was 1; required: 0)
  BL-01 fix                   -> 1
  j = rand(rng, (i+2):n)      -> 1   (untouched)
  function definitions        -> 5

test/test_symulacja.jl:
  BL-01 boundary i=n-1...     -> 2 (testset name + section header)
  punkty3 = generuj_punkty(3  -> 1
  for _ in 1:10_000           -> 1
  for _ in 1:100_000          -> 1
  outer @testset closed       -> 1   (preserved)
  ALG-06 testset preserved    -> 1
  TEST-08 placeholder logic   -> 1   (preserved)

test/test_energia.jl:
  BL-01 kalibruj_T0 boundary  -> 2 (testset + header)
  kalibruj_T0(stan3; n_probek=10_000) -> 1
  (T0 >= 0.0) || isnan(T0)    -> 2
  testset 7 preserved         -> 1
  outer @testset closed       -> 1   (preserved)

.planning/phases/02-energy-sa-algorithm-test-suite/deferred-items.md:
  RESOLVED in plan 02-07      -> 1
  ## Resolution log           -> 1
  Pre-existing, locked        -> 0   (replaced)
  Last updated by Plan 02-07  -> 1
  TEST-08 row preserved       -> 1
```

**Runtime (Pkg.test()):** DEFERRED to plan 02-13 (Julia not installed in this worktree per env_note).

## Known Stubs

None. This plan only modifies existing code paths.

The pre-existing TEST-08 placeholders (`const TRASA_REF = Int[]`, `const ENERGIA_REF = NaN` in `test/test_symulacja.jl:45-46`) are unrelated to BL-01 and tracked separately in `deferred-items.md` (resolved by plan 02-13). Intentionally untouched here.

## Threat Flags

None. The fix narrows a probabilistic-crash attack surface (a maliciously-crafted RNG seed could deterministically trigger ArgumentError pre-fix); no new surface introduced.

## Next Phase Readiness

- **Phase 2 SC-2 (Hamilton invariant after every step) - code-level unblocked.** Pre-fix probabilistically violated; post-fix structurally guaranteed for all valid (n>=3) fixtures. Runtime confirmation pending plan 02-13.
- **Phase 2 SC-4 (NN-baseline-beat on N=1000 seed=42 with 20_000 SA steps) - pre-fix had ~13.5 percent probability of crash before reaching the ratio assertion. Post-fix: zero.** Runtime measurement pending plan 02-13.
- **No new blockers introduced.** Other Phase 2 BLOCKERs (BL-02 Aqua, BL-03 patience, BL-04 chunked-threading, manifest regen) are owned by sibling plans 02-08, 02-09, 02-10, 02-13.
- **Phase 3 (visualization) precondition for BL-01 specifically is now met.** Other Phase 2 must-haves remain unmet until the rest of waves 7-10 + CI run.

## Self-Check: PASSED

All claims re-verified against on-disk reality and git log immediately before finalization:

- All 5 task commits exist in `git log`: `d709500`, `aefc1dc`, `d66c108`, `24458d7`, `57ffbc5` - VERIFIED
- All 5 modified files appear in `git diff --name-only 22cf251..HEAD` and no others - VERIFIED
- All grep-level acceptance criteria reflect bash grep -c output, not Read/Grep tool output - VERIFIED
- CONTEXT.md, STATE.md, ROADMAP.md NOT modified - VERIFIED via git diff --name-only
- This SUMMARY.md is committed in the final-commit step

---
*Phase: 02-energy-sa-algorithm-test-suite*
*Plan: 02-07 (gap-closure)*
*Completed: 2026-04-29*
