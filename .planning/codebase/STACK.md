# Technology Stack

**Analysis Date:** 2026-04-29

> **Status note:** Phase 1 (Bootstrap) is partially landed. The package skeleton, `Project.toml`/`Manifest.toml`, encoding-hygiene infrastructure, runtime types and `generuj_punkty` are present. Visualization (GLMakie/Makie/Observables) and quality/test tooling (Aqua/JET/StableRNGs/BenchmarkTools) are declared in `[compat]`/`[extras]` but **not yet wired into `src/` or installed in `Manifest.toml`** — they will be activated in Phases 2–4 per `.planning/ROADMAP.md`.

## Languages

**Primary:**
- Julia (target compat floor `1.10`, see `Project.toml` line 11) — the only language used in `src/` and `test/`. Source files: `src/JuliaCity.jl`, `src/typy.jl`, `src/punkty.jl`, `test/runtests.jl`.

**Secondary:**
- TOML — `Project.toml`, `Manifest.toml` package manifests
- YAML — `.github/workflows/CI.yml` GitHub Actions config
- Markdown — `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `.planning/**/*.md`

## Runtime

**Environment:**
- Julia — `[compat] julia = "1.10"` in `Project.toml` (line 11).
- Resolved Julia in current `Manifest.toml`: `julia_version = "1.10.11"` (line 3).
- CI matrix in `.github/workflows/CI.yml` exercises `1.10` (LTS), `1.11` (current minor), `nightly` (allowed-to-fail) on Ubuntu / Windows / macOS x64.

**Package Manager:**
- Pkg (Julia stdlib).
- Lockfile: `Manifest.toml` is **committed** (intentional — see `.gitignore` line 26: "Manifest.toml NIE jest tutaj — jest commitowany ... to jest aplikacja, nie biblioteka"). `manifest_format = "2.0"`.

## Frameworks

**Core (declared and currently used in `src/`):**
- GeometryBasics 0.5.x — provides `Point2{Float64}` aliased as `Punkt2D` in `src/typy.jl:18`. Resolved version in `Manifest.toml:49` is `0.5.10`.
- Random (Julia stdlib) — `Xoshiro` RNG used in `src/punkty.jl:31` and as default for `StanSymulacji` in `src/typy.jl:72`.

**Declared in `[compat]` / `[extras]` but NOT yet imported in source (Phases 2–4):**
- GLMakie 0.24 — live OpenGL rendering window (Phase 3). Only listed in `Project.toml` `[compat]` (line 12) and `[extras]` (line 24); not in `[deps]`, not in `Manifest.toml`.
- Makie 0.24 — plotting framework (Phase 3). Same status as GLMakie.
- Observables 0.5 — reactive primitives for animated plots (Phase 3). Same status.
- StableRNGs 1.0 — cross-version-stable RNG for golden-value tests (Phase 2). Listed in `[extras]` and `test` target.
- Aqua 0.8.14 — package quality gates. **Imported and used** in `test/runtests.jl:13` and `:174`, but Aqua itself is not yet present in `Manifest.toml` (test target deps are only resolved when `Pkg.test()` runs).
- JET 0.9 — static type-stability analyzer. **Imported and used** in `test/runtests.jl:14` and `:192`. Same Manifest status as Aqua.
- BenchmarkTools 1.6 — declared in `[compat]` and `[extras]` for Phase 4; no `bench/*.jl` scripts exist yet (`bench/.gitkeep` only).

**Testing:**
- Test (Julia stdlib) — used in `test/runtests.jl:8`. Single suite file.
- Unicode (Julia stdlib) — used for NFC normalization checks in the encoding-hygiene testset (`test/runtests.jl:12`, `:71`).

**Build/Dev:**
- No bundlers, no transpilers — pure Julia. `Pkg.instantiate()` is the only build step (also called by `julia-actions/julia-buildpkg@v1` in CI).

## Key Dependencies

**Critical (currently in `[deps]`, resolved in `Manifest.toml`):**
- `GeometryBasics` `0.5.10` — provides `Point2{Float64}` and the `rand(rng, Point2{Float64}, n)` method used by `generuj_punkty` (`src/punkty.jl:53`).
- `Random` (stdlib) — `Xoshiro`, `AbstractRNG`, `default_rng`.

**Transitive (visible in `Manifest.toml`):**
- StaticArrays `1.9.18`, StaticArraysCore `1.4.4` — `Point2` is a `StaticVector`.
- EarCut_jll `2.2.4+0`, Extents `0.1.6`, IterTools `1.10.0`, PrecompileTools `1.2.1`, Preferences `1.5.2`, JLLWrappers `1.7.1` — pulled in by GeometryBasics.
- Standard JLL artifacts: OpenBLAS, libblastrampoline, MbedTLS, Zlib, nghttp2, p7zip, libcurl, libgit2, libssh2, MozillaCACerts.

**Infrastructure (declared, not yet active):**
- See "Frameworks → Declared in `[compat]` / `[extras]`" above.

## Configuration

**Environment:**
- No `.env` file; no runtime env-var configuration in source.
- CI sets `JULIA_NUM_THREADS: 2` for the test job (`.github/workflows/CI.yml:55`).
- Default seed is hardcoded at `Xoshiro(42)` for `generuj_punkty` (`src/punkty.jl:31`) and `StanSymulacji` (`src/typy.jl:72`).

**Build:**
- `Project.toml` — package manifest with `[deps]`, `[compat]`, `[extras]`, `[targets]`.
- `Manifest.toml` — fully-resolved dependency graph; intentionally committed (this is treated as an application, not a library).
- `.editorconfig` — UTF-8, LF, indent rules (`*.jl,*.toml` 4 spaces; `*.md,*.yml` 2 spaces).
- `.gitattributes` — enforces `eol=lf` on all text formats; marks `*.png/*.jpg/*.gif/*.mp4/*.webm` as binary.
- `.gitignore` — ignores VS Code/IntelliJ/swap files, `.cov`/`.mem` Julia outputs, `*.bak`, `Manifest.toml.bak`. Explicitly does **not** ignore `Manifest.toml`.

## Platform Requirements

**Development:**
- Julia ≥ 1.10 installed (per `README.md:13`, "zalecane: 1.11 lub 1.12").
- Recommended bootstrap: `juliaup` (per Phase 1 plan `01-01-PLAN.md`).
- No native build deps required at this stage (GeometryBasics + Random only).
- Phase 3 will add an OpenGL-capable display for GLMakie.

**Production:**
- No deployment target — this is a single-user, run-locally Julia application. End-state (Phase 4) is a runnable `examples/podstawowy.jl` plus optional MP4/GIF export.

## Planned vs Current Gap

| Area | Declared in `Project.toml` | Imported in `src/` | In `Manifest.toml` |
|------|----------------------------|--------------------|--------------------|
| GeometryBasics | yes (`[deps]`) | yes (`src/JuliaCity.jl:20`) | yes (`0.5.10`) |
| Random (stdlib) | yes (`[deps]`) | yes (`src/JuliaCity.jl:21`) | yes (stdlib) |
| GLMakie | `[compat]` + `[extras]` only | no | no |
| Makie | `[compat]` + `[extras]` only | no | no |
| Observables | `[compat]` + `[extras]` only | no | no |
| StableRNGs | `[compat]` + `[extras]` (test target) | no | no |
| Aqua | `[compat]` + `[extras]` (test target) | yes — `test/runtests.jl` | no (resolved at test time) |
| JET | `[compat]` + `[extras]` (test target) | yes — `test/runtests.jl` | no (resolved at test time) |
| BenchmarkTools | `[compat]` + `[extras]` only | no | no |

---

*Stack analysis: 2026-04-29*
