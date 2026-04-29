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

## Status

| Item | Severity | Suggested resolver | Status |
|------|----------|--------------------|--------|
| 2-opt edge case `i = n-1` empty `j` range | Low (probabilistic crash) | Plan 02-05 or 02-06 | Pre-existing, locked pattern |
| TEST-08 placeholder removal | Low (test broken until CI run) | First CI run with Julia | Helper script + `@test_broken` guard in place |

---
*Last updated: 2026-04-29 by Plan 02-05 executor.*
