---
phase: 01-bootstrap-core-types-points
plan: 03
subsystem: infra
tags: [project-toml, manifest, deps, compat, extras, targets, pkg-test]

requires:
  - phase: 01-01
    provides: "Działający binary `julia` 1.10.11 (LTS, default channel) — match z `julia = \"1.10\"` compat floor"
  - phase: 01-02
    provides: "`.gitignore` świadomie BEZ `Manifest.toml` (D-25 honored), encoding hygiene aktywne dla `.toml`/`.jl`"
provides:
  - "`Project.toml` z `name = \"JuliaCity\"`, UUID v4 (`91765426-3422-4b27-9a04-a58724ef843e`), `version = \"0.1.0\"`"
  - "`[deps]`: GeometryBasics v0.5.10 (D-02 — bezpośredni dep), Random (stdlib, runtime PRNG per D-13)"
  - "`[compat]` (9 wpisów, Wariant a / literal ROADMAP SC2): `julia = \"1.10\"`, `GLMakie = \"0.24\"`, `Makie = \"0.24\"`, `GeometryBasics = \"0.5\"`, `Observables = \"0.5\"`, `StableRNGs = \"1.0\"`, `Aqua = \"0.8.14\"`, `JET = \"0.9\"` (deviation), `BenchmarkTools = \"1.6\"`"
  - "`[extras]` (9 wpisów): test-only deps (`Aqua`, `JET`, `StableRNGs`, `Test`, `Unicode`) + parking spots dla future-phase deps (`GLMakie`, `Makie`, `Observables`, `BenchmarkTools` — wymóg Julia 1.10 resolver)"
  - "`[targets].test = [\"Aqua\", \"JET\", \"StableRNGs\", \"Test\", \"Unicode\"]` — tylko 5 deps do faktycznej instalacji w test env"
  - "`Manifest.toml` z resolved versions (commit'owany per D-25); 9 transitive deps zarejestrowane (StaticArrays, Extents, EarCut_jll, etc.)"
  - "`test/runtests.jl` stub: `using Test; @testset \"JuliaCity (stub)\"; @test true; end` — pełna treść w plan 06"
  - "`Pkg.test()` przechodzi: 1 Pass / 1 Total / `JuliaCity tests passed`"
affects: [01-04-module-types, 01-05-generuj-punkty, 01-06-tests-ci]

tech-stack:
  added: [GeometryBasics-0.5.10, Random-stdlib, Aqua-extras, JET-extras, StableRNGs-extras, Test-extras, Unicode-extras]
  patterns:
    - "Project.toml [extras] zawiera nie tylko test-deps, ale tez parking spots dla future-phase compat entries (Julia 1.10 wymaga zeby kazdy [compat] entry istnial w [deps]/[weakdeps]/[extras])"
    - "Wariant a / literal ROADMAP SC2 compliance: GLMakie/Makie/Observables/BenchmarkTools w [compat] zanim trafia do [deps] — Aqua stale_deps suppression pozniej w plan 06"
    - "Manifest.toml jako single source of truth dla reprodukcji demo (D-25, aplikacja-not-library)"

key-files:
  created:
    - "Project.toml"
    - "Manifest.toml"
    - "test/runtests.jl"
  modified: []

key-decisions:
  - "Wariant a (D-17 / ROADMAP SC2 literal) zachowany: 9 wpisów w [compat] obejmujących GLMakie/Makie/Observables/BenchmarkTools mimo że nie są jeszcze w [deps] — dodane do [extras] z legalnymi UUID-ami żeby przejść Julia 1.10 Pkg validate"
  - "JET = \"0.9\" (zamiast \"0.11\" z STACK.md/D-17) — JET 0.11.x wymaga Julia >= 1.11, konflikt z julia=\"1.10\" floor; ROADMAP SC2 literal text NIE wymusza JET = \"0.11\" tylko julia/GLMakie/Makie wartości; resolver wybrał JET v0.9.18"
  - "[targets].test zawiera tylko 5 z 9 [extras] entries — GLMakie/Makie/Observables/BenchmarkTools są extras-only (parking spots dla compat), nie instalowane przez Pkg.test()"
  - "stdlib (Random, Test, Unicode) NIE w [compat] per Pkg ekosystem konwencja — sterowane przez julia=\"1.10\""
  - "PkgTemplates NIE użyty (D-16 dopuszcza, ale ręczny scaffold + Pkg.add jest czystszy w worktree); plan task 1 wpisał Project.toml ręcznie z UUID v4 wygenerowanym przez julia -e 'uuid4()', potem Pkg.add wypełnił [deps]"

patterns-established:
  - "Pattern: ręczny scaffolding Project.toml + Pkg.add zamiast PkgTemplates Tests() plugin'a — A2 z RESEARCH.md potwierdzone empirycznie (PkgTemplates Tests() nie edytuje [extras]/[targets] rootowego Project.toml)"
  - "Pattern: '[extras] parking spot' — pakiety w [compat] ale jeszcze nie w [deps] muszą być w [extras] dla Julia 1.10 resolver, nawet jeśli nie są w [targets].test"
  - "Pattern: 'Wariant a soft compromise' — JET version downgrade (0.11 → 0.9) zachowuje julia floor i ROADMAP SC2 literal text bez bumpowania floora do 1.11"

requirements-completed: [BOOT-01, BOOT-02]

duration: 30min
completed: 2026-04-28
---

# Phase 01 Plan 03: Project.toml, Manifest, Test Stub Summary

**`Project.toml` z runtime/test deps i pełną sekcją `[compat]` (9 wpisów, Wariant a / literal ROADMAP SC2 compliance), commitowanym `Manifest.toml` (D-25), oraz minimalnym stubem `test/runtests.jl` przechodzącym `Pkg.test()` — Pkg environment gotowy na `using JuliaCity` w plan 04**

## Performance

- **Duration:** ~30 min (1776 s, większość — pierwsza instalacja General Registry + precompile GLMakie/Makie/JET stack)
- **Started:** 2026-04-28T15:55:39Z
- **Completed:** 2026-04-28T16:25:15Z
- **Tasks:** 4 (auto, no checkpoints) + 1 fixup commit (chore — Manifest hash sync)
- **Files created:** 3 (Project.toml, Manifest.toml, test/runtests.jl)

## Accomplishments

- `Project.toml` zainicjalizowany: `name = "JuliaCity"`, UUID v4 (`91765426-3422-4b27-9a04-a58724ef843e`), `authors = ["Mateusz Parol <matimuzykant@gmail.com>"]`, `version = "0.1.0"`
- `[deps]`: 2 wpisy — `GeometryBasics = "5c1252a2-..."` (v0.5.10 instalowany), `Random = "9a3f8284-..."` (stdlib)
- `[compat]`: 9 wpisów per D-17 (Wariant a / literal ROADMAP SC2): `julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"`, `GeometryBasics = "0.5"`, `Observables = "0.5"`, `StableRNGs = "1.0"`, `Aqua = "0.8.14"`, `JET = "0.9"` (deviation — patrz niżej), `BenchmarkTools = "1.6"`
- `[extras]`: 9 wpisów — 5 test deps (`Aqua`, `JET`, `StableRNGs`, `Test`, `Unicode`) + 4 parking spots dla future-phase compat (`GLMakie`, `Makie`, `Observables`, `BenchmarkTools`) z UUID-ami z General Registry
- `[targets].test = ["Aqua", "JET", "StableRNGs", "Test", "Unicode"]` — tylko 5 deps faktycznie instalowane w test env (pozostałe 4 [extras] są tylko po to żeby resolver akceptował [compat])
- `Manifest.toml` utworzony, 9 transitive deps zarejestrowane (StaticArrays v1.9.18, Extents v0.1.6, IterTools v1.10.0, EarCut_jll v2.2.4+0, JLLWrappers v1.7.1, Preferences v1.5.2, PrecompileTools v1.2.1, StaticArraysCore v1.4.4 + GeometryBasics)
- `test/runtests.jl` stub utworzony — UTF-8 bez BOM, polski komentarz wyjaśniający, `@test true` placeholder
- Pełna walidacja: `Pkg.resolve()`, `Pkg.instantiate()`, `Pkg.test()` wszystkie zwracają exit 0
- `Pkg.test()` output: `Test Summary: JuliaCity (stub) | 1 Pass / 1 Total / 0.0s` — confirms że `[extras]+[targets]` poprawnie aktywowany

## Task Commits

1. **Task 1: Inicjalizacja Project.toml + runtime deps** — `af328a2` (feat)
   - Files: `Project.toml`, `Manifest.toml`
   - GeometryBasics v0.5.10 + Random stdlib zarejestrowane
2. **Task 2: Test deps przez `[extras]`+`[targets]`** — `b05de8c` (feat)
   - Files: `Project.toml`
   - 5 test-only entries: Aqua, JET, StableRNGs, Test, Unicode
3. **Task 3: Sekcja `[compat]` (Wariant a)** — `7236b89` (feat)
   - Files: `Project.toml`
   - 9 wpisów (julia, GLMakie, Makie, GeometryBasics, Observables, StableRNGs, Aqua, JET, BenchmarkTools)
   - Inline deviation: dodano GLMakie/Makie/Observables/BenchmarkTools do `[extras]` (Rule 3 fix)
4. **Task 3 fixup: Manifest.toml hash sync** — `1cd6b85` (chore)
   - Files: `Manifest.toml`
   - project_hash przeliczony przez Pkg.resolve() po dodaniu [compat]+[extras]
5. **Task 4: Stub test/runtests.jl + JET compat fix** — `63ced39` (feat)
   - Files: `test/runtests.jl`, `Project.toml`, `Manifest.toml`
   - JET = "0.11" → JET = "0.9" (Rule 3 fix dla Julia 1.10 compat)
   - Pkg.test() output: 1 Pass / 1 Total / "tests passed"

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

**Created (3 files):**
- `Project.toml` — 31 linii: `[deps]` (2), `[compat]` (9), `[extras]` (9), `[targets].test` (5)
- `Manifest.toml` — auto-generated, ~228 linii, 9 direct + transitive deps + stdlib pin
- `test/runtests.jl` — 8 linii, polski komentarz + `@testset "JuliaCity (stub)"` + `@test true`

**Modified:** None.

## Decisions Made

- **Wariant a / literal ROADMAP SC2 zachowany** — D-17 lockuje 9 wpisów w `[compat]`, w tym GLMakie/Makie/Observables/BenchmarkTools które nie są jeszcze w `[deps]`. Trade-off: Aqua zgłosi "stale [compat]" warning, mitigowane w plan 06 przez `Aqua.test_all(JuliaCity; stale_deps=false)` z TODO Phase 4 (re-enable po dodaniu reszty deps).
- **JET = "0.9" zamiast "0.11" (deviation)** — D-17 i STACK.md sugerują JET 0.11, ale registry constraint mówi "JET 0.11.x requires Julia >= 1.11" konfliktując z `julia = "1.10"` floor. ROADMAP SC2 literal text wymaga tylko `julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"` — JET version nie jest częścią literal SC2. Najmniej-inwazyjny fix: lower JET floor do "0.9" (resolver wybrał JET v0.9.18). Re-bump do "0.11" przy bumpie julia floor do "1.11" w późniejszej fazie (jeśli). Decyzja zalogowana jako D-26 (proposed) — zostaje do akceptacji w STATE.md update przez orchestrator.
- **`[extras]` jako parking spot dla future-phase compat (Rule 3 fix)** — Julia 1.10 Pkg validate wymaga, żeby każdy `[compat]` entry istniał w `[deps]`/`[weakdeps]`/`[extras]`. RESEARCH.md zakładała "resolver akceptuje luźne [compat]" (błąd dla 1.10). Fix: dodano GLMakie/Makie/Observables/BenchmarkTools do `[extras]` z legalnymi UUID-ami z General Registry. Pakiety NIE są w `[targets].test` więc nie pobierane podczas `Pkg.test()` — Manifest pokazuje tylko GeometryBasics + Random. Pattern zapisany w `patterns-established`.
- **PkgTemplates NIE użyte** — D-16 dopuszcza one-shot lokalne PkgTemplates, ale w worktree-execution context ręczny scaffold (Project.toml piszemy ręcznie + `julia -e 'uuid4()'` + `Pkg.add(...)`) jest czystszy: nie ryzykujemy nadpisania `LICENSE`/`README.md`/`.gitattributes` z plan 02. Plan 03 task 1 jawnie instruuje ręczne podejście.
- **Manifest.toml hash sync jako osobny chore commit** — Po commitcie Task 3 (`Project.toml`) git zauważył modyfikację `Manifest.toml` (project_hash recompute przez `Pkg.resolve`). Per protocol "NEVER amend", utworzono osobny `chore(01-03)` commit (`1cd6b85`) zamiast amend.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Julia 1.10 Pkg validate wymaga, żeby każdy `[compat]` entry istniał w `[deps]`/`[weakdeps]`/`[extras]`**

- **Found during:** Task 3 (po dodaniu `[compat]` z GLMakie/Makie/Observables/BenchmarkTools)
- **Issue:** `Pkg.resolve()` zwrócił `ERROR: Compat \`Observables\` not listed in \`deps\`, \`weakdeps\` or \`extras\` section`. RESEARCH.md zakładała "resolver akceptuje wpisy [compat] dla pakietów które nie są w [deps] ani [extras]" — to było błędne dla Julia 1.10 (validation step jest twardy, nie soft).
- **Fix:** Dodano GLMakie (`e9467ef8-...`), Makie (`ee78f7c6-...`), Observables (`510215fc-...`), BenchmarkTools (`6e4b80f9-...`) do `[extras]` z UUID-ami zaczerpniętymi z General Registry przez `Pkg.activate(temp=true); Pkg.add(...)`. Pakiety NIE są w `[targets].test` więc nie są pobierane przez `Pkg.test()`.
- **Files modified:** `Project.toml`
- **Commit:** `7236b89` (commit message zawiera deviation note)
- **Verification:** `Pkg.resolve()` + `Pkg.instantiate()` exit 0; Manifest tree zawiera tylko GeometryBasics + Random (bez GLMakie/Makie tree)

**2. [Rule 3 - Blocking issue] JET = "0.11" w `[compat]` konfliktuje z `julia = "1.10"` floor**

- **Found during:** Task 4 (`Pkg.test()` próbował zarezolwować test sandbox env)
- **Issue:** `ERROR: Unsatisfiable requirements detected for package JET [c3a54625]: restricted to versions 0.11 by project, restricted by julia compatibility requirements to versions: 0.8.22-0.9.18 or uninstalled — no versions left`. JET 0.11.x wymaga Julia >= 1.11 (registry-confirmed), co konfliktuje z naszym `julia = "1.10"` floor.
- **Fix:** `JET = "0.11"` → `JET = "0.9"` w `[compat]`. Resolver wybrał JET v0.9.18 (najnowsza w 0.9.x, działa na 1.10). ROADMAP SC2 literal text wymaga tylko `julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"` — JET version nie jest częścią literal SC2, więc obniżenie floora nie łamie ROADMAP SC2.
- **Files modified:** `Project.toml`, `Manifest.toml` (hash sync)
- **Commit:** `63ced39` (commit message zawiera deviation note)
- **Verification:** `Pkg.test()` przechodzi z `Test Summary: JuliaCity (stub) | 1 Pass / 1 Total / 0.0s` + `Testing JuliaCity tests passed`

**Total deviations:** 2 auto-fixed (Rule 3 — blocking issues z resolver constraints; oba zachowują D-17 intent — Wariant a / literal ROADMAP SC2 — bo zmieniają tylko aspekty NIE pokryte literal SC2 text).

**Impact on plan:**
- Plan 06 musi `Aqua.test_all(JuliaCity; stale_deps=false)` (już zaplanowane). Gdy GLMakie/Makie/Observables (Phase 3) i BenchmarkTools (Phase 4) trafią do `[deps]`, `[extras]` oczyści się z parking spots i `stale_deps=false` można usunąć.
- JET version downgrade (0.11 → 0.9) — JET 0.9.18 nadal wspiera `@report_opt`/`@report_call`, więc Plan 06 tasks (TEST-01 type stability) nadal działają. Ewentualny re-bump do JET 0.11 wymaga równoczesnego bumpa `julia = "1.11"`, co należy do osobnej decyzji (Phase 4 Documenter tooling lub future v1.1 release).

## Authentication Gates

None — Pkg.add z General Registry przez HTTPS bez auth (oficjalny package registry).

## Issues Encountered

- **Pre-Pkg.add precompile warning "Missing source file for JuliaCity"** — pojawia się na każdym `Pkg.add` / `Pkg.resolve` / `Pkg.instantiate` ponieważ `src/JuliaCity.jl` nie istnieje (zostanie utworzony w plan 04). Warning jest benign — Pkg.test() i tak działa, JuliaCity test sandbox env zarezolwowany poprawnie. Po plan 04 (gdy `src/JuliaCity.jl` powstanie) warning zniknie.
- **First-time General Registry install** — pierwsze `Pkg.add` zaciągnęło rejestr (~30 MB downloaded), co dodało ~10 sekund. Drugi `Pkg.activate(temp=true)` na potrzeby UUID resolution dla GLMakie/Makie zaciągnął te pakiety + 240 transitive deps (Distributions, FFMPEG_jll, GLFW, Pango, etc.) — czas precompile ~12 minut, jednorazowo dla worktree (cache w `~/.julia/`).

## Next Phase Readiness

- **Wave 4 (`01-04` module + types):** odblokowane — `using GeometryBasics; const Punkt2D = Point2{Float64}` (D-01) i parametryczny `StanSymulacji{R<:AbstractRNG}` (D-05/D-06) mogą być pisane w `src/JuliaCity.jl` (`Pkg.activate(".")` znajduje GeometryBasics w manifeście)
- **Wave 5 (`01-05` generuj_punkty):** odblokowane po 01-04 (zależy od `const Punkt2D` z 01-04 + `Random.Xoshiro` z deps)
- **Wave 6 (`01-06` runtests pełny):** odblokowane po 01-04, 01-05 — `[extras]+[targets]` przygotowane (Aqua, JET, StableRNGs, Test, Unicode), `Pkg.test()` framework działa
- **Phase 2 (energy, SA, tests):** Plan 03 nie blokuje Phase 2 — `[deps]` ma już Random (potrzebne dla SA Metropolis), GeometryBasics (potrzebne dla `Punkt2D` typu w `oblicz_energie`)
- **Phase 3 (visualization):** GLMakie/Makie/Observables są już w `[compat]` (Wariant a) — Phase 3 plan 1 task 1 będzie tylko `Pkg.add(["GLMakie", "Makie", "Observables"])` żeby przesunąć z `[extras]` do `[deps]` i pobrać do manifestu

## Threat Surface Scan

Wszystkie zagrożenia z `<threat_model>` planu 03 zaadresowane:

- **T-01-09 (Manifest.toml ujawnia path-dependent paths)** — verified: `! grep -q 'path = "' Manifest.toml` (PASS); użyto tylko `Pkg.add("Name")` z General Registry, brak `Pkg.develop("/local/path")`
- **T-01-10 (Pkg.add z złośliwego mirrora)** — accepted: oficjalny `General` registry z `pkg.julialang.org`, Manifest pinuje konkretne wersje, kolejne resolve nie eskalują
- **T-01-11 (Ręcznie wpisany UUID jest błędny)** — mitigated: UUID-y dla GLMakie/Makie/Observables/BenchmarkTools/Aqua/JET/StableRNGs zaczerpnięte przez `Pkg.activate(temp=true); Pkg.add(...)` (nie ręczny copy-paste); UUID-y stdlib (Test, Unicode) z RESEARCH.md Pattern 2 zweryfikowane przez `Pkg.resolve` exit 0
- **T-01-12 (authors field zawiera email użytkownika)** — accepted: standardowa praktyka Julia ekosystemu

Brak nowych threat surfaces poza zarejestrowanymi.

## Self-Check: PASSED

All claims verified.

**Files:**
- `/Users/mattparol/Desktop/Projekty/JuliaCity/.claude/worktrees/agent-a91e6ab804799bda1/Project.toml` — FOUND
- `/Users/mattparol/Desktop/Projekty/JuliaCity/.claude/worktrees/agent-a91e6ab804799bda1/Manifest.toml` — FOUND
- `/Users/mattparol/Desktop/Projekty/JuliaCity/.claude/worktrees/agent-a91e6ab804799bda1/test/runtests.jl` — FOUND
- `/Users/mattparol/Desktop/Projekty/JuliaCity/.claude/worktrees/agent-a91e6ab804799bda1/.planning/phases/01-bootstrap-core-types-points/01-03-SUMMARY.md` — FOUND (this file)

**Commits:**
- `af328a2` (Task 1: Project.toml + runtime deps) — FOUND in git log
- `b05de8c` (Task 2: [extras]+[targets]) — FOUND in git log
- `7236b89` (Task 3: [compat] Wariant a) — FOUND in git log
- `1cd6b85` (Task 3 fixup: Manifest hash sync) — FOUND in git log
- `63ced39` (Task 4: stub runtests + JET fix) — FOUND in git log

**Verification block from PLAN executed:**
- FILES OK (Project.toml, Manifest.toml, test/runtests.jl all exist)
- SECTIONS OK ([deps], [compat], [extras], [targets] all present)
- COMPAT OK (9 entries — julia, GLMakie, Makie, GeometryBasics, Observables, StableRNGs, Aqua, JET, BenchmarkTools)
- RESOLVE OK (Pkg.resolve + Pkg.instantiate exit 0)
- Pkg.test OK ("JuliaCity tests passed", 1 Pass / 1 Total)
- MANIFEST CLEAN OK (no `path = "/...` entries from local dev)

---
*Phase: 01-bootstrap-core-types-points*
*Completed: 2026-04-28*
