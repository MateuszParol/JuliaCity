---
phase: 04-demo-benchmarks-documentation
plan: 04
type: execute
wave: 2
depends_on:
  - 01
files_modified:
  - bench/bench_energia.jl
  - bench/bench_krok.jl
autonomous: true
requirements:
  - BENCH-01
  - BENCH-02
  - BENCH-04
must_haves:
  truths:
    - "bench/bench_energia.jl mierzy oblicz_energie z BenchmarkTools @benchmark + $ interpolacją + fresh setup= per sample"
    - "bench/bench_krok.jl mierzy symuluj_krok! z BenchmarkTools @benchmark + fresh stan per sample (no state accumulation)"
    - "Oba skrypty mają function main() wrapper i są ładowane przez orchestrator (run_all.jl) w izolowanym module"
    - "Oba skrypty zwracają BenchmarkTools.Trial dla orchestratora bench/run_all.jl"
  artifacts:
    - path: "bench/bench_energia.jl"
      provides: "Microbench oblicz_energie 3-arg na fixture N=1000 (fresh per sample)"
      contains: "@benchmark"
    - path: "bench/bench_krok.jl"
      provides: "Microbench symuluj_krok! z fresh stan per sample (no SA-loop drift)"
      contains: "setup="
  key_links:
    - from: "bench/bench_energia.jl"
      to: "JuliaCity.oblicz_energie"
      via: "interpolated benchmark call with fresh setup"
      pattern: "@benchmark oblicz_energie"
    - from: "bench/bench_krok.jl"
      to: "JuliaCity.symuluj_krok!"
      via: "interpolated benchmark call with fresh stan setup + warmup"
      pattern: "@benchmark symuluj_krok!"
---

<objective>
Wave 2: Stworzyć dwa microbenchmarki BenchmarkTools dla najgorętszych funkcji core'u: `oblicz_energie` (full energy recompute) i `symuluj_krok!` (one SA step with delta evaluation). Oba używają `$` interpolacji + `setup=` z FRESH stan per sample (Phase 2 D-08 zero-alloc warmup discipline + sample stationarity — per checker iteracja 1 BLOCKER #2: bez fresh setup `stan` akumuluje state przez tysiące samples i drifts poza Parametry.liczba_krokow).

Purpose: Daje empiryczne liczby (median time, memory, allocs) do `bench/wyniki.md` (Wave 3 orchestrator) i potwierdza Phase 2 D-08 zero-alloc gwarancję na działającym fixture. Skrypty są wywoływane WYŁĄCZNIE przez orchestrator `bench/run_all.jl` (plan 04-06) — orchestrator ładuje je w izolowanych modułach (`Module(:_BenchSandbox)`) by uniknąć kolizji `Main.main` (BLOCKER #3 fix).
Output: 2 nowe skrypty `bench/bench_energia.jl` + `bench/bench_krok.jl`.
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
@src/baselines.jl
@src/energia.jl
@src/algorytmy/simulowane_wyzarzanie.jl

<interfaces>
<!-- Key types and contracts the executor needs. Extracted from codebase. -->

From src/JuliaCity.jl exports:
```julia
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty,
       Parametry, SimAnnealing,
       oblicz_macierz_dystans!, oblicz_energie, delta_energii, kalibruj_T0,
       trasa_nn, inicjuj_nn!,
       symuluj_krok!, uruchom_sa!,
       wizualizuj
```

From src/baselines.jl (line ~98-99):
```julia
bufor = zeros(Float64, Threads.nthreads())             # alloc OK — wywoływane raz
stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
```

oblicz_energie signatures (verified — Phase 2 D-08):
- `oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})::Float64` (2-arg, slower path)
- `oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64` (3-arg, zero-alloc po warmup, threaded)

symuluj_krok! signature (Phase 2 ALG-02):
- `symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing)::Nothing` (mutuje stan in-place; @allocated == 0 po warmup TEST-03)

StableRNG (test-deps, available przez [targets].test po plan 04-01):
- `StableRNG(42)` — deterministyczny seed cross-version stable. Używany w bench setup= dla bit-stable fixture.

Fixture pattern (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn) — wykonywany wewnątrz `setup=` per-sample dla stationarity:
```julia
rng = StableRNG(42)
punkty = generuj_punkty(1000; seed=42)
stan = StanSymulacji(punkty)        # rng kwarg może być brak; punkty deterministyczne
inicjuj_nn!(stan)                    # ustawia stan.energia = energia_nn (Phase 2 D-08 cache invariant)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Utwórz bench/bench_energia.jl (fresh fixture per sample)</name>
  <read_first>
    - src/baselines.jl (linie ~95-100 — bufor pattern, sygnatura `oblicz_energie(stan.D, stan.trasa, bufor)`)
    - src/energia.jl (potwierdzić sygnaturę 3-arg oblicz_energie)
    - bench/historyczne/diagnostyka_test05.jl (linie 1-19 i 59-69 — header docstring + fresh_stan_with_nn)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/bench_energia.jl" — exact code excerpt)
  </read_first>
  <action>
    Utworzyć plik `bench/bench_energia.jl` z fresh-fixture-per-sample pattern (polski, NFC, BOM-free, LF, final newline; ASCII identyfikatory):

    ```julia
    # bench/bench_energia.jl
    #
    # Microbench `oblicz_energie` (3-arg, threaded) na fixture N=1000 (Phase 4 BENCH-01, BENCH-04).
    # Mierzy median time + memory + alokacje (D-07).
    # Phase 2 D-08 gwarancja: zero-alloc po warmup — sprawdzone w teście TEST (PerformanceTestTools).
    #
    # Pattern fresh-per-sample: setup= rebuilduje fixture przed kazda probka dla
    # stationarity (uniform pattern z bench_krok.jl — checker iteracja 1 BLOCKER #2 + Warning #1).
    # `oblicz_energie` jest non-mutating, ale konsystentnosc setup-pattern uproszcza review
    # i pasuje do Phase 2 D-08 zero-alloc warmup discipline.
    #
    # Uruchomienie WYLACZNIE przez orchestrator (D-06 + checker iteracja 1 BLOCKER #4):
    #   bash bench/uruchom.sh        (POSIX)
    #   pwsh bench/uruchom.ps1       (PowerShell)
    # Standalone: include z Julia REPL z BenchmarkTools dostepnym, potem main() — main()
    # zwraca BenchmarkTools.Trial.

    using JuliaCity
    using BenchmarkTools
    using StableRNGs: StableRNG

    function main()
        # BENCH-04: $ interpolacja eliminuje boxing globals (Pitfall „@btime bez $").
        # Fresh fixture per sample przez setup= — uniform z bench_krok.jl (checker BLOCKER #2).
        # evals=1: trial.allocs odpowiada jednemu wywolaniu oblicz_energie (czysty pomiar
        # zero-alloc gwarancji per Phase 2 D-08).
        # samples=200, seconds=5: ograniczenie wallclock'a — bench_energia jest szybki (~us).
        wynik = BenchmarkTools.@benchmark begin
            oblicz_energie(stan.D, stan.trasa, bufor)
        end setup = (
            rng = StableRNG(42);
            punkty = generuj_punkty(1000; seed=42);
            stan = StanSymulacji(punkty);
            inicjuj_nn!(stan);
            bufor = zeros(Float64, Threads.nthreads())
        ) evals = 1 samples = 200 seconds = 5

        return wynik
    end
    ```

    KRYTYCZNE:
    - Fresh `setup=` block per sample (uniform z bench_krok per BLOCKER #2 + Warning #1) — `oblicz_energie` jest non-mutating, ale consistency upraszcza review; `StableRNG(42)` zapewnia bit-stable fixture cross-version.
    - `evals=1` — bez tego BenchmarkTools agreguje N evals w jedną próbkę (memory/allocs to suma) i pomiar zero-alloc gwarancji jest nieczytelny.
    - W `setup=` używamy lokalnych zmiennych (`stan`, `bufor`) — w body `oblicz_energie(stan.D, stan.trasa, bufor)` — BenchmarkTools widzi je jako interpolated locals (NIE globals), więc nie potrzebujemy `$` (nazwy `setup=` są captured automatycznie).
    - 3-arg sygnatura `oblicz_energie(stan.D, stan.trasa, bufor)` — Phase 2 D-08 zero-alloc threaded path.
    - Header docstring 9+ linii top-of-file zgodnie z PATTERNS.md "Header Docstring Convention".
    - `function main()` wrapper LOCKED dla orchestrator includes (D-06). NIE wywołujemy `main()` na końcu pliku — orchestrator (plan 04-06) ładuje plik w izolowanym module i ręcznie wywołuje `Base.invokelatest(m.main)`.
    - BRAK standalone branch `if abspath(PROGRAM_FILE) == @__FILE__` — checker BLOCKER #4: standalone `julia bench/bench_energia.jl` nie znajdzie BenchmarkTools (D-10 + Pkg.jl resolver limit). Uruchamianie WYŁĄCZNIE przez `bench/uruchom.{sh,ps1}` wrapper który aktywuje throwaway env z BenchmarkTools.
  </action>
  <verify>
    <automated>test -f bench/bench_energia.jl &amp;&amp; grep -q 'oblicz_energie(stan.D' bench/bench_energia.jl &amp;&amp; grep -q 'function main()' bench/bench_energia.jl &amp;&amp; grep -q 'using BenchmarkTools' bench/bench_energia.jl &amp;&amp; grep -q 'setup =' bench/bench_energia.jl &amp;&amp; grep -q 'StableRNG' bench/bench_energia.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/bench_energia.jl` istnieje.
    - Zawiera literalny string `using BenchmarkTools`.
    - Zawiera literalny string `using JuliaCity`.
    - Zawiera literalny string `using StableRNGs: StableRNG` (fresh fixture seed).
    - Zawiera literalny string `@benchmark` (BenchmarkTools macro).
    - Zawiera `setup =` block (fresh-per-sample pattern — BLOCKER #2 fix; uniform z bench_krok).
    - Setup block zawiera DOKŁADNIE: `StableRNG(`, `generuj_punkty(`, `StanSymulacji(`, `inicjuj_nn!(`, `zeros(Float64,` — wszystkie 5 (`grep -c` w setup region ≥ 5).
    - Zawiera `evals = 1` (per-call zero-alloc weryfikacja).
    - Zawiera `samples = 200` LUB `samples=200` (bound wallclock).
    - Zawiera `seconds = 5` LUB `seconds=5` (bound wallclock).
    - Zawiera `function main()` (D-06).
    - Zawiera `inicjuj_nn!(stan)` (Phase 2 fixture).
    - Zawiera header docstring zaczynający od `# bench/bench_energia.jl` (PATTERNS.md convention).
    - NIE zawiera standalone branch `abspath(PROGRAM_FILE)` (BLOCKER #4 fix — uruchamianie tylko przez wrapper).
    - NIE zawiera `main()` na końcu pliku jako top-level call — `grep -c '^main()$' bench/bench_energia.jl` zwraca 0.
    - Standalone smoke (zaktualizowane per BLOCKER #4): `include` z Julia REPL z BenchmarkTools dostępnym; weryfikacja: `main()` zwraca `BenchmarkTools.Trial`.
    - BOM-free, LF, final newline (encoding hygiene).
    - ASCII-only identyfikatory.
  </acceptance_criteria>
  <done>bench/bench_energia.jl gotowy: BenchmarkTools fresh-per-sample setup + 3-arg oblicz_energie + evals=1 + StableRNG fixture.</done>
</task>

<task type="auto">
  <name>Task 2: Utwórz bench/bench_krok.jl (fresh stan per sample — BLOCKER #2 fix)</name>
  <read_first>
    - test/test_symulacja.jl (linie ~60-85 — zero-alloc helper `_alloc_krok` + warmup pattern)
    - src/algorytmy/simulowane_wyzarzanie.jl (sygnatura symuluj_krok!)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/bench_krok.jl" — exact code excerpt)
    - bench/bench_energia.jl (właśnie utworzony — żeby zachować spójny styl header'a + fresh setup pattern)
  </read_first>
  <action>
    Utworzyć plik `bench/bench_krok.jl` z fresh-stan-per-sample pattern (polski, NFC, BOM-free, LF, final newline). KRYTYCZNY FIX z checker iteracja 1 BLOCKER #2: poprzednia wersja używała `setup=(symuluj_krok!($stan, $params, $alg))` z modyfikowaniem TEGO SAMEGO `stan` przez tysiące samples — `stan.iteracja` przekraczała `Parametry.liczba_krokow=50_000` i SA-loop semantyka driftowała. NOWA wersja rebuilduje `stan` od zera per sample + 1× warmup step:

    ```julia
    # bench/bench_krok.jl
    #
    # Microbench `symuluj_krok!` (jeden krok SA z delta-energy + Metropolis) na fixture N=1000 (BENCH-02, BENCH-04).
    # Mierzy median time + memory + alokacje (D-07).
    # Phase 2 TEST-03 gwarantuje @allocated == 0 po warmup; bench potwierdza empirycznie.
    #
    # Fresh-stan-per-sample (checker iteracja 1 BLOCKER #2):
    # setup= rebuildujce fresh `stan` + jeden warmup `symuluj_krok!` PRZED kazdym pomiarem.
    # Bez tego stan akumuluje state przez tysiace samples (stan.iteracja przekracza
    # Parametry.liczba_krokow=50_000) i SA-loop semantyka drifts od pomiaru fresh single-step.
    #
    # Uruchomienie WYLACZNIE przez orchestrator (D-06 + checker BLOCKER #4):
    #   bash bench/uruchom.sh        (POSIX)
    #   pwsh bench/uruchom.ps1       (PowerShell)
    # Standalone: include z Julia REPL z BenchmarkTools dostepnym, potem main() — main()
    # zwraca BenchmarkTools.Trial.

    using JuliaCity
    using BenchmarkTools
    using StableRNGs: StableRNG

    function main()
        # BENCH-04: $ interpolacja eliminuje boxing globals (przez setup= captured locals).
        # Fresh stan per sample (BLOCKER #2): kazda probka dostaje swiezo zainicjowany stan
        # z 1x warmup step (mid-flight measurement, NIE first-step compile).
        # evals=1: pojedyncze wywolanie per probka, czytelne allocs (Phase 2 TEST-03 lock).
        # samples=200, seconds=5: bound wallclock — pojedynczy krok ~us, full setup ~ms,
        # 200 probek × ~ms = ~sec (akceptowalne).
        wynik = BenchmarkTools.@benchmark begin
            symuluj_krok!(stan, params, alg)
        end setup = (
            rng = StableRNG(42);
            punkty = generuj_punkty(1000; seed=42);
            stan = StanSymulacji(punkty);
            inicjuj_nn!(stan);
            params = Parametry(liczba_krokow=50_000);
            alg = SimAnnealing(stan);
            stan.temperatura = alg.T_zero;
            symuluj_krok!(stan, params, alg)
        ) evals = 1 samples = 200 seconds = 5

        return wynik
    end
    ```

    KRYTYCZNE:
    - `setup=` block buduje FRESH `stan` per sample przez: `StableRNG(42) → generuj_punkty → StanSymulacji → inicjuj_nn! → Parametry → SimAnnealing(stan) → stan.temperatura = alg.T_zero → symuluj_krok! (warmup)`. Ostatnia linijka setupu (1× `symuluj_krok!`) zapewnia że BenchmarkTools mierzy "mid-flight" (po JIT compile + co najmniej 1 ruch), NIE first-step.
    - `evals=1` — pojedyncze wywołanie per próbka (jak bench_energia) — wymóg zero-alloc weryfikacji.
    - `samples=200, seconds=5` — bound całkowity wallclock (~10s w realiach z setup-overhead).
    - `Parametry(liczba_krokow=50_000)` — stan.iteracja w kazdej probce zaczyna od 1 (po warmup), nie zbliza się do liczba_krokow LIMITU (BLOCKER #2 fix).
    - `alg = SimAnnealing(stan)` — używa default 2σ kalibracji (NIE T_zero=0.001 — to override tylko dla bench_jakosc).
    - `stan.temperatura = alg.T_zero` — explicit per docstring `SimAnnealing` (immutable struct nie ustawia temperatura sam).
    - W body `symuluj_krok!(stan, params, alg)` — captured locals z setup, brak `$` interpolation needed.
    - Brak top-level `main()` call (orchestrator robi `Base.invokelatest(m.main)`).
    - Brak standalone branch (BLOCKER #4 — uruchamianie przez wrapper).
  </action>
  <verify>
    <automated>test -f bench/bench_krok.jl &amp;&amp; grep -q 'symuluj_krok!(stan, params, alg)' bench/bench_krok.jl &amp;&amp; grep -q 'setup =' bench/bench_krok.jl &amp;&amp; grep -q 'function main()' bench/bench_krok.jl &amp;&amp; grep -q 'StanSymulacji(' bench/bench_krok.jl &amp;&amp; grep -q 'inicjuj_nn!(' bench/bench_krok.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/bench_krok.jl` istnieje.
    - Zawiera literalny string `using BenchmarkTools`.
    - Zawiera literalny string `using JuliaCity`.
    - Zawiera literalny string `using StableRNGs: StableRNG`.
    - Zawiera literalny string `@benchmark` (BenchmarkTools macro).
    - Zawiera `setup =` block (BLOCKER #2 fresh-per-sample fix).
    - Setup block zawiera DOKŁADNIE następujące tokeny (verify każdy obecny):
      - `StableRNG(`
      - `generuj_punkty(`
      - `StanSymulacji(`
      - `inicjuj_nn!(`
      - `Parametry(`
      - `SimAnnealing(`
      - `stan.temperatura = alg.T_zero`
      - Trailing single `symuluj_krok!(` line PRZED `) evals = 1` (warmup)
    - Body benchmark to `symuluj_krok!(stan, params, alg)` (single line w `begin`/`end` bloku).
    - Zawiera `evals = 1`.
    - Zawiera `samples = 200` LUB `samples=200`.
    - Zawiera `seconds = 5` LUB `seconds=5`.
    - Zawiera `function main()`.
    - Header docstring zaczyna od `# bench/bench_krok.jl`.
    - NIE zawiera top-level `main()` call (orchestrator robi `Base.invokelatest(m.main)`).
    - NIE zawiera standalone branch `abspath(PROGRAM_FILE)` (BLOCKER #4).
    - NIE zawiera `T_zero=0.001` (default kalibracja, NIE erratum override — to tylko bench_jakosc).
    - Standalone smoke (BLOCKER #4 zaktualizowane): `include` z Julia REPL z BenchmarkTools dostępnym; `main()` zwraca `BenchmarkTools.Trial`.
    - BOM-free, LF, final newline.
  </acceptance_criteria>
  <done>bench/bench_krok.jl gotowy: BenchmarkTools fresh-stan-per-sample setup + 1x warmup + symuluj_krok! + evals=1.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 2 nowe pliki Julia w bench/. Brak wejścia użytkownika, brak network, brak persistence danych. |
| benchmark execution | Skrypty czytają tylko deterministyczny seed-controlled fixture (StableRNG(42), seed=42); nie modyfikują stanu globalnego poza lokalnym `stan::StanSymulacji` per setup-block sample. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-04-01 | Tampering | BenchmarkTools fresh setup= sample stationarity | mitigate | Acceptance criteria sprawdza obecność `StanSymulacji(`, `inicjuj_nn!(`, `Parametry(`, `SimAnnealing(`, oraz trailing `symuluj_krok!(` warmup. Bez fresh setup state akumuluje się przez tysiące samples (BLOCKER #2). |
| T-04-04-02 | Information Disclosure | Sysinfo w benchmark output | accept | `Sys.cpu_info()[1].model`, `Threads.nthreads()`, `VERSION` to publiczne info; orchestrator (Wave 3) zapisuje do `bench/wyniki.md` commitowanego w repo — przewidziane przez D-07. |

Brak ASVS L1 controls naruszonych — read-only deterministic compute.
</threat_model>

<verification>
- Standalone smoke (BLOCKER #4 path): `julia --project=. -e 'using Pkg; Pkg.activate(temp=true); Pkg.develop(path="."); Pkg.add("BenchmarkTools"); include("bench/bench_energia.jl"); println(typeof(main()))'` zwraca `BenchmarkTools.Trial`.
- Analogiczne dla `bench_krok.jl` — `main()` zwraca `BenchmarkTools.Trial`.
- BenchmarkTools.Trial.allocs == 0 dla bench_krok (Phase 2 TEST-03 lock); allocs niski dla bench_energia (Phase 2 D-08 zero-alloc-after-warmup).
- W `setup=` block stan.iteracja przed pomiarem wynosi DOKŁADNIE 1 (warmup step), NIE rośnie poza limity Parametry.
</verification>

<success_criteria>
- 2 microbenchmarki `bench_energia.jl` + `bench_krok.jl` używają `@benchmark` + fresh `setup=` per sample (BLOCKER #2 fix; uniform pattern).
- Oba zwracają BenchmarkTools.Trial dla orchestratora przy ładowaniu w izolowanym module (BLOCKER #3 fix przez orchestrator).
- Phase 2 zero-alloc gwarancja widoczna empirycznie w trial.allocs.
- Standalone uruchomienie wyłącznie przez `bench/uruchom.{sh,ps1}` wrapper (BLOCKER #4) lub manual REPL include z BenchmarkTools available.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-04-SUMMARY.md`
</output>
