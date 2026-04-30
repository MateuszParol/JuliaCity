---
phase: 03-visualization-export
plan: "04"
subsystem: wizualizacja
tags:
  - julia
  - visualization
  - export
  - record
  - progressmeter
dependency_graph:
  requires:
    - 03-03-SUMMARY.md  # _live_loop, _trasa_do_punkty, _zbuduj_overlay_string, _init_observables
    - src/algorytmy/simulowane_wyzarzanie.jl  # symuluj_krok! zero-alloc
  provides:
    - _export_loop helper z Makie.record() blocking export
    - branch eksport isa String w wizualizuj() — _export_loop call
  affects:
    - src/wizualizacja.jl (jedyny plik zmodyfikowany)
tech_stack:
  added: []
  patterns:
    - "Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do frame_i — blocking export per klatka"
    - "sa_zakonczono = Ref(false) freeze-last-frame semantics (D-12)"
    - "ProgressMeter.Progress(n_klatek; desc=..., dt=0.5) + next! + finish! (EKS-03)"
    - "isfile(sciezka) hard-fail z polskim errorem PRZED record() (D-10/EKS-04/Pitfall D)"
    - "format auto-detect z extensji .mp4/.gif/.webm przez Makie (RESEARCH Q9/EKS-02)"
key_files:
  modified:
    - path: src/wizualizacja.jl
      lines_before: 326
      lines_after: 398
      changes: "dodany _export_loop helper (~70 linii) + zastapiony placeholder error w eksport isa String branchu"
decisions:
  - "NIE wywolujemy display(fig) przed _export_loop — record() samodzielnie obsluguje off-screen render"
  - "overlay w eksport mode przekazuje NaN dla fps_est/eta_sec/accept_rate — metryki realtime bez sensu w blocking record"
  - "frame_i parametr wymagany przez Makie.record API ale nieuzywany wewnatrz callbacka — stan trzymany w stan + obs_*"
  - "Point2f(Float32(stan.iteracja), Float32(stan.energia)) — explicit Float32 konwersja dla Point2f = Point2{Float32}"
metrics:
  duration: "8 minut"
  completed_date: "2026-04-30"
  tasks_completed: 1
  files_modified: 1
---

# Phase 03 Plan 04: Export Loop (_export_loop) Summary

**One-liner:** Blocking `Makie.record()` eksport z ProgressMeter, isfile() hard-fail, freeze-last-frame Ref, i polskim @info — kompletna implementacja branch `eksport isa String` w `wizualizuj()`.

## Co zostalo zrobione

Dodano helper `_export_loop` (~70 linii) do `src/wizualizacja.jl` oraz zastapiono placeholder error w branchu `eksport isa String` wywolaniem `_export_loop(...)`.

### _export_loop — sygnatura

```julia
function _export_loop(fig, stan::StanSymulacji, params::Parametry, alg::Algorytm,
                      obs_trasa::Observable{Vector{Point2f}},
                      obs_historia::Observable{Vector{Point2f}},
                      obs_overlay::Observable{String},
                      sciezka::String;
                      liczba_krokow::Int, fps::Int, kroki_na_klatke::Int)
```

### D-10 / EKS-04 — polski error message (literalna kopia dla plan 03-05 + Phase 4)

```
"Plik '$sciezka' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku."
```

### D-09 — polski @info message (literalna kopia)

```
"Eksport do $sciezka — może potrwać kilka minut, terminal nie reaguje, postęp poniżej:"
```

### n_klatek (D-12)

```julia
n_klatek = liczba_krokow ÷ kroki_na_klatke
@assert n_klatek > 0 "n_klatek must be positive (liczba_krokow >= kroki_na_klatke required)"
```

### Freeze-last-frame (D-12)

```julia
sa_zakonczono = Ref(false)
# ...
Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do frame_i
    if !sa_zakonczono[]
        for _ in 1:kroki_na_klatke
            if stan.iteracja >= liczba_krokow
                sa_zakonczono[] = true
                break
            end
            symuluj_krok!(stan, params, alg)
        end
    end
    # Observable update niezalezny od sa_zakonczono — FREEZE przez brak zmiany stanu
    obs_trasa[] = _trasa_do_punkty(stan)
    push!(obs_historia.val, Point2f(Float32(stan.iteracja), Float32(stan.energia)))
    notify(obs_historia)
    obs_overlay[] = _zbuduj_overlay_string(stan, alg, NaN, NaN, NaN)
    next!(prog)
end
finish!(prog)
```

### Branching matrix

| Branch | Status | Plan |
|--------|--------|------|
| `eksport === nothing` | ZAIMPLEMENTOWANY — display(fig) + _live_loop | 03-03 |
| `eksport isa String` | ZAIMPLEMENTOWANY — _export_loop + Makie.record | 03-04 (ten plan) |
| Hard-fail GLMakie wrapper | DEFERRED | 03-05 |
| GOTOWE overlay (D-06) | DEFERRED | 03-05 |
| TTFP @info (D-08) | ZAIMPLEMENTOWANY (juz w 03-03) | 03-03 |

### Linii w pliku

`src/wizualizacja.jl`: **398 linii** (minimum 320 per plan requirements — sanity check PASS).

## Manual smoke test

Smoke test planowany recznie per D-14 LOCKED. Nie wykonany w ramach automatycznej egzekucji planu (headless CI bez OpenGL).

- **Test sukces eksportu**: `wizualizuj(stan, params, alg; liczba_krokow=400, kroki_na_klatke=20, fps=30, eksport="/tmp/test.mp4")` → @info wyswietlony, ProgressMeter dziala, plik powstaje.
- **Test D-10 trigger**: drugi call z ta sama sciezka → `ErrorException: Plik '/tmp/test.mp4' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku.`
- **Status**: Nie wykonany automatycznie (D-14 LOCKED — Pkg.test() nie uruchamia wizualizuj()).

## Regresja testowa

`Pkg.test()` — **226/226 PASS** (exit 0). Testy Phase 1+2 nienaruszone.

## Deviations from Plan

None — plan wykonany dokladnie wedlug specyfikacji. Sygnatura `_export_loop` zgodna z PLAN interfejsem. Polskie komunikaty z poprawnymi NFC diakrytykami.

## Known Stubs

Brak — oba branche (live + eksport) sa pelne. Plan 03-05 doda: try/catch hard-fail wrapper (D-13), GOTOWE overlay (D-06), ewentualnie test isopen fallback.

## Threat Flags

Brak nowych powierzchni bezpieczenstwa — _export_loop zapisuje tylko do sciezki podanej przez uzytkownika (lokalne CLI). Zagrozenia z `<threat_model>` planu pokryte:

- **T-03-15** (Tampering — overwrite bez ostrzezenia): `isfile(sciezka) && error(...)` wdroz
- **T-03-16** (n_klatek == 0): `@assert n_klatek > 0` wdroz
- **T-03-17** (path w error message): akceptowane — standard practice
- **T-03-18** (DoS — brak feedback): @info + ProgressMeter wdroz

## Self-Check

```
src/wizualizacja.jl: FOUND (398 linii — >= 320 PASS)
function _export_loop: FOUND (grep count=1)
isfile(sciezka) functional call: FOUND (linia 270)
"już istnieje" polish error: FOUND (linia 271)
Makie.record(fig, sciezka, 1:n_klatek; framerate=fps): FOUND (linia 289)
Progress(n_klatek; desc="Eksport animacji: ", dt=0.5): FOUND (linia 285)
next!(prog): FOUND (linia 311)
finish!(prog): FOUND (linia 313)
sa_zakonczono: FOUND (5x — init, check, set true x2, return path)
n_klatek = liczba_krokow ÷ kroki_na_klatke: FOUND (linia 275)
"Eksport do $sciezka — może potrwać...": FOUND (linia 282)
_export_loop call in wizualizuj() body: FOUND (linia 392)
Placeholder error absent: CONFIRMED (grep -c = 0)
_live_loop call preserved: FOUND (linia 388)
format= kwarg absent: CONFIRMED (grep -c = 0, auto-detect z extensji)
VIZ-06: grep -rl "^using GLMakie" src/ = 1 file (tylko wizualizacja.jl) PASS
Pkg.test() 226/226 PASS
commit 7172efd: FOUND
```

## Self-Check: PASSED
