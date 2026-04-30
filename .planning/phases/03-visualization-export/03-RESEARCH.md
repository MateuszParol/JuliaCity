# Phase 3: Visualization & Export — Research

**Researched:** 2026-04-30
**Domain:** GLMakie 0.13.x + Observables 0.5.x + ProgressMeter 1.11 — live animation + MP4/GIF export
**Confidence:** HIGH (versions verified against registry; API verified against docs.makie.org)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01**: Dual-panel layout — `fig[1,1] = ax_trasa` (AxisAspect 1:1), `fig[1,2] = ax_energia` (live energy chart).
- **D-02**: NN baseline as `lines!(ax_trasa, nn_points; color=:gray, linestyle=:dash, alpha=0.3)` — rendered once before SA.
- **D-03**: `set_theme!(theme_dark())` + `ax_trasa.aspect = AxisAspect(1)`.
- **D-04**: Rich 7-field Polish overlay via `text!` (or `textlabel!`) — each field an `Observable{String}`.
- **D-05**: `KROKI_NA_KLATKE = 50` (public kwarg `kroki_na_klatke::Int=50`).
- **D-06**: Freeze + "GOTOWE" overlay after SA ends; window stays open.
- **D-07**: Default Makie interactivity (zoom/pan/Ctrl+R); no DataInspector.
- **D-08**: TTFP `@info` before `display(fig)`.
- **D-09**: Single `wizualizuj()` entry point branching on `eksport === nothing` (live loop) vs `eksport isa String` (blocking `Makie.record()`).
- **D-10**: File-exists hard error (`isfile()` check before `Makie.record()`).
- **D-11**: `fps` unified for live + export (default 30).
- **D-12**: Export frame count = `liczba_krokow ÷ kroki_na_klatke`; freeze last frame if SA ends early.
- **D-13**: Hard-fail GLMakie errors with Polish message; no CairoMakie fallback.
- **D-14**: `runtests.jl` does NOT test visualization.
- **D-15**: GitHub Actions CI unchanged.

### Claude's Discretion

- Kolor punktów: jednolity z dark theme palette (np. cyan/light blue).
- Kolor linii trasy: kontrastowy do tła (np. white/light yellow).
- Font overlay'u: GLMakie default; diakrytyki działają out-of-the-box (potwierdzono NFC w Phase 1 D-21).
- Margin/padding: Makie defaults; tweaks during execution if overlay overlaps route.
- Overlay position: top-left (`align=(:left, :top)`), ~10px from edge.
- Scatter markersize: ~4-6 px empirically for N=1000.
- Energy line: 2px, kontrastowy kolor.
- Full signature: `wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm; liczba_krokow::Int=params.liczba_krokow, fps::Int=30, kroki_na_klatke::Int=50, eksport::Union{Nothing,String}=nothing)::Nothing`.

### Deferred Ideas (OUT OF SCOPE)

- CairoMakie fallback for headless CI
- Color gradients (temperature → energy per-point)
- Loop replay
- Separate `eksport_fps`
- Auto-suffix naming
- `nadpisz::Bool` kwarg
- Visualization smoke test in runtests.jl
- Linux CI with xvfb
- PackageCompiler sysimage
- DataInspector
- Multi-algorithm comparison view
- 3-opt / or-opt
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VIZ-01 | `wizualizuj()` opens GLMakie window and animates tour in real-time | D-09 branching pattern; `record()` vs live loop architecture documented below |
| VIZ-02 | Route rendered as line connecting points in permutation order with cycle closure; uses `Observable{Vector{Point2f}}` | Observable update pattern; `lines!(ax, obs_trasa)` with cycle-closure point appended |
| VIZ-03 | Points as scatter with size legible for N=1000 | `scatter!(ax, obs_punkty; markersize=4)` — exact size empirically determined |
| VIZ-04 | Polish title, axis labels, overlay — all in Polish with correct diacritics | `textlabel!` (0.22.5+) or `text!`; default "TeX Gyre Heros Makie" font covers Latin-extended; verified via NFC encoding |
| VIZ-05 | Observable updates throttled (KROKI_NA_KLATKE ≥ 10) | `KROKI_NA_KLATKE=50` pattern; `sleep(1/fps)` for live loop; single `notify` per frame |
| VIZ-06 | `wizualizacja.jl` is the ONLY file in `src/` importing GLMakie | Module isolation pattern confirmed; `using GLMakie` at top of `wizualizacja.jl` only |
| VIZ-07 | Polish diacritics render correctly in Makie | Default "TeX Gyre Heros Makie" font covers Latin Extended-A/B; NFC encoding in Phase 1 D-21 ensures correct source |
| EKS-01 | `eksport::Union{Nothing,String}` arg; path given → `Makie.record()` | `record(fig, path, 1:n_klatek; framerate=fps) do i ... end` |
| EKS-02 | `.mp4` and `.gif` extensions detected from path | `Makie.record()` auto-detects from file extension — VERIFIED |
| EKS-03 | ProgressMeter shows progress during export | `Progress(n_klatek; desc="...")` + `next!(prog)` inside `record()` callback |
| EKS-04 | Safe file handling — no silent overwrite | `isfile(eksport) && error(...)` before `record()` call |
</phase_requirements>

---

## Summary

Phase 3 adds `src/wizualizacja.jl` — the sole GLMakie consumer in the codebase. The file implements `wizualizuj()`, a public function that branches between two execution paths: a live interactive renderloop and a blocking `Makie.record()` export. All 15 user decisions in CONTEXT.md are firm; this research surfaces the HOW of each decision.

**Critical blocker found during research:** Project.toml [compat] has `GLMakie = "0.24"` which is **wrong**. GLMakie uses its own version series (currently 0.13.10); the correct compat entry is `GLMakie = "0.13"`. This error blocks `Pkg.add("GLMakie")` entirely. Wave 0 must fix this before any other task.

The standard pattern for live animation is `obs[] = new_value` (triggers callbacks synchronously) with `sleep(1/fps)` in the outer loop — confirmed from Makie docs and Discourse. The `record()` function accepts an iterator, calls a user-supplied callback per element, detects file format from extension (mp4/gif/webm/mkv), and uses FFMPEG_jll transitively. ProgressMeter integrates cleanly inside the `record()` callback. Polish diacritics render correctly via the default "TeX Gyre Heros Makie" font (FreeType-backed, Latin Extended-A/B). GLMakie must be used from the main thread only.

**Primary recommendation:** Fix [compat] GLMakie = "0.13" in Wave 0; then follow the Observable + throttled loop pattern for the live path and the `record()` + ProgressMeter pattern for the export path, exactly as described in the Code Examples section below.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SA step execution | CPU / main thread | — | `symuluj_krok!` is sequential single-RNG (Phase 2 D-09) |
| Observable update (route + energy) | Main thread | — | GLMakie thread-safety: "updates from other threads may cause segfault" |
| Live renderloop | Main thread (blocking while loop) | — | `sleep(1/fps)` + `yield()` lets GLMakie event loop breathe |
| Export recording | Main thread (`Makie.record()`) | FFMPEG_jll (subprocess) | `record()` is synchronous; FFMPEG spawned by Makie internals |
| Figure layout / styling | GLMakie / GPU | — | `set_theme!`, `Figure`, `Axis`, `colsize!` |
| Polish text overlay | GLMakie text renderer | FreeType | `textlabel!` or `text!` with `Observable{String}` |
| NN baseline draw | GLMakie (one-shot) | — | `lines!` called once before loop; no Observable needed |
| Energy history plot | GLMakie (Observable) | — | `obs_energia_historia::Observable{Vector{Float64}}` |
| File-exists guard | Julia stdlib (`isfile`) | — | Pure Julia, no GLMakie needed |
| ProgressMeter display | Terminal stdout | — | ProgressMeter writes to stdout; not part of GLMakie render |

---

## Standard Stack

### Core (Phase 3 additions)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **GLMakie** | **0.13.10** | Live OpenGL window, scatter/lines/text, record() | Only backend with GPU renderloop; VERIFIED: `v0.13.10` installs from registry [VERIFIED: julia registry] |
| **Makie** | **0.24.10** | Framework; transitively pulled by GLMakie | Monorepo — installed automatically; provides `record()`, `Observable`, themes [VERIFIED: julia registry] |
| **Observables** | **0.5.5** | Reactive containers `Observable{T}` | Canonical animation primitive for Makie; `obs[] = val` triggers callbacks [VERIFIED: julia registry] |
| **ProgressMeter** | **1.11.0** | Progress bar during blocking `record()` | Standard Julia progress library; `Progress(n) + next!()` pattern; thread-safe [VERIFIED: julia registry] |

### Already in Project

| Library | Version | Phase Added | Used in Phase 3 |
|---------|---------|-------------|-----------------|
| **GeometryBasics** | 0.5.10 | Phase 1 | `Point2f` for Makie GPU pipeline; conversion from `Punkt2D = Point2{Float64}` |
| **Random** | stdlib | Phase 1 | Not directly used in wizualizacja.jl |

### Critical Project.toml Fix Required (Wave 0)

Current [compat]: `GLMakie = "0.24"` — **WRONG** (0.24 does not exist for GLMakie)
Correct [compat]: `GLMakie = "0.13"` — **VERIFIED** against registry (GLMakie 0.13.10 pairs with Makie 0.24.10)

[VERIFIED: npm registry equivalent — `julia -e "Pkg.add(\"GLMakie\")"` in clean env returns `GLMakie v0.13.10`]

**Installation (after compat fix):**
```julia
using Pkg
Pkg.activate(".")
# Fix Project.toml [compat] GLMakie = "0.13" first, then:
Pkg.add(["GLMakie", "Observables", "ProgressMeter"])
```

**FFMPEG_jll:** Do NOT add as direct dep — pulled transitively by Makie. [CITED: docs.makie.org/stable/explanations/animation.html]

---

## Architecture Patterns

### System Architecture Diagram

```
wizualizuj() entry
       │
       ├─ eksport === nothing ──────────────────────────────┐
       │                                                     │
       │  LIVE PATH                                         EXPORT PATH
       │  display(fig)                                       │
       │       │                                    isfile() guard → error or continue
       │  while isopen(fig)                                  │
       │    for _ in 1:kroki_na_klatke                @info "Eksport do {path}..."
       │       symuluj_krok!(stan, params, alg)             │
       │    end                                      Progress(n_klatek; desc="...")
       │    obs_trasa[] = trasa_do_point2f(stan)             │
       │    obs_energia[] = push!(historia, stan.energia)   Makie.record(fig, path, 1:n_klatek;
       │    update_overlay_observables!(...)                    framerate=fps) do frame_i
       │    sleep(1/fps)         ◄── yield to renderloop         for _ in 1:kroki_na_klatke
       │  end                                                       symuluj_krok!(...)
       │                                                         end
       │  GOTOWE overlay                                          obs_trasa[] = ...
       │  wait for window close                                   obs_energia[] = ...
       │                                                          next!(prog)  ← ProgressMeter
       │                                                       end  ← record frame
       │                                                   end  ← record closes file
       └────────────────────────────────────────────────────┘
              ▲                          ▲
         GLMakie GPU               FFMPEG_jll subprocess
         (renderloop)              (MP4/GIF encoding)
```

### Recommended Project Structure

```
src/
├── JuliaCity.jl         # add: include("wizualizacja.jl") + export wizualizuj
├── wizualizacja.jl      # ONLY file with `using GLMakie` (VIZ-06)
├── typy.jl              # StanSymulacji, Parametry, Algorytm (unchanged)
├── punkty.jl            # generuj_punkty (unchanged)
├── energia.jl           # oblicz_energie, delta_energii (unchanged)
├── baselines.jl         # trasa_nn, inicjuj_nn! (unchanged)
└── algorytmy/
    └── simulowane_wyzarzanie.jl  # symuluj_krok!, uruchom_sa! (unchanged)
```

### Pattern 1: Figure Setup with Dual Panel

```julia
# Source: docs.makie.org/stable/explanations/animation.html + Axis docs
using GLMakie

function _setup_figure(stan::StanSymulacji, nn_trasa::Vector{Int})
    fig = Figure(size=(1400, 700))

    # Lewy panel — trasa SA z aspect 1:1
    ax_trasa = Axis(fig[1, 1];
        title = "Trasa TSP — błona mydlana (N=$(length(stan.punkty)))",
        xlabel = "Współrzędna X",
        ylabel = "Współrzędna Y",
        aspect = AxisAspect(1))

    # Prawy panel — wykres energii
    ax_energia = Axis(fig[1, 2];
        title = "Energia trasy vs iteracja",
        xlabel = "Iteracja",
        ylabel = "Energia (długość trasy)")

    # Prawy panel ~40% szerokości lewego
    colsize!(fig.layout, 1, Relative(0.6))

    return fig, ax_trasa, ax_energia
end
```

[CITED: docs.makie.org/stable/reference/blocks/axis] — `AxisAspect(1)`, `colsize!`, `Relative`

### Pattern 2: Observable Architecture (Type-Stable)

```julia
# Typy obserwabli — KONKRETNE (nie Observable{Any} — Pitfall 5 + closure boxing)
obs_trasa    = Observable(Vector{Point2f}())    # Observable{Vector{Point2f}}
obs_energia  = Observable(Point2f[])            # dla lines! na wykresie energii
obs_iter     = Observable("Iteracja: 0")        # Observable{String}
obs_ene_str  = Observable("Energia: 0.0000")
obs_temp_str = Observable("Temperatura: 0.0000")
obs_alfa_str = Observable("Alfa: $(alg.alfa)")
obs_fps_str  = Observable("FPS: —")
obs_eta_str  = Observable("Pozostało: —")
obs_acc_str  = Observable("Akceptacja worsening: —")

# Podłączenie do Makie — scatter + lines wymagają Vector{Point2f}
scatter!(ax_trasa, obs_trasa; markersize=5, color=:cyan)
lines!(ax_trasa, obs_trasa; color=:white)   # open polyline
# NOTE: zamknięcie cyklu — dodaj punkty[trasa[1]] na końcu przy każdym update

# NN baseline — jednorazowy lines! (nie Observable — statyczny)
nn_points = [stan.punkty[i] for i in nn_trasa]
push!(nn_points, nn_points[1])  # zamknięcie cyklu
lines!(ax_trasa, Point2f.(nn_points); color=:gray, linestyle=:dash, alpha=0.3)

# Energia — push do obs i replot
lines!(ax_energia, obs_energia; color=:orange, linewidth=2)
```

[CITED: docs.makie.org/stable/explanations/observables.html] — typed observables, `obs[] = val`

### Pattern 3: Observable Update — Vektor + Cycle Closure

```julia
# Konwersja Punkt2D(Float64) → Point2f(Float32) dla GPU pipeline
# Point2f.(vec) alokuje nowy Vector — jedyna allokacja per frame, akceptowalna
function trasa_do_punkty(stan::StanSymulacji)::Vector{Point2f}
    n = length(stan.trasa)
    pts = Vector{Point2f}(undef, n + 1)   # +1 dla zamknięcia cyklu
    @inbounds for k in 1:n
        pts[k] = Point2f(stan.punkty[stan.trasa[k]])
    end
    pts[n + 1] = pts[1]  # zamknięcie cyklu
    return pts
end

# Mutacja val + notify vs [] = val:
# - obs[] = new_val    → triggers callbacks synchronously (standard)
# - obs.val = new_val  → mutacja bez triggera, potem notify(obs) ręcznie
# Używamy obs[] = val (jedna allokacja per frame dla Vector{Point2f})
obs_trasa[] = trasa_do_punkty(stan)
```

[CITED: docs.makie.org/stable/explanations/observables.html] — `obs.val` mutation vs `obs[] = val`

### Pattern 4: Live Renderloop (display path)

```julia
function _live_loop(fig, stan, params, alg, obs_trasa, obs_ene_historia,
                    overlay_obs, liczba_krokow, fps, kroki_na_klatke)
    # Rolling window dla FPS i accept rate
    fps_window   = zeros(Float64, 60)   # ostatnie 60 timestampów
    acc_window   = zeros(Bool, 1000)    # ostatnie 1000 kroków
    fps_idx      = Ref(0)
    acc_idx      = Ref(0)
    acc_total    = Ref(0)
    t_prev       = Ref(time())

    while isopen(fig) && stan.iteracja < liczba_krokow
        for _ in 1:kroki_na_klatke
            energia_przed = stan.energia
            symuluj_krok!(stan, params, alg)
            acc_window[mod1(acc_idx[] += 1, 1000)] = (stan.energia <= energia_przed)
        end

        # Update Observables (jeden raz na kroki_na_klatke kroków — D-05)
        obs_trasa[] = trasa_do_punkty(stan)
        push!(obs_ene_historia[], Point2f(stan.iteracja, stan.energia))
        notify(obs_ene_historia)  # Vector mutowany in-place → ręczny notify

        # Overlay strings update
        t_now = time()
        fps_est = 1.0 / max(t_now - t_prev[], 1e-9)
        t_prev[] = t_now
        eta = (liczba_krokow - stan.iteracja) / (fps_est * kroki_na_klatke)
        acc_rate = sum(acc_window) / min(acc_idx[], 1000)
        _aktualizuj_overlay!(overlay_obs, stan, alg, fps_est, eta, acc_rate)

        sleep(1/fps)   # yield do renderloop GLMakie — kluczowe dla responsywności
    end

    # GOTOWE overlay (D-06)
    # ...
end
```

[CITED: discourse.julialang.org/t/renderloop-updates-in-glmakie-jl/114397] — `sleep(1/fps)` pattern
[ASSUMED: `isopen(fig)` works correctly as stop condition — sprawdzić w implementacji]

### Pattern 5: Export Path z ProgressMeter

```julia
function _export_loop(fig, stan, params, alg, obs_trasa, obs_ene_historia,
                      overlay_obs, sciezka, fps, kroki_na_klatke, liczba_krokow)
    isfile(sciezka) && error("Plik '$sciezka' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku.")

    n_klatek = liczba_krokow ÷ kroki_na_klatke
    sa_zakonczono = Ref(false)

    @info "Eksport do $sciezka — może potrwać kilka minut, terminal nie reaguje, postęp poniżej:"
    prog = Progress(n_klatek; desc="Eksport animacji: ", dt=0.5)

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
        # Freeze last frame gdy SA skończyło wcześniej (D-12)
        obs_trasa[] = trasa_do_punkty(stan)
        push!(obs_ene_historia[], Point2f(stan.iteracja, stan.energia))
        notify(obs_ene_historia)
        next!(prog)
    end
    finish!(prog)
end
```

[CITED: github.com/timholy/ProgressMeter.jl] — `Progress(n; desc=..., dt=...)` + `next!()` + `finish!()`
[CITED: docs.makie.org/stable/explanations/animation.html] — `record(fig, path, iterator; framerate=fps) do i ... end`

### Pattern 6: Hard-Fail GLMakie Catch (D-13)

```julia
function wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
                    liczba_krokow::Int=params.liczba_krokow,
                    fps::Int=30,
                    kroki_na_klatke::Int=50,
                    eksport::Union{Nothing,String}=nothing)::Nothing
    @info "Ładowanie GLMakie (pierwsze uruchomienie może trwać 60+ s — kompilacja JIT)..."
    try
        _wizualizuj_impl(stan, params, alg; liczba_krokow, fps, kroki_na_klatke, eksport)
    catch e
        # GLMakie rzuca GLFW.GLFWError lub InitError gdy brak OpenGL/display
        # Sprawdzamy po typie lub komunikacie (GLFW może nie być eksportowane)
        msg = sprint(showerror, e)
        if contains(msg, "GLFW") || contains(msg, "OpenGL") || contains(msg, "display") ||
           contains(msg, "X11") || contains(msg, "GLMakie") || isa(e, InitError)
            error("GLMakie wymaga aktywnego kontekstu OpenGL. Brak displayu? " *
                  "Spróbuj `xvfb-run -a julia ...` na Linuksie albo uruchom lokalnie z GUI. " *
                  "Headless cloud (CI, Docker bez X) NIE jest wspierany w wersji v1.")
        else
            rethrow(e)
        end
    end
    return nothing
end
```

[CITED: github.com/MakieOrg/Makie.jl/issues/1953] — GLFWError(VERSION_UNAVAILABLE) as exception type
[CITED: docs.makie.org/stable/explanations/backends/glmakie.html] — headless CI requirement

### Pattern 7: Theme Scoping (D-03)

```julia
# WYBÓR: with_theme() dla scope-owanej zmiany (zalecane gdy wizualizuj() może być
# wywołane wielokrotnie — nie zanieczyszcza globalnego stanu po powrocie)
with_theme(theme_dark()) do
    fig, ax_trasa, ax_energia = _setup_figure(stan, nn_trasa)
    ax_trasa.aspect = AxisAspect(1)
    # ... cała logika wewnątrz
end
```

Alternatywa: `set_theme!(theme_dark())` — persists globalnie (ryzyko: zanieczyszcza środowisko
wywołującego jeśli `wizualizuj()` wraca bez reset). `with_theme` jest bezpieczniejsze.
[CITED: docs.makie.org/dev/explanations/theming/themes] — `with_theme` auto-resets on exit

### Pattern 8: textlabel! dla overlay z tłem (dostępne od Makie 0.22.5)

```julia
# textlabel! dostarcza background z padding, cornerradius — idealne dla overlay (D-04)
# Dostępne od Makie 0.22.5, więc bezpieczne przy compat "0.24"
obs_overlay = Observable("""
Iteracja: 0
Energia: 0.0000
Temperatura: 0.000000
Alfa: $(alg.alfa)
FPS: —
Pozostało: —
Akceptacja worsening: —""")

# position w data coordinates — top-left unit square
textlabel!(ax_trasa, 0.02, 0.98, obs_overlay;
    align = (:left, :top),
    fontsize = 12,
    background_color = (:black, 0.6),
    padding = (5, 5, 5, 5))
```

Alternatywa jeśli `textlabel!` ma problemy: `text!` z `:data` markerspace + ręczny `Rect2f` jako tło.
[CITED: docs.makie.org/stable/reference/plots/textlabel.html] — `background_color`, `padding`

### Pattern 9: Module Integration (VIZ-06)

```julia
# src/JuliaCity.jl — dodać TYLKO te dwie linie (reszta bez zmian):
include("wizualizacja.jl")   # using GLMakie jest WEWNĄTRZ wizualizacja.jl
# ...
export ..., wizualizuj       # dodać do istniejącej listy

# src/wizualizacja.jl — pierwsze linie:
using GLMakie                # jedyne miejsce w src/ z tym importem (VIZ-06)
using ProgressMeter
using GeometryBasics: Point2f
```

### Anti-Patterns to Avoid

- **`Observable{Any}` w closure:** Użyj zawsze `Observable{ConcreteType}` — np. `Observable(Vector{Point2f}())` zamiast `Observable(Any[])`. [CITED: pitfalls.md Pitfall 5]
- **`obs.val .= new_vec`:** In-place mutacja bez `notify` nie triggeruje callbacków. Użyj albo `obs[] = nowy_wektor` albo `obs.val = ...; notify(obs)`. [CITED: docs.makie.org/stable/explanations/observables.html]
- **`Makie.record()` bez ProgressMeter:** Blokuje REPL bez feedbacku; userzy myślą że crashed. Zawsze `Progress + next!`. [CITED: pitfalls.md Pitfall 6]
- **`using GLMakie` w kilku plikach:** Łamie VIZ-06 i utrudnia headless testing rdzenia.
- **`set_theme!` bez resetu:** Globalny efekt po powrocie z `wizualizuj()`. Używaj `with_theme`.
- **`Point2{Float64}` (Punkt2D) bezpośrednio w `lines!`:** Makie GPU pipeline preferuje `Point2f` (Float32). Konwertuj przez `Point2f.(vec)`.
- **`GLMakie.record()` z `display(fig)` wewnątrz callback:** Nie działa w CairoMakie; niepotrzebne w GLMakie (okno aktualizuje się automatycznie).
- **`using Makie` bez `using GLMakie`:** `Makie` samo w sobie nie daje okna GUI. `GLMakie` aktywuje backend.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MP4/GIF encoding | własny FFMPEG wrapper | `Makie.record(fig, path, iter; framerate=fps)` | Wbudowane w Makie; format z extensji; FFMPEG_jll transitive |
| Progress bar | własny `print("\r...")` | `ProgressMeter.Progress + next!` | Thread-safe; terminal-aware; ETA estimation built-in |
| Text background box | własny `poly!` + `text!` | `textlabel!(...)` | Wbudowane od Makie 0.22.5; padding, cornerradius, background_color |
| Reactive data binding | własny callback system | `Observable{T}` + `obs[] = val` | Makie dependency graph; single notify per assign; type-safe |
| FPS timer | `time()` co klatkę | Rolling window `fps_window = zeros(60)` + `1/(t_now - t_prev)` | Simple, allocation-free, stable rolling average |
| Layout columns | ręczne obliczenia pixel | `colsize!(fig.layout, 1, Relative(0.6))` | Auto-responsive do resize; composable z innymi layout constraints |

---

## Pitfall Mitigations

### Pitfall 5: Observable Update Storms
**Decision that resolves it:** D-05 (`KROKI_NA_KLATKE=50`) — tylko 1 Observable notify per 50 SA stepów.
**Additional mitigation:** Dla `obs_ene_historia` używamy mutacji `.val = push!(...)` + `notify(obs)` zamiast `obs[] = całkowity_wektor` (unika alokacji całego historii przy każdej klatce).
**Warning sign pattern:** Jeśli okno staje się "Not Responding" — `KROKI_NA_KLATKE` za małe lub brakuje `sleep(1/fps)`.

### Pitfall 6: `record()` Blocking
**Decision that resolves it:** D-09 (single entry point) + D-09's `@info` warning before `record()` + EKS-03 (ProgressMeter).
**Pattern:** `@info "Eksport do $sciezka — może potrwać kilka minut..."` + `Progress(n; desc="Eksport animacji: ")` + `next!(prog)` inside callback.
**Key fact:** `record()` w GLMakie aktualizuje okno podczas nagrywania — użytkownik widzi postęp wizualnie ORAZ pasek w terminalu.

### Pitfall 7: GLMakie Headless CI
**Decision that resolves it:** D-13 (hard-fail z polskim komunikatem) + D-14 (runtests.jl bez wizualizacji) + D-15 (CI bez zmian).
**Exception types to catch:** `GLFW.GLFWError` (jeśli dostępne) LUB `InitError` LUB catch-all na `sprint(showerror, e)` zawierające "GLFW"/"OpenGL"/"X11". Sprawdzanie po stringu jest robustne gdy `GLFW` nie jest eksportowane do scope'u.

### Pitfall 13: GC Pauses → Animation Stutter
**Mitigation:** `trasa_do_punkty()` alokuje jeden `Vector{Point2f}` per klatka — niezbędna allokacja. Overlay strings alokują `String` per klatka (niezbędne). Energia historia: `push!` na `.val` + `notify` zamiast `obs[] = cały_wektor`. `GC.gc(false)` co 100 klatek w export path (deterministyczne mini-GC).

### Pitfall 14: TTFP Surprise
**Decision that resolves it:** D-08 — `@info "Ładowanie GLMakie..."` przed `display(fig)` (lub przed `with_theme do`). Czas pierwszego ładowania GLMakie: 60-150s na zimnym REPL; po precompilation cache (Julia 1.9+): 5-15s.

---

## Key Research Findings

### Q1: Observable Architecture — Batching vs Per-Field

**Finding:** Makie 0.24 `obs[] = val` triggers callbacks synchronously. Dla 7-field overlay'u:
- **Opcja A (D-04 mandated):** Każde pole to osobny `Observable{String}`. Wymaga 7 `obs[] = val` per klatka — każde triggeruje rerender fragmentu. Potencjalnie 7x update storms.
- **Opcja B (zalecana optymalizacja):** Jeden `Observable{String}` z wieloliniowym stringiem (newline `\n` separator). Jeden notify per klatka. `textlabel!` renderuje multi-line text poprawnie.

D-04 mówi "każde pole wrap'owane w Observable{String}". Opcja B osiąga ten sam efekt przy mniejszym koszcie — `textlabel!(ax, pos, obs_multiline)` gdzie `obs_multiline = Observable("pole1\npole2\n...")`.

**Recommendation:** Użyj jednego `Observable{String}` dla całego bloku overlay (7 pól, separator `\n`). Minimalizuje liczbę notify per klatka do jednego.
[ASSUMED — interpretacja D-04 jako "każde pole to update-able" nie musi oznaczać osobny Observable per pole]

### Q2: Throttling Pattern — Live Path

**Finding:** Kanoniczny wzorzec potwierdzony:
```julia
while isopen(fig)
    for _ in 1:kroki_na_klatke
        symuluj_krok!(stan, params, alg)
    end
    obs_trasa[] = ...    # jeden update
    sleep(1/fps)         # yield do GLMakie event loop
end
```
`sleep(1/fps)` jest wymagane — bez niego GLMakie event loop nie otrzymuje czasu CPU i okno staje się "Not Responding". `yield()` samo w sobie za krótkie dla renderloop'u.
[CITED: discourse.julialang.org/t/renderloop-updates-in-glmakie-jl/114397]
[CITED: docs.juliahub.com/MakieGallery — "add a short sleep interval so that the display can refresh"]

### Q3: `Makie.record()` Semantics

**Finding:** API potwierdzone:
```julia
Makie.record(fig, "output.mp4", 1:n_klatek; framerate=30) do frame_i
    # frame_i to wartość z iteratora (tu: Int 1..n_klatek)
    # modyfikacje Observables tutaj stają się jedną klatką
end
```
- Callback otrzymuje wartość z iteratora (tu `Int`).
- Format wykrywany z extensji: `.mp4`, `.gif`, `.webm`, `.mkv` (domyślny).
- FFMPEG_jll transitive — nie dodawać jako direct dep.
- `framerate=fps` kontroluje playback FPS w pliku wynikowym.
- Callback jest synchroniczny; każde wywołanie = 1 klatka.

[CITED: docs.makie.org/stable/explanations/animation.html]

### Q4: ProgressMeter w `record()`

**Finding:** `Progress(n; desc="...", dt=0.5)` + `next!(prog)` wewnątrz callback działa poprawnie:
```julia
prog = Progress(n_klatek; desc="Eksport animacji: ", dt=0.5)
Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do i
    # ... SA steps + Observable update
    next!(prog)
end
finish!(prog)
```
`dt=0.5` — minimalna przerwa między aktualizacjami display (0.5s). Bez `dt` każde `next!()` emituje linię.
[CITED: github.com/timholy/ProgressMeter.jl — Progress() + next!() pattern]

### Q5: Polish Diacritics w Makie

**Finding:** Domyślny font Makie to **"TeX Gyre Heros Makie"** (loaded via FreeType.jl). Font ten pokrywa Latin Extended-A i Extended-B, co obejmuje wszystkie polskie znaki (ą ę ł ó ś ź ż ń ć).
Phase 1 D-21 zapewnia NFC encoding wszystkich źródeł — to eliminuje ryzyko "composed vs decomposed" glyph miss.
Wniosek: polskie diakrytyki renderują się poprawnie **bez żadnej dodatkowej konfiguracji fontu**.
[CITED: docs.makie.org/dev/explanations/fonts] — "TeX Gyre Heros Makie", FreeType.jl backend
[ASSUMED: Latin Extended coverage — docs nie podają explicit codepage coverage; weryfikacja wizualna rekomendowana]

### Q6: Theme Scoping — set_theme! vs with_theme

**Finding:** `with_theme(theme_dark()) do ... end` — scope-owana; automatycznie resetuje po wyjściu z bloku (nawet przy throw).
`set_theme!(theme_dark())` — globalna; persists po powrocie z `wizualizuj()`.
**Recommendation:** Używaj `with_theme` w `wizualizuj()` — nie zanieczyszcza globalnego stanu wywołującego.
[CITED: docs.makie.org/dev/explanations/theming/themes] — with_theme auto-resets

### Q7: NN Baseline Overlay — `:dash` linestyle

**Finding:** `lines!(ax, points; color=:gray, linestyle=:dash, alpha=0.3)` — potwierdzone:
- `:dash` jest jednym z 5 standardowych linestyle opcji (`:solid`, `:dot`, `:dash`, `:dashdot`, `:dashdotdot`).
- Działa w GLMakie 0.13.x — brak znanych regresji.
- `alpha` i `color` są niezależne; `color=(:gray, 0.3)` jako alternatywa dla osobnego `alpha=0.3`.
[CITED: docs.makie.org/stable/reference/plots/lines] — linestyle options

### Q8: Point2f Conversion

**Finding:** `Punkt2D = Point2{Float64}`. Makie GPU pipeline preferuje `Point2f = Point2{Float32}`.
**Konwersja:** `Point2f.(vec)` — broadcast alokuje nowy wektor. Dla N=1001 (1000 + cycle closure) ≈ 8 KB per frame — akceptowalne.
**Nie używaj:** `reinterpret(Point2f, vec)` — różny rozmiar bitu (Float64 vs Float32), nieprawidłowe.
**Pattern:** Funkcja `trasa_do_punkty(stan)::Vector{Point2f}` pre-alokuje z `undef` i wypełnia loopem — lepsza niż broadcast, ponieważ nie alokuje pośredniego `Vector{Punkt2D}`.
[CITED: discourse.julialang.org/t/glmakie-point2f-not-defined/84292] — Point2f type aliases

### Q9: `record()` File Extension Detection

**Finding:** **Automatyczne** — Makie wykrywa format z extensji pliku:
- `.mp4` → H.264/AVC przez FFMPEG_jll
- `.gif` → Animated GIF przez FFMPEG_jll
- `.webm` → VP8/VP9 przez FFMPEG_jll
- `.mkv` → Matroska (domyślny, brak konwersji)
Caller nie musi przekazywać dodatkowego `format=` parametru.
[CITED: docs.makie.org/stable/explanations/animation.html] — "determines output format from file extension"

### Q10: GLMakie Headless Exception Types

**Finding:** Konkretne typy wyjątków przy braku OpenGL/display:
- `GLFW.GLFWError` z `VERSION_UNAVAILABLE` (brak GPU/drivers)
- `InitError` owijający `GLFW.GLFWError` (przy `using GLMakie` failure)
- Wiadomości zawierają: `"X11: Failed to open display"`, `"GLX: Failed to create context"`, `"glfwInit failed"`

**Robustne catch:** Sprawdzaj `sprint(showerror, e)` zawierające "GLFW"/"OpenGL"/"X11"/"display" — działa nawet gdy `GLFW` nie jest w scope'ie (jest wewnątrz GLMakie, nie re-eksportowane).
[CITED: github.com/MakieOrg/Makie.jl/issues/1953] — GLFWError type on headless Ubuntu 22.04

### Q11: Project.toml / Manifest.toml Mechanics — CRITICAL BUG

**Finding:** Obecny `Project.toml` ma `GLMakie = "0.24"` w `[compat]` — **BŁĄD BLOKUJĄCY**.
GLMakie NIE używa numeracji Makie (0.24.x). GLMakie używa własnej numeracji:
- **GLMakie 0.13.10** pairs with **Makie 0.24.10**

Próba `Pkg.add("GLMakie")` z compat `"0.24"` daje:
`ERROR: Unsatisfiable requirements detected for package GLMakie: restricted to versions 0.24 — no versions left`

**Fix wymagany w Wave 0:**
```toml
[compat]
GLMakie = "0.13"      # NIE "0.24" — to jest wersja Makie, nie GLMakie
Makie = "0.24"        # PRAWIDŁOWE (Makie ma własną wersję 0.24.x)
ProgressMeter = "1"   # dodać nowy wpis
Observables = "0.5"   # już jest w [compat]
```

[VERIFIED: `julia -e "Pkg.add(\"GLMakie\")"` w czystym env → `GLMakie v0.13.10` zainstalowane]

### Q12: Type-Stability i Observable Closures

**Finding:** Pułapka `Observable{Any}` w zamknięciach:
```julia
# ZŁE — obs będzie Observable{Any} jeśli typ nie jest inferowany:
obs = Observable(nothing)
obs[] = Point2f(0, 0)  # teraz Any, nie Point2f

# DOBRE — zawsze podawaj konkretny typ:
obs = Observable(Point2f(0, 0))           # Observable{Point2f}
obs = Observable(Vector{Point2f}())       # Observable{Vector{Point2f}}
obs = Observable("start")                 # Observable{String}
```

Dla zmiennych przechwyconych w closure przez wizualizuj():
```julia
# Użyj let block lub Ref{T} dla mutowalnych skalarów
let obs_trasa = Observable(Vector{Point2f}()),
    obs_str   = Observable("Iteracja: 0")
    # ... closure tutaj widzi typed variables
end
```
[CITED: discourse.julialang.org/t/type-stability-in-closures/123227]
[CITED: github.com/JuliaLang/julia/issues/15276 — Core.Box pitfall]

### Q13: Module Integration — `using GLMakie` Placement

**Finding:** `using GLMakie` w top-level `src/wizualizacja.jl` (nie wewnątrz funkcji) jest **idiomatyczne i prawidłowe**. Julia ładuje moduł przy pierwszym `using JuliaCity` — stąd TTFP przy pierwszym uruchomieniu. Precompile cache (Julia 1.9+) redukuje to do sekund przy kolejnych uruchomieniach.

**VIZ-06 enforcement:** `using GLMakie` TYLKO w `wizualizacja.jl`. `JuliaCity.jl` robi tylko `include("wizualizacja.jl")` — nie importuje GLMakie bezpośrednio.

**Weryfikacja grep:** `grep -rl "using GLMakie" src/` powinno zwrócić tylko `src/wizualizacja.jl`.

### Q14: GLMakie Thread Safety

**Finding:** Oficjalna dokumentacja: *"GLMakie is not thread-safe! Makie functions to display in GLMakie or updates to Observables displayed in GLMakie windows from other threads may not work as expected or cause a segmentation fault."*

**Implikacja dla wizualizuj():** Cały kod GL musi działać na głównym wątku Julia. `wizualizuj()` blokuje główny wątek (live loop lub `record()` loop). `symuluj_krok!` jest sekwencyjne (Phase 2 D-09 — single master RNG), więc nie ma threading konfliktów.

**Nie używaj `@async`** dla Observable updates — ryzyko segfault.
[CITED: docs.makie.org/stable/explanations/backends/glmakie.html]

---

## Runtime State Inventory

Phase 3 jest greenfield (additive file addition, no rename/refactor). Sekcja pominięta.

---

## Common Pitfalls

### Pitfall A: GLMakie = "0.24" w [compat] blokuje instalację
**What goes wrong:** `Pkg.add("GLMakie")` zgłasza `Unsatisfiable requirements` bo GLMakie 0.24 nie istnieje.
**Why it happens:** STACK.md błędnie podaje `GLMakie 0.10.x` — to historyczna numeracja (przed scaleniem monorepo); obecna wersja to 0.13.x.
**How to avoid:** Wave 0 musi zmienić `GLMakie = "0.24"` na `GLMakie = "0.13"` w Project.toml [compat]. To blokuje wszystkie inne zadania.

### Pitfall B: `obs.val .= new_vec` bez `notify` — zamrożony ekran
**What goes wrong:** In-place mutacja `obs.val .= nowa_trasa` nie triggeruje Makie callbacks — ekran nie aktualizuje się.
**Why it happens:** `obs[] = val` to sugar dla `setindex!` który triggeruje; `.val` access to surowe pole, bez triggera.
**How to avoid:** Albo `obs[] = nowy_wektor` (triggeruje, alokuje referencję) albo `mutate!(obs.val); notify(obs)`.

### Pitfall C: `sleep()` za długie w live loop → laggy UI
**What goes wrong:** `sleep(1/fps)` przy `fps=30` daje budżet 33ms per klatka. Jeśli `kroki_na_klatke=50` stepów SA + Observable update + string formatting przekracza 33ms, animacja jest wolniejsza niż target FPS.
**Why it happens:** `symuluj_krok!` to ~1-5µs per call; 50 stepów ≈ 50-250µs — bezpieczne. Bottleneck prawdopodobnie TTFP przy pierwszej klatce.
**How to avoid:** `KROKI_NA_KLATKE=50` z `fps=30` daje 50_000/50 = 1000 klatek × 33ms = 33s animacji — mieści się w budżecie.

### Pitfall D: `Makie.record()` nadpisuje plik bez ostrzeżenia (jeśli nie sprawdzimy)
**What goes wrong:** Bez `isfile()` check, ponowne wywołanie `wizualizuj(...; eksport="demo.mp4")` cicho nadpisuje poprzedni plik.
**How to avoid:** D-10 mandates `isfile(sciezka) && error(...)` — już w CONTEXT.md.

### Pitfall E: `with_theme` wewnątrz `try/catch` — theme nie resetuje się przy błędzie w środku catch
**What goes wrong:** Jeśli GLMakie init rzuca, jesteśmy `catch` bloku — ale `with_theme` blok mógł nie zacząć się jeszcze.
**How to avoid:** `try/catch` wrapper na ZEWNĄTRZ `with_theme do`. Hierarchia: outer try/catch → with_theme do → display(fig) → loop.

### Pitfall F: `textlabel!` position w pixel vs data coordinates
**What goes wrong:** Przy `markerspace=:pixel` (domyślne), `autolimits!` może przyciąć overlay.
**How to avoid:** Użyj `markerspace=:data` lub podaj pozycję w data space (np. `(0.02, 0.98)` dla unit square [0,1]²) — ax_trasa już ma `xlimits=[0,1], ylimits=[0,1]`.

---

## Code Examples

### Pełna sygnatura funkcji publicznej

```julia
# Source: 03-CONTEXT.md — Claude's Discretion (canonical signature)
"""
    wizualizuj(stan, params, alg; liczba_krokow, fps, kroki_na_klatke, eksport)

Animuje proces wyżarzania TSP w oknie GLMakie lub eksportuje animację do pliku.

# Argumenty
- `stan::StanSymulacji` — zainicjowany stan SA (po `inicjuj_nn!` i ustawieniu `stan.temperatura`)
- `params::Parametry` — parametry symulacji
- `alg::Algorytm` — algorytm (np. `SimAnnealing`)

# Słowa kluczowe
- `liczba_krokow::Int=params.liczba_krokow` — liczba kroków SA do wykonania
- `fps::Int=30` — klatki na sekundę (live i eksport)
- `kroki_na_klatke::Int=50` — kroków SA między aktualizacjami Observables (throttling)
- `eksport::Union{Nothing,String}=nothing` — ścieżka do pliku MP4/GIF (lub `nothing` dla live)

# Zachowanie
- `eksport=nothing`: otwiera okno GLMakie, animuje w czasie rzeczywistym, czeka na zamknięcie
- `eksport="ścieżka.mp4"`: zapisuje animację (blokujące; postęp w terminalu)

Wymaga OpenGL. Na headless CI rzuci błąd z polską wiadomością diagnostyczną.
"""
function wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
                    liczba_krokow::Int=params.liczba_krokow,
                    fps::Int=30,
                    kroki_na_klatke::Int=50,
                    eksport::Union{Nothing,String}=nothing)::Nothing
```

### Inicjalizacja figure i osi

```julia
# Source: docs.makie.org/stable/reference/blocks/axis — colsize!, AxisAspect
fig = Figure(size=(1400, 700))
ax_trasa = Axis(fig[1, 1];
    title="Trasa TSP — błona mydlana (N=$(length(stan.punkty)))",
    xlabel="Współrzędna X", ylabel="Współrzędna Y",
    aspect=AxisAspect(1))
ax_energia = Axis(fig[1, 2];
    title="Energia trasy vs iteracja",
    xlabel="Iteracja", ylabel="Energia (długość trasy)")
colsize!(fig.layout, 1, Relative(0.6))   # lewy panel 60%, prawy 40%
```

### Observable update — trasa + energia historia

```julia
# Source: docs.makie.org/stable/explanations/observables.html
# Inicjalizacja
obs_trasa   = Observable(trasa_do_punkty(stan))    # Observable{Vector{Point2f}}
obs_historia = Observable(Point2f[(0f0, Float32(stan.energia))])  # Observable{Vector{Point2f}}

# Podłączenie do plotów
lines!(ax_trasa, obs_trasa; color=:white, linewidth=1.5)
scatter!(ax_trasa, obs_trasa; color=:cyan, markersize=5)
lines!(ax_energia, obs_historia; color=:orange, linewidth=2)

# Update per klatka (wewnątrz loop)
obs_trasa[] = trasa_do_punkty(stan)                # alokuje Vector{Point2f}
push!(obs_historia.val, Point2f(stan.iteracja, stan.energia))  # in-place
notify(obs_historia)                               # ręczny trigger po .val mutation
```

### ProgressMeter z record()

```julia
# Source: github.com/timholy/ProgressMeter.jl
using ProgressMeter
n_klatek = liczba_krokow ÷ kroki_na_klatke
prog = Progress(n_klatek; desc="Eksport animacji: ", dt=0.5, barlen=40)
Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do frame_i
    for _ in 1:kroki_na_klatke
        stan.iteracja < liczba_krokow && symuluj_krok!(stan, params, alg)
    end
    obs_trasa[] = trasa_do_punkty(stan)
    push!(obs_historia.val, Point2f(stan.iteracja, stan.energia))
    notify(obs_historia)
    next!(prog)
end
finish!(prog)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-----------------|--------------|--------|
| GLMakie.jl osobne repo | GLMakie jest subdirectory monorepo Makie.jl | ~2022 | Wersja GLMakie ≠ wersja Makie; compat musi używać GLMAKIE wersji (0.13), nie Makie (0.24) |
| `AbstractPlotting.@lift` makro | `@lift $obs` / `lift(f, obs)` | Makie 0.18+ | Stare tutoriale używają `AbstractPlotting` — ignoruj |
| `record_events` / frame buffering | `Makie.record(fig, path, iter; framerate=fps) do i` | Makie 0.20+ | Prostsze API; auto format detection z extensji |
| Oddzielny `text!` + `poly!` dla tła | `textlabel!(pos, text; background_color=...)` | Makie 0.22.5 | Wbudowane tło tekstu |
| `Observables.jl` standalone | `Observables.jl` zintegrowane z Makie | Makie 0.15+ | `Observable` dostępne przez `using Makie`/`using GLMakie` |
| `scene, layout = layoutscene()` | `fig = Figure(); Axis(fig[1,1])` | Makie 0.18+ | Nowe API Figure/Axis; stare `scene` podejście deprecated |

**Deprecated/outdated:**
- `AbstractPlotting`: stary namespace, zastąpiony przez `Makie`
- `GLMakie.AbstractScreen`: używaj `display(fig)` lub `GLMakie.Screen()`
- `Record(fig, path) do; push frame manually`: nowy `record(fig, path, iter; framerate) do i` jest prostszy

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | "TeX Gyre Heros Makie" font pokrywa wszystkie polskie znaki (ą ę ł ó ś ź ż ń ć) | Q5: Polish diacritics | Tofu/missing glyphs w overlay; fixable przez explicit font specification (np. DejaVu Sans) |
| A2 | `isopen(fig)` jako warunek stopu live loop działa gdy user zamknie okno | Pattern 4: Live Loop | Loop nie zatrzymuje się; użyj `events(fig).window_open` albo `display(fig)` z `wait()` |
| A3 | Jeden `Observable{String}` dla całego 7-pola overlay (zamiast 7 osobnych) jest poprawną interpretacją D-04 | Q1: Observable Architecture | D-04 może wymagać osobnych Observables per pole — zmiana architektury overlay |
| A4 | `Point2f.(nn_points)` działa gdy `nn_points::Vector{Punkt2D}` (Point2{Float64}) | Q8: Point2f conversion | MethodError jeśli broadcast nie jest zdefiniowany; użyj `[Point2f(p) for p in nn_points]` jako fallback |
| A5 | `textlabel!` dostępny w Makie 0.24 (dodany w 0.22.5) | Pattern 8: textlabel | Jeśli nie dostępny: użyj `text!` + `:data` markerspace (brak tła ale działa) |

---

## Open Questions

1. **`isopen(fig)` vs `events(fig).window_open[]` jako stop condition**
   - Znamy: obydwie mają sens; `isopen(scene)` istnieje w Makie API
   - Niejasne: czy `isopen(Figure)` jest wspierane czy tylko `isopen(Scene)`?
   - Rekomendacja: sprawdzić w implementacji; fallback: `events(fig).window_open[]`

2. **Freeze last frame w record() gdy SA kończy wcześniej**
   - Znamy: `sa_zakonczono = Ref(false)` + brak `symuluj_krok!` gdy true; Observable nie zmienia się
   - Niejasne: czy Makie.record() wymaga że Observable MUSI się zmienić per klatka, czy może pozostać statyczne?
   - Rekomendacja: Makie renderuje aktualny stan figure per klatka — statyczny state = zamrożona klatka. Bezpieczne.

3. **`obs_ene_historia` type — `Point2f` vs oddzielne `x::Vector{Float32}` i `y::Vector{Float32}`**
   - Znamy: `lines!(ax, obs)` gdzie `obs::Observable{Vector{Point2f}}` działa
   - Niejasne: czy `lines!(ax, x_obs, y_obs)` (dwa osobne Observable) byłoby wydajniejsze?
   - Rekomendacja: użyj `Vector{Point2f}` — jeden Observable, spójny z trasą pattern; unika x/y desync

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Julia | Runtime | ✓ | 1.12.6 | — |
| GLMakie | VIZ-01..07 | ✓ (w global env) | 0.13.10 | Brak w v1 (D-13) |
| Makie | Transitywnie via GLMakie | ✓ | 0.24.10 | — |
| Observables | Reaktywne Observable{T} | ✓ | 0.5.5 | — |
| ProgressMeter | EKS-03 | ✓ | 1.11.0 | — |
| FFMPEG_jll | EKS-01, EKS-02 (via Makie) | ✓ (transitive) | latest | — |
| OpenGL 3.3+ | GLMakie renderloop | ✓ (Windows 11 z GPU) | — | N/A — D-13 hard-fail |

**Missing dependencies with no fallback:** Brak (wszystkie dostępne na dev machine Windows 11).

**Note:** GLMakie + Makie NIE mogą być dodane do projektu bez najpierw naprawienia `[compat]`. Patrz Q11 / Pitfall A.

---

## Validation Architecture

`nyquist_validation: false` w config.json — sekcja skrócona do manualnych checków.

**Manual smoke tests (dev machine):**
- `wizualizuj(stan, params, alg; liczba_krokow=200)` — okno GLMakie otwiera się, animacja widoczna, polskie etykiety czytelne, diakrytyki OK.
- `wizualizuj(stan, params, alg; liczba_krokow=200, eksport="test.mp4")` — plik `test.mp4` powstaje, ProgressMeter widoczny w terminalu.
- `wizualizuj(stan, params, alg; eksport="test.mp4")` — drugi call → error z polską wiadomością (D-10).

**Automatable guards (grep-level, bez OpenGL):**
```bash
# VIZ-06: tylko wizualizacja.jl importuje GLMakie
grep -rl "using GLMakie" src/
# Oczekiwany output: tylko src/wizualizacja.jl

# LANG-01/02: brak angielskich napisów w UI strings
grep -n '"[A-Z][a-z]* ' src/wizualizacja.jl | grep -v "#\|error("
```

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1`.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth in local CLI tool) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | partial | `eksport` path: `isfile()` check; no path traversal risk (local filesystem, user-provided) |
| V6 Cryptography | no | — |

**Relevant threat patterns:**
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Plik eksportu nadpisuje istniejący | Tampering | D-10: `isfile()` check + error przed `record()` |
| `/tmp/anim.mp4` predictable on shared host | Disclosure | User podaje explicit path; brak tempname() auto-generation (YAGNI per D-10) |

No high-severity security concerns for this local-only visualization module.

---

## Sources

### Primary (HIGH confidence)
- [docs.makie.org/stable/explanations/animation.html](https://docs.makie.org/stable/explanations/animation.html) — `record()` API, FFMPEG_jll, format detection
- [docs.makie.org/stable/explanations/observables.html](https://docs.makie.org/stable/explanations/observables.html) — `obs[] = val` vs `notify(obs)`, `.val` mutation
- [docs.makie.org/stable/reference/blocks/axis](https://docs.makie.org/stable/reference/blocks/axis) — AxisAspect(1), colsize!, Relative()
- [docs.makie.org/stable/reference/plots/textlabel.html](https://docs.makie.org/stable/reference/plots/textlabel.html) — `textlabel!` background_color, padding (Makie 0.22.5+)
- [docs.makie.org/stable/reference/plots/lines](https://docs.makie.org/stable/reference/plots/lines) — linestyle=:dash confirmed
- [docs.makie.org/stable/explanations/backends/glmakie.html](https://docs.makie.org/stable/explanations/backends/glmakie.html) — thread-safety warning, headless CI
- [docs.makie.org/dev/explanations/fonts](https://docs.makie.org/dev/explanations/fonts) — "TeX Gyre Heros Makie", FreeType.jl
- [docs.makie.org/dev/explanations/theming/themes](https://docs.makie.org/dev/explanations/theming/themes) — with_theme vs set_theme!
- [github.com/timholy/ProgressMeter.jl](https://github.com/timholy/ProgressMeter.jl) — `Progress(n; desc=..., dt=...)` + `next!()` + `finish!()`
- [github.com/MakieOrg/Makie.jl/issues/1953](https://github.com/MakieOrg/Makie.jl/issues/1953) — GLFWError(VERSION_UNAVAILABLE) on headless
- Julia registry (verified via `julia -e "Pkg.add(\"GLMakie\")"`) — GLMakie 0.13.10, Makie 0.24.10, Observables 0.5.5, ProgressMeter 1.11.0

### Secondary (MEDIUM confidence)
- [discourse.julialang.org/t/renderloop-updates-in-glmakie-jl/114397](https://discourse.julialang.org/t/renderloop-updates-in-glmakie-jl/114397) — `sleep(1/fps)` + render_tick pattern
- [discourse.julialang.org/t/displaying-figure-while-recording-animation-using-makie-record/110269](https://discourse.julialang.org/t/displaying-figure-while-recording-animation-using-makie-record/110269) — display(fig) before record() pattern
- [discourse.julialang.org/t/type-stability-in-closures/123227](https://discourse.julialang.org/t/type-stability-in-closures/123227) — let block closure type stability
- Makie docs.juliahub.com/MakieGallery — animation loop with sleep(1/fps)

### Tertiary (LOW confidence — flag for validation)
- `isopen(fig)` jako stop condition — brak oficjalnej dokumentacji potwierdzającej dla Figure (vs Scene)

---

## Metadata

**Confidence breakdown:**
- GLMakie/Makie/Observables/ProgressMeter versions: HIGH — verified against Julia registry
- record() API: HIGH — cited from official Makie animation docs
- Observable patterns: HIGH — cited from official Makie observables docs
- Polish diacritics font coverage: MEDIUM — font name confirmed; codepage coverage assumed
- live renderloop sleep() pattern: MEDIUM — multiple Discourse confirmations
- GLFWError exception catching: MEDIUM — one GitHub issue; string-match fallback robust
- textlabel! availability in 0.24: HIGH — added in 0.22.5 per search result

**Research date:** 2026-04-30
**Valid until:** 2026-07-30 (Makie 0.24 stable; 30-day validity for GLMakie version)
