# Requirements: JuliaCity

**Defined:** 2026-04-28
**Core Value:** Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — użytkownik widzi, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymuje krótszą trasę niż naiwny baseline.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Bootstrap (BOOT)

- [ ] **BOOT-01**: Pakiet ma strukturę `src/`, `test/`, `examples/`, `bench/`, `Project.toml`, `Manifest.toml` — wygenerowane przez PkgTemplates lub równoważnie ręcznie
- [ ] **BOOT-02**: `Project.toml` zawiera sekcję `[compat]` z `julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"` oraz pozostałymi twardymi zależnościami z STACK.md
- [ ] **BOOT-03**: Repo zawiera `.editorconfig` (UTF-8, LF, bez BOM) oraz `.gitattributes` wymuszające UTF-8 dla `*.jl`
- [ ] **BOOT-04**: Wszystkie pliki źródłowe mają nazwy ASCII (bez polskich diakrytyków w ścieżkach) — konwencja udokumentowana w README/CONTRIBUTING

### Punkty (PKT)

- [ ] **PKT-01**: Funkcja `generuj_punkty(n::Int; seed=42)` zwraca `Vector{Punkt2D}` o długości `n`, deterministycznie dla danego seeda
- [ ] **PKT-02**: Domyślnie `n = 1000` przy wywołaniu bez argumentu liczbowego — projekt celuje w tę liczbę punktów
- [ ] **PKT-03**: Wygenerowane punkty leżą w jednostkowym kwadracie `[0,1]²` (rozkład jednostajny)
- [ ] **PKT-04**: Brak globalnego stanu — funkcja nie modyfikuje `Random.GLOBAL_RNG`, tylko lokalny `Xoshiro(seed)`

### Energia (ENE)

- [ ] **ENE-01**: Funkcja `oblicz_energie(punkty, trasa)::Float64` zwraca długość cyklu Hamiltona (suma odległości euklidesowych łącznie z domknięciem)
- [ ] **ENE-02**: `oblicz_energie` jest type-stable — `@code_warntype` / JET `@report_opt` nie zgłasza ostrzeżeń
- [ ] **ENE-03**: `oblicz_energie` po rozgrzewce nie alokuje — test `@allocated < 4096` (margines dla buforów wątków)
- [ ] **ENE-04**: Pomocnicza `delta_energii(stan, i, j)` liczy zmianę energii dla ruchu 2-opt w O(1), bez kopiowania trasy
- [ ] **ENE-05**: Wewnątrz `oblicz_energie` używana jest `Threads.@threads :static` na chunkach krawędzi, bez closure-capture boxing (per-thread sloty w pre-alokowanym wektorze)

### Algorytm (ALG)

- [ ] **ALG-01**: Zdefiniowany `abstract type Algorytm end` plus konkretny podtyp `struct SimAnnealing <: Algorytm` z hiperparametrami (T₀, α, patience)
- [ ] **ALG-02**: Funkcja `symuluj_krok!(stan, params, alg::SimAnnealing)` mutuje `stan` in-place: proponuje ruch 2-opt, akceptuje wg kryterium Metropolisa, aktualizuje temperaturę i historię
- [ ] **ALG-03**: `symuluj_krok!` jest type-stable i nie alokuje po rozgrzewce — test `@allocated == 0`
- [ ] **ALG-04**: Inicjalizacja trasy przez nearest-neighbor (`trasa_nn(punkty)`) — używana jako start symulacji oraz jako baseline jakości
- [ ] **ALG-05**: T₀ kalibrowane automatycznie z 1000 losowych delt energii na trasie startowej (T₀ = 2σ); parametr można nadpisać ręcznie
- [ ] **ALG-06**: Kryterium stopu: stagnation patience — brak poprawy energii przez `cierpliwość` kolejnych kroków → koniec
- [ ] **ALG-07**: Każdy wątek ma własny RNG zbudowany deterministycznie z master seeda — same seed + same nthreads → identyczna trasa końcowa
- [ ] **ALG-08**: Po każdym kroku trasa zachowuje niezmiennik cyklu Hamiltona (`sort(trasa) == 1:n`) — sprawdzane testem

### Wizualizacja (VIZ)

- [x] **VIZ-01**: Funkcja `wizualizuj(stan, params, alg; liczba_krokow, fps=30, eksport=nothing)` otwiera okno GLMakie i animuje proces zaciągania trasy w czasie rzeczywistym
- [x] **VIZ-02**: Trasa renderowana jako linia łącząca punkty w kolejności permutacji `stan.trasa`, z domknięciem cyklu — używa `Observable{Vector{Point2f}}`
- [x] **VIZ-03**: Punkty renderowane jako scatter (rozmiar wystarczająco czytelny dla N=1000)
- [x] **VIZ-04**: Tytuł, etykiety osi i overlay tekstowy (numer iteracji + bieżąca energia) — wszystko po polsku
- [x] **VIZ-05**: Aktualizacja Observables jest throttled (parametr `KROKI_NA_KLATKE`, default ≥ 10) — brak update storm zalewającego renderloop
- [x] **VIZ-06**: Plik `wizualizacja.jl` jest jedynym w `src/` importującym GLMakie — core jest testowalny headlessly bez OpenGL
- [x] **VIZ-07**: Diakrytyki polskie (ąęłńóśźż) renderują się poprawnie w Makie (potwierdzone wizualnie i/lub testem render-and-pixel)

### Eksport (EKS)

- [ ] **EKS-01**: Argument `eksport::Union{Nothing,String}` w `wizualizuj()` — gdy podana ścieżka, animacja jest zapisywana do pliku przez `Makie.record(...)`
- [ ] **EKS-02**: Obsługa rozszerzeń `.mp4` i `.gif` — wykrywane z extensji ścieżki
- [ ] **EKS-03**: Eksport używa `ProgressMeter.jl` lub równoważnego wskaźnika postępu — użytkownik widzi że proces żyje
- [ ] **EKS-04**: Bezpieczna obsługa nazw plików (brak nadpisywania bez ostrzeżenia, lub jawna polityka nadpisania)

### Demo (DEMO)

- [ ] **DEMO-01**: Plik `examples/podstawowy.jl` uruchamia pełną pętlę: `generuj_punkty` → init NN → SA z wizualizacją na żywo
- [ ] **DEMO-02**: Plik `examples/eksport_mp4.jl` produkuje plik wideo `assets/demo.mp4` (lub `.gif`)
- [ ] **DEMO-03**: Każdy plik w `examples/` opakowany w `function main(); ...; end; main()` — unika spowolnienia top-level scope
- [ ] **DEMO-04**: Demo uruchamia się komendą `julia --project=. --threads=auto examples/podstawowy.jl` bez dodatkowych przygotowań

### Testy (TEST)

- [ ] **TEST-01**: `test/runtests.jl` zawiera `@testset` dla niezmiennika cyklu Hamiltona po każdym kroku symulacji
- [ ] **TEST-02**: `@testset` dla type stability — `@inferred` na każdej publicznej funkcji
- [ ] **TEST-03**: `@testset` dla zerowej alokacji — `@allocated == 0` na `symuluj_krok!` po rozgrzewce
- [ ] **TEST-04**: `@testset` dla determinizmu — same seed + różne `JULIA_NUM_THREADS` → identyczna trasa końcowa
- [ ] **TEST-05**: `@testset` dla wymagania jakości — wynikowa trasa SA krótsza niż NN baseline o co najmniej **5%** (zluźnione z 10% w plan 02-14; zob. ROADMAP SC #4 + 02-CONTEXT.md D-03 erratum: pure 2-opt SA na N=1000 NN-start plateauje przy ratio ≈ 0.92, cel ≤0.9 wymaga stronger move poza scope v1)
- [ ] **TEST-06**: `@testset` Aqua.jl (`Aqua.test_all`) bez naruszeń (lub z udokumentowanymi suppressions)
- [ ] **TEST-07**: `@testset` JET — `@report_opt` clean na publicznym API
- [ ] **TEST-08**: Golden-value test używa `StableRNG(42)` (nie `Xoshiro`) dla stabilnych przebiegów między wersjami Julii

### Benchmark (BENCH)

- [ ] **BENCH-01**: Folder `bench/` z reprodukowalnym skryptem `bench_energia.jl` (czas + alokacje `oblicz_energie`)
- [ ] **BENCH-02**: Skrypt `bench/bench_krok.jl` (czas + alokacje `symuluj_krok!`)
- [ ] **BENCH-03**: Skrypt `bench/bench_jakosc.jl` porównujący długość trasy SA vs NN baseline na N=1000 (uśrednienie po seedach)
- [ ] **BENCH-04**: Wszystkie benchmarki używają `BenchmarkTools` z `$` interpolacją i `setup=` discipline
- [ ] **BENCH-05**: Wyniki benchmarków zapisywane do `bench/wyniki.md` (format: czas, alokacje, jakość trasy)

### Polski język (LANG)

- [ ] **LANG-01**: Wszystkie komentarze w kodzie po polsku
- [ ] **LANG-02**: Wszystkie napisy w UI (tytuły, osie, overlay, komunikaty postępu) po polsku
- [ ] **LANG-03**: README.md napisany po polsku (Core Value, instalacja, quickstart, demo GIF, benchmark)
- [ ] **LANG-04**: Komunikaty błędów / asercje wewnętrzne mogą być po angielsku (konwencja udokumentowana) — ale komunikaty user-facing po polsku

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Algorithm Variants (ALGV2)

- **ALGV2-01**: Wariant `struct ForceDirected <: Algorytm` — fizyka sprężyn na cyklu Hamiltona, wymaga osobnej fazy badawczej (brak kanonicznych referencji)
- **ALGV2-02**: Wariant `struct Hybryda <: Algorytm` — SA jako szkielet decyzyjny + force-directed wygładzanie pomiędzy iteracjami

### Visual Differentiators (VIZV2)

- **VIZV2-01**: Dual-panel layout: trasa + krzywa energii vs iteracja (single biggest visual upgrade)
- **VIZV2-02**: Edge color encodes edge length (gradient — krótsze krawędzie zielone, dłuższe czerwone)
- **VIZV2-03**: Or-opt move zmieszany z 2-opt (~30% blend) dla lepszej jakości trasy
- **VIZV2-04**: Slider prędkości + przycisk pauzy/wznowienia w GLMakie
- **VIZV2-05**: Wybór dystrybucji punktów (`:jednostajny`, `:zgrupowany`, `:siatka`, `:okrąg`)
- **VIZV2-06**: Side-by-side panel NN-frozen vs SA-evolving

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Metryki nieeuklidesowe (Manhattan, Haversine) | Łamie analogię błony mydlanej; projekt to fizyczna heurystyka 2D Euclidean |
| Punkty 3D / wyższe wymiary | Projekt celuje w wizualną demonstrację 2D — wyższe wymiary unieważniają cel |
| Solver klasy Concorde / LKH | Projekt to ładna heurystyka, nie state-of-the-art TSP solver |
| Web interface / API / serwer | Projekt jest do uruchamiania lokalnie z GLMakie |
| N >> 1000 punktów (np. 100k) | Algorytm i wizualizacja zoptymalizowane pod 1000 punktów |
| UI w innym języku niż polski | Twardy wymóg projektu (niezmienny) |
| 3-opt / Lin-Kernighan moves | Wysoki koszt implementacji, marginalny zysk dla N=1000 |
| Drag-and-drop edycja punktów | Łamie niezmienniki symulacji; nie ma w wymaganiach |
| Plots.jl jako równorzędny backend | Mieszanie Plots+Makie to udokumentowany anti-pattern; GLMakie pokrywa wszystkie potrzeby |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOT-01 | Phase 1 | Pending |
| BOOT-02 | Phase 1 | Pending |
| BOOT-03 | Phase 1 | Pending |
| BOOT-04 | Phase 1 | Pending |
| PKT-01 | Phase 1 | Pending |
| PKT-02 | Phase 1 | Pending |
| PKT-03 | Phase 1 | Pending |
| PKT-04 | Phase 1 | Pending |
| ENE-01 | Phase 2 | Pending |
| ENE-02 | Phase 2 | Pending |
| ENE-03 | Phase 2 | Pending |
| ENE-04 | Phase 2 | Pending |
| ENE-05 | Phase 2 | Pending |
| ALG-01 | Phase 2 | Pending |
| ALG-02 | Phase 2 | Pending |
| ALG-03 | Phase 2 | Pending |
| ALG-04 | Phase 2 | Pending |
| ALG-05 | Phase 2 | Pending |
| ALG-06 | Phase 2 | Pending |
| ALG-07 | Phase 2 | Pending |
| ALG-08 | Phase 2 | Pending |
| VIZ-01 | Phase 3 | Complete |
| VIZ-02 | Phase 3 | Complete |
| VIZ-03 | Phase 3 | Complete |
| VIZ-04 | Phase 3 | Complete |
| VIZ-05 | Phase 3 | Complete |
| VIZ-06 | Phase 3 | Complete |
| VIZ-07 | Phase 3 | Complete |
| EKS-01 | Phase 3 | Pending |
| EKS-02 | Phase 3 | Pending |
| EKS-03 | Phase 3 | Pending |
| EKS-04 | Phase 3 | Pending |
| DEMO-01 | Phase 4 | Pending |
| DEMO-02 | Phase 4 | Pending |
| DEMO-03 | Phase 4 | Pending |
| DEMO-04 | Phase 4 | Pending |
| TEST-01 | Phase 2 | Pending |
| TEST-02 | Phase 2 | Pending |
| TEST-03 | Phase 2 | Pending |
| TEST-04 | Phase 2 | Pending |
| TEST-05 | Phase 2 | Pending |
| TEST-06 | Phase 2 | Pending |
| TEST-07 | Phase 2 | Pending |
| TEST-08 | Phase 2 | Pending |
| BENCH-01 | Phase 4 | Pending |
| BENCH-02 | Phase 4 | Pending |
| BENCH-03 | Phase 4 | Pending |
| BENCH-04 | Phase 4 | Pending |
| BENCH-05 | Phase 4 | Pending |
| LANG-01 | Phase 1 | Pending |
| LANG-02 | Phase 4 | Pending |
| LANG-03 | Phase 4 | Pending |
| LANG-04 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 53 total (recount: BOOT×4 + PKT×4 + ENE×5 + ALG×8 + VIZ×7 + EKS×4 + DEMO×4 + TEST×8 + BENCH×5 + LANG×4 = 53; previous header "51" was a miscount)
- Mapped to phases: 53 ✓
- Unmapped: 0

---
*Requirements defined: 2026-04-28*
*Last updated: 2026-04-28 after roadmap creation (traceability filled, total recount fixed)*
