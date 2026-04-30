---
phase: 04-demo-benchmarks-documentation
plan: 05
type: execute
wave: 2
depends_on:
  - 01
files_modified:
  - bench/bench_jakosc.jl
autonomous: true
requirements:
  - BENCH-03
  - BENCH-04
must_haves:
  truths:
    - "bench/bench_jakosc.jl uruchamia SA na 5 seedach × N=1000 × 50_000 krokow z T_zero=0.001"
    - "Skrypt zwraca NamedTuple z mean, std, min, max ratio"
    - "Każdy seed loguje pojedynczy ratio przez @info po polsku"
  artifacts:
    - path: "bench/bench_jakosc.jl"
      provides: "Quality benchmark SA vs NN baseline (5 seedów aggregate)"
      contains: "[42, 123, 456, 789, 2025]"
  key_links:
    - from: "bench/bench_jakosc.jl"
      to: "JuliaCity.uruchom_sa!"
      via: "SA execution per seed"
      pattern: "uruchom_sa!"
---

<objective>
Wave 2: Stworzyć quality benchmark `bench/bench_jakosc.jl` który mierzy jakość trasy SA vs NN baseline na N=1000 punktów uśrednioną po 5 seedach `[42, 123, 456, 789, 2025]` (D-08). Reprodukuje Phase 2 plan 02-14 erratum protocol (T_zero=0.001 override). Dostarcza headline number do README: „SA znajduje trasę średnio ~6% krótszą niż NN baseline (5 seedów × N=1000)".

Purpose: Niezależny od bench_energia/bench_krok pomiar — nie korzysta z BenchmarkTools (mierzy ratio, nie czas). Wymaga ~5 minut wallclock'a (5 seedów × 50_000 SA steps), więc Wave 3 orchestrator może opcjonalnie pominąć go w „fast" trybie. Headline number dla README D-15 §7.
Output: 1 nowy skrypt `bench/bench_jakosc.jl` zwracający aggregate ratio statistics.
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
@.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md
@src/algorytmy/simulowane_wyzarzanie.jl
@src/baselines.jl

<interfaces>
<!-- Phase 2 erratum lock: TEST-05 uses T_zero=0.001 override + 50_000 steps -->

From src/algorytmy/simulowane_wyzarzanie.jl:
- `SimAnnealing(stan; T_zero, alfa, cierpliwosc)::SimAnnealing` (kwargs default-aware, T_zero kwarg overrides 2σ kalibracja)
- `uruchom_sa!(stan, params, alg)::Nothing` — SA loop with patience early-stop; mutates stan.trasa, stan.energia, stan.iteracja

Fixture pattern (per seed):
```julia
punkty = generuj_punkty(N; seed=seed)
stan = StanSymulacji(punkty; rng=Xoshiro(seed))
inicjuj_nn!(stan)        # ustawia stan.energia = energia_nn
energia_nn = stan.energia  # capture PRZED SA
alg = SimAnnealing(stan; T_zero=0.001)   # erratum override (Phase 2 plan 02-14, 02-CONTEXT.md D-03)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=50_000)  # D-08 budget
uruchom_sa!(stan, params, alg)
ratio = stan.energia / energia_nn         # < 1.0 oczekiwane (SA bije NN)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Utwórz bench/bench_jakosc.jl</name>
  <read_first>
    - bench/historyczne/diagnostyka_test05.jl (linie 162-191 — pattern eksperymenty() multi-seed loop)
    - src/algorytmy/simulowane_wyzarzanie.jl (sygnatura SimAnnealing constructor + uruchom_sa!)
    - src/baselines.jl (inicjuj_nn! ustawia stan.energia)
    - .planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md (D-03 erratum — T_zero=0.001 rationale)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/bench_jakosc.jl" — exact code)
  </read_first>
  <action>
    Utworzyć plik `bench/bench_jakosc.jl` (polski, NFC, BOM-free, LF, final newline):

    ```julia
    # bench/bench_jakosc.jl
    #
    # Quality bench SA vs NN baseline (Phase 4 BENCH-03, BENCH-04).
    # 5 seedow × N=1000 punktow × 50 000 krokow SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).
    # Raportuje mean ± std, min, max dla ratio = stan.energia / energia_nn (D-08).
    # Headline dla README: „SA znajduje trase srednio ~6% krotsza niz NN baseline (5 seedow)".
    #
    # Uruchomienie standalone:
    #   julia --project=. --threads=auto bench/bench_jakosc.jl
    # Lub przez orchestrator:
    #   julia --project=. --threads=auto bench/run_all.jl
    #
    # UWAGA: ~5 min wallclock'a (5 × 50_000 SA steps). Nie uzywa BenchmarkTools — mierzy ratio,
    # nie czas. Czas SA-loop nie jest wymagany dla BENCH-03 (BENCH-02 = symuluj_krok! one-step).

    using JuliaCity
    using Random: Xoshiro
    using Statistics: mean, std

    function main()
        # D-08: 5 fixed seeds — deterministyczne, stabilne miedzy uruchomieniami
        SEEDS = [42, 123, 456, 789, 2025]
        N = 1000
        LICZBA_KROKOW = 50_000

        @info "[bench_jakosc] Start: $(length(SEEDS)) seedow × N=$N × $LICZBA_KROKOW krokow, threads=$(Threads.nthreads())"

        ratios = Float64[]

        for seed in SEEDS
            # Fixture per seed (Phase 2 fixture pattern, deterministyczny RNG)
            punkty = generuj_punkty(N; seed=seed)
            stan = StanSymulacji(punkty; rng=Xoshiro(seed))
            inicjuj_nn!(stan)
            energia_nn = stan.energia                # NN baseline = stan.energia po inicjuj_nn!

            # SA z T_zero=0.001 override (Phase 2 plan 02-14 erratum, 02-CONTEXT.md D-03)
            # Default 2σ kalibracja wyrzuca SA z basena NN-start; T_zero=0.001 utrzymuje SA blisko
            # NN-start zeby 2-opt local search mial szanse zejsc nizej.
            alg = SimAnnealing(stan; T_zero=0.001)
            stan.temperatura = alg.T_zero
            params = Parametry(liczba_krokow=LICZBA_KROKOW)

            t_start = time()
            uruchom_sa!(stan, params, alg)
            dt = time() - t_start

            ratio = stan.energia / energia_nn
            push!(ratios, ratio)

            @info "  seed=$seed: ratio=$(round(ratio; digits=4)), iter=$(stan.iteracja), czas=$(round(dt; digits=1))s"
        end

        mean_r = mean(ratios)
        std_r = std(ratios)
        min_r = minimum(ratios)
        max_r = maximum(ratios)

        @info "[bench_jakosc] GOTOWE: mean=$(round(mean_r; digits=4)) ± $(round(std_r; digits=4)), min=$(round(min_r; digits=4)), max=$(round(max_r; digits=4))"

        return (
            seeds = SEEDS,
            ratios = ratios,
            mean_ratio = mean_r,
            std_ratio = std_r,
            min_ratio = min_r,
            max_ratio = max_r,
            n = N,
            liczba_krokow = LICZBA_KROKOW,
        )
    end

    if abspath(PROGRAM_FILE) == @__FILE__
        wynik = main()
        println("="^60)
        println("[bench_jakosc] Aggregate (5 seedow × N=$(wynik.n)):")
        println("="^60)
        println("  mean ratio: $(round(wynik.mean_ratio; digits=4))")
        println("  std ratio:  $(round(wynik.std_ratio; digits=4))")
        println("  min ratio:  $(round(wynik.min_ratio; digits=4))")
        println("  max ratio:  $(round(wynik.max_ratio; digits=4))")
        println()
    end
    ```

    KRYTYCZNE:
    - `T_zero=0.001` HARDCODED w kwargach `SimAnnealing(stan; T_zero=0.001)` — Phase 2 plan 02-14 erratum LOCKED. NIE używać default 2σ kalibracji (wyrzuca SA z basena NN-start, ratio rośnie do ~0.97).
    - `SEEDS = [42, 123, 456, 789, 2025]` — exact list z D-08, NIE losowy.
    - `params = Parametry(liczba_krokow=LICZBA_KROKOW)` — patience early-stop może zakończyć wcześniej; raportujemy `stan.iteracja` jako rzeczywisty count.
    - Return type: NamedTuple z polami `seeds, ratios, mean_ratio, std_ratio, min_ratio, max_ratio, n, liczba_krokow` — pełny kontrakt dla `bench/run_all.jl` orchestrator (Wave 3).
    - `@info` po polsku (LANG-02). Bez diakrytyków (komentarze + literały bez polskich znaków, `"."` zamiast `„..."` — to format @info nie user-facing string z gwarancją typografii).
    - ASCII-only identyfikatory: `mean_r`, `std_r`, `min_r`, `max_r` — krótkie, deskryptywne.
    - Brak top-level `main()` call (orchestrator wywoła go przez include + ręczne `Main.main()`).
  </action>
  <verify>
    <automated>test -f bench/bench_jakosc.jl &amp;&amp; grep -q '\[42, 123, 456, 789, 2025\]' bench/bench_jakosc.jl &amp;&amp; grep -q 'T_zero=0.001' bench/bench_jakosc.jl &amp;&amp; grep -q 'uruchom_sa!' bench/bench_jakosc.jl &amp;&amp; grep -q 'function main()' bench/bench_jakosc.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/bench_jakosc.jl` istnieje.
    - Zawiera literalną listę 5 seedów: `[42, 123, 456, 789, 2025]` (D-08 exact).
    - Zawiera literalny string `T_zero=0.001` (Phase 2 erratum lock).
    - Zawiera literalny string `uruchom_sa!` (NIE goły `for _ in 1:N symuluj_krok!`).
    - Zawiera literalny string `inicjuj_nn!` (NN baseline init).
    - Zawiera `using Statistics: mean, std`.
    - Zawiera `LICZBA_KROKOW = 50_000` (D-08 budget).
    - Zawiera `function main()`.
    - Return value to NamedTuple z polami `mean_ratio`, `std_ratio`, `min_ratio`, `max_ratio` (grep `mean_ratio`, `std_ratio` — obie obecne).
    - Header docstring zaczyna od `# bench/bench_jakosc.jl`.
    - `@info` używany do progresu (`grep -c '@info' bench/bench_jakosc.jl` ≥ 3 — start, per-seed, final).
    - NIE zawiera top-level `main()` call (orchestrator robi include + manual call).
    - BOM-free, LF, final newline.
    - ASCII-only identyfikatory (zmienne: `ratios`, `mean_r`, `seed`, `energia_nn` — wszystkie ASCII).
  </acceptance_criteria>
  <done>bench/bench_jakosc.jl gotowy: 5 seeds × N=1000 × 50k SA steps z T_zero=0.001 lock, raportuje aggregate ratio.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 1 nowy plik Julia w bench/. Brak wejścia użytkownika, brak network, brak persistence danych. |
| compute load | ~5 min wallclock SA execution per uruchomienie; brak persistent state changes poza zwracanym NamedTuple. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-05-01 | Tampering | T_zero parameter (Phase 2 erratum lock) | mitigate | Acceptance criteria sprawdza literalnie `T_zero=0.001`. Bez tego override default 2σ kalibracja wyrzuca SA z basena NN-start i ratio rośnie do ~0.97 (regresja jakości). Phase 2 plan 02-14 SUMMARY dokumentuje rationale. |
| T-04-05-02 | Tampering | Seed list (D-08 exact) | mitigate | Acceptance criteria sprawdza literalnie `[42, 123, 456, 789, 2025]`. Zmiana seedów = zmiana headline number w README → niespójność dokumentacji. |
| T-04-05-03 | Denial of Service | Wallclock ~5 min | accept | Akceptowalne dla quality bench (BENCH-03 nie wymaga wallclock < N). Orchestrator (Wave 3) może opcjonalnie skipować bench_jakosc w „fast" trybie — ale nie w default. |

Brak ASVS L1 controls naruszonych — read-only deterministic compute.
</threat_model>

<verification>
- Standalone smoke (BLOCKER #4 zaktualizowane — bench scripts uruchamiane WYŁĄCZNIE przez orchestrator): `include` z Julia REPL z aktywnym `--project=.` (bench_jakosc.jl używa tylko `Statistics` stdlib + `JuliaCity` z `[deps]` — bez BenchmarkTools, więc resolver nie blokuje); weryfikacja: `main()` zwraca `NamedTuple` z polami `:mean_ratio, :std_ratio, :min_ratio, :max_ratio, :ratios, :seeds, :n, :liczba_krokow`.
- Kanoniczne uruchomienie produkcyjne: `bash bench/uruchom.sh` lub `pwsh bench/uruchom.ps1` (wrapper tworzony w plan 04-06 Task 0; uruchamia całe `bench/run_all.jl` które ładuje bench_jakosc w izolowanym module).
- Empiryczna weryfikacja: `mean_ratio ≈ 0.94 ± 0.01` (extrapolacja z TEST-05 lock 0.9408). Wszystkie 5 ratios < 1.0 (SA bije NN konsekwentnie).
- Oczekiwany headline po regen: „SA znajduje trasę średnio ~6% krótszą niż NN baseline" (1 - 0.94 = 0.06).
- Jeśli `std_ratio > 0.02` po pierwszym regen → README headline w plan 04-08 musi być zaktualizowany do faktycznej średniej z `bench/wyniki.md` zaokrąglonej do 1 miejsca po przecinku (per Warning #2).
</verification>

<success_criteria>
- bench_jakosc.jl reprodukowalnie mierzy 5-seed × N=1000 SA quality vs NN.
- Returns NamedTuple z mean/std/min/max ratio dla orchestratora.
- Phase 2 plan 02-14 erratum lock zachowany (T_zero=0.001).
- Headline number dla README D-15 §7 generowany przez ten skrypt.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-05-SUMMARY.md`
</output>
