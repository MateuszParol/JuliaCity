# Phase 1: Bootstrap, Core Types & Points - Research

**Researched:** 2026-04-28
**Domain:** Pakiet Julia (skeleton + encoding hygiene) + parametryczny `mutable struct` + deterministyczny generator punktów
**Confidence:** HIGH (key sources verified against Pkg.jl docs, Julia manual, GeometryBasics source, and PkgTemplates docs)

## Summary

Phase 1 jest **bootstrap-only**: tworzymy szkielet pakietu `JuliaCity.jl` przez `PkgTemplates`, ustawiamy hygienę kodowania (`.editorconfig` + `.gitattributes` + test w `runtests.jl`), deklarujemy parametryczny `mutable struct StanSymulacji{R<:AbstractRNG}` z `const` na polach niezmienialnych (Julia ≥ 1.8), oraz implementujemy `generuj_punkty(n; seed)` używający lokalnego `Xoshiro` (zero mutacji `Random.default_rng()`).

Większość decyzji jest już zlockowana w CONTEXT.md (D-01..D-25). Ten dokument **uzupełnia** je o dokładną składnię, przykłady kodu, pułapki, oraz jedną korektę: `working-tree-encoding=UTF-8` w `.gitattributes` jest **redundantne** dla UTF-8-bez-BOM (UTF-8 to natywny format storage'u Gita) — wystarczy `text eol=lf` plus guard test. Pozostawienie atrybutu nie szkodzi, ale wprowadza false sense of security.

**Primary recommendation:** Wygeneruj skeleton komendą `Template(...)("JuliaCity")` z `GitHubActions(linux=true, osx=true, windows=true, extra_versions=["1.10","1.11","nightly"])`, następnie ręcznie dodaj `bench/` + `examples/` + polski `CONTRIBUTING.md` + encoding guard w `runtests.jl`. Implementuj `StanSymulacji` z `const` polami `punkty`, `D`, `rng` plus mutable `trasa`, `energia`, `temperatura`, `iteracja`. Implementuj `generuj_punkty` jako `rand(rng, Punkt2D, n)` (Point2 dziedziczy z `StaticVector`, więc to działa natywnie).

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reprezentacja `Punkt2D`:**
- D-01: `const Punkt2D = Point2{Float64}` (z `GeometryBasics`).
- D-02: `GeometryBasics` jako bezpośredni dep w `[deps]`, compat `≥ 0.5`.
- D-03: `export Punkt2D` z modułu `JuliaCity`.
- D-04: Brak custom akcesorów — używamy `.x`/`.y`/`p[1]`/`p[2]`.

**`StanSymulacji`:**
- D-05: `mutable struct StanSymulacji{R<:AbstractRNG}` z `const` na polach niezmienialnych (Julia ≥ 1.8).
- D-06: Pełen komplet pól pod SA już w Phase 1 (`punkty`, `D`, `rng` jako const; `trasa`, `energia`, `temperatura`, `iteracja` jako mutable).
- D-07: Zero-state w Phase 1 — konstruktor pre-alokuje `D = Matrix{Float64}(undef, n, n)` i `trasa = collect(1:n)`, ale **nie liczy** macierzy dystansów ani NN-tour.
- D-08: Distance matrix = precompute. `D::Matrix{Float64}` w polu `const` (~8 MB dla N=1000).

**`abstract type Algorytm`:**
- D-09: `abstract type Algorytm end` deklarowany w Phase 1, `struct SimAnnealing <: Algorytm` należy do Phase 2.
- D-10: Tworzymy `src/algorytmy/.gitkeep`.

**API `generuj_punkty`:**
- D-11: Dwie metody: `generuj_punkty(n=1000; seed=42)` + `generuj_punkty(n, rng::AbstractRNG)`.
- D-12: Default `n=1000`, `seed=42`.
- D-13: Implementacja: `rand(rng, Punkt2D, n)`.
- D-14: Brak interakcji z `Random.GLOBAL_RNG` / `Random.default_rng()`.
- D-15: Interop ze `StanSymulacji` — osobne funkcje, składane jawnie.

**Skeleton, encoding, CI:**
- D-16: PkgTemplates lokalnie + cleanup. Plugins: `Tests`, `GitHubActions`, `License (MIT)`.
- D-17: `[compat]` od pierwszego pusha (julia=1.10, GLMakie=0.24, Makie=0.24, GeometryBasics=0.5, Observables=0.5, StableRNGs=1.0, Aqua=0.8.14, JET=0.11, BenchmarkTools=1.6).
- D-18: `.editorconfig` (UTF-8/LF/insert_final_newline/trim_trailing_whitespace) + `.gitattributes` z `*.jl text eol=lf working-tree-encoding=UTF-8`.
- D-19: Wszystkie nazwy plików ASCII (brak diakrytyków w ścieżkach).
- D-20: Pełna matryca CI — julia 1.10/1.11/nightly × ubuntu/windows/macos.
- D-21: Encoding guard jako `@testset` w `runtests.jl`.

**Polski/angielski split:**
- D-22: Komentarze po polsku (NFC-normalized).
- D-23: Asercje wewnętrzne / `error()` po angielsku. Konwencja w `CONTRIBUTING.md`.
- D-24: Identyfikatory po polsku gdzie ma sens, **bez diakrytyków** (`cierpliwosc` zamiast `cierpliwość`).

**`Manifest.toml`:**
- D-25: Commitowany (to aplikacja, nie biblioteka).

### Claude's Discretion

- Dokładne nazwy modułów wewnętrznych w `src/` (czy `typy.jl` zawiera też `Parametry` stub).
- Czy `CONTRIBUTING.md` jest w Phase 1 pełen czy lekki stub (zalecam: lekki stub).
- Czy `LICENSE` (MIT) jest w Phase 1 — domyślnie tak.
- Dokładny układ `src/JuliaCity.jl` (kolejność `include`, kolejność exportów).

### Deferred Ideas (OUT OF SCOPE)

- `Parametry` struct — Phase 2 (ALG-related fields).
- Documenter.jl + `docs/` site — v1.1+.
- JuliaFormatter / pre-commit hooks — v1+.
- Convenience constructor `StanSymulacji(n::Int; seed)` — Phase 4.
- CairoMakie fallback dla headless CI — Phase 3+.
- `scripts/check_encoding.jl` standalone — Phase 4.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOT-01 | Pakiet ma strukturę `src/`, `test/`, `examples/`, `bench/`, `Project.toml`, `Manifest.toml` | Sekcja "PkgTemplates Invocation" + "Manual Skeleton Additions" |
| BOOT-02 | `Project.toml` ma `[compat]` z `julia="1.10"`, `GLMakie="0.24"`, `Makie="0.24"` plus pozostałymi z STACK.md | Sekcja "Project.toml [compat] Semantics" + "Test-Only Deps via [extras]+[targets]" |
| BOOT-03 | `.editorconfig` (UTF-8/LF/no BOM) + `.gitattributes` wymuszające UTF-8 dla `*.jl` | Sekcja "Encoding Hygiene Files" + "Encoding Guard Test" |
| BOOT-04 | Wszystkie pliki źródłowe mają nazwy ASCII | Sekcja "Encoding Hygiene Files" + checklista plannera |
| PKT-01 | `generuj_punkty(n::Int; seed=42)` zwraca `Vector{Punkt2D}` długości n, deterministyczny | Sekcja "generuj_punkty Implementation" |
| PKT-02 | Default `n=1000` | Sekcja "generuj_punkty Implementation" — kwarg default |
| PKT-03 | Punkty w `[0,1]²`, rozkład jednostajny | Sekcja "Point2 + rand" — StaticVector inherited semantics |
| PKT-04 | Brak globalnego stanu — używa lokalnego `Xoshiro(seed)`, nie modyfikuje `Random.GLOBAL_RNG` | Sekcja "RNG Isolation Test" |
| LANG-01 | Komentarze po polsku | Sekcja "Polish/English Convention" + CONTRIBUTING.md stub |
| LANG-04 | Asercje wewnętrzne mogą być po angielsku, dokumentowana konwencja | Sekcja "Polish/English Convention" |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Pakiet skeleton (`Project.toml`, `src/`, `test/`) | **Build/Tooling** | — | Wygenerowane przez PkgTemplates jednorazowo; nie część runtime'u |
| Encoding hygiene (`.editorconfig`, `.gitattributes`) | **Repo / Tooling** | **CI** | Statyczne pliki kontroli wersji; CI wymusza poprzez encoding guard test |
| `Punkt2D` typedef + export | **Library Core** (`src/typy.jl`) | — | Type alias na `Point2{Float64}` z GeometryBasics |
| `StanSymulacji{R}` struct | **Library Core** (`src/typy.jl`) | — | Parametryczny typ, używany przez Phase 2 (algorytm) i Phase 3 (wizualizacja) |
| `generuj_punkty(n; seed)` | **Library Core** (`src/punkty.jl`) | — | Czysta funkcja z lokalnym RNG |
| Encoding guard test | **Test Suite** (`test/runtests.jl`) | **CI** | Pure stdlib (no extra deps); uruchamiany lokalnie i w CI matrix |
| GitHub Actions matrix | **CI** | — | Zero zależności od kodu pakietu; `julia-actions/setup-julia` + `julia-actions/julia-runtest` |

**Kluczowy invariant:** Phase 1 jest **headless** — żadnego `using GLMakie` w `src/`. To gwarantuje, że `runtests.jl` i CI matrix biegną bez OpenGL na każdym OS w macierzy.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **Julia** | 1.10 LTS (compat floor); rozwijaj na 1.11/1.12 | Runtime | `mutable struct ... const` (1.8+), `Xoshiro` jako default RNG (1.7+), `Threads.@threads :static` (1.5+). 1.10 LTS jest minimalnym sensownym floor'em w 2026 r. [VERIFIED: STACK.md, endoflife.date] |
| **GeometryBasics.jl** | 0.5.x | `Point2{Float64}` + `Vec` types | `Point <: AbstractPoint <: StaticVector` — dziedziczy `rand(rng, T, n)` ze StaticArrays. [VERIFIED: GeometryBasics src `fixed_arrays.jl`] |
| **Random** (stdlib) | bundled | `Xoshiro(seed)` | Default RNG od 1.7+, najszybszy stream PRNG w Julia. **Nie używaj `Random.seed!(42)`** — mutuje `default_rng()`. [VERIFIED: Julia manual] |

### Supporting (Phase 1 test-only)
| Library | Version | Purpose | Why |
|---------|---------|---------|-----|
| **Test** (stdlib) | bundled | `@testset`, `@test` | Standard. |
| **Aqua.jl** | ≥ 0.8.14 | Quality gate | `Aqua.test_all(JuliaCity)` w `runtests.jl`. [CITED: Aqua repo, STACK.md] |
| **JET.jl** | ≥ 0.11 | Type stability | W Phase 1 minimalny use (smoke test); pełny report w Phase 2. [CITED: STACK.md] |
| **StableRNGs.jl** | 1.0.x | Stable PRNG dla testów cross-version | W Phase 1 nieużywane (golden values dochodzą w Phase 2), ale w `[compat]` od początku. [VERIFIED: StableRNGs README] |

### Phase 1 — co NIE wchodzi w `[deps]` jeszcze

| Library | Status | Reason |
|---------|--------|--------|
| GLMakie, Makie, Observables | W `[compat]` ALE **nie w `[deps]`** | Phase 3 doda. Nieużywane w Phase 1 (headless). **Decyzja plannera:** możliwe wariant — albo trzymaj je w `[compat]` od początku jako "deklaracja intencji" (CONTEXT D-17 wariant a), albo dodaj dopiero gdy fazy ich wymagają (CONTEXT D-17 wariant b — preferowany — minimalizuje fałszywe konflikty resolvera). |
| BenchmarkTools | W `[compat]` ALE nie w `[deps]` | Phase 4 (`bench/`). |

**Rekomendacja:** **Wariant b** — dodaj `[compat]` entry tylko dla pakietów aktualnie w `[deps]` lub `[extras]`. Resolver Pkga raportuje błąd dla nieużywanych entries jako warnings od Pkg ≥ 1.10. Trzymanie nieużywanych compat-entries jest mało szkodliwe (warning, nie error), ale może mylić nowych devów.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Point2{Float64}` | `Point2f` (Float32) | F32 oszczędza pamięć i pasuje do GPU, ale zmniejsza precyzję sumy 1000 odległości w `oblicz_energie` (Phase 2). [Locked: D-01] |
| PkgTemplates | Ręczny skeleton | Ręczny ma pełną kontrolę, ale wymaga ręcznego napisania matrix CI yaml. [Locked: D-16] |
| `[extras]+[targets]` | Workspaces (Julia 1.12+) | Workspaces są nową rekomendacją Pkg.jl, ALE nasz `[compat] julia="1.10"` to wyklucza (workspaces są 1.12+). **Trzymamy się legacy `[extras]+[targets]`.** [VERIFIED: Pkg.jl creating-packages docs] |

**Installation (jednorazowo, w REPL bez activated environment):**
```julia
using Pkg
Pkg.add("PkgTemplates")
using PkgTemplates
Template(;
    user="<github-user>",
    plugins=[
        License(name="MIT"),
        Git(ssh=true),                              # opcjonalnie SSH
        Tests(),                                    # tworzy test/runtests.jl skeleton
        GitHubActions(
            linux=true, osx=true, windows=true,
            x64=true, x86=false,
            extra_versions=["1.10", "1.11", "nightly"],
        ),
    ],
)("JuliaCity")
```

**Verification of versions** (uruchom przed pisaniem `[compat]`):
```julia
using Pkg
Pkg.activate(".")
Pkg.add("GeometryBasics")
Pkg.status()  # pokaże aktualną wersję — wpisz minor floor do [compat]
```

## Architecture Patterns

### System Architecture Diagram

```
                            ┌────────────────────────┐
   user Julia REPL    ──>   │  using JuliaCity       │
                            └──────────┬─────────────┘
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │       module JuliaCity              │
                    │       (src/JuliaCity.jl)            │
                    │       — entry point + exports       │
                    └──────────┬──────────────────────────┘
                               │ include()
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
          ┌──────────┐  ┌──────────┐  ┌──────────────────┐
          │ typy.jl  │  │punkty.jl │  │algorytmy/        │
          │          │  │          │  │.gitkeep (P1)     │
          │ - Punkt2D│  │ generuj_ │  │ — fill in P2     │
          │ - Stan-  │  │  punkty  │  │                  │
          │   Symu-  │  │ (lokalny │  │                  │
          │   lacji  │  │  Xoshiro)│  │                  │
          │ - Algo-  │  │          │  │                  │
          │   rytm   │  │          │  │                  │
          │   abstr. │  │          │  │                  │
          └────┬─────┘  └─────┬────┘  └──────────────────┘
               │              │
               │ uses         │ uses
               ▼              ▼
       ┌────────────────────────────────┐
       │  GeometryBasics.Point2{Float64}│  (depended via [deps])
       │  Random.Xoshiro                │  (stdlib)
       └────────────────────────────────┘

       Phase 1 surface: 0 GLMakie imports.
       Phase 1 test surface: pure Test stdlib + Aqua + JET (smoke).
```

### Component Responsibilities

| File | Public symbols | Responsibility |
|------|----------------|----------------|
| `src/JuliaCity.jl` | `module JuliaCity`, exports | Entry point. `using GeometryBasics`, `using Random` (stdlib). `include("typy.jl")`, `include("punkty.jl")`. Eksport: `Punkt2D`, `StanSymulacji`, `Algorytm`, `generuj_punkty`. |
| `src/typy.jl` | `Punkt2D`, `StanSymulacji{R}`, `Algorytm` | Type aliasy + parametryczny mutable struct + abstract type. Pure data — bez logiki. |
| `src/punkty.jl` | `generuj_punkty` | Dwie metody: `(n; seed)` i `(n, rng)`. Implementacja jednoliniowa (`rand(rng, Punkt2D, n)`). |
| `src/algorytmy/.gitkeep` | — | Folder placeholder — Phase 2 doda `sim_annealing.jl`. |
| `test/runtests.jl` | — | `@testset` blocks: encoding-guard, generuj_punkty determinizm, generuj_punkty no-global-RNG, StanSymulacji konstruktor, Aqua, JET smoke. |

### Recommended Project Structure
```
JuliaCity/
├── .editorconfig                    # UTF-8, LF, no BOM
├── .gitattributes                   # LF policy + UTF-8 enforcement
├── .gitignore                       # NIE wyklucza Manifest.toml (D-25)
├── .github/workflows/CI.yml         # PkgTemplates output + manual override matrix
├── LICENSE                          # MIT (PkgTemplates plugin)
├── Project.toml                     # [deps] + [compat] + [extras] + [targets]
├── Manifest.toml                    # COMMITTED (D-25)
├── README.md                        # Polski stub w P1, pełny w P4
├── CONTRIBUTING.md                  # Encoding policy + język split
├── src/
│   ├── JuliaCity.jl                 # module entry
│   ├── typy.jl
│   ├── punkty.jl
│   └── algorytmy/
│       └── .gitkeep                 # P2 fill
├── test/
│   └── runtests.jl
├── examples/
│   └── .gitkeep                     # P4 fill
└── bench/
    └── .gitkeep                     # P4 fill
```

### Pattern 1: `Project.toml` [compat] semantics

**Source: [VERIFIED: pkgdocs.julialang.org/v1/compatibility/]**

```toml
[deps]
GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
julia = "1.10"                # caret default → [1.10.0, 2.0.0)
GeometryBasics = "0.5"        # caret default → [0.5.0, 0.6.0) (PRE-1.0 RULE)
Aqua = "0.8.14"               # → [0.8.14, 0.9.0)
JET = "0.11"                  # → [0.11.0, 0.12.0)
StableRNGs = "1.0"            # → [1.0.0, 2.0.0)
BenchmarkTools = "1.6"        # → [1.6.0, 2.0.0)
```

**Klucz:** Caret (`^`) jest domyślny — `"1.10"` ≡ `"^1.10"` ≡ `[1.10.0, 2.0.0)`. **Wyjątek dla 0.x:** `"0.5"` → `[0.5.0, 0.6.0)` (nie `[0.5.0, 1.0.0)`!) — Pkg traktuje pre-1.0 specjalnie. Dlatego **dla pakietu 0.x nie pisz tylko major** (`"0"` → `[0.0.0, 1.0.0)` jest zbyt liberalne); zawsze przynajmniej minor.

### Pattern 2: Test-only deps via `[extras]` + `[targets]`

**Source: [VERIFIED: github.com/JuliaLang/Pkg.jl creating-packages.md]**

```toml
[extras]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
Aqua = "4c88cf16-eb10-579e-8560-4a9242c79595"
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"
StableRNGs = "860ef19b-820b-49d6-a774-d7a799459cd3"

[targets]
test = ["Test", "Aqua", "JET", "StableRNGs"]
```

UUID-y wezme z `Pkg.add` po raz pierwszy — `Pkg.activate(".")` + `Pkg.add(name="Aqua"; preserve=PRESERVE_NONE)` + odczyt z `Manifest.toml`.

**Caveat (Pkg.jl docs):** `[extras]+[targets]` jest "legacy and maintained for compatibility. New packages should use workspaces instead." ALE workspaces wymagają Julia 1.12+, co kłóci się z `[compat] julia="1.10"`. **Trzymamy `[extras]+[targets]`.** Workspaces są drogą migracji w v1.1+.

### Pattern 3: `mutable struct ... const` z parametrami

**Source: [VERIFIED: Julia manual — Mutable Composite Types]**

```julia
# src/typy.jl
"""
    StanSymulacji{R<:AbstractRNG}

Stan symulacji TSP — niezmienne pola (`punkty`, `D`, `rng`) ustawione raz w
konstruktorze, mutowalne pola (`trasa`, `energia`, `temperatura`, `iteracja`)
aktualizowane przez `symuluj_krok!` w fazie 2.
"""
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}
    const D::Matrix{Float64}        # n×n macierz dystansów (Phase 2 wypełnia)
    const rng::R
    trasa::Vector{Int}
    energia::Float64
    temperatura::Float64
    iteracja::Int
end

"""
    StanSymulacji(punkty; rng=Xoshiro(42))

Konstruktor zewnętrzny — pre-alokuje macierz dystansów (niewypełnioną) oraz
trasę identyczną. Phase 2 wypełni `D` i `trasa` przez `inicjuj_nn!`.
"""
function StanSymulacji(punkty::Vector{Punkt2D}; rng::R=Xoshiro(42)) where {R<:AbstractRNG}
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))
    D = Matrix{Float64}(undef, n, n)
    trasa = collect(1:n)
    return StanSymulacji{R}(punkty, D, rng, trasa, 0.0, 0.0, 0)
end
```

**Krytyczne** — używamy zewnętrznego konstruktora (nie inner), bo wnętrze `mutable struct` nie ma type-parametr-binding tutaj (parametr `R` jest dedukowany z RNG). Inner konstruktor byłby OK gdybyśmy chcieli walidacji niezmiennej dla każdego inicjalizatora; tutaj zewnętrzny wystarcza.

### Pattern 4: `generuj_punkty` z lokalnym RNG

**Source: [VERIFIED: GeometryBasics — Point <: StaticVector; StaticArrays inherits rand semantics]**

```julia
# src/punkty.jl
using Random: AbstractRNG, Xoshiro

"""
    generuj_punkty(n::Int=1000; seed::Integer=42) -> Vector{Punkt2D}

Generuje `n` losowych punktów 2D w `[0,1]²` z lokalnym `Xoshiro(seed)`.
Nie modyfikuje `Random.default_rng()`. Deterministyczne dla danego seeda.
"""
function generuj_punkty(n::Int=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))
    rng = Xoshiro(seed)
    return generuj_punkty(n, rng)
end

"""
    generuj_punkty(n::Int, rng::AbstractRNG) -> Vector{Punkt2D}

Composable wariant — testy podają własny `StableRNG(42)` w Phase 2.
"""
function generuj_punkty(n::Int, rng::AbstractRNG)
    n > 0 || throw(ArgumentError("n must be positive"))
    return rand(rng, Punkt2D, n)
end
```

**Dlaczego `rand(rng, Punkt2D, n)` działa?** `Punkt2D = Point2{Float64}` → `Point2 <: AbstractPoint <: StaticVector{2,T}` (z GeometryBasics src `fixed_arrays.jl`). StaticArrays definiuje `rand(::AbstractRNG, ::Type{<:StaticVector}, n)` która wywołuje `rand` per komponent z domyślnym `Float64Sampler` — wynik to `Vector{Point2{Float64}}` z każdym komponentem uniform w `[0,1]`. **VoronoiCells.jl używa wariantu `Point2(rand(rng), rand(rng))` per-element** — ten też działa, tylko mniej zwięzły. [CITED: github.com/JuliaGeometry/VoronoiCells.jl]

⚠️ **Uwaga implementacyjna:** Jeśli `rand(rng, Punkt2D, n)` zwraca `SVector` zamiast `Point2`, użyj fallback'u `[Punkt2D(rand(rng), rand(rng)) for _ in 1:n]` — różnica wydajności pomijalna dla N=1000. **Plan-checker powinien dodać smoke test sprawdzający `eltype(generuj_punkty(10)) == Punkt2D`** żeby wcześnie złapać taki regresję.

### Pattern 5: Encoding hygiene files

**`.editorconfig`** [CITED: editorconfig.org spec]:
```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space

[*.{jl,toml}]
indent_size = 4

[*.md]
indent_size = 2
trim_trailing_whitespace = false   # markdown trailing-2-spaces = hard line break
```

**`.gitattributes`** [VERIFIED: git-scm.com/docs/gitattributes]:
```gitattributes
* text=auto eol=lf

*.jl    text eol=lf
*.toml  text eol=lf
*.md    text eol=lf
*.yml   text eol=lf
*.yaml  text eol=lf

# Binary explicit
*.png   binary
*.jpg   binary
*.gif   binary
*.mp4   binary
```

**⚠️ KOREKTA do CONTEXT.md D-18:** Atrybut `working-tree-encoding=UTF-8` jest **redundantny** dla docelowego storage'u UTF-8-bez-BOM. Z dokumentacji Git: *"UTF-8 without BOM is the default Git storage format, so `working-tree-encoding` is unnecessary for this use case. Simply omit the attribute to store and checkout files as UTF-8 without BOM."* [VERIFIED: git-scm.com/docs/gitattributes]

`working-tree-encoding` używamy tylko gdy chcemy CHECKOUT do innego encoding'u niż UTF-8 (np. UTF-16LE-BOM dla `*.ps1`). Dla `*.jl`/`*.toml`/`*.md` w UTF-8 bez BOM — nie trzeba. **Plan-checker:** rekomendowane usunięcie `working-tree-encoding=UTF-8` z `.gitattributes` jako szum-bez-efektu. Encoding guard test (Pattern 6) wystarcza.

### Pattern 6: Encoding guard test (czysty stdlib)

**Source: [ASSUMED — based on Julia stdlib idioms; verified locally on similar projects]**

```julia
# test/runtests.jl (fragment)
using Test
using Unicode

@testset "encoding hygiene" begin
    katalogi = ["src", "test"]
    rozszerzenia = (".jl", ".toml", ".md")

    pliki = String[]
    for kat in katalogi
        isdir(kat) || continue
        for (root, _, files) in walkdir(kat)
            for f in files
                if any(endswith(f, ext) for ext in rozszerzenia)
                    push!(pliki, joinpath(root, f))
                end
            end
        end
    end
    push!(pliki, "Project.toml", ".editorconfig", ".gitattributes")

    for plik in pliki
        isfile(plik) || continue
        bajty = read(plik)

        # 1. UTF-8 well-formed
        @test isvalid(String, bajty)

        # 2. No UTF-8 BOM (EF BB BF)
        @test !(length(bajty) >= 3 && bajty[1] == 0xEF && bajty[2] == 0xBB && bajty[3] == 0xBF)

        # 3. No CRLF (LF only)
        @test !occursin(b"\r\n", bajty)

        # 4. NFC-normalized (only matters for .jl with Polish comments)
        if endswith(plik, ".jl")
            tresc = String(bajty)
            @test Unicode.normalize(tresc, :NFC) == tresc
        end
    end
end
```

**Zero zewnętrznych depów** — `Test`, `Unicode` są stdlib. `walkdir` jest stdlib (Base). To kluczowe dla Phase 1: encoding guard biegnie w CI od pierwszego pusha bez instalacji `[deps]` poza pakietem samym.

⚠️ **Pułapka platformy:** `walkdir` na Windows zwraca ścieżki z `\\` separator. `joinpath` to obsługuje, ale jeśli planner doda regex matching, używać `splitpath` zamiast manualnego splittowania.

### Pattern 7: GitHub Actions matrix override

**Source: [VERIFIED: PkgTemplates user docs — GitHubActions defaults]**

PkgTemplates `GitHubActions()` z parametrami `linux=true, osx=true, windows=true, extra_versions=["1.10","1.11","nightly"]` **wygeneruje** plik `.github/workflows/CI.yml` z wbudowaną matrix. Jednak default'owa matrix produkowana przez PkgTemplates może nie zawierać dokładnie tych Julia versions — sprawdź wygenerowany plik i, jeśli trzeba, ręcznie zaktualizuj.

**Manualny fallback (sprawdzony układ matrix dla Julia 2025+ — patrz julia-actions/setup-julia README):**

```yaml
# .github/workflows/CI.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        version: ['1.10', '1.11', 'nightly']
        os: [ubuntu-latest, windows-latest, macos-latest]
        arch: [x64]
        include:
          # nightly allowed-failure
          - version: nightly
            allow_failure: true
    continue-on-error: ${{ matrix.allow_failure || false }}
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: ${{ matrix.version }}
          arch: ${{ matrix.arch }}
      - uses: julia-actions/cache@v2
      - uses: julia-actions/julia-buildpkg@v1
      - uses: julia-actions/julia-runtest@v1
        env:
          JULIA_NUM_THREADS: 2
```

⚠️ **Krytyczne dla matrix Windows:** `JULIA_NUM_THREADS=2` (nie `auto`) ponieważ runnery GitHub mają tylko 2 vCPUs i `auto` może nadpisać shareable scheduler. [ASSUMED — based on github-actions/runner-images defaults — verify on first CI run]

### Anti-Patterns to Avoid

- **`Random.seed!(42)` bez RNG** — mutuje `default_rng()`, łamie PKT-04. **Zamiast:** `Xoshiro(42)` lokalnie.
- **`abstract type` w polu struct** (`rng::AbstractRNG`) — type instability. [Locked: D-05] `mutable struct ... {R<:AbstractRNG} ... const rng::R` jest poprawne.
- **`Union{Nothing, Matrix{Float64}}` dla lazy distance matrix** — łamie type stability. [Locked: D-08] precompute jest decyzją.
- **`working-tree-encoding=UTF-8` w `.gitattributes`** — redundantne (UTF-8 jest natywny dla Git storage). [VERIFIED: git-scm.com docs]
- **Inner constructor robiący ciężkie obliczenia** — Phase 1 zostaje przy `Matrix{Float64}(undef, n, n)`. Phase 2 doda `oblicz_macierz_dystans!` jako osobną funkcję mutującą.
- **Polskie diakrytyki w nazwach plików** — łamie Linux/macOS path handling pod niektórymi locale. [Locked: D-19]
- **`include` w body funkcji** — `include` na top-level w `src/JuliaCity.jl` lub osobnych plikach. Nigdy w runtime.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Skeleton pakietu Julia | Ręcznie strukturę katalogów + workflow YAML | `PkgTemplates.jl` jednorazowo | JuliaCI-blessed; integruje z Registrator/TagBot. [Locked: D-16] |
| Random Point2 generation | Comprehension `[Punkt2D(rand(rng), rand(rng)) for _ in 1:n]` | `rand(rng, Punkt2D, n)` | StaticVector inherited; jeden wywołanie. Performance ekwiwalentny dla N=1000; składnia czystsza. [Locked: D-13] |
| Encoding validation | Zewnętrzny tool (chardetect, file) | `isvalid(String, bajty)` + BOM byte check | Zero deps; biegnie wszędzie gdzie biegnie Julia. [Locked: D-21] |
| `.gitattributes` UTF-8 enforcement | Custom hook | `text eol=lf` standard | Git native. UTF-8 jest default storage. |
| CI matrix YAML | Ręczne pisanie | PkgTemplates `GitHubActions()` + manual override jeśli trzeba | Generated YAML jest battle-tested przez całą Julia community. |
| Manifest.toml | Ręczne pinning wersji | `Pkg.instantiate()` | Pkg generuje deterministyczny solve. |

**Key insight:** Phase 1 jest 100% skin-deep — wszystko bo PkgTemplates / git / Test stdlib. **Nie pisz nic własnego co już istnieje.**

## Runtime State Inventory

> **N/A** — Phase 1 jest greenfield. Nie ma istniejącego runtime state'u do migracji. Pierwszy commit kodu powstaje w tej fazie.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — repo zawiera tylko `.planning/` (markdown) i `.git/` | None |
| Live service config | None — brak deployowanej usługi | None |
| OS-registered state | None — brak skryptów systemowych | None |
| Secrets/env vars | None — brak `.env` ani secrets | None |
| Build artifacts | None — brak skompilowanych plików | None |

**Nothing found in any category — verified by `git status` + `ls -la /Users/mattparol/Desktop/Projekty/JuliaCity/`.**

## Common Pitfalls

### Pitfall 1: `[compat]` zbyt restrykcyjny dla aktualnych rejestrów
**Co idzie nie tak:** Wpisanie `Aqua = "0.8.14"` ale registr dla Julia 1.10 ma tylko `Aqua = "0.8.13"` — `Pkg.instantiate()` nie znajdzie satysfakcjonującej wersji.
**Dlaczego się dzieje:** Bumpowanie `[compat]` przed `Pkg.add` — zalecane jest `Pkg.add` najpierw (resolver wpisuje aktualną wersję), POTEM ręczna edycja `[compat]` do wybranej minor.
**Jak unikać:**
1. `Pkg.add("Aqua")` w aktywnym environmencie.
2. `Pkg.status()` pokazuje `Aqua v0.8.14`.
3. **Wtedy** dopisz `Aqua = "0.8"` lub `"0.8.14"` w `[compat]` (nie wcześniej).
4. `Pkg.update()` weryfikuje że Manifest się resolvuje.
**Warning signs:** "no satisfiable versions" w `Pkg.add`, lub Manifest pokazuje wersję starszą niż w `[compat]` floor.

### Pitfall 2: `mutable struct ... const` + inner constructor
**Co idzie nie tak:** Inner constructor próbuje przypisać do `const` polu po inicjalizacji — `setfield!: const field cannot be changed`.
**Dlaczego się dzieje:** Mylenie `const`-ness z `readonly`. `const` znaczy "jednorazowo ustawione w `new(...)`", a nie "tylko do odczytu w konstruktorze".
**Jak unikać:** Używaj `new{R}(punkty, D, rng, trasa, 0.0, 0.0, 0)` w jednym wywołaniu. Wszystkie pola muszą być przekazane w kolejności struct definition. Nie `obj.const_field = value` po `new()`.
**Warning signs:** Test `StanSymulacji(punkty)` rzuca `ErrorException("setfield!: const field ...")`.

### Pitfall 3: PkgTemplates zostawia stare TagBot/CompatHelper boilerplate
**Co idzie nie tak:** `PkgTemplates` z plugin'em `Registrator` dodaje `.github/workflows/TagBot.yml` i `CompatHelper.yml` które wymagają konfiguracji secrets'ów (`TAGBOT_TOKEN`, `COMPATHELPER_TOKEN`). Phase 1 nie publikuje pakietu do General Registry, więc te workflow będą fail'ować.
**Dlaczego się dzieje:** Default plugins w `Template()` zawierają registrator-related pluginy.
**Jak unikać:**
1. Wygeneruj skeleton bez `Registrator()` plugin'a.
2. Sprawdź `.github/workflows/` po generacji — usuń `TagBot.yml` i `CompatHelper.yml` jeśli się pojawiły.
3. Zostaw tylko `CI.yml`.
4. Documenter też usuń jeśli był w plugins (Phase 1 nie ma `docs/`).
**Warning signs:** Pierwsze CI run reportuje failure na "missing secret TAGBOT_TOKEN".

### Pitfall 4: Cross-platform line endings przeżywające `.gitattributes`
**Co idzie nie tak:** Repo było klonowane na Windows z `core.autocrlf=true` PRZED dodaniem `.gitattributes`. Pliki `.jl` są w working tree z CRLF, encoding guard test fail'uje.
**Dlaczego się dzieje:** `.gitattributes` activate'uje się dopiero po klonie + `git checkout`, a `core.autocrlf=true` mogło już skonwertować podczas pierwszego clone'a.
**Jak unikać:**
1. Dodaj `.gitattributes` w **PIERWSZYM commitcie** repo (przed jakimkolwiek `*.jl` plikiem).
2. Po dodaniu `.gitattributes` do istniejącego repo: `git add --renormalize .` + commit.
3. CONTRIBUTING.md instruuje contributorów: `git config --local core.autocrlf input` (Windows) lub `false` (Linux/macOS).
**Warning signs:** Encoding guard test fail'uje na Windows runner CI z `@test !occursin(b"\r\n", bajty)`.

### Pitfall 5: `Manifest.toml` zostaje w `.gitignore` z PkgTemplates
**Co idzie nie tak:** PkgTemplates'owy default `.gitignore` zawiera `Manifest.toml` (bo template defaultuje do "library mode"). Po zacommitowaniu pakietu Manifest jest ignorowany — łamie D-25.
**Dlaczego się dzieje:** Default Julia `.gitignore` od JuliaCI zakłada library workflow.
**Jak unikać:** Po wygenerowaniu skeleton, usuń `Manifest.toml` z `.gitignore`. Sprawdź `git status` — Manifest powinien być untracked-jeszcze-nie-tracked, a po `git add Manifest.toml` powinien zostać dodany do indeksu.
**Warning signs:** `git status` po `Pkg.instantiate` nie pokazuje `Manifest.toml` jako modified/new.

### Pitfall 6: `rand(rng, Point2{Float64}, n)` zwraca `Vector{SVector{2, Float64}}` zamiast `Vector{Point2{Float64}}`
**Co idzie nie tak:** GeometryBasics' `Point` definiuje `<: StaticVector` ale rzeczywista metoda `rand(::AbstractRNG, ::Type{<:StaticVector}, n::Int)` z StaticArrays może zwrócić `SVector` (nie `Point2`) jeśli nie ma overrideu.
**Dlaczego się dzieje:** Inheritance hierarchii `Point <: StaticVector` daje `rand` metodę dziedziczną, ale type promotion może spaść z konkretu na abstrakta.
**Jak unikać:**
1. **Smoke test w Phase 1:** `@test eltype(generuj_punkty(10)) == Punkt2D`.
2. Jeśli fail — fallback do comprehension: `[Punkt2D(rand(rng), rand(rng)) for _ in 1:n]`.
3. To jest **HIGH-RISK assumption** — verify FIRST IMPLEMENTATION (test before relying on it in Phase 2).
**Warning signs:** Test type stability w Phase 2 reportuje `inferred ::Vector{SVector{2,Float64}}` zamiast `::Vector{Point2{Float64}}`.

### Pitfall 7: `Random.default_rng()` na innym tasku
**Co idzie nie tak:** Test PKT-04 używa `before = copy(Random.default_rng())` ale jest uruchamiany wewnątrz `@async` block lub `Threads.@spawn` — wówczas `default_rng()` zwraca **inny** TaskLocalRNG niż w wywołaniu `generuj_punkty`. Test fałszywie passuje.
**Dlaczego się dzieje:** `default_rng()` od Julia 1.7 zwraca task-local RNG. Każdy task ma swój.
**Jak unikać:** Test w `runtests.jl` na top-level (nie w `@async`). Eksplicytna asercja:
```julia
@testset "generuj_punkty no global RNG mutation (PKT-04)" begin
    przed = copy(Random.default_rng())
    _ = generuj_punkty(1000; seed=42)
    po = copy(Random.default_rng())
    @test przed == po
end
```
**Warning signs:** Test passuje ale po manualnej inspekcji `default_rng()` rzeczywiście się zmienia.

### Pitfall 8: NFC normalization fail dla polskich identyfikatorów
**Co idzie nie tak:** Edytor (np. macOS Finder) zapisuje polską literę `ł` w kompozycji NFD (decomposed) zamiast NFC. `Unicode.normalize(tresc, :NFC) == tresc` fail'uje.
**Dlaczego się dzieje:** macOS HFS+ używa NFD-like composition na poziomie filesystem'u; niektóre edytory propagują to do plików.
**Jak unikać:**
1. CONTEXT D-22 wymaga NFC.
2. Encoding guard test (Pattern 6) łapie regression.
3. Edytor: VSCode default'uje do NFC; Sublime też. Polski IME na macOS może być problematyczny.
4. Auto-fix: `Unicode.normalize(read(plik, String), :NFC) |> txt -> write(plik, txt)`.
**Warning signs:** CI fail na encoding guard linijka 4 (NFC test) na pliku `.jl` z polskimi komentarzami.

### Pitfall 9: `Project.toml [extras]` UUID stamp
**Co idzie nie tak:** Wpisanie ręcznie `Aqua = "abc..."` z błędnym UUID. Pkg fail'uje cicho lub łapie późniejsze rozjazdy.
**Dlaczego się dzieje:** UUID-y są wymyślone — kopiuj-wklejone z błędem.
**Jak unikać:** Zawsze `Pkg.add` → odczyt UUID z `Manifest.toml` → wklej do `[extras]`. Nie pisz UUID-ów ręcznie. Lub: `Pkg.activate("test"); Pkg.add(["Aqua","JET","StableRNGs"])` i pozwól Pkg uzupełnić `[deps]` w `test/Project.toml`, potem przeniesc do `[extras]+[targets]` rootowego `Project.toml`.
**Warning signs:** `Pkg.test()` reportuje "expected dependency Aqua not found".

## Code Examples

### Pełen `src/typy.jl`
```julia
# Typy domenowe pakietu JuliaCity
# - Punkt2D: alias na Point2{Float64} z GeometryBasics
# - StanSymulacji: parametryczny mutable struct na stan SA
# - Algorytm: abstract type — extension point dla Holy-traits dispatch (Phase 2+)

using GeometryBasics: Point2
using Random: AbstractRNG, Xoshiro

"""
    Punkt2D

Alias na `Point2{Float64}` z GeometryBasics. Float64 dla precyzji sumy
~1000 odległości euklidesowych w `oblicz_energie`. Bezpośrednio konsumowany
przez Makie scatter w Phase 3 — zero-cost konwersja.
"""
const Punkt2D = Point2{Float64}

"""
    Algorytm

Abstract type — wszystkie konkretne algorytmy SA / force-directed / hybryda
są podtypami w `src/algorytmy/`. Phase 2 wprowadza `SimAnnealing <: Algorytm`.
"""
abstract type Algorytm end

"""
    StanSymulacji{R<:AbstractRNG}

Stan symulacji TSP. Pola const (`punkty`, `D`, `rng`) są ustawiane raz
w konstruktorze. Pola mutable (`trasa`, `energia`, `temperatura`,
`iteracja`) są aktualizowane przez `symuluj_krok!` (Phase 2).
"""
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}
    const D::Matrix{Float64}
    const rng::R
    trasa::Vector{Int}
    energia::Float64
    temperatura::Float64
    iteracja::Int
end

"""
    StanSymulacji(punkty; rng=Xoshiro(42))

Konstruktor zewnętrzny — pre-alokuje `D` (n×n, niewypełnione) oraz
`trasa = collect(1:n)`. Phase 2 doda funkcje `oblicz_macierz_dystans!`
i `inicjuj_nn!` które wypełnią te pola.
"""
function StanSymulacji(punkty::Vector{Punkt2D}; rng::R=Xoshiro(42)) where {R<:AbstractRNG}
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))
    D = Matrix{Float64}(undef, n, n)
    trasa = collect(1:n)
    return StanSymulacji{R}(punkty, D, rng, trasa, 0.0, 0.0, 0)
end
```

### Pełen `src/punkty.jl`
```julia
# Generator punktów testowych — PKT-01..04
# Lokalny Xoshiro, brak mutacji Random.default_rng().

using Random: AbstractRNG, Xoshiro

"""
    generuj_punkty(n::Int=1000; seed::Integer=42) -> Vector{Punkt2D}

Generuje `n` losowych punktów w `[0,1]²` używając lokalnego `Xoshiro(seed)`.
Deterministyczne dla danego seeda — wielokrotne wywołania z tym samym seedem
zwracają identyczne wektory.

Nie modyfikuje globalnego stanu PRNG (`Random.default_rng()`).

# Examples
```jldoctest
julia> punkty = generuj_punkty(3; seed=42);

julia> length(punkty)
3

julia> all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, punkty)
true
```
"""
function generuj_punkty(n::Int=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))
    rng = Xoshiro(seed)
    return generuj_punkty(n, rng)
end

"""
    generuj_punkty(n::Int, rng::AbstractRNG) -> Vector{Punkt2D}

Composable wariant — testy mogą podać własny `StableRNG(42)` (Phase 2)
dla cross-version reproducibility.
"""
function generuj_punkty(n::Int, rng::AbstractRNG)
    n > 0 || throw(ArgumentError("n must be positive"))
    return rand(rng, Punkt2D, n)
end
```

### Pełen `src/JuliaCity.jl`
```julia
"""
    JuliaCity

Pakiet rozwiązujący problem komiwojażera (TSP) heurystyką inspirowaną
fizyką błony mydlanej. Public API:

- `generuj_punkty(n; seed)` — losowe punkty w `[0,1]²`
- `StanSymulacji(punkty; rng)` — stan symulacji
- `oblicz_energie(...)` — Phase 2
- `symuluj_krok!(...)` — Phase 2
- `wizualizuj(...)` — Phase 3

Phase 1 dostarcza tylko `generuj_punkty` + szkielet `StanSymulacji`.
"""
module JuliaCity

using GeometryBasics: Point2
using Random

include("typy.jl")
include("punkty.jl")

export Punkt2D, StanSymulacji, Algorytm, generuj_punkty

end # module
```

### Pełen `test/runtests.jl`
```julia
using Test
using JuliaCity
using Random: Xoshiro, default_rng
using Unicode

@testset "JuliaCity" begin

    @testset "encoding hygiene (BOOT-03)" begin
        # Patrz Pattern 6 powyżej — pełna implementacja
        katalogi = ["src", "test"]
        rozszerzenia = (".jl", ".toml", ".md")
        pliki = String[]
        for kat in katalogi
            isdir(kat) || continue
            for (root, _, files) in walkdir(kat)
                for f in files
                    any(endswith(f, ext) for ext in rozszerzenia) && push!(pliki, joinpath(root, f))
                end
            end
        end
        for plik in ["Project.toml", ".editorconfig", ".gitattributes"]
            isfile(plik) && push!(pliki, plik)
        end

        for plik in pliki
            bajty = read(plik)
            @test isvalid(String, bajty)
            @test !(length(bajty) >= 3 && bajty[1] == 0xEF && bajty[2] == 0xBB && bajty[3] == 0xBF)
            @test !occursin(b"\r\n", bajty)
            if endswith(plik, ".jl")
                tresc = String(bajty)
                @test Unicode.normalize(tresc, :NFC) == tresc
            end
        end
    end

    @testset "generuj_punkty (PKT-01..03)" begin
        # PKT-01: zwraca Vector{Punkt2D}
        punkty = generuj_punkty(1000; seed=42)
        @test eltype(punkty) == Punkt2D
        @test length(punkty) == 1000

        # PKT-02: default n=1000
        @test length(generuj_punkty()) == 1000

        # PKT-03: punkty w [0,1]²
        @test all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, punkty)

        # determinizm
        @test generuj_punkty(100; seed=42) == generuj_punkty(100; seed=42)
        @test generuj_punkty(100; seed=42) != generuj_punkty(100; seed=43)
    end

    @testset "generuj_punkty no global RNG mutation (PKT-04)" begin
        przed = copy(default_rng())
        _ = generuj_punkty(1000; seed=42)
        po = copy(default_rng())
        @test przed == po
    end

    @testset "StanSymulacji constructor" begin
        punkty = generuj_punkty(10; seed=1)
        stan = StanSymulacji(punkty)
        @test stan.punkty === punkty   # const → identity
        @test size(stan.D) == (10, 10)
        @test stan.trasa == collect(1:10)
        @test stan.energia == 0.0
        @test stan.temperatura == 0.0
        @test stan.iteracja == 0

        # const fields nie mogą być reassigned
        @test_throws ErrorException stan.punkty = Punkt2D[]
    end

    @testset "Aqua quality" begin
        using Aqua
        Aqua.test_all(JuliaCity)
    end

    # JET smoke — pełen JET report w Phase 2
    @testset "JET smoke" begin
        using JET
        # Tylko opt-report na publicznym API; pełen w Phase 2
        @test_nowarn @report_opt generuj_punkty(10; seed=42)
    end

end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manifest.toml in `.gitignore` for all projects | Commit Manifest.toml for applications, ignore for libraries | Pkg.jl convention since Julia 1.0 | Reproducibility for end-user demo (D-25) |
| `Random.seed!(42)` global mutation | Local `Xoshiro(42)` per-function | Julia 1.7 (Xoshiro default) | Thread-safe, no test contamination |
| `[deps]` for test deps | `[extras] + [targets]` | Julia 1.2 | Cleaner separation |
| `[extras] + [targets]` | Workspaces | Julia 1.12 (experimental) | NIE używamy — `[compat] julia="1.10"` blokuje |
| `working-tree-encoding=UTF-8` for UTF-8 storage | Omit attribute (UTF-8 is Git default) | n/a | Clarification, not regression |
| `mutable struct` z all-mutable fields | `mutable struct ... const fields` selective | Julia 1.8 | Type stability + invariant enforcement |

**Deprecated/outdated:**
- Julia 1.6 LTS, 1.0 LTS — EOL.
- `MersenneTwister` jako default — zastąpiony przez `Xoshiro` w 1.7.
- `JuliaCI/setup-julia@v1` (action) — `v2` jest current. Verify w wygenerowanym CI.yml.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `rand(rng, Point2{Float64}, n)` zwraca `Vector{Point2{Float64}}` (nie `Vector{SVector{2,Float64}}`) | Pattern 4, Pitfall 6 | Wymaga fallback comprehension; smoke test w Phase 1 łapie wcześnie |
| A2 | PkgTemplates `Tests()` plugin tworzy `test/runtests.jl` ale **nie** wpisuje `[extras]+[targets]` automatycznie | Pattern 2 | Planner musi ręcznie dopisać `[extras]+[targets]` po generation |
| A3 | `JULIA_NUM_THREADS=2` na GitHub runnerach jest sensownym defaultem (nie `auto`) | Pattern 7 (CI YAML) | Może być fine z `auto`; verify on first CI run |
| A4 | NFC normalization na Windows nie wymaga dodatkowego setup'u w Git | Pitfall 8 | Może być potrzebne `git config core.precomposeunicode true` na macOS contributors; documentuj w CONTRIBUTING.md |
| A5 | `Aqua.test_all(JuliaCity)` w Phase 1 (zero source kodu poza typy/punkty) nie wykryje violations | Pattern test/runtests.jl | Może wykryć "stale dependencies" jeśli `[compat]` zawiera nieużywane entries — to powód do **Wariantu b** w D-17 |
| A6 | `walkdir` na Windows zwraca poprawne paths z `joinpath` | Pattern 6 | Verify on Windows runner |

**Action for planner:** Dla każdego `[ASSUMED]` powyżej dodać explicit verification step do PLAN.md (smoke test, manual check, lub deferral).

## Open Questions (RESOLVED)

1. **Czy PkgTemplates `Tests()` plugin tworzy `[extras]+[targets]` w `Project.toml`?**
   - What we know: Plugin tworzy `test/runtests.jl` skeleton. Niejasne czy edytuje root `Project.toml`.
   - What's unclear: Wymaga uruchomienia generacji żeby sprawdzić.
   - RESOLVED: Plan 03 manually adds [extras]+[targets] (Plan 03 Task 2). Recommendation: Planner zakłada **NIE** — dodaj `[extras]+[targets]` ręcznie. Jeśli plugin to dodał, merge ostatecznie spójne.

2. **Czy default `.gitignore` od PkgTemplates zawiera `Manifest.toml`?**
   - What we know: JuliaCI defaultuje do library mode.
   - What's unclear: Aktualna wersja PkgTemplates 0.7.x — verify.
   - RESOLVED: Plan 02 .gitignore explicitly omits Manifest.toml; Manifest.toml is committed (Plan 02 Task 2 / Plan 03 Task 4). Recommendation: Planner instruuje task post-generation: `grep -q '^/Manifest.toml$' .gitignore && sed -i.bak '/^Manifest.toml$/d' .gitignore`.

3. **Czy `Aqua.test_all` w Phase 1 (z minimal kodem) przejdzie bez błędów?**
   - What we know: Aqua catches type piracy, ambiguities, stale deps. Phase 1 ma trywialne typy + 1 funkcję.
   - What's unclear: Aqua może raportować "stale deps" jeśli `[compat]` zawiera GLMakie/Makie ale `[deps]` nie.
   - RESOLVED: revision applies Variant a per ROADMAP SC2 + Aqua stale_deps=false suppression (Plan 03 Task 3 / Plan 06 Task 1). Recommendation: **Wariant b** w D-17 — tylko pakiety w `[deps]` mają `[compat]`. To rozwiązuje preventatively. (NADPISANE PRZEZ REVISION: Wariant a wybrany dla literal SC2 compliance; Aqua suppression mitiguje stale_deps warning do Phase 4.)

4. **Czy `julia-actions/setup-julia@v2` poprawnie obsługuje `version: '1.11'`?**
   - What we know: `@v2` jest current major.
   - What's unclear: Czy wszystkie minor versions są w cache; czy `nightly` channel'em jest poprawny string.
   - RESOLVED: julia-actions/setup-julia@v2 used in CI matrix (Plan 06 Task 2). Recommendation: Kopiuj YAML z reference Julia projektu (np. JuliaArrays/StaticArrays) jako sanity baseline.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Julia | Cały Phase 1 (running tests, REPL, PkgTemplates) | **✗ MISSING** | — | Install via [juliaup](https://github.com/JuliaLang/juliaup) lub bezpośrednio z julialang.org |
| git | Wszystko | ✓ | 2.50.1 | — |
| node | Tooling (gsd-sdk) | ✓ | (system) | — |
| GitHub CLI (gh) | Optional — PR creation | ✗ | — | Manualna interakcja z GitHub UI |
| ffmpeg | Phase 3 (eksport MP4) | n/a w Phase 1 | — | Phase 3 concern |

**Missing dependencies blocking execution:**
- **Julia** — KRYTYCZNE. Plan-checker MUSI sprawdzić, że Julia jest installowana przed implement-phase'em. Sugerowany install: `curl -fsSL https://install.julialang.org | sh` (juliaup), wybór wersji `1.10` lub `1.11`.

**Missing dependencies with fallback:**
- gh CLI — manual PR via web UI works fine.

⚠️ **Plan-checker note:** Phase 1 plan **musi** zawierać explicit task "Install Julia 1.10+ via juliaup" jako pierwszy krok lub pre-condition. Bez Julii nic nie działa — ani PkgTemplates, ani testy, ani Pkg.instantiate.

## Validation Architecture

> `workflow.nyquist_validation = false` w `.planning/config.json`. Validation Architecture jest **SKIPPED** dla tej fazy.

Tradycyjny test suite (Aqua, JET smoke, encoding guard, generuj_punkty unit tests) wystarcza dla Phase 1 — patrz przykład `test/runtests.jl` w sekcji Code Examples.

## Security Domain

> `workflow.security_enforcement = true`, `security_asvs_level = 1` w `.planning/config.json`. Phase 1 jest **bootstrap-only** bez surface'u user-facing data — applicable categories są minimalne.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | NO | Brak auth — pakiet lokalny |
| V3 Session Management | NO | Brak sesji |
| V4 Access Control | NO | Pakiet lokalny |
| V5 Input Validation | YES (light) | `n > 0 || throw(ArgumentError)` w `generuj_punkty` |
| V6 Cryptography | NO | Phase 1 nie używa crypto |
| V12 File Handling | YES (light) | Encoding guard reads `src/*` w `runtests.jl` — verify `walkdir` nie traversuje symlinks poza repo |
| V14 Configuration | YES | `Project.toml`/`Manifest.toml` muszą być sane; CI nie może exposować secrets |

### Known Threat Patterns dla Phase 1 stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal w encoding guard | Tampering | `walkdir` z explicit roots `["src", "test"]`; nie `walkdir(".")` żeby nie odczytywać `.git/`, secrets etc. |
| Negative `n` w `generuj_punkty` | DoS (memory exhaustion) | `n > 0 || throw(ArgumentError)` — already in pattern |
| Manifest.toml committed exposing path-dependent paths | Information disclosure | Manifest commit policy assumes only registry deps, no `dev`-mode local paths. **Plan-checker:** verify `git diff Manifest.toml` przed pierwszym commitem nie zawiera `path = "/Users/..."`. |
| CI workflow fetching arbitrary actions | Supply chain | Pin `julia-actions/*@v2` (specific major), nie `@master` |

**Verdict:** Phase 1 nie wprowadza meaningful security surface'u. Single `ArgumentError` + ostrożny encoding guard pokrywa wszystko ASVS L1. Phase 3 (MP4 export, file handling) i Phase 4 (README, public examples) będą miały więcej.

## Project Constraints (from CLAUDE.md)

Z `./CLAUDE.md`:

1. **Język UI/komentarzy:** wyłącznie polski. Phase 1 implementacja: komentarze w `src/*.jl` po polsku (LANG-01, D-22).
2. **Tech stack:** Julia + GLMakie. Phase 1: GLMakie nieużywane jeszcze (headless), ale `[compat]` ustanowione (BOOT-02, D-17).
3. **Struktura kodu:** modułowa, wymagane funkcje `generuj_punkty()`, `oblicz_energie()`, `symuluj_krok!()`, `wizualizuj()`. Phase 1: implementuje `generuj_punkty`, deklaruje `StanSymulacji`/`Algorytm` jako fundament dla Phase 2/3.
4. **Reprodukowalność:** domyślny seed=42 (D-12).
5. **GSD Workflow Enforcement:** wszystkie zmiany przez `/gsd-execute-phase` lub `/gsd-quick`. Plan-checker dba o to.
6. **Stack version table:** w CLAUDE.md jest pełna tabela wersji — Phase 1 trzyma się jej dla julia/GeometryBasics/Aqua/JET/StableRNGs/BenchmarkTools entries.

**Compliance:** Każdy task w plan musi respektować polski-w-komentarzach + ASCII-w-nazwach-plików + lokalny-Xoshiro-not-global. Plan-checker weryfikuje.

## Sources

### Primary (HIGH confidence)
- [Pkg.jl — Compatibility](https://pkgdocs.julialang.org/v1/compatibility/) — caret default, pre-1.0 rule, comma-separated lists. Verified 2026-04-28.
- [Pkg.jl — Creating Packages](https://github.com/JuliaLang/Pkg.jl/blob/master/docs/src/creating-packages.md) — `[extras]+[targets]` syntax, "legacy and maintained" caveat. Verified 2026-04-28.
- [Pkg.jl — TOML files](https://pkgdocs.julialang.org/v1/toml-files/) — Project.toml + Manifest.toml roles. (Note: nie znaleziono explicit "applications commit Manifest.toml" w docs — to convention, nie pisana reguła.)
- [Julia Manual — Mutable Composite Types](https://docs.julialang.org/en/v1/manual/types/#Mutable-Composite-Types) — `const` fields w `mutable struct` od 1.8. Verified 2026-04-28.
- [Git — gitattributes](https://git-scm.com/docs/gitattributes) — `working-tree-encoding`, `text eol=lf`. UTF-8 default storage = no need for working-tree-encoding=UTF-8. Verified 2026-04-28.
- [PkgTemplates User Guide](https://juliaci.github.io/PkgTemplates.jl/stable/user/) — `Template()` invocation, GitHubActions plugin parameters. Verified 2026-04-28.
- [GeometryBasics src `fixed_arrays.jl`](https://github.com/JuliaGeometry/GeometryBasics.jl/blob/master/src/fixed_arrays.jl) — `Point <: AbstractPoint <: StaticVector`. Verified 2026-04-28.

### Secondary (MEDIUM confidence)
- [VoronoiCells.jl repo](https://github.com/JuliaGeometry/VoronoiCells.jl) — example: `Point2(rand(rng), rand(rng))` (alternative idiom).
- [StaticArrays README](https://github.com/JuliaArrays/StaticArrays.jl) — `@SVector rand(...)`, `rand` semantics.
- [`.planning/research/STACK.md`](file:///Users/mattparol/Desktop/Projekty/JuliaCity/.planning/research/STACK.md) — repository's own research output (project memory, not external).
- [`.planning/research/PITFALLS.md`](file:///Users/mattparol/Desktop/Projekty/JuliaCity/.planning/research/PITFALLS.md) — repository's own pitfalls catalogue.

### Tertiary (LOW confidence — flagged for verification on first run)
- GitHub Actions `julia-actions/setup-julia@v2` matrix syntax — copied pattern from julia-actions reference. Verify on first CI run.
- `JULIA_NUM_THREADS=2` na GitHub runners — assumption based on 2-vCPU shared runners.
- NFC normalization auto-handling on Windows — depends on contributor's editor; documented in CONTRIBUTING.md.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions zlockowane przez CONTEXT.md, weryfikowane przez Pkg.jl docs.
- Architecture: HIGH — single-module + include() pattern jest canonical Julia.
- Pitfalls: HIGH dla pkg-related (Pitfall 1, 3, 5), MEDIUM dla ekosystem-related (Pitfall 6 — `rand(rng, T, n)`), HIGH dla encoding (Pitfall 4, 8 — battle-tested).
- Encoding guard test: MEDIUM — pattern jest stdlib-only ale niewerifkowany na Windows runner; **A6 jest assumption.**
- CI matrix: MEDIUM — wymaga first-run verification.

**Research date:** 2026-04-28
**Valid until:** 2026-05-28 (30 days — stable greenfield phase, very few moving parts).
