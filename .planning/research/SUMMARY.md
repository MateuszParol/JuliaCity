# Project Research Summary

**Project:** JuliaCity.jl
**Domain:** Julia scientific package — physics-inspired TSP heuristic with real-time GLMakie visualization, Polish-language UI, multithreaded
**Researched:** 2026-04-28
**Confidence:** HIGH overall (one MEDIUM area: algorithm-variant choice, deferred by design)

## Executive Summary

JuliaCity is a single-purpose Julia package that solves a 1000-point Euclidean 2D TSP with a "soap-bubble" heuristic and animates the tour shrinking live in a GLMakie window, with optional MP4/GIF export. It is simultaneously an algorithmic experiment, a teaching demo, and a quality-bar exercise (type-stable hot path, zero-allocation `symuluj_krok!`, `Threads.@threads` inside the inner loops, full `src/`/`test/`/`examples/` package layout, Polish UI/comments). The four research dimensions converge on a strikingly consistent picture, which makes the roadmap unusually well-grounded: stack is settled, table-stakes features are explicit in PROJECT.md, the architectural pattern is standard idiomatic Julia, and the dominant risks are textbook Julia/GLMakie pitfalls with known mitigations.

The recommended approach is: develop on Julia 1.11/1.12 (compat floor `1.10`), build on GLMakie 0.24.x + Observables, dispatch the algorithm variant via an `abstract type Algorytm end` hierarchy so the force-directed vs. SA-2-opt vs. hybrid decision can be deferred without reworking the surface, and ship v1 as a minimal SA-2-opt over a permutation (with NN initialization) so the visualization pipeline has a correct, fast core to drive. The "true" force-directed bubble pass is the single highest-risk feature and explicitly belongs to v1.1+, not v1. Quality gates are JET (type stability), `@allocated == 0` (zero-alloc hot path), Aqua (package hygiene), `StableRNG` (stream-stable golden values), BenchmarkTools (perf regression), all wired into a `test/runtests.jl` that runs headlessly.

The risk profile is dominated by four Julia-specific failure modes that compound each other: (1) abstract-typed struct fields silently destroying type stability in `StanSymulacji`, (2) closure-capture boxing inside `Threads.@threads` blocks giving both correctness and performance regressions, (3) shared RNG across threads breaking reproducibility, and (4) GLMakie Observable update storms turning a 60 FPS animation into a frozen window. All four are preventable with patterns documented in PITFALLS.md; the roadmap should encode the prevention as gating tests in early phases rather than as cleanup later. Polish-language source files add a fifth, lower-stakes risk class (UTF-8/BOM/NFC handling) that needs `.editorconfig` + `.gitattributes` from day zero and ASCII-only file names to survive Linux CI.

## Key Findings

### Recommended Stack

The Julia plotting and quality-tooling ecosystem has consolidated to a clear best stack for this exact use case: live OpenGL animation through GLMakie 0.24.x driven by Observables, MP4/GIF via the FFMPEG_jll runtime that ships transitively with Makie (`record(fig, "out.mp4", ...)`), and a four-layer quality gate (Test stdlib + Aqua + JET + BenchmarkTools) that is now standard for any Julia package that calls itself "production". `Threads.@threads :static` is the right baseline for parallel inner loops at N=1000; OhMyThreads/Polyester are escape hatches if profiling shows they are needed (likely not). Reproducibility splits cleanly: `Xoshiro` in `src/`, `StableRNG` in `test/` for golden values that survive Julia minor-version bumps. Plots.jl is mentioned in PROJECT.md as a fallback but should be removed from the decision after Phase 1; mixing Plots and Makie in the same project is a documented anti-pattern.

**Core technologies:**
- **Julia 1.11/1.12 (compat `1.10`)** — modern threading, Xoshiro default, ScopedValues; LTS floor for ecosystem reach
- **GLMakie 0.24.x + Makie 0.24.10** — only Makie backend with a real GPU renderloop; `record()` for MP4/GIF
- **GeometryBasics.jl + Observables.jl** — `Vector{Point2f}` inside `Observable` is the canonical animation contract
- **Test + Aqua + JET + BenchmarkTools + StableRNGs** — quality gate stack consensus from modernjuliaworkflows.org
- **Threads.@threads (baseline) + OhMyThreads (escape hatch)** — inner-loop parallelism only; outer loop stays single-threaded for SA acceptance and GL context safety

(Full version table, alternatives, and what-not-to-use rationale: `STACK.md`.)

### Expected Features

PROJECT.md's "Active" requirements already enumerate the table stakes; FEATURES.md confirms they are also the ecosystem expectation for a production-quality Julia algorithm-visualization package, and adds a clear set of high-leverage v1.1+ differentiators that materially improve the educational/demo value without expanding the v1 surface.

**Must have (table stakes — v1.0):**
- `generuj_punkty(n; seed=42)` returning `Vector{Punkt2D}` with deterministic RNG
- `oblicz_energie(punkty, trasa)::Float64` — type-stable, allocation-free, true Euclidean tour length
- `symuluj_krok!(stan, params, alg)` — in-place SA iteration with 2-opt move, zero-alloc after warmup
- Nearest-neighbor initial tour as starting point and benchmark baseline
- Geometric SA cooling (default α≈0.995, T₀ calibrated from initial Δ-energy distribution) + stagnation-patience stopping
- Hamilton-cycle invariant checked in tests after every step
- GLMakie window with `Observable{Vector{Point2f}}`-driven tour, Polish title/axes/labels, current-iteration + current-energy text overlay
- `record(...)` MP4/GIF export reusing the same simulation loop, gated by an `eksport` kwarg
- Full package layout: `Project.toml` with `[compat]`, `Manifest.toml` committed, `test/runtests.jl` covering tour validity + `@inferred` + `@allocated == 0` + NN-baseline-beat, `examples/` with quickstart, README in Polish with demo GIF
- `Threads.@threads` parallelism inside `oblicz_energie`/`delta_energii`, not on the outer step loop

**Should have (competitive differentiators — v1.1):**
- Dual-panel layout: tour view + energy curve over iterations (single biggest visual upgrade)
- Edge color encodes edge length (visual reinforcement of the bubble metaphor)
- Or-opt move blended ~30% with 2-opt (literature-supported quality bump)
- Speed slider + pause/resume button for live demos
- Configurable point distributions (`:jednostajny`, `:zgrupowany`, `:siatka`, `:okrąg`)

**Defer (v2+):**
- True force-directed smoothing pass (philosophically purest bubble physics, HIGH-risk; SA-2-opt with bubble naming is a defensible v1)
- Side-by-side NN-frozen vs. evolving comparison panel
- "Current move" highlight flash
- 3-opt / Lin-Kernighan moves (high implementation cost, marginal gain at N=1000)

(Anti-features explicitly rejected: Concorde/LKH integration, N>>1000, 3D/non-Euclidean metrics, web/server interface, English UI, drag-to-edit points. All fall under PROJECT.md Out of Scope. Full prioritization matrix: `FEATURES.md`.)

### Architecture Approach

A single top-level `module JuliaCity` with `include()`-d files, no nested submodules. All evolving state lives in one parametric, concretely-typed `mutable struct StanSymulacji{R<:AbstractRNG}` — the "no global state" hard requirement is satisfied by passing this struct as an argument. Algorithm variant is selected via Holy-traits / multiple-dispatch on an `abstract type Algorytm end` hierarchy (`ForceDirected`, `SimAnnealing`, `Hybryda`), so the deferred algorithm decision becomes additive: implement a new variant by dropping a file in `src/algorytmy/` and adding a `symuluj_krok!(stan, params, alg::NewVariant)` method, with zero changes to `wizualizuj`, `oblicz_energie`, or unrelated tests. The visualization layer mirrors core state through Observables but never owns it; core has no `using GLMakie`. Threading lives strictly inside `oblicz_energie`/`delta_energii` (embarrassingly parallel chunked sums); the outer animation loop is single-threaded because both SA acceptance and GLMakie's GL context demand it.

**Major components:**
1. **`typy.jl`** — `Punkt2D`, `StanSymulacji{R}`, `Parametry`, `abstract type Algorytm` (must be included first)
2. **`punkty.jl`** — pure `generuj_punkty(N; seed)` returning `Vector{Punkt2D}`
3. **`energia.jl`** — `oblicz_energie` (parallel chunked sum) and `delta_energii` (O(1) for 2-opt) — threading hot zone
4. **`algorytmy/{force_directed,simulated_annealing,hybryda}.jl`** — one file per `<:Algorytm` subtype with hyperparameters and `symuluj_krok!` method
5. **`symulacja.jl`** — top-level `symuluj_krok!` dispatch glue
6. **`wizualizacja.jl`** — only file in `src/` that imports GLMakie + Observables; backend-agnostic via `Makie` import for headless CI
7. **`eksport.jl`** — MP4/GIF helpers (small wrapper around `Makie.record`)

The architecture ensures the core is testable headlessly without OpenGL — critical for CI. Build order is strictly topological (`typy` → `punkty`/`energia`/`algorytmy` → `symulacja` → `wizualizacja` → `eksport`); algorithm correctness must be tested headlessly before `wizualizuj` is even started, because a "looks broken" live window is impossible to debug if the underlying algorithm is also wrong. (Full pattern catalog and anti-patterns: `ARCHITECTURE.md`.)

### Critical Pitfalls

PITFALLS.md flags 9 critical-tier failure modes; the top five compound the most and need the earliest prevention.

1. **Type instability in `StanSymulacji` via abstract-typed fields** — `trasa::Vector` (no eltype), `temperatura::Real`, or `rng::AbstractRNG` silently kill specialization and make the hot path 100× slower. Prevention: parametric struct with concretely-typed fields from day zero (`StanSymulacji{R<:AbstractRNG}` with `rng::R`); JET `@report_opt` + `@allocated == 0` regression tests in `test/runtests.jl`.
2. **Closure-capture boxing in `Threads.@threads`** — capturing and reassigning a scalar accumulator across the loop closure boxes it as `Core.Box`, simultaneously destroying type stability and introducing a data race. Prevention: per-thread accumulator slots in a pre-sized `Vector` reduced afterward; never write to a captured outer-scope scalar inside `@threads`. Add a determinism test: same seed + same `nthreads` → identical final tour.
3. **Shared RNG across threads** — manually constructed `MersenneTwister`/`Xoshiro` is not thread-safe; concurrent `rand!` calls produce duplicate streams or corrupted state. Prevention: build one RNG per thread/chunk from a master seed; never call `rand()` (no rng arg) inside `@threads` if reproducibility matters; use `StableRNG` only for tests.
4. **Broken Hamilton-cycle invariant from conflating force model with permutation** — the physical analogy operates on continuous geometry, TSP on combinatorial permutations. Mixing them lets the algorithm produce shorter "tours" by duplicating vertices. Prevention: pick one representation upfront (recommended: SA over permutations with 2-opt; "soap bubble" is the visual narrative, not literal force on coordinates); enforce `sort(trasa) == 1:n` after every step in tests.
5. **GLMakie Observable update storms** — `obs[] = ...` per simulation step at 1000+ steps/sec saturates the renderloop, freezes the window, drops frames, or fails to fire at all (in-place `obs[] .=` does not notify). Prevention: throttle with `KROKI_NA_KLATKE` (e.g., 50 sim steps per Observable update), `yield()` once per frame, batch multi-attribute updates via `Makie.update!`.

Three more critical pitfalls deserve roadmap visibility: `Makie.record` blocks the REPL with no progress indicator (wrap with `ProgressMeter`); GLMakie does not run on headless Linux CI without `xvfb` (need a CairoMakie fallback for tests); `MersenneTwister`-style golden-value tests break on Julia upgrades (use `StableRNG` for fingerprint tests). Polish-language source files add encoding traps on Windows (Windows-1250 vs. UTF-8, BOMs, NFC normalization); fix with `.editorconfig` + `.gitattributes` + ASCII file names + a CI guard. (Full pitfall catalog with detection signals and recovery costs: `PITFALLS.md`.)

## Implications for Roadmap

The four research streams converge on a phase ordering dictated by build dependencies (types → core → algorithm → tests → visualization → export → polish) plus two cross-cutting decisions (algorithm variant deferral, headless-testability). The roadmapper has unusual freedom on phase grouping but very little on phase order: skipping ahead to `wizualizuj` before the core is correct is the single most expensive mistake this project can make.

### Phase 0: Bootstrap & Conventions
**Rationale:** Polish-language source files require encoding hygiene from the first commit; retrofitting `.editorconfig`/`.gitattributes` after files have been saved as Windows-1250 means rewriting them. PkgTemplates produces the skeleton in seconds.
**Delivers:** Package skeleton, `Project.toml` with `[compat]` floors (`julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"`), `.editorconfig` (UTF-8, LF, no BOM), `.gitattributes`, `CONTRIBUTING.md` documenting Polish-for-user-strings / English-for-internal-asserts convention, ASCII-file-name policy, encoding-validation CI test stub
**Avoids:** Pitfalls 9 (Polish encoding), 18 (mixed-language errors)

### Phase 1: Core Types & Pure Helpers
**Rationale:** Every other file depends on `typy.jl`; type stability of `StanSymulacji` is the project's load-bearing decision. Get it right once, mechanically.
**Delivers:** `typy.jl` with `Punkt2D`, `StanSymulacji{R<:AbstractRNG}` (parametric, concretely-typed fields, pre-allocated scratch buffers), `Parametry`, `abstract type Algorytm end` hierarchy stubs; `punkty.jl` with `generuj_punkty(N; seed)`; first round of unit tests for point-cloud properties
**Uses:** `Random`/`Xoshiro`
**Avoids:** Pitfall 1 (type instability) — by construction

### Phase 2: Energy & Distance Hot Path
**Rationale:** `oblicz_energie` is the most-called function and the threading testbed; getting it allocation-free and type-stable is the precondition for everything downstream. Distance-matrix decision (precompute vs. on-the-fly) lands here, locked in by benchmark.
**Delivers:** `energia.jl` with `oblicz_energie` (parallel chunked sum, no captured-scalar boxing) and `delta_energii` (O(1) for 2-opt); precomputed `D::Matrix{Float64}` (8 MB at N=1000) stored on `StanSymulacji`; `@inferred` + `@allocated < 4096` tests
**Uses:** `Threads.@threads :static`, `@inbounds` after correctness verified
**Avoids:** Pitfalls 2 (closure-capture boxing), 10 (distance-matrix decision locked by benchmark)

### Phase 3: Algorithm Variant — SA-2-opt First
**Rationale:** PROJECT.md defers the variant choice to "research"; the Holy-traits architecture lets v1 ship with the simplest correct variant (SA over permutations + 2-opt + NN init + Metropolis acceptance + geometric cooling α≈0.995) while leaving force-directed and hybrid as additive future variants. SA-2-opt is the textbook combo with the most literature support and the lowest correctness risk; force-directed is the project's HIGH-risk feature and explicitly belongs in v1.1+.
**Delivers:** `algorytmy/simulated_annealing.jl` with `struct SimAnnealing <: Algorytm`; `symulacja.jl` with `symuluj_krok!(stan, params, alg::SimAnnealing)`; T₀ calibration (sample 1000 random Δ-energies, set `T₀ = 2σ`); stagnation-patience stopping; per-thread RNG vector built from master seed
**Avoids:** Pitfalls 3 (shared RNG), 4 (Hamilton invariant), 11 (cooling schedule calibrated, not guessed)
**Defers:** `ForceDirected`, `Hybryda` to v1.1+

### Phase 4: Parallelization Validation
**Rationale:** `Threads.@threads` is a stated requirement, but at N=1000 with sub-millisecond inner loops the correct parallelism granularity is non-obvious — naive outer-loop `@threads` may be slower than serial. This phase locks in the granularity decision with measurement.
**Delivers:** Benchmark sweep (`JULIA_NUM_THREADS=1,2,4,8`) for `oblicz_energie` and `symuluj_krok!`; `MIN_N_THREAD` threshold guard; documented choice; determinism test asserting same seed + any thread count → same tour
**Uses:** `BenchmarkTools` with `$` interpolation and `setup=` discipline
**Avoids:** Pitfalls 12 (`@threads` overhead), 16 (BenchmarkTools without `$`)

### Phase 5: Test Suite & Quality Gates
**Rationale:** PROJECT.md explicitly enumerates the test contract (Hamilton validity, type stability, zero-alloc hot path, NN-baseline-beat, benchmark vs. baseline). This phase wires it into `runtests.jl` and CI before visualization, so visualization can be developed against a known-correct core.
**Delivers:** `test/runtests.jl` with `@testset`s for: tour validity invariant, `@inferred` on every public function, `@allocated == 0` on `symuluj_krok!` after warmup, NN-baseline-beat assertion, JET `@report_opt` clean, Aqua all-on (each suppression has comment + upstream issue link), one `StableRNG` golden-value fingerprint test on a tiny fixture; `bench/` folder with reproducible benchmark scripts; CI workflow (GitHub Actions) running headlessly with `CairoMakie` fallback or `xvfb-run`
**Uses:** `Test`, `Aqua 0.8.14+`, `JET 0.11+`, `BenchmarkTools 1.6.x`, `StableRNGs 1.0.x`
**Avoids:** Pitfalls 8 (cross-version reproducibility), 15 (Aqua suppression drift), 7 (headless CI breakage)

### Phase 6: Visualization (GLMakie + Observables)
**Rationale:** Only attempted after the core is correct, fast, and tested. The Observables-mirror pattern keeps `wizualizacja.jl` as the single Makie-importing file in `src/`. Update-storm and GC-stutter risks land here.
**Delivers:** `wizualizacja.jl` with `wizualizuj(stan, params, alg; liczba_krokow, fps, eksport)` — GLMakie window, `Observable{Vector{Point2f}}` for the tour, throttled updates (`KROKI_NA_KLATKE` parameter), Polish axis labels/title/legend, current-iteration + current-energy text overlay (allocation-aware via pre-allocated `IOBuffer`), backend-agnostic API so CairoMakie can drive headless tests
**Uses:** `GLMakie 0.24.x`, `Observables 0.5.x`, `GeometryBasics.Point2f`
**Avoids:** Pitfalls 5 (Observable update storms), 13 (GC stutter), 7 (headless CI)

### Phase 7: Export & Examples
**Rationale:** `record(fig, "out.mp4", ...)` reuses the live loop verbatim, but blocks the REPL and overwrites silently. Examples must wrap bodies in `function main()` to avoid top-level slowness.
**Delivers:** `eksport.jl` with `eksportuj_mp4(...)` wrapping `Makie.record` + `ProgressMeter` + safe filename handling; `examples/podstawowy.jl`, `examples/eksport_mp4.jl` — each `function main(); ...; end; main()`; CI runs all examples end-to-end at small N
**Avoids:** Pitfalls 6 (`record` blocks), 19 (top-level slowness), 20 (disk fill)

### Phase 8: README, Demo GIF, Release Polish
**Rationale:** The demo GIF is the marketing for this package; producing it depends on Phases 6+7 working. Polish typography (proper „..." quotes) and font fallback (Polish diacritics rendering, not "tofu") matter once a screenshot leaves the repo.
**Delivers:** README in Polish (Core Value, install, quickstart, demo GIF embedded, benchmark numbers vs. NN, contributing pointer); `assets/demo.gif` produced by `examples/eksport_mp4.jl`; final benchmark numbers in README; release-tag PR
**Avoids:** UX pitfalls (axis labels, baseline comparison, Polish typography)

### Optional Phase 9: v1.1 Differentiators
Each is independently shippable post-v1: dual-panel tour+energy layout → edge-color-by-length gradient → Or-opt move → speed slider/pause-resume → configurable point distributions.

### Optional Phase 10: v2+ Force-Directed Bubble Pass
The "true" soap-bubble physics. HIGH-risk; only attempt after v1 + v1.1 are stable.

### Phase Ordering Rationale

- **Type system before any algorithm code** — retrofitting type stability into `Stan` after it has 30 callers is the highest-leverage mistake.
- **Energy/distance before algorithm** — `symuluj_krok!` calls `oblicz_energie`/`delta_energii`; benchmarking and threading the energy hot path in isolation is faster than disentangling it inside the algorithm step.
- **One algorithm variant in v1, others as v1.1+ additives** — honors PROJECT.md's deferral via Holy-traits; SA-2-opt is the lowest-risk variant with the most literature support; dropping force-directed from v1 does not invalidate the project.
- **Tests before visualization** — `wizualizuj` is hard to debug independently; a correct-and-tested core means any visualization issue is isolated to the visualization layer.
- **Visualization before export** — `record` is just the live loop wrapped in a context manager.
- **README/GIF last** — depends on Phases 6+7; benchmark numbers depend on Phase 5 being final.

### Research Flags

Phases likely needing deeper research during planning (recommend `/gsd-research-phase`):

- **Phase 3 (algorithm variant):** T₀ calibration procedure, stagnation-patience defaults, Or-opt blend ratio are problem-specific. The Hybryda variant (v1.1) needs research on phase-handoff conditions. The force-directed variant (v2) needs deep research — no canonical reference implementation exists for "force-directed-on-Hamilton-cycle TSP".
- **Phase 4 (parallelization):** Granularity decision is genuinely measurement-dependent; "don't thread tighter than ~100 µs per task" suggests inner loop may be too small. Need a focused benchmark pass before locking in.
- **Phase 6 (visualization):** Throttling parameter `KROKI_NA_KLATKE` and FPS cap are UX-tuning decisions; needs a quick spike to find sane defaults for N=1000 on commodity laptops.

Phases with standard patterns (skip research-phase):
- **Phase 0 (bootstrap):** PkgTemplates + `.editorconfig` + `.gitattributes` — fully standard.
- **Phase 1 (types) and Phase 2 (energy):** PITFALLS.md and ARCHITECTURE.md already specify the patterns at the level of pasteable code.
- **Phase 5 (tests/quality):** modernjuliaworkflows.org has the canonical recipe; STACK.md spells out versions.
- **Phase 7 (export) and Phase 8 (README):** mostly mechanical.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Versions verified against official sources April 2026; ecosystem consensus on GLMakie/Makie/JET/Aqua/BenchmarkTools combination is unambiguous. |
| Features | HIGH | Table stakes are explicit in PROJECT.md; differentiators corroborated by multiple peer-reviewed TSP/SA sources; anti-features map cleanly to Out of Scope. MEDIUM only on the force-directed bubble pass (no canonical reference, hence v2+ placement). |
| Architecture | HIGH | Single-module + `include` + Holy-traits + Observables-mirror are textbook idiomatic Julia, documented across SciML, modernjuliaworkflows.org, and Makie docs. The algorithm-variant abstraction is opinionated but the alternatives are clearly worse for this case. |
| Pitfalls | HIGH | All Critical pitfalls are documented in official Julia/Makie sources or well-cited Discourse threads with reproducible failure modes; prevention patterns are paste-ready. MEDIUM only on hardware-dependent thresholds (threading granularity, GC pause magnitude). |

**Overall confidence:** HIGH. The roadmap has unusually little ambiguity — the four research streams agree on every cross-cutting decision (one module, one mutable state struct, one algorithm dispatch hierarchy, threading-inside-not-outside, Observables-mirror, JET+Aqua+`@allocated` quality gates).

### Gaps to Address

- **Algorithm variant for v1 is asserted as SA-2-opt by synthesis, not by PROJECT.md.** PROJECT.md defers this to "research". The requirements step / Phase 3 planner should explicitly confirm SA-2-opt for v1 (with force-directed and hybrid as v1.1+/v2 additive variants), so the roadmap is not silently making the choice.
- **T₀ calibration procedure and stagnation-patience defaults are problem-specific.** Encode the calibration sample size (e.g., 1000 random Δ-energies on initial tour) and acceptance-ratio target (~80% at start, ~1% at end) as concrete defaults in Phase 3, but flag for empirical tuning before Phase 8 release.
- **Threading granularity at N=1000 is genuinely measurement-dependent.** The rule of thumb "don't thread tighter than ~100 µs per task" suggests `@threads` may be a no-op or net-negative at this N for the energy sum. The `MIN_N_THREAD` threshold guard in Phase 4 should default to no threading until measurement justifies it; PROJECT.md's "use `Threads.@threads`" requirement is satisfied by having the threading code path, not by it being faster.
- **CairoMakie fallback for headless CI requires a backend-agnostic API.** The visualization layer should be designed in Phase 6 with a `using Makie` (not `using GLMakie`) import discipline, with the backend chosen by a runtime/CI guard, not hardcoded.
- **Polish typography in Makie text.** Polish diacritics need a font that supports them; default Makie fonts handle them but a CI render-and-pixel-check guard is recommended in Phase 8 to catch "tofu" regressions.

## Sources

### Primary (HIGH confidence)
- **STACK.md sources:** endoflife.date/julia, julialang.org release notes (1.11/1.12), docs.makie.org (animation, observables, changelog 0.24.10), docs.julialang.org (multi-threading, Random), aviatesk.github.io/JET.jl, Aqua.jl repo (v0.8.14), StableRNGs.jl repo, OhMyThreads.jl docs, BenchmarkTools.jl docs, Chairmarks.jl docs, modernjuliaworkflows.org (sharing/optimizing)
- **FEATURES.md sources:** Metaheuristics.jl visualization docs, Makie animation/GridLayout/Observables docs, DTU thesis on TSP heuristic visualization, MDPI empirical comparison of local-search operators, Andresen on SA cooling strategies, Banchs on simulated annealing, tspgen + DIMACS portgen taxonomy, Julia Performance Tips manual
- **ARCHITECTURE.md sources:** Julia manual (modules, multi-threading), Pkg.jl creating-packages, Makie Observables/animations docs, SciML Style Guide, JuliaDynamics DynamicalSystems.jl visualizations
- **PITFALLS.md sources:** Julia Performance Tips, Multi-Threading manual, Random stdlib (TaskLocalRNG), JuliaLang/julia#15276 (closure capture), discourse.julialang.org #53964 (`@threads` overhead), FastClosures.jl, Aqua.jl docs, BenchmarkTools manual, PackageCompiler docs, Unicode/identifiers manual, MakieOrg/Makie.jl#1164/#1953/#420, JuliaLang/julia#49743

### Secondary (MEDIUM confidence)
- viralinstruction.com optimization guide
- discourse.julialang.org #77364 (random + threads), #103626 (slow Makie animations), #40235 (GC pauses), #68969 (squared euclidean distance), #20972 (BenchmarkTools setup/teardown)
- bkamins.github.io (RNG performance)
- scientificcoder.com (automate Julia code quality)
- TSP/SA academic sources: List-Based SA for TSP (PMC), Hybrid SA with adaptive cooling (ACM), Cooling Schedules for Optimal Annealing (Math. of OR)
- jling.dev (false sharing)
- Datseris gist on interactive Makie

---
*Research completed: 2026-04-28*
*Ready for roadmap: yes*
