# Codebase Structure

**Analysis Date:** 2026-04-29

> **Status note:** The skeleton from Phase 1 is in place — `src/`, `test/`, `examples/`, `bench/`, `Project.toml`, `Manifest.toml`, CI workflow, encoding-hygiene config, and the planning suite. `examples/` and `bench/` and `src/algorytmy/` exist but contain only `.gitkeep` placeholders; they will be populated by Phases 2–4. `src/wizualizacja.jl`, `src/energia.jl`, and `src/algorytmy/sim_annealing.jl` do not yet exist.

## Directory Layout

```
JuliaCity/
├── .editorconfig             # UTF-8, LF, indent rules
├── .gitattributes            # eol=lf for text; binary markers for media
├── .gitignore                # Manifest.toml intentionally NOT ignored
├── .github/
│   └── workflows/
│       └── CI.yml            # 3 Julia versions × 3 OS matrix
├── .planning/                # GSD planning artifacts (project memory)
│   ├── PROJECT.md            # vision, constraints, key decisions
│   ├── REQUIREMENTS.md       # 53 v1 REQ-IDs across 10 categories
│   ├── ROADMAP.md            # 4 phases with success criteria
│   ├── STATE.md              # current position + locked decisions
│   ├── config.json           # GSD config
│   ├── codebase/             # codebase docs (this directory)
│   ├── phases/
│   │   ├── 01-bootstrap-core-types-points/   # 6 plans + summaries + research
│   │   └── 02-energy-sa-algorithm-test-suite/ # CONTEXT + DISCUSSION-LOG (planning in progress)
│   └── research/             # ARCHITECTURE/FEATURES/PITFALLS/STACK/SUMMARY (Phase 0 research)
├── bench/
│   └── .gitkeep              # empty — Phase 4 will add bench_*.jl
├── examples/
│   └── .gitkeep              # empty — Phase 4 will add podstawowy.jl, eksport_mp4.jl
├── src/
│   ├── JuliaCity.jl          # module entry: deps, includes, exports
│   ├── typy.jl               # Punkt2D, Algorytm, StanSymulacji{R}
│   ├── punkty.jl             # generuj_punkty (2 methods)
│   └── algorytmy/
│       └── .gitkeep          # empty — Phase 2 will add sim_annealing.jl
├── test/
│   └── runtests.jl           # encoding hygiene + PKT-01..04 + StanSymulacji + Aqua + JET smoke
├── CLAUDE.md                 # project instructions for Claude Code
├── CONTRIBUTING.md           # encoding rules, language split, GSD workflow
├── LICENSE                   # MIT
├── Manifest.toml             # committed (this is an application)
├── Project.toml              # [deps], [compat], [extras], [targets]
└── README.md                 # Polish; quickstart points at `generuj_punkty`
```

## Directory Purposes

**`src/`**
- Purpose: package source. The single `module JuliaCity` lives here, glued together via `include`.
- Contains: `JuliaCity.jl` (module entry), `typy.jl` (domain types), `punkty.jl` (point generator).
- Subdirectory `algorytmy/`: reserved for `<:Algorytm` variant implementations (Phase 2 SA, future v2 ForceDirected/Hybryda). Currently `.gitkeep` only.

**`test/`**
- Purpose: test suite consumed by `Pkg.test()` / `julia-actions/julia-runtest@v1`.
- Contains a single `runtests.jl` that imports `JuliaCity`, `Aqua`, `JET`, plus stdlib `Test`/`Random`/`Unicode`.
- Test deps are declared via `[extras]` + `[targets]` in `Project.toml` (lines 22–33), not `[deps]`.

**`bench/`**
- Purpose: BenchmarkTools-based regression suite (Phase 4).
- Currently empty (`.gitkeep`). Planned files: `bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl`, plus output `wyniki.md`.

**`examples/`**
- Purpose: runnable demo scripts (Phase 4).
- Currently empty (`.gitkeep`). Planned files: `podstawowy.jl` (live demo), `eksport_mp4.jl` (offline MP4/GIF render). Convention: each script wraps logic in `function main(); ...; end; main()` (ROADMAP Phase 4 SC1).

**`.github/workflows/`**
- Purpose: GitHub Actions CI definitions.
- Contains: `CI.yml` only. Matrix: `julia ∈ {1.10, 1.11, nightly}` × `os ∈ {ubuntu, windows, macos}`-latest × `arch=x64`. Sets `JULIA_NUM_THREADS=2`.

**`.planning/`**
- Purpose: GSD (planning workflow) artifacts. **Read-only from the package's runtime perspective** — none of these files are loaded by `module JuliaCity`.
- Top-level files: `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `config.json`.
- `phases/`: per-phase plans, summaries, context, discussion logs, research, review, verification.
- `research/`: Phase-0-style research dumps (`ARCHITECTURE.md`, `FEATURES.md`, `PITFALLS.md`, `STACK.md`, `SUMMARY.md`). These are *research outputs*, not the production codebase analysis (which is what this `codebase/` directory holds).
- `codebase/`: codebase analysis docs consumed by `/gsd-plan-phase` and `/gsd-execute-phase`.

## Key File Locations

**Module entry / public API:**
- `src/JuliaCity.jl` — declares `module JuliaCity`; `using GeometryBasics: Point2`; `using Random`; `include("typy.jl")`; `include("punkty.jl")`; `export Punkt2D, StanSymulacji, Algorytm, generuj_punkty`.

**Configuration:**
- `Project.toml` — package manifest (UUID `91765426-3422-4b27-9a04-a58724ef843e`, version `0.1.0`).
- `Manifest.toml` — resolved Julia 1.10.11 dep graph. Committed.
- `.editorconfig` — UTF-8 / LF / indent.
- `.gitattributes` — `eol=lf` for text formats; binary markers for `*.png/*.jpg/*.jpeg/*.gif/*.mp4/*.webm`.
- `.gitignore` — Julia/editor cruft; explicitly preserves `Manifest.toml`.
- `.github/workflows/CI.yml` — CI matrix.

**Core logic (currently realized):**
- `src/typy.jl` — `const Punkt2D = Point2{Float64}` (line 18); `abstract type Algorytm end` (line 28); `mutable struct StanSymulacji{R<:AbstractRNG}` (line 48); external constructor `StanSymulacji(punkty; rng=Xoshiro(42))` (line 72).
- `src/punkty.jl` — `generuj_punkty(n::Int=1000; seed::Integer=42)` (line 29); composable `generuj_punkty(n::Int, rng::AbstractRNG)` (line 46).

**Testing:**
- `test/runtests.jl` — six top-level `@testset`s under one `@testset "JuliaCity"` umbrella: encoding hygiene, `generuj_punkty`, no-global-RNG-mutation, `StanSymulacji` constructor, Aqua quality, JET smoke.

**Documentation:**
- `README.md` — Polish overview, quickstart.
- `CONTRIBUTING.md` — encoding rules, ASCII filenames, Polish/English split, GSD workflow.
- `CLAUDE.md` — project instructions and stack research for Claude Code.
- `LICENSE` — MIT.

## Naming Conventions

**Files:**
- All filenames are **ASCII only** (enforced by `test/runtests.jl:75` and `CONTRIBUTING.md` §2).
- Source files use lowercase Polish nouns without diacritics: `typy.jl`, `punkty.jl`, planned `algorytmy/`, `wizualizacja.jl`, `energia.jl`.
- Configuration files follow ecosystem convention: `Project.toml`, `Manifest.toml`, `runtests.jl`, `CI.yml`.

**Directories:**
- Lowercase Polish (without diacritics) where domain-flavored: `algorytmy/`. Otherwise standard Julia layout: `src/`, `test/`, `bench/`, `examples/`.
- `.planning/phases/` directories use kebab-case English: `01-bootstrap-core-types-points/`, `02-energy-sa-algorithm-test-suite/`.

**Identifiers (from realized code):**
- Functions: lowercase with underscores, Polish without diacritics — `generuj_punkty`, planned `oblicz_energie`, `symuluj_krok!`, `wizualizuj`. Bang suffix (`!`) for mutating functions (Julia convention).
- Types: PascalCase, Polish without diacritics — `Punkt2D`, `Algorytm`, `StanSymulacji`. Type parameter is single uppercase letter (`R<:AbstractRNG`).
- Variables/fields: lowercase Polish without diacritics — `punkty`, `trasa`, `energia`, `temperatura`, `iteracja`, `cierpliwosc`. Math symbols (`x`, `y`, `D`, `n`) stay in standard math notation.
- Constants in module exports: PascalCase if they're type aliases (`Punkt2D`).

**Comments and docstrings:**
- **Polish** in `src/*.jl` and `test/*.jl` (LANG-01, `CONTRIBUTING.md` §3).
- **English** in error messages: `throw(ArgumentError("n must be positive"))` (LANG-04, `src/punkty.jl:30`).

## Where to Add New Code

### A new domain type

- File: extend `src/typy.jl` (small) or create a new `src/{domain}.jl` (large).
- After creating: add `include("{domain}.jl")` to `src/JuliaCity.jl` after the existing includes.
- If user-facing: add to the `export` line in `src/JuliaCity.jl:30`.
- Tests: add a new `@testset` block in `test/runtests.jl`.

### A new algorithm variant

- File: `src/algorytmy/{nazwa}.jl` (e.g., `sim_annealing.jl`, future `force_directed.jl`).
- Pattern: `struct YourAlg <: Algorytm ... end` plus method `symuluj_krok!(stan, params, ::YourAlg)` (Holy-traits dispatch on the third argument).
- Wire-up: add `include("algorytmy/{nazwa}.jl")` in `src/JuliaCity.jl`.
- Tests: add a `@testset` covering Hamilton-cycle invariant, type-stability (`@inferred`), zero allocations (`@allocated == 0` after warmup), and a NN-baseline-beat assertion (per ROADMAP Phase 2 SC4–SC5).

### Energy / step kernels (Phase 2)

- Files: likely `src/energia.jl` for `oblicz_energie` + `delta_energii`, and `src/algorytmy/sim_annealing.jl` for `symuluj_krok!` + helpers (`inicjuj_nn!`, `oblicz_macierz_dystans!`).
- Wire-up: include both in `src/JuliaCity.jl`; add `oblicz_energie`, `symuluj_krok!` to the `export` line.

### Visualization (Phase 3)

- File: `src/wizualizacja.jl` — must be the **only** file with `using GLMakie` (Phase 3 SC4).
- Wire-up: `include("wizualizacja.jl")`; export `wizualizuj`.
- Add `GLMakie`, `Makie`, `Observables` to `[deps]` in `Project.toml` (currently only in `[compat]`/`[extras]`).

### Tests

- Single test file: `test/runtests.jl`. Each new feature gets a new `@testset "...":` block under the umbrella `@testset "JuliaCity"`.
- Phase 2 test deps (`StableRNGs`) are already declared in `Project.toml [extras]` and `[targets]` — just `using StableRNGs` in `runtests.jl` once needed.

### Demo / examples (Phase 4)

- Files: `examples/podstawowy.jl`, `examples/eksport_mp4.jl`.
- Convention: wrap in `function main(); ...; end; main()` and run with `julia --project=. --threads=auto examples/{file}.jl` (ROADMAP Phase 4 SC1).

### Benchmarks (Phase 4)

- Files: `bench/bench_energia.jl`, `bench/bench_krok.jl`, `bench/bench_jakosc.jl`.
- Use `BenchmarkTools.@benchmark` with `$` interpolation and `setup=` blocks.
- Output: `bench/wyniki.md` table.

### CI changes

- Edit `.github/workflows/CI.yml`. Keep the matrix on `1.10`/`1.11`/`nightly` × Linux/Windows/macOS unless there's a strong reason. Phase 3+ may need a headless OpenGL fallback (open question per `.planning/STATE.md` line 81).

## Special Directories

**`.planning/`**
- Purpose: GSD project memory. Drives `/gsd-plan-phase`, `/gsd-execute-phase`, `/gsd-quick`.
- Generated: partially — research and codebase docs are generated by Claude; PROJECT/REQUIREMENTS/ROADMAP/STATE are user-curated with Claude's help.
- Committed: yes. Required for cross-session continuity.

**`.planning/codebase/`**
- Purpose: codebase snapshot consumed by planning/execution commands.
- Generated: yes (by `/gsd-map-codebase`).
- Committed: yes.

**`.planning/research/`**
- Purpose: deep research dumps from Phase 0 (`SUMMARY.md`, `STACK.md`, `ARCHITECTURE.md`, `FEATURES.md`, `PITFALLS.md`).
- Note: do NOT confuse `.planning/research/ARCHITECTURE.md` (research) with `.planning/codebase/ARCHITECTURE.md` (this directory's snapshot). They are different documents at different abstraction levels.

**`.planning/phases/{NN}-{slug}/`**
- Purpose: per-phase planning artifacts (`{NN}-CONTEXT.md`, `{NN}-DISCUSSION-LOG.md`, `{NN}-RESEARCH.md`, `{NN}-{NN}-PLAN.md`, `{NN}-{NN}-SUMMARY.md`, `{NN}-REVIEW.md`, `{NN}-VERIFICATION.md`).
- Phase 1 directory is fully populated; Phase 2 has CONTEXT + DISCUSSION-LOG only (planning still in progress).
- Generated: by GSD commands.
- Committed: yes.

**`src/algorytmy/`, `bench/`, `examples/`**
- Purpose: reserved directories for Phases 2/3/4.
- Currently `.gitkeep` placeholders so the directory is tracked by git but appears empty.
- Committed: yes (the `.gitkeep` files only).

---

*Structure analysis: 2026-04-29*
