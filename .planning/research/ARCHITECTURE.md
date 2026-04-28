# Architecture Research

**Domain:** Julia scientific package (TSP heuristic + real-time GLMakie animation, multithreaded)
**Researched:** 2026-04-28
**Confidence:** HIGH (Julia/Makie patterns are well-documented and stable; algorithm-variant abstraction is opinionated based on idiomatic Julia)

---

## Standard Architecture

### System Overview

```
+--------------------------------------------------------------+
|                    examples/ (Demo Layer)                    |
|   demo.jl  ----  loads JuliaCity, runs full simulation,      |
|                  opens GLMakie window, optionally records.   |
+----------------------+---------------------------------------+
                       | uses public API
                       v
+--------------------------------------------------------------+
|                JuliaCity.jl (Top-level Module)               |
|   re-exports public API:                                     |
|   generuj_punkty, oblicz_energie, symuluj_krok!, wizualizuj  |
|   + types: Punkt2D, StanSymulacji, Parametry, Algorytm       |
+----+--------------+--------------+--------------+------------+
     |              |              |              |
     v              v              v              v
+---------+   +-----------+   +-----------+   +-----------+
| Typy    |   | Punkty    |   | Energia   |   | Symulacja |
| (types) |   | (genera-  |   | (energy   |   | (step!,   |
|         |   |  tion)    |   |  + delta) |   |  variants)|
+---------+   +-----------+   +-----------+   +-----------+
     ^              ^              ^              ^
     |              |              |              |
     +--------------+--------------+--------------+
                       | shared types only
                       v
+--------------------------------------------------------------+
|             Wizualizacja (Visualization Layer)               |
|   Observables wrapping StanSymulacji fields,                 |
|   Makie scene construction, animation loop driver.           |
|   Depends on core; core does NOT depend on this layer.       |
+--------------------------------------------------------------+

Hot loop is single-threaded at the OUTER level (one symuluj_krok!
per frame), with Threads.@threads INSIDE energy/delta computations
where iterations are independent.
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `Typy` (types module) | Owns `Punkt2D`, `StanSymulacji`, `Parametry`, `Algorytm` abstract type | Concrete-fielded structs, parametric where useful |
| `Punkty` | Deterministic point generation (`generuj_punkty`) | Pure function, takes seed and N, returns `Vector{Punkt2D}` |
| `Energia` | Total tour length (`oblicz_energie`) and incremental delta (`delta_energii`) for 2-opt swaps | Type-stable, zero-alloc inner loop, uses `@threads` for parallel chunked sum |
| `Symulacja` | `symuluj_krok!(state, params, alg)` — one in-place step. Algorithm variant dispatched on `alg::Algorytm` | Multiple-dispatch entry, no globals, RNG passed via state |
| `Wizualizacja` | Builds Makie figure, wires Observables to state, drives animation | Depends only on public types from core; never the reverse |
| `examples/demo.jl` | End-to-end demo: generate -> simulate -> visualize -> optional MP4 | Outside `src/`, just consumes the package |
| `test/` | Correctness (Hamiltonian cycle invariant), type stability (`@inferred`), zero-allocation (`@allocated == 0`) | Standard `Test` stdlib + `BenchmarkTools` |

---

## Recommended Project Structure

```
JuliaCity/
+-- Project.toml              # name="JuliaCity", uuid, deps, compat
+-- Manifest.toml             # generated, committed for reproducibility of demo
+-- README.md
+-- src/
|   +-- JuliaCity.jl          # main module, includes + exports public API
|   +-- typy.jl               # Punkt2D, StanSymulacji, Parametry, Algorytm hierarchy
|   +-- punkty.jl             # generuj_punkty
|   +-- energia.jl            # oblicz_energie, delta_energii (hot path, @threads inside)
|   +-- symulacja.jl          # symuluj_krok! (dispatched on Algorytm variant)
|   +-- algorytmy/            # one file per algorithm variant
|   |   +-- force_directed.jl # ForceDirected <: Algorytm
|   |   +-- simulated_annealing.jl # SimAnnealing <: Algorytm
|   |   +-- hybryda.jl        # Hybryda <: Algorytm (composes the other two)
|   +-- wizualizacja.jl       # wizualizuj (GLMakie + Observables)
|   +-- eksport.jl            # MP4/GIF recording helpers (optional load)
+-- test/
|   +-- runtests.jl           # top-level test runner
|   +-- test_punkty.jl
|   +-- test_energia.jl       # includes type-stability + allocation tests
|   +-- test_symulacja.jl     # Hamiltonian-cycle invariant tests
|   +-- test_typy.jl
+-- examples/
|   +-- demo.jl               # full end-to-end run with live window
|   +-- demo_export.jl        # headless run -> MP4
+-- bench/                    # OPTIONAL — benchmarks separate from tests
|   +-- bench_energia.jl
|   +-- bench_symulacja.jl
+-- .planning/                # project planning (already exists)
```

### Structure Rationale

- **Single top-level module `JuliaCity.jl`** — the conventional Julia layout. Re-exports the four user-mandated functions (`generuj_punkty`, `oblicz_energie`, `symuluj_krok!`, `wizualizuj`) plus public types. No sub-`module`s; just `include()` of files. Sub-modules add ceremony without payoff in a single-purpose package and complicate `using` statements.
- **`typy.jl` first in include order** — every other file depends on these types. Include order matters in Julia.
- **`algorytmy/` subdirectory** — one file per `<:Algorytm` subtype. Adding a new variant is "drop a file + include it." Mirrors how SciML organises solvers.
- **`wizualizacja.jl` last** — visualization depends on core; core never imports Makie. This guarantees you can `using JuliaCity` in a script with `using GLMakie` deferred to call sites if needed (precompile cost matters for Makie).
- **`examples/` outside `src/`** — they are not part of the package's compiled module; they are scripts. This is the universal Julia convention and is what `Pkg.test()` and `Pkg.precompile()` expect.
- **`bench/` separate from `test/`** — benchmarks are slow and interactive; mixing them with `runtests.jl` slows CI and `Pkg.test()`. Keep `BenchmarkTools` out of `[deps]`, push to `[extras]` or a sub-environment.

---

## Architectural Patterns

### Pattern 1: Single Mutable Simulation-State Struct

**What:** All evolving state lives in one mutable struct `StanSymulacji` with concretely-typed fields. Pure data; no methods attached. Functions take it by argument.

**When to use:** Always, for this project. Aligns with the user's "no global state" hard constraint and with `symuluj_krok!(state, ...)`'s in-place semantics.

**Trade-offs:**
- Pro: Single argument carries everything; easy to checkpoint/restore; testable in isolation.
- Pro: Concrete fields = type-stable struct = compiler can specialize all hot-path code.
- Con: Adding a field is a breaking change for downstream code that destructures it (mitigate with kwargs constructor).

**Example:**

```julia
# typy.jl
struct Punkt2D
    x::Float64
    y::Float64
end

# Parametric on RNG type so any AbstractRNG works without abstract field.
mutable struct StanSymulacji{R<:AbstractRNG}
    punkty::Vector{Punkt2D}        # immutable point cloud (set once)
    trasa::Vector{Int}             # permutation, length == length(punkty)
    energia::Float64               # cached total tour length
    krok::Int                      # iteration counter
    rng::R                         # reproducibility
    historia::Vector{Float64}      # energy over time, for plotting
    # Pre-allocated scratch buffers (avoid hot-path allocations):
    bufor_delta::Vector{Float64}   # length == nthreads()
end
```

Note: `punkty` is logically immutable but stored in a `Vector` (mutable container). Document the contract: the algorithm mutates `trasa`, `energia`, `krok`, `historia`, `bufor_delta` — never `punkty`.

### Pattern 2: Holy-Traits / Abstract-Type Dispatch for Algorithm Variant

**What:** Define `abstract type Algorytm end`. Each variant is a concrete subtype carrying its own hyperparameters. `symuluj_krok!` dispatches on the algorithm argument.

**When to use:** Always, for this project. The variant is undecided per PROJECT.md; this pattern lets all three (force-directed, SA, hybrid) coexist and lets `demo.jl` swap them with a one-line change.

**Trade-offs:**
- Pro: Zero runtime cost — dispatch is resolved at compile time per call site.
- Pro: Each variant's hyperparameters live with the variant, not in a god-struct of params.
- Pro: Easy to add a fourth variant later without touching existing code (open-closed).
- Con: Slightly more types to learn than a `if alg == :sa` switch — but Julia idiom is unambiguous here.

**Example:**

```julia
# typy.jl
abstract type Algorytm end

# algorytmy/force_directed.jl
Base.@kwdef struct ForceDirected <: Algorytm
    krok_sily::Float64 = 0.01
    tlumienie::Float64 = 0.95
end

# algorytmy/simulated_annealing.jl
Base.@kwdef struct SimAnnealing <: Algorytm
    temperatura::Float64 = 1.0
    chlodzenie::Float64 = 0.9995
end

# algorytmy/hybryda.jl
struct Hybryda{F<:ForceDirected,S<:SimAnnealing} <: Algorytm
    force::F
    sa::S
end

# symulacja.jl
function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::ForceDirected)
    # force-directed update of trasa, mutates stan in place
end

function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing)
    # 2-opt proposal + Metropolis acceptance, mutates stan in place
end

function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::Hybryda)
    symuluj_krok!(stan, params, alg.force)
    symuluj_krok!(stan, params, alg.sa)
end
```

Caller:
```julia
alg = SimAnnealing(temperatura = 2.0)   # or ForceDirected() or Hybryda(...)
for _ in 1:1000
    symuluj_krok!(stan, params, alg)
end
```

This is the textbook Julia "strategy pattern" — better than passing function handles in `Parametry` because hyperparameters travel with the strategy and dispatch is compile-time resolved.

### Pattern 3: Observables Mirror, Not Own, the Simulation State

**What:** The visualization layer creates `Observable`s that mirror specific *views* of `StanSymulacji` (e.g., a `Vector{Point2f}` derived from `punkty[trasa]`). The algorithm core never touches Observables. After each `symuluj_krok!`, the visualization driver pulls fresh data, writes it into Observables, calls `notify()` if needed, and yields.

**When to use:** Always, for this project. Keeps `Energia`/`Symulacja` testable without any Makie dependency, and keeps the algorithm's hot path free of GUI-thread concerns.

**Trade-offs:**
- Pro: Core is testable headlessly (CI without OpenGL).
- Pro: Same `StanSymulacji` can drive multiple visualizations (live + recorded export).
- Con: One extra copy per frame to pack `punkty[trasa]` into `Point2f`. Negligible at N=1000.

**Critical Makie semantics** (from official docs):
- `obs[] = new_value` — assignment via empty-index automatically notifies listeners.
- `obs[] .= ...` — in-place broadcast does NOT notify; you must call `notify(obs)` manually.

**Example:**

```julia
# wizualizacja.jl
function wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
                    liczba_krokow::Int = 5_000, fps::Int = 60)
    fig = Figure(size = (900, 900))
    ax  = Axis(fig[1, 1], title = "Bańka mydlana TSP — krok 0",
               xlabel = "x", ylabel = "y")

    # Observables mirror state. Use Point2f (Makie's native).
    obs_trasa  = Observable(_punkty_w_kolejnosci(stan))   # closed polyline
    obs_tytul  = Observable("Bańka mydlana TSP — krok 0")
    obs_energia = Observable(Float64[stan.energia])

    lines!(ax, obs_trasa; linewidth = 1.5)
    scatter!(ax, [Point2f(p.x, p.y) for p in stan.punkty]; markersize = 4)
    on(obs_tytul) do t; ax.title = t; end

    display(fig)

    # Animation loop. NOT @threads — GLMakie wants the GL context on one thread.
    for k in 1:liczba_krokow
        symuluj_krok!(stan, params, alg)               # core; @threads lives INSIDE
        obs_trasa[]  = _punkty_w_kolejnosci(stan)      # auto-notify
        obs_tytul[]  = "Bańka mydlana TSP — krok $k"
        push!(obs_energia[], stan.energia); notify(obs_energia)  # in-place => notify
        sleep(1 / fps)                                 # let GUI pump events
    end
    return fig
end

@inline function _punkty_w_kolejnosci(stan::StanSymulacji)
    n = length(stan.trasa)
    out = Vector{Point2f}(undef, n + 1)
    @inbounds for i in 1:n
        p = stan.punkty[stan.trasa[i]]
        out[i] = Point2f(p.x, p.y)
    end
    out[n + 1] = out[1]   # close the cycle visually
    return out
end
```

### Pattern 4: Threading Inside Energy, Not Outside Step

**What:** `Threads.@threads` lives in the *innermost* parallelizable construct: chunked partial sums for `oblicz_energie`, parallel evaluation of independent 2-opt candidates for `delta_energii`. The outer `symuluj_krok!` and the animation loop are single-threaded.

**When to use:** Always, for this project. Outer-loop parallelism conflicts with sequential acceptance (SA needs the latest energy before proposing the next move) and with the GL context single-thread requirement. Inner-loop parallelism is embarrassingly parallel and safe.

**Trade-offs:**
- Pro: No locks, no race conditions, no GL context contention.
- Pro: Hot path stays cache-friendly per thread.
- Con: For very small N (< ~200) threading overhead dominates; gate with `if length(trasa) > THRESHOLD`.

**Example:**

```julia
# energia.jl

# Total tour length, parallel chunked sum.
function oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})
    n = length(trasa)
    nt = Threads.nthreads()
    czesciowe = zeros(Float64, nt)              # one slot per thread, no false sharing concern at this size

    Threads.@threads for tid in 1:nt
        s = 0.0
        # Stride loop: each thread handles indices tid, tid+nt, tid+2nt, ...
        @inbounds for i in tid:nt:n
            j = i == n ? 1 : i + 1
            a = punkty[trasa[i]]
            b = punkty[trasa[j]]
            dx = a.x - b.x
            dy = a.y - b.y
            s += sqrt(dx*dx + dy*dy)
        end
        czesciowe[tid] = s
    end
    return sum(czesciowe)
end
```

CRITICAL: write the @threads body so it does NOT capture or reassign outer locals after the loop — that is the documented boxing trap (see Pitfalls).

---

## Data Flow

### State Lifecycle

```
Phase 0 — Construction (once per run)
    seed -> generuj_punkty(N; seed) -> Vector{Punkt2D}
                                          |
                                          v
    StanSymulacji(punkty, trasa_pocz, oblicz_energie(...), 0, MersenneTwister(seed),
                  Float64[], zeros(nthreads()))
                                          |
                                          v
Phase 1 — Hot Loop (per frame)
    symuluj_krok!(stan, params, alg)
        |   propose move (alg-specific)
        |   delta_energii(stan, swap_i, swap_j)        <-- @threads inside
        |   accept/reject (alg-specific)
        |   stan.trasa[i:j] = ...                      <-- mutation
        |   stan.energia   += delta                    <-- cached update
        |   stan.krok      += 1
        |   push!(stan.historia, stan.energia)
        v
    (return; stan now updated)
                                          |
                                          v
Phase 2 — Render (per frame, on main thread, after step!)
    obs_trasa[]   = _punkty_w_kolejnosci(stan)
    obs_tytul[]   = "krok $(stan.krok)"
    push!(obs_energia[], stan.energia); notify(obs_energia)
    sleep(1/fps)   # yield to Makie's event loop
                                          |
                                          v
Phase 3 — Termination
    save("trasa.png", fig)        # optional
    record(fig, "trasa.mp4", ...) # optional, alternative path
```

### Three Boundaries Worth Naming

1. **Pure-data boundary:** `generuj_punkty -> Vector{Punkt2D}`. No I/O, no plotting, no RNG side effects beyond the one passed. Pure function of `(N, seed)`.
2. **Mutation boundary:** `symuluj_krok!` — only this function mutates `stan`. Tests assert this by deep-copying before/after and diffing.
3. **Reactive boundary:** Observables. Only the visualization layer reads `stan` and writes Observables. Algorithm core has no `using Observables`.

### Frame-by-Frame Sequence

```
main thread                              worker threads
-----------                              --------------
symuluj_krok! begin
    propose 2-opt(i,j)
    delta_energii dispatch  ----------->  parallel slice sum
                            <-----------  return partial sums
    accept/reject
    mutate stan.trasa, stan.energia
symuluj_krok! end

obs_trasa[] = view_into(stan)
obs_energia mutation + notify(...)
sleep(1/fps)         # Makie pumps GL events here
```

The fact that the render uses ordinary Julia `sleep` (not a separate task) is deliberate: GLMakie's GL context is single-threaded, and `sleep` is the simplest way to yield to its event loop without introducing `@async` complexity.

---

## Public API Surface

Required by user mandate:

```julia
generuj_punkty(N::Integer = 1000; seed::Integer = 42)::Vector{Punkt2D}

oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})::Float64

symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::Algorytm)::Nothing

wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
           liczba_krokow::Int = 5_000,
           fps::Int           = 60,
           eksport_mp4::Union{String,Nothing} = nothing)::Figure
```

### Convention Choices

- **Required positional vs kwargs:** Required data is positional (points, route, state). Tunables are kwargs (`seed`, `fps`, `liczba_krokow`). This is the SciML / Julia stdlib convention.
- **Configuration:** Use a `struct Parametry` (with `Base.@kwdef` for default-friendly construction) for cross-cutting hyperparameters (e.g., `n_punktow`, `seed`, `kroki_per_klatka`). Algorithm-specific hyperparameters live in the algorithm subtype (`ForceDirected`, `SimAnnealing`). Do NOT mix the two — that creates a god-struct that breaks every time a new algorithm needs a new parameter.
- **`Base.@kwdef` over plain constructors:** Provides keyword constructors with defaults; standard idiom in modern Julia packages.
- **`!` suffix:** Mandatory on `symuluj_krok!`; the user already specified this. Document that `symuluj_krok!` mutates `stan` and `stan` only.

### Exports

```julia
# JuliaCity.jl
module JuliaCity

using Random, LinearAlgebra
# Visualization is loaded but the package can also be used headlessly;
# users importing JuliaCity get the types and core algorithms either way.
using GLMakie, Observables

include("typy.jl")
include("punkty.jl")
include("energia.jl")
include("algorytmy/force_directed.jl")
include("algorytmy/simulated_annealing.jl")
include("algorytmy/hybryda.jl")
include("symulacja.jl")
include("wizualizacja.jl")
include("eksport.jl")

# Public functions (user mandate)
export generuj_punkty, oblicz_energie, symuluj_krok!, wizualizuj
# Public types
export Punkt2D, StanSymulacji, Parametry, Algorytm,
       ForceDirected, SimAnnealing, Hybryda

end # module
```

If GLMakie load time becomes a problem, the project can later move visualization behind a package extension (Julia 1.9+ `Project.toml [extensions]`), but for milestone 1 keep it simple — single module, no extensions.

---

## Component Boundaries

| Boundary | Direction | Communicates Via | Notes |
|----------|-----------|------------------|-------|
| `Punkty` -> caller | one-way | return `Vector{Punkt2D}` | Pure function. Seed in, points out. |
| caller -> `Energia` | one-way | passes points + route | Pure function. Returns `Float64`. |
| caller -> `Symulacja` | one-way + mutation | passes `StanSymulacji` by reference | `symuluj_krok!` mutates state. Returns `Nothing`. |
| `Symulacja` -> `Algorytm` variant | dispatch | type of `alg` argument | Holy-traits style; resolved at compile time. |
| `Symulacja` -> `Energia` | call | `delta_energii(stan, i, j)` | Inner threading lives here. |
| `Wizualizacja` -> core | read-only after step | reads `stan` fields | NEVER writes. |
| core -> `Wizualizacja` | none | n/a | Strict: core has zero awareness of GLMakie. |
| `examples/demo.jl` -> all | usage | `using JuliaCity` | Composes the full pipeline. |
| `test/` -> core | usage | `using JuliaCity, Test` | No Makie in tests; visualization smoke-tested in `examples/`. |

### Internal Constraint Worth Stating in Code

```julia
# In src/wizualizacja.jl, top of file:
# UWAGA: Ten plik importuje GLMakie i Observables. Pliki w src/ poza tym
# JEDNYM nie mogą używać Makie/Observables — rdzeń ma być testowalny bezgłowo.
```

---

## Build Order Implications

### Strict Topological Order

```
1. typy.jl                  -- nothing else compiles without these
2. punkty.jl                -- depends only on typy
3. energia.jl               -- depends on typy
4. algorytmy/*.jl           -- depend on typy
5. symulacja.jl             -- depends on typy, energia, algorytmy
6. wizualizacja.jl          -- depends on typy, GLMakie, Observables
7. eksport.jl               -- depends on wizualizacja
```

### Minimum Viable Demo Path

The shortest path to "user sees the bubble shrink":

1. **typy.jl + punkty.jl** -> can do `generuj_punkty(1000)` and verify points form a valid distribution.
2. **energia.jl** -> can compute `oblicz_energie` on a random permutation and on a known trivial cycle (square -> perimeter); test correctness.
3. **One** algorithm variant (probably the simplest 2-opt + Metropolis SA) + **symulacja.jl** -> can run the algorithm headlessly for K steps and verify energy decreases monotonically (or stochastically downward).
4. **wizualizacja.jl** -> wire Observables, get the live window.
5. **examples/demo.jl** -> ties it all together.

Crucial sequencing: **steps 1-3 must be tested before step 4 is even started.** A live window that "looks broken" is impossible to debug if you don't already know the algorithm is correct headlessly. This is the single most important build-order decision.

### Test-Before-Visualize Discipline

Write these tests before `wizualizuj`:
- `oblicz_energie` on a 4-point square returns `4.0` (within floating-point tolerance).
- `oblicz_energie(p, [1,2,3,4])` == `oblicz_energie(p, [2,3,4,1])` (rotation invariance).
- After K steps of `symuluj_krok!`, `stan.trasa` is still a permutation of `1:N` (Hamiltonian-cycle invariant).
- `stan.energia ≈ oblicz_energie(stan.punkty, stan.trasa)` after each step (cached value matches recomputation).
- `@allocated symuluj_krok!(stan, params, alg) == 0` after warmup (zero-alloc hot path).
- `@inferred oblicz_energie(...)` succeeds (type stability).

---

## Type Stability Strategy

### Concrete Rules (apply mechanically)

1. **All struct fields concretely typed.** Either `Float64` etc., or parametric (`StanSymulacji{R<:AbstractRNG}` with field `rng::R`). NEVER `rng::AbstractRNG` (abstract field => allocation per access).
2. **No `Vector{Any}` anywhere.** Always parameterize.
3. **Single return type per function.** A function returning `Float64` in one branch and `Int` in another is type-unstable.
4. **Avoid global non-`const` variables.** Hard-banned by PROJECT.md anyway.
5. **Initialize accumulators with the right type.** `s = 0.0` not `s = 0` when summing `Float64`s.
6. **Validate with `@inferred` in tests.** `@test (@inferred oblicz_energie(p, t)) isa Float64`.
7. **Validate with `@code_warntype`** during development on the four public functions; no red `Any` should appear in the hot path.

### The @threads Boxing Trap (Highest-Risk Hazard)

**The problem:** `Threads.@threads` lowers to a closure. If the loop body captures and *reassigns* an outer local, that variable gets boxed (heap-allocated, type-erased to `Core.Box`). This silently destroys type stability and adds allocations per iteration.

**Documented trigger pattern:**

```julia
# BAD — `total` is reassigned across the loop body's closure boundary.
function bad(xs)
    total = 0.0
    Threads.@threads for i in eachindex(xs)
        total += xs[i]      # WRONG anyway (race) but ALSO boxes total
    end
    return total
end
```

**Safe patterns:**

```julia
# GOOD — per-thread slot in pre-allocated array, no captured-and-reassigned scalar.
function good(xs)
    nt = Threads.nthreads()
    parts = zeros(Float64, nt)
    Threads.@threads for tid in 1:nt
        s = 0.0
        @inbounds for i in tid:nt:length(xs)
            s += xs[i]
        end
        parts[tid] = s
    end
    return sum(parts)
end

# GOOD — wrap the threaded section in a function so the closure captures only
# the function arguments (which the compiler knows the types of).
function _hot_inner!(stan, ...)
    Threads.@threads for i in ...
        # body
    end
end
```

### Specific Hazards in This Project

| Hazard | Where it lurks | Mitigation |
|--------|----------------|------------|
| Boxing of accumulator inside `oblicz_energie` parallel sum | `energia.jl` | Use the per-thread `parts[tid] = ...` pattern shown above. NEVER write to a scalar captured outside the @threads loop. |
| Abstract field `rng::AbstractRNG` | `typy.jl` | Make `StanSymulacji` parametric in `R<:AbstractRNG`. |
| Mixed numeric types in `Punkt2D` | `typy.jl` | Either `Float64`-fixed (simpler) or `Punkt2D{T<:AbstractFloat}` (general). Pick `Float64` for v1. |
| Accidental `Vector{Punkt2D}` -> `Vector{Any}` from `[Punkt2D(0,0), ...]` literal with mixed types | `punkty.jl` | Use `Punkt2D[...]` typed literal, or `[Punkt2D(rand(rng), rand(rng)) for _ in 1:N]` (comprehension preserves type). |
| `historia` resizing during hot loop | `symulacja.jl` | Either pre-`sizehint!` to expected length, or accept amortized O(1) `push!` (fine for 5k steps). |
| Allocation from `Vector{Point2f}(undef, n+1)` per frame in `_punkty_w_kolejnosci` | `wizualizacja.jl` | This allocation is OUTSIDE the algorithm hot path; one alloc per frame at 60 fps is negligible. Don't over-optimize. |
| Closure inside `lift(...)` capturing the wrong scope | `wizualizacja.jl` | Prefer explicit `on(obs) do v ... end` blocks, which are local-scope and don't capture mutable outer locals. |
| Type-stability check failing on `delta_energii` because of branch returning `Int(0)` for "no change" | `energia.jl` | Always return `Float64`; if no change, return `0.0`. |

### Type-Stability Test (paste-ready)

```julia
# test/test_energia.jl
using JuliaCity, Test

@testset "Type stability and zero-alloc hot path" begin
    pts = generuj_punkty(1000; seed = 42)
    trasa = collect(1:1000)

    @test (@inferred oblicz_energie(pts, trasa)) isa Float64

    # Warmup
    oblicz_energie(pts, trasa)
    # On modern Julia, parallel-sum with pre-allocated `parts` should be alloc-free
    # except for the `parts` allocation itself; assert a small upper bound:
    @test (@allocated oblicz_energie(pts, trasa)) < 4096
end
```

---

## Algorithm-Variant Abstraction (Concrete Plan)

Per PROJECT.md, the algorithm choice (force-directed vs SA vs hybrid) is deferred. The architecture must accommodate any choice and let the future-research-phase plug in the winner without rework.

### Decision: Holy-Traits / Abstract-Type Dispatch

```
                    abstract type Algorytm end
                              |
            +-----------------+-----------------+
            |                 |                 |
       ForceDirected    SimAnnealing         Hybryda
       <:Algorytm       <:Algorytm           <:Algorytm
       (springs +       (2-opt +             (composes
        2-opt)           Metropolis)          the others)
```

### Why Not the Alternatives

- **Symbol/enum switch (`alg::Symbol`)** — runtime dispatch on string compare, no compile-time specialization, no place to attach hyperparameters. Idiomatic Julia rejects this for hot-path code.
- **Function handle in `Parametry` (`step_fn::Function`)** — type-unstable (`Function` is abstract); also makes hyperparameters live separately from the algorithm, which fragments configuration.
- **OOP-style virtual method** — Julia doesn't have it. Multiple dispatch is the language-level answer.

### What This Buys the Roadmap

The research phase that picks the algorithm variant only needs to:
1. Define a new file `src/algorytmy/<wariant>.jl` with `struct <Wariant> <: Algorytm ... end` and a `symuluj_krok!(stan, params, alg::<Wariant>)` method.
2. Add `include("algorytmy/<wariant>.jl")` and an export.
3. Done. No changes to `wizualizuj`, `oblicz_energie`, or any test that doesn't specifically target the new variant.

This is the architectural property the user implicitly asked for.

---

## Scaling Considerations

This project's "scale" is N (number of points), not concurrent users.

| Scale | Architecture Adjustments |
|-------|--------------------------|
| N <= 1000 (target) | Current architecture as-is. Inner `@threads` parallel sum, full repaint per frame. |
| N ~ 5000 | Switch from full-tour repaint to dirty-segment repaint (track which edges changed in the last step). Consider `Float32` points to halve memory traffic. |
| N >= 10000 | Out of scope per PROJECT.md, but architecturally: precompute kd-tree for nearest-neighbor proposals; consider chunking the route into segments and parallelizing 2-opt across chunks (with the conflict-resolution overhead this implies). |

### Scaling Priorities

1. **First bottleneck (most likely):** `_punkty_w_kolejnosci` allocating a fresh `Vector{Point2f}` every frame. Fix: pre-allocate the buffer in `StanSymulacji` and reuse.
2. **Second bottleneck:** `delta_energii` for 2-opt is already O(1) — but if you parallelize *proposals* across threads, you need to reconcile conflicting moves. Pick one good proposal per step instead, parallelize the *evaluation*, not the *acceptance*.
3. **Third bottleneck:** Makie redraw cost. At 1000 points, line redraw is sub-millisecond. Not a concern at target N.

---

## Anti-Patterns

### Anti-Pattern 1: God-Struct of All Parameters

**What people do:** One giant `Parametry` struct with fields for SA temperature, force-directed stiffness, hybrid mixing ratio, FPS, seed, N, recording filename, ...

**Why it's wrong:** Every new algorithm variant adds dead fields for the others. Defaults become misleading. Construction becomes unergonomic.

**Do this instead:** Algorithm-specific hyperparameters live in the algorithm subtype (`SimAnnealing(temperatura=2.0)`). `Parametry` holds only cross-cutting concerns (seed, N, frames-per-step).

### Anti-Pattern 2: Visualization Pulls State Through a Global

**What people do:** Stash the `StanSymulacji` in a module-level `Ref` so the Makie callback can find it.

**Why it's wrong:** PROJECT.md hard-bans global state. It also creates aliasing bugs across runs (second `wizualizuj` call sees stale state).

**Do this instead:** `wizualizuj` takes `stan` as an argument and closes over it explicitly inside the local animation loop.

### Anti-Pattern 3: `@threads` on the Outer Animation Loop

**What people do:** `Threads.@threads for k in 1:liczba_krokow ...`

**Why it's wrong:** SA acceptance is sequential by definition. GLMakie's GL context is single-threaded. Parallelizing this introduces races AND crashes.

**Do this instead:** Single-threaded outer loop. `@threads` only inside `oblicz_energie` / `delta_energii`.

### Anti-Pattern 4: Mutating an Observable In-Place Without `notify`

**What people do:** `obs[][end+1] = new_value`  or  `push!(obs[], v)`  and expect the plot to update.

**Why it's wrong:** Per Makie docs, in-place mutation of an Observable's contents does NOT trigger listeners; only `obs[] = new_value` does.

**Do this instead:** Either reassign whole-cloth (`obs[] = new_array`) for small data, or `push!(obs[], v); notify(obs)` for streaming data.

### Anti-Pattern 5: Abstract-Typed Field "for flexibility"

**What people do:** `rng::AbstractRNG` to "support different RNGs."

**Why it's wrong:** Abstract field => `getfield` returns abstract => every use boxes => kills type stability => kills performance.

**Do this instead:** Make the struct parametric: `struct StanSymulacji{R<:AbstractRNG} ... rng::R end`. Same flexibility, full specialization.

### Anti-Pattern 6: Sub-modules per File for "Modularity"

**What people do:** `module Energia ... end` inside `energia.jl`, then `using ..Energia` everywhere.

**Why it's wrong:** Adds ceremony, complicates imports, doesn't help performance, and `revise.jl` workflow gets clumsier. Idiomatic small Julia packages use one module and `include()` files.

**Do this instead:** Single `module JuliaCity` in `JuliaCity.jl`, `include("energia.jl")` etc. No nested modules unless the package grows past ~5000 LoC.

---

## Integration Points

### External Dependencies

| Dependency | Role | Notes |
|------------|------|-------|
| `Random` (stdlib) | RNG | `MersenneTwister(seed)` for reproducibility. |
| `LinearAlgebra` (stdlib) | Vector math | Optional; explicit arithmetic on `Punkt2D` is faster. |
| `GLMakie` | Live window | Heavy precompile; tolerate first-run delay. |
| `Observables` | Reactive state in plots | Re-exported by Makie; usable directly. |
| `BenchmarkTools` (test/extras) | Microbenchmarks | Keep out of `[deps]`; only in `[extras]`. |

### Internal Boundaries (restated)

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Symulacja` <-> `Energia` | Direct function call | Both in core; share types via `typy.jl`. |
| `Symulacja` <-> `Algorytm` | Multiple dispatch on `alg` argument | Compile-time resolved. |
| Core <-> `Wizualizacja` | One-way: visualization reads core state | Core has no awareness of viz. |
| `Wizualizacja` <-> Makie | `Observable` + `lines!`/`scatter!` | Use `obs[] = ...` for whole-array updates; `push!; notify` for streams. |
| Tests <-> Core | `using JuliaCity` | No Makie in `runtests.jl`; viz smoke-tested via `examples/demo.jl` invocation in CI optionally. |

---

## Sources

- [Modules - The Julia Language manual](https://docs.julialang.org/en/v1/manual/modules/) — module/include conventions, public API
- [Pkg.jl: Creating Packages](https://pkgdocs.julialang.org/v1/creating-packages/) — Project.toml, src/, test/ layout
- [Makie - Observables explanation](https://docs.makie.org/dev/explanations/observables) — `obs[] = ...` vs in-place + `notify`
- [Makie - Animations explanation](https://docs.makie.org/dev/explanations/animation) — animation loop patterns
- [Multi-Threading - Julia manual](https://docs.julialang.org/en/v1/manual/multi-threading/) — `Threads.@threads` semantics
- [Type-instability because of @threads boxing variables (Discourse)](https://discourse.julialang.org/t/type-instability-because-of-threads-boxing-variables/78395) — closure-capture trap and workarounds
- [Multiple Dispatch Designs: Duck Typing, Hierarchies and Traits](http://ucidatascienceinitiative.github.io/IntroToJulia/Html/DispatchDesigns) — strategy pattern via abstract type + multiple dispatch
- [Holy Traits Pattern (book excerpt)](https://ahsmart.com/pub/holy-traits-design-patterns-and-best-practice-book/) — trait-based dispatch idiom
- [SciML Style Guide for Julia](https://docs.sciml.ai/SciMLStyle/dev/) — keyword-vs-positional, struct conventions in scientific Julia
- [Performance of type-stable fields in structs (Discourse)](https://discourse.julialang.org/t/performance-of-type-stable-fields-in-structs/19348) — concrete-vs-abstract field rationale
- [Animations, GUIs, Visuals - DynamicalSystems.jl](https://juliadynamics.github.io/DynamicalSystems.jl/dev/visualizations/) — real-time scientific simulation + Makie patterns
- [Plotting with Observables in Makie (Discourse)](https://discourse.julialang.org/t/plotting-with-observables-in-makie/70939) — Observable-driven plot updates

---
*Architecture research for: Julia scientific package — TSP heuristic with real-time GLMakie visualization*
*Researched: 2026-04-28*
