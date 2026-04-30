---
phase: 04-demo-benchmarks-documentation
plan: 08
type: execute
wave: 4
depends_on:
  - 03
  - 06
  - 07
files_modified:
  - assets/demo.gif
  - README.md
autonomous: false
requirements:
  - DEMO-02
  - LANG-03
must_haves:
  truths:
    - "assets/demo.gif istnieje w repo, jest commitowany, ~3-5 MB, produkowany przez examples/eksport_mp4.jl"
    - "README.md ma 9 sekcji per D-15 w polskim (Header, GIF embed, Wymagania, Instalacja, Quickstart, Algorytm, Benchmarki, Struktura, Licencja)"
    - "README.md osadza demo.gif przez ![alt](assets/demo.gif)"
    - "README.md w sekcji Benchmarki linkuje do bench/wyniki.md i podaje empiryczny headline z bench_jakosc"
    - "README.md używa polskiej typografii: „..." cudzysłowy + — em-dash + NFC (per D-18)"
  artifacts:
    - path: "assets/demo.gif"
      provides: "Demo animacji SA-2-opt na 1000 punktach (~10s, ~3-5 MB)"
      min_lines: 0
    - path: "README.md"
      provides: "Polski README z 9 sekcjami, embed GIF, headline benchmark, struktura projektu"
      contains: "assets/demo.gif"
  key_links:
    - from: "README.md"
      to: "assets/demo.gif"
      via: "markdown image embed"
      pattern: "!\\[.*\\]\\(assets/demo\\.gif\\)"
    - from: "README.md"
      to: "bench/wyniki.md"
      via: "markdown link"
      pattern: "\\[.*\\]\\(bench/wyniki\\.md\\)"
    - from: "README.md"
      to: "LICENSE"
      via: "markdown link"
      pattern: "\\[.*\\]\\(LICENSE\\)"
---

<objective>
Wave 4 final: (a) wygenerować `assets/demo.gif` przez uruchomienie `examples/eksport_mp4.jl` (checkpoint:human-action — wymaga GLMakie GUI lokalnie), (b) przepisać `README.md` na 9-sekcyjną polską wersję per D-15 z osadzonym GIF i empirycznym headline'em z `bench/wyniki.md`.

Purpose: Domyka Phase 4 — DEMO-02 wymaga `assets/demo.gif` lub `.mp4`; LANG-03 wymaga README po polsku z GIF i bench numbers; ROADMAP SC #5 explicit „README jest w pełni po polsku, zawiera Core Value, instrukcje instalacji, quickstart, osadzony demo GIF, sekcję benchmarków z aktualnymi liczbami vs NN baseline".
Output: Nowy `assets/demo.gif` (~3-5 MB) commitowany do repo + przepisany `README.md` z 9 sekcjami, polską typografią, embed GIF, headline benchmark, struktura projektu.
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
@CONTRIBUTING.md
@examples/eksport_mp4.jl
@bench/wyniki.md
@README.md

<interfaces>
<!-- Materials produced by previous waves used by this plan -->

From plan 04-07 (examples/eksport_mp4.jl):
- Skrypt jest gotowy do produkcji `assets/demo.gif` po lokalnym uruchomieniu z GLMakie/OpenGL.
- Komenda: `julia --project=. --threads=auto examples/eksport_mp4.jl`

From plan 04-06 (bench/wyniki.md):
- Plik istnieje z aggregate ratio statistics z bench_jakosc.
- Headline value: `mean_ratio` empiryczny (oczekiwany ~0.94, czyli ~6% krótsza).
- Struktura: `## Środowisko` + `## Microbenchmarki` + `## Jakość trasy`.

From plan 04-03 (CONTRIBUTING.md §4):
- Konwencja typografii: „..." cudzysłowy (U+201E + U+201D), — em-dash (U+2014), NFC, BOM-free.

From PROJECT.md Core Value (do skopiowania DOSŁOWNIE w README header):
"Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — jeśli wszystko inne zawiedzie, użytkownik musi zobaczyć, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymać krótszą trasę niż naiwny baseline."
(W README §1 może być skrócone do 1-2 zdań — poniżej proponowane brzmienie.)
</interfaces>
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 1: Wygeneruj assets/demo.gif lokalnie (wymaga GLMakie GUI)</name>
  <read_first>
    - examples/eksport_mp4.jl (właśnie utworzony przez plan 04-07 — skrypt gotowy do uruchomienia)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-02 — 10s ~15 000 kroków, ~3-5 MB target; D-05 — assets/demo.gif commitowany; D-17 — brak xvfb CI, build lokalny)
    - .planning/phases/03-visualization-export/03-CONTEXT.md (D-09 — wizualizuj eksport API; D-10 — file-exists hard-fail obchodzony przez D-04 w eksport_mp4.jl)
  </read_first>
  <what-built>
    Wave 1 utworzył katalog `assets/` z `.gitkeep`. Wave 2 (plan 04-07) utworzył `examples/eksport_mp4.jl` ze świadomym pre-rm policy i hardcoded ścieżką `"assets/demo.gif"`. Wszystko gotowe deklaratywnie do produkcji GIFa.

    Brakujący artefakt to sam plik binarny `assets/demo.gif` — wymaga lokalnego uruchomienia z dostępem do OpenGL (GLMakie). D-17 LOCKED: brak xvfb CI, GIF buildowany lokalnie i commitowany ręcznie przez developera.
  </what-built>
  <how-to-verify>
    Wykonać RĘCZNIE w terminalu na lokalnej maszynie z GLMakie (Linux/macOS/Windows desktop, NIE headless):

    1. **Sprawdzić brak istniejącego pliku** (powinien nie istnieć po Wave 1, ale defensywnie):
       ```bash
       ls -la assets/demo.gif 2>/dev/null && echo "ISTNIEJE — examples/eksport_mp4.jl wykona pre-rm" || echo "BRAK — OK"
       ```

    2. **Uruchomić eksport** (czas ~3-5 minut, dominuje GLMakie ładowanie + Makie.record):
       ```bash
       cd C:/Users/mparol/Desktop/Dokumenty/Projekty/JuliaCity
       julia --project=. --threads=auto examples/eksport_mp4.jl
       ```

       Oczekiwane @info na stdout (per Phase 3 D-08 + Phase 4 D-13):
       - `[ Info: Ładowanie GLMakie (pierwsze uruchomienie może trwać 60+ s — kompilacja JIT)...`
       - `[ Info: JuliaCity eksport GIF — N=1000, seed=42, threads=...`
       - `[ Info: Eksport do assets/demo.gif — może potrwać kilka minut, terminal nie reaguje, postęp poniżej:`
       - ProgressMeter bar (300 klatek)
       - `[ Info: GOTOWE eksport: assets/demo.gif, ratio=..., czas=...s`

    3. **Weryfikacja właściwości pliku:**
       ```bash
       ls -la assets/demo.gif    # exists, ~3-5 MB
       file assets/demo.gif       # GIF image data, version 89a, 1280x720+ (or whatever Makie default)
       ```

       Akceptowalny rozmiar: 1.5 MB - 8 MB. Jeśli > 10 MB — albo zmniejszyć `LICZBA_KROKOW` w eksport_mp4.jl, albo zwiększyć `KROKI_NA_KLATKE` (mniej klatek). Jeśli < 1 MB — sprawdzić czy 300 klatek faktycznie zostało wygenerowanych (bug?).

    4. **Wizualna weryfikacja** (otworzyć GIF w przeglądarce/viewerze):
       - Powinno być widać 1000 niebieskich punktów + czerwoną/zielona linię trasy zaciskającej się przez ~10s.
       - Polskie etykiety: tytuł „SA-2-opt — N=1000", oś X „x", oś Y „y", overlay numer iteracji + energia po polsku.
       - Auto-loop przy embed na GitHubie (GIF format property).

    5. **Commit:**
       ```bash
       git add assets/demo.gif
       git status   # sprawdzić że demo.gif jest staged, .gitkeep nie został odepchnięty
       ```

       UWAGA: `.gitignore` reguła `assets/*` + `!assets/demo.gif` (Wave 1, plan 04-01) gwarantuje że TYLKO demo.gif przechodzi. Inne pliki w `assets/` (np. test artefakty) zostaną zignorowane.

    6. **Sanity check rozmiaru repo po commit:** `du -sh .git/` — powinno wzrosnąć o ~3-5 MB. Akceptowalne dla v1 (D-05 LOCKED).
  </how-to-verify>
  <resume-signal>
    Po wykonaniu kroków 1-6: napisać `approved: assets/demo.gif scommitowany, rozmiar=$N MB, ratio z @info=$RATIO` lub opisać blokery.

    Jeśli GLMakie/OpenGL fail (Pitfall 7) — opisać dokładny błąd (Polish error message z `_format_glmakie_error_msg` powinien się pojawić) i rozważyć:
    - Restart maszyny / aktualizacja drivera GPU
    - Próba na innej maszynie (D-17 ślepy zaułek dla CI rozwiązany lokalnie)
    - Rollback: zostawić `assets/.gitkeep` placeholder, README odwołać się do braku GIFa z notką „Demo GIF dochodzi po rozwiązaniu env GLMakie"
  </resume-signal>
</task>

<task type="auto">
  <name>Task 2: Przepisz README.md na 9-sekcyjną polską wersję (D-15)</name>
  <read_first>
    - README.md (obecny stan — Phase 1 placeholder, ~38 linii — będzie w pełni nadpisany)
    - PROJECT.md (Core Value — exact phrasing do skopiowania w sekcji 1)
    - CONTRIBUTING.md (§4 Typografia polska — właśnie dodana w plan 04-03; reguły do zastosowania)
    - bench/wyniki.md (właśnie wygenerowane w plan 04-06 — empiryczny headline number do skopiowania)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-15 — exact 9 sekcji + D-18 typografia + D-08 headline phrasing)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "README.md REWRITE — 9 sekcji" — exact skeleton)
    - assets/demo.gif (właśnie scommitowany w Task 1 — dla `![](assets/demo.gif)` embed)
    - .planning/codebase/STRUCTURE.md (jeśli istnieje — drzewko top-level dla sekcji "Struktura projektu")
    - **src/algorytmy/simulowane_wyzarzanie.jl** (BLOCKER #5 fix — verify actual `alfa` default w `SimAnnealing` constructor; sekcja "Algorytm" README MUSI używać DOKŁADNIE tej wartości z polskim przecinkiem dziesiętnym)
    - **src/energia.jl** (BLOCKER #5 — verify `kalibruj_T0` formula: jeśli `2σ(Δ-energii)` to phrasing "T₀ = 2σ(Δ-energii)" OK; jeśli inna — zaktualizować)
  </read_first>
  <action>
    Nadpisać `README.md` w pełni nową polską 9-sekcyjną treścią. Każda sekcja jest WYMAGANA per D-15 (kolejność LOCKED).

    Pełna treść do zapisania (NFC, BOM-free, LF, final newline; polska typografia per D-18):

    ```markdown
    # JuliaCity

    Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i daje krótszą trasę niż naiwny baseline nearest-neighbor.

    ![Demo SA na 1000 punktach](assets/demo.gif)

    ## Wymagania

    - Julia ≥ 1.10 (zalecane: 1.11 lub 1.12)
    - System: Linux / macOS / Windows
    - GPU z OpenGL 3.3+ (dla okna GLMakie — patrz uwagi headless poniżej)

    ## Instalacja

    W REPL Julii, w katalogu repo:

    ```julia
    using Pkg
    Pkg.activate(".")
    Pkg.instantiate()
    ```

    `Manifest.toml` jest commitowany (to aplikacja, nie biblioteka) — `instantiate` przypina dokładne wersje.

    ## Quickstart

    Trzy fragmenty pokazujące pełen pipeline:

    **(a) Generowanie 1000 punktów (deterministyczne dla danego seeda):**

    ```julia
    using JuliaCity
    punkty = generuj_punkty(1000; seed=42)
    @assert length(punkty) == 1000
    ```

    **(b) Live demo (otwiera okno GLMakie):**

    ```julia
    using JuliaCity, Random
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=50_000)
    wizualizuj(stan, params, alg; liczba_krokow=50_000, fps=30, kroki_na_klatke=50)
    ```

    Lub po prostu:

    ```bash
    julia --project=. --threads=auto examples/podstawowy.jl
    ```

    **(c) Eksport do GIF/MP4:**

    ```julia
    wizualizuj(stan, params, alg; liczba_krokow=15_000, kroki_na_klatke=50, fps=30, eksport="moje_demo.gif")
    ```

    Rozszerzenie `.gif` lub `.mp4` jest wykrywane automatycznie. Szablon w `examples/eksport_mp4.jl`.

    ## Algorytm

    Symulowane wyżarzanie z ruchami 2-opt i metropolis acceptance, startujące od trasy nearest-neighbor (NN), z geometrycznym chłodzeniem (α = {ALFA_VERIFIED}) i auto-kalibrowaną temperaturą początkową `T₀ = {T_ZERO_VERIFIED}`.

    Metafora błony mydlanej: krawędzie trasy zachowują się jak elastyczne membrany pod napięciem powierzchniowym — w każdej iteracji algorytm „zaciska" jedną z par krawędzi (ruch 2-opt) i akceptuje nową trasę z prawdopodobieństwem `exp(−Δ/T)`. W trakcie chłodzenia (`T → 0`) akceptowane są tylko ulepszenia, więc trasa zbiega do minimum lokalnego 2-opt.

    **NOTA dla executora (BLOCKER #5):** PRZED zapisaniem README, executor MUSI:
    1. Odczytać `src/algorytmy/simulowane_wyzarzanie.jl` i znaleźć linię `alfa::Float64=0.9999` w konstruktorze `SimAnnealing`. Podstawić ZWERYFIKOWANĄ wartość zamiast `{ALFA_VERIFIED}` — z polskim przecinkiem dziesiętnym (`0,9999` jeśli wynosi 0.9999).
    2. Odczytać `src/energia.jl::kalibruj_T0` i zweryfikować formułę. Jeśli zwraca `2 * std(deltas)` lub równoważne `2σ(Δ-energii)` — podstawić `2σ(Δ-energii)` zamiast `{T_ZERO_VERIFIED}`. Jeśli formuła jest inna, użyć tej z podpisem matematycznym po polsku.
    3. Verify CLI: `julia --project=. -e 'using JuliaCity; punkty = generuj_punkty(100; seed=1); stan = StanSymulacji(punkty); inicjuj_nn!(stan); println(SimAnnealing(stan).alfa)'` — output musi pasować do liczby w README.
    Brak placeholderów `{...}` w shipping README.

    Architektura jest rozszerzalna — `abstract type Algorytm` + Holy-traits dispatch pozwala dodać warianty `ForceDirected` i `Hybryda` w v2 bez zmiany API.

    ## Benchmarki

    Pełne wyniki (czas, alokacje, jakość trasy): [`bench/wyniki.md`](bench/wyniki.md).

    **Headline:** SA znajduje trasę średnio ~{HEADLINE_PERCENT}% krótszą niż NN baseline (5 seedów × N=1000 × 50 000 kroków).

    *(NOTA executor — Warning #2: jeśli `bench/wyniki.md` pokazuje `std_ratio > 0.02`, podstaw `{HEADLINE_PERCENT}` z DOKŁADNĄ średnią z bench/wyniki.md zaokrągloną do 1 miejsca po przecinku — NIE shipuj placeholdera „~6%" jeśli pomiar disagrees. Jeśli `std_ratio ≤ 0.02`, zaokrąglenie do najbliższej liczby całkowitej OK.)*

    Reprodukcja:

    ```bash
    julia --project=. --threads=auto bench/run_all.jl
    ```

    Suite zawiera:
    - `bench/bench_energia.jl` — czas + alokacje `oblicz_energie` (3-arg, threaded)
    - `bench/bench_krok.jl` — czas + alokacje `symuluj_krok!` (jeden krok SA-2-opt + Metropolis)
    - `bench/bench_jakosc.jl` — ratio `SA / NN` na 5 seedach (D-08 lock)

    Pliki `bench/historyczne/` zawierają empiryczną diagnostykę z Phase 2 — patrz [`bench/historyczne/README.md`](bench/historyczne/README.md).

    ## Struktura projektu

    ```
    JuliaCity/
    ├── src/                    # Kod źródłowy: typy, energia, SA, baselines, wizualizacja
    │   ├── JuliaCity.jl         # Moduł główny + eksport publicznego API
    │   ├── typy.jl              # Punkt2D, StanSymulacji, Algorytm, Parametry
    │   ├── punkty.jl            # generuj_punkty (deterministyczny RNG)
    │   ├── energia.jl           # oblicz_energie + delta_energii + kalibruj_T0
    │   ├── baselines.jl         # NN init (trasa_nn, inicjuj_nn!)
    │   ├── algorytmy/           # Warianty <:Algorytm (Holy-traits)
    │   │   └── simulowane_wyzarzanie.jl
    │   └── wizualizacja.jl      # GLMakie + Makie.record (jedyny plik z `using GLMakie`)
    ├── test/                    # Test suite (230+ testów: encoding, type stability, zero-alloc, NN-beat)
    ├── examples/                # Skrypty demo: live + eksport GIF
    ├── bench/                   # Benchmarki: energia, krok, jakość + run_all orchestrator
    ├── assets/                  # Demo GIF (commitowany, ~3-5 MB)
    ├── .planning/               # Pamięć projektu (GSD workflow — STATE/ROADMAP/REQUIREMENTS)
    ├── Project.toml             # Deps + compat
    ├── Manifest.toml             # Pinned versions (commitowany — to aplikacja)
    ├── CONTRIBUTING.md          # Konwencje (encoding, ASCII, polski/angielski split, typografia)
    └── LICENSE                  # MIT
    ```

    ## Licencja

    MIT — patrz [`LICENSE`](LICENSE).
    ```

    KRYTYCZNE — typografia (per D-18 + CONTRIBUTING §4):
    - `„` (U+201E) + `"` (U+201D) — cudzysłowy w prozie. Sprawdź: `grep -c '„' README.md` ≥ 2, `grep -c '"' README.md` ≥ 2.
    - `—` (U+2014) — em-dash, używany jako myślnik wprost. NIE `--`. Sprawdź: `grep -c '—' README.md` ≥ 5.
    - `≥` (U+2265) w „Julia ≥ 1.10" — Unicode math symbol (akceptowalny, NFC composed).
    - `α` (U+03B1) w „α ≈ 0,9999" — grecki alfa (matematyczny).
    - NFC normalization, BOM-free, LF line endings, final newline `\n`.

    KRYTYCZNE — 9 sekcji w EXACT order (D-15 LOCKED):
    1. `# JuliaCity` (h1) + 1 zdanie Core Value
    2. `![Demo SA na 1000 punktach](assets/demo.gif)` (image embed — bez `## ` header dla samego GIFa)
    3. `## Wymagania`
    4. `## Instalacja`
    5. `## Quickstart` (3 fragmenty kodu z labels (a), (b), (c))
    6. `## Algorytm` (1-2 paragrafy z metaforą bańki mydlanej)
    7. `## Benchmarki` (link do bench/wyniki.md + headline + reprodukcja + lista skryptów)
    8. `## Struktura projektu` (drzewko ASCII)
    9. `## Licencja`

    Sprawdzenie liczby h2 sekcji: `grep -c '^## ' README.md` MUSI zwrócić DOKŁADNIE 7 (Wymagania, Instalacja, Quickstart, Algorytm, Benchmarki, Struktura projektu, Licencja — bez header'a `# JuliaCity` h1 i bez GIF embed który nie ma h2).

    KRYTYCZNE — empiryczny headline (Warning #2):
    - Po Task 1 (assets/demo.gif) i plan 04-06 Task 2 (bench/wyniki.md regenerated), executor MUSI sprawdzić rzeczywistą wartość `mean_ratio` ORAZ `std_ratio` w `bench/wyniki.md` i podstawić procent w sekcji „Benchmarki".
    - Domyślny tekst „~6% krótszą" zakłada `mean_ratio ≈ 0.94`. Jeśli empiryczny `mean_ratio` jest np. 0.937 → headline „~6% krótszą"; jeśli 0.952 → „~5% krótszą".
    - **Warning #2 guard:** jeśli `std_ratio > 0.02`, NIE zaokrąglaj do całkowitej — użyj średniej z 1 miejscem po przecinku (np. „~6,3% krótszą" jeśli mean_ratio=0.937, std=0.025).
    - Jeśli `std_ratio ≤ 0.02`, zaokrąglenie do całkowitej OK (np. „~6%").
    - Jeśli `mean_ratio > 1.0` (REGRESJA — SA gorsza niż NN): NIE WRITE README, zatrzymaj się i zgłoś jako bloker (sprawdzić czy bench_jakosc.jl użył T_zero=0.001).

    KRYTYCZNE — algorithm constants verification (BLOCKER #5):
    - Executor MUSI zastąpić placeholdery `{ALFA_VERIFIED}` i `{T_ZERO_VERIFIED}` w sekcji „Algorytm" zweryfikowanymi wartościami z `src/algorytmy/simulowane_wyzarzanie.jl` i `src/energia.jl` (kalibruj_T0).
    - Verify command: `julia --project=. -e 'using JuliaCity; punkty = generuj_punkty(100; seed=1); stan = StanSymulacji(punkty); inicjuj_nn!(stan); println(SimAnnealing(stan).alfa)'` — wartość zwrócona MUSI pasować do liczby w README (z polskim przecinkiem dziesiętnym).
    - Jeśli kalibruj_T0 implementuje 2σ(Δ-energii) — phrase pozostaje. Jeśli implementuje inną formułę, README użyje tej formuły.
    - **NIE shipuj README z literalnymi placeholderami `{ALFA_VERIFIED}`, `{T_ZERO_VERIFIED}`, `{HEADLINE_PERCENT}`** — wszystkie 3 muszą być zastąpione zweryfikowanymi wartościami.

    KRYTYCZNE — ścieżki w drzewku struktury:
    - Drzewko ASCII musi być zgodne z rzeczywistą strukturą po Phase 4. Sprawdź `ls src/`, `ls bench/`, `ls examples/` przed napisaniem.
    - Jeśli struktura odbiega (np. nowy plik w src/ pojawił się), zaktualizuj drzewko do faktycznego stanu.
  </action>
  <verify>
    <automated>test -f README.md &amp;&amp; grep -c '^## ' README.md &amp;&amp; grep -q '!\[.*\](assets/demo\.gif)' README.md &amp;&amp; grep -q '\[.*\](bench/wyniki\.md)' README.md &amp;&amp; grep -q '\[.*\](LICENSE)' README.md &amp;&amp; grep -q '„' README.md &amp;&amp; grep -q '—' README.md &amp;&amp; grep -q 'Wymagania' README.md &amp;&amp; grep -q 'Quickstart' README.md &amp;&amp; grep -q 'Benchmarki' README.md &amp;&amp; grep -q 'Licencja' README.md</automated>
  </verify>
  <acceptance_criteria>
    - `README.md` istnieje i ma > 80 linii (`wc -l README.md` ≥ 80; obecny plan generuje ~115 linii).
    - Liczba `## ` h2 nagłówków: DOKŁADNIE 7 (`grep -c '^## ' README.md` zwraca `7`).
    - Liczba `# ` h1 nagłówków: DOKŁADNIE 1 (`grep -c '^# ' README.md` zwraca `1`).
    - Wszystkie 7 h2 nagłówków obecne w EXACT order:
      - `## Wymagania`
      - `## Instalacja`
      - `## Quickstart`
      - `## Algorytm`
      - `## Benchmarki`
      - `## Struktura projektu`
      - `## Licencja`
    - Embed GIF: `grep -E '!\[.*\]\(assets/demo\.gif\)' README.md` zwraca exit 0.
    - Link do bench/wyniki.md: `grep -E '\[.*\]\(bench/wyniki\.md\)' README.md` zwraca exit 0.
    - Link do LICENSE: `grep -E '\[.*\]\(LICENSE\)' README.md` zwraca exit 0.
    - Polska typografia (D-18):
      - `grep -c '„' README.md` ≥ 1 (otwierający cudzysłów dolny U+201E).
      - `grep -c '—' README.md` ≥ 5 (em-dash U+2014, używany w wielu miejscach: header, opis algorytmu, lista benchmarków).
    - Empiryczny headline: zawiera literalny znak `%` w sekcji `## Benchmarki` z procentem (np. `~6%`, `~5%`, etc.) — sprawdzona zgodność z `bench/wyniki.md` mean_ratio.
    - 3 quickstart fragmenty: zawiera literały `**(a)`, `**(b)`, `**(c)` (markdown bold labels).
    - Drzewko struktury: zawiera `JuliaCity/`, `src/`, `test/`, `examples/`, `bench/`, `assets/`, `.planning/`, `Project.toml`, `Manifest.toml`, `CONTRIBUTING.md`, `LICENSE`.
    - Zawiera komendę reprodukcji benchmarków (BLOCKER #4 — wrapper, NIE direct julia): `bash bench/uruchom.sh` LUB `pwsh bench/uruchom.ps1`. Verify: `grep -E 'bash bench/uruchom\.sh|pwsh bench/uruchom\.ps1' README.md` zwraca exit 0.
    - **BLOCKER #5 — algorithm constants verified:**
      - Sekcja „Algorytm" zawiera DOKŁADNĄ wartość `alfa` z `src/algorytmy/simulowane_wyzarzanie.jl` (kwarg default `alfa::Float64=0.9999`). Verify CLI: `julia --project=. -e 'using JuliaCity; punkty = generuj_punkty(100; seed=1); stan = StanSymulacji(punkty); inicjuj_nn!(stan); println(SimAnnealing(stan).alfa)'` produkuje wartość pasującą do liczby w README (z polskim przecinkiem `0,9999` zamiast `0.9999`).
      - Sekcja „Algorytm" `T₀` phrasing pasuje do faktycznej formuły w `src/energia.jl::kalibruj_T0` (jeśli `2σ(Δ-energii)` → phrase OK; inaczej zaktualizować).
      - **README NIE zawiera literalnych stringów `{ALFA_VERIFIED}`, `{T_ZERO_VERIFIED}`, `{HEADLINE_PERCENT}`** (placeholdery zostały zastąpione): `grep -cE '\{ALFA_VERIFIED\}|\{T_ZERO_VERIFIED\}|\{HEADLINE_PERCENT\}' README.md` zwraca 0.
    - **WARNING #2 — headline matches bench/wyniki.md:**
      - README headline number dla SA/NN ratio pasuje do `mean_ratio` w `bench/wyniki.md` w obrębie ±1 punktu procentowego.
    - **WARNING #4 — struktura tree drift guard:**
      - Każdy plik `src/*.jl` (top-level i `src/algorytmy/*.jl`) wyświetlony przez `find src -maxdepth 2 -name "*.jl"` MUSI pojawić się w drzewku „Struktura projektu" w README. Verify (manual + CLI): output `find src -maxdepth 2 -name "*.jl"` porównać z linijkami w sekcji README po `## Struktura projektu`. Standard kontrakt na czas Phase 4: `JuliaCity.jl, typy.jl, punkty.jl, energia.jl, baselines.jl, wizualizacja.jl, algorytmy/simulowane_wyzarzanie.jl`.
    - Zawiera komendę uruchomienia demo: `julia --project=. --threads=auto examples/podstawowy.jl`.
    - Zawiera komendę uruchomienia demo: `julia --project=. --threads=auto examples/podstawowy.jl`.
    - BOM-free: `head -c3 README.md | xxd` NIE zawiera `efbbbf`.
    - Final newline: `tail -c1 README.md | xxd` zawiera `0a`.
    - LF line endings: `file README.md` raportuje "ASCII text" lub "UTF-8 Unicode text" (nie CRLF).
    - Encoding-guard test (`test/runtests.jl`) dalej przechodzi po edycji (sprawdza root-level `.md`).
  </acceptance_criteria>
  <done>README.md przepisany na 9 sekcji polskich z embed GIF, headline z bench/wyniki.md, polska typografia per D-18, drzewko struktury aktualne.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write (binary) | Plan zapisuje `assets/demo.gif` (~3-5 MB) — produkt animacji deterministycznej (seed=42, hardcoded fixture). Brak user input. |
| filesystem write (markdown) | Plan nadpisuje `README.md` z hardcoded skeleton + jednym wartościowym substituent (empiryczny headline `~N%` z bench/wyniki.md). |
| GLMakie GUI dependency | Task 1 wymaga lokalnego GPU/OpenGL — D-17 LOCKED, nie ma fallback CI. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-08-01 | Tampering | Empiryczny headline w README | mitigate | Acceptance criteria sprawdza obecność `%` w sekcji Benchmarki. Action explicit instruuje sprawdzenie `bench/wyniki.md` `mean_ratio` i dopasowanie procentu. Bloker przy regression (`mean_ratio > 1.0`). |
| T-04-08-02 | Tampering | Polska typografia (cudzysłowy + em-dash) | mitigate | Acceptance criteria sprawdza grep counts dla `„` i `—`. CONTRIBUTING §4 dokumentuje konwencję. Phase 1 encoding guard test waliduje NFC + BOM-free. |
| T-04-08-03 | Information Disclosure | Drzewko struktury projektu | accept | Public info; NIE eksponuje secrets ani PII. .gitignore zapewnia że żadne wrażliwe ścieżki (np. `.env`, secrets) nie znajdą się w drzewku README. |
| T-04-08-04 | Denial of Service | Repo size +3-5 MB po commit demo.gif | accept | D-05 LOCKED akceptuje rozmiar. PROJECT D-25 traktuje repo jak aplikację (binarne assets OK). |
| T-04-08-05 | Tampering | Demo.gif visual content | mitigate | Hardcoded seed=42 + fixture deterministyczny → reprodukowalna animacja. Każde uruchomienie `examples/eksport_mp4.jl` daje (powinno dać) bit-identical lub semantycznie identyczny GIF (drobne różnice z FFMPEG_jll quality settings możliwe — akceptowalne). |

Brak ASVS L1 controls naruszonych — read-only deterministic compute (Task 1) + static markdown rewrite (Task 2). README zawiera tylko publiczne info: link do LICENSE, link do bench/wyniki.md, embed GIF z repo.
</threat_model>

<verification>
- `assets/demo.gif` istnieje, ~3-5 MB, GIF89a format.
- `README.md` ma 9 sekcji (1 h1 + 7 h2 + 1 image embed bez nagłówka).
- Headline w sekcji Benchmarki linkuje empirycznie do `bench/wyniki.md` i pokazuje procent zgodny z `mean_ratio`.
- Polish typography: minimum 1 `„`, minimum 5 `—`.
- Encoding guard test (`test/runtests.jl`) PASS na zaktualizowanym README.md (NFC, BOM-free).
- ROADMAP SC #5 spełnione: README po polsku, Core Value, instalacja, quickstart, demo GIF, sekcja benchmarków z liczbami vs NN baseline.
</verification>

<success_criteria>
- DEMO-02 spełnione: `assets/demo.gif` istnieje (lub `assets/demo.mp4` — D-01 wybiera GIF).
- LANG-03 spełnione: README.md w pełni po polsku, Core Value + instalacja + quickstart + GIF + benchmark numbers.
- D-15 spełnione: 9 sekcji w exact order.
- D-18 spełnione: polska typografia (cudzysłowy, em-dash, NFC).
- Phase 4 ROADMAP SC #1-5 wszystkie spełnione (po wcześniejszych planach 04-01..04-07).
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-08-SUMMARY.md`

Po tym planie Phase 4 jest COMPLETE — wszystkie 11 REQ-IDs (DEMO-01..04, BENCH-01..05, LANG-02, LANG-03) pokryte.
</output>
