---
phase: 03-visualization-export
verified: 2026-04-30T12:00:00Z
status: human_needed
score: 5/5 must-haves verified (automated); 2 items require human/OpenGL validation
overrides_applied: 0
re_verification: false
gaps: []
human_verification:
  - test: "Run `julia --project=. examples/podstawowy.jl` (or equivalent REPL script) with a display; verify GLMakie window opens with dual-panel layout (ax_trasa left + ax_energia right), dark theme, NN baseline gray dashed line, cyan scatter points, white route line, 7-field Polish overlay in top-left, and that route visibly animates (contracts)."
    expected: "Window opens without error, SA runs for liczba_krokow steps, overlay fields update every kroki_na_klatke=50 steps, window stays responsive throughout; GOTOWE overlay appears center-screen when SA finishes."
    why_human: "GLMakie requires an active OpenGL context and a display; cannot be validated in headless CI or without a GPU/display (D-14/D-15 LOCKED). All structural wiring is verified — only visual correctness and window responsiveness need human eyes."
  - test: "Run `wizualizuj(stan, params, alg; eksport=\"demo.mp4\")` from a REPL with GLMakie loaded; verify file is created, ProgressMeter bar appears in terminal, and file plays back correctly."
    expected: "MP4 file created at target path; ProgressMeter `Eksport animacji:` bar shows progress; calling again with same path raises Polish error 'Plik ... juz istnieje.'"
    why_human: "Export requires FFMPEG_jll + off-screen GLMakie render context; the record() path cannot be exercised headlessly. File-exists error path is structurally wired (grep-verified) but runtime behavior must be confirmed."
---

# Phase 3: Visualization & Export — Verification Report

**Phase Goal:** Plik `wizualizacja.jl` (jedyny w `src/` z `using GLMakie`) buduje okno z `Observable{Vector{Point2f}}`, polskim tytułem/etykietami/overlay'em (numer iteracji + bieżąca energia), throttled updates przez `KROKI_NA_KLATKE`. Argument `eksport=` pozwala zapisać animację do MP4 lub GIF z paskiem postępu i bezpieczną obsługą nazw plików.
**Verified:** 2026-04-30T12:00:00Z
**Status:** PASS WITH MANUAL (all automated checks VERIFIED; 2 items require OpenGL/display)
**Re-verification:** No — initial verification

---

## Goal-Backward Analysis

The phase goal requires three independent properties to be TRUE simultaneously:

1. `wizualizacja.jl` is the single GLMakie-importing file in `src/`
2. The public function `wizualizuj()` builds a complete, wired live/export render pipeline using `Observable{Vector{Point2f}}`, Polish strings, and throttled updates
3. Export path uses `Makie.record()` with ProgressMeter and a file-exists hard error

All three are VERIFIED at the code level. The two items requiring human validation (live window behavior and export playback) are architectural consequences of D-14/D-15 LOCKED decisions — they are not gaps in the implementation, they are the expected headless boundary.

---

## Observable Truths — Verification

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `wizualizuj()` opens GLMakie window with live animated Hamiltonian cycle + scatter for N=1000 | VERIFIED (code) / MANUAL (runtime) | `src/wizualizacja.jl` line 366: `display(fig)` called in live branch; `_live_loop` at line 184 executes `kroki_na_klatke` SA steps + Observable update per frame; `scatter!` at line 145 (markersize=5), `lines!` at line 146 with `obs_trasa` (cycle-closed via `_trasa_do_punkty` n+1 points). Runtime behavior requires display. |
| 2 | Title, axis labels, overlay are fully Polish with correct diacritics (ąęłńóśźż) | VERIFIED | Line 97: `"Trasa TSP — błona mydlana (N=...)"`, line 98: `"Współrzędna X"`, line 99: `"Współrzędna Y"`, line 106: `"Energia (długość trasy)"`, line 75-81: overlay fields `Iteracja`, `Energia`, `Temperatura`, `Alfa`, `FPS`, `Pozostało`, `Akceptacja worsening`. 12 lines contain Polish diacritics (ą ę ł ó ś ż confirmed by grep). File is NFC-normalized per encoding hygiene testset (230/230 PASS). |
| 3 | Observable updates throttled at `kroki_na_klatke` (default 50, ≥ 10) | VERIFIED | `wizualizuj()` signature line 435: `kroki_na_klatke::Int=50`. `_live_loop` line 205: `for _ in 1:kroki_na_klatke`. Single `obs_trasa[]=`, single `notify(obs_historia)`, single `obs_overlay[]=` per frame iteration (lines 217-238). Constant `_ACC_WIN=1000` at module level (type-stable, no closure boxing). |
| 4 | `wizualizacja.jl` is the ONLY file in `src/` importing GLMakie | VERIFIED | `grep -rl "using GLMakie" src/` returns exactly `src/wizualizacja.jl`. Verified: `src/baselines.jl`, `src/energia.jl`, `src/typy.jl`, `src/punkty.jl`, `src/algorytmy/simulowane_wyzarzanie.jl` contain zero GLMakie or Makie imports. Formal test `@testset "VIZ-06: GLMakie isolation"` in `test/runtests.jl` lines 208-245 uses `walkdir` + per-line `startswith(strip(linia), "using GLMakie")` guard. Test passes as part of 230/230 suite. |
| 5 | `wizualizuj(...; eksport="demo.mp4")` produces video with ProgressMeter and hard-fails on existing file | VERIFIED (code) / MANUAL (runtime) | `_export_loop` line 270: `isfile(sciezka) && error("Plik '$sciezka' już istnieje...")`. Line 285: `Progress(n_klatek; desc="Eksport animacji: ", dt=0.5)`. Line 289: `Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do frame_i`. Lines 311/313: `next!(prog)` / `finish!(prog)`. Extension auto-detection delegated to `Makie.record` (EKS-02, confirmed by FFMPEG_jll 8.1.0 in Manifest.toml). Runtime record() requires FFMPEG + display. |

**Score: 5/5 truths verified at code level; 2 require human validation for runtime confirmation.**

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/wizualizacja.jl` | Full implementation (VIZ-01..07, EKS-01..04) | VERIFIED | 465 lines; 8 internal helpers + 1 public function `wizualizuj()`. Non-stub: complete live loop, export loop, try/catch wrapper, GOTOWE overlay. |
| `src/JuliaCity.jl` | `include("wizualizacja.jl")` + `export wizualizuj` | VERIFIED | Line 42: `include("wizualizacja.jl")`; line 50: `wizualizuj` in export list. |
| `Project.toml` | `GLMakie = "0.13"` in [compat]; ProgressMeter in [deps]+[compat] | VERIFIED | [deps] has GLMakie, Makie, Observables, ProgressMeter. [compat]: `GLMakie = "0.13"` (corrected from erroneous "0.24"), `ProgressMeter = "1"`. |
| `Manifest.toml` | `[[deps.GLMakie]]` at version 0.13.10; FFMPEG_jll present | VERIFIED | Manifest line count 1666; GLMakie 0.13.10 confirmed; Makie 0.24.10; FFMPEG_jll 8.1.0 as transitive dep; ProgressMeter 1.11.0. |
| `test/runtests.jl` | `@testset "VIZ-06: GLMakie isolation"` headless grep guard | VERIFIED | Lines 201-245; walkdir+per-line startswith scan; `@test length(pliki_z_glmakie) == 1` + `@test endswith(..., "wizualizacja.jl")`. No OpenGL required. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `wizualizuj()` | `_wizualizuj_impl()` | try/catch wrapper (D-13) | WIRED | Line 446: `_wizualizuj_impl(stan, params, alg; ...)` called inside try block |
| `_wizualizuj_impl` | `with_theme(theme_dark())` | scope (D-03) | WIRED | Line 358: `with_theme(theme_dark()) do` |
| `_wizualizuj_impl` | `_setup_figure` | direct call | WIRED | Line 359: `fig, ax_trasa, ax_energia = _setup_figure(stan, nn_trasa)` |
| `_wizualizuj_impl` | `_init_observables` | direct call | WIRED | Line 360: `obs = _init_observables(stan, alg, ax_trasa, ax_energia)` |
| `_init_observables` | `scatter!(ax_trasa, obs_trasa)` + `lines!(ax_trasa, obs_trasa)` + `lines!(ax_energia, obs_historia)` + `text!(ax_trasa, obs_overlay)` | GLMakie binding | WIRED | Lines 145-160: all four plot primitives receive Observables |
| `_live_loop` | `symuluj_krok!` | direct call in inner loop | WIRED | Line 208: `symuluj_krok!(stan, params, alg)` |
| `_live_loop` | Observable update | `obs_trasa[] =` / `notify(obs_historia)` / `obs_overlay[] =` | WIRED | Lines 217-238 |
| `_export_loop` | `isfile()` | before `Makie.record()` | WIRED | Line 270: check precedes record call at line 289 |
| `_export_loop` | `Makie.record(fig, sciezka, ...)` | do-block with SA steps + Observable updates | WIRED | Lines 289-312 |
| `_export_loop` | `Progress` / `next!` / `finish!` | ProgressMeter | WIRED | Lines 285/311/313 |
| `_dodaj_gotowe_overlay!` | `text!` with ratio string | called from `_wizualizuj_impl` after SA stop | WIRED | Line 374: `_dodaj_gotowe_overlay!(ax_trasa, stan, energia_nn)` |
| `VIZ-06 test` | walkdir `src/` + per-line GLMakie check | `startswith(strip(linia), "using GLMakie")` | WIRED | runtests.jl lines 215-243 |

---

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `_live_loop` | `obs_trasa[]` | `_trasa_do_punkty(stan)` → `stan.trasa` (mutated by `symuluj_krok!`) | Yes — SA mutation produces real evolving permutation | FLOWING |
| `_live_loop` | `obs_historia.val` | `push!` with real `stan.energia` after each SA batch | Yes — energy is a genuine Float64 from SA state | FLOWING |
| `_live_loop` | `obs_overlay[]` | `_zbuduj_overlay_string(stan, alg, fps_est, eta_sec, acc_rate)` | Yes — derives from real `time()` + acc_window counts | FLOWING |
| `_export_loop` | All obs | Same as live loop but inside `Makie.record` do-block | Yes — same `symuluj_krok!` mutation path | FLOWING |
| `_setup_figure` | NN baseline line | `trasa_nn(stan.D; start=1)` → `oblicz_energie(stan.D, nn_trasa, bufor)` | Yes — real deterministic NN tour | FLOWING |

No hollow props or disconnected data sources found.

---

## Behavioral Spot-Checks

Step 7b: SKIPPED for live-window and export behaviors (require OpenGL context; cannot test headlessly per D-14/D-15 LOCKED).

The following headless-safe checks were verified via grep and file inspection:

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| VIZ-06 isolation: only 1 file imports GLMakie | `grep -rl "using GLMakie" src/` | Returns only `src/wizualizacja.jl` | PASS |
| `wizualizuj` exported from module | grep `export wizualizuj` in `src/JuliaCity.jl` | Found at line 50 | PASS |
| GLMakie compat "0.13" (not "0.24") | grep Project.toml | `GLMakie = "0.13"` confirmed | PASS |
| FFMPEG_jll in Manifest (transitive) | grep Manifest.toml | `[[deps.FFMPEG_jll]]` version 8.1.0 present | PASS |
| ProgressMeter in [deps] and Manifest | grep Project.toml + Manifest | Both present (1.11.0) | PASS |
| file-exists hard error before record() | grep `isfile(sciezka)` in wizualizacja.jl | Line 270, precedes Makie.record at line 289 | PASS |
| kroki_na_klatke default 50 (≥10) | grep signature `wizualizuj(` | Line 435: `kroki_na_klatke::Int=50` | PASS |
| try/catch D-13 Polish error | grep `GLMakie wymaga aktywnego` | Line 456-458 confirmed verbatim | PASS |
| TTFP @info before display | grep `Ładowanie GLMakie` | Line 440, before any display call | PASS |
| GOTOWE overlay after SA stop | grep `_dodaj_gotowe_overlay!` | Lines 374/325-333 wired correctly | PASS |
| Test count 230/230 | 03-06-SUMMARY.md + git evidence | 230/230 PASS (Pkg.test exit 0) | PASS |

---

## REQ-ID Coverage (Phase 3 — 11 requirements)

| REQ-ID | Description | Implementation Location | Status |
|--------|-------------|------------------------|--------|
| VIZ-01 | `wizualizuj(stan, params, alg; ...)` opens GLMakie window, animates route | `src/wizualizacja.jl` lines 432-465 (public API) + `_live_loop` | SATISFIED (code-verified; runtime: MANUAL) |
| VIZ-02 | Route as line connecting trasa permutation + cycle closure, `Observable{Vector{Point2f}}` | `_trasa_do_punkty` (line 46-54), `obs_trasa::Observable{Vector{Point2f}}` (line 136), `lines!(ax_trasa, obs_trasa)` (line 146) | SATISFIED |
| VIZ-03 | Scatter points at readable size for N=1000 | `scatter!(ax_trasa, obs_trasa; markersize=5, color=:cyan)` line 145 | SATISFIED |
| VIZ-04 | Polish title, axis labels, overlay (iteration + energy) | Lines 97-106 (axis), lines 75-81 (overlay fields), 12 diacritic lines confirmed | SATISFIED |
| VIZ-05 | Throttled Observable updates, `KROKI_NA_KLATKE` default ≥ 10 | `kroki_na_klatke::Int=50` (line 435), inner batch loop (lines 205-213), 1 notify per Observable per frame | SATISFIED |
| VIZ-06 | Only `wizualizacja.jl` imports GLMakie; `runtests.jl` headless | grep confirms single file; VIZ-06 testset in runtests.jl (lines 208-245); 230/230 PASS without OpenGL | SATISFIED |
| VIZ-07 | Polish diacritics render correctly in Makie | NFC encoding confirmed by encoding-hygiene testset (230/230 PASS); diacritics present in title, labels, overlay, error messages; VIZ-07 is visual confirmation — flagged MANUAL | SATISFIED (code) / MANUAL (pixel) |
| EKS-01 | `eksport::Union{Nothing,String}` argument; saves via `Makie.record()` | `wizualizuj()` signature line 436; `_export_loop` line 289: `Makie.record(fig, sciezka, ...)` | SATISFIED (code-verified; runtime: MANUAL) |
| EKS-02 | `.mp4` and `.gif` extension auto-detected | Extension detection delegated to `Makie.record` (format inferred from path). Comment line 287: "Format wykrywany z extensji sciezka". FFMPEG_jll 8.1.0 in Manifest handles encoding. | SATISFIED |
| EKS-03 | `ProgressMeter.jl` progress bar during export | `using ProgressMeter` (line 28); `Progress(n_klatek; desc="Eksport animacji: ", dt=0.5)` (line 285); `next!(prog)` (line 311); `finish!(prog)` (line 313) | SATISFIED |
| EKS-04 | Safe file handling — hard error on existing file | `isfile(sciezka) && error("Plik '$sciezka' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku.")` lines 270-271 | SATISFIED |

---

## CONTEXT D-01..D-15 Coverage

| Decision | Description | Implementation | Status |
|----------|-------------|---------------|--------|
| D-01 | Dual-panel layout (ax_trasa left, ax_energia right) | `_setup_figure`: `Axis(fig[1,1])` + `Axis(fig[1,2])`; `colsize!(fig.layout, 1, Relative(0.6))` | IMPLEMENTED |
| D-02 | NN baseline gray dashed line on ax_trasa | `_setup_figure` lines 114-119: `lines!(ax_trasa, nn_points; color=:gray, linestyle=:dash, alpha=0.3, linewidth=1)` | IMPLEMENTED |
| D-03 | Dark theme + aspect 1:1 | `with_theme(theme_dark()) do` (line 358); `AxisAspect(1)` (line 100) | IMPLEMENTED |
| D-04 | Rich 7-field Polish overlay | `_zbuduj_overlay_string` returns 7-line string (lines 75-81); `obs_overlay::Observable{String}` (Opcja B — 1 Observable, 1 notify/frame) | IMPLEMENTED |
| D-05 | `KROKI_NA_KLATKE=50` default (≥10) | `kroki_na_klatke::Int=50` in `wizualizuj()` signature (line 435) | IMPLEMENTED |
| D-06 | GOTOWE freeze overlay after SA stop | `_dodaj_gotowe_overlay!` (lines 325-333); passive event loop `while isopen(fig); sleep(1/fps); end` (lines 377-379) | IMPLEMENTED |
| D-07 | Default Makie interactive controls; no DataInspector | No override of Makie defaults; no `DataInspector` call anywhere in file | IMPLEMENTED |
| D-08 | Two TTFP @info messages | Line 440: `"Ładowanie GLMakie..."` BEFORE display; line 368: `"Wizualizacja gotowa..."` AFTER display(fig) | IMPLEMENTED |
| D-09 | Single API entry point; branch on `eksport === nothing` | `wizualizuj()` → `_wizualizuj_impl()` → if/else branch at line 363; live: `display(fig)` + `_live_loop`; export: `_export_loop` | IMPLEMENTED |
| D-10 | File-exists hard error (no overwrite kwarg) | `isfile(sciezka) && error(...)` at line 270, before `Makie.record()` | IMPLEMENTED |
| D-11 | Unified `fps` parameter for live and export | Single `fps::Int=30` kwarg passed to both `_live_loop` (`sleep(1/fps)`) and `Makie.record(...; framerate=fps)` | IMPLEMENTED |
| D-12 | Export frame count = `liczba_krokow ÷ kroki_na_klatke`; freeze last frame on early SA stop | `n_klatek = liczba_krokow ÷ kroki_na_klatke` (line 275); `sa_zakonczono = Ref(false)` (line 279); when `sa_zakonczono[]`, Observable updated with unchanged stan (freeze) | IMPLEMENTED |
| D-13 | GLMakie hard-fail with Polish error message | `try`/`catch` wrapper in `wizualizuj()` (lines 445-462); `sprint(showerror,e)` + `contains(msg, "GLFW")` etc.; verbatim Polish error line 456-458 | IMPLEMENTED |
| D-14 | `runtests.jl` does NOT test visualization (headless) | No `@testset` for visualization smoke in `test/runtests.jl`; VIZ-06 test is pure grep-level (no GLMakie load); 230/230 PASS in headless | RESPECTED |
| D-15 | GitHub Actions CI without GLMakie display requirements | No CI config changes in Phase 3; tests remain headless-safe | RESPECTED |

**All 15 CONTEXT decisions D-01..D-15 are implemented or respected.**

---

## ROADMAP Success Criteria Coverage

| SC | Criterion | Evidence | Status |
|----|-----------|----------|--------|
| SC #1 | `wizualizuj(stan, params, alg; liczba_krokow=5000)` opens GLMakie window with live animated Hamiltonian cycle + scatter for N=1000 | `_live_loop` + `display(fig)` + `scatter!`/`lines!` on `obs_trasa`; markersize=5 for N=1000 readability | COVERED (code) / MANUAL (runtime) |
| SC #2 | Title, labels, overlay fully Polish; ąęłńóśźż render correctly | 7-field overlay (Iteracja..Akceptacja worsening), axis titles, error messages contain diacritics; NFC-normalized (encoding hygiene testset passes) | COVERED (code); MANUAL (pixel render) |
| SC #3 | Throttled updates (KROKI_NA_KLATKE ≥ 10), window stays responsive | `kroki_na_klatke=50` default; 1 Observable notify per frame; `sleep(1/fps)` yields event loop | COVERED |
| SC #4 | `wizualizacja.jl` is ONLY file in `src/` importing GLMakie; `runtests.jl` runs without OpenGL | grep confirms single file; VIZ-06 testset in runtests.jl headless; 230/230 PASS | COVERED |
| SC #5 | `wizualizuj(...; eksport="demo.mp4"/"demo.gif")` produces video with ProgressMeter + safe overwrite handling | `_export_loop` with `Makie.record()`, `Progress`/`next!`/`finish!`, `isfile()` hard error | COVERED (code) / MANUAL (runtime) |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/wizualizacja.jl` | 60-61 | Comments use "blona", "Pozostalo" (without diacritics) in docstrings but actual Polish strings in code DO have diacritics | INFO | Cosmetic only; per LANG-01 Polish in comments is best-effort, docstrings mix conventions. Diacritics in user-facing strings (overlay, error messages, titles) are correct. |
| None | — | No `return null`, empty handlers, or hollow stub patterns found | — | — |
| None | — | No `TODO`/`FIXME`/`PLACEHOLDER` in wizualizacja.jl | — | — |
| None | — | No hardcoded empty `[]` or `{}` at render sites | — | — |

No blockers or warnings found.

---

## Human Verification Required

### 1. Live Window Smoke Test

**Test:** From a machine with GPU/display, open REPL with `julia --project=. --threads=auto`, then:
```julia
using JuliaCity
pts = generuj_punkty(1000)
stan = StanSymulacji(pts)
inicjuj_nn!(stan)
alg = SimAnnealing(stan)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=5000)
wizualizuj(stan, params, alg)
```
**Expected:**
- Two @info messages appear in terminal before and after window opens
- GLMakie window opens with dark theme, dual-panel (route left, energy curve right)
- Gray dashed NN baseline visible on left panel
- Cyan scatter points + white route line update every 50 SA steps
- 7-field Polish overlay visible in top-left with live-updating values
- Window stays responsive (not frozen) throughout all 5000 steps
- GOTOWE overlay (yellow, center) appears when SA finishes
- Window stays open until manually closed

**Why human:** GLMakie requires active OpenGL context (D-14/D-15 LOCKED). Cannot test headlessly.

### 2. Export Path Smoke Test

**Test:** After live test above, from same REPL:
```julia
# Reset state
pts2 = generuj_punkty(1000)
stan2 = StanSymulacji(pts2)
inicjuj_nn!(stan2)
alg2 = SimAnnealing(stan2)
stan2.temperatura = alg2.T_zero
params2 = Parametry(liczba_krokow=1000)

# Export
wizualizuj(stan2, params2, alg2; eksport="test_output.mp4")

# Should fail:
wizualizuj(stan2, params2, alg2; eksport="test_output.mp4")  # second call same file
```
**Expected:**
- @info "Eksport do test_output.mp4 — może potrwać kilka minut..." appears
- ProgressMeter bar `Eksport animacji: XX%` updates in terminal
- `test_output.mp4` created and playable (20 frames at 30fps)
- Second call immediately throws: `"Plik 'test_output.mp4' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku."`
- GIF export also works: `eksport="test_output.gif"`

**Why human:** `Makie.record()` requires FFMPEG_jll and off-screen render context; cannot be validated headlessly.

---

## Gaps Summary

No gaps. All 5 ROADMAP Success Criteria are implemented in code. The 2 items requiring human validation are architectural consequences of D-14/D-15 LOCKED decisions (headless CI by design — not defects). The implementation is structurally complete and wired.

The test suite (230/230 PASS) validates everything that can be validated headlessly, including the critical VIZ-06 GLMakie isolation invariant.

---

## Deferred Items

No deferred items. All Phase 3 requirements (VIZ-01..07, EKS-01..04) are fully implemented. Items explicitly deferred to Phase 4 or v2 are documented in 03-CONTEXT.md and are not in-scope for this phase.

---

_Verified: 2026-04-30T12:00:00Z_
_Verifier: Claude (gsd-verifier) — model: claude-sonnet-4-6_
_Branch: master — commit range covers plans 03-00 through 03-06 (commits d5f7c14, 0de24af, ..., 26a48d6, c851d40)_
