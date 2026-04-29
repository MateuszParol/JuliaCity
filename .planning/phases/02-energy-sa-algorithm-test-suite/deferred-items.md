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

## Status

| Item | Severity | Suggested resolver | Severity |
|------|----------|--------------------|----------|
| 2-opt edge case `i = n-1` empty `j` range | Low (probabilistic crash) | Plan 02-05 or 02-06 | Pre-existing, locked pattern |

---
*Last updated: 2026-04-29 by Plan 02-04 executor.*
