---
phase: 04-demo-benchmarks-documentation
plan: 07
type: execute
wave: 2
depends_on:
  - 01
files_modified:
  - examples/podstawowy.jl
  - examples/eksport_mp4.jl
autonomous: true
requirements:
  - DEMO-01
  - DEMO-02
  - DEMO-03
  - DEMO-04
  - LANG-02
must_haves:
  truths:
    - "examples/podstawowy.jl uruchamia generuj_punkty + inicjuj_nn! + SimAnnealing + wizualizuj (live, eksport=nothing)"
    - "examples/eksport_mp4.jl uruchamia ten sam pipeline z eksport=\"assets/demo.gif\", mkpath(dirname) defensywnie + pre-rm istniejącego pliku (BLOCKER #1)"
    - "Oba pliki mają function main() wrapper i kończą się main() top-level call (DEMO-03 LOCKED)"
    - "Oba pliki używają hardcoded sensible defaults (D-11) — bez ENV/ARGS"
    - "Banner @info na starcie + summary @info po wizualizuj() (D-13)"
  artifacts:
    - path: "examples/podstawowy.jl"
      provides: "Live demo skrypt — N=1000, 50_000 krokow, 33s @30fps"
      contains: "function main()"
    - path: "examples/eksport_mp4.jl"
      provides: "Eksport demo skrypt — 15_000 krokow, ~10s GIF, pre-rm"
      contains: "isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)"
  key_links:
    - from: "examples/podstawowy.jl"
      to: "JuliaCity.wizualizuj"
      via: "live mode (eksport=nothing)"
      pattern: "wizualizuj\\(stan, params, alg"
    - from: "examples/eksport_mp4.jl"
      to: "JuliaCity.wizualizuj"
      via: "export mode (eksport=...)"
      pattern: "eksport=.*demo\\.gif"
---

<objective>
Wave 2: Stworzyć dwa skrypty demo w `examples/` które konsumują pełen public API JuliaCity (Phase 1+2+3) bez żadnych modyfikacji src/. `podstawowy.jl` = live demo (otwiera GLMakie), `eksport_mp4.jl` = eksport do `assets/demo.gif` z pre-rm dla świadomej regeneracji (D-04 obchodzi Phase 3 D-10 hard-fail w API, ale tylko w skrypcie demo).

Purpose: DEMO-01..04 + LANG-02 explicit. ROADMAP SC #1 i SC #2 wymagają oba skrypty. DEMO-03 LOCKED `function main(); ...; end; main()` wrapper. Skrypty są prerequisite dla Wave 4 (assets/demo.gif generowany przez `eksport_mp4.jl`).
Output: 2 skrypty `.jl` w `examples/` używające hardcoded defaults D-11.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md
@.planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md
@.planning/phases/03-visualization-export/03-CONTEXT.md
@src/JuliaCity.jl
@src/wizualizacja.jl

<interfaces>
<!-- Public API for examples to consume — Phase 3 D-09 LOCKED -->

From src/JuliaCity.jl exports:
- generuj_punkty(n; seed)        — Phase 1 PKT-01..04
- StanSymulacji(punkty; rng)     — Phase 1 zero-state, mutable
- inicjuj_nn!(stan)              — Phase 2 ALG-04, ustawia stan.energia = energia_nn
- SimAnnealing(stan; T_zero?, alfa?, cierpliwosc?) — Phase 2 ALG-01
- Parametry(; liczba_krokow, ...)
- wizualizuj(stan, params, alg; liczba_krokow, fps=30, kroki_na_klatke=10, eksport=nothing) -> Nothing

Phase 3 D-10 hard-fail (in src/wizualizacja.jl line ~270):
```julia
if eksport !== nothing && isfile(eksport)
    error("Plik $eksport istnieje — wybierz inną nazwę lub usuń go ręcznie")
end
```
→ Phase 4 D-04 OBCHODZI to w examples/eksport_mp4.jl przez `isfile(out) && rm(out)` PRZED wywołaniem wizualizuj().

Fixture pattern (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn):
```julia
punkty = generuj_punkty(N; seed=SEED)
stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
inicjuj_nn!(stan)
energia_nn = stan.energia                        # capture PRZED SA dla post-summary ratio
alg = SimAnnealing(stan)                         # default kalibracja (NIE T_zero=0.001 — to tylko dla TEST-05/bench_jakosc)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=LICZBA_KROKOW)
```

UWAGA: examples używają DEFAULT 2σ kalibracji (`SimAnnealing(stan)` bez kwarg), NIE Phase 2 erratum override `T_zero=0.001`. To świadoma decyzja — examples pokazują „typowe" zachowanie SA z metropolis acceptance rejecting+accepting; bench_jakosc używa erratum lock dla deterministycznego ratio porównania.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Utwórz examples/podstawowy.jl (live demo)</name>
  <read_first>
    - src/wizualizacja.jl (linie 1-25 — header docstring style; linie ~432-465 — pełny example call site z polskim @info)
    - bench/historyczne/diagnostyka_test05.jl (linie 59-69 — fresh_stan_with_nn fixture)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "examples/podstawowy.jl" — exact code excerpt z function main wrapper)
  </read_first>
  <action>
    Utworzyć plik `examples/podstawowy.jl` (polski, NFC, BOM-free, LF, final newline; ASCII identyfikatory):

    ```julia
    # examples/podstawowy.jl
    #
    # Live demo SA-2-opt na 1000 punktach (Phase 4 DEMO-01, DEMO-03, DEMO-04, LANG-02).
    # Otwiera okno GLMakie z dual-panel layoutem, animuje proces zaciagania trasy.
    # Hardcoded sensible defaults: N=1000, seed=42, 50_000 krokow, 33s @30fps (D-11).
    # Bez ENV/ARGS — edytuj stale ponizej zeby zmienic dlugosc demo.
    #
    # Uruchomienie:
    #   julia --project=. --threads=auto examples/podstawowy.jl

    using JuliaCity
    using Random: Xoshiro

    function main()
        # D-11: hardcoded sensible defaults (komentarze polskie nad kazda stala)
        N = 1000                  # liczba punktow (PROJECT.md core value)
        SEED = 42                 # deterministyczny seed (D-11)
        LICZBA_KROKOW = 50_000    # 33s @ 30fps z kroki_na_klatke=50 (D-11 + D-13)
        KROKI_NA_KLATKE = 50      # throttling Observable update (Phase 3 D-05)
        FPS = 30                  # unified live i eksport (Phase 3 D-11)

        # D-13: banner @info na starcie
        @info "JuliaCity demo — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

        # Build fixture (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn)
        punkty = generuj_punkty(N; seed=SEED)
        stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
        inicjuj_nn!(stan)
        energia_nn = stan.energia                     # captured PRZED SA dla post-summary ratio
        alg = SimAnnealing(stan)                      # default 2σ kalibracja — examples = typowe zachowanie
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=LICZBA_KROKOW)

        # Live demo (Phase 3 D-09 API consumer — eksport=nothing => live mode)
        t_start = time()
        wizualizuj(stan, params, alg;
                   liczba_krokow=LICZBA_KROKOW,
                   fps=FPS,
                   kroki_na_klatke=KROKI_NA_KLATKE)
        dt = time() - t_start

        # D-13: post-SA summary @info (NIE duplikuje overlay'u "GOTOWE" z Phase 3 D-06 —
        # overlay zyje w oknie GLMakie, summary w terminalu)
        ratio = round(stan.energia / energia_nn; digits=4)
        @info "GOTOWE: ratio=$ratio, czas=$(round(dt; digits=2))s, krokow=$(stan.iteracja)"

        return nothing
    end

    main()
    ```

    KRYTYCZNE:
    - DEMO-03 + D-12: `function main(); ...; end; main()` — top-level `main()` MUSI być na końcu pliku (pojedyncza linia, dokładnie `main()`).
    - DEMO-04 + D-11: HARDCODED stałe na początku `main()`. Bez `ENV[...]`, bez `ARGS[...]`, bez ArgParse.
    - LANG-02: `@info` po polsku z diakrytykami (komentarze ASCII OK, ale @info user-facing).
    - LANG-04: brak asercji `@assert` w tym pliku (nie-asercyjny scope), więc nie miesz polskiego/angielskiego.
    - Phase 3 D-09 API consumer: `wizualizuj(stan, params, alg; liczba_krokow, fps, kroki_na_klatke)` — NIE przekazujemy `eksport=...`.
    - `SimAnnealing(stan)` BEZ kwarg `T_zero=0.001` — examples pokazują domyślne zachowanie (metropolis accepting/rejecting z auto-kalibracji 2σ); erratum override jest tylko dla bench_jakosc.
    - ASCII-only stałe: `KROKI_NA_KLATKE` (NIE `KROKI_NA_KLATKĘ`), `LICZBA_KROKOW` (NIE `LICZBA_KROKÓW`).
    - Header docstring 7-8 linii top-of-file (BEFORE `using` block).
    - Komentarze polskie ale BEZ diakrytyków w identyfikatorach (per Phase 1 D-23 + CONTRIBUTING §3) — OK używać `# Hardcoded sensible defaults` (komentarz, ASCII), ale BAD `KROKI_NA_KLATKĘ` (identyfikator z diakrytykiem).
  </action>
  <verify>
    <automated>test -f examples/podstawowy.jl &amp;&amp; grep -q 'function main()' examples/podstawowy.jl &amp;&amp; grep -qE '^main\(\)$' examples/podstawowy.jl &amp;&amp; grep -q 'wizualizuj(stan, params, alg' examples/podstawowy.jl &amp;&amp; grep -q 'inicjuj_nn!' examples/podstawowy.jl &amp;&amp; grep -q 'liczba_krokow=50_000' examples/podstawowy.jl &amp;&amp; grep -q 'kroki_na_klatke=50' examples/podstawowy.jl &amp;&amp; grep -q '@info "JuliaCity demo' examples/podstawowy.jl &amp;&amp; grep -q '@info "GOTOWE' examples/podstawowy.jl</automated>
  </verify>
  <acceptance_criteria>
    - `examples/podstawowy.jl` istnieje.
    - Zawiera `function main()` (D-12 LOCKED).
    - Zawiera DOKŁADNIE jedną linię `main()` na top-level (grep `-cE '^main\(\)$'` zwraca 1).
    - Zawiera `wizualizuj(stan, params, alg` (Phase 3 D-09 API consumer).
    - Zawiera literalnie `LICZBA_KROKOW = 50_000` (D-11 hardcoded — 33s demo).
    - Zawiera literalnie `KROKI_NA_KLATKE = 50` (Phase 3 D-05 throttling).
    - Zawiera literalnie `FPS = 30`.
    - Zawiera literalnie `SEED = 42`.
    - Zawiera `inicjuj_nn!(stan)` (Phase 2 fixture).
    - Zawiera `energia_nn = stan.energia` (capture PRZED SA — D-13 ratio).
    - Zawiera 2 wywołania `@info`: banner (zawiera `"JuliaCity demo"`) i summary (zawiera `"GOTOWE"`).
    - Header docstring 7+ linii top-of-file (`head -10 | grep -c '^#'` ≥ 7).
    - NIE zawiera `eksport=` (live mode — eksport=nothing default).
    - NIE zawiera `ENV[`, `ARGS[`, `using ArgParse` (DEMO-04 + D-11 — bez parametryzacji).
    - NIE zawiera `T_zero=0.001` (examples = default kalibracja).
    - ASCII-only identyfikatory: `grep -P '\b[a-zA-Z_]*[ąćęłńóśźż][a-zA-Z_]*\b' examples/podstawowy.jl` zwraca tylko hits z komentarzy/stringów (sprawdzić ręcznie że żaden nie jest identyfikatorem).
    - BOM-free, LF, final newline.
  </acceptance_criteria>
  <done>examples/podstawowy.jl gotowy: live demo z hardcoded defaults, function main() wrapper, banner+summary @info po polsku.</done>
</task>

<task type="auto">
  <name>Task 2: Utwórz examples/eksport_mp4.jl (eksport demo.gif z pre-rm)</name>
  <read_first>
    - examples/podstawowy.jl (właśnie utworzony — żeby zachować spójny styl header'a, kolejność stałych, format @info)
    - src/wizualizacja.jl (linia ~270 — Phase 3 D-10 hard-fail policy która jest celowo obchodzona przez D-04)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-02, D-03, D-04, D-05 — eksport_mp4.jl spec)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "examples/eksport_mp4.jl" — exact code excerpt)
  </read_first>
  <action>
    Utworzyć plik `examples/eksport_mp4.jl` (polski, NFC, BOM-free, LF, final newline; ASCII identyfikatory):

    ```julia
    # examples/eksport_mp4.jl
    #
    # Eksport krotkiego ~10s demo SA-2-opt do assets/demo.gif (Phase 4 DEMO-02, DEMO-03, DEMO-04, D-01..D-05).
    # UWAGA: Pomimo nazwy "eksport_mp4", produkujemy GIF — D-01 wybiera GIF dla auto-play
    # w README (embed `![](assets/demo.gif)`). Nazwa zachowana zgodnie z REQUIREMENTS DEMO-02
    # i ROADMAP Phase 4 SC #2 (oba dopuszczaja .gif). Phase 3 wizualizuj() rozpoznaje rozszerzenie
    # `.gif` automatycznie (Phase 3 D-09 + EKS-02).
    #
    # Uruchomienie:
    #   julia --project=. --threads=auto examples/eksport_mp4.jl

    using JuliaCity
    using Random: Xoshiro

    function main()
        # D-02 + D-11: 15_000 krokow / 50 kroki_na_klatke = 300 klatek / 30 fps = 10s GIF (~3-5 MB)
        N = 1000
        SEED = 42
        LICZBA_KROKOW = 15_000
        KROKI_NA_KLATKE = 50
        FPS = 30
        SCIEZKA_GIF = "assets/demo.gif"

        @info "JuliaCity eksport GIF — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

        # Checker iteracja 1 BLOCKER #1: katalog `assets/` NIE jest commitowany w repo
        # (D-05 EXACT — brak `.gitkeep`). Defensywnie tworzymy parent dir przed pre-rm/eksport.
        # Idempotent (force=true): bez bledu jezeli juz istnieje.
        mkpath(dirname(SCIEZKA_GIF))

        # D-04: pre-rm istniejacego pliku (swiadoma regeneracja, NIE accident overwrite).
        # Phase 3 D-10 hard-fail (src/wizualizacja.jl ~line 270) chroni API users przed
        # przypadkowym nadpisaniem; demo skrypt = explicit regen, wiec usuwamy plik PRZED
        # wywolaniem wizualizuj(). To celowy obejscie hard-fail tylko w skrypcie demo.
        isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)

        # Build fixture (analog examples/podstawowy.jl)
        punkty = generuj_punkty(N; seed=SEED)
        stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
        inicjuj_nn!(stan)
        energia_nn = stan.energia
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=LICZBA_KROKOW)

        # Eksport (Phase 3 D-09 API consumer — eksport=path => Makie.record + ProgressMeter)
        t_start = time()
        wizualizuj(stan, params, alg;
                   liczba_krokow=LICZBA_KROKOW,
                   fps=FPS,
                   kroki_na_klatke=KROKI_NA_KLATKE,
                   eksport=SCIEZKA_GIF)
        dt = time() - t_start

        ratio = round(stan.energia / energia_nn; digits=4)
        @info "GOTOWE eksport: $SCIEZKA_GIF, ratio=$ratio, czas=$(round(dt; digits=2))s"

        return nothing
    end

    main()
    ```

    KRYTYCZNE:
    - D-04 LOCKED: `isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)` PRZED `wizualizuj(...)`. Bez tego Phase 3 D-10 hard-fail rzuca `error()` przy drugim uruchomieniu skryptu (gdy demo.gif już istnieje).
    - SCIEZKA_GIF MUSI być `"assets/demo.gif"` literalnie — README D-15 §2 embed używa tej ścieżki: `![Demo SA na 1000 punktach](assets/demo.gif)`.
    - DEMO-03 + D-12: `function main(); ...; end; main()` — top-level call (jak podstawowy.jl).
    - D-02: `LICZBA_KROKOW = 15_000` (NIE 50_000 jak podstawowy.jl) — krótszy demo dla README UX (~10s GIF, ~3-5 MB).
    - `eksport=SCIEZKA_GIF` przekazane do `wizualizuj` — Phase 3 D-09 API rozpoznaje extension i wybiera Makie.record + ProgressMeter.
    - Komentarz polski wyjaśniający D-04 obejście Phase 3 D-10 (audit trail w pliku, żeby przyszły reader rozumiał celowość).
    - LANG-02: `@info` po polsku.
    - ASCII identyfikatory: `SCIEZKA_GIF`, `LICZBA_KROKOW`, `KROKI_NA_KLATKE` — bez diakrytyków.
    - Plan 04-01 (revised per checker iteracja 1 BLOCKER #1): NIE dostarcza już katalogu `assets/` ani `.gitkeep` — D-05 EXACT (`assets/*` + `!assets/demo.gif`, nic więcej). Ten skrypt MUSI sam tworzyć katalog przez `mkpath(dirname(SCIEZKA_GIF))` PRZED `isfile/rm/wizualizuj` — defensywnie i idempotentnie. Bez `mkpath` na fresh checkout (gdzie `assets/` nigdy nie zostało utworzone) `Makie.record` rzuca błąd I/O.
    - Kolejność operacji: `mkpath(dirname(SCIEZKA_GIF))` → `isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)` → `wizualizuj(...; eksport=SCIEZKA_GIF)`. Wszystkie 3 kroki MUSZĄ być w tej kolejności.
  </action>
  <verify>
    <automated>test -f examples/eksport_mp4.jl &amp;&amp; grep -q 'function main()' examples/eksport_mp4.jl &amp;&amp; grep -qE '^main\(\)$' examples/eksport_mp4.jl &amp;&amp; grep -q 'mkpath(dirname(SCIEZKA_GIF))' examples/eksport_mp4.jl &amp;&amp; grep -q 'isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)' examples/eksport_mp4.jl &amp;&amp; grep -q 'eksport=SCIEZKA_GIF' examples/eksport_mp4.jl &amp;&amp; grep -q 'SCIEZKA_GIF = "assets/demo.gif"' examples/eksport_mp4.jl &amp;&amp; grep -q 'LICZBA_KROKOW = 15_000' examples/eksport_mp4.jl</automated>
  </verify>
  <acceptance_criteria>
    - `examples/eksport_mp4.jl` istnieje.
    - Zawiera `function main()` (D-12 LOCKED).
    - Zawiera DOKŁADNIE jedną linię `main()` na top-level (grep `-cE '^main\(\)$'` zwraca 1).
    - Zawiera literalnie `mkpath(dirname(SCIEZKA_GIF))` (BLOCKER #1 fix — defensywne tworzenie katalogu na fresh checkout).
    - `mkpath` linia POPRZEDZA `isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)` w pliku (numer linii grep `mkpath` < numer linii grep `isfile`).
    - Zawiera literalnie `isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)` (D-04 pre-rm).
    - Zawiera literalnie `SCIEZKA_GIF = "assets/demo.gif"` (D-05 + README D-15 embed path).
    - Zawiera `eksport=SCIEZKA_GIF` w wywołaniu `wizualizuj` (Phase 3 D-09 API).
    - Zawiera literalnie `LICZBA_KROKOW = 15_000` (D-02 — 10s GIF).
    - Zawiera literalnie `KROKI_NA_KLATKE = 50`.
    - Zawiera literalnie `FPS = 30`.
    - Zawiera 2 wywołania `@info`: banner + GOTOWE.
    - Header docstring 8+ linii top-of-file (zawiera wyjaśnienie nazwy "eksport_mp4" vs `.gif` per D-03).
    - Komentarz nad `isfile(...) && rm(...)` zawiera literalnie `D-04` (audit trail).
    - NIE zawiera `T_zero=0.001`.
    - NIE zawiera `ENV[`, `ARGS[`, `using ArgParse`.
    - BOM-free, LF, final newline.
    - ASCII-only identyfikatory.
  </acceptance_criteria>
  <done>examples/eksport_mp4.jl gotowy: pre-rm + wizualizuj z eksport="assets/demo.gif", 15_000 krokow/10s/3-5 MB target.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 2 nowe pliki `.jl` w examples/. examples/eksport_mp4.jl po wykonaniu (Wave 4) zapisuje do `assets/demo.gif`. Brak wejścia użytkownika, brak network, brak persistence danych użytkownika. |
| filesystem delete | examples/eksport_mp4.jl wywołuje `rm("assets/demo.gif")` jeśli plik istnieje — D-04 explicit rationale dokumentowany w komentarzu. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-07-01 | Tampering | Pre-rm w examples/eksport_mp4.jl | mitigate | Hardcoded ścieżka `"assets/demo.gif"` (NIE wzięta z user input/ENV). Path traversal niemożliwy. Acceptance criteria sprawdza dokładny literal `isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)`. |
| T-04-07-02 | Tampering | Phase 3 D-10 hard-fail bypass | accept | D-04 LOCKED w 04-CONTEXT.md — świadome obejście tylko w skrypcie demo, NIE w API `wizualizuj()`. Komentarz polski w pliku jako audit trail dla przyszłych readerów. |
| T-04-07-03 | Information Disclosure | Banner @info pokazuje threads/seed | accept | Public deterministic info; brak PII. ASVS L1 nie wymaga kontroli. |

Brak ASVS L1 controls naruszonych — examples skrypt z hardcoded path, brak external input.
</threat_model>

<verification>
- Smoke test (jeśli toolchain): `julia --project=. --threads=auto examples/podstawowy.jl` otwiera GLMakie window i emituje 2 @info (banner + GOTOWE).
- Smoke test eksport: `julia --project=. --threads=auto examples/eksport_mp4.jl` produkuje `assets/demo.gif` (~3-5 MB) i emituje banner + GOTOWE @info; powtórzone uruchomienie nie blokuje (D-04 pre-rm).
- DEMO-04 spełnione: `julia --project=. --threads=auto examples/podstawowy.jl` exit 0 bez additional setup.
</verification>

<success_criteria>
- DEMO-01 spełnione: examples/podstawowy.jl pełna pętla (generuj_punkty → inicjuj_nn → SA → wizualizuj live).
- DEMO-02 spełnione: examples/eksport_mp4.jl produkuje plik `.gif` (Phase 3 EKS-02 dispatch).
- DEMO-03 spełnione: oba pliki w `function main(); ...; end; main()` wrapper.
- DEMO-04 spełnione: oba uruchamiają się komendą `julia --project=. --threads=auto examples/...` bez extras.
- LANG-02 spełnione: banner + summary @info po polsku z diakrytykami.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-07-SUMMARY.md`
</output>
