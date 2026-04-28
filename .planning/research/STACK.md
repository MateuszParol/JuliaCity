# Stack Research

**Domain:** Julia scientific computing — TSP physics-heuristic with real-time visualization
**Researched:** 2026-04-28
**Confidence:** HIGH (versions verified against official sources April 2026)

## Executive Recommendation

Build `JuliaCity.jl` on **Julia 1.11.x or 1.12.x** (current stable is 1.12.6, LTS is 1.10.11). Use **GLMakie 0.24.10** for the live OpenGL window, with `record(...)` and the `FFMPEG_jll` runtime that ships transitively for MP4/GIF export. For correctness and perf gates, use **Test stdlib + Aqua + JET + BenchmarkTools** (with Chairmarks as an optional secondary). For threading the inner SA / force-directed loops over 1000 points, use plain **`Threads.@threads :static`** as the baseline and switch to **OhMyThreads.jl `@tasks`/`tmapreduce`** if a per-iteration TLS buffer is needed (1000 elems is borderline for thread overhead — measure). Reproducibility comes from seeding `StableRNG(42)` for tests and `Xoshiro(42)` for hot-path generation. Bootstrap the package layout with **PkgTemplates.jl** (or copy-paste a skeleton — both fine for a single package).

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Julia** | 1.11.x (preferred) or 1.12.6 | Language runtime | 1.11 ships ScopedValues, the `:greedy` `Threads.@threads` schedule, negative-seed `TaskLocalRNG`. 1.12 (released 2025-10-08) adds experimental code trimming and further multithreading improvements. 1.10 LTS (2023-12-25) is acceptable as the conservative floor, but loses 1.11+ threading conveniences and is being phased out by the ecosystem. **Recommendation: target `julia = "1.10"` in `Project.toml [compat]` for broad reach but develop on 1.11/1.12.** |
| **GLMakie.jl** | 0.10.x (paired with Makie 0.24.10) | Live OpenGL plotting window | Only Makie backend with a true GPU renderloop. CairoMakie is static raster (no live animation). WGLMakie targets browsers and adds JSServe complexity we don't need. Live `record()` works natively. |
| **Makie.jl** | 0.24.10 (released 2026-04-27) | Plotting framework that GLMakie implements | Released as part of the monorepo with GLMakie. v0.24 (2025-06-20) introduced ComputeGraph (replaces Observables for many internals, but the public Observable API remains the supported animation contract). |
| **FFMPEG_jll** | latest (transitive via Makie) | MP4/GIF/WebM encoding for `record()` | Makie docs explicitly state "Video files are created with FFMPEG_jll.jl". Pulled in transitively when you depend on Makie/GLMakie — **do not add as direct dep** unless you call ffmpeg yourself. |
| **GeometryBasics.jl** | 0.5.x | `Point2f`, `Point2`, `Vec2f` types Makie consumes | The native coordinate type for Makie scatter/lines. `Vector{Point2f}` inside an `Observable` is the canonical pattern for animated 2D plots. |
| **Observables.jl** | 0.5.x | Reactive containers for live plot updates | The supported animation primitive — mutate `obs[] = new_value` inside a `record()` block to push a frame. Wrap point arrays as `Observable{Vector{Point2f}}` to avoid x/y desync. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Test** (stdlib) | bundled | Unit tests, `@test`, `@testset` | Always — `test/runtests.jl` is the canonical entry point. |
| **Aqua.jl** | 0.8.14+ | Package quality gate (ambiguities, stale deps, type piracy) | Always — add `Aqua.test_all(JuliaCity)` to runtests.jl. Cheap, catches structural mistakes. |
| **JET.jl** | 0.11+ | Static type-stability analyzer (`@report_opt`, `@report_call`) | For the type-stability requirement in PROJECT.md. Use `@report_opt` on `oblicz_energie` and `symuluj_krok!` and assert no errors in CI. JET 0.11 is the current main static analysis tool per JuliaLang October 2025 update. |
| **Cthulhu.jl** | 2.x | Interactive type-inference descender | Dev-only (REPL). Use when JET flags an instability and you need to drill into the call tree. Don't add to test deps. |
| **BenchmarkTools.jl** | 1.6.x | Battle-tested microbenchmark framework | The ecosystem standard. Use `@benchmark` for the energy/step hot path and store results in `benchmarks/` for regression tracking. |
| **Chairmarks.jl** | 1.4+ | Faster benchmark framework (alt to BenchmarkTools) | Optional secondary. ~100x faster for CI loops, accepts non-interpolated globals more gracefully. Use if benchmark phase budget is tight. Not yet a 1:1 replacement for BenchmarkTools. |
| **StableRNGs.jl** | 1.0.x | RNG with stable cross-version streams | **Use in `test/`** to assert deterministic outputs that survive Julia minor-version bumps. The default `Xoshiro` stream is explicitly *not* guaranteed stable across minor releases. |
| **Random** (stdlib) | bundled | `Xoshiro`, `Random.seed!`, `randn` | Use in `src/` for the actual point generation — fast, idiomatic. Take an `rng::AbstractRNG = Xoshiro(42)` argument so callers can override. |
| **OhMyThreads.jl** | 0.7.x | Higher-level threading (`@tasks`, `tmap`, `tmapreduce`) | Use **only if** the inner loop needs per-task TLS buffers (e.g., per-thread accumulators for the energy delta). For a plain map over 1000 points, `Threads.@threads` is enough. |
| **Polyester.jl** | 0.7.x | Ultra-low-overhead `@batch` for tight inner loops | Use **only if** profiling shows `Threads.@threads` overhead dominates a sub-millisecond inner loop. For 1000 points and a non-trivial swap evaluation, plain `@threads` will not be the bottleneck. |
| **PkgTemplates.jl** | 0.7.x | Generates package skeleton + GitHub Actions CI | One-shot: run once at project init to create Project.toml, src/, test/, .github/workflows. Not a runtime dep. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Pkg** (stdlib) | Project/Manifest management | Always commit `Project.toml`; commit `Manifest.toml` for an *application* (this is one) — pins exact versions for reproducibility. |
| **Revise.jl** | Hot-reload during dev | Add to `~/.julia/config/startup.jl`, not to package deps. Speeds up the `using JuliaCity; example()` REPL loop dramatically. |
| **`@code_warntype`** (Base) | Quick type-stability spot check | Built-in. Use as a smoke test before reaching for JET. PROJECT.md explicitly mentions it. |
| **`--check-bounds=no`** + `@inbounds` | Hot-path elision | Use sparingly inside `oblicz_energie` and `symuluj_krok!` after correctness tests pass. Document with a comment. |

---

## Installation

```julia
# Bootstrap a new package skeleton (one-time, in REPL)
using Pkg
Pkg.add("PkgTemplates")
using PkgTemplates
Template(;
    user="<github-user>",
    plugins=[
        License(name="MIT"),
        Git(ssh=true),
        GitHubActions(),
        Codecov(),
        Tests(),
        Documenter{GitHubActions}(),
    ],
)("JuliaCity")
```

```julia
# Inside the generated JuliaCity/ directory, activate and add deps
using Pkg; Pkg.activate(".")

# Runtime deps (go in [deps] of Project.toml)
Pkg.add(["GLMakie", "Makie", "GeometryBasics", "Observables"])
# Optional perf deps — add only if profiling justifies them
# Pkg.add(["OhMyThreads", "Polyester"])

# Test deps (go in [extras] + [targets] of Project.toml, not [deps])
Pkg.activate("test")
Pkg.add(["Test", "Aqua", "JET", "BenchmarkTools", "StableRNGs"])
```

```toml
# Project.toml [compat] block — recommended floors
[compat]
julia = "1.10"
GLMakie = "0.10"
Makie = "0.24"
GeometryBasics = "0.5"
Observables = "0.5"
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **GLMakie** | **CairoMakie** | If you need publication-quality static SVG/PDF instead of live window. Not for this project (animation is core). |
| **GLMakie** | **WGLMakie** | If you need a browser-based demo. Adds JSServe + websocket complexity. Not for this project (PROJECT.md says local laptop). |
| **GLMakie** | **Plots.jl + GR backend** | Plots.jl listed as fallback in PROJECT.md. Viable for static plots and basic `@animate`/GIF, but its real-time interactive story is weaker — no GPU renderloop, animation is frame-replay not live update. **Use only if GLMakie OpenGL fails on a target machine.** |
| **Threads.@threads** | **OhMyThreads.@tasks** | When you need per-task TLS storage, custom chunking, or a `tmapreduce` reduction. Cleaner ergonomics for non-trivial parallelism. |
| **Threads.@threads** | **Polyester.@batch** | When `@threads` overhead dominates (sub-microsecond loop bodies). Static scheduling, reused tasks. **Caveat: not composable with nested threading.** |
| **BenchmarkTools** | **Chairmarks** | When CI runtime is tight or you want simpler global-variable handling. Solid but younger; pin a recent version. |
| **JET** | **`@code_warntype`** | One-off spot checks. JET wins for CI gating because it produces machine-readable reports. |
| **StableRNG (tests)** | **Random123 (Threefry/Philox)** | If you need *parallel* deterministic streams (counter-based RNG seeded per task). Overkill for a single-threaded seeded test fixture. |
| **PkgTemplates** | **PkgSkeleton.jl** / **BestieTemplate** | Both viable; PkgTemplates is the JuliaCI-blessed default and integrates with the registrator/TagBot toolchain. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Julia 1.6 LTS** or **1.0 LTS** | EOL (2024-10-08 / 2021-12-01). Missing modern threading, Xoshiro default RNG, ScopedValues. | Julia 1.10 LTS at minimum, prefer 1.11/1.12. |
| **Julia 1.11 as `[compat]` floor for distribution** | 1.11's official support ended 2025-10-08 (now superseded by 1.12). | Set `julia = "1.10"` for compat to support both LTS and current. |
| **CairoMakie for the live window** | Cairo is a CPU raster backend — no GPU renderloop. `record()` works but you re-render every frame from scratch on the CPU. | GLMakie for live; switch backend to CairoMakie only if exporting publication-grade PDFs. |
| **Plots.jl for the *primary* visualization** | Slower live updates, smaller animation feature set, ecosystem momentum has shifted. | GLMakie. Keep Plots.jl mental fallback only for triage. |
| **`Random.seed!(42)` without specifying RNG** | Mutates the global default RNG (TaskLocalRNG). Causes cross-test contamination and non-stable streams across Julia minor versions. | Pass an explicit `rng = Xoshiro(42)` (runtime) or `StableRNG(42)` (tests) into every random-using function. |
| **Global mutable state in src/** | PROJECT.md explicitly forbids it; also breaks type inference in closures (the "captured variables" pitfall — Julia can't infer types for variables modified across enclosing/inner functions). | Pass state as a struct argument; use `Ref{T}` only for genuine sentinel values. |
| **`Threads.@threads` *outside* a function** | Captures from global scope, kills type inference, kills perf. | Always wrap parallel loops inside a function with explicit-typed args. |
| **`@btime` outside `BenchmarkTools.@benchmark`** | Common confusion: `@btime` *requires* `using BenchmarkTools` and global-variable interpolation with `$`. Without `$` you measure dispatch on globals, not your code. | Either use `@benchmark` with interpolation, or switch to Chairmarks which handles globals gracefully. |
| **ReTest.jl** for new packages | Niche. Useful for very large test suites that need filtering, but adds an extra abstraction. | Plain `Test` stdlib + `@testset`. Add **ReTestItems.jl** only if you want VSCode TestItem integration and parallel test execution. |
| **Adding `FFMPEG_jll` directly to `[deps]`** | Already pulled in transitively by Makie. Adding it directly creates a version-pinning conflict. | Just depend on GLMakie — `record()` works out of the box. |

---

## Stack Patterns by Variant

**If algorithm = Force-Directed on Hamiltonian cycle:**
- Inner loop = "for each node, compute spring force from prev/next neighbors + repulsion from all others"
- Use `Threads.@threads :static` over the node index — embarrassingly parallel per-node
- Allocate force buffer **once** outside the loop, mutate in-place inside
- Keep `Vector{Point2f}` for points so it can flow straight into the `Observable` without conversion

**If algorithm = Simulated Annealing 2-opt:**
- Inner loop = "evaluate Δ-energy of N candidate 2-opt swaps, pick best/random by Metropolis criterion"
- Parallelism is at the *batch evaluation* level: `OhMyThreads.tmapreduce(eval_swap, +, candidates)` cleaner than raw `@threads` here
- Reduction needs a thread-safe accumulator — OhMyThreads handles this; raw `@threads` requires per-thread arrays + reduce
- StableRNG for the Metropolis acceptance test (so test suite can assert exact-trajectory reproducibility)

**If algorithm = Hybrid (SA shell + force-directed smoothing):**
- Two distinct hot paths — benchmark each separately
- Don't share thread pools between them in the same iteration; let `@threads` run sequentially in each phase

**If perf target is frame-rate-limited (~30-60 FPS for 1000 points):**
- Don't thread tighter than ~100 µs per task — overhead dominates
- For 1000 points, *one* SA iteration = ~1000 swap evaluations ≈ 10-100 µs total → **consider not threading the innermost loop**, instead thread across multiple SA iterations between frames

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Makie 0.24.x | Julia ≥ 1.10 | Issue #5496 discusses retroactive Julia version restrictions on old Makie. Stick to current Makie + current Julia. |
| GLMakie 0.10.x | Makie 0.24.x (matched in monorepo) | They are released together — never mix major versions across the monorepo backends. |
| GeometryBasics 0.5.x | Makie 0.24.x | Makie 0.24.4 added support for `GeometryBasics.MultiPoint`. Older GeometryBasics 0.4 is incompatible with current Makie. |
| Observables 0.5.x | Makie 0.24.x | Makie 0.24 introduced ComputeGraph internally but the user-facing `Observable` API is stable. Keep using `Observable{T}` for animation. |
| Aqua 0.8.x | Julia ≥ 1.6 | Stable. |
| JET 0.11.x | Julia ≥ 1.10 | 0.11 is the current main release per JuliaLang Oct 2025 announcement. |
| BenchmarkTools 1.x | Julia ≥ 1.6 | Mature, stable. |
| Chairmarks 1.x | Julia ≥ 1.6 | Newer, presented at JuliaCon 2025; pin a specific minor to avoid regressions. |
| OhMyThreads 0.7.x | Julia ≥ 1.10 | Active development; `chunksize` arg and `chunking=false` are recent additions. |
| StableRNGs 1.0.x | Julia ≥ 1.6 | Stable LCG; explicitly-frozen output stream. |

---

## Confidence Levels per Recommendation

| Recommendation | Confidence | Source |
|----------------|------------|--------|
| Julia 1.12 stable / 1.10 LTS / target 1.11+ | **HIGH** | endoflife.date verified 2026-04-10, julialang.org release notes |
| GLMakie over CairoMakie/WGLMakie for live | **HIGH** | Makie official docs, multiple ecosystem examples |
| Makie 0.24.10 current | **HIGH** | docs.makie.org/dev/changelog verified 2026-04-27 |
| `record()` uses FFMPEG_jll transitively | **HIGH** | Makie docs explicit statement |
| BenchmarkTools as primary, Chairmarks as alt | **HIGH** | modernjuliaworkflows.org, JuliaCon 2025 talk |
| JET + Aqua for CI quality gates | **HIGH** | modernjuliaworkflows.org/sharing, scientificcoder.com |
| Threads.@threads default, OhMyThreads if needed | **MEDIUM** | General community guidance; **specific recommendation depends on profiling 1000-element loops** — flag for benchmark phase |
| StableRNG (tests) + Xoshiro (runtime) | **HIGH** | Official Julia Random docs + StableRNGs.jl README |
| PkgTemplates for skeleton | **HIGH** | JuliaCI-maintained, standard practice |
| Plots.jl as live-animation fallback (not recommended) | **MEDIUM** | Inferred from ecosystem direction; PROJECT.md mentions as fallback |
| `Manifest.toml` should be committed (this is an app, not a library) | **HIGH** | Pkg.jl docs convention |

---

## Sources

### Official documentation (HIGH confidence)
- [endoflife.date/julia](https://endoflife.date/julia) — Julia version status verified 2026-04-10
- [Julia 1.11 Highlights](https://julialang.org/blog/2024/10/julia-1.11-highlights/) — ScopedValues, threading, RNG
- [Julia 1.12 Highlights](https://julialang.org/blog/2025/10/julia-1.12-highlights/index.html) — code trimming, threading
- [Julia v1.12 Release Notes / NEWS.md](https://docs.julialang.org/en/v1/NEWS/)
- [Makie Animation docs](https://docs.makie.org/stable/explanations/animation/) — `record()` API and FFMPEG_jll
- [Makie Changelog](https://docs.makie.org/dev/changelog) — version 0.24.10 (2026-04-27)
- [Makie Observables docs](https://docs.makie.org/dev/explanations/observables) — animation pattern
- [Multi-Threading Manual](https://docs.julialang.org/en/v1/manual/multi-threading/) — `@threads`, `:greedy` schedule
- [Random Manual](https://docs.julialang.org/en/v1/stdlib/Random/) — Xoshiro default, stable streams caveat
- [JET.jl docs](https://aviatesk.github.io/JET.jl/stable/) — `@report_opt` for type stability
- [Aqua.jl repo](https://github.com/JuliaTesting/Aqua.jl) — v0.8.14 (2025-08-04)
- [StableRNGs.jl repo](https://github.com/JuliaRandom/StableRNGs.jl) — stable streams
- [OhMyThreads.jl docs](https://juliafolds2.github.io/OhMyThreads.jl/stable/) — `@tasks`, `tmapreduce`
- [Polyester.jl docs](https://juliasimd.github.io/Polyester.jl/dev/) — `@batch` low-overhead threading
- [Chairmarks.jl docs](https://chairmarks.lilithhafner.com/) — fast benchmarking
- [PkgTemplates.jl User Guide](https://juliaci.github.io/PkgTemplates.jl/stable/user/)

### Community references (MEDIUM confidence)
- [Modern Julia Workflows — Sharing](https://modernjuliaworkflows.org/sharing/) — package quality stack
- [Modern Julia Workflows — Optimizing](https://modernjuliaworkflows.org/optimizing/) — benchmark/JET advice
- [scientificcoder.com — Automate Code Quality In Julia](https://scientificcoder.com/automate-your-code-quality-in-julia)
- [Julia Discourse — Chairmarks announcement](https://discourse.julialang.org/t/chairmarks-jl/111096)
- [Julia Discourse — Threading vs Polyester comparison](https://discourse.julialang.org/t/threading-threads-threads-vs-polyester-batch-vs-loopvectorization-tturbo/84576)
- [bkamins blog — RNG performance changes](https://bkamins.github.io/julialang/2024/02/16/rng.html)
- [JuliaLang October 2025 monthly](https://julialang.org/blog/2025/11/this-month-in-julia-world/index.html) — JET 0.11

---

*Stack research for: Julia TSP physics-heuristic with real-time GLMakie visualization*
*Researched: 2026-04-28*
