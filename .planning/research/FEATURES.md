# Feature Research

**Domain:** Algorithm-visualization package for TSP heuristic in Julia (live GLMakie animation, soap-bubble physics analogy)
**Researched:** 2026-04-28
**Confidence:** HIGH (mature problem domain, well-documented Julia/Makie idioms, clear scope boundaries from PROJECT.md)

## Scope Anchor

This catalogue is filtered through three hard constraints from `PROJECT.md`:

1. **N = 1000 points, Euclidean 2D, single-threaded GLMakie window** — anything that scales beyond this is anti-feature.
2. **Polish UI/comments mandatory** — labels, titles, axes, error messages, docstring narrative.
3. **Mandatory function contract:** `generuj_punkty()`, `oblicz_energie()`, `symuluj_krok!()`, `wizualizuj()` — every feature must compose with this surface.

"Table stakes" here means: omitting the feature would make a Julia user say *"this is a toy script, not a package."* "Differentiator" means: it earns the package its educational/demo value above competing TSP scripts on GitHub. "Anti-feature" means: explicitly listed in `PROJECT.md` Out of Scope or implied by the 1000-point ceiling.

---

## Feature Landscape

### Table Stakes (Users Expect These)

#### Algorithm features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Random uniform point generator with seed control** | Already in PROJECT.md Active Requirements; reproducible test runs are baseline Julia practice | LOW | `generuj_punkty(n; seed=42, rng=Xoshiro(seed))`. Use `Random.Xoshiro` (Julia 1.7+ default, fast, type-stable). Returns `Matrix{Float64}` (2×N) or `Vector{SVector{2,Float64}}` from `StaticArrays.jl` — the latter is recommended for hot-loop performance and zero allocations. |
| **Nearest-neighbor (NN) initial tour** | Universal TSP baseline; the user explicitly named NN as the comparison baseline. Without it, "the bubble shrunk the route" is not falsifiable | LOW | O(N²) construction is acceptable for N=1000 (~1M ops, sub-millisecond). NN tour also gives the soap-bubble heuristic a sensible starting topology rather than a random tangled cycle. |
| **2-opt local-search move** | Literature consensus: "2-opt neighborhood is especially adequate for routing problems"; for the soap-bubble analogy, 2-opt is the geometric move that "untangles" crossings — exactly the visual story | MEDIUM | Hot path: must be allocation-free (precompute squared distances? on-the-fly is fine for N=1000). Wrap as `apply_2opt!(tour, i, j)` with O(1) reversal via in-place reverse on a `CircularArray`-style segment. |
| **Energy / tour-length function** | Mandated by PROJECT.md as `oblicz_energie()`. Must be type-stable, allocation-free (PROJECT.md hard requirement) | LOW | Sum of Euclidean edges. Avoid `sqrt` in delta-energy comparisons where possible (squared distances suffice for relative SA acceptance). But `oblicz_energie` itself returns true Euclidean length — that's the contract. |
| **In-place simulation step** | Mandated as `symuluj_krok!()`. The `!` is the Julia community contract for mutation | LOW | One step = one or more local moves (e.g., "try K random 2-opts, accept if energy drops or SA roll passes"). Returns the new energy as `Float64` so the caller can plot it without re-computing. |
| **Hamilton-cycle validator** | Listed in PROJECT.md test suite requirements; without it, the package can silently produce broken tours | LOW | `is_valid_tour(tour, n) = length(tour) == n && Set(tour) == Set(1:n)`. Use as test invariant after every `symuluj_krok!`. |
| **Convergence detection: max-iterations + stagnation patience** | Standard stopping criteria across the SA literature: "stagnation is a well-known phenomenon … a common practice is to use stagnation as a stopping criterion" | LOW | Two parameters: `max_iter::Int`, `patience::Int` (no improvement for N consecutive iterations → stop). Energy-threshold convergence is overkill for a heuristic with no known optimum. |

#### Visualization features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Real-time edge drawing on GLMakie window** | Mandated by PROJECT.md. The whole project's *Core Value* hinges on the user seeing the bubble shrink | MEDIUM | Use `Observable{Vector{Point2f}}` for the cycle vertices; `lines!(ax, obs)` re-renders on `notify(obs)`. One observable for points, one for the tour-edge sequence. |
| **Tour evolves smoothly without flicker** | Anything choppy on a 1000-point cycle on a modern laptop reads as "broken" | MEDIUM | Update Observable at most every K simulation steps (decouple sim rate from frame rate). Avoid recreating the figure; only mutate `obs[]`. |
| **MP4/GIF export of the animation** | Mandated by PROJECT.md ("opcjonalny przełącznik"). The Julia/Makie idiom is `record(fig, "out.mp4", iter; framerate=30) do i ... end` | LOW | Wraps the same simulation loop with a `record` block. FFMPEG_jll is bundled. GIF is a one-line backend swap. |
| **Polish axis labels, title, legend** | Hard project requirement: "Język UI/komentarzy: wyłącznie polski" | LOW | "Długość trasy", "Iteracja", "Energia bańki", "Trasa początkowa (NN)", etc. |
| **Display of current iteration / current energy as on-screen text** | Without a number, the viewer can't tell if the bubble is still improving or has stalled | LOW | `text!(ax, lift(i -> "Iter: $i | E = $(round(E[]; digits=2))", iter_obs))`. |

#### Quality features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **`Project.toml` + `Manifest.toml` with pinned compat bounds** | Listed in PROJECT.md as "Pełna struktura pakietu Julia" | LOW | Compat bounds for `julia = "1.10"`, `GLMakie = "0.10"`, `StaticArrays`, `BenchmarkTools` (test-only). |
| **`test/runtests.jl` covering: tour validity, type stability, no-allocation hot path, NN baseline beat** | PROJECT.md explicitly enumerates each one | MEDIUM | `@inferred` for type-stability, `@allocated` for hot-path zero-alloc check, `@test final_length < nn_length` for the quality gate. |
| **Benchmark vs. NN baseline** | Listed in PROJECT.md Active Requirements | LOW | `benchmark/run.jl` printing: NN length, soap-bubble length, gap %, wall-clock per iteration. Use `BenchmarkTools.@btime` interpolating with `$`. |
| **Public API exports only the documented contract functions** | Hides internal helpers; standard Julia hygiene | LOW | `export generuj_punkty, oblicz_energie, symuluj_krok!, wizualizuj`. Anything else stays unexported. |
| **Docstrings in Polish on every exported function** | Project language requirement extends to `?function` help | LOW | First-line summary in Polish, examples block, argument table. |
| **Multi-threaded hot loops via `Threads.@threads`** | PROJECT.md hard requirement | MEDIUM | Best target: parallel evaluation of 2-opt move candidates, *not* the move-application itself (race). Apply `@threads` to "score K random candidate moves, then sequentially apply the best." |

---

### Differentiators (Educational / Demo Advantage)

These are where this package earns the right to exist instead of being a 200-line gist.

#### Algorithm differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Or-opt (segment relocation, length 1–3)** | The literature finding ("best results are obtained using a mixture of 2-opt, relocate, link swap") matters: a soap bubble *also* slides chains of beads around, not only flips. Visually, Or-opt produces qualitatively different motion than 2-opt — chain migration vs. crossing-flip | MEDIUM | Add as a second move operator with configurable mix ratio (`p_2opt = 0.7`, `p_oropt = 0.3`). One extra function, ~30 LOC. |
| **Geometric SA cooling schedule with documented α** | Literature: "α between 0.8 and 0.99 … the geometric schedule proved its performance" — the de facto standard. Avoids the trap of a logarithmic schedule that "is very slow and unrealizable in practice" | LOW | `T(k) = T₀ * α^k` with `T₀` calibrated from initial energy delta. Default `α = 0.995`. Expose as kwarg. |
| **Force-directed smoothing pass (true "soap bubble" component)** | This is the *naming differentiator*. A pure SA-2-opt package is "yet another TSP demo." The spring-pulling-cycle-tight pass is what makes it *JuliaCity* and not *AnotherTSP.jl* | HIGH | Each iteration: each city gets pulled by its two cycle neighbors (Hooke spring on edge over-length), with damping. Then snap to nearest valid topology. Tunable: `k_spring`, `damping`, `dt`. Literature warns: "springs are notoriously difficult to tune" — ship sane defaults and document them. |
| **Hybrid pipeline: NN init → SA-2-opt phase → bubble-relax finishing pass** | Matches PROJECT.md's "Hybryda — SA jako szkielet decyzyjny + force-directed wygładzanie" option. Each phase has a distinct visual signature, which is great for demos | MEDIUM | Compose existing primitives. Phase boundaries get printed to stdout in Polish ("Faza 1: konstrukcja NN ukończona…"). |

#### Visualization differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Dual-panel layout: tour view (top) + energy curve over iterations (bottom)** | The energy curve is the canonical "I can see SA actually working" indicator. Makie's `GridLayout` with `linkxaxes!` is the standard idiom. This is the single highest-leverage visualization feature beyond the bare tour | LOW–MEDIUM | `fig[1,1] = Axis(...)` for trasa, `fig[2,1] = Axis(...)` for energia. Energy is `Observable{Vector{Float64}}` that grows by `push!(obs[], new_E); notify(obs)`. |
| **Edge color encodes edge length (gradient: short=green, long=red)** | Reinforces the soap-bubble metaphor — long edges are "stretched" and stand out as visual tension. Free educational signal | LOW | `linecolor` per-segment via `linesegments!` with a color-vector observable. Use `:RdYlGn` colormap reversed. |
| **Speed control (frames-per-step slider) + pause/resume button** | Universal in algorithm-visualization tools; user can step into the "interesting" phase. Makie has native `Slider` and `Button` blocks | MEDIUM | A `frames_per_step` Observable controls how many `symuluj_krok!` invocations happen between Observable notifications. Pause = a `Bool` Observable gating the loop. Reset = re-call `generuj_punkty` with the same seed. |
| **Highlighted "current move" — flash the two edges that just got 2-opt-flipped** | Makes the algorithm legible: the viewer sees *what changed*, not just *that something changed* | MEDIUM | Add a transient `last_move::Tuple{Int,Int}` Observable; render those edges in a thicker stroke for K frames. |
| **Side-by-side comparison view: NN baseline (frozen) next to evolving bubble tour** | Makes the quality improvement visceral, not abstract. Two `Axis` blocks sharing the same point cloud | MEDIUM | Adds a third panel. Worthwhile only after dual-panel is shipped. |

#### Quality differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Configurable point distribution: `:uniform`, `:clustered`, `:grid`, `:circle`** | Literature standard — DIMACS portgen, tspgen all ship clustered + uniform. Clustered instances stress the bubble heuristic differently than uniform; this is a great pedagogical tool | LOW | Dispatched on a `Symbol` kwarg in `generuj_punkty(n; rozkład=:jednostajny, …)`. Uniform = `rand(rng, 2, n)`. Clustered = K Gaussian blobs. Grid = `√n × √n` regular lattice plus jitter. Circle = parametric (degenerate but instructive). |
| **`@code_warntype` smoke test in the test suite** | PROJECT.md requires type-stability checking. Encoding it as a test, not just a manual ritual, prevents regression | LOW | Use `Test.@inferred` on hot-path calls. For `symuluj_krok!`, also `@test (@allocated symuluj_krok!(state, args...)) == 0`. |
| **Examples folder with three demo scripts** | PROJECT.md mentions `examples/`. Suggested set: (1) live-window quickstart, (2) MP4 export with default settings, (3) clustered-distribution comparison run | LOW | Each <50 LOC, runnable with `julia --project=. examples/01_okno_na_zywo.jl`. |
| **README with embedded GIF showing the bubble shrinking on a 1000-point cluster** | The GIF *is* the marketing for this package. Captures Core Value in 5 seconds | LOW (assets), MEDIUM (production quality) | Generate via the existing GIF-export feature. Place in `assets/demo.gif`. |
| **CI workflow (GitHub Actions) running `julia --check-bounds=yes test/runtests.jl`** | Standard expectation for any "production-quality" Julia package | LOW | One YAML file, copies from any modern Julia package template. Headless GLMakie tests need `xvfb-run` or skip-on-CI guard. |

---

### Anti-Features (Explicitly NOT Built)

These are mostly direct reads from PROJECT.md "Out of Scope" plus features common in algorithm-vis tools that would actively harm this scope.

| Feature | Why Tempting | Why It's an Anti-Feature Here | Alternative |
|---------|--------------|-------------------------------|-------------|
| **Concorde / LKH-3 quality optimization** | Easy to spec ("just integrate LKH"), looks impressive in benchmarks | Explicit Out of Scope: "celem jest ładna heurystyka, nie state-of-the-art TSP solver". Wrapping LKH would dwarf the soap-bubble code and obscure the educational point | Compare against NN baseline only. Document the optimality gap honestly. |
| **N >> 1000 (e.g., 10k, 100k cities)** | "Why not?" curiosity scaling | Explicit Out of Scope. The animation would either drop frames or skip iterations, breaking the visual story. Force-directed iteration is O(N) per step → 100× more cities = 100× slower frames | Document that the package is tuned for N=1000. Hard-cap or warn at N>5000. |
| **3D tours / non-Euclidean metrics (Manhattan, geographic)** | Both add ~30 LOC and "more options" | Explicit Out of Scope: "metryki nieeuklidesowe łamią analogię". The whole physics story collapses: a soap bubble on a sphere is a different (interesting!) problem and dilutes this package | If someone wants this, fork. Don't add a `metric=:manhattan` kwarg. |
| **Web/server interface (Pluto-only is a gray area)** | Modern tooling expectation; Pluto+WGLMakie is one Project.toml away | Explicit Out of Scope. GLMakie's OpenGL acceleration is *what makes the 1000-point animation smooth*; WGLMakie or Genie would noticeably degrade the demo | Local script + recorded GIF for sharing. |
| **3-opt and Lin-Kernighan moves** | "More moves = better quality" intuition; LK is the gold standard | High implementation cost (LK needs careful neighborhood structure, segment reversal bookkeeping); their visual signature is *less* legible than 2-opt — they fix things via long chains of micro-edits. Quality gain is marginal vs. SA-2-opt + Or-opt at N=1000 | Stop at 2-opt + Or-opt. Document the choice in the README rationale. |
| **English UI / bilingual labels** | Wider audience, easier collaboration | Explicit Out of Scope: "Język inny niż polski w UI — twardy wymóg projektu". Any English string in a chart title is a contract violation | Ship Polish-only. If translation ever happens, do it as a fork or v2. |
| **Energy threshold as primary stop criterion** | Sounds principled | A heuristic with no known optimum has no calibrated energy threshold. Stagnation patience is the right idiom for SA | Use `patience` and `max_iter`. Energy threshold can be an *optional* extra kwarg, off by default. |
| **Logarithmic SA cooling schedule** | Theoretically guarantees global optimum | "Very slow and unrealizable in practice" — at 1000 points and animation-rate iterations the user would see no movement | Geometric, α=0.995 default. |
| **Live editing of point positions during animation (drag-to-move)** | Eye-catching interactive feature | Breaks the simulation invariants (energy comparisons across changing point sets are meaningless); visually busy without educational payoff. Doubles the UI complexity | Static point set per run. To explore a different layout, restart with a new seed or distribution. |
| **Per-edge tooltip on hover** | Algo-vis tools commonly have it | At N=1000 with edges criss-crossing, hover-hit-testing on lines is awkward and the tooltip rarely lands on the intended edge. Implementation cost vs. value is poor | Side panel showing global stats (current energy, # accepted moves, current temperature) is more legible. |
| **Multi-run statistical study mode (run K times, plot variance bands)** | Sounds rigorous, common in metaheuristic research | Doubles project scope; better fit for a downstream `JuliaCityBenchmarks.jl`. The single-run animation *is* the deliverable | Note in README that for empirical studies, scripts can call `wizualizuj` with `record=false` and aggregate externally. |

---

## Feature Dependencies

```
generuj_punkty (table stakes)
    └── used by ──> wszystko inne

Nearest-neighbor init (table stakes)
    └── required by ──> 2-opt phase (needs a starting tour)
    └── required by ──> baseline benchmark

oblicz_energie (table stakes)
    └── required by ──> SA acceptance rule
    └── required by ──> energy curve panel (differentiator)
    └── required by ──> stagnation/patience convergence detection

2-opt move (table stakes)
    └── required by ──> symuluj_krok!
    └── enhanced by ──> Or-opt (differentiator) — same neighborhood-search infrastructure
    └── enhanced by ──> "current move" highlight (differentiator)

symuluj_krok! (table stakes)
    └── required by ──> wizualizuj (live + recorded)
    └── required by ──> benchmark suite

GLMakie window with Observable-driven tour (table stakes)
    └── required by ──> dual-panel layout (differentiator)
    └── required by ──> edge-color-by-length gradient (differentiator)
    └── required by ──> pause/speed slider (differentiator)
    └── required by ──> MP4/GIF export (table stakes — same loop, wrapped in `record`)

Stagnation-patience convergence (table stakes)
    └── enhanced by ──> energy curve panel (differentiator) — patience is just plateau detection,
                                                              the panel makes it visible

Force-directed smoothing pass (HIGH-complexity differentiator)
    └── conflicts with ──> "no global state, allocation-free hot path"
                           if implemented naively. Resolve by storing forces in a preallocated
                           Vector{SVector{2,Float64}} that lives on the State struct.

Hamilton-cycle validator (table stakes)
    └── required by ──> test suite invariants
    └── required by ──> any 2-opt / Or-opt move (post-condition assertion in debug mode)

Configurable point distribution (differentiator)
    └── independent — pure addition to generuj_punkty
```

### Dependency Notes

- **Energy curve panel ↔ stagnation detection:** these share infrastructure. If the simulation already keeps a `Vector{Float64}` of historical energies for the panel, stagnation detection is a 3-line `findlast(e -> e < current_min - ε, history)` check. Build the history vector once.
- **Force-directed pass requires careful state design:** to keep the hot path allocation-free with `Threads.@threads`, the per-city force accumulator must be a preallocated buffer in the simulation `State` struct, not a fresh `Vector` per step. This is the single highest-risk feature in the project; if scope pressure hits, drop it before dropping anything in the table stakes column. The package can launch as "JuliaCity = SA-2-opt with NN init and live animation" and still meet PROJECT.md's Core Value.
- **MP4 export reuses the live loop verbatim** — Makie's `record` is just a context manager around the same Observable updates. This means the export feature is essentially free *if* the live loop is structured cleanly (no interactive blocking inside the loop body).
- **Speed/pause controls conflict with `record`:** during MP4 export, speed sliders are meaningless. Branch on a `mode::Symbol` parameter (`:live` vs `:record`) and only mount UI controls in `:live`.

---

## MVP Definition

### Launch With (v1.0)

This is the minimum that satisfies PROJECT.md's *Core Value*: user runs one command, sees 1000 points, watches the bubble shrink in real time, gets a tour shorter than NN.

- [x] `generuj_punkty(n=1000; seed=42, rozkład=:jednostajny)` — uniform distribution at minimum, others optional in MVP
- [x] `oblicz_energie(tour, points)` — type-stable, allocation-free, returns `Float64`
- [x] `symuluj_krok!(state)` — one SA iteration with 2-opt move; updates `state.tour`, `state.energy`, `state.iter`, `state.temperature` in place
- [x] Nearest-neighbor initial tour as the starting point (gives the bubble something to shrink from)
- [x] Geometric SA cooling, α=0.995, default `T₀` calibrated from mean edge length
- [x] Stagnation-patience stopping (default `patience=500`, `max_iter=50_000`)
- [x] `wizualizuj(state; eksport=nothing)` — opens GLMakie window, animates the tour, Polish title/axes, current-energy text overlay
- [x] When `eksport="trasa.mp4"` (or `.gif`), recorded file instead of live window
- [x] `Project.toml` with compat bounds; `test/runtests.jl` covering Hamilton validity, type inference, allocation-free hot path, NN-baseline-beat
- [x] One `examples/` script demonstrating the live window
- [x] README in Polish with one demo GIF

### Add After Validation (v1.1)

These multiply the educational/demo value once the core works. Each is independently shippable.

- [ ] **Dual-panel layout (tour + energy curve)** — single biggest visual upgrade; trigger: after v1 is on GitHub and at least one user has watched the demo
- [ ] **Edge color encodes edge length** — geometric reinforcement of the bubble metaphor; trigger: with dual-panel
- [ ] **Or-opt move blended at 30% with 2-opt** — solution-quality bump; trigger: when v1 baseline benchmark is < 5% better than NN, prompting the question "can we do better"
- [ ] **Speed slider + pause/resume button** — only matters for live demos and teaching; trigger: when someone uses the package in a presentation
- [ ] **Configurable point distributions** (`:zgrupowany`, `:siatka`, `:okrąg`) — pedagogical variety; trigger: when first external user asks "what if the points are clustered?"

### Future Consideration (v2+)

Defer until there is signal that they're worth the complexity. None of these are committed.

- [ ] **Force-directed smoothing pass** (true bubble physics) — the philosophically purest version of the project, but HIGH-risk implementation. Defer until SA-2-opt MVP proves the visualization pipeline works. Dropping this *does not* invalidate the project: SA-2-opt with the bubble *naming* is a defensible v1 framing ("the cycle relaxes toward minimum energy, like a soap film").
- [ ] **Side-by-side NN-frozen vs. evolving comparison panel** — only after dual-panel is solid
- [ ] **"Current move" highlight flash** — polish; only after the basics are tight
- [ ] **CI on GitHub Actions with headless GLMakie** — when the package leaves personal use

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `generuj_punkty` (uniform, seeded) | HIGH | LOW | P1 |
| `oblicz_energie` (type-stable, alloc-free) | HIGH | LOW | P1 |
| `symuluj_krok!` (SA + 2-opt) | HIGH | MEDIUM | P1 |
| NN initial tour | HIGH | LOW | P1 |
| Geometric SA cooling, α=0.995 | HIGH | LOW | P1 |
| Stagnation-patience stopping | MEDIUM | LOW | P1 |
| GLMakie live window with Observable-driven tour | HIGH | MEDIUM | P1 |
| Polish UI labels everywhere | HIGH | LOW | P1 |
| MP4/GIF export via `record` | HIGH | LOW | P1 |
| `test/runtests.jl` with Hamilton + type + alloc + baseline | HIGH | MEDIUM | P1 |
| NN-baseline benchmark script | HIGH | LOW | P1 |
| `examples/` with quickstart | MEDIUM | LOW | P1 |
| README + demo GIF | HIGH | LOW | P1 |
| Dual-panel layout (tour + energy curve) | HIGH | LOW–MEDIUM | P2 |
| Edge color by length gradient | MEDIUM | LOW | P2 |
| Or-opt move | MEDIUM | MEDIUM | P2 |
| Speed slider + pause/resume button | MEDIUM | MEDIUM | P2 |
| Configurable point distributions | MEDIUM | LOW | P2 |
| Force-directed smoothing pass | HIGH | HIGH | P3 |
| "Current move" flash highlight | LOW | MEDIUM | P3 |
| Side-by-side NN-vs-bubble comparison panel | MEDIUM | MEDIUM | P3 |
| CI workflow (headless) | LOW | LOW | P3 |

**Priority key:**
- **P1** — Required for v1. Without these the package is incomplete relative to PROJECT.md's *Validated/Active* requirements and *Core Value*.
- **P2** — High-leverage additions that materially improve the demo/educational value. Add post-v1 once the loop is stable.
- **P3** — Pure polish or HIGH-risk experiments. Only attempt if v1 + P2 are landed and time remains.

---

## Competitor / Reference Analysis

| Feature | Metaheuristics.jl `visualization` | tspgen (R) | See-Algorithms / AlgorithmVisualizer (web) | JuliaCity (our plan) |
|---------|---------------------------------|-----------|---------------------------------------------|------------------------|
| **Live algorithm animation** | Yes — generic optimization-progress plot, not TSP-specific | No (pure instance generator) | Yes, but for sorting / pathfinding, not TSP heuristics | Yes — TSP-specific tour evolution with soap-bubble framing |
| **Tour visualization** | No (objective-value plot only) | No | No | Yes — full 2D cycle, edge gradient, Polish labels |
| **Energy / objective curve** | Yes | No | Speed/step controls only | Yes (P2 dual-panel) |
| **Point distribution variety** | N/A (problem-agnostic) | Yes — uniform, clustered, mutations | N/A | P2 — uniform / clustered / grid / circle |
| **MP4/GIF export** | Implicit via Makie | No | No (browser-only) | Yes (P1, mandated) |
| **Pause / resume / speed** | No | N/A | Yes | P2 |
| **Polish UI** | No | No | No | Yes (mandated) |
| **Quality benchmark vs. NN** | Generic | No | No | Yes (P1, mandated) |
| **Type-stable, alloc-free hot path** | Mixed | N/A (R) | N/A (JS) | Yes (P1, mandated) |

**Where JuliaCity stakes its claim:** the only Polish-language, GLMakie-native, TSP-specific, physics-narrated, package-quality demo of a soap-bubble-style heuristic on a deterministic 1000-point instance. None of the surveyed reference points cover this niche directly.

---

## Sources

- [Metaheuristics.jl Visualization](https://jmejia8.github.io/Metaheuristics.jl/dev/visualization/) — Julia idiom for animating optimization progress with Makie
- [Makie Animations docs](https://docs.makie.org/dev/explanations/animation) — `record`, Observables, `@lift` patterns
- [Makie GridLayout reference](https://docs.makie.org/stable/reference/blocks/gridlayout/) — dual-panel layout, `linkxaxes!`
- [Datseris gist on interactive Makie](https://gist.github.com/Datseris/4b9d25a3ddb3936d3b83d3037f8188dd) — Observable-driven live updates
- [DTU thesis: visualization and comparison of randomized search heuristics on TSP](http://www2.imm.dtu.dk/pubdb/edoc/imm6870.pdf) — confirms 2-opt + SA as standard demo combination
- [Which local-search operator works best for TSP (MDPI)](https://www.mdpi.com/2076-3417/9/19/3985) — empirical: 2-opt + relocate + link-swap mixture beats any single operator
- [Combining SA with local search heuristics (Springer)](https://link.springer.com/article/10.1007/BF02601639) — SA + 2-opt is the canonical hybrid
- [Andresen, "A comparison of SA cooling strategies"](https://www.fys.ku.dk/~andresen/BAhome/ownpapers/perm-annealSched.pdf) — geometric ≫ logarithmic in practice
- [Banchs, "Simulated Annealing"](https://rbanchs.com/documents/THFEL_PR15.pdf) — α ∈ [0.8, 0.99] empirical range for geometric cooling
- [tspgen (R)](https://jakobbossek.github.io/tspgen/) and [DIMACS portgen](http://dimacs.rutgers.edu/archive/Challenges/TSP/download.html) — standard TSP point-distribution taxonomy: RUE, clustered, grid
- [Algorithm Visualizer](https://www.algo-viz.com/) and [See Algorithms](https://see-algorithms.com/) — UX baseline: pause / step / speed / regenerate are universal
- [Julia Performance Tips (manual)](https://docs.julialang.org/en/v1/manual/performance-tips/) — `@code_warntype`, `@btime`, `$` interpolation patterns
- [JuliaNotes — Type instability](https://m3g.github.io/JuliaNotes.jl/stable/instability/) — `@inferred` test pattern
- [BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) — benchmark suite idioms
- [Stagnation as stopping criterion (MDPI)](https://www.mdpi.com/2227-7390/13/11/1803) — patience-based convergence is standard

**Confidence justification:** All algorithmic recommendations (NN init, SA-2-opt, geometric cooling α≈0.995, Or-opt as a complement, stagnation-patience stopping) are corroborated by multiple peer-reviewed sources. All Julia/Makie idioms are confirmed against current official docs. The only MEDIUM-confidence area is the *force-directed bubble pass*, which has no canonical reference implementation in the literature for TSP — it's an original contribution of this project, hence its placement at P3 with explicit fallback path.

---
*Feature research for: TSP soap-bubble heuristic visualization in Julia*
*Researched: 2026-04-28*
