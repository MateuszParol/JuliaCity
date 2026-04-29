<!-- refreshed: 2026-04-29 -->
# Architecture

**Analysis Date:** 2026-04-29

> **Status note:** Phase 1 (Bootstrap) is in place. The architecture currently realized on disk covers only **types + point generation**. The full intended architecture (energy, simulation step, visualization, export) is documented in `CLAUDE.md` and `.planning/ROADMAP.md` but is not yet implemented. Each section below distinguishes "currently realized" from "planned".

## System Overview

```text
                        ┌──────────────────────────────────────┐
                        │     module JuliaCity                 │
                        │     `src/JuliaCity.jl`               │
                        │     (single-module package)          │
                        └──────────────────────────────────────┘
                                          │ include()
                ┌─────────────────────────┼─────────────────────────┐
                ▼                         ▼                         ▼
   ┌────────────────────────┐ ┌──────────────────────┐ ┌──────────────────────────┐
   │   types layer          │ │  point generator     │ │  algorithms (PLANNED)    │
   │   `src/typy.jl`        │ │  `src/punkty.jl`     │ │  `src/algorytmy/`        │
   │                        │ │                      │ │  (empty: .gitkeep only)  │
   │  - Punkt2D (alias)     │ │  - generuj_punkty(n; │ │                          │
   │  - Algorytm (abstract) │ │      seed)           │ │  Phase 2 will add:       │
   │  - StanSymulacji{R}    │ │  - generuj_punkty(n, │ │  - SimAnnealing struct   │
   │    (parametric mutable │ │      rng)            │ │  - oblicz_energie        │
   │     struct)            │ │                      │ │  - symuluj_krok!         │
   └────────────────────────┘ └──────────────────────┘ │  - delta_energii         │
                ▲                         ▲             │  - inicjuj_nn!           │
                │                         │             └──────────────────────────┘
                │                         │
                └─────────────────────────┴─── consumed by ─── test/runtests.jl
                                                              (Phase 1 suite)

                        ┌──────────────────────────────────────┐
                        │  Visualization layer (PLANNED, P3)   │
                        │  `src/wizualizacja.jl` (not present) │
                        │  Only file allowed to import GLMakie │
                        └──────────────────────────────────────┘
                                          │
                                          ▼
                        ┌──────────────────────────────────────┐
                        │  GLMakie + Observables (PLANNED, P3) │
                        │  Live OpenGL window + MP4/GIF export │
                        └──────────────────────────────────────┘
```

## Component Responsibilities

### Currently realized

| Component | Responsibility | File |
|-----------|----------------|------|
| `module JuliaCity` | Single top-level module; declares deps (`using GeometryBasics: Point2`, `using Random`); `include`s component files; defines exports. | `src/JuliaCity.jl` |
| Types layer | Defines `Punkt2D` alias, `Algorytm` abstract type (Holy-traits extension point), parametric `StanSymulacji{R<:AbstractRNG}` with `const`/mutable field split. | `src/typy.jl` |
| Point generator | Provides `generuj_punkty(n; seed)` (friendly default) and `generuj_punkty(n, rng)` (composable) — both deterministic, no global RNG mutation. | `src/punkty.jl` |
| Test suite | Encoding hygiene (UTF-8, no BOM, no CRLF, NFC for `.jl`, ASCII filenames), `generuj_punkty` correctness, `StanSymulacji` zero-state, Aqua quality, JET smoke. | `test/runtests.jl` |

### Planned (not yet on disk)

| Component | Responsibility | Planned file |
|-----------|----------------|--------------|
| Energy calculator | `oblicz_energie(punkty, trasa)` Hamiltonian cycle length; `delta_energii` O(1) update. Type-stable, zero-alloc. | Phase 2 — likely `src/energia.jl` |
| Algorithms | `SimAnnealing <: Algorytm` struct + `symuluj_krok!(stan, params, alg)` SA-2-opt + Metropolis + cooling + NN init. | Phase 2 — `src/algorytmy/` (currently empty + `.gitkeep`) |
| Visualization | `wizualizuj(stan, params, alg; ...)` — only file with `using GLMakie`; throttled `Observable` updates; Polish UI; optional MP4/GIF export. | Phase 3 — `src/wizualizacja.jl` |

## Pattern Overview

**Overall:** Single-module Julia package with `include()`-based file composition and Holy-traits dispatch over an `abstract type Algorytm` extension point.

**Key Characteristics:**
- One module (`JuliaCity`) — all files glued through `include` in `src/JuliaCity.jl`.
- Parametric struct (`StanSymulacji{R<:AbstractRNG}`) keeps RNG type concrete at the field level for type stability (Pitfall 1 from `.planning/research/PITFALLS.md`).
- `const` fields on the mutable struct enforce immutability of pre-allocated buffers (`punkty`, `D`, `rng`) since Julia 1.8.
- External-constructor pattern (no inner constructors) — validation lives in the outer `StanSymulacji(punkty; rng)` call.
- Headless-by-default: `src/` deliberately has zero plotting imports until Phase 3 (`wizualizacja.jl` will be the only file with `using GLMakie`).

## Layers

### Module entry layer (realized)

- Purpose: one place to declare runtime deps, `include` component files, and curate the export list.
- Location: `src/JuliaCity.jl`.
- Contains: `using GeometryBasics: Point2`, `using Random`, `include("typy.jl")`, `include("punkty.jl")`, `export Punkt2D, StanSymulacji, Algorytm, generuj_punkty`.
- Depends on: GeometryBasics, Random.
- Used by: `test/runtests.jl` via `using JuliaCity` (line 9), and (later) `examples/` scripts.

### Types layer (realized)

- Purpose: canonical domain types — alias `Point2{Float64}` once, declare the `Algorytm` extension point, and pre-shape the simulation state struct.
- Location: `src/typy.jl`.
- Contains: `const Punkt2D` (line 18), `abstract type Algorytm end` (line 28), `mutable struct StanSymulacji{R<:AbstractRNG}` (line 48), and the external constructor `StanSymulacji(punkty::Vector{Punkt2D}; rng=Xoshiro(42))` (line 72).
- Depends on: `Point2` (from GeometryBasics, hoisted by `JuliaCity.jl`), `Xoshiro`/`AbstractRNG` (from Random, also hoisted).
- Used by: `src/punkty.jl` (uses `Punkt2D`), planned `src/algorytmy/*.jl` (will subtype `Algorytm` and mutate `StanSymulacji`).

### Generator layer (realized)

- Purpose: produce a deterministic `Vector{Punkt2D}` of `n` uniform points in `[0,1]²` without touching the global RNG.
- Location: `src/punkty.jl`.
- Pattern: two methods (the "friendly default + composable" pattern documented in `.planning/research/ARCHITECTURE.md` decisions D-11):
  - `generuj_punkty(n::Int=1000; seed::Integer=42)` — constructs `Xoshiro(seed)` locally and delegates.
  - `generuj_punkty(n::Int, rng::AbstractRNG)` — composable; accepts caller-supplied RNG.
- Validation: `n > 0 || throw(ArgumentError("n must be positive"))` in both methods (English message — convention LANG-04).
- Depends on: `Punkt2D` (from `src/typy.jl`), `Xoshiro` (Random stdlib), `rand(rng, T, n)` from StaticArrays via GeometryBasics.

### Algorithms layer (planned, not realized)

- Planned location: `src/algorytmy/` (currently `.gitkeep` only).
- Will contain `SimAnnealing <: Algorytm` and the SA-2-opt step kernel.
- Will mutate `StanSymulacji.trasa` / `.energia` / `.temperatura` / `.iteracja` (the four non-`const` fields).

### Visualization layer (planned, not realized)

- Planned location: `src/wizualizacja.jl` (not present).
- Constraint: ONLY file in `src/` allowed to `using GLMakie` — keeps headless test path GLMakie-free (Phase 3 SC4).

## Data Flow

### Currently realized — point generation

1. Caller invokes `generuj_punkty(1000; seed=42)` (`src/punkty.jl:29`).
2. Validates `n > 0`.
3. Constructs local `rng = Xoshiro(seed)` (line 31).
4. Delegates to `generuj_punkty(n, rng)` (line 32).
5. The composable method calls `rand(rng, Punkt2D, n)` (line 53), which dispatches through StaticArrays' `rand` for `Point2{Float64} <: StaticVector`.
6. Returns `Vector{Punkt2D}` of length `n`.

### Currently realized — state construction

1. Caller invokes `StanSymulacji(punkty)` with a `Vector{Punkt2D}` (`src/typy.jl:72`).
2. Validates `length(punkty) > 0`.
3. Pre-allocates `D = Matrix{Float64}(undef, n, n)` (decision D-07: zero-state, values filled in Phase 2 by `oblicz_macierz_dystans!`).
4. Initializes `trasa = collect(1:n)` (identity permutation).
5. Returns `StanSymulacji{Xoshiro}(punkty, D, rng, trasa, 0.0, 0.0, 0)` with all numeric mutable fields zeroed.

### Planned — primary simulation flow (Phase 2+)

1. `punkty = generuj_punkty(1000; seed=42)` — generate fixture.
2. `stan = StanSymulacji(punkty; rng=Xoshiro(seed))` — pre-allocate state.
3. `oblicz_macierz_dystans!(stan)` — fill `D`.
4. `inicjuj_nn!(stan)` — overwrite `trasa` with NN tour, set `stan.energia` accordingly.
5. Loop: `symuluj_krok!(stan, params, SimAnnealing(...))` — proposes 2-opt swap, accepts via Metropolis, updates `trasa`/`energia`/`temperatura`/`iteracja`.
6. Phase 3: `wizualizuj(stan, params, alg; KROKI_NA_KLATKE=10, eksport=...)` — wraps the loop, pushes `stan.trasa` snapshots into an `Observable{Vector{Point2f}}` every K steps; optionally encodes to MP4/GIF via Makie's `record()`.

**State Management (planned):**
- All mutation flows through `symuluj_krok!` mutating `stan::StanSymulacji`. No global state. Per-thread RNG (Phase 2) will be derived deterministically from the master seed for `JULIA_NUM_THREADS`-invariant results (ROADMAP Phase 2 SC3).

## Key Abstractions

**`Punkt2D`** (realized)
- Purpose: canonical 2D point type for the whole package.
- Location: `src/typy.jl:18`.
- Pattern: `const Punkt2D = Point2{Float64}` — type alias, zero-cost. Inherits accessors `p.x`, `p.y`, `p[1]`, `p[2]` from GeometryBasics. Will be consumed unchanged by Makie's scatter/lines in Phase 3.

**`Algorytm`** (realized as declaration; subtypes planned)
- Purpose: extension point for algorithm variants (Holy-traits dispatch).
- Location: `src/typy.jl:28`.
- Pattern: `abstract type Algorytm end`. Phase 2 will add `struct SimAnnealing <: Algorytm`; v2 may add `ForceDirected`, `Hybryda`. New variants are additive — drop a file in `src/algorytmy/` and `include` it in `JuliaCity.jl`.

**`StanSymulacji{R<:AbstractRNG}`** (realized)
- Purpose: bundles all simulation state as a single argument; type-parametric in the RNG so `stan.rng` calls dispatch concretely.
- Location: `src/typy.jl:48`.
- Pattern: parametric mutable struct with split `const`/mutable fields:
  - `const punkty::Vector{Punkt2D}` — input data, immutable.
  - `const D::Matrix{Float64}` — pre-allocated distance matrix (filled in Phase 2).
  - `const rng::R` — locked RNG instance.
  - `trasa::Vector{Int}`, `energia::Float64`, `temperatura::Float64`, `iteracja::Int` — mutated by the planned `symuluj_krok!`.

## Entry Points

**Test suite (realized):**
- Location: `test/runtests.jl`.
- Triggered by: `julia --project=. test/runtests.jl` locally; `julia-actions/julia-runtest@v1` in CI.
- Responsibilities: encoding hygiene over `src/`, `test/`, and root config files; correctness of `generuj_punkty` (PKT-01..04); `StanSymulacji` constructor invariants and `const`-field protection; Aqua quality gate (with `stale_deps=false` until Phase 4); JET `@report_opt` smoke.

**REPL / library use (realized):**
- `using JuliaCity` from a project-activated REPL exposes `Punkt2D`, `StanSymulacji`, `Algorytm`, `generuj_punkty`.

**Planned entry points (Phase 4):**
- `examples/podstawowy.jl` — `function main(); ...; end; main()` wrapper (REQ DEMO-01).
- `examples/eksport_mp4.jl` — same wrapper, writes MP4/GIF (REQ DEMO-02).
- `bench/bench_energia.jl`, `bench/bench_krok.jl`, `bench/bench_jakosc.jl` (REQ BENCH-01..03).

## Architectural Constraints

- **Threading model (planned):** Phase 2 will use `Threads.@threads` *only inside* `oblicz_energie` / `delta_energii`, never on the outer SA acceptance loop (which is sequential by design). Per-thread RNGs derived deterministically from a master seed so results are `JULIA_NUM_THREADS`-invariant (ROADMAP Phase 2 SC3, STATE.md "Locked-in Decisions").
- **Global mutable state:** explicitly forbidden (per `CLAUDE.md` "What NOT to Use" and `.planning/REQUIREMENTS.md`). Currently zero global mutable state in `src/`. The point generator and constructor both validate that no `Random.default_rng()` mutation occurs (test in `test/runtests.jl:118`).
- **`const` fields:** `StanSymulacji.punkty`, `.D`, `.rng` are `const` since Julia 1.8 — reassignment `stan.punkty = ...` raises `ErrorException` (asserted by `test/runtests.jl:144`).
- **Determinism contract:** Same seed must yield identical output; `Xoshiro` is used for runtime, `StableRNG` (Phase 2) for golden tests since `Xoshiro` streams are not stable across Julia minor versions (Pitfall 8 from `.planning/research/PITFALLS.md`).
- **Headless core:** No file in `src/` may import `GLMakie`/`Makie` until `wizualizacja.jl` lands in Phase 3, and even then it must be the *only* such file (Phase 3 SC4).
- **Internal asserts language:** error messages in `throw(...)` / `@assert` must be English (LANG-04, `CONTRIBUTING.md` §3); comments and docstrings stay Polish.
- **Filenames must be ASCII** (`CONTRIBUTING.md` §2; encoding test `test/runtests.jl:75`).

## Anti-Patterns (called out in `CLAUDE.md` and research, to avoid as code lands)

### Mutating `Random.default_rng()`

**What happens:** Calling `Random.seed!(42)` without an explicit RNG mutates the task-local global RNG, which leaks across tests and is not stream-stable across Julia minor versions.
**Why it's wrong:** Cross-test contamination; tests would silently change behavior on a Julia upgrade; violates determinism contract.
**Do this instead:** Always pass an explicit `rng::AbstractRNG`. The realized pattern is in `src/punkty.jl:31` (`rng = Xoshiro(seed)` local) and `src/typy.jl:72` (`rng::R = Xoshiro(42)` keyword arg). Test in `test/runtests.jl:118` asserts no mutation occurs.

### `Threads.@threads` outside a function

**What happens:** Captures globals → kills type inference → kills performance.
**Why it's wrong:** Documented in `CLAUDE.md` "What NOT to Use".
**Do this instead:** Phase 2 must wrap any `@threads` loop inside a function with explicitly typed arguments (`oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})`).

### Abstract field types in performance-critical structs

**What happens:** A field typed `rng::AbstractRNG` triggers dynamic dispatch on every `rand(stan.rng, ...)` call.
**Why it's wrong:** Per Pitfall 1 in `.planning/research/PITFALLS.md` — type-instability cascade.
**Do this instead:** The realized `StanSymulacji{R<:AbstractRNG}` parametrization (`src/typy.jl:48`) keeps `R` concrete at construction time so `stan.rng` is type-stable.

### Adding `FFMPEG_jll` directly

**What happens:** Pinning conflict with Makie's transitive dep.
**Do this instead:** Phase 3 will add only `Makie` / `GLMakie`; FFMPEG comes for free.

## Error Handling

**Strategy:** Fail-fast with `throw(ArgumentError(...))` for bad inputs at API boundaries; English error messages (LANG-04).

**Realized patterns:**
- `n > 0 || throw(ArgumentError("n must be positive"))` — `src/punkty.jl:30`, `:47`.
- `n > 0 || throw(ArgumentError("punkty must be non-empty"))` — `src/typy.jl:74`.
- `const`-field reassignment raises `ErrorException` (Julia 1.8+ semantics) — asserted by `test/runtests.jl:144`.

**Planned (Phase 3):**
- `wizualizuj(...; eksport=path)` will need an explicit overwrite policy or error on existing files (REQ EKS-04).

## Cross-Cutting Concerns

**Logging:** Not used. No `using Logging` in `src/`. (Planned: `ProgressMeter` for export progress in Phase 3.)

**Validation:** Done at construction / API entry only — `generuj_punkty` and `StanSymulacji` validate up front; downstream code assumes invariants hold.

**Authentication:** Not applicable.

**Encoding hygiene:** Enforced by `.editorconfig`, `.gitattributes`, and the dedicated testset in `test/runtests.jl:21` — UTF-8, no BOM, LF-only, NFC for `.jl`, ASCII filenames.

**Internationalization:** Polish for user-facing strings, comments, docstrings; English for internal asserts and error messages. Documented in `CONTRIBUTING.md` §3.

---

*Architecture analysis: 2026-04-29*
