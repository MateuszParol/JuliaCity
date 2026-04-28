---
phase: 01-bootstrap-core-types-points
reviewed: 2026-04-28T17:03:04Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - .editorconfig
  - .gitattributes
  - .github/workflows/CI.yml
  - .gitignore
  - CONTRIBUTING.md
  - LICENSE
  - Manifest.toml
  - Project.toml
  - README.md
  - src/JuliaCity.jl
  - src/punkty.jl
  - src/typy.jl
  - test/runtests.jl
findings:
  critical: 0
  warning: 1
  info: 5
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-28T17:03:04Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 01 delivers a clean, well-structured bootstrap: module entry point, two
domain types (`Punkt2D` alias + `StanSymulacji` parametric mutable struct + `Algorytm`
abstract type), the `generuj_punkty` generator with two methods (friendly default
+ composable), and a comprehensive test suite covering encoding hygiene, PRNG
isolation, constructor invariants, Aqua quality gates, and a JET smoke test. CI
matrix correctly spans 1.10/1.11/nightly across three OSes with `allow-failure`
on nightly.

The locked decisions (Polish docstrings/comments, English ArgumentError messages,
tracked Manifest.toml, `julia = "1.10"` floor, JET pinned at 0.9, `[extras]`
parking spots, `const Punkt2D = Point2{Float64}`, mutable struct with const fields,
deliberate test workarounds for Aqua/JET/sandbox quirks) are honored throughout
and were excluded from scrutiny.

One warning: a tautological assertion in the `StanSymulacji` test that compares
an object to itself. Five info-level items cover minor documentation drift,
type-restriction tightness, and one weak smoke-test assertion that is already
acknowledged inline. No security issues, no logic bugs, no encoding/formatting
problems detected.

## Warnings

### WR-01: Tautological assertion in `StanSymulacji` custom-rng test

**File:** `test/runtests.jl:155`
**Issue:** The line `@test stan_custom.rng === stan_custom.rng   # same object`
compares `stan_custom.rng` to itself, which is trivially `true` for any object
that is not a value-type missing/NaN. The assertion exercises nothing — it
neither verifies that the keyword argument was actually stored, nor that the
custom RNG seed differs from the default. The comment ("same object") suggests
the intent was to verify identity against the originally-passed RNG instance,
but the source `Xoshiro(123)` was constructed inline and is not retained in a
local binding to compare against.

**Fix:** Bind the RNG before passing it, and compare identity against that local:
```julia
# Custom rng (composable z generuj_punkty)
custom_rng = Xoshiro(123)
stan_custom = StanSymulacji(punkty; rng=custom_rng)
@test stan_custom.rng === custom_rng                       # identity preserved
@test typeof(stan_custom) === typeof(StanSymulacji(punkty)) ||
      typeof(stan_custom) <: StanSymulacji{<:Random.Xoshiro}  # type param flows through
```
Optionally also assert that two distinct seeds produce distinguishable sampling,
e.g. `@test rand(stan_custom.rng) != rand(StanSymulacji(punkty).rng)`, to catch
silent default-fallback regressions.

## Info

### IN-01: Type restriction `n::Int` is narrower than docstring's `Integer` contract

**File:** `src/punkty.jl:29`, `src/punkty.jl:46`
**Issue:** Both methods of `generuj_punkty` declare `n::Int`, but `seed::Integer`
is wider on the same signature. Calling with a non-`Int` integer (`Int32(100)`,
`UInt(100)`, `BigInt(100)`) will dispatch-fail with `MethodError` rather than
running. The docstring header (`generuj_punkty(n::Int=1000; seed::Integer=42)`)
is internally consistent, but the asymmetry between `n` and `seed` is mildly
surprising for a friendly default. Phase 1 tests only cover the default `Int`
path, so a regression on a Windows runner where `Int === Int64` already would
not surface here, but downstream callers in Phase 2/3 may pass `length(...)`
results that are typed `Int` everywhere on 64-bit so this is unlikely to bite
in practice.

**Fix:** Either widen to `n::Integer` and convert internally, or document the
restriction explicitly:
```julia
function generuj_punkty(n::Integer=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))
    rng = Xoshiro(seed)
    return generuj_punkty(Int(n), rng)
end
```
Low priority — defer to Phase 2 if convenient.

### IN-02: JET smoke-test assertion is effectively a tautology

**File:** `test/runtests.jl:192-193`
**Issue:** `result = @report_opt generuj_punkty(10; seed=42)` followed by
`@test result !== nothing` asserts only that the macro produced *some* return
value. `@report_opt` from JET 0.9 returns a `JETCallResult` (or analogous)
object that is never `nothing`, so this assertion always passes regardless of
whether the analyzer found type-stability issues.

The block-level comment (lines 186-191) explicitly acknowledges this is a soft
gate ("Phase 1 to tylko gate 'macro się parsuje + analiza nie wybucha'") and
defers hard `isempty(get_reports(result))` to Phase 2, so this is an
intentional design — flagging only because the assertion text gives a misleading
impression of substance to a future reader skimming the tests.

**Fix:** Either replace with an explicit smoke comment as the test body, or
upgrade now:
```julia
result = @report_opt generuj_punkty(10; seed=42)
# Soft assertion: macro parsed + analysis did not throw.
# Phase 2 upgrades to: @test isempty(JET.get_reports(result))
@test result !== nothing
```
Or, more honestly:
```julia
# Phase 1 smoke: simply verify @report_opt does not throw at parse/eval time.
@report_opt generuj_punkty(10; seed=42)
@test true
```
No behavior change; this is a clarity-of-intent edit.

### IN-03: `MethodError` not exercised for `StanSymulacji` non-`Vector{Punkt2D}` argument

**File:** `test/runtests.jl:128-156`
**Issue:** The constructor `StanSymulacji(punkty::Vector{Punkt2D}; ...)` will
`MethodError` if a caller passes `Vector{Point2{Float32}}`, `Vector{SVector{2,Float64}}`,
or `Tuple{...}`. There is no test verifying this dispatch boundary. Given the
emphasis on type stability and the `Punkt2D = Point2{Float64}` hard-alias
decision (D-04), it would be cheap to add one negative test:

**Fix:**
```julia
# Dispatch boundary: only Vector{Punkt2D} accepted (D-04)
@test_throws MethodError StanSymulacji(Point2{Float32}[Point2{Float32}(0, 0)])
```
Defer to Phase 2 if not in scope here. Pure hygiene.

### IN-04: `[compat]` block ordering does not follow ecosystem convention

**File:** `Project.toml:10-19`
**Issue:** The `[compat]` block lists `julia` first (correct) but the remaining
entries are not alphabetized (GLMakie, Makie, GeometryBasics, Observables,
StableRNGs, Aqua, JET, BenchmarkTools). Most Julia packages alphabetize
non-`julia` compat entries to match `[deps]` ordering and minimize merge
conflicts. Aqua does not enforce alphabetization, so this does not break the
quality gate, but it is a minor convention deviation.

**Fix:**
```toml
[compat]
julia = "1.10"
Aqua = "0.8.14"
BenchmarkTools = "1.6"
GLMakie = "0.24"
GeometryBasics = "0.5"
JET = "0.9"
Makie = "0.24"
Observables = "0.5"
StableRNGs = "1.0"
```
Pure cosmetic — defer indefinitely if a different ordering convention is
preferred (e.g., grouping by phase / by purpose).

### IN-05: CI matrix lacks Julia 1.12 even though stack recommends targeting it

**File:** `.github/workflows/CI.yml:22-25`
**Issue:** The matrix tests `1.10` (LTS), `1.11` (current minor), and `nightly`,
but the locked technology stack says "Julia 1.11.x (preferred) or 1.12.6 …
Julia 1.12 (released 2025-10-08) adds experimental code trimming and further
multithreading improvements". As of 2026-04-28 (today), 1.12 is the latest
stable; 1.11 has been superseded. Adding `1.12` to the matrix would catch
regressions caused by 1.12-specific changes (e.g., code trimming, threading
runtime tweaks) before nightly does, on a stable runner.

**Fix:**
```yaml
        version:
          - '1.10'      # LTS (compat floor)
          - '1.11'      # previous minor (legacy)
          - '1.12'      # current stable
          - 'nightly'   # bleeding edge — allow-failure
```
Bumps CI cost by one row × three OSes = three more jobs. Worth it if 1.12 is
the recommended dev target. If runner budget is tight, swap `1.11` → `1.12`
rather than adding.

---

_Reviewed: 2026-04-28T17:03:04Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
