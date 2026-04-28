# Phase 1: Bootstrap, Core Types & Points - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 1-bootstrap-core-types-points
**Areas discussed:** Reprezentacja Punkt2D, Zakres StanSymulacji w Phase 1, API generuj_punkty, Skeleton & CI

---

## Reprezentacja Punkt2D

| Option | Description | Selected |
|--------|-------------|----------|
| `const Punkt2D = Point2{Float64}` | Type alias dla GeometryBasics.Point2{Float64}. Pełna precyzja Float64 dla sumy odległości euklidesowych; zerowy koszt konwersji do Makie. | ✓ |
| `const Punkt2D = Point2f` | Float32 native dla Makie GPU; mniej precyzji w sumach energii. | |
| `struct Punkt2D` własny | Domain type, polski feel; wymaga ręcznej konwersji do Makie. | |
| `SVector{2, Float64}` | Najszybsze CPU dla wektorów; dodaje StaticArrays dep. | |

**User's choice:** `const Punkt2D = Point2{Float64}` (Recommended).

**Follow-up:** Decyzja o eksporcie i depie GeometryBasics.

| Option | Description | Selected |
|--------|-------------|----------|
| `export Punkt2D` + GeometryBasics jako bezpośredni dep | Czyste, brak transitive zależności od GLMakie w Phase 1. | ✓ |
| Tylko transitive przez Makie w Phase 3 | Phase 1 nie ma jeszcze Makie — rezultat niespójny. | |
| Bez exportu, dostęp przez `JuliaCity.Punkt2D` | Niezgodne z rolą `Punkt2D` w publicznym API. | |

**User's choice:** `export Punkt2D + GeometryBasics jako bezpośredni dep` (Recommended).

**Follow-up:** Helpery dostępu do współrzędnych.

| Option | Description | Selected |
|--------|-------------|----------|
| Surowe `.x` / `.y` / `p[1]` / `p[2]` | Native API GeometryBasics. JET-clean. | ✓ |
| `wsp_x(p)` / `wsp_y(p)` | Polskie helpery, ryzyko narzutu dispatch. | |
| Bez aliasu Punkt2D — używamy Point2 wprost | Kompromituje polski feel API. | |

**User's choice:** Surowe `.x`/`.y` (Recommended).

---

## Zakres StanSymulacji w Phase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Pełen komplet pól pod SA już w Phase 1 | Phase 2 tylko wypełnia wartości; zero refaktoru konstruktora. | ✓ |
| Minimum + TODO pól | YAGNI, prostszy test Phase 1; ale refactor konstruktora w Phase 2. | |
| Pełen komplet bez `D` | Distance matrix decision deferred do Phase 2. | |

**User's choice:** Pełen komplet (Recommended).

**Follow-up:** Distance matrix open question (STATE.md).

| Option | Description | Selected |
|--------|-------------|----------|
| Precompute `D::Matrix{Float64}` ~8 MB | PITFALLS Pitfall 10 confirmed; O(1) lookup. | ✓ |
| `D::Union{Nothing, Matrix{Float64}}` lazy | Łamie type stability. | |
| Pole `D::Matrix{Float64}` puste w Phase 1 | Type-stable intermediate; mniej elegancki. | |
| Defer całość | Cofnięcie do "bez D" — odrzucone. | |

**User's choice:** Precompute (Recommended). Open Question z STATE.md domknięta.

**Follow-up:** Mutability shape.

| Option | Description | Selected |
|--------|-------------|----------|
| `mutable struct StanSymulacji` | Czyste re-assignment skalarów `stan.energia = ...` etc. | ✓ |
| `struct` (immutable) + `Ref{Float64}` | Idiomatyczne ale Ref noise. | |
| `mutable struct` + `const` na niezmienialnych polach | Pełna kontrola, wymaga julia ≥ 1.8 (mamy). | |

**User's choice:** `mutable struct` (Recommended). Wybór z follow-up: `const` używamy na (punkty, D, rng) — D-05/D-06 łączy wszystkie poprzednie.

**Follow-up:** Czy konstruktor liczy NN/D w Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Zero-state w Phase 1 | Konstruktor pre-alokuje, NN/D-fill w Phase 2. | ✓ |
| Pełna inicjalizacja w Phase 1 | Wymaga `oblicz_energie` + `trasa_nn` z Phase 2 — wykracza poza scope. | |
| Lekka inicjalizacja — D wypełniona, brak NN | Rozmywa granicę faz. | |

**User's choice:** Zero-state (Recommended).

---

## API generuj_punkty

| Option | Description | Selected |
|--------|-------------|----------|
| Dwie metody: seed-based + rng-based | Friendly default + composability dla testów. | ✓ |
| Tylko seed-based | Najprostsze, dosłownie zgodne z PKT-01. | |
| Tylko rng-based | Najczystsze idiomatycznie ale niezgodne z PKT-01 dosłownie. | |
| Pojedyncza sygnatura: oba kwargi | Konflikt seed vs rng. | |

**User's choice:** Dwie metody (Recommended).

**Follow-up:** Interop ze StanSymulacji.

| Option | Description | Selected |
|--------|-------------|----------|
| Osobne funkcje, składane jawnie | Czyste rozdzielenie; user widzi krok po kroku. | ✓ |
| `StanSymulacji(n::Int; seed)` constructor | Wiąże StanSymulacji z PRNG — mniej testowalne. | |
| Oba | Convenience constructor + osobne funkcje — kompleks API. | |

**User's choice:** Osobne funkcje (Recommended).

**Follow-up:** Implementacja sample'owania.

| Option | Description | Selected |
|--------|-------------|----------|
| `rand(rng, Punkt2D, n)` | Wbudowane wsparcie GeometryBasics; jeden call. | ✓ |
| Comprehension `[Punkt2D(rand(rng), rand(rng)) for _ in 1:n]` | Eksplicit, dwa rand calls per punkt. | |
| `reinterpret(Punkt2D, rand(rng, 2n))` | Najszybsze, ale kruche jeśli layout się zmieni. | |

**User's choice:** `rand(rng, Punkt2D, n)` (Recommended).

---

## Skeleton & CI

| Option | Description | Selected |
|--------|-------------|----------|
| PkgTemplates lokalnie + cleanup | Standardowe konwencje + wymagana matryca CI. | ✓ |
| Ręcznie | Lean ale więcej plan-time; pełna kontrola. | |
| PkgTemplates jako runtime tool | Tylko dokumentacyjne. | |

**User's choice:** PkgTemplates lokalnie (Recommended).

**Follow-up:** CI matrix scope.

| Option | Description | Selected |
|--------|-------------|----------|
| Pełna matryca: julia 1.10/1.11/nightly × ubuntu/windows/macos | Reprodukcja modernjuliaworkflows; łapie encoding bugs. | ✓ |
| Minimum: julia stable × ubuntu | Najszybsze; brak Windows/macos coverage. | |
| Stub workflow, matryca w Phase 5 | Nieklarowne kto pilnuje encodingu mid-roadmap. | |

**User's choice:** Pełna matryca (Recommended).

**Follow-up:** Encoding-validation guard.

| Option | Description | Selected |
|--------|-------------|----------|
| Test w `runtests.jl` (UTF-8/no-BOM/NFC) | Konkretny @testset; działa lokalnie i CI. | ✓ |
| `scripts/check_encoding.jl` standalone | Bardziej separowane ale local dev może pominąć. | |
| Tylko `.editorconfig` + `.gitattributes` | CI łapie post-factum. | |
| Pre-commit hook (chardet/file) | Zewnętrzne deps; odradzane dla pakietu Julia. | |

**User's choice:** Test w `runtests.jl` (Recommended).

**Follow-up:** Algorytm extension point w Phase 1.

| Option | Description | Selected |
|--------|-------------|----------|
| `abstract type Algorytm end` TAK, `SimAnnealing` NIE | Zgodne z traceability ALG-01 → Phase 2. | ✓ |
| Oba w Phase 1 | Łamie traceability requirement → faza. | |
| Żadnego | Mniej koherentne — StanSymulacji ma `iteracja` ale brak hierarchii. | |

**User's choice:** Tylko abstract type (Recommended).

---

## Claude's Discretion

- Dokładny układ `src/JuliaCity.jl` (kolejność `include`, kolejność exportów).
- Czy `Parametry` dochodzi w Phase 1 jako pure-data stub czy w Phase 2 (sugestia: planner decyduje, prawdopodobnie w Phase 2).
- Czy `LICENSE` (MIT) jest w Phase 1 — domyślnie tak (PkgTemplates plugin).
- Dokładna treść `CONTRIBUTING.md` — sugestia: lekki stub z core conventions.
- Forma `.gitattributes` (linia po linii vs glob patterns).

## Deferred Ideas

- **`Parametry` struct shape** — Phase 2 (ALG-related fields).
- **Documenter.jl + `docs/` site** — v1.1+ (poza scope v1, README po polsku starczy).
- **JuliaFormatter / pre-commit hooks** — encoding test w runtests.jl wystarczy dla v1.
- **Convenience constructor `StanSymulacji(n::Int; seed)`** — Phase 4 jeśli `examples/` tego wymaga.
- **CairoMakie fallback dla headless CI** — Phase 3+ (Phase 1 jest headless natively).
- **`scripts/check_encoding.jl` standalone** — Phase 4 jeśli pre-commit hooks się pojawią.

### Reviewed Todos (not folded into Phase 1 scope)

- "Confirm Manifest.toml is committed" (STATE.md TODO) — **rozwiązane w D-25**, do oznaczenia `done` po Phase 1 verify.
- "Add encoding-validation CI guard test" (STATE.md TODO) — **fold do D-21**, do oznaczenia `done` po Phase 1 verify.
- "Document Polish-typography convention" (STATE.md TODO) — **deferred do Phase 4** (user-facing strings concern).
