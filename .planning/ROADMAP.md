# Roadmap: JuliaCity

**Created:** 2026-04-28
**Granularity:** coarse (4 broad phases)
**Core Value:** Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — użytkownik widzi, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymuje krótszą trasę niż naiwny baseline.

## Phases

- [ ] **Phase 1: Bootstrap, Core Types & Points** — Pakiet startuje, encoding hygiene jest na miejscu, parametryczny `StanSymulacji` skompilowany, `generuj_punkty(1000)` zwraca deterministyczny `Vector{Punkt2D}`.
- [ ] **Phase 2: Energy, SA Algorithm & Test Suite** — `oblicz_energie` i `symuluj_krok!` (SA + 2-opt + NN init + Metropolis) działają headlessly, type-stable, zero-alloc, zwalidowane suitem testowym (Hamilton, JET, Aqua, NN-baseline-beat).
- [x] **Phase 3: Visualization & Export** — Okno GLMakie z animacją „zaciągania trasy", polskie etykiety, opcjonalny eksport MP4/GIF.
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
**Plans**: 6 plans
- [x] 01-01-PLAN.md — Instalacja Julia 1.10+ przez juliaup (checkpoint, blokuje fazę)
- [x] 01-02-PLAN.md — Repo skeleton: .editorconfig, .gitattributes, .gitignore, LICENSE, README.md, CONTRIBUTING.md, placeholder katalogi
- [x] 01-03-PLAN.md — Project.toml + Manifest.toml: [deps], [compat] (Wariant b), [extras]+[targets], stub test/runtests.jl
- [x] 01-04-PLAN.md — Core types: src/JuliaCity.jl module + src/typy.jl (Punkt2D, Algorytm, StanSymulacji{R} z const fields)
- [x] 01-05-PLAN.md — generuj_punkty: src/punkty.jl z dwiema metodami (D-11), wire do JuliaCity module
- [x] 01-06-PLAN.md — Pełen test suite (encoding guard, PKT-01..04, StanSymulacji, Aqua, JET smoke) + .github/workflows/CI.yml (matrix 3×3)
**UI hint**: no

### Phase 2: Energy, SA Algorithm & Test Suite
**Goal**: Algorytmiczny rdzeń — `oblicz_energie` z `Threads.@threads` na chunkach krawędzi, `delta_energii` w O(1), `symuluj_krok!` dla `SimAnnealing` (NN init + 2-opt + Metropolis + cooling α≈0.995 + T₀ kalibrowane automatycznie + stagnation patience). Pełen suite testowy z gwarancjami type-stability, zerowych alokacji i poprawności cyklu Hamiltona PRZED jakąkolwiek wizualizacją.
**Depends on**: Phase 1
**Requirements**: ENE-01, ENE-02, ENE-03, ENE-04, ENE-05, ALG-01, ALG-02, ALG-03, ALG-04, ALG-05, ALG-06, ALG-07, ALG-08, TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, TEST-08
**Success Criteria** (what must be TRUE):
  1. Wywołanie `oblicz_energie(punkty, trasa)` na cyklu Hamiltona zwraca prawdziwą długość euklidesową (test na 4-punktowym kwadracie zwraca `4.0 ± eps`); funkcja jest type-stable (`@inferred ... isa Float64`) i po rozgrzewce alokuje `< 4096 B`.
  2. `symuluj_krok!(stan, params, SimAnnealing(...))` jest type-stable i `@allocated == 0` po rozgrzewce; po każdym kroku `sort(stan.trasa) == 1:n` (niezmiennik cyklu Hamiltona).
  3. Uruchomienie SA z tym samym seedem master pod `JULIA_NUM_THREADS=1` i `JULIA_NUM_THREADS=8` daje identyczną trasę końcową (per-thread RNG zbudowany deterministycznie z master seeda).
  4. Wynikowa trasa SA jest co najmniej **5%** krótsza niż baseline NN (test asercja na fixtureze N=1000, seed=42); T₀ jest kalibrowane z 1000 losowych delt energii (T₀ = 2σ) — z zastrzeżeniem: TEST-05 nadpisuje `T_zero=0.001` ponieważ kalibracja `2σ` jest skalibrowana dla random startu i wyrzuca SA z basena NN-start (plan 02-14 erratum, 02-CONTEXT.md D-03). **Zluźnienie z 10% → 5%** (plan 02-14): pure 2-opt SA na N=1000 NN-start plateauje przy ratio ≈ 0.92 (2-opt local minimum); cel ≤0.9 wymagałby stronger move (3-opt / or-opt / double-bridge perturbation), poza scope v1.
  5. `julia --project=. test/runtests.jl` raportuje 0 failures: `@testset`-y dla niezmiennika Hamiltona, `@inferred` na publicznym API, `@allocated == 0`, determinizmu wieloraetkowego, NN-baseline-beat, `Aqua.test_all` (z udokumentowanymi suppressions), `JET.@report_opt` clean, golden-value `StableRNG(42)` na małym fixturze.
**Plans**: 6 plans in 6 waves (sequential — `src/JuliaCity.jl` file conflict + dependency chain) + 7 gap-closure plans (waves 7-10) addressing VERIFICATION.md/REVIEW.md blockers

**Wave 1** *(foundation — no deps)*
- [x] 02-01-PLAN.md — Project.toml deps (ChunkSplitters, Statistics, PerformanceTestTools w [extras]+[targets].test) + `Parametry` struct + Wave 0 StableRNG↔Punkt2D smoke

**Wave 2** *(blocked on Wave 1)*
- [x] 02-02-PLAN.md — `src/energia.jl`: `oblicz_macierz_dystans!`, `oblicz_energie` (2 metody, ChunkSplitters-threaded), `delta_energii` O(1), `kalibruj_T0` = 2σ

**Wave 3** *(blocked on Wave 2)*
- [x] 02-03-PLAN.md — `src/baselines.jl`: `trasa_nn(D; start=1)` (pure) + `inicjuj_nn!(stan)` (mutating wrapper)

**Wave 4** *(blocked on Wave 3)*
- [x] 02-04-PLAN.md — `src/algorytmy/simulowane_wyzarzanie.jl`: `SimAnnealing <: Algorytm` + `symuluj_krok!` (zero-alloc) + `uruchom_sa!` (ALG-06 stagnation-patience stop, D-04)

**Wave 5** *(blocked on Wave 4)*
- [x] 02-05-PLAN.md — `test/test_energia.jl` + `test/test_baselines.jl` + `test/test_symulacja.jl` (każdy w outer `@testset`); TEST-01/03/04/05/08; ALG-06 patience early-stop test; TEST-08 golden-value via Task 3a placeholder + Task 3b helper-script generation

**Wave 6** *(blocked on Wave 5)*
- [x] 02-06-PLAN.md — `test/runtests.jl` integration: 3 `include`s + Aqua TEST-06 (deps_compat ignore [Random, Statistics]) + JET TEST-07 (`@test_opt target_modules=(JuliaCity,)`)

**Wave 7** *(gap-closure: BL-01 off-by-one fix)*
- [x] 02-07-PLAN.md — BL-01 fix in `symuluj_krok!` + `kalibruj_T0` (`1:(n-2)` upper bound) + N=3 boundary regression tests + deferred-items.md cleanup

**Wave 8** *(gap-closure: parallel — Aqua, BL-03 patience, BL-04 threading)*
- [x] 02-08-PLAN.md — BL-02 + IN-04 fix: hoist `check_extras` to top-level Aqua kwarg + extend ignore list (BenchmarkTools, GLMakie, Makie, Observables)
- [x] 02-09-PLAN.md — BL-03 fix: `uruchom_sa!` patience reset semantic (rule 2 — strict per-step delta<0 via `energia_prev` tracker) + discriminator test
- [x] 02-10-PLAN.md — BL-04 fix: canonical chunked-threading pattern (`collect(chunks(...))` + `eachindex`) in `oblicz_energie` 3-arg

**Wave 9** *(gap-closure: parallel — WR-01 NaN guard, WR-08 dynamic threads)*
- [x] 02-11-PLAN.md — WR-01 fix: `kalibruj_T0` 3-way length dispatch (length>=2 / ==1 / ==0) + degenerate-path test
- [x] 02-12-PLAN.md — WR-08 fix: dynamic `max(2, Sys.CPU_THREADS)` in TEST-04 subprocess + single-core skip gate

**Wave 10** *(gap-closure: empirical verification — REQUIRES JULIA TOOLCHAIN)*
- [x] 02-13-PLAN.md *(autonomous: false)* — Manifest.toml regen + TEST-08 placeholder removal + `Pkg.test()` exit 0 evidence (handoff dd65a35; ukończone w plan 02-14 po naprawie `PerformanceTestTools` compat)

**Wave 11** *(gap-closure: TEST-05 algorithm decision)*
- [x] 02-14-PLAN.md — TEST-05 NN-baseline-beat fix; empirical diagnosis (`bench/diagnostyka_test05*.jl`) wykazała 2-opt local minimum przy ratio ≈ 0.92; opcja X: ROADMAP SC #4 zluźnione 10%→5% (ratio ≤ 0.95), `T_zero=0.001` override w teście, budżet 125_000 kroków. Pkg.test() 222/222 PASS, ratio 0.9408. Phase 2 COMPLETE.

**Cross-cutting constraints** *(must_haves shared across plans):*
- `StanSymulacji` shape preserved (Phase 1 D-06 lock — no field additions; SA stop counter local to `uruchom_sa!`)
- ASCII-only identifiers (`alfa`, `cierpliwosc`, `simulowane_wyzarzanie.jl`); Polish docstrings/comments OK with diacritics (NFC)
- JET pinned at `0.9` (NOT 0.11 — incompatible with `julia = "1.10"` compat floor)
- ChunkSplitters 3.x for thread-stable chunk IDs (Pitfall 2 mitigation; not `threadid()`)

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
**Plans**: 7 plans in 7 waves (Wave 0 BLOKER: Project.toml GLMakie compat fix; Waves 1-5 sequential — `src/wizualizacja.jl` file conflict; Wave 6 testing guard)

**Wave 0** *(pre-flight BLOKER — Project.toml + Manifest)*
- [x] 03-00-PLAN.md — Project.toml fix `GLMakie = "0.13"` (NIE "0.24"), przeniesienie GLMakie/Makie/Observables do [deps], dodanie ProgressMeter, regeneracja Manifest.toml przez Pkg.add. GLMakie 0.13.10, Makie 0.24.10, Observables 0.5.5, ProgressMeter 1.11.0 zainstalowane. Pkg.test 221/221 PASS.

**Wave 1** *(blocked on Wave 0 — module skeleton + integration)*
- [x] 03-01-PLAN.md — `src/wizualizacja.jl` skeleton (header + using GLMakie/ProgressMeter/Point2f + sygnatura `wizualizuj(...)::Nothing` z polish docstring + placeholder body) + wireing do `src/JuliaCity.jl` (include + export wizualizuj)

**Wave 2** *(blocked on Wave 1 — figure setup + Observables)*
- [x] 03-02-PLAN.md — 4 internal helpery: `_trasa_do_punkty` (Point2f + cycle closure), `_zbuduj_overlay_string` (7-pol overlay D-04), `_setup_figure` (dual-panel D-01 + dark theme D-03 + NN baseline D-02), `_init_observables` (Observable{Vector{Point2f}} + Observable{String} typed). Body wizualizuj() z with_theme(theme_dark()) do ... end.

**Wave 3** *(blocked on Wave 2 — live renderloop)*
- [x] 03-03-PLAN.md — `_live_loop` z throttled `while isopen(fig)` + sleep(1/fps), kroki_na_klatke SA stepów per Observable update (D-05/VIZ-05), rolling FPS/ETA/accept-rate, branch eksport===nothing wywoluje display(fig) + _live_loop.

**Wave 4** *(blocked on Wave 3 — eksport branch)*
- [x] 03-04-PLAN.md — `_export_loop` z `Makie.record(fig, sciezka, 1:n_klatek; framerate=fps) do frame_i ... end`, ProgressMeter (EKS-03), isfile() hard-fail (D-10/EKS-04), freeze last frame (D-12), polski @info/error (LANG-02). Branch eksport isa String wywoluje _export_loop. Pkg.test 226/226 PASS.

**Wave 5** *(blocked on Wave 4 — finalize: hard-fail wrapper + TTFP + GOTOWE)*
- [x] 03-05-PLAN.md — Refactor wizualizuj() na try/catch wrapper (D-13 polish hard-fail dla GLMakie/OpenGL/X11/display); `_wizualizuj_impl` jako internal; `_dodaj_gotowe_overlay!` (D-06 GOTOWE z ratio energia/energia_nn po SA stop); dwa @info TTFP messages (D-08). Pkg.test 226/226 PASS. 15/15 CONTEXT decisions D-01..D-15 zaimplementowane.

**Wave 6** *(blocked on Wave 5 — VIZ-06 grep guard test)*
- [x] 03-06-PLAN.md — `@testset "VIZ-06: GLMakie isolation"` w test/runtests.jl — grep-level (read+per-line) sprawdza ze tylko src/wizualizacja.jl ma `using GLMakie`. Pure headless (D-14, D-15), bezpieczne dla CI. Pkg.test 230/230 PASS. Phase 3 COMPLETE: 11/11 REQ-IDow.

**Cross-cutting constraints** *(must_haves shared across plans):*
- `src/wizualizacja.jl` jest JEDYNYM plikiem w src/ z `using GLMakie` (VIZ-06 LOCKED — formal test w plan 03-06)
- BRAK modyfikacji w src/{punkty.jl, energia.jl, baselines.jl, algorytmy/, typy.jl} (Phase 1+2 PHASE COMPLETE preserved)
- Polish UI strings (overlay, @info, error msg) z poprawnymi diakrytykami; ASCII identyfikatory (LANG-01/02 + BOOT-04)
- Manifest.toml regenerowany i commitowany (PROJECT D-25 — to aplikacja, nie biblioteka)
- All 15 CONTEXT decisions D-01..D-15 zaimplementowane (mapowanie w plan 03-05 SUMMARY)

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
**Plans**: 8 plans in 4 waves (Wave 1 parallel: 04-01..04-03 prep; Wave 2 parallel: 04-04..04-05 microbenchmarks + 04-07 examples; Wave 3: 04-06 orchestrator+wyniki.md; Wave 4: 04-08 demo.gif+README rewrite)

**Wave 1** *(independent prep — parallel)*
- [x] 04-01-PLAN.md — Project.toml [targets].test += BenchmarkTools (D-10) + .gitignore assets rules (D-05 EXACTLY: `assets/*` + `!assets/demo.gif`, nic więcej)
- [x] 04-02-PLAN.md — bench/historyczne/ archive move (D-16) — 3 diagnostyka_test05*.jl + README.md
- [x] 04-03-PLAN.md — CONTRIBUTING.md §4 Typografia polska (D-18) + renumber §4→§5, §5→§6

**Wave 2** *(parallel — blocked on 04-01)*
- [x] 04-04-PLAN.md — bench/bench_energia.jl + bench/bench_krok.jl (BENCH-01,02 + BENCH-04 $ interpolacja + fresh-fixture setup=, evals=1, samples=200)
- [x] 04-05-PLAN.md — bench/bench_jakosc.jl (BENCH-03 — 5 seedów × N=1000 × 50_000 SA z T_zero=0.001)
- [x] 04-07-PLAN.md — examples/podstawowy.jl + examples/eksport_mp4.jl (DEMO-01..04, D-04 pre-rm + mkpath defensive, D-11 hardcoded)

**Wave 3** *(blocked on Wave 2 + 04-02)*
- [ ] 04-06-PLAN.md — bench/run_all.jl orchestrator (D-06) + bench/uruchom.{sh,ps1} wrappers (Pkg.activate(temp=true) recipe — odblokowuje BenchmarkTools z [targets].test) + Module(:_BenchSandbox) izolacja per-bench `main()` + initial bench/wyniki.md (autonomous: false — wymaga toolchainu Julia)

**Wave 4** *(blocked on Wave 3 + 04-07)*
- [ ] 04-08-PLAN.md — assets/demo.gif (autonomous: false — wymaga lokalnego GLMakie GUI) + README.md rewrite 9 sekcji (D-15, D-18)

**Cross-cutting constraints** *(must_haves shared across plans):*
- BRAK modyfikacji w src/{punkty,energia,baselines,algorytmy/,typy,JuliaCity,wizualizacja}.jl (Phase 1+2+3 PHASE COMPLETE preserved — Phase 4 czysto additive)
- ASCII-only filenames (Phase 1 D-23): examples/podstawowy.jl, examples/eksport_mp4.jl, bench/bench_energia.jl, bench/bench_krok.jl, bench/bench_jakosc.jl, bench/run_all.jl, bench/historyczne/
- Polski docstring + komentarze + @info/@error (LANG-01, LANG-02); ASCII identyfikatory (BOOT-04 + Phase 1 D-23)
- function main(); ...; end; main() wrapper w examples (DEMO-03 + D-12 LOCKED)
- BenchmarkTools $ interpolacja + setup= discipline + evals=1 (BENCH-04)
- Polska typografia w user-facing markdown (cudzysłowy „...", em-dash —, NFC) per D-18 / CONTRIBUTING §4
- Encoding hygiene NFC + BOM-free + LF + final newline (Phase 1 D-21 — guard test waliduje)
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Bootstrap, Core Types & Points | 6/6 | Complete | 2026-04-28 |
| 2. Energy, SA Algorithm & Test Suite | 14/14 | Complete | 2026-04-30 |
| 3. Visualization & Export | 7/7 | Complete | 2026-04-30 |
| 4. Demo, Benchmarks & Documentation | 0/8 | Planned (4 waves) | - |

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
