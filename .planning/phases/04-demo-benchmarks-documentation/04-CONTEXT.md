# Phase 4: Demo, Benchmarks & Documentation - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 dostarcza pakiet „produkcyjny" gotowy do udostępnienia: dwa uruchamialne skrypty w `examples/` (live demo + eksport GIF), reprodukowalna suite trzech benchmarków w `bench/` z auto-generowanym `bench/wyniki.md`, oraz pełen polski `README.md` z osadzonym demo GIF i headline'owymi liczbami vs NN baseline. Cały UI/dokumentacja w polskim z poprawną typografią („…", em-dash, NFC).

Pokrywa **REQ-IDs:** DEMO-01..04, BENCH-01..05, LANG-02, LANG-03 (11 wymagań).

**W zakresie:**
- `examples/podstawowy.jl` — live demo `wizualizuj()` z hardcoded sensible defaults (N=1000, seed=42, 50 000 kroków, 33s @30fps).
- `examples/eksport_mp4.jl` — eksport krótszego ~10s demo do `assets/demo.gif` (15 000 kroków, 300 klatek @30fps, ~3-5 MB), pre-rm istniejącego pliku.
- `bench/run_all.jl` orchestrator, plus `bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl` — pojedyncza komenda `julia --project=. --threads=auto bench/run_all.jl` regeneruje `bench/wyniki.md`.
- `README.md` po polsku: header + 1-zdanie core value, GIF, wymagania, instalacja, quickstart (3 fragmenty), opis algorytmu, tabela benchmarków, struktura projektu, licencja.
- Cleanup: `bench/diagnostyka_test05*.jl` → `bench/historyczne/` (audit trail Phase 2 plan 02-14 zachowany).
- `CONTRIBUTING.md` zyskuje sekcję „Typografia polska" (cudzysłowy, em-dash, NFC normalization) — zamyka jeden z STATE.md TODOs.

**Poza zakresem (świadomie):**
- xvfb / headless CI step dla auto-build `assets/demo.gif` w PR — deferred (STATE.md open question pozostaje, GIF buildowany lokalnie i commitowany).
- Encoding-validation guard test (Phase 1 D-21 TODO) — pozostaje deferred.
- ENV/ARGS parametryzacja examples (KISS, DEMO-04 wymaga „bez dodatkowych przygotowań").
- ArgParse, Documenter.jl, FAQ/architektura w README — YAGNI dla v1.
- Threading scalability matrix w benchmarkach (1/2/4/8) — tylko `--threads=auto`.
- Chairmarks — REQUIREMENTS.md BENCH-04 explicit `BenchmarkTools` (nie zmieniamy).

</domain>

<decisions>
## Implementation Decisions

### A. Demo: format, długość, hosting

- **D-01: GIF jako jedyny format demo** — `assets/demo.gif` embed'owany w README przez `![](assets/demo.gif)`. Bez MP4 (link w README mniej widoczny niż auto-play GIF). Decyzja przeciwna do D-09 z Phase 3 sugestii „mp4" — tu produkcja końcowa świadomie wybiera GIF dla README UX.
- **D-02: 10s ~15 000 kroków, ~300 klatek @30fps** — `examples/eksport_mp4.jl` wywołuje `wizualizuj(stan, params, alg; liczba_krokow=15_000, kroki_na_klatke=50, fps=30, eksport="assets/demo.gif")`. Daje 300 klatek = 10s, ~3-5 MB GIF. Krótszy niż Phase 3 sugerowane „33s" demo target — README-friendly + szybsze regen lokalnie.
- **D-03: Nazwa skryptu `examples/eksport_mp4.jl` zachowana** — zgodność z REQUIREMENTS.md DEMO-02 i ROADMAP.md Phase 4 SC #2 (oba dopuszczają `.gif` jako alternative). Docstring polski wyjaśnia dlaczego pomimo nazwy „eksport_mp4" produkujemy GIF (README embed). Brak rename — plan unika ALTER REQUIREMENTS.md tylko dla nazwy.
- **D-04: Pre-rm w skrypcie eksportu** — `examples/eksport_mp4.jl` wykonuje `isfile(out) && rm(out)` przed wywołaniem `wizualizuj()`. Świadomie obchodzi Phase 3 D-10 hard-fail (D-10 to ochrona przed przypadkowym overwrite z poziomu API; demo skrypt = świadoma regeneracja). Komentarz polski wyjaśnia intencję.
- **D-05: `assets/demo.gif` commitowany do repo** — rozmiar ~3-5 MB akceptowalny. `.gitignore` dostaje regułę `assets/*` z wyjątkiem `!assets/demo.gif` — żaden lokalny artefakt (np. `assets/test.mp4` developera) nie wpada do git status. Dev odpowiedzialny za commit nowego GIFa po regen.

### B. Benchmarks: format, metryki, deps

- **D-06: `bench/run_all.jl` jako single entry point** — orchestrator uruchamia `bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl`, zbiera wyniki przez Serialization (lub raw `BenchmarkTools.Trial`), renderuje markdown table do `bench/wyniki.md`. Jedna komenda dla full reproduction: `julia --project=. --threads=auto bench/run_all.jl`. Per-bench skrypty pozostają samodzielnie uruchamialne (każdy ma `function main()` z `Test` opcjonalnym warmup).
- **D-07: Metryki:** median time + memory + alokacje na `bench_energia` i `bench_krok` (`BenchmarkTools.@benchmark` z `$` interpolacją + `setup=` discipline per BENCH-04). Header `bench/wyniki.md`: Julia version, OS, CPU model (`Sys.cpu_info()[1].model`), `nthreads()`, `Dates.now()`. Bez percentile / bez matrix scalability.
- **D-08: `bench_jakosc.jl` — 5 seedów** — `[42, 123, 456, 789, 2025]` × N=1000 punktów × 50 000 kroków SA. Raportujemy `mean(ratio_SA_NN) ± std`, `min`, `max`. Przykładowe oczekiwane wartości (ekstrapolacja z TEST-05): mean ≈ 0.94, std ≈ 0.01, ratio < 1.0 we wszystkich (pokazuje: SA bije NN konsekwentnie). Headline number do README: „SA znajduje trasę średnio ~6% krótszą niż NN baseline (5 seedów)".
- **D-09: Threading: tylko `--threads=auto`** — jedna kolumna w tabeli wyników. Bez matrix `JULIA_NUM_THREADS=1,2,4` (perf hipster trap dla v1). README mentioned w sekcji „Reprodukowalność": „Wyniki zaleznę od liczby wątków; podane przy `--threads=auto` na hardware z header'a".
- **D-10: BenchmarkTools wciągany przez `[extras]`+`[targets].test`** — obecnie `BenchmarkTools` jest w `[extras]` i `[compat]` Project.toml; **brakuje wpisu w `[targets].test`** (line 45 Project.toml: `test = ["Aqua", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]` — nie ma BenchmarkTools). Phase 4 plan dodaje `BenchmarkTools` do `[targets].test` (rozszerza środowisko testowe, dostępne dla `bench/*.jl` po `using Pkg; Pkg.test(); ` lub przez activation testowego env). Bez osobnego `bench/Project.toml` (over-engineering dla 4 skryptów). Aqua TEST-06 ignore lista pozostaje (BenchmarkTools już udokumentowane jako test dep).

### C. Demo scripts: parametryzacja i UX

- **D-11: Hardcoded sensible defaults** — `examples/podstawowy.jl` używa hardcoded `N=1000, seed=42, liczba_krokow=50_000, kroki_na_klatke=50, fps=30` (target 33s live demo). `examples/eksport_mp4.jl` używa `liczba_krokow=15_000` (per D-02). Komentarze polskie nad każdą stałą: „# Aby zmienić długość demo, edytuj `liczba_krokow` poniżej". Zero ENV/ARGS magic, zero ArgParse dep — DEMO-04 spełnione („bez dodatkowych przygotowań").
- **D-12: Każdy plik w `examples/` zamknięty w `function main(); ...; end; main()`** — DEMO-03 explicit. Unika spowolnień top-level scope (Julia compilation), umożliwia łatwy `include()` dla integration testing.
- **D-13: Banner + timing summary po SA stop** — examples wypisują:
  - Na starcie: `@info "JuliaCity demo — N=$N, seed=$SEED, threads=$(Threads.nthreads())"`
  - Po `wizualizuj()` zwróceniu: `@info "GOTOWE: ratio=$(round(stan.energia/energia_nn, digits=4)), czas=$(round(dt, digits=2))s, kroków=$(stan.iteracja)"`
  Phase 3 wizualizuj() już emituje TTFP @info (D-08) i komunikat „Eksport..." — examples dodają tylko summary. LANG-02 zaspokojone.
- **D-14: Threading messaging — `Threads.nthreads()` w bannerze** — examples nie zmieniają threading defaultu (`--threads=auto` w komendzie); banner pokazuje co aktualnie ustawione. Brak `Threads.nthreads() == 1 && @warn "Uruchom z --threads=auto..."` (overbearing — DEMO-04 KISS).

### D. README, cleanup, CI

- **D-15: README.md struktura (9 sekcji, polski, LANG-03)** — kolejność:
  1. Header `# JuliaCity` + 1-zdanie core value (z PROJECT.md)
  2. `![Demo SA na 1000 punktach](assets/demo.gif)` (centered/below header)
  3. **Wymagania** — Julia ≥ 1.10 (zalecane 1.11/1.12), system: Linux/macOS/Windows
  4. **Instalacja** — `Pkg.activate(".") + Pkg.instantiate()` snippet (jak obecnie)
  5. **Quickstart** — 3 fragmenty kodu: (a) `generuj_punkty(1000)`, (b) `wizualizuj(stan, params, alg)` (live), (c) `wizualizuj(...; eksport="moje_demo.gif")`
  6. **Algorytm** — 1 paragraf prosty: „SA-2-opt z metropolis acceptance + nearest-neighbor init. Metafora błony mydlanej…" (z PROJECT.md core value)
  7. **Benchmarki** — link do `bench/wyniki.md` + headline: „SA znajduje trasę średnio ~6% krótszą niż NN baseline (5 seedów × N=1000)" (z bench_jakosc D-08)
  8. **Struktura projektu** — drzewko ASCII (z `.planning/codebase/STRUCTURE.md` skrót)
  9. **Licencja** — MIT, link do LICENSE
- **D-16: `bench/diagnostyka_test05*.jl` → `bench/historyczne/`** — 3 pliki (z plan 02-14 erratum) przenoszone, NIE usuwane (zachowany audit trail empirycznej diagnozy 2-opt local minimum). `bench/run_all.jl` ich nie wykonuje. README w `bench/historyczne/` (lub nagłówek w `bench/wyniki.md`) wyjaśnia kontekst.
- **D-17: Brak xvfb CI step w Phase 4** — STATE.md open question „CairoMakie fallback for headless CI" pozostaje OPEN (deferred do v2). CI matrix z Phase 1 (`1.10/1.11/1.12 × ubuntu/windows/macos`) bez zmian. `assets/demo.gif` buildowany lokalnie przez dev'a, commitowany ręcznie. Eliminuje ryzyko Pitfall 7 (GLMakie headless flaky).
- **D-18: Polish typography w README + sekcja w `CONTRIBUTING.md`** — README.md używa „…" (proper polish quotes, U+201E + U+201D), em-dash (—, U+2014), NFC normalization (encoding hygiene Phase 1). Dodajemy do `CONTRIBUTING.md` sekcję „§4. Typografia polska" z konwencją: cudzysłowy, em-dash, NFC, BOM-free. STATE.md TODO „Polish-typography convention" → zamknięty.
- **D-19: Encoding-validation CI guard test (Phase 1 D-21 TODO) — pozostaje deferred** — wymaga osobnego designu (jakie pliki skanować? jakie violations są błędem vs warningiem?). Nie blokuje Phase 4. STATE.md TODO zostaje otwarty.

### Claude's Discretion

User nie wybrał szczegółów estetycznych/poziomu detail — Claude działa po sensownych defaultach:

- **Format `bench/wyniki.md` tabel** — zwykły markdown table, bez multikolumnowych pivot'ów. Każdy bench dostaje swoją sekcję z `### bench_xxx`. Statystyki sformatowane przez `@sprintf` (`%.3f` dla times, `%.4f` dla ratio).
- **Layout `examples/podstawowy.jl` header** — krótki polski docstring na top of file (3-4 linijki: cel skryptu, jak uruchomić, oczekiwane zachowanie). Konwencja jak `src/wizualizacja.jl` Phase 3.
- **Pomocnicze funkcje w `bench/run_all.jl`** — np. `_zbierz_metadane()::String` (sysinfo), `_renderuj_tabele(wyniki::Dict)::String`. Prefiksowane `_` zgodnie z Phase 3 D-09 conventions.
- **Strategia warmup w benchmarkach** — `BenchmarkTools.@benchmark setup=(stan = ...; symuluj_krok!(stan, params, alg))` (warmup wewnątrz setup) — standardowa dyscyplina. Plan precyzuje per-bench.
- **Lokalizacja headline'u w README** — pod sekcją „Benchmarki" jako wytłuszczona linijka. Może zmienić na sekcję „Highlights" przy planning, jeśli okaże się czytelniejsze.
- **Diagram ASCII struktury projektu w README** — z `.planning/codebase/STRUCTURE.md`, skrócony do top-level `src/`, `test/`, `examples/`, `bench/`, `assets/`, `.planning/` (ostatni z notą „project memory").
- **`Project.toml` dodanie BenchmarkTools do `[targets].test`** — konkretne miejsce edycji w plan execution; Aqua reuse istniejącej ignore listy.
- **NN baseline w `bench_jakosc`** — używamy `inicjuj_nn!(stan)` + `oblicz_energie(stan)` jako baseline (zgodnie z Phase 2 fixture pattern). NIE re-implementujemy.
- **Czy commitować bench/wyniki.md po regen** — TAK, zgodnie z D-06 wyniki commitowane (PROJECT D-25: aplikacja). Dev regeneruje przy każdym milestone-ready commit.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level decisions
- `.planning/PROJECT.md` — Core Value („wizualnie przekonująca, fizycznie umotywowana heurystyka"), constraints (LANG = polski), Active Requirements (DEMO + BENCH wciąż otwarte), key decisions (Manifest committed)
- `.planning/REQUIREMENTS.md` §"Demo (DEMO-01..04)" + §"Benchmark (BENCH-01..05)" + §"Polski język (LANG-02..03)" — 11 REQ-IDs locked dla Phase 4
- `.planning/ROADMAP.md` Phase 4 — Goal, Success Criteria 1–5 (`examples/podstawowy.jl`, `examples/eksport_mp4.jl`, `bench/{bench_energia,bench_krok,bench_jakosc}.jl`, `bench/wyniki.md`, README po polsku z GIF + bench numbers)
- `.planning/STATE.md` — locked decisions (TEST-05 ratio 0.9408, GLMakie compat 0.13, kroki_na_klatke=50 default), open question „CairoMakie fallback for headless CI" (deferred), aktywne TODOs („Polish-typography" → zamykane w D-18; „encoding CI guard" → zostaje deferred)

### Stack & technology
- `.planning/research/STACK.md` §"Recommended Stack" — `BenchmarkTools` 1.6 jako primary, `Chairmarks` jako optional alt (rejected dla Phase 4 — REQUIREMENTS.md BENCH-04 explicit)
- `.planning/research/STACK.md` §"What NOT to Use" — `Plots.jl` jako equal backend (Phase 3 zamknął: GLMakie-only); `FFMPEG_jll` direct dep (transitive via Makie — działa dla `.gif` eksportu)
- `.planning/research/PITFALLS.md` Pitfall 7 — GLMakie headless CI (D-17 świadomie deferred do v2)
- `.planning/research/PITFALLS.md` Pitfall 14 — sysimage trap (Phase 3 D-08 mitigated, Phase 4 nie wprowadza nowych)
- `.planning/research/PITFALLS.md` „BenchmarkTools `@btime` bez `$` interpolation" — adresowane przez BENCH-04 dyscyplinę

### Phase 3 carry-forward dependencies
- `.planning/phases/03-visualization-export/03-CONTEXT.md` D-09 — `wizualizuj(...; eksport=path)` API: extension detection (`.gif`/`.mp4`), `Makie.record(...)` z `ProgressMeter`. Examples Phase 4 KONSUMUJĄ to API niezmienione.
- `.planning/phases/03-visualization-export/03-CONTEXT.md` D-10 — file-exists hard-fail policy (Phase 4 D-04 świadomie obchodzi w skrypcie demo przez pre-rm)
- `.planning/phases/03-visualization-export/03-CONTEXT.md` D-12 — eksport długość = `liczba_krokow / KROKI_NA_KLATKE` klatek; freeze last frame przy patience early-stop
- `.planning/phases/03-visualization-export/03-CONTEXT.md` D-08 — TTFP @info messages (examples nie duplikują, Phase 4 D-13 dodaje TYLKO post-SA summary)
- `.planning/phases/03-visualization-export/03-CONTEXT.md` D-06 — „GOTOWE" overlay już ratio'em z Phase 3; Phase 4 examples summary do stdout NIE duplikuje overlay'u

### Phase 1 + 2 carry-forward dependencies
- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` D-21 — encoding hygiene NFC + BOM-free → README.md i CONTRIBUTING.md typography (Phase 4 D-18) wymaga NFC
- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` D-23 — ASCII-only file names → `examples/podstawowy.jl`, `examples/eksport_mp4.jl`, `bench/bench_*.jl`, `bench/run_all.jl`, `bench/historyczne/` — wszystkie ASCII
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` „D-03 erratum (plan 02-14)" — TEST-05 ratio 0.9408, T_zero=0.001 override, 125_000 kroków limit; bench_jakosc używa tego samego pattern fixture (z 50_000 kroków per D-08)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` D-06 — `StanSymulacji` shape LOCKED → benchmarks i examples konsumują stan READ-ONLY (poza `symuluj_krok!`)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` D-08 — `oblicz_energie` zero-alloc po warmup → `bench_energia` musi mieć warmup w `setup=` przed pomiarami

### Codebase snapshot (read at planning, may have shifted)
- `.planning/codebase/STRUCTURE.md` — drzewko (Phase 4 dodaje pliki w `examples/`, `bench/`, `assets/`)
- `.planning/codebase/INTEGRATIONS.md` (jeśli istnieje, planner odczyta) — relacje między modułami
- `Project.toml` — bieżący stan deps (`BenchmarkTools` w `[extras]` i `[compat]` ALE NIE w `[targets].test` — Phase 4 D-10 dodaje)

### External docs (LIVE during planning)
- https://juliaci.github.io/BenchmarkTools.jl/stable/ — `@benchmark`, `setup=`, `$` interpolation, `BenchmarkTools.save/load`
- https://docs.makie.org/stable/explanations/animation/ — `record()` z `.gif` extension (FFMPEG_jll transitive)
- https://docs.julialang.org/en/v1/stdlib/Pkg/ — `[targets].test`, `Project.toml [extras]` semantyka
- https://discourse.julialang.org/t/best-practices-for-benchmark-folder-structure/ — bench/Project.toml vs [extras] (referencja przy planning, gdyby plan_count rośnie)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`src/JuliaCity.jl` exports** (Phase 1+2+3): `Punkt2D, StanSymulacji, Algorytm, generuj_punkty, oblicz_energie, symuluj_krok!, wizualizuj, Parametry, SimAnnealing, inicjuj_nn!, trasa_nn` (lub równoważne — planner zweryfikuje aktualną listę). Phase 4 examples konsumują pełen public API, bez nowych eksportów.
- **`src/baselines.jl::trasa_nn(D)`** + **`inicjuj_nn!(stan)`** — `bench_jakosc.jl` używa do baseline ratio: `nn_route = trasa_nn(stan.D); nn_energy = oblicz_energie(stan.punkty, nn_route); ratio = stan.energia / nn_energy`.
- **`src/algorytmy/simulowane_wyzarzanie.jl::SimAnnealing` + `uruchom_sa!`** — `bench_jakosc.jl` używa `uruchom_sa!(stan, params, alg)` (tak samo jak Phase 2 TEST-05); zwraca po patience stop lub max_kroki. Wstawia `T_zero=0.001` jeśli reproducing TEST-05 pattern.
- **`src/wizualizacja.jl::wizualizuj(stan, params, alg; liczba_krokow, fps, kroki_na_klatke, eksport)`** — examples konsumują niezmienione (Phase 3 D-09). `examples/eksport_mp4.jl` przekazuje `eksport="assets/demo.gif"` po pre-rm.
- **`src/punkty.jl::generuj_punkty(n; seed)`** — bezstanowe, deterministyczne (Phase 1 PKT-01..04). examples używają `seed=42` (matchuje testy + reproducibility).

### Established Patterns

- **`module JuliaCity` + `include()`** — Phase 4 NIE dodaje plików do `src/`; tylko `examples/`, `bench/`, `CONTRIBUTING.md` update + `assets/demo.gif` + `Project.toml` `[targets].test` extension. Pure additive zewnętrznie.
- **ASCII-only file names** (Phase 1 D-23) — wszystkie nowe pliki: `examples/podstawowy.jl`, `examples/eksport_mp4.jl`, `bench/bench_energia.jl`, `bench/bench_krok.jl`, `bench/bench_jakosc.jl`, `bench/run_all.jl`, `bench/historyczne/diagnostyka_test05*.jl` (po przeniesieniu).
- **Polski docstring + komentarze, ASCII identyfikatory** (Phase 1 LANG-01) — `function main(); ...; end` w examples; pomocnicze prefixed `_` w `bench/run_all.jl`.
- **`function main(); body; end; main()` wrapper w examples** (Phase 4 DEMO-03 + ROADMAP SC #1) — unika top-level slowdown, działa z `julia --project=. --threads=auto examples/podstawowy.jl`.
- **`@info` po polsku, `@error`/`@warn` po polsku** (LANG-02 + Phase 3 D-04 conventions) — examples banner i timing summary po polsku.
- **Type stability rygorystyczne** (Phase 2 TEST-07 JET) — bench_jakosc/krok/energia muszą używać konkretnych typów, NIE `Any` containers. `BenchmarkTools.@benchmark` z `$` interpolation eliminuje boxing.
- **Manifest.toml committed** (PROJECT D-25) — Phase 4 może wymagać regeneracji jeśli `[targets].test` extension wymusi resolver work; Manifest committed.

### Integration Points

- **`Project.toml` `[targets].test`** — line 45: `test = ["Aqua", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]` — Phase 4 dodaje `"BenchmarkTools"`. Aqua TEST-06 ignore lista pozostaje (BenchmarkTools już w `[extras]` i `[compat]`).
- **`.gitignore`** — Phase 4 dodaje regułę: `assets/*` + `!assets/demo.gif`. Sprawdzić czy `bench/wyniki.md` nie jest ignorowany (powinien być commitowany).
- **`.gitattributes`** — Phase 1 ustanawia `*.gif binary` i `*.mp4 binary` (per `.planning/codebase/STRUCTURE.md`); Phase 4 NIE zmienia.
- **`README.md`** — pełen rewrite (obecny zawiera tylko Phase 1 status, brak GIF, brak bench numbers). Phase 4 zastępuje 9-sekcyjną wersją (D-15).
- **`CONTRIBUTING.md`** — dodanie `§4. Typografia polska` (D-18). Plan musi czytać obecne sekcje (encoding rules + GSD workflow) i appendnąć bez zmiany istniejących.
- **Brak modyfikacji w `src/{punkty.jl, energia.jl, baselines.jl, algorytmy/, typy.jl, JuliaCity.jl, wizualizacja.jl}`** — Phase 1+2+3 PHASE COMPLETE markers preserved. Pure additive change w `examples/` + `bench/` + dokumentacja.
- **`test/runtests.jl`** — bez zmian (Phase 4 NIE dodaje testów core; encoding-validation guard pozostaje deferred per D-19).

</code_context>

<specifics>
## Specific Ideas

- **„Trasa zaciska się jak bańka mydlana"** (PROJECT.md core value) — Phase 4 README sekcja „Algorytm" wyraźnie eksponuje tę metaforę (1 paragraf), parząc z osadzonym GIF który ją wizualizuje. Headline section „Benchmarki" pokazuje liczby uzasadniające: SA ~6% pod NN.
- **`assets/demo.gif` 10s ~3-5 MB** (D-02) — sweet spot README UX: auto-play na GitHubie, akceptowalny size dla `git clone`, krótki dla user attention span. Nie próbuje pokazać pełnego SA (33s = nudne pod koniec); skupia się na pierwszych 15 000 krokach gdzie dzieje się wizualnie najwięcej.
- **Headline number „SA znajduje trasę średnio ~6% krótszą niż NN"** (D-08 + README D-15 §7) — konkretny marketing claim oparty na 5 seedach × N=1000. Liczba dopasowuje się do TEST-05 lock 0.9408 (Phase 2 plan 02-14). Plan może zaktualizować po empirycznej weryfikacji w Phase 4.
- **`bench/historyczne/`** dla diagnostyka_test05*.jl (D-16) — polska nazwa folderu (jak `algorytmy/`), bez diakrytyków per LANG/D-23. Audit trail Phase 2 plan 02-14 erratum zachowany.
- **`function main(); ...; end; main()`** w examples (D-12) — DEMO-03 explicit, ROADMAP SC #1 explicit. Forma kanoniczna w Julia community dla scripts.
- **„GOTOWE" overlay w `wizualizuj()`** (Phase 3 D-06) + summary `@info "GOTOWE: ratio=$..."` w examples (Phase 4 D-13) — komplementarne: overlay w oknie GUI, @info w terminalu. Polskie „GOTOWE" jako konsekwentny brand-marker końca animacji.
- **CONTRIBUTING.md §4 Typografia polska** (D-18) — konkretne reguły: `„` = U+201E, `"` = U+201D, `—` = U+2014, NFC normalization, BOM-free. Krótka sekcja (10-20 linijek), z linkiem do `.editorconfig` (już ustawione w Phase 1).

</specifics>

<deferred>
## Deferred Ideas

- **xvfb / headless CI step dla auto-build `assets/demo.gif`** (D-17) — STATE.md open question pozostaje OPEN. v2 może dodać `examples/build_demo.sh` + GitHub Actions ubuntu+xvfb workflow + artifact upload. Wymaga rozwiązania Pitfall 7 (GLMakie OpenGL na headless CI flaky).
- **Encoding-validation CI guard test** (Phase 1 D-21 TODO) — wymaga osobnego designu (jakie pliki? co exactly violates? Aqua-style report?). Pozostaje TODO w STATE.md.
- **Threading scalability matrix w benchmarkach** (1/2/4/8) — D-09 świadomie wyłączone. v2 może dodać `bench/scalability.jl` z `BenchmarkTools.run` przez subprocess + matrix env.
- **Chairmarks zamiast BenchmarkTools** — D-10 reject (REQUIREMENTS.md BENCH-04 explicit). v2 może rozważyć migrację jeśli CI loop time zaczyna boleć.
- **Documenter.jl + GitHub Pages** — D-15 reject (alt option „Z osobnym docs/index.md"). v2 może dodać dla pełnej dokumentacji API + tutorials.
- **README sekcje „Architektura" + „FAQ" + „Roadmap v2"** — D-15 reject (alt „Bogaty"). Może być dodane w v2 milestone polish.
- **MP4 jako secondary alongside GIF** — D-01 reject (chose GIF only). v2 może dodać `assets/demo.mp4` jako bonus link „Zobacz w wyższej jakości".
- **ENV/ARGS parametryzacja examples** — D-11 reject (KISS, DEMO-04). v2 może dodać `JC_KROKI`, `JC_SEED` env vars dla power-users.
- **ArgParse.jl w examples** — D-11 reject (over-engineering). Nie jest planowane.
- **bench/Project.toml osobny env** — D-10 reject (over-engineering). v2 może rozważyć jeśli bench deps się rozszerzają.
- **`nadpisz::Bool` kwarg w `wizualizuj()`** — Phase 3 D-10 reject (KISS); Phase 4 D-04 obchodzi w skrypcie demo przez pre-rm. v2 może dodać kwarg do Phase 3 API.
- **Headline number jako badge w README** (np. `![ratio](https://img.shields.io/badge/SA%2FNN-0.94-green)`) — może być fajne v2 polish; v1 zostawiamy plain text dla prostoty.
- **Auto-suffix file naming dla examples/eksport_mp4.jl (`demo-1.gif`, `demo-2.gif`)** — Phase 3 D-10 deferred; Phase 4 D-04 pre-rm zamiast tego. v2 może dodać dla power-users.
- **Linux CI z xvfb dla README demo badge (always-fresh)** — D-17 reject. Powiązane z xvfb deferred.

### Reviewed Todos (not folded)

None — `list-todos` zwrócił 0 todos w bieżącej milestonie.

</deferred>

---

*Phase: 4-Demo, Benchmarks & Documentation*
*Context gathered: 2026-04-30*
