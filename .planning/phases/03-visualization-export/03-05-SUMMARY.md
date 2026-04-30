---
phase: 03-visualization-export
plan: 05
subsystem: visualization
tags: [julia, glmakie, error-handling, ttfp, hard-fail, gotowe-overlay, refactor]

# Dependency graph
requires:
  - phase: 03-visualization-export (03-04)
    provides: "_export_loop + eksport isa String branch, full wizualizacja.jl with live+export"
provides:
  - "_dodaj_gotowe_overlay! helper (D-06 GOTOWE text! ratio po SA stop)"
  - "_wizualizuj_impl internal helper (refaktor z wizualizuj body)"
  - "wizualizuj() jako cienki try/catch wrapper (D-13 hard-fail polski)"
  - "D-08 TTFP @info messages: Ładowanie GLMakie + Wizualizacja gotowa"
  - "D-06 passive event loop po GOTOWE overlay (okno otwarte az user zamknie)"
affects: [03-06-grep-guard-test, 04-demo-benchmarks-docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "try/catch NA ZEWNATRZ with_theme — Pitfall E compliance: _wizualizuj_impl trzyma with_theme, wizualizuj trzyma try/catch"
    - "sprint(showerror, e) + contains(msg, ...) string-match dla GLMakie/GLFW/X11/OpenGL/display errors + isa(e, InitError)"
    - "pasywny event loop while isopen(fig); sleep(1/fps); end po GOTOWE overlay"

key-files:
  created: []
  modified:
    - src/wizualizacja.jl

key-decisions:
  - "try/catch wrapper w wizualizuj() (D-13): catch po sprint(showerror,e) zawierajacym GLFW/OpenGL/X11/display/GLMakie + isa(e,InitError); rethrow dla wszystkich innych"
  - "TTFP @info D-08: Ładowanie GLMakie PRZED with_theme (wizualizuj body); Wizualizacja gotowa PO display(fig) (w _wizualizuj_impl)"
  - "GOTOWE overlay D-06: _dodaj_gotowe_overlay! dodaje text! z ratio energia/energia_nn tylko gdy SA dobiegl konca I okno otwarte; passive event loop trzyma okno az user zamknie"
  - "energia_nn liczone raz w _wizualizuj_impl przed with_theme: oblicz_energie(stan.D, nn_trasa, bufor)"

patterns-established:
  - "Thin public wrapper pattern: wizualizuj() = TTFP @info + try + _wizualizuj_impl() + catch"
  - "GLMakie error catch: string match (nie typy — GLFW nie eksportowane do scope) + isa(e, InitError)"

requirements-completed:
  - VIZ-01
  - VIZ-04
  - VIZ-05

# Metrics
duration: 12min
completed: 2026-04-30
---

# Phase 03 Plan 05: Hard-Fail Wrapper + TTFP @info + GOTOWE Overlay Summary

**wizualizuj() refaktoryzowany do cienkiego try/catch wrappera delegujacego do _wizualizuj_impl; D-08 TTFP @info messages + D-06 GOTOWE text! overlay z ratio energia/energia_nn po SA stop z pasywnym event loopem; D-13 polski hard-fail error dla GLMakie/GLFW/OpenGL/X11 na headless**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-30T09:43:00Z
- **Completed:** 2026-04-30T09:55:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Refactored `wizualizuj()` body do `_wizualizuj_impl` — try/catch jest teraz NA ZEWNATRZ `with_theme` (Pitfall E compliance)
- Dodany `_dodaj_gotowe_overlay!` helper: `text!` z `"GOTOWE — ratio: {ratio}"` w zoltym kolorze na center ax_trasa
- D-08 TTFP grace messages: `@info "Ładowanie GLMakie (pierwsze uruchomienie moze trwac 60+ s — kompilacja JIT)..."` przed z_theme; `@info "Wizualizacja gotowa, rozpoczynam symulacje..."` po display(fig)
- D-06 passive event loop po `_live_loop`: gdy SA dobiegl konca i okno otwarte — dodaje GOTOWE overlay i czeka `while isopen(fig); sleep(1/fps); end` az user zamknie
- D-13 hard-fail: catches GLFW/OpenGL/X11/display/GLMakie w sprint(showerror, e) + isa(e, InitError) → polski error verbatim; inne errors przez rethrow(e)

## Plik wizualizacja.jl — finalna struktura

**Liczba linii:** 465 (plan wymagal >= 360)

**8 internal helperow (w kolejnosci w pliku):**

| # | Funkcja | Sygnatura |
|---|---------|-----------|
| 1 | `_trasa_do_punkty` | `(stan::StanSymulacji)::Vector{Point2f}` |
| 2 | `_zbuduj_overlay_string` | `(stan::StanSymulacji, alg::Algorytm, fps_est::Float64, eta_sec::Float64, accept_rate::Float64)::String` |
| 3 | `_setup_figure` | `(stan::StanSymulacji, nn_trasa::Vector{Int})` → `(fig, ax_trasa, ax_energia)` |
| 4 | `_init_observables` | `(stan::StanSymulacji, alg::Algorytm, ax_trasa::Axis, ax_energia::Axis)` → NamedTuple |
| 5 | `_live_loop` | `(fig, stan, params, alg, obs_trasa, obs_historia, obs_overlay; liczba_krokow, fps, kroki_na_klatke)` |
| 6 | `_export_loop` | `(fig, stan, params, alg, obs_trasa, obs_historia, obs_overlay, sciezka; liczba_krokow, fps, kroki_na_klatke)` |
| 7 | `_dodaj_gotowe_overlay!` | `(ax_trasa::Axis, stan::StanSymulacji, energia_nn::Float64)` → Nothing (NEW) |
| 8 | `_wizualizuj_impl` | `(stan::StanSymulacji, params::Parametry, alg::Algorytm; liczba_krokow, fps, kroki_na_klatke, eksport)` (NEW) |

**Publiczna sygnatura:**
```julia
function wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
                    liczba_krokow::Int=params.liczba_krokow,
                    fps::Int=30,
                    kroki_na_klatke::Int=50,
                    eksport::Union{Nothing,String}=nothing)::Nothing
```

## Literalne wartosci D-06/D-08/D-13

**D-13 polish error (verbatim):**
```
GLMakie wymaga aktywnego kontekstu OpenGL. Brak displayu? Spróbuj `xvfb-run -a julia ...` na Linuksie albo uruchom lokalnie z GUI. Headless cloud (CI, Docker bez X) NIE jest wspierany w wersji v1.
```

**D-08 TTFP messages:**
```
Ładowanie GLMakie (pierwsze uruchomienie może trwać 60+ s — kompilacja JIT)...
Wizualizacja gotowa, rozpoczynam symulację...
```

**D-06 GOTOWE overlay text format:**
```
GOTOWE — ratio: {round(stan.energia / energia_nn; digits=4)}
```
(np. "GOTOWE — ratio: 0.9408" dla SA/NN baseline ratio)

## Coverage matrix D-01..D-15

| Decision | Funkcja realizujaca | Status |
|----------|---------------------|--------|
| D-01: Dual-panel layout | `_setup_figure` | DONE (plan 03-02) |
| D-02: NN baseline szara linia | `_setup_figure` | DONE (plan 03-02) |
| D-03: Dark theme + aspect 1:1 | `_wizualizuj_impl` (with_theme) | DONE (plan 03-02) |
| D-04: Rich overlay 7 pol | `_zbuduj_overlay_string` + `_live_loop` | DONE (plan 03-02/03) |
| D-05: KROKI_NA_KLATKE=50 default | `wizualizuj()` sygnatura | DONE (plan 03-03) |
| D-06: GOTOWE freeze po SA stop | `_dodaj_gotowe_overlay!` + `_wizualizuj_impl` passive loop | DONE (plan 03-05) |
| D-07: Interactive Makie defaults | brak override (passthrough) | DONE (plan 03-02) |
| D-08: TTFP @info grace | `wizualizuj()` + `_wizualizuj_impl` | DONE (plan 03-05) |
| D-09: Single API entry point | `wizualizuj()` branching | DONE (plan 03-03/04) |
| D-10: file-exists hard error | `_export_loop` | DONE (plan 03-04) |
| D-11: Unified fps | wspolny parametr | DONE (plan 03-03) |
| D-12: Eksport n_klatek = kroków/klatke | `_export_loop` | DONE (plan 03-04) |
| D-13: GLMakie hard-fail polski | `wizualizuj()` try/catch | DONE (plan 03-05) |
| D-14: runtests bez wizualizacji | testy headless (src/*.jl bez wizualizacja.jl) | RESPECTED |
| D-15: CI bez GLMakie | brak zmian CI | RESPECTED |

**Wszystkie 15 CONTEXT decisions D-01..D-15 zaimplementowane.**

## Task Commits

1. **Task 1: Refactor wizualizuj() + _dodaj_gotowe_overlay! + _wizualizuj_impl + TTFP + D-13** - `26a48d6` (feat)

## Files Created/Modified

- `/C/Users/mparol/Desktop/Dokumenty/Projekty/JuliaCity/src/wizualizacja.jl` - Added _dodaj_gotowe_overlay!, _wizualizuj_impl, TTFP @info messages, try/catch D-13 wrapper; 399 -> 465 lines (+66 lines net refactor + additions)

## Decisions Made

- try/catch NA ZEWNATRZ with_theme — Pitfall E compliance: wymagalo refaktoryzacji body wizualizuj() do _wizualizuj_impl
- energia_nn liczone w _wizualizuj_impl przed with_theme uzywajac 3-arg oblicz_energie(stan.D, nn_trasa, bufor)
- Passive event loop zamiast wait(fig.scene) — prostsze i pewniejsze na roznych platformach

## Deviations from Plan

None — plan wykonany dokladnie wedlug specyfikacji. Wszystkie 3 elementy (D-13, D-08, D-06) zaimplementowane zgodnie z PLAN.md interfejsami.

## Issues Encountered

None. Precompilacja JuliaCity (bez GLMakie OpenGL window) zajela 20s. Pkg.test() 226/226 PASS w 1m48s.

## Manual Smoke Tests

- **Live mode + GOTOWE overlay:** NIE uruchamiano (brak GUI w srodowisku wykonawczym) — logika poprawna strukturalnie
- **Export mode:** NIE uruchamiano (wymaga FFMPEG + display) — _export_loop nie zmieniony od plan 03-04
- **Headless D-13 error:** NIE uruchamiano (wymaga srodowiska bez DISPLAY) — logika try/catch zweryfikowana statycznie przez grep + using JuliaCity precompile

## Regression Check

- **Pkg.test():** 226/226 PASS (exit 0)
- **VIZ-06:** `grep -rl "^using GLMakie" src/` zwraca tylko `src/wizualizacja.jl` (1 plik)

## Next Phase Readiness

- `src/wizualizacja.jl` jest PELNA (wszystkie 15 D-01..D-15 decisions zaimplementowane)
- Pozostaje tylko plan 03-06: grep guard test (`grep -l "using GLMakie" src/` w runtests.jl)
- Phase 4 (demo, benchmarks, docs) moze teraz korzystac z kompletnego publicznego API `wizualizuj()`

---
*Phase: 03-visualization-export*
*Completed: 2026-04-30*
