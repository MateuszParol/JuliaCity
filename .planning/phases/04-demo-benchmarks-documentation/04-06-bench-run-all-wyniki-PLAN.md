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
  - bench/uruchom.sh
  - bench/uruchom.ps1
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
    - "bench/run_all.jl ładuje 3 bench scripts w izolowanych modułach (Module(:_BenchSandbox)) — uniknięcie kolizji Main.main (BLOCKER #3)"
    - "bench/uruchom.sh + bench/uruchom.ps1 dostarczają canonical runtime path z BenchmarkTools resolverem (BLOCKER #4)"
    - "bench/wyniki.md generowany z metadanymi (Julia, OS, CPU, threads, date) i 3 sekcjami wyników"
    - "Microbench rows w bench/wyniki.md sortowane alfabetycznie (Warning #3)"
    - "Pojedyncza komenda `bash bench/uruchom.sh` (lub pwsh equivalent) regeneruje wyniki"
  artifacts:
    - path: "bench/run_all.jl"
      provides: "Orchestrator suite Phase 4 — single entry point z module-isolated includes"
      contains: "_uruchom_bench"
    - path: "bench/uruchom.sh"
      provides: "POSIX wrapper z auto-detect BenchmarkTools resolverem (BLOCKER #4)"
      contains: "Pkg.activate(temp=true)"
    - path: "bench/uruchom.ps1"
      provides: "PowerShell wrapper (Windows-friendly equivalent of uruchom.sh)"
      contains: "Pkg.activate(temp=true)"
    - path: "bench/wyniki.md"
      provides: "Generated benchmark report — Polish, markdown tabular"
      contains: "Środowisko"
  key_links:
    - from: "bench/run_all.jl"
      to: "bench/bench_energia.jl, bench/bench_krok.jl, bench/bench_jakosc.jl"
      via: "Module(:_BenchSandbox) + Base.include + invokelatest"
      pattern: "Base\\.include\\(m,"
    - from: "bench/uruchom.sh"
      to: "bench/run_all.jl"
      via: "throwaway env + Pkg.develop + include"
      pattern: "include\\(.bench/run_all\\.jl.\\)"
    - from: "bench/run_all.jl"
      to: "bench/wyniki.md"
      via: "open(...write)"
      pattern: "wyniki\\.md"
---

<objective>
Wave 3: (a) utworzyć wrappery `bench/uruchom.sh` + `bench/uruchom.ps1` które dostarczają jedyną wspieraną drogę uruchomienia z dostępnym BenchmarkTools (checker iteracja 1 BLOCKER #4); (b) stworzyć orchestrator `bench/run_all.jl` (D-06 LOCKED single entry point) ładujący 3 bench scripts w IZOLOWANYCH MODUŁACH (`Module(:_BenchSandbox)` per BLOCKER #3 — uniknięcie kolizji `Main.main`); (c) regenerować `bench/wyniki.md` (BENCH-05 + ROADMAP SC #4).

Purpose: BLOCKER #3 fix — sekwencyjny `include(bench_*.jl)` w Main scope nadpisuje `Main.main` w środku wykonania orchestratora; rozwiązanie: każdy bench skrypt ładowany do `Module(:_BenchSandbox)` przez `Base.include(m, sciezka)`, wywołanie przez `Base.invokelatest(m.main)`. BLOCKER #4 fix — `--project=.` resolver NIE widzi pakietów z `[targets].test` przy plain script execution; wrapper aktywuje throwaway env z `Pkg.activate(temp=true) + Pkg.develop(path=".") + Pkg.add("BenchmarkTools")` i delegate'uje do `include("bench/run_all.jl")`. D-10 (no `bench/Project.toml`) honored — temp-env jest in-runtime, brak commit'owanego env.
Output: 1 orchestrator + 2 wrappery + scommitowany pierwszy snapshot bench/wyniki.md.
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
<!-- Returns from per-bench scripts (loaded in isolated modules) -->

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

Module isolation pattern (BLOCKER #3 fix):
```julia
function _uruchom_bench(sciezka::String)
    # Isolacja: kazdy bench skrypt ladowany w osobnym anonimowym module,
    # by `function main()` z bench_*.jl nie nadpisal Main.main orchestratora.
    m = Module(:_BenchSandbox)
    Base.include(m, sciezka)
    return Base.invokelatest(m.main)
end
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 0: Utwórz bench/uruchom.sh + bench/uruchom.ps1 wrappery (BLOCKER #4 fix)</name>
  <read_first>
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-10 — no `bench/Project.toml`; D-06 — single entry point)
    - Project.toml (potwierdzić że BenchmarkTools jest w `[extras]` i `[compat]`, NIE w `[deps]` — wymaga temp-env)
  </read_first>
  <action>
    Utworzyć DWA wrappery dla canonical runtime path. Wrappery muszą działać niezależnie od cwd; `dirname` script + `cd` do repo root przed Julia call.

    **bench/uruchom.sh** (POSIX, LF endings, executable):

    ```bash
    #!/usr/bin/env bash
    # bench/uruchom.sh
    #
    # Canonical wrapper dla bench/run_all.jl (Phase 4 D-06 + checker iteracja 1 BLOCKER #4).
    # Aktywuje throwaway environment z BenchmarkTools — workaround dla limitu Pkg.jl gdzie
    # `--project=.` nie widzi pakietow z `[targets].test` przy plain script execution.
    # D-10 (no bench/Project.toml) honored — temp-env zyje wylacznie w runtime.

    set -euo pipefail

    # Cwd niezalezny od miejsca wywolania — script zawsze cd'i do repo root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "${REPO_ROOT}"

    # Auto-detect: jesli BenchmarkTools resolvable z `--project=.`, uzywamy direct path.
    # Inaczej fallback do temp-env recipe.
    if julia --project=. -e 'using BenchmarkTools' >/dev/null 2>&1; then
        echo "[uruchom.sh] BenchmarkTools resolvable via --project=. — direct invocation"
        exec julia --project=. --threads=auto bench/run_all.jl
    else
        echo "[uruchom.sh] BenchmarkTools nie resolvable via --project=. — fallback do throwaway env"
        exec julia --threads=auto --project=. -e '
            import Pkg
            Pkg.activate(temp=true)
            Pkg.develop(path=".")
            Pkg.add("BenchmarkTools")
            include("bench/run_all.jl")
        '
    fi
    ```

    **bench/uruchom.ps1** (PowerShell, LF endings — Windows + cross-platform PowerShell Core):

    ```powershell
    # bench/uruchom.ps1
    #
    # Canonical wrapper dla bench/run_all.jl (Phase 4 D-06 + checker BLOCKER #4).
    # Aktywuje throwaway environment z BenchmarkTools — workaround dla limitu Pkg.jl.
    # D-10 (no bench/Project.toml) honored — temp-env zyje wylacznie w runtime.

    $ErrorActionPreference = 'Stop'

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')
    Set-Location $RepoRoot

    # Auto-detect: jesli BenchmarkTools resolvable z --project=., uzywamy direct path.
    & julia --project=. -e 'using BenchmarkTools' 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[uruchom.ps1] BenchmarkTools resolvable via --project=. — direct invocation"
        & julia --project=. --threads=auto bench/run_all.jl
    } else {
        Write-Host "[uruchom.ps1] BenchmarkTools nie resolvable via --project=. — fallback do throwaway env"
        & julia --threads=auto --project=. -e @'
import Pkg
Pkg.activate(temp=true)
Pkg.develop(path=".")
Pkg.add("BenchmarkTools")
include("bench/run_all.jl")
'@
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    ```

    Po utworzeniu uruchom (best-effort): `chmod +x bench/uruchom.sh` (ignorowane na Windows; OK).

    KRYTYCZNE — D-10 honored:
    - `Pkg.activate(temp=true)` — throwaway env (NIE commitowany).
    - `Pkg.develop(path=".")` — JuliaCity dostępny przez local develop, NIE przez registry.
    - `Pkg.add("BenchmarkTools")` — dodaje BenchmarkTools tylko do throwaway env.
    - Po zakończeniu skryptu temp-env znika (Julia GC). Brak persistent `bench/Project.toml`.

    KRYTYCZNE — encoding:
    - Polskie diakrytyki w komentarzach OK (UTF-8); LF line endings na obu plikach.
    - Identyfikatory ASCII (`SCRIPT_DIR`, `REPO_ROOT`, `ScriptDir`, `RepoRoot`).
  </action>
  <verify>
    <automated>test -f bench/uruchom.sh &amp;&amp; test -f bench/uruchom.ps1 &amp;&amp; grep -q 'Pkg.activate(temp=true)' bench/uruchom.sh &amp;&amp; grep -q 'Pkg.develop(path=".")' bench/uruchom.sh &amp;&amp; grep -q 'Pkg.add("BenchmarkTools")' bench/uruchom.sh &amp;&amp; grep -q 'include("bench/run_all.jl")' bench/uruchom.sh &amp;&amp; grep -q 'Pkg.activate(temp=true)' bench/uruchom.ps1</automated>
  </verify>
  <acceptance_criteria>
    - `bench/uruchom.sh` istnieje, zawiera shebang `#!/usr/bin/env bash`.
    - `bench/uruchom.sh` zawiera `set -euo pipefail`.
    - `bench/uruchom.sh` zawiera auto-detect: `julia --project=. -e 'using BenchmarkTools'` w `if` bloku, direct invocation w gałęzi true.
    - `bench/uruchom.sh` w fallback gałęzi zawiera: `Pkg.activate(temp=true)`, `Pkg.develop(path=".")`, `Pkg.add("BenchmarkTools")`, `include("bench/run_all.jl")`.
    - `bench/uruchom.ps1` istnieje, zawiera `$ErrorActionPreference = 'Stop'`.
    - `bench/uruchom.ps1` zawiera analogiczny auto-detect + fallback z `Pkg.activate(temp=true)`, `Pkg.develop(path=".")`, `Pkg.add("BenchmarkTools")`, `include("bench/run_all.jl")`.
    - Oba pliki używają względnej ścieżki `bench/run_all.jl` (cd do repo root przed wywołaniem).
    - LF line endings na obu plikach (`file bench/uruchom.sh` raportuje "ASCII text" lub "UTF-8 Unicode text", nie CRLF).
    - `bench/uruchom.sh` ma flagę executable (best-effort): `test -x bench/uruchom.sh` exit 0 (na Linux/macOS).
  </acceptance_criteria>
  <done>bench/uruchom.{sh,ps1} gotowe: auto-detect + temp-env fallback z Pkg.activate(temp=true) + Pkg.develop + Pkg.add + include, D-10 honored.</done>
</task>

<task type="auto">
  <name>Task 1: Utwórz bench/run_all.jl orchestrator z module-isolated includes (BLOCKER #3 fix)</name>
  <read_first>
    - bench/bench_energia.jl (return value: BenchmarkTools.Trial)
    - bench/bench_krok.jl (return value: BenchmarkTools.Trial)
    - bench/bench_jakosc.jl (return value: NamedTuple — exact field names: :seeds, :ratios, :mean_ratio, :std_ratio, :min_ratio, :max_ratio, :n, :liczba_krokow)
    - test/runtests.jl (linie 186-200 — sequential include pattern dla referencji)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "bench/run_all.jl" — exact code excerpt z helperami)
  </read_first>
  <action>
    Utworzyć plik `bench/run_all.jl` (polski, NFC, BOM-free, LF, final newline). Konkretne wymagania:

    Header docstring (top-of-file, 9 linii zaczynających od `#`):
    - `# bench/run_all.jl`
    - pusta linia komentarza
    - 3-4 linie kontekstu (REQ-IDs BENCH-01..05, D-06, D-07; checker BLOCKER #3 fix module isolation)
    - pusta linia komentarza
    - blok `# Uruchomienie:` z `bash bench/uruchom.sh` lub `pwsh bench/uruchom.ps1` (NIE direct julia command — to BLOCKER #4 fix)
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

    1. `_uruchom_bench(sciezka::String)::Any` — BLOCKER #3 fix, module isolation:
       ```julia
       function _uruchom_bench(sciezka::String)
           # Isolacja: kazdy bench skrypt ladowany w osobnym anonimowym module,
           # by `function main()` z bench_*.jl nie nadpisal Main.main orchestratora.
           # Bez tego: top-level `main()` wywolanie na koncu run_all.jl wywolaloby
           # ostatnio-zaladowany bench main, NIE orchestratora.
           m = Module(:_BenchSandbox)
           Base.include(m, sciezka)
           return Base.invokelatest(m.main)
       end
       ```

    2. `_zbierz_metadane()::String` — zwraca multi-line String z metadanymi:
       - `- Julia: $(VERSION)`
       - `- OS: $(Sys.KERNEL)`
       - `- CPU: $cpu` (z `Sys.cpu_info()[1].model` opakowanym w try/catch z fallback `"unknown"`)
       - `- Wątki: $(Threads.nthreads())`
       - `- Data: $(now())`
       Polskie etykiety, `Wątki` z polskimi diakrytykami (NFC).

    3. `_formatuj_trial(t::BenchmarkTools.Trial)::NamedTuple` — `(time_us=String, memory_b=String, allocs=String)`:
       - `med = median(t)`
       - `time_us = @sprintf("%.3f", med.time / 1000.0)` — nanoseconds → microseconds, 3 cyfry po przecinku
       - `memory_b = string(med.memory)`
       - `allocs = string(med.allocs)`

    4. `_renderuj_microbench_tabele(wyniki::Dict{String, BenchmarkTools.Trial})::String` — markdown table:
       - Nagłówek: `## Microbenchmarki` (polski h2)
       - 1 zdanie opisu po polsku (BenchmarkTools, evals=1, fresh-per-sample setup)
       - Markdown table 4-kolumnowy: `Funkcja | Median time (μs) | Memory (B) | Alokacje`
       - **STABLE ALPHABETICAL ORDER** (Warning #3 fix): `for nazwa in sort(collect(keys(wyniki)))` — gwarantuje że `oblicz_energie` < `symuluj_krok!` w wyjściu.
       - Każdy wiersz: `| \`$nazwa\` | $(f.time_us) | $(f.memory_b) | $(f.allocs) |`

    5. `_renderuj_jakosc_sekcje(j::NamedTuple)::String` — sekcja jakości:
       - Nagłówek: `## Jakość trasy (bench_jakosc)`
       - 1 zdanie kontekstu: `Aggregate po $(length(j.seeds)) seedach × N=$(j.n) × $(j.liczba_krokow) kroków SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).`
       - Headline (bold): `**Headline:** SA znajduje trasę średnio $(round((1 - j.mean_ratio) * 100; digits=1))% krótszą niż NN baseline.`
       - Markdown table 2-kolumnowy (Statystyka | Wartość): mean, std, min, max — wszystkie format `@sprintf("%.4f", ...)`.
       - Lista per-seed: `for (s, r) in zip(j.seeds, j.ratios) ... println("- seed=$s: $(@sprintf("%.4f", r))") end`

    Główna funkcja `main()`:
    1. Banner `="^72` + `[run_all] Suite benchmarkow JuliaCity (Phase 4 BENCH-01..05)` + `="^72`
    2. `microbench = Dict{String, BenchmarkTools.Trial}()`
    3. Krok 1/3: `@info "[run_all] (1/3) bench_energia.jl ..."` + `microbench["oblicz_energie (3-arg, N=1000)"] = _uruchom_bench(joinpath(@__DIR__, "bench_energia.jl"))`
    4. Krok 2/3: analogicznie z `bench_krok.jl` i kluczem `"symuluj_krok! (SA-2-opt, N=1000)"`
    5. Krok 3/3: `@info "[run_all] (3/3) bench_jakosc.jl (~5 min) ..."` + `jakosc = _uruchom_bench(joinpath(@__DIR__, "bench_jakosc.jl"))`
    6. Render: wywołać 3 helpery (`_zbierz_metadane`, `_renderuj_microbench_tabele`, `_renderuj_jakosc_sekcje`), zbudować markdown.
    7. Open + write do `joinpath(@__DIR__, "wyniki.md")`:
       - `# Wyniki benchmarków JuliaCity` (h1)
       - 1 zdanie: `Wygenerowane przez \`bench/run_all.jl\` (D-06). Reprodukuj komendą:`
       - Bash code block z komendą `bash bench/uruchom.sh` LUB `pwsh bench/uruchom.ps1` (BLOCKER #4 fix — wrappers są canonical command).
       - `## Środowisko` + metadane
       - tabela_micro (zawiera już `## Microbenchmarki`)
       - sekcja_jakosc (zawiera już `## Jakość trasy`)
    8. `@info "[run_all] GOTOWE — wyniki zapisane do bench/wyniki.md"`
    9. Banner zamknięcia + `return nothing`

    Top-level call: `main()` na końcu pliku (single line — orchestrator JEST entry point).

    KRYTYCZNE — module isolation (BLOCKER #3 fix):
    - `_uruchom_bench(sciezka)` używa `m = Module(:_BenchSandbox)` + `Base.include(m, sciezka)` + `Base.invokelatest(m.main)`. KAŻDE wywołanie tworzy NOWY moduł — `Main.main` (orchestrator) nigdy nie jest nadpisywany.
    - W `Base.include(m, sciezka)`: `m` to anonimowy moduł w Main scope, `sciezka` to absolute path; bench script działa wewnątrz `m`, jego `using JuliaCity` etc. działa normalnie (Module dziedziczy widoczność top-level packages).
    - `Base.invokelatest(m.main)` — KONIECZNE; `Base.include` definiuje `m.main` w runtime, a wywołanie z `main()` orchestratora wymaga `invokelatest` (Julia world age semantics).

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
    <automated>test -f bench/run_all.jl &amp;&amp; grep -q '_uruchom_bench' bench/run_all.jl &amp;&amp; grep -q 'Module(' bench/run_all.jl &amp;&amp; grep -q 'Base.include(m,' bench/run_all.jl &amp;&amp; grep -q 'Base.invokelatest(m.main)' bench/run_all.jl &amp;&amp; grep -q '_zbierz_metadane' bench/run_all.jl &amp;&amp; grep -q '_renderuj_microbench_tabele' bench/run_all.jl &amp;&amp; grep -q '_renderuj_jakosc_sekcje' bench/run_all.jl &amp;&amp; grep -q 'sort(collect(keys' bench/run_all.jl &amp;&amp; grep -qE 'wyniki\.md' bench/run_all.jl</automated>
  </verify>
  <acceptance_criteria>
    - `bench/run_all.jl` istnieje.
    - Zawiera 5 helperów: `_uruchom_bench`, `_zbierz_metadane`, `_formatuj_trial`, `_renderuj_microbench_tabele`, `_renderuj_jakosc_sekcje` — wszystkie prefixed `_` (Phase 3 D-09).
    - **BLOCKER #3 fix obecny** (3 sygnatury w jednym helperze):
      - `Module(` w `bench/run_all.jl` (anonimowy moduł)
      - `Base.include(m,` (load do modułu)
      - `Base.invokelatest(m.main)` (world age fix)
    - Zawiera 3 wywołania `_uruchom_bench(joinpath(@__DIR__,` — po jednym dla każdego bench script.
    - **NIE zawiera bezpośrednich `include(joinpath(@__DIR__, "bench_*.jl"))` w main** — wszystkie includes idą przez `_uruchom_bench` (grep `-cE 'include\(joinpath.*bench_'` w main scope zwraca 0; pozostałe `joinpath` tylko w `_uruchom_bench` argument lub `wyniki.md` write).
    - Zawiera `using BenchmarkTools`, `using Statistics: median`, `using Dates: now`, `using Printf: @sprintf`.
    - Zawiera `Sys.cpu_info()[1].model` w bloku `try ... catch` z fallback (sprawdź obecność słów `try` i `catch` w okolicy `cpu_info`).
    - Zawiera literalny string `T_zero=0.001` (referencja do Phase 2 erratum lock w opisie tabeli jakości).
    - Zawiera `(1 - j.mean_ratio) * 100` (headline computation z aggregate).
    - Zawiera literalny string `## Środowisko` (polski h2 z diakrytykiem).
    - Zawiera literalny string `Wątki` (polski etykieta z diakrytykiem).
    - Zawiera literalny string `## Jakość trasy` (polski h2).
    - **WARNING #3 fix obecny:** zawiera `sort(collect(keys` w `_renderuj_microbench_tabele` (alfabetyczny order — `oblicz_energie` < `symuluj_krok!` gwarantowane).
    - Zawiera `bash bench/uruchom.sh` LUB `pwsh bench/uruchom.ps1` w komendzie reprodukcji w `wyniki.md` write (NIE `julia --project=. bench/run_all.jl` — BLOCKER #4 fix).
    - Zawiera dokładnie 1 top-level `main()` call: `grep -cE '^main\(\)$' bench/run_all.jl` zwraca `1`.
    - Plik kończy się znakiem LF.
    - BOM-free.
    - ASCII-only identyfikatory zmiennych.
  </acceptance_criteria>
  <done>bench/run_all.jl gotowy: 5 helperów prefixed `_`, 3 module-isolated calls przez `_uruchom_bench`, alfabetyczny order microbench, wrapper-based reprodukcja w wyniki.md.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 2: Pierwsza regeneracja bench/wyniki.md przez wrapper</name>
  <read_first>
    - bench/run_all.jl (właśnie utworzony)
    - bench/uruchom.sh / bench/uruchom.ps1 (właśnie utworzone)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-06 — single entry point)
  </read_first>
  <what-built>
    Wave 1-2 dostarczyły wszystkie 4 bench scripts (`bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl`, plus orchestrator `run_all.jl`) i 2 wrappery (`uruchom.sh`, `uruchom.ps1`). Project.toml ma BenchmarkTools w `[targets].test`. Wszystko gotowe deklaratywnie.

    Brakujący artefakt to `bench/wyniki.md` — plik który MUSI istnieć w repo (BENCH-05) i być commitowany przed Wave 4 (README odwołuje się do niego linkiem). Pierwsza generacja wymaga uruchomienia wrappera lokalnie przez developera (~5-7 min wallclock dominowanego przez bench_jakosc).
  </what-built>
  <how-to-verify>
    Wykonać RĘCZNIE w terminalu na lokalnej maszynie z Julia 1.10+ w PATH:

    1. **Uruchomić wrapper** (POSIX bash lub PowerShell):
       ```bash
       cd C:/Users/mparol/Desktop/Dokumenty/Projekty/JuliaCity
       bash bench/uruchom.sh
       ```
       LUB (Windows-native):
       ```powershell
       pwsh bench/uruchom.ps1
       ```

       Wrapper wykona auto-detect:
       - Jeśli `julia --project=. -e 'using BenchmarkTools'` exit 0 → direct invocation `julia --project=. --threads=auto bench/run_all.jl`.
       - Inaczej (typowy przypadek dla `[targets].test` lokalizacji BenchmarkTools) → throwaway env recipe (`Pkg.activate(temp=true) + Pkg.develop(path=".") + Pkg.add("BenchmarkTools") + include("bench/run_all.jl")`).

       D-10 honored: throwaway env zyje wyłącznie w runtime, brak commitowanego `bench/Project.toml`.

    2. **Czas wykonania:** ~5-10 minut (z setup-overhead dla bench_krok i bench_jakosc dominującym). Postęp widoczny przez `@info` z każdego skryptu (3 etapy).

    3. **Po zakończeniu:** sprawdzić że `bench/wyniki.md` istnieje i zawiera:
       - Nagłówek `# Wyniki benchmarków JuliaCity`
       - Komenda reprodukcji: `bash bench/uruchom.sh` lub `pwsh bench/uruchom.ps1` (NIE direct julia — BLOCKER #4)
       - Sekcja `## Środowisko` z konkretną wersją Julii, OS, CPU, threads, datą
       - Sekcja `## Microbenchmarki` z tabelą 2-rzędową w **alfabetycznej kolejności**: `oblicz_energie` PRZED `symuluj_krok!` (Warning #3)
       - Sekcja `## Jakość trasy (bench_jakosc)` z headline'em i tabelą statystyk
       - Headline w okolicy `~6%` (per D-08 ekstrapolacja z TEST-05)

    4. **Commit:** `bench/wyniki.md` MUSI być scommitowany (D-06 + PROJECT D-25 — to aplikacja, deterministyczne wyniki commitowane).

    5. **Empiryczna weryfikacja headline'u:**
       - mean ratio z bench_jakosc powinien być w okolicy 0.93-0.95 (zgodnie z TEST-05 lock 0.9408 i D-08 ekstrapolacją).
       - Jeśli mean > 0.97 lub mean < 0.85 → REGRESJA. Sprawdzić czy `T_zero=0.001` faktycznie został zastosowany.
       - **Warning #2 follow-up:** jeśli `std_ratio > 0.02` po regen, plan 04-08 README headline musi być zaktualizowany do faktycznej średniej zaokrąglonej do 1 dec, NIE do `~6%` placeholder.
  </how-to-verify>
  <resume-signal>
    Po wykonaniu kroków 1-5: napisać `approved: bench/wyniki.md scommitowany, mean_ratio=$WARTOSC, std_ratio=$STD, alfabetyczna_kolejnosc=YES` lub opisać blokery.

    Jeśli wrapper rzuca błąd resolverem — opisać dokładny błąd, zweryfikować czy Project.toml BenchmarkTools jest faktycznie w `[compat]` i `[extras]`.
  </resume-signal>
  <acceptance_criteria>
    - `bench/wyniki.md` istnieje i jest scommitowany (`git ls-files bench/wyniki.md` zwraca path).
    - Zawiera `# Wyniki benchmarków JuliaCity` (h1).
    - Zawiera `## Środowisko`, `## Microbenchmarki`, `## Jakość trasy` (3 h2).
    - Zawiera komendę reprodukcji `bash bench/uruchom.sh` LUB `pwsh bench/uruchom.ps1` (BLOCKER #4 — NIE bezpośrednie `julia bench/run_all.jl`).
    - **Microbench rows w alfabetycznej kolejności (Warning #3):** numer linii zawierającej `| oblicz_energie` < numer linii zawierającej `| symuluj_krok!`. Verify: `grep -n '^| oblicz_energie' bench/wyniki.md` < `grep -n '^| symuluj_krok!' bench/wyniki.md`.
    - Headline pokazuje procent (`grep -E 'średnio.*%' bench/wyniki.md` zwraca exit 0).
    - mean ratio ∈ [0.85, 0.97] (sanity range — zgodnie z D-08 ekstrapolacją).
  </acceptance_criteria>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan tworzy 3 nowe pliki (orchestrator + 2 wrappery) + generuje 1 plik markdown. Brak wejścia użytkownika, brak network. |
| module isolation | Orchestrator ładuje 3 bench scripts w izolowanych anonimowych modułach (`Module(:_BenchSandbox)`) — każdy ma własny scope dla `function main()`. |
| temp-env activation | Wrapper aktywuje throwaway Pkg env (`Pkg.activate(temp=true)`) który zyje tylko w runtime — brak persistent state poza repo. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-06-01 | Tampering | Module isolation `_uruchom_bench` | mitigate | Acceptance criteria sprawdza obecność `Module(`, `Base.include(m,`, `Base.invokelatest(m.main)`. Bez tego top-level `main()` na końcu run_all.jl wywołałby ostatnio-załadowany bench `main`, NIE orchestrator. (BLOCKER #3 fix). |
| T-04-06-02 | Tampering | Resolver path (BenchmarkTools availability) | mitigate | Wrapper auto-detect direct path → temp-env fallback. D-10 honored (no `bench/Project.toml`). Acceptance criteria sprawdza obecność `Pkg.activate(temp=true)`. (BLOCKER #4 fix). |
| T-04-06-03 | Information Disclosure | Sysinfo (CPU model, OS, Julia version) | accept | Public info, commitowane przez D-07 explicit. ASVS L1 nie wymaga redakcji. |
| T-04-06-04 | Denial of Service | bench_jakosc ~5 min wallclock | accept | Akceptowalne dla offline regeneracji (D-06 single entry point + manual commit). |

Brak ASVS L1 controls naruszonych — read-only deterministic compute + filesystem write w repo subdir.
</threat_model>

<verification>
- `bench/run_all.jl` istnieje, ma 5 helperów prefixed `_` (w tym `_uruchom_bench` z module isolation), top-level `main()` call.
- `bench/uruchom.sh` + `bench/uruchom.ps1` istnieją, oba zawierają `Pkg.activate(temp=true) + Pkg.develop(path=".") + Pkg.add("BenchmarkTools") + include("bench/run_all.jl")` w fallback gałęzi.
- `bench/wyniki.md` istnieje po Task 2 z 3 sekcjami (Środowisko + Microbenchmarki + Jakość trasy).
- Komenda `bash bench/uruchom.sh` (lub `pwsh bench/uruchom.ps1`) zwraca exit 0 i regeneruje plik.
- Microbench rows w alfabetycznej kolejności (Warning #3).
- Headline w `bench/wyniki.md` zawiera procent w okolicy 5-7% (per D-08 ekstrapolacja z 0.9408).
</verification>

<success_criteria>
- D-06 LOCKED: pojedyncza komenda `bash bench/uruchom.sh` regeneruje `bench/wyniki.md` (alternatywa `pwsh bench/uruchom.ps1`).
- D-07 LOCKED: metadane + median time + memory + alokacje per microbench + mean±std/min/max ratio dla jakości.
- D-10 honored: brak `bench/Project.toml`; wrapper używa `Pkg.activate(temp=true)` runtime-only.
- BLOCKER #3 fix: module isolation w `_uruchom_bench` — `Main.main` orchestratora nigdy nadpisany.
- BLOCKER #4 fix: wrappery `bench/uruchom.{sh,ps1}` jako canonical runtime path z auto-detect + temp-env fallback.
- BENCH-05 spełnione: wyniki w formie tabelarycznej, plik commitowany.
- Headline number wygenerowany do referencji w README D-15 §7.
- Warning #3: microbench rows alfabetycznie posortowane.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-06-SUMMARY.md`
</output>
