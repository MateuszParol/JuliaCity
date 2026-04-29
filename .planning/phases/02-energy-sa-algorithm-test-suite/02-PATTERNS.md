# Phase 2: Energy, SA Algorithm & Test Suite — Pattern Map

**Mapped:** 2026-04-29
**Files analyzed:** 11 (5 new src, 3 new test, 3 modified)
**Analogs found:** 11 / 11 (100% — all new files have a Phase 1 analog in the same repo)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/energia.jl` (NEW) | service (pure compute) | transform | `src/punkty.jl` | role-match (pure compute + 2-method idiom + thread-safe construction) |
| `src/algorytmy/simulowane_wyzarzanie.jl` (NEW) | service (mutating algorithm) | event-driven (per-step) | `src/typy.jl` (struct + ctor) **and** `src/punkty.jl` (`!` mutating discipline) | role-match (struct decl + bang-function idiom; no exact analog because Phase 1 has no algorithm yet) |
| `src/baselines.jl` (NEW) | service (NN init) | transform + mutate | `src/punkty.jl` | role-match (pure entry point + composable variant) |
| `test/test_energia.jl` (NEW) | test | unit | `test/runtests.jl` `@testset "generuj_punkty (PKT-…)"` block (lines 89–113) | exact (testset structure, fixture pattern, `@test_throws`, NFC-asserts) |
| `test/test_symulacja.jl` (NEW) | test | unit + integ | `test/runtests.jl` `@testset "StanSymulacji konstruktor"` block (lines 128–156) | exact (testset structure, mutation semantics test) |
| `test/test_baselines.jl` (NEW) | test | unit + integ | `test/runtests.jl` `@testset "JuliaCity"` outermost (lines 16–195) | role-match (orchestration of multiple sub-testsets) |
| `src/JuliaCity.jl` (MOD) | config (module entry) | wiring | `src/JuliaCity.jl` (existing) | exact (extend in place) |
| `src/typy.jl` (MOD) | model (types) | structural | `src/typy.jl` (existing `StanSymulacji` block) | exact (add `Parametry` next to `StanSymulacji`) |
| `test/runtests.jl` (MOD) | test (orchestrator) | wiring | `test/runtests.jl` (existing) | exact (extend in place) |
| `Project.toml` (MOD) | config (deps) | structural | `Project.toml` (existing) | exact (add to `[deps]` + `[compat]` + `[extras]` + `[targets]`) |

---

## Pattern Assignments

### `src/energia.jl` (service / transform)

**Analog:** `src/punkty.jl`

**File-header / docstring convention** (analog lines 1–4):
```julia
# Generator losowych punktów testowych — pokrywa REQ PKT-01..04.
# Lokalny Xoshiro, brak mutacji Random.default_rng() (PKT-04, D-14).
# Dwie metody (D-11) — friendly default + composable.
```
Pattern: top-of-file polski hash-comment naming **REQ-IDs covered** + **D-decisions** + **convention rationale**. Mirror in `src/energia.jl`:
```julia
# Energia trasy + macierz dystansów + delta 2-opt + kalibracja T0.
# Pokrywa REQ ENE-01..05. Threadowane przez Threads.@threads :static + ChunkSplitters
# (D-11). Hot path (delta_energii) jest single-threaded i O(1) (D-08).
```

**Two-method idiom (Phase 1 D-11 → Phase 2 D-10)** (analog lines 29–54):
```julia
function generuj_punkty(n::Int=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))   # asercja po angielsku (LANG-04)
    rng = Xoshiro(seed)
    return generuj_punkty(n, rng)
end

function generuj_punkty(n::Int, rng::AbstractRNG)
    n > 0 || throw(ArgumentError("n must be positive"))
    return rand(rng, Punkt2D, n)
end
```
Mirror for `oblicz_energie`:
```julia
# Friendly 2-arg (1 alloc OK per ENE-03 < 4096 B) — buduje lokalny D + bufor.
function oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})::Float64
    # ... lokalna macierz D + bufor + delegacja
    return oblicz_energie(D, trasa, bufor)
end

# Hot-path 3-arg (zero-alloc po rozgrzewce z pre-alokowanym bufor).
function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64
    # ... ChunkSplitters + @threads :static
end
```

**Docstring template** (analog lines 5–28 + 35–45):
- 1 linia signature line `function_name(args) -> ReturnType`
- Polish prose paragraph explaining purpose + REQ ID
- `# Examples` jldoctest block dla pure functions (skopiuj z `generuj_punkty`)
- `# Argumenty` lista dla composable wariantu

**English internal asserts** (analog line 30):
```julia
n > 0 || throw(ArgumentError("n must be positive"))
```
Mirror:
```julia
@assert 1 <= i < j <= n "i, j out of range"             # delta_energii
@assert size(stan.D) == (n, n) "D dimension mismatch"   # oblicz_macierz_dystans!
@assert !isempty(worsening) "no worsening moves sampled" # kalibruj_T0
```

**What to deviate:** `oblicz_energie` MUST use `Threads.@threads :static` + `ChunkSplitters.chunks(1:n; n=nthreads())` + `enumerate` (RESEARCH Pattern 1, ~lines 156–177). `delta_energii` is **explicitly NOT threaded** (D-08 — hot path single-threaded O(1)). `kalibruj_T0` uses `Statistics.std` — add `using Statistics` at top of file (or in `JuliaCity.jl`).

**Pitfalls specific to this file:**
- **D-11 boxing trap:** Use `bufor[chunk_idx] = s` accumulator inside `@threads`, never re-assign a captured scalar (PITFALLS Pitfall 2).
- **`Statistics` is stdlib** — must be added to `[deps]` (no `[compat]` entry, just `[deps]`). RESEARCH §Wave 0 Gaps line 700.
- **NFC normalization** — file is `.jl`; encoding-guard test (Phase 1 D-21) will assert NFC. Use IDE that writes NFC (VSCode default OK; Notepad emits NFD on macOS).
- **Filename is ASCII** (Phase 1 D-19, BOOT-04): `energia.jl` ✓.

---

### `src/algorytmy/simulowane_wyzarzanie.jl` (service / event-driven)

**Analog:** `src/typy.jl` (for struct declaration discipline) + `src/punkty.jl` (for function discipline). No closer analog because Phase 1 has no concrete algorithm yet — this file establishes the `<:Algorytm` extension pattern.

**Struct + outer constructor pattern** (analog `src/typy.jl` lines 48–78):
```julia
"""
    StanSymulacji{R<:AbstractRNG}

[Polish prose docstring with bullet lists for `# Pola const` and `# Pola mutable`]
"""
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}
    # ...
end

"""
    StanSymulacji(punkty; rng=Xoshiro(42))

[outer ctor docstring with arguments + cross-refs to D-IDs]
"""
function StanSymulacji(punkty::Vector{Punkt2D}; rng::R=Xoshiro(42)) where {R<:AbstractRNG}
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))
    # ... pre-allocate ...
    return StanSymulacji{R}(punkty, D, rng, trasa, 0.0, 0.0, 0)
end
```

Mirror:
```julia
"""
    SimAnnealing <: Algorytm

Wariant Simulowane Wyzarzanie — geometric cooling z patience stop. Hiperparametry
żyją w strukturze (D-01) — `Parametry` trzyma pola niezależne od algorytmu.

# Pola
- `T_zero::Float64`  — początkowa temperatura (kalibrowana przez `kalibruj_T0`)
- `alfa::Float64`    — współczynnik geometric cooling, default 0.9999 (D-02)
- `cierpliwosc::Int` — stagnation patience threshold, default 5000 (D-02)
"""
struct SimAnnealing <: Algorytm
    T_zero::Float64
    alfa::Float64
    cierpliwosc::Int
end

"""
    SimAnnealing(stan; alfa=0.9999, cierpliwosc=5000, T_zero=kalibruj_T0(stan))

[ctor docstring; T0 calibrated in default kwarg per D-03]
"""
function SimAnnealing(stan::StanSymulacji; alfa::Float64=0.9999,
                      cierpliwosc::Int=5000,
                      T_zero::Float64=kalibruj_T0(stan))
    return SimAnnealing(T_zero, alfa, cierpliwosc)
end
```

**Mutating-bang function pattern** (analog `src/punkty.jl::generuj_punkty` is *non-bang* but the idiom is consistent — all mutating functions in Phase 2 use `!`):
- `oblicz_macierz_dystans!`, `inicjuj_nn!`, `symuluj_krok!` — all bang.
- `oblicz_energie`, `delta_energii`, `trasa_nn`, `kalibruj_T0` — pure.

**`symuluj_krok!` core pattern** (RESEARCH Pattern 2, lines 184–209):
```julia
function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing)
    n = length(stan.trasa)
    i = rand(stan.rng, 1:(n - 1))
    j = rand(stan.rng, (i + 2):n)
    @assert 1 <= i < j <= n "i, j out of range"

    delta = delta_energii(stan, i, j)
    zaakceptowano = delta < 0.0 || rand(stan.rng) < exp(-delta / stan.temperatura)
    if zaakceptowano
        reverse!(view(stan.trasa, (i + 1):j))
        stan.energia += delta
    end
    stan.temperatura *= alg.alfa
    stan.iteracja += 1
    return nothing
end
```

**What to deviate (vs Phase 1 analog):**
- This file lives in `src/algorytmy/` subdirectory — `src/algorytmy/.gitkeep` exists from Phase 1 D-10; **delete `.gitkeep`** when adding this file.
- Exports go through `src/JuliaCity.jl` extension (NOT in this file).

**Pitfalls specific to this file:**
- **Filename has NO diacritics:** `simulowane_wyzarzanie.jl` (LANG-04 / Phase 1 D-19 ASCII filenames) — but the **algorithm display name** in docstring/comments CAN use Polish diacritics (`Simulowane Wyżarzanie`) because that's prose, not an identifier or filename.
- **Polish identifier discipline (D-24):** field name is `cierpliwosc` (not `cierpliwość`); kwarg is `alfa` (not `α` — though Julia supports `α`, ASCII-safe identifiers are project convention; **alternatively** `α` is acceptable per `cierpliwo`/Greek-letter-friendly Julia idiom, planner decides). Phase 1 used pure ASCII identifiers throughout. **Recommendation:** stay ASCII (`alfa`).
- **`return nothing` explicitly** (Pitfall B) — must be a literal `return nothing`, not implicit, for `@inferred ::Nothing` to pass.
- **Cooling step location** (D-04): `stan.temperatura *= alfa` AFTER Metropolis test, BEFORE `iteracja += 1`. Standard SA convention.
- **NO modification of `StanSymulacji` shape** (Phase 1 D-06 hard lock). All new mutable fields go in `Parametry` or are local to `symuluj_krok!`.

---

### `src/baselines.jl` (service / transform + mutate)

**Analog:** `src/punkty.jl`

**Two-method idiom** (analog lines 29–54) — same as `src/energia.jl`:
```julia
# Pure (composable, used by TEST-05 without Stan)
function trasa_nn(D::Matrix{Float64}; start::Int=1)::Vector{Int}
    n = size(D, 1)
    @assert n == size(D, 2) "D must be square"
    # ... NN greedy loop ...
    return trasa
end

# Mutating wrapper (consumes Stan, fills D + trasa + energia)
function inicjuj_nn!(stan::StanSymulacji)
    oblicz_macierz_dystans!(stan)
    stan.trasa = trasa_nn(stan.D; start=1)
    bufor = zeros(Float64, Threads.nthreads())
    stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
    stan.iteracja = 0
    return nothing
end
```

**Docstring + Polish prose discipline** — copy directly from `src/punkty.jl` lines 5–27. Cite REQ ALG-04 + D-14/D-15 in docstrings.

**What to deviate:**
- This is **not** in `src/algorytmy/` because NN is conceptually a baseline + initializer, not a `<:Algorytm` (no `symuluj_krok!`). RESEARCH §Architectural Responsibility Map line 30.
- `inicjuj_nn!` allocates a fresh `bufor` (call site is one-shot — alloc OK per RESEARCH §Open Question 2).

**Pitfalls specific to this file:**
- **`@inbounds` only after correctness tests pass** — NN inner loop has bounds-clean access, but mark with comment per CLAUDE.md guidance.
- **`start=1` deterministically** (D-15) — no RNG dependency. Test fixture relies on this.
- **NFC + ASCII filename** ✓.

---

### `test/test_energia.jl` (test / unit)

**Analog:** `test/runtests.jl` lines 89–113 (`@testset "generuj_punkty (PKT-01, PKT-02, PKT-03)"`)

**Testset structure pattern** (analog lines 88–113):
```julia
@testset "generuj_punkty (PKT-01, PKT-02, PKT-03)" begin
    # PKT-01: zwraca Vector{Punkt2D}
    punkty = generuj_punkty(1000; seed=42)
    @test eltype(punkty) == Punkt2D
    @test length(punkty) == 1000

    # PKT-02: default n=1000
    @test length(generuj_punkty()) == 1000

    # PKT-03: punkty w [0,1]², rozkład jednostajny
    @test all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, punkty)

    # Determinizm dla seed=42 (PKT-01)
    @test generuj_punkty(100; seed=42) == generuj_punkty(100; seed=42)
    @test generuj_punkty(100; seed=42) != generuj_punkty(100; seed=43)

    # ArgumentError dla n ≤ 0
    @test_throws ArgumentError generuj_punkty(0)
end
```

**Pattern features to mirror in `test_energia.jl`:**
- Testset name format: `"<funkcja> (REQ-ID-A, REQ-ID-B, ...)"`.
- Inline polski commentaries naming each REQ ID before its asserts.
- Fresh fixtures per-block via `generuj_punkty(...)` from Phase 1.
- `@test_throws ArgumentError ...` for invalid input.
- Use `Punkt2D(0,0)` literal corners for the N=4 unit-square smoke test (D-16):
  ```julia
  punkty = [Punkt2D(0,0), Punkt2D(1,0), Punkt2D(1,1), Punkt2D(0,1)]
  trasa = [1, 2, 3, 4]
  @test oblicz_energie(punkty, trasa) ≈ 4.0
  ```

**Imports at top of file** — copy from `test/runtests.jl` lines 8–14, but **conditionally**: `test_energia.jl` is `include`d from `runtests.jl` so imports might already be in scope. Pattern: re-declare `using Test, JuliaCity` at top of each `test_*.jl` file (defensive — allows running file standalone via `include("test/test_energia.jl")` after `using JuliaCity, Test`).

**Pitfalls specific to this file:**
- **`@allocated` test must use helper function** (RESEARCH Pitfall A, lines 290–320). Pattern:
  ```julia
  function _alloc_test_helper(D, trasa, bufor)
      return @allocated oblicz_energie(D, trasa, bufor)
  end
  # warmup loop
  for _ in 1:3
      oblicz_energie(D, trasa, bufor)
  end
  @test _alloc_test_helper(D, trasa, bufor) < 4096   # ENE-03 < 4096 B
  ```
- **`@inferred` for type stability** — assert single concrete return type (RESEARCH Pitfall B):
  ```julia
  @test @inferred(oblicz_energie(D, trasa, bufor)) isa Float64
  @test @inferred(delta_energii(stan, 5, 17)) isa Float64
  ```
- **Cache-invariant test** (D-08): after a manual SA loop, `@test isapprox(stan.energia, oblicz_energie(stan.D, stan.trasa, bufor); rtol=1e-10)`.

---

### `test/test_symulacja.jl` (test / unit + integ)

**Analog:** `test/runtests.jl` lines 128–156 (`@testset "StanSymulacji konstruktor"`)

**Testset structure pattern** (analog lines 128–156):
```julia
@testset "StanSymulacji konstruktor" begin
    punkty = generuj_punkty(10; seed=1)
    stan = StanSymulacji(punkty)

    # const fields — identity / pre-allocated
    @test stan.punkty === punkty
    @test size(stan.D) == (10, 10)
    @test stan.rng isa Random.Xoshiro

    # mutable fields — zero-state (D-07)
    @test stan.trasa == collect(1:10)
    @test stan.energia == 0.0
    # ...

    # mutable field reassignment OK
    stan.iteracja = 42
    @test stan.iteracja == 42

    # ArgumentError dla pustego punkty (D-07 walidacja)
    @test_throws ArgumentError StanSymulacji(Punkt2D[])
end
```

**Pattern features to mirror:**
- Block structure: `setup → const-field asserts → mutable-field asserts → invariant violation asserts → error path asserts`.
- Section dividers using `# ` comments naming each D-decision being verified.
- `===` for identity (const fields), `==` for value equality, `≈` / `isapprox` for floating-point.

**TEST-08 golden-value pattern (D-17)** — must hard-code expected `stan.trasa` and `stan.energia` after locally generating reference values during planning/exec phase:
```julia
@testset "TEST-08: golden value StableRNG(42), N=20" begin
    using StableRNGs
    punkty = generuj_punkty(20, StableRNG(42))
    stan = StanSymulacji(punkty; rng=StableRNG(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan; alfa=0.9999, cierpliwosc=5000)
    params = Parametry(liczba_krokow=1000)
    for _ in 1:params.liczba_krokow
        symuluj_krok!(stan, params, alg)
    end
    @test stan.trasa == [HARDCODED_REFERENCE]   # generate locally during plan-exec
    @test isapprox(stan.energia, HARDCODED_FLOAT; rtol=1e-6)
end
```

**TEST-04 multi-thread determinism pattern (RESEARCH Example 3, lines 491–530)**:
- Use `PerformanceTestTools.@include_foreach` with subprocess + env override `JULIA_NUM_THREADS="1"` vs `="8"`.
- Serialize `(trasa, energia)` to `tempname()` files; deserialize and compare.
- `@test r1.trasa == rn.trasa` (bit-identical per D-12).
- `@test isapprox(r1.energia, rn.energia; rtol=1e-12)` (sub-ULP differ tolerated per D-12).

**TEST-01 Hamilton invariant pattern**:
```julia
for k in 1:N
    symuluj_krok!(stan, params, alg)
    if k % 100 == 0   # sample every 100 steps for speed
        @test sort(stan.trasa) == 1:length(stan.trasa)
    end
end
```

**Pitfalls specific to this file:**
- **`@allocated == 0` test** (TEST-03, ALG-03) — same helper-function trick as `test_energia.jl` (RESEARCH Pitfall A). The threshold is **strictly 0** here, NOT `< 4096`.
- **`StableRNG(42)` ↔ `Punkt2D` smoke test (Wave 0)** must come BEFORE TEST-08 (RESEARCH Pitfall E):
  ```julia
  @testset "Wave 0: StableRNG ↔ Punkt2D smoke" begin
      pkty = generuj_punkty(5, StableRNG(42))
      @test eltype(pkty) == Punkt2D
      @test length(pkty) == 5
      @test generuj_punkty(5, StableRNG(42)) == generuj_punkty(5, StableRNG(42))
  end
  ```
- **PerformanceTestTools UUID** — planner must run `Pkg.add("PerformanceTestTools")` and read UUID from generated `Project.toml` (RESEARCH §Environment Availability).

---

### `test/test_baselines.jl` (test / unit + integ)

**Analog:** `test/runtests.jl` lines 16–195 (orchestrator structure of multiple sub-testsets within a top-level `@testset "JuliaCity"`).

**Pattern features to mirror:**
- Multiple inner `@testset "..."` blocks, each with its own setup.
- Section divider format (analog lines 18–20):
  ```julia
  # ─────────────────────────────────────────────────────────────────────────
  # 1. Encoding hygiene guard (BOOT-03, D-21) — Pattern 6 z RESEARCH.md
  # ─────────────────────────────────────────────────────────────────────────
  ```
- Number each inner testset for navigation (lines 21, 89, 118, 128, 161, 180).

**TEST-05 NN-baseline-beat pattern**:
```julia
@testset "TEST-05: NN-baseline-beat ≥ 10%" begin
    punkty = generuj_punkty(1000; seed=42)

    # NN baseline (pure trasa_nn, no Stan)
    D = oblicz_macierz_dystans_lokalnie(punkty)   # helper, builds D
    nn = trasa_nn(D; start=1)
    bufor = zeros(Float64, Threads.nthreads())
    energia_nn = oblicz_energie(D, nn, bufor)

    # SA run
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan)
    params = Parametry(liczba_krokow=20_000)   # RESEARCH Pitfall G — start at 20k
    for _ in 1:params.liczba_krokow
        symuluj_krok!(stan, params, alg)
    end

    @test stan.energia / energia_nn <= 0.9
end
```

**Pitfalls specific to this file:**
- **CI runtime budget** (RESEARCH Pitfall G) — start with `liczba_krokow=20_000`; if it fails on CI, raise to 50_000.
- **Deterministic single-seed test** — no flakiness, binary outcome.

---

### `src/JuliaCity.jl` (MODIFIED)

**Analog:** itself (pre-existing module wiring file). Phase 2 extends in place.

**Existing module structure** (analog lines 17–32):
```julia
module JuliaCity

# Zewnętrzne zależności runtime
using GeometryBasics: Point2
using Random

# Typy domenowe (Punkt2D, Algorytm, StanSymulacji)
include("typy.jl")

# Generator punktów testowych (PKT-01..04)
include("punkty.jl")

# Eksport publicznego API
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty

end # module
```

**Modification pattern (extend, not replace):**
```julia
module JuliaCity

# Zewnętrzne zależności runtime
using GeometryBasics: Point2
using Random
using ChunkSplitters                       # NEW Phase 2 (D-11)
using Statistics: std                      # NEW Phase 2 (kalibruj_T0)

# Typy domenowe (Punkt2D, Algorytm, StanSymulacji, Parametry)
include("typy.jl")                         # MOD: + Parametry

# Generator punktów testowych (PKT-01..04)
include("punkty.jl")

# Energia + macierz dystansów + delta + kalibracja T0 (Phase 2)
include("energia.jl")                      # NEW

# Baseline NN (Phase 2)
include("baselines.jl")                    # NEW

# Algorytmy <:Algorytm (Holy-traits) (Phase 2+)
include("algorytmy/simulowane_wyzarzanie.jl")  # NEW

# Eksport publicznego API
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty,
       Parametry, SimAnnealing,
       oblicz_energie, oblicz_macierz_dystans!, delta_energii, kalibruj_T0,
       trasa_nn, inicjuj_nn!,
       symuluj_krok!

end # module
```

**Pattern features to preserve:**
- Top-of-file module docstring (analog lines 1–16) — extend the API list to include Phase 2 functions.
- `include` order **strictly topological**: `typy → punkty → energia → baselines → algorytmy/...` (RESEARCH §Architecture line 174 — Phase 1 ARCHITECTURE.md).
- Polish prose comments above each `include` block.
- Single `export` block at end (multi-line for readability).

**Pitfalls specific to this file:**
- **Topological order:** `algorytmy/simulowane_wyzarzanie.jl` MUST come AFTER `energia.jl` (uses `delta_energii`) AND `baselines.jl` (uses nothing, but for clarity).
- **`using ChunkSplitters`** can live here (module-wide) OR in `src/energia.jl` (file-local). Phase 1 convention is module-wide — recommend module-wide.
- **`using Statistics: std`** — explicit symbol import keeps the namespace tight.

---

### `src/typy.jl` (MODIFIED)

**Analog:** itself (existing struct + ctor file).

**Existing struct + ctor pattern** (analog lines 30–78) — already shown above.

**Modification: add `Parametry` AFTER `StanSymulacji` block, BEFORE end of file:**
```julia
"""
    Parametry

Hiperparametry niezależne od algorytmu (D-01). Slot na `kroki_na_klatke` w Phase 3.

# Pola
- `liczba_krokow::Int = 50_000` — budżet kroków SA (D-02)
"""
Base.@kwdef struct Parametry
    liczba_krokow::Int = 50_000
end
```

**Pattern features to mirror:**
- Polish docstring above struct.
- `# Pola` bullet list with type + default + D-decision cross-reference.
- `Base.@kwdef` for default-value-friendly constructor (RESEARCH §Standard Stack patterns).

**Pitfalls specific to this file:**
- **DO NOT modify `StanSymulacji` shape** — Phase 1 D-06 hard lock.
- **`Parametry` is immutable `struct`** (no `mutable` keyword) — Phase 3 will only ADD a field for `kroki_na_klatke`, never mutate per-instance.
- **`Base.@kwdef`** is stdlib-bundled in Julia 1.10+ — no extra import needed.

---

### `test/runtests.jl` (MODIFIED)

**Analog:** itself (existing orchestrator).

**Existing orchestrator pattern** (analog lines 16–195) — multiple inner testsets in a top-level `@testset "JuliaCity" begin ... end`.

**Modification pattern: add new `include` calls + extend Aqua/JET testsets**:
```julia
@testset "JuliaCity" begin

    # 1. Encoding hygiene (Phase 1, unchanged)
    @testset "encoding hygiene (BOOT-03, D-21)" begin ... end

    # 2. Phase 1 generuj_punkty (unchanged)
    @testset "generuj_punkty (PKT-01..03)" begin ... end

    # 3. Phase 1 RNG isolation (unchanged)
    @testset "generuj_punkty no global RNG mutation (PKT-04, D-14)" begin ... end

    # 4. Phase 1 StanSymulacji (unchanged)
    @testset "StanSymulacji konstruktor" begin ... end

    # 5. Phase 2 NEW — energia
    include("test_energia.jl")

    # 6. Phase 2 NEW — symulacja (SA + TEST-04 + TEST-08)
    include("test_symulacja.jl")

    # 7. Phase 2 NEW — baselines (NN + TEST-05)
    include("test_baselines.jl")

    # 8. Aqua extended (TEST-06)
    @testset "Aqua.jl quality (TEST-06)" begin
        Aqua.test_all(JuliaCity;
            ambiguities = (recursive = false,),
            stale_deps = false,
            deps_compat = (ignore = [:Random, :Statistics],
                           check_extras = (ignore = [:Test, :Unicode],)),
        )
    end

    # 9. JET extended (TEST-07)
    @testset "JET type stability (TEST-07)" begin
        # fixture
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        params = Parametry(liczba_krokow=100)
        bufor = zeros(Float64, Threads.nthreads())

        # warmup
        oblicz_energie(stan.D, stan.trasa, bufor)
        delta_energii(stan, 5, 17)
        symuluj_krok!(stan, params, alg)

        @test_opt target_modules=(JuliaCity,) oblicz_energie(stan.D, stan.trasa, bufor)
        @test_opt target_modules=(JuliaCity,) delta_energii(stan, 5, 17)
        @test_opt target_modules=(JuliaCity,) symuluj_krok!(stan, params, alg)
        @test_opt target_modules=(JuliaCity,) kalibruj_T0(stan; n_probek=10)
    end
end
```

**Pattern features to preserve (analog lines 1–14):**
- Top-of-file polski hash-comment header listing covered REQs and conventions.
- All `using` statements at top of file.
- Single outermost `@testset "JuliaCity" begin ... end` wrap.
- Section dividers with line of `─` for visual grouping.

**Pitfalls specific to this file:**
- **`include` paths are relative to `runtests.jl`** — `include("test_energia.jl")` works because all test files are siblings.
- **Aqua `deps_compat` ignore list** — Phase 2 adds `Statistics` to ignore (stdlib has no compat entry; Phase 1 already ignores `Random`).
- **Aqua `unbound_args`** — DO NOT add `(broken=true,)` preemptively (RESEARCH Pitfall F); only add IF Aqua flags `StanSymulacji{R}` false-positive on first run.
- **Phase 1 JET smoke test** at lines 180–194 should be **removed/replaced** by the full TEST-07 testset above (no point keeping the soft-assertion smoke once we have hard `@test_opt`).
- **TEST-04 may need to live in `test_symulacja.jl`** (uses `PerformanceTestTools.@include_foreach`) rather than `runtests.jl` — keeps subprocess machinery encapsulated.

---

### `Project.toml` (MODIFIED)

**Analog:** itself (existing dep manifest).

**Existing structure** (analog lines 1–34):
```toml
[deps]
GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[compat]
julia = "1.10"
GLMakie = "0.24"
Makie = "0.24"
GeometryBasics = "0.5"
Observables = "0.5"
StableRNGs = "1.0"
Aqua = "0.8.14"
JET = "0.9"
BenchmarkTools = "1.6"

[extras]
Aqua = "..."
BenchmarkTools = "..."
GLMakie = "..."
JET = "..."
Makie = "..."
Observables = "..."
StableRNGs = "..."
Test = "..."
Unicode = "..."

[targets]
test = ["Aqua", "JET", "StableRNGs", "Test", "Unicode"]
```

**Modification: Phase 2 additions:**
```toml
[deps]
ChunkSplitters = "ae650224-84b6-46f8-82ea-d812ca08434e"   # NEW Phase 2 (D-11)
GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"        # NEW Phase 2 (stdlib for std)

[compat]
julia = "1.10"
ChunkSplitters = "3"                                        # NEW Phase 2
GLMakie = "0.24"
# ... (rest unchanged)
JET = "0.9"                                                 # CONFIRMED — RESEARCH Critical version note
# ... (Statistics is stdlib — NO compat entry, just [deps])

[extras]
# ... existing entries unchanged ...
PerformanceTestTools = "<UUID-from-Pkg.add>"               # NEW Phase 2 (TEST-04)

[targets]
test = ["Aqua", "JET", "PerformanceTestTools", "StableRNGs", "Test", "Unicode"]   # ADD PerformanceTestTools
```

**Pattern features to preserve (analog lines 6–9, 21–30, 32–33):**
- `[deps]` alphabetical order.
- `[compat]` alphabetical order with `julia` first (Phase 1 convention).
- `[extras]` alphabetical order.
- `[targets].test` is a sorted array.

**Pitfalls specific to this file:**
- **`Statistics` is stdlib** — goes in `[deps]` (with UUID `10745b16-79ce-11e8-11f9-7d13ad32a3b2`) but **NOT** in `[compat]` (RESEARCH §Wave 0 Gaps line 700; Aqua.jl convention).
- **JET version stays at 0.9** (RESEARCH §Critical version note, lines 47–52). CONTEXT.md and STACK.md mistakenly mention 0.11; Phase 2 plan keeps 0.9 because `julia = "1.10"` is the locked compat floor and JET 0.11 requires Julia 1.12.
- **`ChunkSplitters` UUID** verified: `ae650224-84b6-46f8-82ea-d812ca08434e` (RESEARCH §Sources line 743).
- **`PerformanceTestTools` UUID** must be obtained via `Pkg.add("PerformanceTestTools")` and read from generated Project.toml (RESEARCH §Environment Availability line 644).
- **`Manifest.toml`** must be re-generated after changes and committed (Phase 1 D-25).

---

## Shared Patterns

### Polish identifier discipline (LANG-04, Phase 1 D-22/D-23/D-24)

**Source:** `src/typy.jl` lines 48–56 + `test/runtests.jl` line 6.
**Apply to:** ALL new `src/*.jl` and `test/*.jl` files.

```julia
# src/typy.jl L74 — English internal assert
n > 0 || throw(ArgumentError("punkty must be non-empty"))   # asercja po angielsku (D-23, LANG-04)

# src/typy.jl L43 — Polish docstring prose
- `trasa::Vector{Int}` — permutacja `1:n` reprezentująca cykl Hamiltona

# src/typy.jl L48-56 — ASCII identifiers (no diacritics in field/var names)
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}    # NOT `punktý`
    # ...
end
```

**Phase 2 application:**
- Identifiers: `cierpliwosc` (NOT `cierpliwość`), `liczba_krokow`, `kalibruj_T0`, `simulowane_wyzarzanie`, `bufor`, `trasa_nn`, `inicjuj_nn!`, `oblicz_macierz_dystans!`.
- Geometry stays `x`, `y`, `i`, `j`, `k`, `n` — it's geometry/math, not domain.
- Asserts (`@assert`, `throw(ArgumentError(...))`, `error(...)`) use English message strings.
- Docstrings, hash-comments, prose use Polish (with diacritics — NFC normalized).
- Filenames: ASCII only (`simulowane_wyzarzanie.jl`, NOT `symulowane_wyżarzanie.jl`).

---

### Two-method idiom (Phase 1 D-11, Phase 2 D-10)

**Source:** `src/punkty.jl` lines 29–54.
**Apply to:** `oblicz_energie`, `SimAnnealing` constructor, `kalibruj_T0` (kwarg-with-default + composable variant).

```julia
# src/punkty.jl — friendly default delegating to composable
function generuj_punkty(n::Int=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))
    rng = Xoshiro(seed)
    return generuj_punkty(n, rng)
end

# Composable
function generuj_punkty(n::Int, rng::AbstractRNG)
    n > 0 || throw(ArgumentError("n must be positive"))
    return rand(rng, Punkt2D, n)
end
```

**Phase 2 application:**
- `oblicz_energie(punkty, trasa)` (friendly, builds D + bufor) → delegates to `oblicz_energie(D, trasa, bufor)` (hot-path, zero-alloc post-warmup).
- `SimAnnealing(stan; alfa, cierpliwosc, T_zero=kalibruj_T0(stan))` → calls `SimAnnealing(T_zero, alfa, cierpliwosc)` (positional, for tests).

---

### English internal asserts (LANG-04 / Phase 1 D-23)

**Source:** `src/typy.jl` line 74, `src/punkty.jl` lines 30, 47.
**Apply to:** ALL `src/*.jl` files.

```julia
n > 0 || throw(ArgumentError("n must be positive"))                # punkty.jl L30
n > 0 || throw(ArgumentError("punkty must be non-empty"))           # typy.jl L74
```

**Phase 2 application:**
- `@assert 1 <= i < j <= n "i, j out of range"` (delta_energii)
- `@assert size(stan.D) == (n, n) "D dimension mismatch"` (oblicz_macierz_dystans!)
- `@assert n == size(D, 2) "D must be square"` (trasa_nn)
- `@assert !isempty(worsening) "no worsening moves sampled"` (kalibruj_T0)

---

### Test fixture pattern (StableRNG vs Xoshiro)

**Source:** `test/runtests.jl` lines 11, 91, 119, 129.
**Apply to:** ALL `test/test_*.jl` files.

```julia
# test/runtests.jl L11 — imports
using Random
using Random: Xoshiro, default_rng

# test/runtests.jl L91 — Xoshiro for runtime fixtures
punkty = generuj_punkty(1000; seed=42)

# test/runtests.jl L129 — local fixture per testset
@testset "..." begin
    punkty = generuj_punkty(10; seed=1)
    stan = StanSymulacji(punkty)
    # ...
end
```

**Phase 2 application:**
- **TEST-08 (golden value)**: use `StableRNG(42)` (Phase 2 D-17, RESEARCH Pitfall E).
- **TEST-04 (multi-thread determinism)**: use `Xoshiro(42)` (runtime path).
- **TEST-05 (NN-baseline-beat)**: use `Xoshiro(42)` (runtime path).
- **ENE-01..05 / ALG-01..08 unit tests**: use `Xoshiro(seed)` with various small seeds (1, 7, 42).
- **Wave 0 smoke**: `rand(StableRNG(42), Punkt2D, 5)` BEFORE TEST-08 fixture (RESEARCH Pitfall E).

---

### Encoding hygiene (Phase 1 BOOT-03 / D-21)

**Source:** `test/runtests.jl` lines 21–84.
**Apply to:** Pre-existing test (extends automatically — new files in `src/` and `test/` are auto-scanned).

The encoding-guard testset already walks `src/` and `test/` recursively. **No code change needed** — but Phase 2 must ensure all NEW files are:
- UTF-8 encoded (no BOM).
- LF line endings (no CRLF).
- NFC normalized (especially `.jl` files with Polish comments).
- ASCII filenames in `src/`, `test/`.

---

## No Analog Found

**None.** All Phase 2 files have a Phase 1 analog suitable for pattern extraction. The closest near-miss is `src/algorytmy/simulowane_wyzarzanie.jl` — there is no existing concrete `<:Algorytm` subtype, but `src/typy.jl::StanSymulacji` provides the struct + outer constructor + parametric type pattern that `SimAnnealing` will mirror, and `src/punkty.jl` provides the function-discipline pattern.

---

## Metadata

**Analog search scope:**
- `src/JuliaCity.jl` (1 file, 33 lines)
- `src/typy.jl` (1 file, 78 lines)
- `src/punkty.jl` (1 file, 54 lines)
- `test/runtests.jl` (1 file, 195 lines)
- `Project.toml` (1 file, 34 lines)
- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` (Phase 1 decisions)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md` (Phase 2 decisions D-01..D-17)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-RESEARCH.md` (Phase 2 technical research, ~780 lines)

**Files scanned:** 5 source/config + 3 planning context = 8 files.

**Pattern extraction date:** 2026-04-29

---

*Phase 2 patterns: derived from Phase 1 implemented code + locked CONTEXT decisions + verified RESEARCH technical specs.*
