---
phase: 02-energy-sa-algorithm-test-suite
verified: 2026-04-29T13:00:00Z
status: gaps_found
score: 0/5 must-haves verified (3 BLOCKED on environment; 2 FAILED on substantive defects)
overrides_applied: 0
re_verification: # Initial verification — no previous VERIFICATION.md present
gaps:
  - truth: "oblicz_energie type-stable, post-warmup alloc < 4096 B, returns 4.0 on N=4 unit square"
    status: failed
    reason: "Manifest.toml has not been regenerated — ChunkSplitters dep is in Project.toml but absent from Manifest.toml. The package will fail to load with `Pkg.ERROR: ChunkSplitters not found`. Cannot verify any runtime claim. Additionally, the Threads.@threads :static for (i, x) in enumerate(chunks(...)) pattern in src/energia.jl:113 is non-canonical — the @threads macro requires indexable iterators, and enumerate(chunks(...)) is at minimum unsupported (REVIEW BL-04)."
    artifacts:
      - path: "Manifest.toml"
        issue: "project_hash = bdc30d7b... (Phase 1 hash); no ChunkSplitters / PerformanceTestTools entries; Statistics only as transitive optional"
      - path: "src/energia.jl"
        issue: "Line 113: Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks)) — non-canonical macro usage; canonical pattern uses @threads :static for chunk_idx in 1:nchunks (REVIEW BL-04)"
    missing:
      - "Pkg.instantiate() must be run on a Julia-equipped machine to regenerate Manifest.toml"
      - "Replace enumerate(chunks(...)) with canonical chunked-threading pattern OR provide explicit evidence that this pattern works in Julia 1.10 + ChunkSplitters 3.x"
      - "Live runtime verification of `oblicz_energie([square4], [1,2,3,4]) ≈ 4.0`"
      - "Live `@inferred oblicz_energie(...) isa Float64` confirmation"
      - "Live `@allocated oblicz_energie(D, trasa, bufor) < 4096` after warmup"

  - truth: "symuluj_krok! type-stable, @allocated == 0 post-warmup, sort(stan.trasa) == 1:n after every step"
    status: failed
    reason: "src/algorytmy/simulowane_wyzarzanie.jl:108-109 contains a real probabilistic crash. Sampling `i = rand(stan.rng, 1:(n-1))` and `j = rand(stan.rng, (i+2):n)` produces an empty range `(n+1):n` whenever `i == n-1` — `rand` on an empty UnitRange throws `ArgumentError`. For the N=20 test fixture this fires at probability 1/19 ≈ 5.3% per call; over 1000–2000 SA steps the test is one bad RNG draw away from crashing. The phase goal explicitly says 'PRZED jakąkolwiek wizualizacją the algorithm must be guaranteed correct on the Hamilton invariant' — guarantee is violated. The bug is acknowledged in deferred-items.md but **was never fixed in shipped code**. The deferred-items.md justification ('D-05/D-06 LOCKED') does not survive scrutiny — the fix `1:(n-1)` → `1:(n-2)` removes an impossible (always-empty) sample without changing the (i, i+2..n) shape. REVIEW BL-01 reaches the same conclusion and calls it a real bug."
    artifacts:
      - path: "src/algorytmy/simulowane_wyzarzanie.jl"
        issue: "Line 108: `i = rand(stan.rng, 1:(n - 1))` should be `1:(n - 2)`; line 109 then samples from empty range when i == n-1"
      - path: "src/energia.jl"
        issue: "Line 178 in kalibruj_T0: identical bug `i = rand(rng, 1:(n - 1))` → `j = rand(rng, (i + 2):n)`"
      - path: ".planning/phases/02-energy-sa-algorithm-test-suite/deferred-items.md"
        issue: "Documents the bug as 'pre-existing pattern' and defers fix indefinitely; bug ships in delivered code"
    missing:
      - "Apply `1:(n-2)` patch in symuluj_krok! AND kalibruj_T0"
      - "Add a regression test that runs ≥ 10000 symuluj_krok! steps on N=3 (smallest valid fixture, only valid (i,j) is (1,3)) and asserts no exception"
      - "Live `Pkg.test()` exit-0 confirmation after fix"

  - truth: "Same master seed under JULIA_NUM_THREADS=1 vs JULIA_NUM_THREADS=8 yields identical final tour"
    status: failed
    reason: "Cannot verify — Julia not installed; Manifest.toml not regenerated. Independently, the threading pattern in oblicz_energie (BL-04) is non-canonical and the multi-thread determinism contract may not hold even when the test does run. test_symulacja.jl Sub-testset 6 hardcodes JULIA_NUM_THREADS=8 — on a CI runner with fewer cores Julia will silently downgrade and the '1 vs 8' comparison degenerates (REVIEW WR-08). The TEST-04 subprocess test itself relies on `using ChunkSplitters` working in the spawned subprocess — which it cannot, until Manifest.toml is regenerated."
    artifacts:
      - path: "test/test_symulacja.jl"
        issue: "Line 229: hardcoded `JULIA_NUM_THREADS => 8` may oversubscribe / silently downgrade on small CI runners (WR-08)"
      - path: "src/energia.jl"
        issue: "Threading pattern correctness unverified (BL-04 + Manifest.toml regression)"
    missing:
      - "Pkg.instantiate() on Julia-equipped machine"
      - "TEST-04 subprocess executes successfully with bit-identical trasa for both thread settings"
      - "Optional but advisable: gate the 8-thread side on `max(2, Sys.CPU_THREADS)` rather than hardcoded 8"

  - truth: "SA result ≥ 10% shorter than NN baseline (N=1000, seed=42); T0 = 2σ from 1000 random delts"
    status: failed
    reason: "Cannot verify — Julia not installed; Manifest.toml not regenerated. Additionally, the BL-01 crash bug means any 1000-step or 20_000-step SA run on N=1000 (fixture size where `i = n-1` probability is 1/999 ≈ 0.1%) has ≈ 99.99%^20000 ≈ 13.5% chance of crashing **at least once** before completing. The TEST-05 NN-baseline-beat test is almost-certainly going to crash before reaching the 10% assertion line. The kalibruj_T0 implementation also has a sub-bug: `Statistics.std` returns `NaN` for length(worsening) == 1 (corrected=true divisor n-1), and the only guard is `@assert !isempty(worsening)` (REVIEW WR-01). For small `n_probek` (e.g. JET fixture uses n_probek=10) this is a real risk."
    artifacts:
      - path: "src/energia.jl"
        issue: "kalibruj_T0 at line 185: `@assert !isempty(worsening)` permits length==1 which makes std() return NaN, leading to silent SA failure (T_zero = NaN, exp(-Δ/NaN) = NaN, Metropolis always rejects worsening, SA degenerates to greedy)"
      - path: "src/algorytmy/simulowane_wyzarzanie.jl"
        issue: "BL-01 crash propagates into TEST-05 fixture (N=1000, 20_000 steps); test cannot reach the ratio assertion line"
    missing:
      - "Tighten `kalibruj_T0` assertion to `length(worsening) >= 2` (REVIEW WR-01)"
      - "Apply BL-01 fix"
      - "Live verification that TEST-05 produces ratio ≤ 0.9"

  - truth: "`julia --project=. test/runtests.jl` reports 0 failures (Hamilton, @inferred, @allocated == 0, multi-thread determinism, NN-baseline-beat, Aqua, JET, golden-value StableRNG(42))"
    status: failed
    reason: "Multiple, independent reasons:\n  (a) Julia is not installed in worktree, AND Manifest.toml has not been regenerated since Phase 2 deps were added — the package literally cannot load.\n  (b) BL-01 crash (above) makes the test suite probabilistically fail.\n  (c) BL-02 + IN-04 — the Aqua call structure is malformed: `check_extras` is nested inside `deps_compat` (test/runtests.jl:215-216), but `check_extras` is its own top-level Aqua kwarg. Aqua will silently ignore the misplaced config and run `check_extras` with defaults, which will fail because Project.toml [extras] declares 4 packages (BenchmarkTools, GLMakie, Makie, Observables) not in any [targets].test list and not on any Aqua ignore list.\n  (d) BL-03 — uruchom_sa! patience reset rule contradicts its own docstring/comment (best-known-minimum implementation vs delta<0 documented). The ALG-06 test only verifies *that* early-stop fires, not which semantics; semantic regression undetected.\n  (e) TEST-08 ships with `const TRASA_REF = Int[]` and `const ENERGIA_REF = NaN` placeholders + `@test_broken` guard (deferred-items.md). These placeholders are explicitly intentional but the corresponding helper script `test/_generuj_test08_refs.jl` has never been run — TEST-08 is `Broken` (not `Pass`). Roadmap SC-5 requires '0 failures' but `@test_broken` is not a Pass.\n  (f) WR-07 — the @allocated bound `< 4096` is loose enough to mask up to a 64-element Vector{Float64} allocation; this technically meets ENE-03 wording (margines for buforów wątków) but does not prove zero-alloc on the inner loop."
    artifacts:
      - path: "test/runtests.jl"
        issue: "Lines 215-216: `deps_compat = (ignore=..., check_extras=(ignore=[:Test, :Unicode],))` — check_extras is misplaced inside deps_compat tuple"
      - path: "Project.toml"
        issue: "[extras] declares BenchmarkTools, GLMakie, Makie, Observables — none are in [targets].test, none on Aqua ignore list (WR-04 was a wrong-numbered cross-reference; this is BL-02 in REVIEW)"
      - path: "test/test_symulacja.jl"
        issue: "Lines 45-46: const TRASA_REF = Int[]; const ENERGIA_REF = NaN — placeholders never replaced; TEST-08 ships @test_broken"
      - path: "src/algorytmy/simulowane_wyzarzanie.jl"
        issue: "Lines 127-175: docstring text contradicts implementation re patience reset rule (BL-03); semantic ambiguity is shipped"
      - path: "Manifest.toml"
        issue: "Phase 2 deps not in manifest; package unloadable until Pkg.instantiate() runs"
    missing:
      - "Run Pkg.instantiate() on a Julia-equipped machine to regenerate Manifest.toml"
      - "Apply BL-01 sampling fix"
      - "Restructure Aqua kwargs: hoist check_extras to top level; add the unused-extras to its ignore list OR remove unused extras from Project.toml"
      - "Reconcile BL-03: pick rule (1) or rule (2), update comment + docstring + impl + add a unit test that distinguishes the two"
      - "Run `julia --project=. test/_generuj_test08_refs.jl`, paste output into test_symulacja.jl, delete helper script (Task 3b CI follow-up)"
      - "Provide first CI green run as evidence (the SUMMARYs all defer this; nothing in the codebase verifies it actually works)"

deferred:
  # No items deferred to later phases. Phase 2 is meant to be self-contained per the roadmap goal:
  # "Pełen suite testowy z gwarancjami type-stability, zerowych alokacji i poprawności cyklu Hamiltona PRZED jakąkolwiek wizualizacją."
  # All 5 success criteria must be true *before* Phase 3 begins.
human_verification:
  # Listed for completeness — but do NOT route to human until BL-01 / Manifest / Aqua-kwargs fixes are applied first.
  - test: "After applying all gap-closure fixes, run on a Julia-equipped machine: `julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'`"
    expected: "Exit code 0; Test Summary shows ≥ 10 testsets all Pass; zero Fail; zero Error; zero Broken (or only TEST-08 Broken if Task 3b helper still pending — but goal SC-5 says 0 failures, so Broken is also a gap)"
    why_human: "Worktree has no Julia toolchain; CI matrix execution is the canonical proof for Roadmap SC-5"
  - test: "Verify TEST-05 ratio assertion holds with seed=42 + N=1000 + liczba_krokow=20_000"
    expected: "@info line shows ratio ≤ 0.9; if it does not, bump liczba_krokow to 50_000 and re-run; document choice in 02-VERIFICATION addendum"
    why_human: "Quality threshold is single-seed deterministic but specific to algorithm parameters chosen in Phase 2 — needs empirical confirmation"
  - test: "Verify Aqua does not flag unbound_args false-positive on StanSymulacji{R} (Pitfall F)"
    expected: "If Aqua reports unbound_args, add `unbound_args=(broken=true,)` kwarg per Pitfall F protocol"
    why_human: "Aqua heuristics are runtime-discovered; documented contingency in PLAN 02-06 needs runtime confirmation"
  - test: "Verify JET TEST-07 does not flag type-instability on the 4 hot-path functions"
    expected: "All 4 @test_opt assertions pass with target_modules=(JuliaCity,)"
    why_human: "JET findings depend on actual compiled type inference; runtime confirmation needed; if it fails, RULE 1 fix per the issue (most likely candidate: kwarg `rng=stan.rng` in kalibruj_T0 lacks type annotation → REVIEW WR-05 + plan 02-02 SUMMARY decisions)"
---

# Phase 2: Energy + SA Algorithm + Test Suite — Verification Report

**Phase Goal (ROADMAP):** Algorytmiczny rdzeń — `oblicz_energie` z `Threads.@threads` na chunkach krawędzi, `delta_energii` w O(1), `symuluj_krok!` dla `SimAnnealing` (NN init + 2-opt + Metropolis + cooling α≈0.995 + T₀ kalibrowane automatycznie + stagnation patience). Pełen suite testowy z gwarancjami type-stability, zerowych alokacji i poprawności cyklu Hamiltona **PRZED jakąkolwiek wizualizacją**.

**Verified:** 2026-04-29T13:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Verifier Stance

This verification was conducted with explicit adversarial framing: assume goal NOT achieved until codebase evidence proves it. Six SUMMARY.md files claim success, but every single plan documented "runtime verification deferred to CI" — no SUMMARY contains evidence of an actual `Pkg.test()` run. The `02-REVIEW.md` independently flagged 4 Blockers + 9 Warnings + 5 Info before this verification began.

The phase goal explicitly states deliverables must be guaranteed correct **before** any visualization work begins. A probabilistic crash that shows up ≈ 5% per step on the test fixture is not a guarantee.

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria, all 5 mandatory)

| #   | Truth                                                                                                                                                          | Status     | Evidence                                                                                                                                                                                                                                                                                                              |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `oblicz_energie(punkty, trasa)` returns true Euclidean cycle length on Hamilton cycle (4-square → 4.0 ± eps); type-stable; alloc < 4096 B post-warmup          | ✗ FAILED   | Code present and structurally plausible (src/energia.jl:71-90, 109-123); Python algorithmic mirror in 02-02-SUMMARY confirms 4.0. **But:** Manifest.toml does not contain ChunkSplitters → package will fail to load. BL-04: `enumerate(chunks(...))` inside `Threads.@threads :static` is a non-canonical pattern.   |
| 2   | `symuluj_krok!` type-stable, @allocated == 0 post-warmup; sort(stan.trasa) == 1:n after every step                                                             | ✗ FAILED   | **BL-01 crash bug ships in delivered code**: src/algorytmy/simulowane_wyzarzanie.jl:108-109 samples from empty range `(n+1):n` when `i == n-1` — ~5% per call for N=20 fixture. Hamilton invariant cannot be guaranteed if the function throws ArgumentError. Bug is documented in deferred-items.md but **NOT fixed**. |
| 3   | Same master seed under JULIA_NUM_THREADS=1 vs 8 → identical final tour                                                                                         | ✗ FAILED   | Cannot verify — Julia not installed AND Manifest.toml regression. Even with runtime: TEST-04 subprocess hardcodes 8 threads (REVIEW WR-08). The threading pattern correctness (BL-04) is unverified.                                                                                                                  |
| 4   | SA result ≥ 10% shorter than NN baseline (N=1000, seed=42); T₀ = 2σ                                                                                            | ✗ FAILED   | Cannot verify — Julia not installed. BL-01 makes a 20_000-step SA run on N=1000 ~13% likely to crash at least once before completion. WR-01: kalibruj_T0 returns NaN for length(worsening)==1.                                                                                                                       |
| 5   | `julia --project=. test/runtests.jl` reports 0 failures (Hamilton, @inferred, @allocated, multi-thread determinism, NN-beat, Aqua, JET, StableRNG(42) golden) | ✗ FAILED   | (a) Cannot run — Julia not installed + Manifest stale; (b) BL-02 + IN-04: Aqua kwargs are malformed (check_extras misplaced inside deps_compat); 4 unused extras will fail check_extras; (c) BL-03: patience semantics ambiguity; (d) TEST-08 ships `@test_broken` (placeholder state — Broken ≠ Pass per SC-5).      |

**Score:** 0/5 truths verified. **Phase goal not achieved.**

### Required Artifacts

| Artifact                                          | Expected                                                                                | Status              | Details                                                                                                                                                                  |
| ------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Project.toml`                                    | ChunkSplitters + Statistics + PerformanceTestTools entries                              | ⚠️ PRESENT-but-bug  | UUIDs correct; **but** [extras] has 4 unused entries (BenchmarkTools, GLMakie, Makie, Observables) without ignore-list (BL-02)                                            |
| `Manifest.toml`                                   | Resolved with Phase 2 deps                                                              | ✗ STALE              | `project_hash = bdc30d7b...` (Phase 1 hash); no ChunkSplitters / PerformanceTestTools entries; never regenerated since Phase 2 began                                      |
| `src/typy.jl`                                     | `Base.@kwdef struct Parametry` with liczba_krokow=50_000                                | ✓ VERIFIED          | typy.jl:91-93 exact match                                                                                                                                                |
| `src/JuliaCity.jl`                                | using ChunkSplitters + Statistics; export 14 names                                     | ✓ VERIFIED          | JuliaCity.jl:22-23, 41-45 — all 14 exports present                                                                                                                       |
| `src/energia.jl`                                  | 4 functions (5 methods)                                                                 | ⚠️ PRESENT-with-bugs | All 5 methods present (188 lines). **Bugs:** BL-04 enumerate(chunks(...)) pattern; BL-01 in kalibruj_T0 line 178; WR-01 std-NaN edge case; WR-02 j==i+1 boundary loose   |
| `src/baselines.jl`                                | trasa_nn + inicjuj_nn!                                                                  | ✓ VERIFIED          | baselines.jl:50-73 + 95-102; logic matches RESEARCH Pattern 3                                                                                                            |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | SimAnnealing struct + ctors + symuluj_krok! + uruchom_sa!                               | ⚠️ PRESENT-with-bugs | All 4 components present (175 lines). **Bugs:** BL-01 line 108; BL-03 docstring/impl mismatch; WR-03 (1, n) wasted O(n); WR-04 unused params; WR-05 ctor-mutates-RNG     |
| `src/algorytmy/.gitkeep`                          | DELETED (per plan)                                                                      | ✓ VERIFIED          | Confirmed deleted (commit 0ee9035)                                                                                                                                       |
| `test/test_energia.jl`                            | 7 sub-testsets in outer wrapper                                                         | ✓ STRUCTURE OK     | 149 lines, structure matches plan; **runtime unverified**                                                                                                                 |
| `test/test_baselines.jl`                          | 4 sub-testsets, TEST-05 NN-baseline-beat                                                | ✓ STRUCTURE OK     | 125 lines; structurally correct; **TEST-05 ratio unverified**                                                                                                             |
| `test/test_symulacja.jl`                          | 7 sub-testsets, TEST-08 with hardcoded refs                                             | ⚠️ PRESENT-stub     | 270 lines, all testsets present; **TEST-08 placeholders never replaced** (Int[] / NaN); @test_broken guard active                                                          |
| `test/_generuj_test08_refs.jl`                    | Helper script for TEST-08 — should be DELETED post-CI run                               | ⚠️ STILL PRESENT    | 27 lines; was supposed to be one-shot + deleted; never run                                                                                                                |
| `test/runtests.jl`                                | 3 includes + Aqua TEST-06 + JET TEST-07                                                 | ⚠️ PRESENT-with-bug  | Includes correct; **Aqua kwargs malformed** (check_extras inside deps_compat — IN-04/BL-02); JET fixture structurally sound                                                |

### Key Link Verification

| From                                              | To                                            | Via                                                                                  | Status              | Details                                                                                                                                                                          |
| ------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/JuliaCity.jl`                                | `src/energia.jl`                              | `include("energia.jl")` (line 32)                                                    | ✓ WIRED             | Topological order correct                                                                                                                                                        |
| `src/JuliaCity.jl`                                | `src/baselines.jl`                            | `include("baselines.jl")` (line 35)                                                  | ✓ WIRED             | Topological order correct                                                                                                                                                        |
| `src/JuliaCity.jl`                                | `src/algorytmy/simulowane_wyzarzanie.jl`      | `include("algorytmy/simulowane_wyzarzanie.jl")` (line 38)                            | ✓ WIRED             | Topological order correct                                                                                                                                                        |
| `src/JuliaCity.jl`                                | `ChunkSplitters` package                      | `using ChunkSplitters` (line 22)                                                     | ✗ NOT_LOADABLE      | Package not in Manifest.toml — `using ChunkSplitters` will throw at module-load time until Pkg.instantiate() runs                                                                |
| `src/JuliaCity.jl`                                | `Statistics` stdlib                           | `using Statistics: std` (line 23)                                                    | ✓ WIRED             | stdlib — available without Manifest entry                                                                                                                                         |
| `src/energia.jl::oblicz_energie`                  | `ChunkSplitters.chunks`                       | `enumerate(chunks(1:n; n=nchunks))` inside `@threads :static` (line 113)             | ⚠️ NON-CANONICAL    | BL-04: pattern is unsupported / undefined; canonical is `@threads :static for chunk_idx in 1:nchunks` followed by indexing into `collect(chunks(...))` or directly into `chunks` |
| `src/energia.jl::delta_energii`                   | `stan.D` lookups                              | 4 D-lookups + 4 t-lookups in formula (lines 152-153)                                 | ✓ WIRED             | Formula matches D-06 LOCKED                                                                                                                                                       |
| `src/energia.jl::kalibruj_T0`                     | `Statistics.std`                              | `std(worsening)` (line 186)                                                          | ⚠️ WIRED-fragile    | Wired correctly but WR-01: returns NaN for length==1 — undetected by current `@assert !isempty` guard                                                                             |
| `src/algorytmy/simulowane_wyzarzanie.jl::SimAnnealing` ctor kwarg | `kalibruj_T0(stan)`                  | Default kwarg `T_zero=kalibruj_T0(stan)` (line 65)                                   | ⚠️ WIRED-side-effect| WR-05: ctor advances `stan.rng` ≈ 2000 calls when T_zero defaulted — surprising side-effect for an immutable struct ctor                                                          |
| `src/algorytmy/simulowane_wyzarzanie.jl::symuluj_krok!` | `delta_energii(stan, i, j)`             | Direct call (line 112)                                                               | ✓ WIRED             | Argument flow correct                                                                                                                                                            |
| `src/algorytmy/simulowane_wyzarzanie.jl::symuluj_krok!` | `stan.rng` → Metropolis acceptance      | `rand(stan.rng, ...)` × 3 (lines 108, 109, 113)                                      | ✗ CRASH-PRONE       | BL-01: line 109 crashes when `i == n-1` (empty `(n+1):n` range)                                                                                                                  |
| `test/test_symulacja.jl::TEST-04`                 | `PerformanceTestTools.@include_foreach`       | macro call (line 225-231)                                                            | ⚠️ WIRED-fragile    | WR-08: hardcoded 8 threads may oversubscribe / silently downgrade on small CI; subprocess depends on Manifest being current                                                       |
| `test/test_symulacja.jl::TEST-08`                 | `TRASA_REF`, `ENERGIA_REF` consts             | Constants declared at module level (lines 45-46)                                     | ⚠️ STUB             | `TRASA_REF = Int[]`, `ENERGIA_REF = NaN` — placeholders, asercje wrapped in `@test_broken` (line 165-167)                                                                          |
| `test/test_baselines.jl::TEST-05`                 | `stan.energia / energia_nn ≤ 0.9`            | Assertion on ratio (line 121)                                                        | ⚠️ UNVERIFIED       | Logic correct; **runtime unverified**                                                                                                                                              |
| `test/test_symulacja.jl::ALG-06 patience`         | `uruchom_sa!`                                 | Direct call with cierpliwosc=10, alfa=0.5, cap=10000 (line 260)                      | ⚠️ WIRED-but-rule-mismatch | BL-03: test only proves *that* early-stop fires; does not distinguish best-known-min vs delta<0 reset rule semantics                                                       |
| `test/runtests.jl::Aqua`                          | `JuliaCity` package                           | `Aqua.test_all(JuliaCity; ...)` (line 211-218)                                       | ✗ MALFORMED         | BL-02 + IN-04: `check_extras` is misplaced inside `deps_compat` tuple instead of being a top-level kwarg                                                                          |
| `test/runtests.jl::JET TEST-07`                   | 4 hot-path functions                          | `@test_opt target_modules=(JuliaCity,)` × 4 (lines 246-249)                          | ⚠️ STRUCTURE OK     | Structure correct; **runtime unverified**                                                                                                                                          |

### Data-Flow Trace (Level 4)

| Artifact                                | Data Variable          | Source                                              | Produces Real Data | Status                                                                                                       |
| --------------------------------------- | ---------------------- | --------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------ |
| `oblicz_energie(punkty, trasa)` 2-arg   | return value Float64   | inline upper-tri D + 3-arg threaded delegate        | Cannot verify      | Pattern correct on paper; BL-04 threading + Manifest stale = no runtime evidence                              |
| `symuluj_krok!`                         | `stan.energia` += delta | `delta_energii(stan, i, j)` after Metropolis accept | Cannot verify      | BL-01 makes the call probabilistically unreachable on N=20                                                    |
| `kalibruj_T0`                           | return value Float64   | `2 * std(worsening)`                                | Cannot verify      | WR-01: NaN risk for length==1; bug ships                                                                      |
| `inicjuj_nn!`                           | `stan.D, stan.trasa, stan.energia` | 4-step pipeline                          | Cannot verify      | Logic plausible; depends on `oblicz_energie` 3-arg working (which depends on BL-04 threading working)         |
| `uruchom_sa!`                           | return Int (n_krokow)  | while-loop on `symuluj_krok!`                       | Cannot verify      | BL-03: patience reset rule ambiguity → semantics not pinned down even if runtime works                        |

### Behavioral Spot-Checks

| Behavior                                                                                                                  | Command                                                                              | Result                          | Status |
| ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------- | ------ |
| `julia --version` returns ≥ 1.10                                                                                          | `where julia`                                                                        | "Could not find" — Julia missing | ✗ SKIP |
| `using JuliaCity` loads without error                                                                                     | (would be) `julia --project=. -e 'using JuliaCity; println("OK")'`                   | N/A — Julia missing             | ✗ SKIP |
| `oblicz_energie(square4, [1,2,3,4]) ≈ 4.0`                                                                                | (would be) `julia --project=. -e ...`                                                | N/A — Julia missing             | ✗ SKIP |
| `Pkg.test()` exits 0                                                                                                       | (would be) `julia --project=. -e 'using Pkg; Pkg.test()'`                            | N/A — Julia missing             | ✗ SKIP |

**Step 7b SKIPPED — no runnable entry point** (Julia toolchain absent in worktree). Every behavioral guarantee is unverifiable here. Phase 1 had Julia available and ran a live `Pkg.test()` (80/80 Pass) per `01-VERIFICATION.md`. Phase 2 has no equivalent evidence.

### Requirements Coverage

| Requirement | Source Plan(s) | Description                                                       | Status   | Evidence                                                                                                                                  |
| ----------- | -------------- | ----------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| ENE-01      | 02-02, 02-05   | `oblicz_energie::Float64` returns Hamilton cycle length           | ⚠️ PARTIAL | Code present (energia.jl:71-90) + test (test_energia.jl:19-26); **runtime unverified, Manifest stale**                                     |
| ENE-02      | 02-02, 02-05   | type-stable                                                       | ⚠️ PARTIAL | `@inferred` test present (test_energia.jl:36, 51); **runtime unverified**                                                                  |
| ENE-03      | 02-02, 02-05   | post-warmup alloc < 4096 B                                        | ⚠️ PARTIAL | `_alloc_3arg` helper present (test_energia.jl:54); WR-07: bound is loose; **runtime unverified**                                            |
| ENE-04      | 02-02, 02-05   | `delta_energii` O(1) without copying                              | ✓ SATISFIED-on-paper | Code matches D-06 (energia.jl:145-154); zero-alloc test present (test_energia.jl:92-98); **runtime unverified**                            |
| ENE-05      | 02-02          | `Threads.@threads :static` on edge chunks, no boxing               | ✗ FAILED  | BL-04: `enumerate(chunks(...))` pattern is non-canonical and may be silently broken; behavioral test only checks in-process determinism   |
| ALG-01      | 02-01, 02-04   | `Algorytm` abstract + `SimAnnealing<:Algorytm` with hyperparams   | ✓ SATISFIED | typy.jl:28 + simulowane_wyzarzanie.jl:35-39 (concrete fields per Pitfall 1)                                                                |
| ALG-02      | 02-04          | `symuluj_krok!` mutates stan with 2-opt + Metropolis              | ✗ FAILED  | Code structurally present; **BL-01 makes the function probabilistically crash**                                                            |
| ALG-03      | 02-04, 02-05   | `symuluj_krok!` type-stable, `@allocated == 0`                    | ⚠️ PARTIAL | `@inferred` + `_alloc_krok` present (test_symulacja.jl:91, 99-106); **runtime unverified**                                                  |
| ALG-04      | 02-03, 02-05   | NN init via `trasa_nn(punkty)`                                    | ✓ SATISFIED | baselines.jl:50-73, 95-102; tested with permutation invariant (test_baselines.jl:33-35)                                                    |
| ALG-05      | 02-02, 02-05   | T₀ kalibrowane z 1000 delts, T₀ = 2σ                              | ⚠️ PARTIAL | Code present (energia.jl:172-188); **WR-01: NaN risk on length==1; runtime unverified**                                                    |
| ALG-06      | 02-04, 02-05   | Stop: stagnation patience                                         | ⚠️ PARTIAL | uruchom_sa! present (simulowane_wyzarzanie.jl:155-175); **BL-03: docstring contradicts impl**; test exists but does not distinguish rules |
| ALG-07      | 02-04          | Per-thread RNG deterministic from master seed                     | ⚠️ DEVIATION | D-09 LOCKED chose **single master RNG**, NOT per-thread RNG. ROADMAP says "per-thread RNG built deterministically from master seed". Plan 02-04 reinterpreted as "single master RNG → deterministic" (D-12). This is a deliberate scope reinterpretation — verifier flags it but does not block (Phase team's call). |
| ALG-08      | 02-04, 02-05   | Hamilton invariant after every step                               | ✗ FAILED  | Test present (test_symulacja.jl:122-130); **BL-01 makes the precondition fail probabilistically**                                          |
| TEST-01     | 02-05          | Hamilton invariant testset                                        | ⚠️ PARTIAL | Present; **BL-01 makes ~5% of test runs crash before assertion**                                                                            |
| TEST-02     | 02-05          | `@inferred` on public API                                         | ⚠️ PARTIAL | Present (test_energia.jl, test_symulacja.jl); **runtime unverified**                                                                       |
| TEST-03     | 02-05          | `@allocated == 0` on `symuluj_krok!`                              | ⚠️ PARTIAL | Present (test_symulacja.jl:99-106); **runtime unverified**                                                                                  |
| TEST-04     | 02-05          | Multi-thread determinism                                          | ⚠️ PARTIAL | Two testsets (in-process + subprocess); WR-08: hardcoded 8 threads; **runtime unverified**                                                  |
| TEST-05     | 02-05          | SA/NN ratio ≤ 0.9 on N=1000 seed=42                               | ⚠️ PARTIAL | Test present (test_baselines.jl:88-123); **BL-01 makes 20_000-step run ~13% likely to crash; runtime unverified**                            |
| TEST-06     | 02-06          | Aqua.test_all clean                                               | ✗ FAILED  | Test present but **Aqua kwargs malformed (BL-02/IN-04); 4 unused extras will fail check_extras**                                            |
| TEST-07     | 02-06          | JET `@report_opt` clean                                           | ⚠️ PARTIAL | Test present with `@test_opt`; **runtime unverified**; possible failure on kalibruj_T0 default kwarg (REVIEW WR-05)                          |
| TEST-08     | 02-05          | Golden-value test using `StableRNG(42)`                           | ✗ FAILED  | Test ships with `Int[]` / `NaN` placeholders + `@test_broken` guard; helper script never run; goal SC-5 says "0 failures" — Broken ≠ Pass  |

**Coverage:** 0 SATISFIED-with-runtime-evidence. 4 SATISFIED-on-paper (ALG-01, ALG-04, ENE-04 partial, ALG-07 with deviation note). 14 PARTIAL (code present but unverified). 4 FAILED (ENE-05 BL-04, ALG-02/ALG-08 BL-01, TEST-06 BL-02, TEST-08 stub).

**No orphaned requirements** — all 21 phase REQ-IDs are claimed by at least one plan's frontmatter, and REQUIREMENTS.md mapping confirms all 21 are Phase 2 work.

### Anti-Patterns Found

| File                                              | Line(s)        | Pattern                                                                                                                          | Severity      | Impact                                                                                                                                                              |
| ------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | 108            | `i = rand(stan.rng, 1:(n - 1))` — empty `(n+1):n` for j on i==n-1                                                                | 🛑 BLOCKER    | ArgumentError crash, ~5%/step on N=20; phase goal violation (BL-01)                                                                                                  |
| `src/energia.jl`                                  | 178            | Same pattern as above in kalibruj_T0                                                                                              | 🛑 BLOCKER    | Identical crash bug (BL-01)                                                                                                                                          |
| `src/energia.jl`                                  | 113            | `Threads.@threads :static for (i,x) in enumerate(chunks(...))` — non-canonical                                                   | 🛑 BLOCKER    | Threading correctness unverified; canonical pattern is documented (BL-04)                                                                                            |
| `test/runtests.jl`                                | 215-216        | `deps_compat = (..., check_extras=...)` — check_extras nested wrong                                                              | 🛑 BLOCKER    | Aqua test_all will fail check_extras with defaults (BL-02 + IN-04)                                                                                                   |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | 127-175        | Docstring claims `delta < 0` reset rule, impl uses `< energia_min` rule                                                          | ⚠️ WARNING    | Semantic ambiguity — readers will believe the wrong rule (BL-03)                                                                                                     |
| `src/energia.jl`                                  | 185            | `@assert !isempty(worsening)` — `std()` returns NaN for length==1                                                                 | ⚠️ WARNING    | Silent SA failure if only 1 worsening sample collected (WR-01)                                                                                                       |
| `src/energia.jl`                                  | 145-154        | `delta_energii` allows `j == i+1` (no-op edge), assertion does not exclude                                                       | ⚠️ WARNING    | Misleading boundary; `delta=0` for adjacent indices is the no-op case (WR-02)                                                                                        |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | 114-117        | (i=1, j=n) sample is always-accepted O(n) reverse with delta=0                                                                    | ⚠️ WARNING    | Wastes O(n) on a guaranteed-no-op swap; contradicts O(1)-per-step claim (WR-03)                                                                                       |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | 106            | `params::Parametry` arg unused inside symuluj_krok! body                                                                          | ⚠️ WARNING    | API surface noise; readers expect mutating this changes behavior (WR-04)                                                                                              |
| `src/algorytmy/simulowane_wyzarzanie.jl`          | 62-67          | `T_zero=kalibruj_T0(stan)` ctor default mutates `stan.rng` as side-effect                                                         | ⚠️ WARNING    | Surprising for immutable-struct ctor; non-obvious from call site (WR-05)                                                                                              |
| `test/test_energia.jl`                            | 41-48          | Distance-matrix loop duplicated (also in test_baselines.jl + 2× in src/)                                                          | ⚠️ WARNING    | Tests can pass even if `oblicz_macierz_dystans!` has a bug, because they build D inline (WR-09)                                                                       |
| `test/test_energia.jl`                            | 63             | `@allocated < 4096` — bound is too loose                                                                                          | ⚠️ WARNING    | Masks ≤ 64-element Vector{Float64} allocation; ENE-03 wording allows margin but does not prove zero-alloc inner loop (WR-07)                                          |
| `test/test_symulacja.jl`                          | 229            | Hardcoded `JULIA_NUM_THREADS=8`                                                                                                   | ⚠️ WARNING    | May oversubscribe / silently downgrade on small CI; misleading test name (WR-08)                                                                                      |
| `test/test_symulacja.jl`                          | 45-46          | `const TRASA_REF = Int[]; const ENERGIA_REF = NaN` — placeholders                                                                 | ⚠️ WARNING    | TEST-08 ships @test_broken; goal SC-5 says 0 failures (Broken is not Pass) (IN-01)                                                                                    |
| `Manifest.toml`                                   | 5              | `project_hash = bdc30d7b...` (Phase 1 hash)                                                                                       | 🛑 BLOCKER    | Manifest never regenerated for Phase 2 deps; package unloadable                                                                                                       |
| `src/energia.jl`                                  | 172-188        | kalibruj_T0 allocates `worsening` vector (push! growth)                                                                            | ℹ️ INFO        | Not a hot-path concern; called once at construction (IN-02)                                                                                                          |
| `src/algorytmy/simulowane_wyzarzanie.jl` + others | various        | Polish diacritics inconsistent across files (mixed NFC vs ASCII-folded)                                                           | ℹ️ INFO        | Style only; encoding hygiene test does not enforce (IN-03)                                                                                                            |

**Counts:** 4 BLOCKER + 1 BLOCKER (manifest) = 5 BLOCKER, 10 WARNING, 2 INFO. Cross-check with REVIEW: 4 BL + 9 WR + 5 IN = 18 — alignment is close (verifier counts the manifest issue as BLOCKER, not flagged in REVIEW; reviewer counts ALG-07 deviation differently from this verifier).

### Human Verification Required

See frontmatter `human_verification` section. **Recommended sequence:**

1. **Apply gap-closure fixes first** — do NOT route to human until BL-01 + Aqua-kwargs + Manifest regeneration are addressed in code.
2. **Then verify on Julia-equipped machine** via the listed test-plans.

### Gaps Summary

**Phase 2 ships with 5 unverified critical claims and at least 4 confirmed blocking defects:**

1. **Manifest.toml stale** — package cannot even load; nothing in the test infrastructure has any chance of running until `Pkg.instantiate()` is executed on a Julia machine. Every "Pkg.test() exits 0" claim across all 6 SUMMARYs is unverified.

2. **BL-01 — Probabilistic ArgumentError crash** in both `symuluj_krok!` (line 108) and `kalibruj_T0` (line 178). For the N=20 fixture used throughout the test suite, the empty-range crash fires at ~5.3% per step. Over 1000 steps that is ~50 expected crashes. The phase goal explicitly says the algorithm must be **guaranteed correct** before visualization — a 5%-per-step crash is not a guarantee. The bug is documented in deferred-items.md as "deferred" but **was never fixed in shipped code**. The locked-decision argument does not survive scrutiny: changing `1:(n-1)` to `1:(n-2)` removes an impossible (always-empty) sample without changing the (i, i+2..n) shape. The reviewer (BL-01 in 02-REVIEW.md) reaches the same conclusion.

3. **BL-02 / IN-04 — Aqua kwargs malformed.** `check_extras` is nested inside `deps_compat` tuple at test/runtests.jl:215-216, but `check_extras` is its own top-level Aqua kwarg. Aqua will silently ignore the misplaced config and run `check_extras` with defaults, which will fail because Project.toml [extras] declares 4 packages (BenchmarkTools, GLMakie, Makie, Observables) not in any [targets].test list and not on any Aqua ignore list.

4. **BL-03 — Patience reset semantics ambiguous.** `uruchom_sa!` docstring (line 130-131, 164) and inline comment claim "reset only on `delta < 0`" (per-step strict improvement, rule 2). Implementation (lines 167-169) uses `if stan.energia < energia_min` (best-known minimum, rule 1). These are different rules with different stop behaviors. The ALG-06 test only verifies *that* early-stop fires, not which semantics. A reader will believe the documented rule when the actual behavior is the implemented rule.

5. **BL-04 — Threading pattern non-canonical.** `Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))` at src/energia.jl:113 is at minimum unsupported in Julia 1.10 (`@threads` requires indexable iterators) and at worst silently broken on Julia minor-version bumps. The blessed pattern is `@threads :static for chunk_idx in 1:nchunks`.

6. **TEST-08 ships placeholders.** `const TRASA_REF = Int[]; const ENERGIA_REF = NaN` + `@test_broken` guard. The helper script `test/_generuj_test08_refs.jl` was supposed to be one-shot + deleted in Plan 02-05 Task 3b but is still present and was never run. Roadmap SC-5 requires "0 failures" — `@test_broken` is reported as Broken, not Pass.

7. **WR-01 — kalibruj_T0 returns NaN** for length(worsening) == 1. Sub-bug of ALG-05; the `@assert !isempty(worsening)` guard does not catch it.

8. **WR-08 — TEST-04 hardcodes 8 threads.** Will oversubscribe / downgrade silently on small CI runners.

**The phase goal is not achieved.** Multiple guaranteed-correctness requirements (ENE-05, ALG-02, ALG-08, TEST-06, TEST-08) are FAILED on substantive defects. The remaining 14 requirements are PARTIAL (code present but unverified — partly because of toolchain absence in worktree, but also because no one in the chain has reported a runtime green run on any machine).

**Recommended closure path** (informational — orchestrator decides):

- **Step 1 (closure-plan):** Fix BL-01 (1:(n-2) patch + N=3 regression test); fix BL-02/IN-04 (hoist check_extras + add unused-extras to ignore list OR remove unused extras from Project.toml); fix BL-04 (canonical chunked-threading pattern); reconcile BL-03 (pick rule + fix docs OR change impl to delta<0 + add a test that distinguishes); fix WR-01 (`length >= 2` assertion).

- **Step 2 (CI):** On a Julia-equipped machine: `Pkg.instantiate()` → `Pkg.test()` → if green, generate TEST-08 refs (`julia --project=. test/_generuj_test08_refs.jl`), paste into test_symulacja.jl, delete helper script, re-run `Pkg.test()`, verify exit 0.

- **Step 3 (re-verify):** Re-run this verifier; status should change to `passed` (or `human_needed` if Aqua/JET surface unanticipated runtime issues).

**One scope note:** ALG-07 wording in REQUIREMENTS.md is "Każdy wątek ma własny RNG zbudowany deterministycznie z master seeda — same seed + same nthreads → identyczna trasa końcowa". Phase 2 explicitly chose D-09 (single master RNG, no per-thread) and reinterpreted ALG-07 as "single master seed → deterministic trajectory" (D-12). This is documented in the plans and is a deliberate scope decision, not a defect, but the verifier flags it for awareness — it changes the RNG architecture without changing the original requirement text.

---

_Verified: 2026-04-29T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
