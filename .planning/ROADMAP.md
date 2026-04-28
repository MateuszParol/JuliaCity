# Roadmap: JuliaCity

**Created:** 2026-04-28
**Granularity:** coarse (4 broad phases)
**Core Value:** Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — użytkownik widzi, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymuje krótszą trasę niż naiwny baseline.

## Phases

- [ ] **Phase 1: Bootstrap, Core Types & Points** — Pakiet startuje, encoding hygiene jest na miejscu, parametryczny `StanSymulacji` skompilowany, `generuj_punkty(1000)` zwraca deterministyczny `Vector{Punkt2D}`.
- [ ] **Phase 2: Energy, SA Algorithm & Test Suite** — `oblicz_energie` i `symuluj_krok!` (SA + 2-opt + NN init + Metropolis) działają headlessly, type-stable, zero-alloc, zwalidowane suitem testowym (Hamilton, JET, Aqua, NN-baseline-beat).
- [ ] **Phase 3: Visualization & Export** — Okno GLMakie z animacją „zaciągania trasy", polskie etykiety, opcjonalny eksport MP4/GIF.
- [ ] **Phase 4: Demo, Benchmarks & Documentation** — Skrypty `examples/`, suite benchmarków w `bench/`, README po polsku z demo GIF i liczbami benchmarków.

## Phase Details

### Phase 1: Bootstrap, Core Types & Points
**Goal**: Pakiet `JuliaCity.jl` ma poprawną strukturę, encoding hygiene od pierwszego commita, parametryczny `StanSymulacji{R<:AbstractRNG}` z konkretnie typowanymi polami oraz w pełni deterministyczny `generuj_punkty`. Headlessly testowalne — bez GLMakie.
**Depends on**: Nothing (first phase)
**Requirements**: BOOT-01, BOOT-02, BOOT-03, BOOT-04, PKT-01, PKT-02, PKT-03, PKT-04, LANG-01, LANG-04
**Success Criteria** (what must be TRUE):
  1. Repo ma strukturę `src/`, `test/`, `examples/`, `bench/`, `Project.toml`, `Manifest.toml` oraz pliki `.editorconfig` (UTF-8, LF, no BOM) i `.gitattributes` wymuszające UTF-8 dla `*.jl`; wszystkie pliki źródłowe mają nazwy ASCII.
  2. `Project.toml` zawiera sekcję `[compat]` z `julia = "1.10"`, `GLMakie = "0.24"`, `Makie = "0.24"` plus pozostałymi twardymi zależnościami z STACK.md.
  3. Uruchomienie `using JuliaCity; generuj_punkty(1000)` zwraca `Vector{Punkt2D}` o długości 1000, wszystkie współrzędne w `[0,1]²`, deterministycznie powtarzalne dla `seed=42` (różne wywołania → identyczne dane).
  4. `generuj_punkty` nie modyfikuje `Random.GLOBAL_RNG` (test sprawdzający `copy(Random.default_rng())` przed/po) — używa lokalnego `Xoshiro(seed)`.
  5. Wszystkie komentarze w `src/*.jl` po polsku; konwencja „polski w UI / angielski w internal asserts" udokumentowana w `CONTRIBUTING.md`.
**Plans**: TBD
**UI hint**: no

### Phase 2: Energy, SA Algorithm & Test Suite
**Goal**: Algorytmiczny rdzeń — `oblicz_energie` z `Threads.@threads` na chunkach krawędzi, `delta_energii` w O(1), `symuluj_krok!` dla `SimAnnealing` (NN init + 2-opt + Metropolis + cooling α≈0.995 + T₀ kalibrowane automatycznie + stagnation patience). Pełen suite testowy z gwarancjami type-stability, zerowych alokacji i poprawności cyklu Hamiltona PRZED jakąkolwiek wizualizacją.
**Depends on**: Phase 1
**Requirements**: ENE-01, ENE-02, ENE-03, ENE-04, ENE-05, ALG-01, ALG-02, ALG-03, ALG-04, ALG-05, ALG-06, ALG-07, ALG-08, TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, TEST-08
**Success Criteria** (what must be TRUE):
  1. Wywołanie `oblicz_energie(punkty, trasa)` na cyklu Hamiltona zwraca prawdziwą długość euklidesową (test na 4-punktowym kwadracie zwraca `4.0 ± eps`); funkcja jest type-stable (`@inferred ... isa Float64`) i po rozgrzewce alokuje `< 4096 B`.
  2. `symuluj_krok!(stan, params, SimAnnealing(...))` jest type-stable i `@allocated == 0` po rozgrzewce; po każdym kroku `sort(stan.trasa) == 1:n` (niezmiennik cyklu Hamiltona).
  3. Uruchomienie SA z tym samym seedem master pod `JULIA_NUM_THREADS=1` i `JULIA_NUM_THREADS=8` daje identyczną trasę końcową (per-thread RNG zbudowany deterministycznie z master seeda).
  4. Wynikowa trasa SA jest co najmniej 10% krótsza niż baseline NN (test asercja na fixtureze N=1000, seed=42); T₀ jest kalibrowane z 1000 losowych delt energii (T₀ = 2σ).
  5. `julia --project=. test/runtests.jl` raportuje 0 failures: `@testset`-y dla niezmiennika Hamiltona, `@inferred` na publicznym API, `@allocated == 0`, determinizmu wieloraetkowego, NN-baseline-beat, `Aqua.test_all` (z udokumentowanymi suppressions), `JET.@report_opt` clean, golden-value `StableRNG(42)` na małym fixturze.
**Plans**: TBD
**UI hint**: no

### Phase 3: Visualization & Export
**Goal**: Plik `wizualizacja.jl` (jedyny w `src/` z `using GLMakie`) buduje okno z `Observable{Vector{Point2f}}`, polskim tytułem/etykietami/overlay'em (numer iteracji + bieżąca energia), throttled updates przez `KROKI_NA_KLATKE`. Argument `eksport=` pozwala zapisać animację do MP4 lub GIF z paskiem postępu i bezpieczną obsługą nazw plików.
**Depends on**: Phase 2
**Requirements**: VIZ-01, VIZ-02, VIZ-03, VIZ-04, VIZ-05, VIZ-06, VIZ-07, EKS-01, EKS-02, EKS-03, EKS-04
**Success Criteria** (what must be TRUE):
  1. Wywołanie `wizualizuj(stan, params, alg; liczba_krokow=5000)` otwiera okno GLMakie i animuje proces zaciągania trasy w czasie rzeczywistym; trasa jest renderowana jako linia łącząca punkty w kolejności permutacji `stan.trasa` z domknięciem cyklu, punkty jako scatter o czytelnym rozmiarze dla N=1000.
  2. Tytuł, etykiety osi i overlay tekstowy z numerem iteracji oraz bieżącą energią są w pełni po polsku; polskie diakrytyki (ąęłńóśźż) renderują się poprawnie w Makie (potwierdzone wizualnie i/lub testem render-and-pixel).
  3. Aktualizacje Observables są throttlowane (parametr `KROKI_NA_KLATKE`, default ≥ 10) — okno pozostaje responsywne na laptopie przez całą animację, brak update storm.
  4. `wizualizacja.jl` jest jedynym plikiem w `src/` importującym GLMakie — uruchomienie testów rdzenia w `test/runtests.jl` nie wymaga OpenGL (potwierdzone `grep -l "using GLMakie" src/` zwraca tylko `wizualizacja.jl`).
  5. Wywołanie `wizualizuj(...; eksport="demo.mp4")` lub `eksport="demo.gif"` produkuje plik wideo/GIF (rozszerzenie wykrywane z extensji ścieżki), z widocznym paskiem postępu (`ProgressMeter` lub odpowiednik) i bezpieczną obsługą istniejących plików (jawna polityka nadpisania lub błąd).
**Plans**: TBD
**UI hint**: yes

### Phase 4: Demo, Benchmarks & Documentation
**Goal**: Pełen pakiet „produkcyjny" — uruchamialne skrypty demo (live i eksport), reprodukowalna suite benchmarków z zapisem wyników, README po polsku z demo GIF, instalacją, quickstartem i liczbami benchmarków vs NN baseline. Wszystkie napisy UI po polsku.
**Depends on**: Phase 3
**Requirements**: DEMO-01, DEMO-02, DEMO-03, DEMO-04, BENCH-01, BENCH-02, BENCH-03, BENCH-04, BENCH-05, LANG-02, LANG-03
**Success Criteria** (what must be TRUE):
  1. Uruchomienie `julia --project=. --threads=auto examples/podstawowy.jl` bez dodatkowych przygotowań otwiera okno GLMakie, generuje 1000 punktów, inicjalizuje trasę NN, uruchamia SA z wizualizacją na żywo i polskimi etykietami; każdy plik w `examples/` opakowany w `function main(); ...; end; main()`.
  2. Uruchomienie `julia --project=. --threads=auto examples/eksport_mp4.jl` produkuje plik `assets/demo.mp4` (lub `.gif`) reprodukowalnie.
  3. Folder `bench/` zawiera trzy reprodukowalne skrypty: `bench_energia.jl` (czas + alokacje `oblicz_energie`), `bench_krok.jl` (czas + alokacje `symuluj_krok!`), `bench_jakosc.jl` (długość trasy SA vs NN na N=1000, uśrednienie po seedach); wszystkie używają `BenchmarkTools` z `$` interpolacją i `setup=` discipline.
  4. Po uruchomieniu suite'u benchmarków plik `bench/wyniki.md` zawiera czasy, alokacje i jakość trasy w formie tabelarycznej.
  5. `README.md` jest w pełni po polsku, zawiera Core Value, instrukcje instalacji, quickstart, osadzony demo GIF z `assets/`, sekcję benchmarków z aktualnymi liczbami vs NN baseline; wszystkie napisy UI w pakiecie (tytuły, osie, overlay, komunikaty postępu) są po polsku.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Bootstrap, Core Types & Points | 0/0 | Not started | - |
| 2. Energy, SA Algorithm & Test Suite | 0/0 | Not started | - |
| 3. Visualization & Export | 0/0 | Not started | - |
| 4. Demo, Benchmarks & Documentation | 0/0 | Not started | - |

## Coverage Summary

**Total v1 requirements:** 53 (10 categories: BOOT×4, PKT×4, ENE×5, ALG×8, VIZ×7, EKS×4, DEMO×4, TEST×8, BENCH×5, LANG×4)
**Mapped:** 53/53 ✓
**Orphaned:** 0
**Duplicated:** 0

> Note: REQUIREMENTS.md header stated "51 total"; actual REQ-ID count is 53 (BOOT-01..04, PKT-01..04, ENE-01..05, ALG-01..08, VIZ-01..07, EKS-01..04, DEMO-01..04, TEST-01..08, BENCH-01..05, LANG-01..04). Traceability table updated to reflect actual REQ-IDs.

| Category | Phase | Count |
|----------|-------|-------|
| BOOT-01..04 | Phase 1 | 4 |
| PKT-01..04 | Phase 1 | 4 |
| LANG-01, LANG-04 | Phase 1 | 2 |
| ENE-01..05 | Phase 2 | 5 |
| ALG-01..08 | Phase 2 | 8 |
| TEST-01..08 | Phase 2 | 8 |
| VIZ-01..07 | Phase 3 | 7 |
| EKS-01..04 | Phase 3 | 4 |
| DEMO-01..04 | Phase 4 | 4 |
| BENCH-01..05 | Phase 4 | 5 |
| LANG-02, LANG-03 | Phase 4 | 2 |

## Phase Ordering Rationale

- **Phase 1 first** — every other phase depends on `typy.jl` and `punkty.jl`; encoding hygiene MUST land before any Polish identifier is committed (retrofit cost is high).
- **Phase 2 before Phase 3** — `wizualizuj` is hard to debug independently; a correct, tested, fast core means any visualization issue is isolated to the visualization layer (PITFALLS.md test-before-visualize discipline).
- **Phase 3 before Phase 4** — README's demo GIF and benchmark numbers depend on Phase 3 working; examples and `eksportuj_mp4()` reuse the live loop.
- **Phase 4 last** — README, demo GIF, and final benchmark numbers are the marketing surface; produce them when everything underneath is stable.

## Algorithm Variant Lock-in

For v1, the only `<:Algorytm` subtype shipped is `SimAnnealing` (SA-2-opt + NN init + Metropolis acceptance + geometric cooling α≈0.995 + auto-calibrated T₀ + stagnation patience). `ForceDirected` and `Hybryda` remain as architecturally-supported v2/v1.1+ additive variants per Holy-traits dispatch — they are NOT in this roadmap.

---
*Roadmap created: 2026-04-28*
*Last updated: 2026-04-28 after initialization*
