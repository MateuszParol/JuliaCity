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
    - "bench/bench_energia.jl mierzy oblicz_energie z BenchmarkTools @benchmark + $ interpolacją"
    - "bench/bench_krok.jl mierzy symuluj_krok! z BenchmarkTools @benchmark + setup= warmup discipline"
    - "Oba skrypty mają function main() wrapper i są samodzielnie uruchamialne"
    - "Oba skrypty zwracają BenchmarkTools.Trial dla orchestratora bench/run_all.jl"
  artifacts:
    - path: "bench/bench_energia.jl"
      provides: "Microbench oblicz_energie 3-arg na fixture N=1000"
      contains: "@benchmark"
    - path: "bench/bench_krok.jl"
      provides: "Microbench symuluj_krok! z warmup discipline"
      contains: "setup="
  key_links:
    - from: "bench/bench_energia.jl"
      to: "JuliaCity.oblicz_energie"
      via: "interpolated benchmark call"
      pattern: "@benchmark oblicz_energie\\(\\$"
    - from: "bench/bench_krok.jl"
      to: "JuliaCity.symuluj_krok!"
      via: "interpolated benchmark call with setup warmup"
      pattern: "@benchmark symuluj_krok!\\(\\$.*\\) setup="
---

<objective>
Wave 2: Stworzyć dwa microbenchmarki BenchmarkTools dla najgorętszych funkcji core'u: `oblicz_energie` (full energy recompute) i `symuluj_krok!` (one SA step with delta evaluation). Oba używają `$` interpolacji + `setup=` warmup discipline (BENCH-04 explicit).

Purpose: Daje empiryczne liczby (median time, memory, allocs) do `bench/wyniki.md` (Wave 3 orchestrator) i potwierdza Phase 2 D-08 zero-alloc gwarancję na działającym fixture.
Output: 2 nowe skrypty `bench/bench_energia.jl` + `bench/bench_krok.jl`, samodzielnie uruchamialne i konsumowane przez `bench/run_all.jl`.
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

Fixture pattern (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn):
```julia
function fresh_stan_with_nn()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)   # ustawia stan.energia = energia_nn (Phase 2 D-08 cache invariant)
    return stan
end
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Utwórz bench/bench_energia.jl</name>
  <read_first>
    - src/baselines.jl (linie ~95-100 — bufor pattern, sygnatura `oblicz_energie(stan.D, stan.trasa, bufor)`)
    - src/energia.jl (potwierdzić sygnaturę 3-arg oblicz_energie)
    - bench/historyczne/diagnostyka_test05.jl (linie 1-19 i 59-69 — header docstring + fresh_stan_with_nn)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/bench_energia.jl" — exact code excerpt)
  </read_first>
  <action>
    Utworzyć plik `bench/bench_energia.jl` z następującą zawartością (polski, NFC, BOM-free, LF, final newline; ASCII identyfikatory):

    ```julia
    # bench/bench_energia.jl
    #
    # Microbench `oblicz_energie` (3-arg, threaded) na fixture N=1000 (Phase 4 BENCH-01, BENCH-04).
    # Mierzy median time + memory + alokacje (D-07).
    # Phase 2 D-08 gwarancja: zero-alloc po warmup — sprawdzone w teście TEST (PerformanceTestTools).
    #
    # Uruchomienie standalone:
    #   julia --project=. --threads=auto bench/bench_energia.jl
    # Lub przez orchestrator:
    #   julia --project=. --threads=auto bench/run_all.jl

    using JuliaCity
    using BenchmarkTools
    using Random: Xoshiro

    function main()
        # Fixture (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn lines 59-64)
        punkty = generuj_punkty(1000; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        bufor = zeros(Float64, Threads.nthreads())   # alloc raz, reuse w benchmarku

        # BENCH-04: $ interpolacja eliminuje boxing globals (Pitfall „@btime bez $").
        # Phase 2 D-08: zero-alloc po warmup — BenchmarkTools dyskwalifikuje pierwsza probke automatycznie,
        # wiec setup= NIE jest wymagane dla samego pomiaru (warmup zaszyty). Dodajemy evals=1
        # zeby trial.allocs odpowiadal jednemu wywolaniu funkcji (czysty pomiar zero-alloc gwarancji).
        wynik = @benchmark oblicz_energie($stan.D, $stan.trasa, $bufor) evals=1

        return wynik
    end

    # Standalone run (gdy plik wywolany bezposrednio, NIE przez include z orchestratora)
    if abspath(PROGRAM_FILE) == @__FILE__
        wynik = main()
        println("="^60)
        println("[bench_energia] oblicz_energie (3-arg, N=1000, threads=$(Threads.nthreads())):")
        println("="^60)
        show(stdout, MIME"text/plain"(), wynik)
        println()
    end
    ```

    KRYTYCZNE:
    - `evals=1` — bez tego BenchmarkTools agreguje N evals w jedną próbkę (memory/allocs to suma) i pomiar zero-alloc gwarancji jest nieczytelny (chcemy `allocs == 0` per pojedyncze wywołanie).
    - 3-arg sygnatura `oblicz_energie($stan.D, $stan.trasa, $bufor)` — interpoluje pola, NIE samego `$stan` (`stan.D` byłoby getproperty na boxowanym globalu).
    - `@info` po polsku jeśli będą — ALE tu jest tylko `println` w standalone branch (nie user-facing strings które wymagają polskiego marketingu).
    - Header docstring 7+ linii top-of-file zgodnie z PATTERNS.md "Header Docstring Convention".
    - `function main()` wrapper jest LOCKED dla examples (D-12); w bench/* zalecany dla orchestrator include (D-06 — „każdy ma `function main()`"). NIE wywołujemy `main()` na końcu pliku — orchestrator `bench/run_all.jl` będzie `include` i odwoła się do `Main.main()` lub przekaże return value przez `include` (verify which pattern in Wave 3).
    - Standalone branch `if abspath(PROGRAM_FILE) == @__FILE__` pozwala na samodzielne uruchomienie bez wywoływania `main()` przy `include` z orchestratora.
  </action>
  <verify>
    <automated>test -f bench/bench_energia.jl &amp;&amp; grep -q '@benchmark oblicz_energie(\$stan.D' bench/bench_energia.jl &amp;&amp; grep -q 'function main()' bench/bench_energia.jl &amp;&amp; grep -q 'using BenchmarkTools' bench/bench_energia.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/bench_energia.jl` istnieje.
    - Zawiera literalny string `using BenchmarkTools`.
    - Zawiera literalny string `using JuliaCity`.
    - Zawiera literalny string `@benchmark` (BenchmarkTools macro).
    - Zawiera literalny string `$stan.D` (interpolacja — BENCH-04 wymóg).
    - Zawiera literalny string `$stan.trasa` (interpolacja).
    - Zawiera literalny string `$bufor` (interpolacja).
    - Zawiera `evals=1` (per-call zero-alloc weryfikacja).
    - Zawiera `function main()` (D-06).
    - Zawiera `inicjuj_nn!(stan)` (Phase 2 fixture).
    - Zawiera header docstring zaczynający od `# bench/bench_energia.jl` (PATTERNS.md convention).
    - NIE zawiera `main()` na końcu pliku jako top-level call (orchestrator robi include + manual call) — `grep -c '^main()$' bench/bench_energia.jl` zwraca 0.
    - BOM-free, LF, final newline (encoding hygiene).
    - ASCII-only identyfikatory: `grep -P '[^\x00-\x7F]' bench/bench_energia.jl` w komentarzach OK (polski tekst), ale w identyfikatorach Julia — żadnych diakrytyków.
  </acceptance_criteria>
  <done>bench/bench_energia.jl gotowy: BenchmarkTools fixture + 3-arg oblicz_energie + $ interpolacja + evals=1.</done>
</task>

<task type="auto">
  <name>Task 2: Utwórz bench/bench_krok.jl</name>
  <read_first>
    - test/test_symulacja.jl (linie ~60-85 — zero-alloc helper `_alloc_krok` + warmup pattern)
    - src/algorytmy/simulowane_wyzarzanie.jl (sygnatura symuluj_krok!)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/bench_krok.jl" — exact code excerpt)
    - bench/bench_energia.jl (właśnie utworzony — żeby zachować spójny styl header'a)
  </read_first>
  <action>
    Utworzyć plik `bench/bench_krok.jl` (polski, NFC, BOM-free, LF, final newline):

    ```julia
    # bench/bench_krok.jl
    #
    # Microbench `symuluj_krok!` (jeden krok SA z delta-energy + Metropolis) na fixture N=1000 (BENCH-02, BENCH-04).
    # Mierzy median time + memory + alokacje (D-07).
    # Phase 2 TEST-03 gwarantuje @allocated == 0 po warmup; bench potwierdza empirycznie.
    #
    # Uruchomienie standalone:
    #   julia --project=. --threads=auto bench/bench_krok.jl
    # Lub przez orchestrator:
    #   julia --project=. --threads=auto bench/run_all.jl

    using JuliaCity
    using BenchmarkTools
    using Random: Xoshiro

    function main()
        # Fixture
        punkty = generuj_punkty(1000; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=50_000)

        # BENCH-04: setup= warmup discipline.
        # Phase 2 D-08: zero-alloc tylko po warmup — pierwsze wywolanie symuluj_krok! kompiluje
        # (JIT) i moze alokowac. setup=(symuluj_krok!(...)) zapewnia ze stan jest w „runtime state"
        # (po jit + co najmniej jeden krok). $ interpolacja eliminuje boxing globals.
        # evals=1 — pojedyncze wywolanie per probka, czytelne allocs.
        wynik = @benchmark symuluj_krok!($stan, $params, $alg) setup=(symuluj_krok!($stan, $params, $alg)) evals=1

        return wynik
    end

    if abspath(PROGRAM_FILE) == @__FILE__
        wynik = main()
        println("="^60)
        println("[bench_krok] symuluj_krok! (SA-2-opt, N=1000, threads=$(Threads.nthreads())):")
        println("="^60)
        show(stdout, MIME"text/plain"(), wynik)
        println()
    end
    ```

    KRYTYCZNE:
    - `setup=(symuluj_krok!($stan, $params, $alg))` — wykonuje 1 krok przed pomiarem żeby JIT skompilował (warmup discipline). UWAGA: setup zostawia `stan` w stanie post-1-krok (temp obniżona, 1 ruch ewentualnie zaakceptowany), co jest realistic runtime state — dokładnie czego chcemy mierzyć.
    - `$stan, $params, $alg` — wszystkie 3 globalne pola interpolowane, eliminuje boxing (Pitfall BENCH-04).
    - `evals=1` (jak w bench_energia) — wymóg zero-alloc weryfikacji.
    - `Parametry(liczba_krokow=50_000)` — to tylko warunek końca dla `uruchom_sa!`, ale `symuluj_krok!` używa go pośrednio do logiki cooling. Wartość `50_000` zgodna z fixture diagnostyki Phase 2.
    - `alg = SimAnnealing(stan); stan.temperatura = alg.T_zero` — exact pattern z `bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn` (potwierdzić w PATTERNS.md).
    - Brak top-level `main()` call (orchestrator robi include + ręczne wywołanie).
  </action>
  <verify>
    <automated>test -f bench/bench_krok.jl &amp;&amp; grep -q '@benchmark symuluj_krok!(\$stan' bench/bench_krok.jl &amp;&amp; grep -q 'setup=' bench/bench_krok.jl &amp;&amp; grep -q 'function main()' bench/bench_krok.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/bench_krok.jl` istnieje.
    - Zawiera literalny string `using BenchmarkTools`.
    - Zawiera literalny string `using JuliaCity`.
    - Zawiera literalny string `@benchmark symuluj_krok!($stan` (BenchmarkTools macro + interpolacja).
    - Zawiera literalny string `setup=` (warmup discipline — BENCH-04 wymóg).
    - Zawiera literalny string `setup=(symuluj_krok!($stan, $params, $alg))` (warmup wykonuje krok przed pomiarem).
    - Zawiera `evals=1`.
    - Zawiera `function main()`.
    - Zawiera `inicjuj_nn!(stan)` + `alg = SimAnnealing(stan)` + `stan.temperatura = alg.T_zero` (Phase 2 fixture pattern).
    - Header docstring zaczyna od `# bench/bench_krok.jl`.
    - NIE zawiera top-level `main()` call.
    - BOM-free, LF, final newline.
  </acceptance_criteria>
  <done>bench/bench_krok.jl gotowy: BenchmarkTools fixture + symuluj_krok! + $ interpolacja + setup= warmup + evals=1.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 2 nowe pliki Julia w bench/. Brak wejścia użytkownika, brak network, brak persistence danych. |
| benchmark execution | Skrypty czytają tylko deterministyczny seed-controlled fixture (seed=42); nie modyfikują stanu globalnego poza lokalnym `stan::StanSymulacji`. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-04-01 | Tampering | BenchmarkTools `$` interpolation | mitigate | Acceptance criteria sprawdza literalnie obecność `$stan.D`, `$stan.trasa`, `$bufor`. Bez interpolacji benchmark mierzy boxing globals zamiast hot path (Pitfall BENCH-04). |
| T-04-04-02 | Information Disclosure | Sysinfo w benchmark output | accept | `Sys.cpu_info()[1].model`, `Threads.nthreads()`, `VERSION` to publiczne info; orchestrator (Wave 3) zapisuje do `bench/wyniki.md` commitowanego w repo — przewidziane przez D-07. |

Brak ASVS L1 controls naruszonych — read-only deterministic compute.
</threat_model>

<verification>
- Smoke test (jeśli toolchain dostępny): `julia --project=. --threads=auto bench/bench_energia.jl` zwraca exit 0 i wypisuje BenchmarkTools.Trial table.
- `julia --project=. --threads=auto bench/bench_krok.jl` zwraca exit 0 i wypisuje BenchmarkTools.Trial table.
- BenchmarkTools.Trial.allocs == 0 dla bench_krok (Phase 2 TEST-03 lock); allocs niski dla bench_energia (Phase 2 D-08 zero-alloc-after-warmup).
</verification>

<success_criteria>
- 2 microbenchmarki `bench_energia.jl` + `bench_krok.jl` używają `@benchmark` + `$` interpolacji + `setup=` warmup discipline (BENCH-04).
- Oba zwracają BenchmarkTools.Trial dla orchestratora.
- Standalone uruchomienie pokazuje median time, memory, alokacje (D-07).
- Phase 2 zero-alloc gwarancja widoczna empirycznie w trial.allocs.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-04-SUMMARY.md`
</output>
