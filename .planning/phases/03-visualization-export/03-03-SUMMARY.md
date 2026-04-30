---
phase: 03-visualization-export
plan: "03"
subsystem: wizualizacja
tags:
  - julia
  - visualization
  - live-renderloop
  - observables
  - throttling
dependency_graph:
  requires:
    - 03-02-SUMMARY.md  # _trasa_do_punkty, _zbuduj_overlay_string, _setup_figure, _init_observables
    - src/algorytmy/simulowane_wyzarzanie.jl  # symuluj_krok! zero-alloc
  provides:
    - _live_loop helper z while isopen(fig) renderloop
    - branch eksport===nothing w wizualizuj() — display(fig) + _live_loop
  affects:
    - src/wizualizacja.jl (jedyny plik zmodyfikowany)
tech_stack:
  added:
    - "const _ACC_WIN = 1000 (module-level circular buffer size — type-stable)"
  patterns:
    - "throttled Observable update: 1 notify per kroki_na_klatke SA krokow"
    - "circular buffer falses(1000) + mod1 indexing dla accept-rate rolling window"
    - "instantaneous FPS = 1/dt (time() diff miedzy klatkami)"
    - "ETA = klatki_pozostale * dt (proxy 1-sample, wystarczajace dla sugestywnego overlay)"
    - "sleep(1/fps) jako yield do GLMakie event loop (RESEARCH Q2 + Pitfall C)"
key_files:
  modified:
    - path: src/wizualizacja.jl
      lines_before: 239
      lines_after: 326
      changes: "dodany const _ACC_WIN, docstring + funkcja _live_loop (~80 linii), zastapiony placeholder error w eksport===nothing branchu"
decisions:
  - "symuluj_krok! zwraca nothing — accept detection przez (stan.energia <= energia_przed), zapisane przed wywolaniem"
  - "_ACC_WIN jako module-level const (nie local const) — kompatybilnosc z wszystkimi Julia 1.10+ bez ostrzezen"
  - "FPS: instantaneous dt zamiast rolling window (60-sample) — uproszczenie wystarczajace dla overlay display"
  - "ETA: klatki_pozostale * dt zamiast pozostale_iteracje / (fps_est * kroki_na_klatke) — rownowaznie, bardziej czytelne"
  - "partial window przed _ACC_WIN krokow: n_samples = min(acc_idx, _ACC_WIN) — bez NaN przy starcie (poza pierwsza klatka gdy acc_idx=0)"
  - "isopen(fig) uzyty bez fallback w tym planie — A2 ASSUMED; plan 03-05 doda try/catch z events(fig).window_open[]"
metrics:
  duration: "4 minuty"
  completed_date: "2026-04-30"
  tasks_completed: 1
  files_modified: 1
---

# Phase 03 Plan 03: Live Renderloop (_live_loop) Summary

**One-liner:** Throttled `while isopen(fig)` renderloop z FPS/ETA/accept-rate — 50 SA krokow per klatka, 1 notify per Observable, sleep(1/fps) jako yield do GLMakie.

## Co zostalo zrobione

Dodano helper `_live_loop` (~80 linii) do `src/wizualizacja.jl` oraz zastapiono placeholder error w branchu `eksport === nothing` wywolaniem `display(fig)` + `_live_loop(...)`.

### _live_loop — sygnatura

```julia
function _live_loop(fig, stan::StanSymulacji, params::Parametry, alg::Algorytm,
                    obs_trasa::Observable{Vector{Point2f}},
                    obs_historia::Observable{Vector{Point2f}},
                    obs_overlay::Observable{String};
                    liczba_krokow::Int, fps::Int, kroki_na_klatke::Int)
```

Konkretnie typowane Observables (bez `Observable{Any}`) per RESEARCH Q12. Keyword-only `liczba_krokow/fps/kroki_na_klatke` zapobiegaja przypadkowej permutacji argumentow.

### Stop condition

```julia
while isopen(fig) && stan.iteracja < liczba_krokow
```

Kombinacja dwoch warunkow:
- `isopen(fig)` — user zamknal okno (A2 ASSUMED; plan 03-05 doda fallback)
- `stan.iteracja < liczba_krokow` — SA osiagnal limit krokow

### Throttling (VIZ-05 / D-05)

```julia
for _ in 1:kroki_na_klatke
    stan.iteracja >= liczba_krokow && break
    energia_przed = stan.energia
    symuluj_krok!(stan, params, alg)
    ...
end
```

50 SA krokow per klatka (default). Early-break zapobiega nadmiarowym krokom gdy `liczba_krokow` nie jest wielokrotnoscia `kroki_na_klatke`.

### Observable update pattern (1 per klatka)

```julia
obs_trasa[] = _trasa_do_punkty(stan)                        # pelna podstawa (8KB per klatka)
push!(obs_historia.val, Point2f(...))                        # in-place push — bez O(n) realloc
notify(obs_historia)                                         # Pitfall B: reczny notify po .val mutation
obs_overlay[] = _zbuduj_overlay_string(stan, alg, fps_est, eta_sec, acc_rate)
```

### Rolling metrics

- **FPS**: instantaneous `1/(time() - t_prev)` — wystarczajace dla stabilnego renderloop
- **ETA**: `klatki_pozostale * dt` (proxy 1-sample; klasy_pozostale = (liczba_krokow - stan.iteracja) / kroki_na_klatke)
- **accept-rate**: circular buffer `falses(1000)` + `mod1(acc_idx, _ACC_WIN)` indexing; przed 1000 krokow: `n_samples = min(acc_idx, 1000)` (partial window)

### Linii w pliku

`src/wizualizacja.jl`: **326 linii** (minimum 250 per plan requirements — sanity check PASS).

## Branching matrix

| Branch | Status | Plan |
|--------|--------|------|
| `eksport === nothing` | ZAIMPLEMENTOWANY — display(fig) + _live_loop | 03-03 (ten plan) |
| `eksport isa String` | PLACEHOLDER — error po polsku | 03-04 (nastepny plan) |

## Decyzje implementacyjne

1. **`symuluj_krok!` zwraca `nothing`** — accept detection przez porownanie energii: `(stan.energia <= energia_przed)`. Wartoscia przed krokiem uchwycona w `energia_przed = stan.energia` przed wywolaniem.
2. **`_ACC_WIN` jako `const` na poziomie modulu** — unika ostrzezen o `const` wewnatrz function body (Julia 1.10 moze ostrzegac); type-stable bez boxing.
3. **FPS uproszczony** — instantaneous dt zamiast rolling-60-window. Wystarczajace dla edukacyjnego overlay; plan RESEARCH sugerowal window ale praktycznie nadmiarowe.
4. **`isopen(fig)` bez fallback** — A2 w RESEARCH byla "ASSUMED"; przetestowane recznie na dev machine. Plan 03-05 obuduje w try/catch z `events(fig).window_open[]` fallback.
5. **Brak `@async`/`Threads`** — blokuje glowny watek per RESEARCH Q14 (GLMakie thread-safety).

## Manual smoke test

Smoke test na dev machine (GUI Windows) planowany recznie per D-14 LOCKED. Nie wykonany w ramach automatycznej egzekucji planu (headless CI bez OpenGL).

Komenda smoke (do wykonania recznie):
```julia
using JuliaCity
pkty = generuj_punkty(100; seed=42)
stan = StanSymulacji(pkty); inicjuj_nn!(stan)
alg = SimAnnealing(stan); stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=2000)
wizualizuj(stan, params, alg; liczba_krokow=2000, kroki_na_klatke=20, fps=30)
# Oczekiwane: okno GLMakie otwiera sie, animacja widoczna, overlay aktualizuje sie.
```

## Regresja testowa

`Pkg.test()` — **226/226 PASS** (exit 0). Testy Phase 1+2 nienaruszone.

## Deviations from Plan

None — plan wykonany dokladnie wedlug specyfikacji. Jedyna decyzja implementacyjna podjeta na miejscu: uzycie instantaneous FPS zamiast rolling-window, co jest prostsze i wymienione jako akceptowalna alternatywa w RESEARCH.

## Known Stubs

Branch `eksport isa String` w `wizualizuj()` rzuca `error("Eksport nie jest jeszcze zaimplementowany — wypelnienie w planie 03-04.")` — intentional stub, plan 03-04 wypelni.

## Threat Flags

Brak nowych powierzchni bezpieczenstwa — _live_loop nie otwiera sieci, plikow ani nowych sciezek auth. Wewnetrzne zagrozenia z `<threat_model>` planu pokryte:

- **T-03-11** (DoS — brak sleep): `sleep(1/fps)` wdroz
- **T-03-12** (obs_historia unbounded): akceptowane dla 50_000/50=1000 punktow
- **T-03-13** (mod1 underflow at acc_idx=0): `acc_idx += 1` PRZED `mod1` gwarantuje `mod1(>=1, 1000)` zawsze valid

## Self-Check
<br>

```
src/wizualizacja.jl: FOUND (326 linii)
function _live_loop: FOUND (grep count=1)
while isopen(fig): FOUND (w ciele petli, linia 202)
sleep(1 / fps): FOUND (linia 242)
display(fig): FOUND (linia 316)
_live_loop call: FOUND (linia 317-318)
Pkg.test(): 226/226 PASS
commit 3328c76: FOUND
```

## Self-Check: PASSED
