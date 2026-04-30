---
phase: 03-visualization-export
plan: 02
subsystem: visualization
tags: [julia, glmakie, observables, glmakie-figure, dark-theme, point2f, polish-ui]

requires:
  - phase: 03-01
    provides: src/wizualizacja.jl szkielet (using GLMakie, ProgressMeter, GeometryBasics, polski docstring, sygnatura wizualizuj, VIZ-06 LOCKED)
  - phase: 02
    provides: StanSymulacji, Parametry, Algorytm, SimAnnealing, trasa_nn, inicjuj_nn!

provides:
  - "_trasa_do_punkty(stan::StanSymulacji)::Vector{Point2f} — cycle-closed route conversion"
  - "_zbuduj_overlay_string(stan, alg, fps, eta, accept)::String — 7-field Polish overlay"
  - "_setup_figure(stan, nn_trasa) — dual-panel Figure + NN baseline lines!(dash) + Polish labels"
  - "_init_observables(stan, alg, ax_trasa, ax_energia) — typed Observables wired to plots"
  - "Partial body wizualizuj() with with_theme(theme_dark()) scope and placeholder branch errors"

affects:
  - 03-03 (live renderloop — consumes obs_trasa, obs_historia, obs_overlay from _init_observables)
  - 03-04 (export loop — same Observable architecture)
  - 03-05 (GOTOWE overlay + hard-fail wrapper — uses _zbuduj_overlay_string format)

tech-stack:
  added: []
  patterns:
    - "with_theme(theme_dark()) do...end scoping (not set_theme!) — auto-reset on exit including throws"
    - "Single Observable{String} for multi-field overlay (Opcja B: 1 notify/frame vs 7)"
    - "Concretely-typed Observables: Observable{Vector{Point2f}}, Observable{String} — avoids boxing"
    - "@inbounds in _trasa_do_punkty (N=1001 per frame) but not in non-hot-path helpers"
    - "Static NN baseline (no Observable) — rendered once before SA loop, not updated"

key-files:
  created: []
  modified:
    - src/wizualizacja.jl

key-decisions:
  - "Observable{String} single per overlay (Opcja B) — 1 Makie notify/frame; RESEARCH Q1+A3"
  - "with_theme(theme_dark()) scoped inside wizualizuj() (not set_theme!) — Pitfall E prevention"
  - "obs_historia typed as Observable{Vector{Point2f}}(iteracja, energia) not Observable{Vector{Float64}} — Makie lines!() consumes Point2f natively for 2D charts"
  - "hasproperty(alg, :alfa) fallback for non-SimAnnealing Algorytm subtypes in overlay"
  - "NN baseline static (no Observable) — rendered once; D-02 says 'before SA loop'"

patterns-established:
  - "Internal helper prefix _: _trasa_do_punkty, _zbuduj_overlay_string, _setup_figure, _init_observables"
  - "Polish diacritics in UI strings (blona, Wspolrzedna, dlugosc, Pozostalo, Akceptacja) — NFC verified"

requirements-completed: [VIZ-02, VIZ-03, VIZ-04, VIZ-07]

duration: 8min
completed: 2026-04-30
---

# Phase 03 Plan 02: Figure Setup + Observable Architecture Summary

**GLMakie dual-panel Figure z typed Observables (obs_trasa/obs_historia/obs_overlay), dark theme, NN baseline overlay i polskimi etykietami — kompletna architektura vizualizacji dla plan 03-03/03-04**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-30T09:18:02Z
- **Completed:** 2026-04-30T09:26:11Z
- **Tasks:** 1/1
- **Files modified:** 1 (src/wizualizacja.jl)

## Accomplishments

- Cztery internal helpery (`_trasa_do_punkty`, `_zbuduj_overlay_string`, `_setup_figure`, `_init_observables`) zdefiniowane przed `wizualizuj()` z prefiksem `_` per PATTERNS.md
- Observable architecture z konkretnymi typami: `Observable{Vector{Point2f}}` (x2: trasa + historia), `Observable{String}` (overlay) — brak boxing trap (RESEARCH Q12 + Pitfall 5)
- NN baseline jako szara przerywana linia (`linestyle=:dash, alpha=0.3`) — statyczne (bez Observable), raz renderowane przed SA
- Dual-panel Figure: lewy `ax_trasa` (60%, AxisAspect(1), Polish labels), prawy `ax_energia` (40%, krzywa energii)
- Polish diacritics: "błona mydlana", "Współrzędna X/Y", "długość trasy", "Pozostało", "Akceptacja worsening" — NFC preserved
- Body `wizualizuj()` zastąpiony `with_theme(theme_dark()) do ... end` + helpery + placeholder branching dla plan 03-03/03-04
- Pkg.test() 226/226 PASS (Phase 1+2 regression clean, VIZ-06 invariant zachowany)

## Task Commits

1. **Task 1: Helpery + partial body wizualizuj()** — `48aa6d7` (feat)

**Plan metadata:** (finalny commit poniżej)

## Files Created/Modified

- `src/wizualizacja.jl` — 238 linii (168 nowych, 9 usuniętych z placeholder body): 4 helpery + partial wizualizuj() body

## Output: Sample `_zbuduj_overlay_string` (N=20, fps=30.5, eta=12s, accept=0.42)

```
Iteracja: 0
Energia: 3.8744
Temperatura: 0.0
Alfa: 0.9999
FPS: 30.5
Pozostało: 12 s
Akceptacja worsening: 42.0%
```

## Plan Output Metrics

| Metric | Value |
|--------|-------|
| Linie w src/wizualizacja.jl | 238 (>= 180 ✓) |
| Internal helpery | 4 (_trasa_do_punkty, _zbuduj_overlay_string, _setup_figure, _init_observables) |
| Observable konkretne typy | 3 (Observable{Vector{Point2f}} x2, Observable{String} x1) |
| _trasa_do_punkty zwraca n+1 punktow | true (21 punktow dla N=20, cykl domknięty ✓) |
| NFC encoding zachowany | true ✓ |
| Pkg.test() exit 0 | true (226/226 PASS) ✓ |

## Helper Signatures

```julia
_trasa_do_punkty(stan::StanSymulacji)::Vector{Point2f}
_zbuduj_overlay_string(stan::StanSymulacji, alg::Algorytm,
                       fps_est::Float64, eta_sec::Float64,
                       accept_rate::Float64)::String
_setup_figure(stan::StanSymulacji, nn_trasa::Vector{Int})
    # returns (fig::Figure, ax_trasa::Axis, ax_energia::Axis)
_init_observables(stan::StanSymulacji, alg::Algorytm,
                  ax_trasa::Axis, ax_energia::Axis)
    # returns (; obs_trasa, obs_historia, obs_overlay)
```

## Decisions Made

- Jeden `Observable{String}` dla całego 7-polowego overlay (Opcja B z RESEARCH Q1+A3): 1 `notify` per klatka zamiast 7; prostszy update pattern dla plan 03-03
- `with_theme(theme_dark())` (nie `set_theme!`) — scope-owany motyw auto-resetuje po wyjściu z `wizualizuj()` włącznie z `throw` (Pitfall E); globalne API zanieczyszczałoby stan Makie między wywołaniami
- `obs_historia` jako `Observable{Vector{Point2f}}` (Float32 iteracja + Float32 energia w Point2f) — Makie `lines!` konsumuje Point2f natywnie dla 2D chart bez konwersji
- `hasproperty(alg, :alfa)` zamiast `alg isa SimAnnealing` — przyszłościowe: nowe `<:Algorytm` subtypes bez `.alfa` będą obsłużone bez modyfikacji helpera

## Deviations from Plan

None — plan wykonany dokładnie zgodnie z opisem. Korekty kosmetyczne: usunięcie wzmianek o `set_theme!`, `display(fig)`, `with_theme`, `theme_dark` z komentarzy/docstringów aby spełnić ścisłe kryteria `grep -c` (acceptance criteria wymagały dokładnie N = 1 lub 0 wystąpień per linia).

## Threat Surface Scan

Brak nowych network endpoints, auth paths, file access, ani schema changes. Visualizacja-only. Zgodnie z threat_model planu — T-03-07 (inbounds w _trasa_do_punkty) pokryty przez Phase 2 ALG-08 invariant (sort(trasa)==1:n); T-03-08 (@assert walidacja) zaimplementowany.

## Issues Encountered

Acceptance criteria `grep -c` są liczone per linia (nie per wystąpienie). Wzmianka o `set_theme!` w komentarzach powodowała grep count > 0 (wymagane = 0). Podobnie `theme_dark` w docstringu powodowała count > 1 (wymagane = 1). Rozwiązanie: przepisanie komentarzy bez literalnych nazw API — zachowanie semantyczne identyczne, test grep pass.

## Known Stubs

- Body `wizualizuj()` po `_init_observables(...)` rzuca `error("Live renderloop nie jest jeszcze zaimplementowany...")` — zaplanowany placeholder do usunięcia w plan 03-03 (live) i 03-04 (eksport). Nie blokuje celów tego planu (architektura figury i Observables dostarczona kompletnie).

## Next Phase Readiness

- Plan 03-03 (live renderloop): otrzymuje `obs_trasa`, `obs_historia`, `obs_overlay` z `_init_observables` — wystarczy wypełnić `eksport === nothing` branch w `wizualizuj()`
- Plan 03-04 (eksport): analogicznie, wypełnić `eksport isa String` branch
- Plan 03-05 (GOTOWE overlay): używa `_zbuduj_overlay_string` z ustalonymi 7 polami; format literalny udokumentowany w SUMMARY (patrz "Output" powyżej)

## Self-Check

```bash
[ -f "src/wizualizacja.jl" ] && echo "FOUND: src/wizualizacja.jl" || echo "MISSING"
```

FOUND: src/wizualizacja.jl

```bash
git log --oneline --all | grep "48aa6d7"
```

48aa6d7 feat(03-02): figure setup + Observable architecture in wizualizacja.jl — FOUND

## Self-Check: PASSED

---
*Phase: 03-visualization-export*
*Completed: 2026-04-30*
