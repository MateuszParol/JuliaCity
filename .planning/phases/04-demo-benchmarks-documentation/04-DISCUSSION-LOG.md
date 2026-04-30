# Phase 4: Demo, Benchmarks & Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 4-demo-benchmarks-documentation
**Areas discussed:** A (demo format), B (bench format), C (demo scripts UX), D (README/cleanup/CI)

---

## A. Demo GIF/MP4 — format, długość, hosting

### A.1 — Format demo w README

| Option | Description | Selected |
|--------|-------------|----------|
| GIF jako główny, MP4 jako bonus (Recommended) | GIF auto-play + MP4 secondary link, oba commitowane | |
| Tylko MP4, link w README | Mniejszy plik, czystszy, brak auto-play (klik wymagany) | |
| Tylko GIF, prosty embed | Pojedynczy assets/demo.gif, README ![](assets/demo.gif), 8-15 MB dla 33s | ✓ |
| Oba osobnymi skryptami (eksport_mp4 + eksport_gif) | Rozdzielenie, README embed GIF, link MP4 | |

**User's choice:** Tylko GIF, prosty embed
**Notes:** README UX wygrywa; akceptujemy size penalty. Wymaga rozważenia długości demo (Q2).

### A.2 — Długość demo + nazwa skryptu eksportującego

| Option | Description | Selected |
|--------|-------------|----------|
| Pełne 33s (50_000 kroków), zachowana nazwa eksport_mp4.jl | 1000 klatek, ~8-12 MB GIF | |
| Krótsze ~10s (15_000 kroków), zachowana nazwa (Recommended) | 300 klatek, ~3-5 MB README-friendly, szybsze CI | ✓ |
| Pełne 33s, rename → examples/eksport_gif.jl | Nazwa odpowiada formatowi, zmiana REQUIREMENTS+ROADMAP | |
| Konfigurowalne przez ENV/ARGS — default krótki | JC_KROKI/JC_OUT z fallbackami | |

**User's choice:** Krótsze ~10s (15_000 kroków), zachować nazwę examples/eksport_mp4.jl
**Notes:** README-friendly, zachowana zgodność z REQUIREMENTS.md DEMO-02 i ROADMAP SC #2 (oba dopuszczają .gif).

### A.3 — Regen + .gitignore polityka assets/

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-rm assets/demo.gif w skrypcie + commit demo.gif (Recommended) | Skrypt obchodzi D-10 świadomie, .gitignore: assets/* + !assets/demo.gif | ✓ |
| Skrypt fail-fast + manualny rm + commit | D-10 propagated, więcej friction | |
| Timestamped output (assets/demo-YYYYMMDD.gif) | Brak kolizji, akumulacja plików | |
| ENV[\"JC_NADPISZ\"]=1 dla overwrite | Domyślnie fail, wybór user | |

**User's choice:** Pre-rm assets/demo.gif w skrypcie + commit demo.gif
**Notes:** Demo skrypt = świadoma regeneracja; D-10 hard-fail z Phase 3 chroni API-level overwrite, examples to inny use case.

---

## B. Benchmarks — format wyników i reprodukowalność

### B.1 — Generowanie bench/wyniki.md

| Option | Description | Selected |
|--------|-------------|----------|
| bench/run_all.jl auto-regeneruje wyniki.md (Recommended) | Single entry point, header z metadata, markdown table | ✓ |
| Per-script append do wyniki.md | Idempotentny replace by section heading, brak orchestratora | |
| Manual edit — skrypty tylko printują | Najprostsze, podatne na rozjazdy | |
| BenchmarkTools.save() do wyniki.json + osobny render | Hist trend tracking, więcej złożoności | |

**User's choice:** bench/run_all.jl auto-regeneruje wyniki.md
**Notes:** Single command reproduction: julia --project=. --threads=auto bench/run_all.jl

### B.2 — Metryki + seedy + threading matrix

| Option | Description | Selected |
|--------|-------------|----------|
| Median + alokacje + hardware spec inline (Recommended) | bench_jakosc 5 seedów (mean±std+min/max), --threads=auto only | ✓ |
| Median + min + std + matrix 1/2/4 | 3 kolumny scalability, 5 seedów | |
| Tylko median + alokacje, 3 seedy | Minimum, najszybszy CI | |
| Median + percentile (p25/p50/p75), 10 seedów | Statystyczna głębia, długi czas | |

**User's choice:** Median + alokacje + hardware spec inline; 5 seedów [42, 123, 456, 789, 2025]
**Notes:** Bez matrix scalability (perf hipster trap dla v1). Hardware spec w header'ze wyniki.md.

### B.3 — BenchmarkTools wciągany do bench/

| Option | Description | Selected |
|--------|-------------|----------|
| BT w [extras]+[targets].test (Recommended) | Obecny stan + dodanie do targets.test | ✓ |
| Osobny bench/Project.toml env | Czysta separacja, Manifest dla bench | |
| BT w [deps] główne | Najprostsze, ale Aqua false-positive | |
| Chairmarks zamiast BenchmarkTools | ~100x szybsze, wymaga zmiany REQUIREMENTS | |

**User's choice:** BenchmarkTools w [extras]+[targets].test (extension obecnego setupu)
**Notes:** Zgodne z REQUIREMENTS.md BENCH-04 (BenchmarkTools explicit). Project.toml line 45 wymaga edycji.

---

## C. Demo scripts — parametryzacja i UX

### C.1 — Parametryzacja examples

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcoded sensible defaults, komenty (Recommended) | Zero ENV/ARGS, DEMO-04 KISS | ✓ |
| ENV vars (JC_N, JC_SEED, JC_KROKI) | Defaults + override, więcej code | |
| ARGS + getopts (ArgParse.jl) | Pełen CLI, dodatkowy dep | |
| examples/config.jl shared include | DRY ale over-engineering dla 4 stałych | |

**User's choice:** Hardcoded sensible defaults
**Notes:** DEMO-04 wymaga „bez dodatkowych przygotowań". Komentarze polskie pokazują jak edytować.

### C.2 — Stdout messaging

| Option | Description | Selected |
|--------|-------------|----------|
| Banner + timing summary po SA stop (Recommended) | @info na start + GOTOWE summary po wizualizuj() | ✓ |
| Minimalne — tylko Phase 3 @info | Brak summary po zamknięciu okna | |
| Verbose — progres co N kroków | Redundancja z overlay GUI | |
| Quiet — żadne @info | Zabija debug-by-grep | |

**User's choice:** Banner + timing summary po SA stop
**Notes:** LANG-02 (polski). Phase 3 wizualizuj() już ma TTFP @info — examples dodają tylko summary.

---

## D. README, cleanup, CI

### D.1 — README.md struktura

| Option | Description | Selected |
|--------|-------------|----------|
| Standard Julia + GIF + benchmarks (Recommended) | 9 sekcji: header/GIF/wymagania/install/quickstart/algorytm/bench/struktura/licencja | ✓ |
| Minimalny: GIF + quickstart + bench link + licencja | 4 sekcje, brak kontekstu | |
| Bogaty z architekturą + FAQ + roadmap | Dodaj sekcje, maintenance burden | |
| Z osobnym docs/index.md (Documenter.jl-ready) | Pre-setup, YAGNI dla v1 | |

**User's choice:** Standard Julia package + GIF + benchmarks
**Notes:** Wszystko po polsku (LANG-03). Headline number w sekcji „Benchmarki".

### D.2 — Historical bench files + xvfb CI

| Option | Description | Selected |
|--------|-------------|----------|
| Przenieś do bench/historyczne/ + brak xvfb (Recommended) | Audit trail zachowany, CI bez zmian | ✓ |
| Usuń diagnostyka_test05*.jl + brak xvfb | git history zachowuje, czysty bench/ | |
| Zostaw in-place + xvfb CI artifact | Pełna automatyzacja, Pitfall 7 ryzyko | |
| Przenieś + xvfb CI (full Phase 4) | Both: cleanup + artifact pipeline | |

**User's choice:** Przenieś do bench/historyczne/ + brak xvfb CI
**Notes:** STATE.md open question „CairoMakie/xvfb" pozostaje deferred do v2. GIF buildowany lokalnie, commitowany ręcznie.

### D.3 — Polish typography + niesione TODOs

| Option | Description | Selected |
|--------|-------------|----------|
| Typography + sekcja w CONTRIBUTING (Recommended) | „..." em-dash NFC + §4 w CONTRIBUTING.md, zamyka 1 STATE.md TODO | ✓ |
| Typografia w README ale bez konwencji | Tylko pisz poprawnie, TODO open | |
| + encoding CI guard test (Phase 1 D-21) | Zamyka 2 TODOs jednym ruchem, więcej code | |
| Wszystkie TODOs deferred | Czysty fokus na DEMO/BENCH/LANG-03 | |

**User's choice:** Polish typography + udokumentowanie konwencji w CONTRIBUTING.md §4
**Notes:** Encoding-validation CI guard test (Phase 1 D-21) pozostaje deferred — wymaga osobnego designu.

---

## Claude's Discretion

User pozostawił następujące szczegóły do Claude'a / planera:

- Format markdown table'i w `bench/wyniki.md` (płaskie sekcje, `@sprintf` discipline)
- Layout `examples/podstawowy.jl` header (krótki polski docstring jak `src/wizualizacja.jl`)
- Pomocnicze funkcje w `bench/run_all.jl` (`_zbierz_metadane`, `_renderuj_tabele`, prefiksowane `_`)
- Strategia warmup w benchmarkach (`BenchmarkTools.@benchmark setup=`)
- Lokalizacja headline'u w README (pod sekcją „Benchmarki" jako wytłuszczone bullet)
- Diagram ASCII struktury projektu w README (skrót ze STRUCTURE.md, top-level)
- Konkretne miejsce edycji `Project.toml` `[targets].test`
- NN baseline w `bench_jakosc` przez `inicjuj_nn!` + `oblicz_energie` (Phase 2 fixture pattern)
- Czy commitować bench/wyniki.md (TAK, zgodnie z PROJECT D-25 application convention)

## Deferred Ideas

(Pełna lista w `04-CONTEXT.md` <deferred> sekcji.)

Najważniejsze:
- xvfb / headless CI dla auto-build assets/demo.gif (STATE.md open question pozostaje)
- Encoding-validation CI guard test (Phase 1 D-21, wymaga osobnego designu)
- Threading scalability matrix w bench (v2)
- Chairmarks migration (v2)
- Documenter.jl + GitHub Pages (v2)
- README rozszerzenia (Architektura, FAQ, Roadmap v2)
- MP4 jako secondary alongside GIF (v2)
- ENV/ARGS parametryzacja examples (v2)
- bench/Project.toml osobny env (v2)
- `nadpisz::Bool` kwarg w `wizualizuj()` (v2)
- README badge dla ratio number (v2 polish)
- Auto-suffix dla examples/eksport_mp4.jl (v2)

## Carrying TODOs (status po Phase 4)

| TODO | Pochodzenie | Status po Phase 4 |
|------|-------------|-------------------|
| Polish-typography convention | STATE.md (Phase 4 deferred) | ✅ Zamknięty (D-18) |
| Encoding-validation CI guard test | STATE.md (Phase 1 D-21) | ⏳ Pozostaje deferred (D-19) |
| CairoMakie fallback for headless CI | STATE.md open question (Phase 3+4) | ⏳ Pozostaje deferred do v2 (D-17) |
| Manifest.toml committed | STATE.md (Phase 1 D-25) | ✅ Zamknięty w Phase 3 (255 packages) |
