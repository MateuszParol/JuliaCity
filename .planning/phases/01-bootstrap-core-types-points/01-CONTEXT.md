# Phase 1: Bootstrap, Core Types & Points - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 1 dostarcza **headlessly testowalny szkielet pakietu** `JuliaCity.jl`:

1. Pełna struktura pakietu Julia (`src/`, `test/`, `examples/`, `bench/`, `Project.toml`, `Manifest.toml`).
2. Hygiena kodowania (UTF-8 / LF / no BOM) wymuszona przez `.editorconfig` + `.gitattributes` + automatyczny test.
3. Parametryczny `mutable struct StanSymulacji{R<:AbstractRNG}` z konkretnie typowanymi polami (zero-state — bez logiki SA/NN).
4. `abstract type Algorytm end` — extension point dla Holy-traits dispatch w Phase 2+.
5. Deterministyczny `generuj_punkty(n; seed=42) → Vector{Punkt2D}` w `[0,1]²`, bez mutacji `Random.GLOBAL_RNG`.
6. CI od pierwszego pusha (matryca 3 × 3) z encoding-guard testem.
7. Komentarze po polsku, asercje wewnętrzne po angielsku, ASCII filenames, `CONTRIBUTING.md` opisujący konwencje.

**Wszystko headless** — żadnego `using GLMakie` w `src/` w Phase 1. GLMakie nie pojawia się aż do Phase 3.

**Pokryte REQ-ID:** BOOT-01..04, PKT-01..04, LANG-01, LANG-04 (10 wymagań).

</domain>

<decisions>
## Implementation Decisions

### Reprezentacja `Punkt2D`
- **D-01:** `const Punkt2D = Point2{Float64}` (z `GeometryBasics`). Float64 dla precyzji sumy ~1000 odległości euklidesowych w `oblicz_energie` (Phase 2). Zero-cost konwersja do Makie scatter w Phase 3.
- **D-02:** `GeometryBasics` jako **bezpośredni** dep w `Project.toml [deps]` (compat `≥ 0.5`). Phase 3 dostanie ten sam typ przez Makie transitive — żadnych konfliktów wersji.
- **D-03:** `export Punkt2D` z modułu `JuliaCity` (zgodnie z `Vector{Punkt2D}` w publicznym kontrakcie `generuj_punkty`).
- **D-04:** Brak custom akcesorów (`wsp_x`, `wsp_y`) — używamy surowych `.x` / `.y` / `p[1]` / `p[2]` z `GeometryBasics.Point2`. Mniej dispatch noise, JET-clean hot path.

### `StanSymulacji` — zakres i kształt
- **D-05:** `mutable struct StanSymulacji{R<:AbstractRNG}` z `const` na polach które raz się ustala (Julia ≥ 1.8 — kompatybilne z `julia = "1.10"`).
- **D-06:** **Pełen komplet pól pod SA już w Phase 1** — Phase 2 tylko wypełnia wartości, nie zmienia konstruktora:

  ```
  mutable struct StanSymulacji{R<:AbstractRNG}
      const punkty::Vector{Punkt2D}
      const D::Matrix{Float64}            # n×n, pre-alokowana, niewypełniona
      const rng::R
      trasa::Vector{Int}                  # = collect(1:n)
      energia::Float64                    # = 0.0
      temperatura::Float64                # = 0.0
      iteracja::Int                       # = 0
  end
  ```

- **D-07:** **Zero-state w Phase 1** — konstruktor `StanSymulacji(punkty; rng=Xoshiro(42))` pre-alokuje `D = Matrix{Float64}(undef, n, n)` i `trasa = collect(1:n)`, ale **nie liczy** macierzy dystansów ani NN-tour. Mutating ops `oblicz_macierz_dystans!`, `inicjuj_nn!`, `oblicz_energie!` należą do Phase 2.
- **D-08:** **Distance matrix = precompute** — Open Question z STATE.md zamknięta tu. `D::Matrix{Float64}` w polu `const` (~8 MB dla N=1000, mieści się w cache laptopa). Argument: PITFALLS Pitfall 10 + O(1) lookup w `delta_energii` Phase 2.

### `abstract type Algorytm end`
- **D-09:** Phase 1 deklaruje `abstract type Algorytm end` w `src/typy.jl` (extension point dla Holy-traits). `struct SimAnnealing <: Algorytm` należy do **Phase 2** (REQ ALG-01).
- **D-10:** Tworzymy `src/algorytmy/.gitkeep` aby struktura katalogów była widoczna od Phase 1, mimo że pliki konkretne dochodzą w Phase 2.

### API `generuj_punkty`
- **D-11:** **Dwie metody** (typowo idiomatyczne dla Julia):
  - `generuj_punkty(n::Int = 1000; seed::Integer = 42)` — friendly default, dosłownie zgodny z PKT-01, buduje lokalny `Xoshiro(seed)` i deleguje.
  - `generuj_punkty(n::Int, rng::AbstractRNG)` — composable, bezpośredni dla testów.
- **D-12:** Default `n = 1000` (PKT-02). Default `seed = 42` (PROJECT.md "Key Decisions").
- **D-13:** Implementacja: `rand(rng, Punkt2D, n)` — wbudowane wsparcie `GeometryBasics` daje uniform sample w `[0,1]²` w jednym wywołaniu. Brak comprehensions, brak ręcznego promotion.
- **D-14:** **Brak interakcji z `Random.GLOBAL_RNG` / `Random.default_rng()`** — lokalny `Xoshiro(seed)` całkowicie izolowany (PKT-04, test sprawdzający `copy(Random.default_rng())` przed/po).
- **D-15:** Interop ze `StanSymulacji` — **osobne funkcje, składane jawnie** przez użytkownika:
  ```julia
  punkty = generuj_punkty(1000; seed=42)
  stan = StanSymulacji(punkty; rng=Xoshiro(42))
  ```
  Brak convenience constructora `StanSymulacji(n::Int; seed)` w v1 (Phase 4 może wprowadzić, jeśli `examples/` tego wymagają).

### Skeleton, encoding, CI
- **D-16:** **PkgTemplates.jl jednorazowo lokalnie** (REPL) — `Template(...)("JuliaCity")` z pluginami: `Tests`, `GitHubActions`, `License (MIT)`. Po wygenerowaniu — ręczny cleanup boilerplate'u, dodanie polskich plików, wprowadzenie `bench/` i `examples/`. PkgTemplates **nie** ląduje w `[deps]`.
- **D-17:** `Project.toml [compat]` od pierwszego pusha:
  ```
  julia = "1.10"
  GLMakie = "0.24"
  Makie = "0.24"
  GeometryBasics = "0.5"
  Observables = "0.5"
  StableRNGs = "1.0"
  Aqua = "0.8.14"
  JET = "0.11"
  BenchmarkTools = "1.6"
  ```
  GLMakie/Makie/Observables są w `[compat]` ale nie w `[deps]` — dochodzą w Phase 3. (Lub: tylko deps używane teraz; reszta dochodzi z fazą która ich wymaga. **Plan-phase decyduje finalny układ.**)
- **D-18:** `.editorconfig` (UTF-8 / LF / `insert_final_newline = true` / `trim_trailing_whitespace = true` / `charset = utf-8` / brak BOM-a — sygnalizowane przez `[*.{jl,toml,md}]` blok). `.gitattributes` z `*.jl text eol=lf working-tree-encoding=UTF-8` plus globalna polityka LF dla wszystkich plików tekstowych.
- **D-19:** **Wszystkie nazwy plików w `src/`, `test/`, `examples/`, `bench/` są ASCII** (brak diakrytyków w ścieżkach — chroni przed Linux CI/Git path issues). Polskie identyfikatory są OK **wewnątrz plików** (Julia obsługuje Unicode identifiers, NFC-normalized).
- **D-20:** **Pełna matryca CI** od pierwszego pusha:
  - julia: `1.10` (LTS), `1.11` (current), `nightly` (allow-failures)
  - os: `ubuntu-latest`, `windows-latest`, `macos-latest`
  - Trigger: `push` + `pull_request` na `main`
  - Headless OK — Phase 1 nie używa GLMakie. Phase 3 doda CairoMakie fallback lub `xvfb-run` (research SUMMARY.md flagged).
- **D-21:** **Encoding-validation guard jako część `runtests.jl`** (nie osobny skrypt):
  ```julia
  @testset "encoding hygiene" begin
      for plik in [walk(["src", "test"], "*.jl")...]
          tresc = read(plik, String)
          bajty = read(plik)
          @test isvalid(String, bajty)
          @test !startswith(bajty, [0xEF, 0xBB, 0xBF])  # no BOM
          @test Unicode.normalize(tresc, :NFC) == tresc  # NFC
      end
  end
  ```
  Lapie problem encodingu lokalnie i w CI; zero zewnętrznych dependencji.

### Polski / angielski split (LANG-01, LANG-04)
- **D-22:** **Komentarze po polsku** — wszystkie komentarze w `src/*.jl` są w języku polskim, włącznie z Unicode diakrytykami (NFC-normalized).
- **D-23:** **Asercje wewnętrzne / `error()` po angielsku** — np. `@assert n > 0 "n must be positive"`. User-facing strings (Phase 3 GLMakie tytuły, Phase 4 README) będą po polsku. Konwencja udokumentowana w `CONTRIBUTING.md`.
- **D-24:** Identyfikatory (nazwy funkcji, pól, zmiennych) po polsku gdzie to ma sens domenowo (`punkty`, `trasa`, `energia`, `temperatura`, `iteracja`, `cierpliwo` etc.) — alfabet bezdiakrytyczny dla bezpieczeństwa CI/IDE (`cierpliwosc` zamiast `cierpliwość`). Współrzędne pozostają `x, y` (geometria, nie domena).

### `Manifest.toml` policy
- **D-25:** `Manifest.toml` **commitowany** — to aplikacja, nie biblioteka (STACK.md, STATE todo). Ujednolica reprodukcję demo dla użytkownika końcowego. `.gitignore` **nie** wyklucza `Manifest.toml`.

### Claude's Discretion
- Dokładne nazwy modułów wewnętrznych w `src/` (np. czy `typy.jl` zawiera też `Parametry` stub czy on dochodzi w Phase 2; planner wybiera).
- Czy `CONTRIBUTING.md` jest w Phase 1 pełen czy lekki stub rozszerzany w późniejszych fazach (zalecam: lekki stub z core conventions: encoding, ASCII filenames, polski/angielski split, ASCII identifiers w nazwach plików).
- Czy `LICENSE` (MIT) jest w Phase 1 — domyślnie tak, PkgTemplates daje to za darmo.
- Dokładny układ `src/JuliaCity.jl` — `module JuliaCity ... using GeometryBasics ... include("typy.jl") ... include("punkty.jl") ... export ... end` — planner ustala kolejność.

### Folded Todos
Brak — `cross_reference_todos` nie znalazł kandydatów do złożenia w Phase 1 (todos w STATE.md są albo project-wide albo Phase 2/3-bound).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Wymagania i scope
- `.planning/PROJECT.md` — Core Value, constraints (Polish UI, GLMakie, Threading), Out of Scope.
- `.planning/REQUIREMENTS.md` §BOOT, §PKT, §LANG — wymagania pokryte przez Phase 1 (BOOT-01..04, PKT-01..04, LANG-01, LANG-04).
- `.planning/ROADMAP.md` §"Phase 1: Bootstrap, Core Types & Points" — Goal, Success Criteria (5 punktów).
- `.planning/STATE.md` §"Locked-in Decisions" — compat `julia = "1.10"`, `StableRNG(42)` w testach, threading-inside-only, public API surface (4 funkcje), Polish/English language split.

### Research (lockujący kontekst techniczny)
- `.planning/research/SUMMARY.md` — Executive summary; Phase 0/1 sections (skeleton, types, headless test) są punktem wyjścia plannera.
- `.planning/research/STACK.md` — kompletna tabela wersji + `[compat]` floor, "What NOT to Use" lista (`Random.seed!` bez RNG, global mutable state, `@threads` outside function), version compatibility matrix.
- `.planning/research/ARCHITECTURE.md` — single module + `include()`, parametric `StanSymulacji{R<:AbstractRNG}`, Holy-traits dispatch via `abstract type Algorytm end`, build order (`typy → punkty → energia → algorytmy → symulacja → wizualizacja → eksport`).
- `.planning/research/PITFALLS.md` — Pitfall 1 (type instability via abstract fields), Pitfall 8 (cross-version RNG reproducibility — `StableRNG` w testach, `Xoshiro` w `src/`), Pitfall 9 (Polish encoding na Windowsie), Pitfall 10 (distance-matrix precompute), Pitfall 18 (mixed-language errors).
- `.planning/research/FEATURES.md` §"Must have (table stakes — v1.0)" — table stakes dla Phase 1 są zgodne z BOOT/PKT.

### Konwencje projektowe
- `CLAUDE.md` §"Conventions" + §"Constraints" — Polish-only UI/comments hard requirement, modular structure with mandated functions, default seed.

### Brak zewnętrznych ADR-ów
W repo nie ma katalogu `docs/adr/` ani `docs/specs/` — wszystkie decyzje technologiczne żyją w `.planning/research/` plus zaakceptowane w `.planning/STATE.md`. Phase 1 nie wprowadza nowych ADR-ów.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Brak istniejącego kodu Julia** — repo zawiera tylko `.planning/`, `.git/`, `CLAUDE.md`. Phase 1 jest greenfield; nie ma plików do wykorzystania ponownie. Pierwszy commit kodu powstaje w tej fazie.

### Established Patterns
- **`.planning/` pattern** — completed: `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, `research/{SUMMARY,STACK,ARCHITECTURE,PITFALLS,FEATURES}.md` istnieją i są źródłem prawdy.
- **Brak prior phase patterns** — Phase 1 ustanawia konwencje (Polish/English split, encoding policy, struct shape) na które kolejne fazy będą się powoływać.

### Integration Points
- **Phase 2 hot zone** — Phase 1 musi zostawić StanSymulacji w stanie, w którym Phase 2 dostaje stabilny konstruktor i pełen zestaw mutable-able pól (energia, temperatura, iteracja, trasa). Decision D-06/D-07 to konkretyzuje.
- **Phase 3 hot zone** — `Punkt2D = Point2{Float64}` (D-01) jest celowo wybrany aby `Vector{Punkt2D}` flowowało bez konwersji do Makie's `Point2{Float64}` scatter input.
- **CI hot zone** — encoding guard (D-21) chroni Phase 2..4 przed regresją; matryca OS (D-20) wcześnie łapie Windows-1250 issue z PITFALLS Pitfall 9.

</code_context>

<specifics>
## Specific Ideas

- Test dla PKT-04 ("no global RNG mutation"): `przed = copy(Random.default_rng()); generuj_punkty(1000; seed=42); po = copy(Random.default_rng()); @test przed == po`. Zauważ — `copy(Random.default_rng())` to `TaskLocalRNG`, więc test musi działać na tym samym tasku.
- Test dla "deterministic dla seed=42": `@test generuj_punkty(1000; seed=42) == generuj_punkty(1000; seed=42)` (golden-value można dodać w Phase 2 z `StableRNG(42)`).
- `Project.toml [extras]` + `[targets]` — `Aqua`, `JET`, `StableRNGs` jako test deps (NIE w `[deps]`, zgodnie z STACK.md).
- `CONTRIBUTING.md` minimum: encoding (UTF-8/LF/no BOM), ASCII filenames, polski/angielski split, ASCII-only identyfikatory w plikach źródłowych (`cierpliwosc` zamiast `cierpliwość`).

</specifics>

<deferred>
## Deferred Ideas

- **`Parametry` struct shape** — pole z hiperparametrami SA (T₀, α, cierpliwosc); planner Phase 1 może go dorzucić do `typy.jl` jako pure-data stub, ale konkretne pola są ALG-related → Phase 2 dolicza.
- **Documenter.jl + dokumentacja API** — projekt ma README.md po polsku w Phase 4, ale pełna Documenter.jl page (`docs/`) nie jest scope'em v1. Możliwe v1.1+ jeśli pakiet ma trafić do General Registry.
- **JuliaFormatter / Pre-commit hooks** — odsuwamy. Encoding-guard test w `runtests.jl` (D-21) wystarcza dla v1.
- **Convenience constructor `StanSymulacji(n::Int; seed)`** — Phase 4 może go dodać jeśli `examples/podstawowy.jl` wymaga zwięzłego kodu. Phase 1 nie wprowadza.
- **CairoMakie fallback dla headless CI** — research flagged dla Phase 3+. Phase 1 jest headless natively, więc problem nie istnieje teraz.
- **`scripts/check_encoding.jl` jako standalone tool** — odrzucone na rzecz testu w `runtests.jl`. Można dodać w Phase 4 jeśli pre-commit hook się pojawi.

### Reviewed Todos (not folded)
- "Confirm `Manifest.toml` is committed" (STATE.md TODO) — **rozwiązane w D-25** (commit yes), formalnie usunięte z STATE.md po Phase 1.
- "Add encoding-validation CI guard test" (STATE.md TODO) — **fold do Phase 1 D-21**, oznaczyć `done` po Phase 1 verify.
- "Document Polish-typography convention" (STATE.md TODO) — **deferred do Phase 4** (przed README polish; dotyczy user-facing strings, nie source code).

</deferred>

---

*Phase: 1-bootstrap-core-types-points*
*Context gathered: 2026-04-28*
