# Phase 4: Demo, Benchmarks & Documentation — Pattern Map

**Mapped:** 2026-04-30
**Files analyzed:** 13 (10 NEW, 3 MODIFIED) + 1 directory (NEW)
**Analogs found:** 13 / 13 (100% — wszystkie nowe pliki maja konkretny analog w kodzie Phase 1-3)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/podstawowy.jl` (NEW) | demo-script (live) | request-response (blocking GUI) | `src/wizualizacja.jl` (consumer), `bench/diagnostyka_test05.jl` (script form) | exact |
| `examples/eksport_mp4.jl` (NEW) | demo-script (export) | request-response + file-I/O | `src/wizualizacja.jl::_export_loop` (caller pattern), `bench/diagnostyka_test05.jl` | exact |
| `bench/bench_energia.jl` (NEW) | microbench | batch-measure | `bench/diagnostyka_test05.jl` (fixture pattern) + `test/test_energia.jl` (zero-alloc helper pattern) | role-match |
| `bench/bench_krok.jl` (NEW) | microbench | batch-measure | `test/test_symulacja.jl` lines 60-85 (zero-alloc helper) + `bench/diagnostyka_test05.jl` | role-match |
| `bench/bench_jakosc.jl` (NEW) | quality-bench | batch-aggregate | `bench/diagnostyka_test05.jl::eksperymenty()` (multi-seed sweep) + `test/test_baselines.jl` TEST-05 | exact |
| `bench/run_all.jl` (NEW) | orchestrator | sequential-include + report-generate | none (zero-of-this-kind in repo) — closest is `test/runtests.jl` (sequential `include`) + bench scripts (single-runs) | role-match (composite) |
| `bench/wyniki.md` (NEW, generated) | doc (generated) | output-only (markdown table) | none (generated; format prescribed by D-07) | no analog (RESEARCH/D-07 dictates) |
| `bench/historyczne/` (NEW dir) | archive | move-only | none (first archive folder) | no analog |
| `README.md` (REWRITE) | doc (top-level) | static markdown | `CONTRIBUTING.md` (Polish typography + section heading style) + obecne `README.md` (krotki, bedzie nadpisane) | role-match |
| `CONTRIBUTING.md` (UPDATE — append §4) | doc (top-level) | static markdown | `CONTRIBUTING.md` §1-3 (style sekcji do skopiowania) | exact (same file) |
| `Project.toml` (MODIFY) | config | declarative TOML edit | `Project.toml` lines 33-44 (existing `[extras]` + `[targets]` block) | exact (same file) |
| `.gitignore` (MODIFY) | config | declarative ignore-rules edit | `.gitignore` lines 26-31 (existing comment-block style) | exact (same file) |
| `assets/demo.gif` (NEW BINARY) | asset | binary file | `.gitattributes` line 13 (`*.gif binary`) — already configured Phase 1 | exact (config already in place) |

---

## Pattern Assignments

### `examples/podstawowy.jl` (demo-script, live)

**Analog 1 — call-site pattern:** `src/wizualizacja.jl` lines 432-465 (consumer of `wizualizuj` API)
**Analog 2 — script form + Polish header:** `bench/diagnostyka_test05.jl` lines 1-22 (header docstring + `using` block + `function ... end` body)
**Analog 3 — fixture build:** `bench/diagnostyka_test05.jl` lines 59-69 (`fresh_stan_with_nn`)

**Header docstring pattern** (z `bench/diagnostyka_test05.jl` lines 1-19, ten sam styl: 1 linia tytulu + 4-5 linii kontekstu + `Uruchomienie:` blok):

```julia
# examples/podstawowy.jl
#
# Live demo SA-2-opt na 1000 punktach (Phase 4 DEMO-01..04, LANG-02).
# Otwiera okno GLMakie z dual-panel layoutem, animuje proces zaciagania trasy.
# Hardcoded sensible defaults: N=1000, seed=42, 50_000 krokow, 33s @30fps (D-11).
# Bez ENV/ARGS — edytuj stale ponizej zeby zmienic dlugosc demo.
#
# Uruchomienie:
#   julia --project=. --threads=auto examples/podstawowy.jl
```

**`function main(); ...; end; main()` wrapper** (DEMO-03 + D-12 LOCKED — szkielet do kazdego pliku w `examples/`):

```julia
using JuliaCity
using Random: Xoshiro

function main()
    # Hardcoded sensible defaults (D-11) — komentarze polskie nad kazda stala
    N = 1000                  # liczba punktow (PROJECT.md core value)
    SEED = 42                 # deterministyczny seed (D-11)
    LICZBA_KROKOW = 50_000    # 33s @ 30fps (D-11 + D-13)
    KROKI_NA_KLATKE = 50      # throttling (Phase 3 D-05)
    FPS = 30                  # unified live i eksport (Phase 3 D-11)

    # D-13: banner @info na starcie
    @info "JuliaCity demo — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

    # Build fixture (analog bench/diagnostyka_test05.jl::fresh_stan_with_nn lines 59-64)
    punkty = generuj_punkty(N; seed=SEED)
    stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
    inicjuj_nn!(stan)
    energia_nn = stan.energia                    # captured PRZED SA dla post-summary ratio
    alg = SimAnnealing(stan)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=LICZBA_KROKOW)

    # Live demo (Phase 3 D-09 API consumer — eksport=nothing)
    t_start = time()
    wizualizuj(stan, params, alg;
               liczba_krokow=LICZBA_KROKOW,
               fps=FPS,
               kroki_na_klatke=KROKI_NA_KLATKE)
    dt = time() - t_start

    # D-13: post-SA summary @info (NIE duplikuje overlay'u "GOTOWE" z Phase 3 D-06)
    ratio = round(stan.energia / energia_nn; digits=4)
    @info "GOTOWE: ratio=$ratio, czas=$(round(dt, digits=2))s, krokow=$(stan.iteracja)"

    return nothing
end

main()
```

**Krytyczne reguly do skopiowania:**
- Polski docstring nad `function main()` zgodnie z `CONTRIBUTING.md` §3 (komentarze i docstringi po polsku)
- Asercje wewnetrzne w przyszlosci: angielski (LANG-04 — patrz `src/wizualizacja.jl` line 344-346 `@assert liczba_krokow > 0 "liczba_krokow must be positive"`)
- ASCII-only nazwy pol / zmiennych (`KROKI_NA_KLATKE` nie `KROKI_NA_KLATKĘ`) — Phase 1 D-23
- `@info` po polsku (LANG-02) — patrz `src/wizualizacja.jl` line 282 `@info "Eksport do $sciezka..."`

---

### `examples/eksport_mp4.jl` (demo-script, export)

**Analog 1 — call-site pattern:** `src/wizualizacja.jl` lines 432-465 (consumer)
**Analog 2 — pre-rm policy:** `src/wizualizacja.jl` line 270-272 (file-exists hard error — D-04 OBCHODZI ten patten przez `isfile() && rm()`)
**Analog 3 — Polish error/info messages:** `src/wizualizacja.jl` lines 282, 456-458

**Pre-rm pattern (Phase 4 D-04 — swiadomie obchodzi Phase 3 D-10 hard-fail):**

```julia
# D-04: pre-rm istniejacego pliku (swiadoma regeneracja, NIE accident overwrite).
# Phase 3 D-10 hard-fail (line 270 wizualizacja.jl) chroni API users; demo skrypt
# = explicit regen, wiec usuwamy plik przed wywolaniem wizualizuj().
isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)
```

**Pelny szkielet:**

```julia
# examples/eksport_mp4.jl
#
# Eksport krotkiego ~10s demo SA-2-opt do assets/demo.gif (Phase 4 DEMO-02, D-01..D-05).
# UWAGA: Pomimo nazwy "eksport_mp4", produkujemy GIF — D-01 wybiera GIF dla auto-play
# w README (embed `![](assets/demo.gif)`). Nazwa zachowana zgodnie z REQUIREMENTS DEMO-02
# i ROADMAP Phase 4 SC #2 (oba dopuszczaja .gif).
#
# Uruchomienie:
#   julia --project=. --threads=auto examples/eksport_mp4.jl

using JuliaCity
using Random: Xoshiro

function main()
    # D-02 + D-11: 15_000 krokow / 50 = 300 klatek / 30fps = 10s GIF (~3-5 MB)
    N = 1000
    SEED = 42
    LICZBA_KROKOW = 15_000
    KROKI_NA_KLATKE = 50
    FPS = 30
    SCIEZKA_GIF = "assets/demo.gif"

    @info "JuliaCity eksport GIF — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

    # D-04: pre-rm istniejacego pliku (swiadoma regeneracja vs Phase 3 D-10 hard-fail)
    isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)

    # Build fixture
    punkty = generuj_punkty(N; seed=SEED)
    stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
    inicjuj_nn!(stan)
    energia_nn = stan.energia
    alg = SimAnnealing(stan)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=LICZBA_KROKOW)

    t_start = time()
    wizualizuj(stan, params, alg;
               liczba_krokow=LICZBA_KROKOW,
               fps=FPS,
               kroki_na_klatke=KROKI_NA_KLATKE,
               eksport=SCIEZKA_GIF)
    dt = time() - t_start

    ratio = round(stan.energia / energia_nn; digits=4)
    @info "GOTOWE eksport: $SCIEZKA_GIF, ratio=$ratio, czas=$(round(dt, digits=2))s"

    return nothing
end

main()
```

---

### `bench/bench_energia.jl` (microbench)

**Analog 1 — fixture build:** `bench/diagnostyka_test05.jl` lines 59-69 (`fresh_stan_with_nn`)
**Analog 2 — zero-alloc helper convention:** `test/test_symulacja.jl` lines 76-79 (`function _alloc_krok(stan, params, alg)`)
**Analog 3 — Polish header docstring:** `bench/diagnostyka_test05.jl` lines 1-19

**`@benchmark` z `$` interpolation + `setup=` discipline (BENCH-04 — wymog explicit):**

Tutaj brakuje bezposredniego analoga w repo (nie ma jeszcze BenchmarkTools w uzyciu). Zrodlo wzorca: `https://juliaci.github.io/BenchmarkTools.jl/stable/` + decyzja D-07. Patten do zaimplementowania:

```julia
# bench/bench_energia.jl
#
# Microbench `oblicz_energie` na fixture N=1000 (Phase 4 BENCH-01, BENCH-04).
# Mierzy median time + memory + alokacje (D-07).
#
# Uruchomienie standalone:
#   julia --project=. --threads=auto bench/bench_energia.jl
# Lub przez orchestrator:
#   julia --project=. --threads=auto bench/run_all.jl

using JuliaCity
using BenchmarkTools
using Random: Xoshiro

function main()
    # Fixture (analog bench/diagnostyka_test05.jl::fresh_stan_with_nn)
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    bufor = zeros(Float64, Threads.nthreads())

    # BENCH-04: $ interpolation + setup (Phase 2 D-08 zero-alloc po warmup —
    # warmup zaszyty wewnatrz BenchmarkTools default samples).
    # Phase 4 D-07: median time + memory + allocs.
    wynik = @benchmark oblicz_energie($stan.D, $stan.trasa, $bufor)

    # Wynik zwracany do orchestratora przez Serialization (D-06) lub print do stdout.
    return wynik
end

# Standalone run: drukuj wynik
if abspath(PROGRAM_FILE) == @__FILE__
    wynik = main()
    show(stdout, MIME"text/plain"(), wynik)
    println()
end
```

**Klucz:** `$stan.D`, `$stan.trasa`, `$bufor` — interpolacja eliminuje boxing globals (RESEARCH PITFALL "BenchmarkTools `@btime` bez `$` interpolation"). Plan musi sprawdzic czy `oblicz_energie(stan.D, stan.trasa, bufor)` 3-arg signature jest aktualna (`src/energia.jl` line 71 ma 2-arg, 3-arg wersja istnieje — patrz `src/baselines.jl` line 99 `oblicz_energie(stan.D, stan.trasa, bufor)`).

---

### `bench/bench_krok.jl` (microbench)

**Analog 1 — zero-alloc helper:** `test/test_symulacja.jl` lines 76-85 (warmup + `_alloc_krok`)
**Analog 2 — fixture:** `bench/diagnostyka_test05.jl` lines 59-69

**Pattern (warmup w `setup=` + per-step measurement):**

```julia
using JuliaCity
using BenchmarkTools
using Random: Xoshiro

function main()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=50_000)

    # BENCH-04: setup discipline. Warmup wbudowany — first sample includes
    # JIT cost; BenchmarkTools dyskwalifikuje pierwsza probke automatycznie.
    # Phase 2 TEST-03 gwarantuje @allocated == 0 (test_symulacja.jl line 84).
    wynik = @benchmark symuluj_krok!($stan, $params, $alg) setup=(symuluj_krok!($stan, $params, $alg))

    return wynik
end
```

**Krytyczne:** `setup=(symuluj_krok!(...))` zapewnia ze stan jest w realnym runtime state (nie zero-state), zgodnie z Phase 2 D-08 (oblicz_energie zero-alloc po warmup) + Phase 2 TEST-03.

---

### `bench/bench_jakosc.jl` (quality-bench)

**Analog 1 — multi-seed sweep:** `bench/diagnostyka_test05.jl::eksperymenty()` lines 162-191
**Analog 2 — NN baseline ratio:** `test/test_baselines.jl` TEST-05 + `bench/diagnostyka_test05.jl` lines 169-180 (`ratio = energia_final / energia_nn`)
**Analog 3 — multi-seed loop:** `bench/diagnostyka_test05_random_vs_nn.jl` lines 64-80 (5 restartow z roznymi seedami)

**Excerpt z `bench/diagnostyka_test05.jl` lines 162-180 (do bezposredniej adaptacji):**

```julia
function eksperymenty(candidates::Vector{Float64}, n_steps::Int, energia_nn::Float64,
                       T0_calibrated::Float64)
    println("\n[diagnostyka] mini-runy SA ($(n_steps) krokow, NN-start, fresh stan):")
    results = Dict{Float64, NamedTuple}()
    for T0 in candidates
        r = mini_run_sa(T0, n_steps)
        ratio = r.energia_final / energia_nn
        # ...
    end
end
```

**Phase 4 adaptation (5 seedy × N=1000 × 50_000 krokow per D-08):**

```julia
using JuliaCity
using Random: Xoshiro
using Statistics: mean, std

function main()
    SEEDS = [42, 123, 456, 789, 2025]   # D-08
    N = 1000
    LICZBA_KROKOW = 50_000

    ratios = Float64[]

    for seed in SEEDS
        # Fixture per seed (analog bench/diagnostyka_test05.jl lines 59-69)
        punkty = generuj_punkty(N; seed=seed)
        stan = StanSymulacji(punkty; rng=Xoshiro(seed))
        inicjuj_nn!(stan)
        energia_nn = stan.energia               # NN baseline = stan.energia po inicjuj_nn!

        # SA run (D-08 + Phase 2 plan 02-14 erratum: T_zero=0.001 override)
        alg = SimAnnealing(stan; T_zero=0.001)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=LICZBA_KROKOW)
        uruchom_sa!(stan, params, alg)          # uruchom_sa! z patience stop (Phase 2)

        ratio = stan.energia / energia_nn
        push!(ratios, ratio)
        @info "seed=$seed: ratio=$(round(ratio, digits=4))"
    end

    # Aggregacja per D-08: mean ± std, min, max
    return (
        seeds = SEEDS,
        ratios = ratios,
        mean_ratio = mean(ratios),
        std_ratio = std(ratios),
        min_ratio = minimum(ratios),
        max_ratio = maximum(ratios),
    )
end
```

**Krytyczne reguly:**
- `T_zero=0.001` override (Phase 2 plan 02-14 erratum, `02-CONTEXT.md` D-03 — domyslna kalibracja `2σ` wyrzuca SA z basena NN-start)
- `uruchom_sa!` z patience stop, NIE goly `for _ in 1:N symuluj_krok!`
- Headline: `mean(ratios) ≈ 0.94`, std ≈ 0.01 (extrapolacja z TEST-05 ratio=0.9408)

---

### `bench/run_all.jl` (orchestrator)

**Analog 1 — sequential `include()` pattern:** `test/runtests.jl` lines 186-198 (`include("test_energia.jl")` itd.)
**Analog 2 — Polish formatted output:** `bench/diagnostyka_test05.jl` lines 74-77, 204-218 (`println("="^72)` separator + `[diagnostyka]` prefix)
**Analog 3 — _underscore helper convention:** Phase 3 `src/wizualizacja.jl` lines 46, 64, 91, 133 (`_trasa_do_punkty`, `_zbuduj_overlay_string`, `_setup_figure`, `_init_observables` — dokumentowane prefixed `_` per Phase 3 D-09 / Claude's Discretion w 04-CONTEXT.md)

**Excerpt z `test/runtests.jl` lines 186-198 (sequential include pattern):**

```julia
# 6. Energia (Plan 02-02 + Plan 02-05 testset-y)
include("test_energia.jl")

# 7. Baselines + TEST-05 NN-baseline-beat
include("test_baselines.jl")

# 8. Symulacja SA + TEST-01/03/04/08
include("test_symulacja.jl")
```

**Phase 4 adaptation — orchestrator z metadane + render markdown:**

```julia
# bench/run_all.jl
#
# Orchestrator suite'u benchmarkow Phase 4 (BENCH-01..05, D-06).
# Uruchamia bench_energia.jl, bench_krok.jl, bench_jakosc.jl, zbiera wyniki,
# generuje bench/wyniki.md z tabelarycznym podsumowaniem (D-07).
#
# Uruchomienie:
#   julia --project=. --threads=auto bench/run_all.jl

using JuliaCity
using BenchmarkTools
using Dates: now
using Printf: @sprintf

# Helpery wewnetrzne (prefiks `_` per Phase 3 D-09 + Claude's Discretion w 04-CONTEXT.md)
function _zbierz_metadane()::String
    julia_ver = string(VERSION)
    os = string(Sys.KERNEL)
    cpu = Sys.cpu_info()[1].model
    nthr = Threads.nthreads()
    timestamp = now()
    return """
- Julia: $julia_ver
- OS: $os
- CPU: $cpu
- Watki: $nthr
- Data: $timestamp
"""
end

function _renderuj_tabele(wyniki::Dict{String, Any})::String
    # Markdown table format (D-07 + Claude's Discretion: zwykla tabela bez pivotow)
    io = IOBuffer()
    println(io, "## Wyniki")
    println(io)
    println(io, "| Bench | Median time | Memory | Alokacje |")
    println(io, "|-------|-------------|--------|----------|")
    for (nazwa, t) in wyniki
        if t isa BenchmarkTools.Trial
            med_time = @sprintf("%.3f μs", median(t).time / 1000)
            mem      = @sprintf("%d B", median(t).memory)
            allocs   = string(median(t).allocs)
            println(io, "| $nazwa | $med_time | $mem | $allocs |")
        end
    end
    return String(take!(io))
end

function main()
    println("="^72)
    println("[run_all] Uruchamiam suite benchmarkow Phase 4 (BENCH-01..05)")
    println("="^72)

    wyniki = Dict{String, Any}()

    # Sekwencyjne wywolanie per-bench scripts (analog test/runtests.jl include pattern)
    println("\n[run_all] bench_energia.jl ...")
    wyniki["oblicz_energie"] = include("bench_energia.jl") |> identity  # zwraca Trial
    # ... bench_krok.jl, bench_jakosc.jl analogicznie

    # Render markdown do bench/wyniki.md
    metadane = _zbierz_metadane()
    tabela = _renderuj_tabele(wyniki)
    open(joinpath(@__DIR__, "wyniki.md"), "w") do io
        println(io, "# Wyniki benchmarkow JuliaCity")
        println(io)
        println(io, "## Srodowisko")
        println(io, metadane)
        println(io, tabela)
    end

    println("="^72)
    println("[run_all] GOTOWE — wyniki w bench/wyniki.md")
    println("="^72)
    return nothing
end

main()
```

**Klucz dla planu:**
- `Dates: now`, `Printf: @sprintf` (Claude's Discretion w 04-CONTEXT.md: `%.3f` dla times, `%.4f` dla ratio)
- `_zbierz_metadane()` + `_renderuj_tabele(...)` — prefixed `_` (Phase 3 D-09 + 04-CONTEXT)
- `Sys.cpu_info()[1].model`, `Sys.KERNEL`, `Threads.nthreads()`, `VERSION`, `Dates.now()` — wymaga D-07
- include vs subprocess: prosty `include` wystarczy dla 3 skryptow (orchestrator nie potrzebuje izolacji subprocesowej, bo wszystkie skrypty maja `function main()` wrapper i nie zanieczyszczaja globalnego scope'u)

---

### `bench/wyniki.md` (NEW, generated)

**Brak analoga w repo.** Format prescribed by D-07 + Claude's Discretion w 04-CONTEXT.md:
- Sekcja `## Srodowisko` z `_zbierz_metadane()` output (Julia version, OS, CPU, threads, date)
- Sekcja `## Wyniki` z markdown tabela per bench
- Sekcja `## Jakosc (bench_jakosc)` z mean ± std, min, max ratio
- Headline: "SA znajduje trase srednio ~6% krotsza niz NN baseline (5 seedow × N=1000)"

Plan moze wziac kontent metadane od formatowania orchestrators's `_zbierz_metadane()` output.

---

### `bench/historyczne/` (NEW directory)

**Brak analoga.** Move-only operation — przeniesc 3 pliki:
- `bench/diagnostyka_test05.jl` → `bench/historyczne/diagnostyka_test05.jl`
- `bench/diagnostyka_test05_budget.jl` → `bench/historyczne/diagnostyka_test05_budget.jl`
- `bench/diagnostyka_test05_random_vs_nn.jl` → `bench/historyczne/diagnostyka_test05_random_vs_nn.jl`

**Rekomendowane:** maly `bench/historyczne/README.md` (1 paragraf po polsku) wyjasniajacy kontekst Phase 2 plan 02-14 erratum + audit trail (D-16 explicit).

**ASCII-only directory name** (Phase 1 D-23): `historyczne/` — bez `historycznę/` z diakrytykiem. OK.

---

### `README.md` (REWRITE — 9 sekcji)

**Analog 1 — sekcje + styl:** `CONTRIBUTING.md` (struktura `## N. Tytul`, polski, NFC, inline code blocks)
**Analog 2 — Polish typography reference:** `CONTRIBUTING.md` lines 1-7 (header + 1-2 zdania kontekstu)
**Analog 3 — obecny `README.md`:** lines 11-23 (Wymagania + Instalacja sekcje — do przepisania w nowym ksztalcie)

**Excerpt z `CONTRIBUTING.md` lines 1-26 (Polish typography pattern do przeniesienia):**

```markdown
# Wkład w JuliaCity

Dziękujemy za zainteresowanie projektem! Poniżej zebrane są konwencje, których trzymamy się
we wszystkich plikach repozytorium.

## 1. Encoding plików
- **Kodowanie:** UTF-8, **bez BOM-a**.
- **Końce linii:** LF (`\n`).
```

**Phase 4 README skeleton (D-15 — 9 sekcji):**

```markdown
# JuliaCity

Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym.

![Demo SA na 1000 punktach](assets/demo.gif)

## Wymagania

- Julia ≥ 1.10 (zalecane: 1.11 lub 1.12)
- System: Linux / macOS / Windows

## Instalacja

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## Quickstart

```julia
using JuliaCity

# (a) Generowanie punktów
punkty = generuj_punkty(1000; seed=42)

# (b) Live demo (otwiera okno GLMakie)
stan = StanSymulacji(punkty)
inicjuj_nn!(stan)
alg = SimAnnealing(stan)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=50_000)
wizualizuj(stan, params, alg)

# (c) Eksport do GIF
wizualizuj(stan, params, alg; eksport="moje_demo.gif")
```

## Algorytm

SA-2-opt z metropolis acceptance + nearest-neighbor init + geometric cooling (α≈0.9999).
Metafora błony mydlanej — krawędzie trasy „ściągają się" do permutacji o minimalnej długości euklidesowej.

## Benchmarki

Pełne wyniki: [`bench/wyniki.md`](bench/wyniki.md).

**SA znajduje trasę średnio ~6% krótszą niż NN baseline** (5 seedów × N=1000).

## Struktura projektu

```
JuliaCity/
├── src/                    # Kod źródłowy (typy, energia, SA, wizualizacja)
├── test/                   # Test suite (230/230 PASS)
├── examples/               # Skrypty demo (live + eksport GIF)
├── bench/                  # Benchmarki (energia, krok, jakość)
├── assets/                 # Demo GIF (commitowany)
└── .planning/              # Pamięć projektu (GSD workflow)
```

## Licencja

MIT — patrz [`LICENSE`](LICENSE).
```

**Krytyczne reguly typografii (D-18 + Phase 1 D-21):**
- Cudzyslowy: „..." (U+201E + U+201D), NIE "..."
- Em-dash: — (U+2014), NIE -- albo --
- NFC normalization (encoding hygiene; runtests.jl test obecnie skanuje tylko `.jl`, ale CONTRIBUTING wspomina ze regula obejmuje wszystkie pliki user-facing)
- BOM-free, LF, final newline (CONTRIBUTING.md §1)

---

### `CONTRIBUTING.md` (UPDATE — append §4)

**Analog (this same file, sections §1-3):** `CONTRIBUTING.md` lines 7-79 — szablon sekcji do skopiowania.

**Wzor naglowka sekcji (z linii 28-44 CONTRIBUTING.md):**

```markdown
## 2. Nazwy plików — wyłącznie ASCII

Wszystkie nazwy plików w `src/`, `test/`, `examples/`, `bench/` są ASCII (znaki 0x20–0x7E).
**Brak polskich diakrytyków w ścieżkach** (`ą`, `ę`, `ł` itp.). Powód: niektóre Linux locale...
```

**Phase 4 §4 do dopisania PO §3 lines 78 (przed §5 GSD workflow lines 87+):**

```markdown
## 4. Typografia polska

User-facing strings (`README.md`, overlay w `wizualizacja.jl`, `@info`/`@error` po polsku) używają
**poprawnej polskiej typografii**:

| Znak | Kod | Użycie |
|------|-----|--------|
| `„` | U+201E | Otwierający cudzysłów dolny (rozpoczyna cytat) |
| `"` | U+201D | Zamykający cudzysłów górny (kończy cytat) |
| `—` | U+2014 | Em-dash (myślnik wprost — bez spacji wokół, jak tu) |
| `–` | U+2013 | En-dash (zakresy, np. „1–10") |

**NIE używamy:** prostych ASCII `"..."` w prozą, `--` (podwójny minus) zamiast `—`.

**Normalizacja:** wszystkie pliki tekstowe w **NFC** (composed). `.editorconfig` + encoding-guard
test w `test/runtests.jl` walidują dla `.jl`; konwencja obejmuje również `.md` (sprawdzane manualnie
w PR review).

**Zasada „BOM-free":** brak sygnatury 0xEF 0xBB 0xBF na początku — zgodnie z §1.

```

**Krytyczne:** §4 jest czysto append — NIE modyfikuje istniejacych §1, §2, §3, §5. Plan musi czytac obecny `CONTRIBUTING.md` i wstawic §4 PO linii 78 (koniec §3 — Polski/angielski split table) ale PRZED linia 80 (`## 4. Style przed commit` → renumerowane na `## 5.`, a `## 5. Workflow GSD` → `## 6.`). LUB (cleaner): wstawic miedzy §3 i §4 obecne i przerumerowac.

**Decyzja planu:** prostsze jest wstawic `## 4. Typografia polska` jako NOWA §4 i przerumerowac obecne §4 → §5, §5 → §6.

---

### `Project.toml` (MODIFY — add `BenchmarkTools` to `[targets].test`)

**Analog (this same file):** `Project.toml` lines 33-44 — istniejacy `[extras]` + `[targets]` blok.

**Excerpt obecnego stanu (lines 33-44):**

```toml
[extras]
Aqua = "4c88cf16-eb10-579e-8560-4a9242c79595"
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
PerformanceTestTools = "dc46b164-d16f-48ec-a853-60448fc869fe"
Serialization = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
StableRNGs = "860ef19b-820b-49d6-a774-d7a799459cd3"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
Unicode = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[targets]
test = ["Aqua", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
```

**Phase 4 D-10 modification (line 44):**

```toml
test = ["Aqua", "BenchmarkTools", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
```

(Zachowac kolejnosc alfabetyczna: `BenchmarkTools` po `Aqua`.)

**Krytyczne:** `BenchmarkTools` JUZ jest w `[extras]` (line 35) i `[compat]` (line 26). Plan dodaje TYLKO do `[targets].test` na linii 44.

**Sanity check** (Aqua TEST-06): obecny test (`test/runtests.jl` line 269-279) ma `project_extras = false` (intencjonalnie wylacza weryfikacje extras-vs-targets). Dodanie BenchmarkTools do `[targets].test` jest BEZPIECZNE — zaden Aqua kwarg nie wymaga zmiany.

---

### `.gitignore` (MODIFY — add `assets/*` + `!assets/demo.gif`)

**Analog (this same file):** `.gitignore` lines 26-31 (sekcja `# Test/diagnostic logs` + komentarz `# WAŻNE: ...`).

**Excerpt obecny (lines 26-31):**

```gitignore
# Test/diagnostic logs (transient artifacts — re-runable from bench/ scripts)
/test-output.log
/pkgtest*.log
/diag-*.log

# WAŻNE: Manifest.toml NIE jest tutaj — jest commitowany (per D-25, to jest aplikacja, nie biblioteka)
```

**Phase 4 D-05 addition (po linii 28 lub na koncu pliku — kolejnosc nie ma znaczenia, ale stylowo grupujemy z innymi assets):**

```gitignore
# Asset binaries (Phase 4 D-05) — commitujemy tylko canonical demo.gif,
# wszystkie inne lokalne artefakty developera (np. assets/test.mp4) ignorowane.
assets/*
!assets/demo.gif
```

**Krytyczne:** kolejnosc regul matters w gitignore — `assets/*` MUSI byc PRZED `!assets/demo.gif` (Git stosuje pattern-by-pattern, ostatni wygrywa dla danego pliku). Komentarz polski `# Phase 4 D-05` zachowuje audit trail.

---

### `assets/demo.gif` (NEW BINARY)

**Analog config:** `.gitattributes` line 13 — `*.gif binary`. **Juz skonfigurowane Phase 1, NIE wymaga zmiany.**

**Generowane przez:** `julia --project=. --threads=auto examples/eksport_mp4.jl` (manualnie przez dev'a po Phase 4 zakonczeniu).

**Krytyczne dla planu:**
- D-05 LOCKED: `assets/demo.gif` JEST commitowany do repo (rozmiar ~3-5 MB akceptowalny)
- D-17 LOCKED: brak xvfb CI step — GIF buildowany lokalnie i commitowany recznie
- Plan musi UTWORZYC `assets/` directory (obecnie nie istnieje — wymagaja `mkdir`)

---

## Shared Patterns

### Polish Comments + ASCII Identifiers (LANG-01, D-23, BOOT-04)

**Source:** `CONTRIBUTING.md` §3 lines 47-78 (table + przyklad z `src/typy.jl`)
**Apply to:** wszystkie nowe pliki `.jl` w `examples/` i `bench/`

**Excerpt z `CONTRIBUTING.md` §3 line 50-56 (locked rules):**

```markdown
| Komentarze w `src/*.jl`, `test/*.jl` | **polski** | Twardy wymóg projektu (CLAUDE.md). |
| Docstringi (`"""..."""`) | **polski** | Spójność z komentarzami. |
| Stringi UI (overlay, README) | **polski** | LANG-02, LANG-03. |
| Asercje wewnętrzne (`@assert`, `error()`) | **angielski** | LANG-04. |
```

### Polish `@info` Messages (LANG-02)

**Source:** `src/wizualizacja.jl` lines 282, 368, 440, 456-458
**Apply to:** `examples/podstawowy.jl`, `examples/eksport_mp4.jl`, `bench/run_all.jl`

**Excerpt z `src/wizualizacja.jl` line 282:**

```julia
@info "Eksport do $sciezka — może potrwać kilka minut, terminal nie reaguje, postęp poniżej:"
```

**Excerpt z `src/wizualizacja.jl` line 440:**

```julia
@info "Ładowanie GLMakie (pierwsze uruchomienie może trwać 60+ s — kompilacja JIT)..."
```

**Pattern:** Polskie diakrytyki uzywane swobodnie (`Ładowanie`, `może`, `potrwać`); NFC normalization gwarantowana przez `.editorconfig` + encoding guard.

### `function main(); ...; end; main()` Wrapper (DEMO-03, D-12)

**Source:** brak istniejacego analoga w `examples/` (folder pusty), ale konwencja explicit w 04-CONTEXT.md D-12 + ROADMAP Phase 4 SC #1
**Apply to:** wszystkie pliki w `examples/` (TYLKO — `bench/*.jl` mogą uzywac `function main()` ALE wywolanie `main()` na koncu jest opcjonalne — D-06 mowi "per-bench skrypty pozostaja samodzielnie uruchamialne, kazdy ma `function main()`")

**Pattern (D-12 LOCKED):**

```julia
function main()
    # ciało skryptu
    return nothing
end

main()  # explicit call na koncu pliku — top-level wywolanie wrappera
```

**Powod:** Phase 4 D-12 + DEMO-03 explicit — unika spowolnien top-level scope (Julia compilation), umożliwia łatwy `include()` dla integration testing (orchestrator `run_all.jl` może sięgnąć po `main()` z bench scripts).

### `bufor = zeros(Float64, Threads.nthreads())` Pattern

**Source:** `src/baselines.jl` line 99, `src/wizualizacja.jl` line 351
**Apply to:** `bench/bench_energia.jl` (tam gdzie wywoluje `oblicz_energie(stan.D, stan.trasa, bufor)` 3-arg)

**Excerpt z `src/baselines.jl` line 98-99:**

```julia
bufor = zeros(Float64, Threads.nthreads())             # alloc OK — wywoływane raz
stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
```

### Header Docstring Convention (Polish, multi-line `#` comments)

**Source:** `bench/diagnostyka_test05.jl` lines 1-19, `src/wizualizacja.jl` lines 1-25, `test/runtests.jl` lines 1-9
**Apply to:** wszystkie nowe `.jl` files Phase 4

**Pattern (top-of-file, BEFORE `using` block):**

```julia
# <plik> — <jednoa zdanie tytulu>
#
# <2-4 linie kontekstu — REQ-IDs, decyzje, ostrzezenia>
#
# Uruchomienie:
#   julia --project=. --threads=auto <plik>
```

### Fixture Build Pattern (NN-init Stan z seed=42)

**Source:** `bench/diagnostyka_test05.jl` lines 59-64 (`fresh_stan_with_nn`), `test/test_symulacja.jl` lines 61-66
**Apply to:** wszystkie 3 bench scripts + examples (nie eksport — eksport pozwala na okreslenie kroku i fps)

**Excerpt z `bench/diagnostyka_test05.jl` lines 59-64:**

```julia
function fresh_stan_with_nn()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    return stan
end
```

**Krytyczne:** `inicjuj_nn!(stan)` JUZ ustawia `stan.energia = energia_nn` (Phase 2 D-08 cache invariant). Wystarczy uchwycic `energia_nn = stan.energia` PRZED uruchomieniem SA.

---

## No Analog Found

| File | Role | Reason |
|------|------|--------|
| `bench/wyniki.md` | doc (generated) | Pierwszy plik tego typu — format prescribed by D-07 + Claude's Discretion. Nie ma istniejacego markdown report w repo. |
| `bench/historyczne/` | archive directory | Pierwsza archive folder w repo. |
| `assets/demo.gif` | binary artifact | Pierwszy commitowany binary asset w repo. `.gitattributes` Phase 1 ma juz regule `*.gif binary` (line 13) — config-side jest OK. |
| `bench/run_all.jl` orchestrator | sequential includes + report-generation | Najblizszy analog (`test/runtests.jl`) tylko sekwencyjnie include-uje testset-y; Phase 4 orchestrator dodaje 2 nowe responsibilities (zbieranie wynikow Trial → Dict + render markdown). Plan musi nowo zaprojektowac `_zbierz_metadane()` + `_renderuj_tabele()`. |

---

## Encoding & Naming Constraints (Phase 1 D-21, D-23)

**Wszystkie nowe pliki Phase 4 musza spelniac:**

- **ASCII-only filenames** (D-23): `examples/podstawowy.jl`, `examples/eksport_mp4.jl`, `bench/bench_energia.jl`, `bench/bench_krok.jl`, `bench/bench_jakosc.jl`, `bench/run_all.jl`, `bench/wyniki.md`, `bench/historyczne/`, `assets/demo.gif` — wszystkie ASCII. ✓
- **NFC normalization** (D-21): polskie diakrytyki w komentarzach/docstringach (jest, dziala, wynik) — ✓ pod warunkiem ze edytor zapisuje NFC (EditorConfig wymusza per Phase 1)
- **No BOM** (D-21): zaden plik nie ma sygnatury 0xEF 0xBB 0xBF — gwarantowane przez `.editorconfig`
- **LF line endings** (D-21): no CRLF — `.gitattributes` Phase 1 line 1 `* text=auto eol=lf` wymusza
- **Encoding guard test** (`test/runtests.jl` lines 25-88) skanuje `.jl`, `.toml`, `.md` w `src/` i `test/` + root level. **NIE skanuje `examples/`, `bench/`** (zawart w katalogach poza scopem). Plan moze rozwazyc rozszerzenie testu do `examples/` i `bench/` LUB pozostawic deferred (D-19 explicit defers encoding-validation guard test do v2).

---

## Metadata

**Analog search scope:**
- `src/` — wszystkie 6 plikow (`JuliaCity.jl`, `typy.jl`, `punkty.jl`, `energia.jl`, `baselines.jl`, `wizualizacja.jl`, `algorytmy/simulowane_wyzarzanie.jl`)
- `test/` — 4 pliki (`runtests.jl`, `test_baselines.jl`, `test_energia.jl`, `test_symulacja.jl`)
- `bench/` — 3 historyczne diagnostyki (Phase 2 plan 02-14)
- `Project.toml`, `.gitignore`, `.gitattributes`, `CONTRIBUTING.md`, `README.md` — root-level pliki konfiguracyjne i dokumentacyjne

**Files scanned:** 19 plikow (excludes `Manifest.toml`, `LICENSE`, log files)

**Pattern extraction date:** 2026-04-30

---

## Quick Reference for Planner

| New file | Najwazniejsze 3 odwolania (file:line) | Code excerpt do skopiowania |
|----------|---------------------------------------|------------------------------|
| `examples/podstawowy.jl` | `bench/diagnostyka_test05.jl:59-64` (fresh_stan), `src/wizualizacja.jl:432-465` (API call), `CONTRIBUTING.md:50-56` (LANG split) | `function main(); ... end; main()` (D-12) |
| `examples/eksport_mp4.jl` | `src/wizualizacja.jl:270-272` (D-04 obchodzi to), j.w. | `isfile(SCIEZKA) && rm(SCIEZKA)` przed `wizualizuj(...; eksport=...)` |
| `bench/bench_energia.jl` | `src/baselines.jl:98-99` (bufor pattern), `bench/diagnostyka_test05.jl:59-64` (fixture) | `@benchmark oblicz_energie($stan.D, $stan.trasa, $bufor)` |
| `bench/bench_krok.jl` | `test/test_symulacja.jl:60-85` (zero-alloc + warmup) | `@benchmark symuluj_krok!($stan, $params, $alg) setup=(symuluj_krok!($stan, $params, $alg))` |
| `bench/bench_jakosc.jl` | `bench/diagnostyka_test05.jl:162-191` (eksperymenty), `test/test_baselines.jl` (TEST-05) | for-loop nad `SEEDS = [42, 123, 456, 789, 2025]`, ratio = `stan.energia / energia_nn` |
| `bench/run_all.jl` | `test/runtests.jl:186-198` (sequential include), `src/wizualizacja.jl:46,64,91,133` (`_helper` convention) | `_zbierz_metadane()`, `_renderuj_tabele(wyniki)` z `@sprintf` |
| `README.md` (REWRITE) | `CONTRIBUTING.md:1-26` (Polish style), obecny `README.md:11-23` | 9 sekcji per D-15 z embed `![](assets/demo.gif)` |
| `CONTRIBUTING.md` (UPDATE) | `CONTRIBUTING.md:28-78` (style sekcji) | Append `## 4. Typografia polska` przed obecnym `## 4. Style przed commit` (renumber) |
| `Project.toml` (MODIFY) | `Project.toml:33-44` (extras + targets) | `test = ["Aqua", "BenchmarkTools", "JET", ...]` (line 44 — alfabetycznie) |
| `.gitignore` (MODIFY) | `.gitignore:26-31` (comment-block style) | `assets/*\n!assets/demo.gif` (D-05) |

---

*PATTERNS.md created: 2026-04-30*
*Phase: 4-Demo, Benchmarks & Documentation*
*Consumed by: gsd-planner (next step in `/gsd-plan-phase` orchestrator)*
