# Phase 3: Visualization & Export - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 dostarcza `src/wizualizacja.jl` — funkcję publiczną `wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm; liczba_krokow::Int, fps::Int=30, eksport::Union{Nothing,String}=nothing)` która buduje okno GLMakie z **dual-panel layoutem** (lewy panel: 2D trasa SA z punktami, linią cyklu i NN baseline overlay; prawy panel: wykres energia(iteracja) w czasie rzeczywistym), animuje proces zaciskania trasy SA z throttled updates (`KROKI_NA_KLATKE=50`), pokazuje rich overlay tekstowy (iter, energia, T, alfa, FPS, ETA, accept rate) — wszystko po polsku z poprawnym renderowaniem diakrytyków, w `theme_dark()` z aspect 1:1. Eksport MP4/GIF realizowany przez `Makie.record(...)` z extension detection, `ProgressMeter.jl` jako wskaźnik postępu, twardy error gdy plik docelowy istnieje, brak fallbacku na CairoMakie (hard-fail z czytelną wiadomością gdy GLMakie nie startuje).

`src/wizualizacja.jl` jest **jedynym** plikiem w `src/` importującym `using GLMakie` (VIZ-06 LOCKED). Core (`punkty.jl`, `energia.jl`, `baselines.jl`, `algorytmy/`, `typy.jl`) pozostaje pure-headless — `runtests.jl` nie testuje wizualizacji.

**Pokrywa REQ-IDs:** VIZ-01..07, EKS-01..04 (11 wymagań).

</domain>

<decisions>
## Implementation Decisions

### Layout & Visual Design (area A)

- **D-01: Dual-panel layout** — `Figure` z dwoma osobnymi `Axis`. Lewy panel (`ax_trasa`): 2D punkty + linia cyklu Hamiltona + NN baseline overlay. Prawy panel (`ax_energia`): linia energia(iteracja) aktualizowana w czasie rzeczywistym. Layout: `fig[1,1] = ax_trasa`, `fig[1,2] = ax_energia`; szerokość prawego panelu ~40-50% lewego.
- **D-02: NN baseline jako szara przerywana linia** — renderowana raz przed startem SA jako overlay na `ax_trasa`: `lines!(ax_trasa, nn_points; color=:gray, linestyle=:dash, alpha=0.3)`. Wizualnie demonstruje "od czego startujemy" i "bicie baseline'u" (Roadmap SC #4 erratum z planu 02-14: ratio ≤ 0.95).
- **D-03: Dark theme + aspect 1:1** — `set_theme!(theme_dark())` przed budową figure (lub `with_theme(theme_dark())` dla scope'owej zmiany). `ax_trasa.aspect = AxisAspect(1)` — odpowiada domenie [0,1]² unit square.
- **D-04: Rich overlay tekstowy (7 pól)** — pojedynczy `text!(ax_trasa, ...)` w lewym górnym rogu lewego panelu, monospace font, semitransparent background. Pola po polsku:
  - `Iteracja: {stan.iteracja}`
  - `Energia: {round(stan.energia, digits=4)}`
  - `Temperatura: {round(stan.temperatura, digits=6)}`
  - `Alfa: {alg.alfa}` (constant, ale obecny dla pełnego obrazu)
  - `FPS: {live_fps_estimate}` (rolling avg z N=60 ostatnich klatek)
  - `Pozostało: {ETA_w_sekundach}` (ekstrapolacja z FPS + remaining steps)
  - `Akceptacja worsening: {accept_rate * 100}%` (rolling window 1000 kroków)
  Każde pole wrap'owane w `Observable{String}` aby Makie wyłapywał update'y bez pełnego re-rendera.

### Animation Rhythm & UX (area B)

- **D-05: `KROKI_NA_KLATKE = 50` default** (per VIZ-05 ≥ 10). Update Observable raz na 50 SA kroków. Dla `liczba_krokow=50_000` daje 1000 klatek = 33s @30fps — sensowny demo length. Parametr publiczny w sygnaturze `wizualizuj(...; kroki_na_klatke::Int=50)`.
- **D-06: Freeze + "GOTOWE" overlay po zakończeniu SA** — gdy SA zakończy się (`stan.iteracja >= liczba_krokow` lub patience stop z `uruchom_sa!`), ostatnia klatka pozostaje wyrenderowana, dodatkowy `text!` overlay: `"GOTOWE — ratio: {round(stan.energia/energia_nn, digits=4)}"`. Window pozostaje otwarty; user zamyka ręcznie. Brak auto-close, brak loop replay.
- **D-07: Interactive Makie controls (default)** — zoom kółkiem myszy, pan przez drag, reset przez Ctrl+R. Brak override'u Makie defaults. `DataInspector` NIE włączany (zbędny dla N=1000 punktów bez metadata).
- **D-08: TTFP grace overlay** — przed `display(fig)` wypisać `@info "Ładowanie GLMakie (pierwsze uruchomienie może trwać 60+ s — Pitfall 14)..."`. Bezpośrednio po `display(fig)` — `@info "Wizualizacja gotowa, rozpoczynam symulację..."`. Mitigacja Pitfall 14 (sysimage trap rejected — żadnego PackageCompiler w v1).

### Export Behavior (area C)

- **D-09: Single API entry point — `wizualizuj(...; eksport=path)`** (per VIZ-01). Branch:
  - `eksport === nothing` → `display(fig)` + manualny renderloop (pętla SA z throttled Observable updates, `sleep(1/fps)` między klatkami).
  - `eksport isa String` → `Makie.record(fig, eksport, 1:n_klatek; framerate=fps)` w blocking trybie. Frame callback wykonuje `KROKI_NA_KLATKE` SA stepów + Observable update. ProgressMeter render w terminalu.
  Brak split functions (`eksportuj_mp4()` etc.) — Pitfall 6 mitigated przez progres bar + clear `@info` message przed startem record (`"Eksport do {path} — może potrwać kilka minut, terminal nie reaguje, postęp poniżej:"`).
- **D-10: File-exists policy — twardy error** — przed `Makie.record(...)`, sprawdź `isfile(eksport)`. Gdy istnieje, rzuć `error("Plik '$eksport' już istnieje. Usuń go ręcznie lub wybierz inną nazwę pliku.")`. Brak `nadpisz::Bool` kwarg w v1 (KISS — zgodne z YAGNI).
- **D-11: FPS unified — `fps` arg dla live i eksport** (default 30). Brak osobnego `eksport_fps`. Reasoning: jeden parametr = mniej API surface, łatwiej tłumaczyć.
- **D-12: Eksport długość = `liczba_krokow / KROKI_NA_KLATKE` klatek** — czyli dla `liczba_krokow=50_000`, `KROKI_NA_KLATKE=50` → 1000 klatek = 33s @30fps. Reprodukowalny czas filmu. Jeśli SA hits patience early (`uruchom_sa!` zwróci wcześnie), pozostałe klatki pokazują freeze ostatniego stanu (recovery via `if stan.iteracja >= liczba_krokow break end` w renderloopie ALE record wymaga deterministycznego frame count → freeze last frame przez kontynuację Observable update bez SA stepów).

### Headless / Failure Mode (area D)

- **D-13: GLMakie hard-fail z czytelną polską wiadomością** — gdy `using GLMakie` lub `display(fig)` rzuci ze względu na brak OpenGL/displayu, `wizualizuj()` ma top-level `try/catch` który catchuje `GLMakie`-related errors i re-rzuca jako:
  ```
  error("GLMakie wymaga aktywnego kontekstu OpenGL. Brak displayu? Spróbuj `xvfb-run -a julia ...` na Linuksie albo uruchom lokalnie z GUI. Headless cloud (CI, Docker bez X) NIE jest wspierany w wersji v1.")
  ```
  Brak CairoMakie fallback w v1 (Pitfall 7 świadomie rejected — visualization-on-CI nie jest w scope).
- **D-14: `runtests.jl` NIE testuje wizualizacji** — testset suite (Phase 2: 222 PASS) pozostaje pure-headless. `src/wizualizacja.jl` walidowana ręcznie na developer machine + Phase 4 `examples/podstawowy.jl` jako manual smoke test. Brak `@testset "wizualizacja smoke"` w `test/`.
- **D-15: GitHub Actions CI bez GLMakie** — obecny matrix (1.10/1.11/1.12 × ubuntu/win/macos) pozostaje. Phase 3 testy = obecny suite. Phase 4 może opcjonalnie dodać Linux+xvfb step dla README demo eksportu (`examples/eksport_mp4.jl` → artifact MP4) — ale to deferred do Phase 4 discussion.

### Claude's Discretion

User nie wybrał szczegółów estetycznych (kolory, fonty, padding) — Claude działa po Makie defaults z dark theme:
- **Kolor punktów** (`scatter!`): jednolity, z palety dark theme (np. cyan/light blue). Bez gradientów temperatura→energia (deferred).
- **Kolor linii trasy** (`lines!`): jednolity, kontrastowy do tła (np. white/light yellow). Bez alpha-blending starych krawędzi.
- **Font overlay'u**: GLMakie default monospace dla wartości numerycznych (FPS, ETA czytelne) + default sans-serif dla etykiet polskich. Diakrytyki (ąęłńóśźż) testowane w Phase 1 D-21 (encoding hygiene NFC) — działają out-of-the-box.
- **Margin/padding** w `Figure`: Makie defaults; ewentualne tweaki w plan execution gdy okaże się że overlay nakłada się na trasę.
- **Position overlay'u**: top-left lewego panelu (`align=(:left, :top)` na `text!`), z padding ~10px od krawędzi.
- **Rozmiar punktów scatter**: empirycznie ustalony dla N=1000 (prawdopodobnie `markersize=4-6` w ekranowych pixelach). Adjustable w plan execution.
- **Linia spadku energii** (prawy panel): grubość 2px, kolor kontrastowy do dark theme.
- **Sygnatura kompletna** dla planu: `wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm; liczba_krokow::Int=params.liczba_krokow, fps::Int=30, kroki_na_klatke::Int=50, eksport::Union{Nothing,String}=nothing)::Nothing`. `liczba_krokow` default'uje do `params.liczba_krokow` (DRY); może być nadpisany dla custom demo lengths.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level decisions
- `.planning/PROJECT.md` — Core Value ("wizualnie przekonująca heurystyka"), constraints (Polish UI, GLMakie tech stack), Active Requirements (VIZ + EKS)
- `.planning/REQUIREMENTS.md` §"Visualization (VIZ-01..07)" + §"Export (EKS-01..04)" — 11 REQ-IDs locked dla Phase 3
- `.planning/ROADMAP.md` Phase 3 — Goal, Success Criteria 1–5, dependency on Phase 2 (`StanSymulacji`, `symuluj_krok!`, `inicjuj_nn!`, `trasa_nn`)

### Stack & technology
- `.planning/research/STACK.md` §"Recommended Stack" (rows: GLMakie, Makie, FFMPEG_jll, GeometryBasics, Observables) — versions HIGH confidence
- `.planning/research/STACK.md` §"What NOT to Use" — explicit reject CairoMakie/WGLMakie/Plots.jl jako primary; `FFMPEG_jll` NIE direct dep (transitive)
- `.planning/research/STACK.md` §"Version Compatibility" — Makie 0.24.x ↔ GLMakie 0.10.x ↔ Observables 0.5.x ↔ GeometryBasics 0.5.x

### Pitfalls (anti-patterns explicitly addressed by D-01..D-15)
- `.planning/research/PITFALLS.md` Pitfall 5 — Observable update storms → mitigated przez D-05 (`KROKI_NA_KLATKE=50`) + single `Observable{Vector{Point2f}}`
- `.planning/research/PITFALLS.md` Pitfall 6 — `record()` synchronous behavior → mitigated przez D-09 (single API + ProgressMeter + clear `@info`)
- `.planning/research/PITFALLS.md` Pitfall 7 — GLMakie headless CI → świadomie rejected przez D-13/D-14/D-15 (no fallback w v1)
- `.planning/research/PITFALLS.md` Pitfall 14 — sysimage trap → mitigated przez D-08 (TTFP message), no PackageCompiler w v1

### Carry-forward dependencies (Phase 1 + 2)
- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` D-21 — encoding hygiene (NFC normalized, BOM-free) → Polish diakrytyki w `text!` overlay'ach
- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` D-23 — ASCII-only file names → `wizualizacja.jl` (nie `wizualizacja-glmakie.jl`)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` D-06 — `StanSymulacji` shape LOCKED → wizualizacja konsumuje stan jako READ-ONLY (poza `symuluj_krok!` mutating); brak nowych pól
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` D-08 — Energy cache pattern → wizualizacja czyta `stan.energia` (nie wywoluje `oblicz_energie` per frame)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` "D-03 erratum (plan 02-14)" — TEST-05 baseline-beat ratio 0.9408; NN baseline overlay (D-02) ma sens edukacyjny

### Makie official docs (LIVE during research/planning)
- https://docs.makie.org/stable/explanations/animation/ — `record()` API, FFMPEG_jll, frame loop pattern
- https://docs.makie.org/dev/explanations/observables — Observable update mechanics
- https://docs.makie.org/stable/reference/blocks/axis — `Axis`, `AxisAspect`, layout patterns
- https://docs.makie.org/stable/reference/plots/text — `text!`, alignment, font, monospace

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`src/typy.jl::StanSymulacji{R}`** — pola `trasa::Vector{Int}` (permutacja 1:n), `D::Matrix{Float64}`, `energia::Float64`, `iteracja::Int`, `temperatura::Float64`. Wizualizacja czyta wszystkie te pola po każdym SA stepie. Brak nowych pól w `StanSymulacji` (Phase 1 D-06 LOCKED, Phase 2 D-06 carry-forward).
- **`src/punkty.jl::Punkt2D = Point2{Float64}`** — już GeometryBasics-friendly (zaimportowane jako `using GeometryBasics: Point2`). Konwersja do `Point2f` (Float32 dla Makie GPU pipeline) przez `Point2f.(stan.punkty)` lub `convert.(Point2f, stan.punkty)`.
- **`src/algorytmy/simulowane_wyzarzanie.jl::symuluj_krok!`** — zero-alloc (TEST-03 PASS), bezpieczny do `KROKI_NA_KLATKE=50` razy per frame w renderloopie bez GC pressure.
- **`src/baselines.jl::trasa_nn(D; start=1)::Vector{Int}`** — pure, used dla NN baseline overlay (D-02). Wizualizacja oblicza NN tour raz przed startem SA: `nn = trasa_nn(stan.D)`, potem renderuje jako szara przerywana linia (`lines!(ax_trasa, [stan.punkty[i] for i in nn]; color=:gray, linestyle=:dash, alpha=0.3)`).
- **`src/baselines.jl::inicjuj_nn!(stan)`** — caller wywołuje przed `wizualizuj()` (zgodnie z TEST-05 fixture pattern); wizualizacja zakłada `stan.trasa` jest valid Hamilton cycle.

### Established Patterns

- **`module JuliaCity` z `include("...")`-d files** — `src/JuliaCity.jl` doda `include("wizualizacja.jl")` + `export wizualizuj`. Phase 1 D-06 architecture preserved.
- **ASCII-only identifiers, Polish docstrings + komentarze** — Phase 1 LANG-01 (twardy wymóg) + D-23 file names. `wizualizuj()` docstring po polsku, kod identyfikatory typu `kroki_na_klatke`, `liczba_krokow` (już istniejące w Phase 2 `Parametry`).
- **Type stability rygorystyczne** — TEST-07 JET 4/4 PASS w Phase 2. Wizualizacja wprowadza Observables → Pitfall 5 closure boxing risk. Plan musi zaadresować: nie używać `Observable{Any}`, używać konkretnych typów (`Observable{Vector{Point2f}}`, `Observable{String}` dla overlay'u).
- **Dwustopniowe API public/internal** — `wizualizuj()` jest public (eksportowane z module); pomocnicze funkcje (np. `_render_overlay`, `_setup_figure`) prefiksowane `_` jako convention dla "internal".

### Integration Points

- **`src/JuliaCity.jl`** — dodać:
  ```julia
  using GLMakie       # tylko TUTAJ — narusza wzorzec? NIE: wizualizacja.jl re-eksportuje
  ```
  ALE per VIZ-06 — `using GLMakie` ma być TYLKO w `src/wizualizacja.jl`. Więc `JuliaCity.jl` robi `include("wizualizacja.jl")` i `export wizualizuj`; samo `using GLMakie` jest wewnątrz `wizualizacja.jl` (top-level w pliku, nie module).
- **`Project.toml` [deps]** — Phase 3 doda 5 nowych deps:
  - `GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"` (compat: `"0.10"`)
  - `Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"` (compat: `"0.24"`)
  - `Observables = "510215fc-4207-5dde-b226-833fc4488ee2"` (compat: `"0.5"`)
  - `ProgressMeter = "92933f4c-e287-5a05-a399-4b506db050ca"` (compat: `"1.10"` — najnowsza stabilna)
  - `GeometryBasics` już jest w deps z Phase 1 (compat: `"0.5"`).
  - `FFMPEG_jll` NIE direct dep (transitive via Makie — zgodnie z STACK.md Pitfall ostatni rząd "What NOT to Use").
- **`Manifest.toml`** — `Pkg.add(["GLMakie", "Makie", "Observables", "ProgressMeter"])` triggeruje regeneration; ~50+ transitive deps (FreeType, FFMPEG_jll, ColorTypes, etc.). Manifest commitowany (PROJECT D-25: aplikacja).
- **Public API rozszerzone**: `wizualizuj` dodane do `export` listy w `src/JuliaCity.jl` linii 41-45.
- **Brak modyfikacji istniejących plików** w `src/{punkty.jl, energia.jl, baselines.jl, algorytmy/, typy.jl}` — pure additive change. Phase 2 PHASE COMPLETE marker preserved.

</code_context>

<specifics>
## Specific Ideas

- **"Trasa zaciska się jak bańka mydlana"** (PROJECT.md core value) — animacja powinna wizualnie sugerować to. KROKI_NA_KLATKE=50 + 2-opt reverse'y w SA daje efekt "krawędzi zacieskających się" naturalnie (zauważalne pojedyncze swap'y, nie chaotyczny "skok"). Dual-panel (D-01) pozwala obserwować "zaciskanie" wizualnie + "spadek energii" matematycznie jednocześnie — edukacyjne.
- **README-friendly demo target**: 33s @30fps MP4 (`liczba_krokow=50_000, KROKI_NA_KLATKE=50, fps=30`) — konkretny target dla Phase 4 eksportu do `assets/demo.mp4`. Plan może embedować to jako standardowy `examples/eksport_mp4.jl`.
- **"GOTOWE"** overlay (D-06) — krótkie polskie słowo, widoczne, oznacza koniec animacji; alternative "ZAKOŃCZONE" za długie.
- **TEST-05 ratio 0.9408** (Phase 2 plan 02-14) — overlay D-04 może pokazywać `Ratio vs NN: {energia/energia_nn}` jako 8. pole? **Decyzja: NIE — ratio liczy się tylko na końcu (potrzebny `energia_nn` jako parametr/argument)**. Dla samej wizualizacji nieistotne; "GOTOWE" overlay (D-06) pokazuje ratio na końcu.

</specifics>

<deferred>
## Deferred Ideas

- **CairoMakie backend abstraction dla headless CI/cloud rendering** — D-13 świadomie rejected. Może być dodane w v2 jeżeli pojawi się use case (cloud-rendered MP4 dla web demo, headless GitHub Actions artifact).
- **Color gradients (temperatura → energia mapping na punktach)** — odroczone, default Makie kolory wystarczą dla v1 visual. Pomyślne dodanie w v2 wymagałoby dodatkowego Observable dla per-point color array.
- **Loop replay po SA stop** — D-06 wybrał freeze. Replay mode (animacja od początku w pętli) może być dodany w v2 jako `wizualizuj(...; loop=true)`.
- **`eksport_fps` osobny od live `fps`** — D-11 unified. Może być dodane w v2 dla high-quality 60fps MP4 z 30fps live preview.
- **Auto-suffix file naming (`demo-1.mp4`)** — D-10 wybrał error. v2 może dodać `nadpisz::Symbol = :error|:overwrite|:suffix` kwarg.
- **`nadpisz::Bool` kwarg dla force-overwrite** — odroczone do v2.
- **Smoke test wizualizacji w `runtests.jl`** — D-14 reject. Phase 4 może rozważyć (`@testset "wizualizacja" if Sys.islinux() && haskey(ENV, "DISPLAY")`).
- **Linux CI z xvfb dla README demo** — odroczone do Phase 4 dyskusji (D-15 reject dla Phase 3, ale może być sensowny dla Phase 4 README badge).
- **PackageCompiler sysimage dla GLMakie TTFP optimization** — Pitfall 14 świadomie odrzuca. v2/Phase 5 może dodać opcjonalny sysimage build script.
- **DataInspector** dla per-point hover info — D-07 NIE włącza (zbędny dla N=1000 bez metadata).
- **Multi-algorithm comparison view** (np. SA vs greedy 2-opt obok siebie) — wykraczające poza scope v1, deferred do v2 ROADMAP.
- **Stronger move (3-opt / or-opt / double-bridge)** dla ratio < 0.9 — ze STATE.md plan 02-14 deferred future work; pozostaje w roadmap v2.

### Reviewed Todos (not folded)
None — `list-todos` zwrócił 0 todos w bieżącej milestonie.

</deferred>

---

*Phase: 3-Visualization & Export*
*Context gathered: 2026-04-30*
