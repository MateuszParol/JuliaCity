# External Integrations

**Analysis Date:** 2026-04-29

> **Status note:** JuliaCity is an offline, single-process Julia application. There are no network APIs, databases, auth providers, or webhooks — and there will not be any in v1 per `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md`. The only external surfaces are: (1) GitHub Actions CI, (2) planned video/GIF file output through Makie's transitive `FFMPEG_jll`, and (3) GLMakie's planned use of the host's OpenGL driver. **Most of these are aspirational** — currently only GitHub Actions CI is wired.

## APIs & External Services

**None.** No HTTP clients, no SDK imports, no third-party service integration anywhere in `src/` or `test/`. Grep for typical SDK patterns (`HTTP`, `Downloads`, `OAuth`, `Stripe`, etc.) returns nothing.

## Data Storage

**Databases:** None — and none planned for v1.

**File Storage:**
- Local filesystem only.
- **Currently produced files:** none (no example scripts run by default; `examples/` and `bench/` contain only `.gitkeep`).
- **Planned outputs (Phase 3 onwards, per `.planning/ROADMAP.md`):**
  - `assets/demo.mp4` or `assets/demo.gif` — animation export written by `wizualizuj(...; eksport=...)` (REQ EKS-01..04).
  - `bench/wyniki.md` — benchmark results table (Phase 4, REQ BENCH-04).

**Caching:** None.

## Authentication & Identity

**None** — no users, no logins. The project is a numerical / visualization tool.

## Monitoring & Observability

**Error Tracking:** None.

**Logs:**
- No logging framework is wired. There is no `using Logging` in `src/` (verified via grep).
- Test output is the standard `Test` stdlib `@testset` summary.
- Plan: Phase 3's progress meter for export (REQ EKS-03) will print to stdout via `ProgressMeter` or equivalent — not yet implemented.

## CI/CD & Deployment

**Hosting:** Not applicable (no deployment surface).

**CI Pipeline:**
- **GitHub Actions** — single workflow at `.github/workflows/CI.yml` (`name: CI`).
  - Triggers: `push` and `pull_request` to `main`/`master`.
  - Concurrency: cancels in-progress runs on same ref (`group: ${{ github.workflow }}-${{ github.ref }}`).
  - Matrix: `julia ∈ {1.10, 1.11, nightly}` × `os ∈ {ubuntu-latest, windows-latest, macos-latest}` × `arch = x64`. `nightly` is `continue-on-error: true`.
  - Steps: `actions/checkout@v4` → `julia-actions/setup-julia@v2` → `julia-actions/cache@v2` → `julia-actions/julia-buildpkg@v1` → `julia-actions/julia-runtest@v1`.
  - Env: `JULIA_NUM_THREADS: 2`.

**Release / Registry:** Not configured. No TagBot / CompatHelper / Registrator workflows present.

## Environment Configuration

**Required env vars:**
- None at runtime. The package can be imported and `generuj_punkty()` called with no setup beyond `Pkg.instantiate()`.

**Optional env vars (CI / dev):**
- `JULIA_NUM_THREADS` — set to `2` in `.github/workflows/CI.yml:55`. Phase 2 will use this for `Threads.@threads` inside `oblicz_energie` (planned, not implemented).

**Secrets location:**
- No secrets are used or stored. No `.env*` files present in the repo.

## Webhooks & Callbacks

**Incoming:** None.

**Outgoing:** None.

## Native / System Integrations

**OpenGL (planned, Phase 3):**
- GLMakie will require an OpenGL-capable display on the host. Not yet imported anywhere — declared only in `Project.toml [compat]` / `[extras]` (lines 12, 24). CI matrix targets Linux/Windows/macOS but headless OpenGL handling for Phase 3 CI is an open question (see `.planning/STATE.md` line 81: "CairoMakie fallback for headless CI?").

**FFMPEG (planned, Phase 3):**
- `FFMPEG_jll` is the standard backend for Makie's `record()` API and is pulled in **transitively** through Makie. Per `CLAUDE.md`, it must NOT be added as a direct dep. Currently absent from both `Project.toml` and `Manifest.toml` because Makie itself has not been added yet.

## CLI Entry Points

**Currently exposed:**
- None — no script with a top-level `main()` exists. The package is consumed from the REPL: `using JuliaCity; generuj_punkty(1000; seed=42)` (per `README.md` Quickstart).
- `julia --project=. test/runtests.jl` runs the test suite (also exercised by CI).

**Planned (Phase 4, per `.planning/ROADMAP.md` Phase 4 SC1–SC2):**
- `julia --project=. --threads=auto examples/podstawowy.jl` — live demo script.
- `julia --project=. --threads=auto examples/eksport_mp4.jl` — produces `assets/demo.mp4`.
- Both are referenced in the roadmap but **not yet present** (`examples/.gitkeep` only).

## Public API Surface (in-process integration contract)

The `module JuliaCity` (`src/JuliaCity.jl`) currently exports:
- `Punkt2D` — `const Punkt2D = Point2{Float64}` (`src/typy.jl:18`).
- `StanSymulacji` — `mutable struct StanSymulacji{R<:AbstractRNG}` (`src/typy.jl:48`).
- `Algorytm` — `abstract type Algorytm end` extension point (`src/typy.jl:28`).
- `generuj_punkty` — two methods: `generuj_punkty(n; seed)` and `generuj_punkty(n, rng)` (`src/punkty.jl:29`, `:46`).

Planned exports (Phases 2–3, per docstring header in `src/JuliaCity.jl`):
- `oblicz_energie(punkty, trasa)` — Phase 2.
- `symuluj_krok!(stan, params, alg)` — Phase 2.
- `wizualizuj(stan, params, alg; ...)` — Phase 3.

---

*Integration audit: 2026-04-29*
