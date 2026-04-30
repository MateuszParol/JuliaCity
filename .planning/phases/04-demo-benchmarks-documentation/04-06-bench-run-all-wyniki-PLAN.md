---
phase: 04-demo-benchmarks-documentation
plan: 06
type: execute
wave: 3
depends_on:
  - 01
  - 02
  - 04
  - 05
files_modified:
  - bench/run_all.jl
  - bench/wyniki.md
autonomous: false
requirements:
  - BENCH-01
  - BENCH-02
  - BENCH-03
  - BENCH-05
  - LANG-02
must_haves:
  truths:
    - "bench/run_all.jl wywoluje 3 bench scripts (energia, krok, jakosc) sekwencyjnie i zbiera wyniki"
    - "bench/wyniki.md generowany z metadanymi (Julia version, OS, CPU, threads, date) i sekcjami wynikow"
    - "Pojedyncza komenda `julia --project=. --threads=auto bench/run_all.jl` regeneruje wyniki"
    - "bench/wyniki.md zawiera markdown table z czasami, alokacjami, jakoscia trasy"
  artifacts:
    - path: "bench/run_all.jl"
      provides: "Orchestrator suite Phase 4 — single entry point"
      contains: "_zbierz_metadane"
    - path: "bench/wyniki.md"
      provides: "Generated benchmark report — Polish, markdown tabular"
      contains: "Środowisko"
  key_links:
    - from: "bench/run_all.jl"
      to: "bench/bench_energia.jl, bench/bench_krok.jl, bench/bench_jakosc.jl"
      via: "include + invokelatest(main)"
      pattern: "include\\(.*bench_"
    - from: "bench/run_all.jl"
      to: "bench/wyniki.md"
      via: "open(...write)"
      pattern: "wyniki\\.md"
---

<objective>
Wave 3: Stworzyć orchestrator `bench/run_all.jl` (D-06 LOCKED single entry point) który: (a) zbiera metadane środowiska (Julia, OS, CPU, threads, date), (b) sekwencyjnie wywołuje 3 bench scripts (Wave 2), (c) renderuje markdown report do `bench/wyniki.md` (D-07). Plus pierwsza generacja `bench/wyniki.md` poprzez wywołanie skryptu (autonomous: false — checkpoint na regen wymaga toolchainu Julia).

Purpose: BENCH-05 explicit „Wyniki benchmarków zapisywane do `bench/wyniki.md`" + ROADMAP SC #4 „Po uruchomieniu suite'u benchmarków plik bench/wyniki.md zawiera czasy, alokacje i jakość trasy w formie tabelarycznej". Headline number generowany w tym kroku trafia do README (Wave 4).
Output: Skrypt orchestrator + scommitowany pierwszy snapshot bench/wyniki.md gotowy do referencji w README.
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
@bench/bench_energia.jl
@bench/bench_krok.jl
@bench/bench_jakosc.jl
@test/runtests.jl

<interfaces>
<!-- Returns from per-bench scripts -->

bench/bench_energia.jl::main() -> BenchmarkTools.Trial
bench/bench_krok.jl::main()    -> BenchmarkTools.Trial
bench/bench_jakosc.jl::main()  -> NamedTuple{(:seeds, :ratios, :mean_ratio, :std_ratio, :min_ratio, :max_ratio, :n, :liczba_krokow), ...}

BenchmarkTools.Trial fields (via median(trial)):
- median(trial).time     (nanoseconds — Float64)
- median(trial).memory   (bytes — Int)
- median(trial).allocs   (count — Int)

System info (Julia stdlib):
- VERSION                  (e.g., "1.11.4")
- Sys.KERNEL               (e.g., :Linux, :NT, :Darwin)
- Sys.cpu_info()[1].model  (CPU brand string — może rzucić w niektórych CI)
- Threads.nthreads()       (currently active threads)
- Dates.now()              (timestamp)

Sequential include pattern (analog test/runtests.jl lines 186-198):
```julia
include("test_energia.jl")     # cwd-relative — w orchestratorze użyjemy joinpath(@__DIR__, ...)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Utwórz bench/run_all.jl orchestrator</name>
  <read_first>
    - bench/bench_energia.jl (return value: BenchmarkTools.Trial)
    - bench/bench_krok.jl (return value: BenchmarkTools.Trial)
    - bench/bench_jakosc.jl (return value: NamedTuple — exact field names: :seeds, :ratios, :mean_ratio, :std_ratio, :min_ratio, :max_ratio, :n, :liczba_krokow)
    - test/runtests.jl (linie 186-200 — sequential include pattern)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/run_all.jl" — exact code excerpt z helperami)
  </read_first>
  <action>
    Utworzyć plik `bench/run_all.jl` (polski, NFC, BOM-free, LF, final newline). Konkretne wymagania zawartości — pełna implementacja:

    Header docstring (top-of-file, 8 linii zaczynających od `#`):
    - `# bench/run_all.jl`
    - pusta linia komentarza
    - 3-4 linie kontekstu (REQ-IDs BENCH-01..05, D-06, D-07)
    - pusta linia komentarza
    - blok `# Uruchomienie:` + przykład komendy
    - linia o ~5-7 min wallclock (dominuje bench_jakosc)

    `using` block (after header, before first function):
    ```julia
    using JuliaCity
    using BenchmarkTools
    using Statistics: median
    using Dates: now
    using Printf: @sprintf
    ```

    Helpery (prefix `_`, w kolejności w pliku):

    1. `_zbierz_metadane()::String` — zwraca multi-line String z metadanymi:
       - `- Julia: $(VERSION)`
       - `- OS: $(Sys.KERNEL)`
       - `- CPU: $cpu` (z `Sys.cpu_info()[1].model` opakowanym w try/catch z fallback `"unknown"` — niektóre CI runnery rzucają)
       - `- Wątki: $(Threads.nthreads())`
       - `- Data: $(now())`
       Polskie etykiety, `Wątki` z polskimi diakrytykami (NFC).

    2. `_formatuj_trial(t::BenchmarkTools.Trial)::NamedTuple` — zwraca `(time_us=String, memory_b=String, allocs=String)`:
       - `med = median(t)`
       - `time_us = @sprintf("%.3f", med.time / 1000.0)` — nanoseconds → microseconds, 3 cyfry po przecinku per Claude's Discretion w 04-CONTEXT.md
       - `memory_b = string(med.memory)`
       - `allocs = string(med.allocs)`

    3. `_renderuj_microbench_tabele(wyniki::Dict{String, BenchmarkTools.Trial})::String` — buduje markdown table:
       - Nagłówek: `## Microbenchmarki` (polski h2)
       - 1 zdanie opisu po polsku (wymienia BenchmarkTools, evals=1, $ interpolacja)
       - Markdown table z 4 kolumnami: `Funkcja | Median time (μs) | Memory (B) | Alokacje`
       - Stable order: `for nazwa in sort(collect(keys(wyniki)))`
       - Każdy wiersz: `| \`$nazwa\` | $(f.time_us) | $(f.memory_b) | $(f.allocs) |`

    4. `_renderuj_jakosc_sekcje(j::NamedTuple)::String` — buduje sekcję jakości:
       - Nagłówek: `## Jakość trasy (bench_jakosc)`
       - 1 zdanie kontekstu: `Aggregate po $(length(j.seeds)) seedach × N=$(j.n) × $(j.liczba_krokow) kroków SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).`
       - Headline (bold): `**Headline:** SA znajduje trasę średnio $(round((1 - j.mean_ratio) * 100; digits=1))% krótszą niż NN baseline.`
       - Markdown table z 2 kolumnami (Statystyka | Wartość): mean, std, min, max — wszystkie format `@sprintf("%.4f", ...)` per Claude's Discretion.
       - Lista per-seed: `for (s, r) in zip(j.seeds, j.ratios) ... println("- seed=$s: $(@sprintf("%.4f", r))") end`

    Główna funkcja `main()`:
    1. Banner `="^72` + `[run_all] Suite benchmarkow JuliaCity (Phase 4 BENCH-01..05)` + `="^72`
    2. `microbench = Dict{String, BenchmarkTools.Trial}()`
    3. Krok 1/3: `@info "[run_all] (1/3) bench_energia.jl ..."` + `include(joinpath(@__DIR__, "bench_energia.jl"))` + `microbench["oblicz_energie (3-arg, N=1000)"] = Base.invokelatest(main)`
    4. Krok 2/3: analogicznie z `bench_krok.jl` i kluczem `"symuluj_krok! (SA-2-opt, N=1000)"`
    5. Krok 3/3: `@info "[run_all] (3/3) bench_jakosc.jl (~5 min) ..."` + `include(joinpath(@__DIR__, "bench_jakosc.jl"))` + `jakosc = Base.invokelatest(main)`
    6. Render: wywołać 3 helpery, zbudować markdown
    7. Open + write do `joinpath(@__DIR__, "wyniki.md")`:
       - `# Wyniki benchmarków JuliaCity` (h1)
       - 1 zdanie: `Wygenerowane przez \`bench/run_all.jl\` (D-06). Reprodukuj komendą:`
       - Bash code block z komendą `julia --project=. --threads=auto bench/run_all.jl`
       - `## Środowisko` + metadane
       - tabela_micro (zawiera już `## Microbenchmarki`)
       - sekcja_jakosc (zawiera już `## Jakość trasy`)
    8. `@info "[run_all] GOTOWE — wyniki zapisane do bench/wyniki.md"`
    9. Banner zamknięcia + `return nothing`

    Top-level call: `main()` na końcu pliku (single line — orchestrator JEST entry point, nie tylko library).

    KRYTYCZNE — world age problem:
    - `Base.invokelatest(main)` — KONIECZNE po każdym `include`, bo `include` definiuje `main()` w runtime, a wywołanie z wewnątrz funkcji `main` orchestratora wymaga `invokelatest` (Julia world age semantics). Bez tego dostaniemy `MethodError` z signature mismatch.
    - Każdy `include` nadpisuje `main` w Main scope — celowy idiom (per-bench scripts mają identyczną nazwę funkcji `main`). `invokelatest(main)` natychmiast po `include` łapie świeżą definicję.

    KRYTYCZNE — ścieżki:
    - `joinpath(@__DIR__, "bench_energia.jl")` zamiast względnej `"bench_energia.jl"` — działa niezależnie od cwd.
    - `joinpath(@__DIR__, "wyniki.md")` analogicznie dla output.

    KRYTYCZNE — encoding:
    - Polskie diakrytyki (Wątki, Środowisko, Jakość, krótszą) NFC composed.
    - BOM-free, LF, final newline.
    - ASCII identyfikatory: `microbench`, `jakosc`, `tabela_micro`, `sekcja_jakosc`, `metadane`, `sciezka` — bez polskich diakrytyków.

    Komentarze polskie nad każdym blokiem logicznym (helpery, main steps), zgodnie z LANG-01.
  </action>
  <verify>
    <automated>test -f bench/run_all.jl &amp;&amp; grep -q '_zbierz_metadane' bench/run_all.jl &amp;&amp; grep -q '_renderuj_microbench_tabele' bench/run_all.jl &amp;&amp; grep -q '_renderuj_jakosc_sekcje' bench/run_all.jl &amp;&amp; grep -q 'invokelatest' bench/run_all.jl &amp;&amp; grep -qE 'wyniki\.md' bench/run_all.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/run_all.jl` istnieje.
    - Zawiera 4 helpery: `_zbierz_metadane`, `_formatuj_trial`, `_renderuj_microbench_tabele`, `_renderuj_jakosc_sekcje` — wszystkie prefixed `_` (Phase 3 D-09).
    - Zawiera literalny string `Base.invokelatest(main)` (KONIECZNE — world age fix).
    - Zawiera 3 wywołania `include(joinpath(@__DIR__,` — po jednym dla każdego bench script.
    - Zawiera `using BenchmarkTools`, `using Statistics: median`, `using Dates: now`, `using Printf: @sprintf`.
    - Zawiera `Sys.cpu_info()[1].model` w bloku `try ... catch` z fallback (sprawdź obecność słów `try` i `catch` w okolicy `cpu_info`).
    - Zawiera literalny string `T_zero=0.001` (referencja do Phase 2 erratum lock w opisie tabeli jakości).
    - Zawiera `(1 - j.mean_ratio) * 100` (headline computation z aggregate).
    - Zawiera literalny string `## Środowisko` (polski h2 z diakrytykiem).
    - Zawiera literalny string `Wątki` (polski etykieta z diakrytykiem).
    - Zawiera literalny string `## Jakość trasy` (polski h2).
    - Zawiera dokładnie 1 top-level `main()` call: `grep -cE '^main\(\)$' bench/run_all.jl` zwraca `1`.
    - Plik kończy się znakiem LF (`tail -c1 | xxd` zawiera `0a`).
    - BOM-free: `head -c3 bench/run_all.jl | xxd` NIE zawiera `efbbbf`.
    - ASCII-only identyfikatory zmiennych (sprawdź że nie ma `microbęnch` z diakrytykiem).
  </acceptance_criteria>
  <done>bench/run_all.jl gotowy: 4 helpery prefixed `_`, 3 sequential includes z invokelatest, zapis markdown do bench/wyniki.md.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 2: Pierwsza regeneracja bench/wyniki.md (wymaga toolchainu Julia)</name>
  <read_first>
    - bench/run_all.jl (właśnie utworzony)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-06 — single entry point)
  </read_first>
  <what-built>
    Wave 1-2 dostarczyły wszystkie 4 bench scripts (`bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl`, `run_all.jl`) i Project.toml ma BenchmarkTools w `[targets].test`. Wszystko jest deklaratywnie gotowe.

    Brakujący artefakt to `bench/wyniki.md` — plik który MUSI istnieć w repo (BENCH-05) i być commitowany przed Wave 4 (README odwołuje się do niego linkiem `[bench/wyniki.md`]). Pierwsza generacja wymaga uruchomienia `bench/run_all.jl` lokalnie przez developera (~5-7 min wallclock dominowanego przez bench_jakosc).
  </what-built>
  <how-to-verify>
    Wykonać następujące kroki RĘCZNIE w terminalu (na lokalnej maszynie z Julia 1.10+ w PATH):

    1. **Aktywować test environment** (BenchmarkTools dostępny tylko w `[targets].test`):
       ```bash
       julia --project=. -e 'using Pkg; Pkg.test(coverage=false)'
       ```
       LUB (rekomendowane — bezpośrednie uruchomienie z aktywowanym test env):
       ```bash
       julia --project=. --threads=auto -e 'using Pkg; Pkg.activate(joinpath(homedir(), ".julia", "environments", "v$(VERSION.major).$(VERSION.minor)")); Pkg.activate("."); include("bench/run_all.jl")'
       ```
       LUB (najprostsza opcja — Julia automatycznie znajdzie BenchmarkTools jeśli jest w `[deps]` lub aktywujemy `--project=test`):
       ```bash
       cd C:/Users/mparol/Desktop/Dokumenty/Projekty/JuliaCity
       julia --project=. --threads=auto bench/run_all.jl
       ```

       UWAGA: jeśli `using BenchmarkTools` w bench scripts rzuci `ArgumentError: Package BenchmarkTools not found`, oznacza że BenchmarkTools nie jest w aktywnym env. Workaround: tymczasowo dodać `BenchmarkTools` do `[deps]` w Project.toml (NIE commitować tego), uruchomić, przywrócić. Lub utworzyć `bench/Project.toml` z BenchmarkTools w deps (D-10 reject — over-engineering — ale to backup gdyby `[targets].test` nie zadziałało).

    2. **Czas wykonania:** ~5-7 minut. Postęp widoczny przez `@info` z każdego skryptu (3 etapy: bench_energia, bench_krok, bench_jakosc).

    3. **Po zakończeniu:** sprawdzić że `bench/wyniki.md` istnieje i zawiera:
       - Nagłówek `# Wyniki benchmarków JuliaCity`
       - Sekcja `## Środowisko` z konkretną wersją Julii, OS, CPU, threads, datą
       - Sekcja `## Microbenchmarki` z tabelą 2-rzędową (oblicz_energie + symuluj_krok!)
       - Sekcja `## Jakość trasy (bench_jakosc)` z headline'em i tabelą statystyk
       - Headline w okolicy `~6%` (per D-08 ekstrapolacja z TEST-05)

    4. **Commit:** `bench/wyniki.md` MUSI być scommitowany (D-06 + PROJECT D-25 — to aplikacja, nie biblioteka; deterministyczne wyniki commitowane).

    5. **Empiryczna weryfikacja headline'u:**
       - mean ratio z bench_jakosc powinien być w okolicy 0.93-0.95 (zgodnie z TEST-05 lock 0.9408 i D-08 ekstrapolacją).
       - Jeśli mean > 0.97 lub mean < 0.85 → REGRESJA. Sprawdzić czy `T_zero=0.001` faktycznie został zastosowany i czy `uruchom_sa!` użyło patience early-stop poprawnie.
  </how-to-verify>
  <resume-signal>
    Po wykonaniu kroków 1-5: napisać `approved: bench/wyniki.md scommitowany, mean_ratio=$WARTOŚĆ` lub opisać blokery.

    Jeśli napotykasz problemy z BenchmarkTools resolverem — opisz dokładny błąd, plan przewiduje rollback / `bench/Project.toml` jako fallback.
  </resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 1 nowy plik Julia + generuje 1 nowy plik markdown (oba w bench/). Brak wejścia użytkownika, brak network. |
| sequential include | Orchestrator `include`-uje 3 skrypty Julia. Wszystkie 3 są wewnętrzne (Wave 1-2 utworzone w tym samym repo) i deklaratywnie nie modyfikują globalnego stanu poza definicją `main()`. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-06-01 | Tampering | Sequential include zamiast subprocess | accept | Wszystkie 3 bench scripts są w-repo (audited Wave 2), nie modyfikują globalnego stanu poza `main()`. Subprocess izolacja byłaby over-engineering dla 3 trusted scripts. |
| T-04-06-02 | Information Disclosure | Sysinfo (CPU model, OS, Julia version) w bench/wyniki.md | accept | Public info, commitowane przez D-07 explicit. ASVS L1 nie wymaga redakcji. |
| T-04-06-03 | Denial of Service | World age problem bez `invokelatest` | mitigate | Acceptance criteria sprawdza literalnie `Base.invokelatest(main)` — bez tego MethodError. |
| T-04-06-04 | Denial of Service | bench_jakosc ~5 min wallclock | accept | Akceptowalne dla offline regeneracji (D-06 single entry point + manual commit). |

Brak ASVS L1 controls naruszonych — read-only deterministic compute + filesystem write w repo subdir.
</threat_model>

<verification>
- `bench/run_all.jl` istnieje, ma 4 helpery prefixed `_`, top-level `main()` call.
- `bench/wyniki.md` istnieje po Task 2 z 3 sekcjami (Środowisko + Microbenchmarki + Jakość trasy).
- Komenda `julia --project=. --threads=auto bench/run_all.jl` zwraca exit 0 i regeneruje plik.
- Headline w `bench/wyniki.md` zawiera procent w okolicy 5-7% (per D-08 ekstrapolacja z 0.9408).
</verification>

<success_criteria>
- D-06 LOCKED: pojedyncza komenda `julia --project=. --threads=auto bench/run_all.jl` regeneruje `bench/wyniki.md`.
- D-07 LOCKED: metadane (Julia, OS, CPU, threads, date) + median time + memory + alokacje per microbench + mean±std/min/max ratio dla jakości.
- BENCH-05 spełnione: wyniki w formie tabelarycznej, plik commitowany.
- Headline number wygenerowany do referencji w README D-15 §7.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-06-SUMMARY.md`
</output>
