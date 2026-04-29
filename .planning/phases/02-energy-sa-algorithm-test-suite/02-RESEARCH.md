# Phase 2: Energy, SA Algorithm & Test Suite — Research

**Researched:** 2026-04-29
**Domain:** Idiomatyczna Julia — algorytmiczny rdzeń SA-2-opt + chunked threading + pełen suite testowy (Aqua, JET, @inferred, @allocated, golden-value StableRNG, multi-thread determinism)
**Confidence:** HIGH dla packages/wersji (zweryfikowane oficjalnymi repo Project.toml), HIGH dla idiomatic patterns (oficjalna dokumentacja), MEDIUM dla `rand(StableRNG, Point2, n)` (community-reported, niezweryfikowane lokalnie)

## Summary

CONTEXT.md jest wyczerpujący — locks 17 decyzji projektowych (D-01..D-17). Ta faza badawcza wypełnia **wyłącznie luki techniczne**, których planner Phase 2 potrzebuje by zoperacjonalizować locked decisions:

1. **ChunkSplitters.jl 3.2.0** to właściwa biblioteka (UUID, API `enumerate(chunks(x; n=N))`, oficjalnie wspiera `Threads.@threads :static`).
2. **JET 0.9 jest właściwy pin dla Julia 1.10** (Project.toml już to ma poprawnie). CONTEXT.md i STACK.md mylnie wspominają JET 0.11 — ta wersja wymaga Julia 1.12 i **jest niezgodna z lockowanym `julia = "1.10"`**. Plan Phase 2 zostaje przy 0.9.
3. **`rand(StableRNG(42), Point2{Float64}, 20)`** prawdopodobnie działa via GeometryBasics' Random.Sampler (community-reported), ale Phase 1 `generuj_punkty(n, rng::AbstractRNG)` używa `rand(rng, Punkt2D, n)` — wymaga **smoke testu w Wave 0** zanim TEST-08 będzie wymyślony nad tą podstawą.
4. **TEST-04 multi-thread determinism** powinien używać `PerformanceTestTools.@include_foreach` (subprocess pattern z env override `JULIA_NUM_THREADS=1` vs `=8`) — kanoniczny mechanizm, idealny dla CI.
5. **`@allocated == 0`** wymaga manual warmup (3+ wywołań) i wrappera funkcyjnego — nie globala. **`@test_opt`** (nie `@report_opt`) jest preferowane dla TEST-07 — automatycznie failuje testset.
6. **Aqua 0.8.x** używa NamedTuple kwargs do per-subcheck konfiguracji; istniejący Phase 1 stub (`stale_deps=false`, deps_compat ignore Random) jest **dobrym punktem startowym** — Phase 2 musi go pielęgnować przy dodaniu ChunkSplitters i nie regresować.

**Primary recommendation:** Trzymać się CONTEXT.md decyzji bez wątpliwości; tylko zaktualizować przyjętą wersję JET (0.9 nie 0.11), dodać Wave 0 smoke test dla `rand(StableRNG, Punkt2D, n)`, i wybrać `PerformanceTestTools.@include_foreach` jako mechanizm dla TEST-04.

## Architectural Responsibility Map

Phase 2 jest **headless / single-tier** (brak warstwy klient/serwer) — wszystko to jeden moduł Julia. Mapowanie tier→capability sprowadza się do *wewnątrzmodułowych warstw kompilacji* (Architecture.md "Strict Topological Order"):

| Capability | Primary Tier (warstwa) | Secondary Tier | Rationale |
|------------|----------------------|----------------|-----------|
| `Punkt2D`/`StanSymulacji` field types | `src/typy.jl` (Phase 1 — dziedziczone) | — | Phase 1 D-06 zamknął shape; Phase 2 NIE modyfikuje |
| `Parametry` struct | `src/typy.jl` (rozszerzenie) | `src/parametry.jl` (alt) | Single source dla typów domeny; rekomendacja CONTEXT.md (Claude's Discretion) |
| `oblicz_macierz_dystans!` / `oblicz_energie` / `delta_energii` / `kalibruj_T0` | `src/energia.jl` | — | Wszystkie operacyjnie powiązane (energia + jej delta + jej kalibracja); pojedynczy `include` |
| `SimAnnealing` struct + `symuluj_krok!(stan, params, alg::SimAnnealing)` | `src/algorytmy/simulowane_wyzarzanie.jl` | — | Holy-traits pattern z Architecture.md; jedna ścieżka per `<:Algorytm` (Phase 2 dodaje TYLKO ten plik do `src/algorytmy/`) |
| `trasa_nn` / `inicjuj_nn!` | `src/baselines.jl` | `src/algorytmy/nn.jl` | NN to konceptualnie **baseline jakości** (TEST-05) i osobno **inicjalizacja** (ALG-04). `src/baselines.jl` jest jaśniejszy semantycznie — NN nie jest `<:Algorytm` (nie ma `symuluj_krok!`), więc nie należy do `src/algorytmy/`. Recommendation: `src/baselines.jl` |
| Threading (`Threads.@threads :static` + chunks) | wewnątrz `oblicz_energie` w `src/energia.jl` | — | Single hot site, locked w D-11 |
| Test orchestration (Aqua, JET, @inferred, @allocated, etc.) | `test/runtests.jl` jako orchestrator | `test/test_energia.jl`, `test/test_symulacja.jl`, `test/test_baselines.jl` (przez `include`) | CONTEXT.md rekomenduje split; planner ustala czy `include` czy inline `@testset`. Rekomendacja: `include` per phase semantyczny → łatwiejszy navigation w razie failu |

## Standard Stack

### Core (zmiany Phase 2 nad Phase 1)

| Library | Version | UUID | Purpose | Why Standard |
|---------|---------|------|---------|--------------|
| **ChunkSplitters.jl** | 3.2.0 (julia ≥ 1.10) | `ae650224-84b6-46f8-82ea-d812ca08434e` | Per-chunk `(idx, range)` enumerate dla `Threads.@threads :static` | [VERIFIED: github.com/JuliaFolds2/ChunkSplitters.jl/blob/main/Project.toml] Stabilne ID-stable chunki niezależne od `Threads.threadid()` (PITFALLS Pitfall 2 caveat dla Julia ≥ 1.12). |

### Test deps (już w Phase 1 [extras]+[targets] — nic do dodania)

| Library | Version | Purpose | Phase 2 Use |
|---------|---------|---------|-------------|
| **Aqua.jl** | 0.8.14+ | Quality gate (ambiguities, piracies, deps_compat) | TEST-06 — Phase 2 rozszerza istniejący stub o full strict config |
| **JET.jl** | **0.9.x** (NIE 0.11 — patrz uwaga niżej) | `@test_opt`/`@report_opt` type-stability | TEST-07 — pełna analiza na 4 funkcjach (`oblicz_energie`, `delta_energii`, `symuluj_krok!`, `kalibruj_T0`) |
| **StableRNGs.jl** | 1.0.x | Cross-Julia-version stable RNG stream | TEST-08 golden-value pattern (N=20 fixture) |
| **Test** (stdlib) | bundled | `@inferred`, `@test`, `@allocated` | TEST-01..04 |
| **Unicode** (stdlib) | bundled | NFC normalization w encoding guard (Phase 1 pattern, dziedziczone) | — |

**Critical version note:** `Project.toml` ma `JET = "0.9"`. CONTEXT.md (line 173) i STACK.md (line 32) mówią "JET 0.11". **JET 0.11.x wymaga Julia 1.12** [VERIFIED: github.com/aviatesk/JET.jl/blob/master/Project.toml — `julia = "1.12"`]. Project ma `julia = "1.10"` LTS compat (BOOT-02, locked). **Plan Phase 2 trzyma się JET 0.9** — to też nie konflikt z istniejącym `Project.toml`. STACK.md i CONTEXT.md *mylnie* zawyżyły wersję; nie reagujemy zmianą lockowanej decyzji o compat floor.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **ChunkSplitters.chunks** | `OhMyThreads.tmapreduce` | OhMyThreads daje wbudowany reduce (cleaner ergonomics dla SA proposal-evaluation); ChunkSplitters daje surowe chunki + manual sum. **Trzymamy ChunkSplitters** (CONTEXT D-11 lock) — `oblicz_energie` jest summa, manual sum trywialna. |
| **`Threads.threadid()`-indexed buffers** | ChunkSplitters | `threadid` jest niestabilne dla migracji w Julia ≥ 1.12 (PITFALLS Pitfall 2). ChunkSplitters dają stabilne `(idx, range)` przez `enumerate`. CONTEXT D-11 zamknął wybór. |
| **`@allocated`** (Base) | `BenchmarkTools.@ballocated` | `@ballocated` wymaga `$` interpolation discipline (PITFALLS Pitfall 16 footgun). `@allocated` w wrapperze funkcyjnym po manual warmup jest prostszy i bezbłędny. CONTEXT Claude's Discretion potwierdza preferencję. |
| **`@report_opt`** | **`@test_opt`** | `@report_opt` zwraca obiekt — testset musiałby odczytać `JET.get_reports(result)` i `@test isempty(...)`. `@test_opt` automatycznie failuje testset gdy są issues. **Rekomendacja: `@test_opt`** — krótszy, bardziej idiomatyczny, integruje się z `@testset`. [CITED: aviatesk.github.io/JET.jl/dev/optanalysis/] |
| **In-process multi-thread test** | `PerformanceTestTools.@include_foreach` | Julia nie pozwala zmienić nthreads runtime; in-process trick (np. `Threads.@spawn` na pojedynczy task) NIE testuje **prawdziwego** różnego scheduler-a. `@include_foreach` odpala subprocess z env `JULIA_NUM_THREADS="8"` — kanoniczny pattern. [CITED: juliatesting.github.io/PerformanceTestTools.jl] |

**Installation (Phase 2 doda jeden dep):**
```julia
# w katalogu projektu
julia --project=. -e 'using Pkg; Pkg.add("ChunkSplitters")'
```
Po dodaniu wpisać do `Project.toml [compat]`:
```toml
ChunkSplitters = "3"
```

**Version verification command (planner powinien uruchomić):**
```bash
julia --project=. -e 'using Pkg; v = Pkg.dependencies()[Base.UUID("ae650224-84b6-46f8-82ea-d812ca08434e")].version; println("ChunkSplitters: ", v)'
```

## Architecture Patterns

### System Architecture Diagram

```
+----------------------------------------------------------+
|               test/runtests.jl (orchestrator)            |
|  - encoding hygiene (Phase 1)                            |
|  - PKT-* (Phase 1)                                       |
|  - StanSymulacji (Phase 1)                               |
|  - Aqua.test_all (TEST-06)                               |
|  - JET.@test_opt (TEST-07)                               |
|  - include("test_baselines.jl")  (TEST-05 NN-beat)       |
|  - include("test_energia.jl")    (ENE-01..05, TEST-02/03)|
|  - include("test_symulacja.jl")  (ALG-01..08, TEST-01/04/08) |
+-------------------+--------------------------------------+
                    | uses
                    v
+----------------------------------------------------------+
|       module JuliaCity (src/JuliaCity.jl)                |
|  using Random, GeometryBasics, ChunkSplitters            |
|  exports: Punkt2D, StanSymulacji, Algorytm, generuj_punkty |
|           +oblicz_energie, delta_energii, symuluj_krok!  |
|           +SimAnnealing, Parametry,                      |
|           +trasa_nn, inicjuj_nn!, kalibruj_T0            |
+--------+------------+---------+---------+----------------+
         |            |         |         |
         v            v         v         v
+-----------+ +-----------+ +-----------+ +------------------+
| typy.jl   | | punkty.jl | | energia.jl| | algorytmy/       |
| Phase 1   | | Phase 1   | | Phase 2   | |   simulowane_    |
| +Parametry| |           | | NEW       | |   wyzarzanie.jl  |
+-----------+ +-----------+ +-----------+ | Phase 2 NEW      |
                              ^           +------------------+
                              |                ^
                              |                |
                          +-------------+      |
                          | baselines.jl|------+
                          | Phase 2 NEW |  uses oblicz_energie
                          | (NN init)   |  and delta_energii
                          +-------------+

Threading scope:  oblicz_energie (D-11) -- Threads.@threads :static
                                            + ChunkSplitters.chunks
Hot path (single thread):  delta_energii (O(1), 4 lookups in stan.D)
                            symuluj_krok! (sequential SA, master rng)
```

### Recommended Project Structure (Phase 2 dodatki)

```
src/
+-- JuliaCity.jl              # Phase 1 — Phase 2 modyfikuje: + include + export
+-- typy.jl                   # Phase 1 — Phase 2 modyfikuje: + struct Parametry
+-- punkty.jl                 # Phase 1 — bez zmian
+-- energia.jl                # NEW — oblicz_macierz_dystans!, oblicz_energie (2 metody),
|                             #       delta_energii, kalibruj_T0
+-- algorytmy/
|   +-- .gitkeep              # Phase 1 — usunąć przy dodaniu pierwszego pliku
|   +-- simulowane_wyzarzanie.jl  # NEW — struct SimAnnealing <: Algorytm,
|                                 #        konstruktory, symuluj_krok!
+-- baselines.jl              # NEW — trasa_nn(D; start), inicjuj_nn!(stan)
test/
+-- runtests.jl               # Phase 1 — Phase 2 dorzuca include + Aqua/JET expansion
+-- test_energia.jl           # NEW — ENE-01..05, TEST-02 częściowo, TEST-03 częściowo
+-- test_symulacja.jl         # NEW — ALG-01..08, TEST-01, TEST-04, TEST-08
+-- test_baselines.jl         # NEW — NN correctness + TEST-05 NN-baseline-beat
```

**Test split rationale (CONTEXT Claude's Discretion):** `include` z osobnych plików (NIE inline `@testset`) — argumenty: (a) jasne ścieżki failów w outputcie, (b) lokalny scope dla per-plik fixturów, (c) szybsze iteracje ("uruchom tylko `test/test_energia.jl`" w REPL — `include("test/test_energia.jl")` after `using JuliaCity, Test`).

### Pattern 1: ChunkSplitters w `oblicz_energie` (zaktualizowanie D-11 do API 3.x)

**What:** Pre-alokowany `bufor::Vector{Float64}` o długości `nchunks`; `enumerate(chunks(...))` daje `(chunk_idx, range_indeksów_krawędzi)`; każdy thread sumuje swój range, zapisuje w `bufor[chunk_idx]`; finalna redukcja `sum(bufor)`.

**When to use:** Wewnątrz `oblicz_energie(D, trasa, bufor)` — *jedyne* miejsce w Phase 2 z threadingiem (D-11).

**Example:**
```julia
# Source: juliafolds2.github.io/ChunkSplitters.jl/stable/multithreading/
using ChunkSplitters
using Base.Threads: @threads, nthreads

function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})
    n = length(trasa)
    nchunks = length(bufor)                                # bufor pre-alokowany do = nthreads()
    fill!(bufor, 0.0)
    @threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))
        s = 0.0
        @inbounds for k in krawedzie
            i_aktualne = trasa[k]
            i_nastepne = trasa[mod1(k + 1, n)]            # mod1 zamyka cykl Hamiltona
            s += D[i_aktualne, i_nastepne]                # O(1) lookup; D pre-policzona
        end
        bufor[chunk_idx] = s
    end
    return sum(bufor)                                      # left-to-right canonical reduce
end
```

**Pattern caveat (LOW confidence):** ChunkSplitters docs sugerują że dla `:static` z bardzo nieregularną pracą warto rozważyć `RoundRobin()` split — ale **`oblicz_energie` ma uniform work per krawędź**, więc default `Consecutive()` jest właściwy. Phase 4 benchmark może to potwierdzić.

### Pattern 2: 2-opt move + uniform random pair (D-05/D-06/D-07)

```julia
# Source: CONTEXT D-05 + D-06 (locked) + idiomatyczna Julia
function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing)
    n = length(stan.trasa)
    # D-05: uniform random pair, j >= i+2 (excludes adjacent — degenerate reverse)
    i = rand(stan.rng, 1:(n - 1))
    j = rand(stan.rng, (i + 2):n)
    @assert 1 <= i < j <= n "i, j out of range"            # English internal assert (LANG-04)

    # D-06: O(1) delta z mod1 wrap-around
    delta = delta_energii(stan, i, j)

    # Metropolis acceptance (D-04)
    zaakceptowano = delta < 0.0 || rand(stan.rng) < exp(-delta / stan.temperatura)
    if zaakceptowano
        # D-07: in-place reverse via view, zero-alloc
        reverse!(view(stan.trasa, (i + 1):j))
        # D-08: cache update (NIGDY full oblicz_energie w hot path)
        stan.energia += delta
    end

    # D-04: cooling po Metropolis (NIE przed)
    stan.temperatura *= alg.alfa
    stan.iteracja += 1
    return nothing                                          # type-stable Nothing return
end
```

**Hot-path discipline:**
- **NIE** używaj `length(stan.trasa)` więcej niż raz — przypisz do `n::Int` na początku.
- **NIE** używaj `getfield`/`@inbounds`/keyword args wewnątrz hot path — same direct field access.
- `@assert` jest darmowy w `--check-bounds=no` builds, drogi w default — ale tu sprawdzane jest tylko w teście, nie w hot path. Dla Phase 4 bench warto rozważyć `@boundscheck` zamiast `@assert`.

### Pattern 3: NN baseline z dual entry-points (D-14)

```julia
# Source: CONTEXT D-14 (locked)
"""
    trasa_nn(D::Matrix{Float64}; start::Int=1) -> Vector{Int}

Pure NN tour z pre-policzoną macierzą dystansów. Używana niezaleznie od `Stan`
w teście NN-baseline-beat (TEST-05).
"""
function trasa_nn(D::Matrix{Float64}; start::Int=1)
    n = size(D, 1)
    @assert n == size(D, 2) "D must be square"
    odwiedzone = falses(n)
    trasa = Vector{Int}(undef, n)
    trasa[1] = start
    odwiedzone[start] = true
    for k in 2:n
        biezacy = trasa[k - 1]
        # Find argmin over D[biezacy, j] for j in 1:n nie-odwiedzony
        najblizszy = 0
        min_dist = Inf
        @inbounds for j in 1:n
            if !odwiedzone[j] && D[biezacy, j] < min_dist
                min_dist = D[biezacy, j]
                najblizszy = j
            end
        end
        trasa[k] = najblizszy
        odwiedzone[najblizszy] = true
    end
    return trasa
end

"""
    inicjuj_nn!(stan::StanSymulacji)

Mutating wrapper — wypełnia `stan.D`, `stan.trasa = trasa_nn(stan.D)`,
`stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)`.
"""
function inicjuj_nn!(stan::StanSymulacji)
    oblicz_macierz_dystans!(stan)                          # wypełnia stan.D
    stan.trasa = trasa_nn(stan.D; start=1)                 # D-15: start=1 deterministically
    bufor = zeros(Float64, Threads.nthreads())             # alloc OK — wywoływane raz
    stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
    stan.iteracja = 0                                       # reset
    return nothing
end
```

### Anti-Patterns to Avoid

- **`Threads.@threads` *outside* a function** — kills type inference (PITFALLS, ARCHITECTURE.md). Wszystkie Phase 2 hot paths są w funkcjach.
- **Re-assigning a captured scalar inside `@threads`** — boxes do `Core.Box` (PITFALLS Pitfall 2). D-11 wzorzec używa `bufor[chunk_idx] = s` — nie capturuje skalarów.
- **`oblicz_energie` w hot path** — naruszenie ENE-04 i CONTEXT D-08. Hot path używa **tylko** `delta_energii`.
- **Per-thread RNG infrastructure** — Phase 2 explicit NIE ma (D-09). v2 ForceDirected miałby, ale to dla wariantu z parallel proposal evaluation.
- **`Random.seed!(42)` w `src/`** — naruszenie PKT-04, PROJECT.md "no global state". Każda funkcja używa lokalnego `stan.rng` lub argumentu `rng`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-thread chunk distribution | `Threads.threadid()` indexing + manual range slicing | `ChunkSplitters.chunks(1:n; n=nthreads())` | `threadid()` niestabilne dla migracji w Julia ≥ 1.12 (PITFALLS Pitfall 2); ChunkSplitters daje stabilne `(idx, range)` przez `enumerate` [VERIFIED] |
| Multi-thread CI test (run with diff `JULIA_NUM_THREADS`) | Manual `run(\`julia -t 8 -e ...\`)` w teście | `PerformanceTestTools.@include_foreach` | Wbudowany pattern z env var override; integruje się z `@testset`; subprocess isolation [CITED: juliatesting.github.io/PerformanceTestTools.jl] |
| 2-opt edge reverse | `trasa_nowa = vcat(trasa[1:i], reverse(trasa[i+1:j]), trasa[j+1:end])` | `reverse!(view(stan.trasa, (i+1):j))` | View jest zero-alloc; `vcat` alokuje 3 wektory + final |
| Cycle wrap-around | `if k == n; 1; else; k+1; end` | `mod1(k+1, n)` | Jednolinijkowy; type-stable; Julia stdlib idiom |
| Boxing-safe parallel sum | Closure z `total += xs[i]` + `Threads.@threads` | Per-chunk `bufor[idx] = s` z chunked enumerate | Boxing trap (PITFALLS Pitfall 2) — silently 100x slower |
| Type-stability test framework | `@code_warntype` parsing w teście | `@inferred` (stdlib) + `JET.@test_opt` (CI gate) | `@inferred` zwraca wynik jeśli typy match, error jeśli nie — composable z `@testset` [CITED: docs.julialang.org/en/v1/stdlib/Test/] |
| Cross-Julia-version reproducibility | Hard-coded golden values z `Xoshiro(42)` | `StableRNG(42)` (StableRNGs.jl) | `Xoshiro` stream NIE jest gwarantowany stabilny między minor versions Julii (PITFALLS Pitfall 8) |

**Key insight:** Phase 2 ma **15-20 sublety mistakes** (boxing, in-place semantics, RNG sharing, 2-opt formula off-by-one) które są poprawnie zlokowane w CONTEXT.md. Don't-hand-roll lista upewnia się, że planner Phase 2 nie sięga po naive primitive zamiast używać już istniejących stabilnych narzędzi.

## Common Pitfalls

### Pitfall A: `@allocated` returns non-zero gdy testowane w global scope

**What goes wrong:** `@test (@allocated symuluj_krok!(stan, params, alg)) == 0` w global scope `runtests.jl` zgłasza non-zero alloc nawet gdy funkcja per-se jest zero-alloc — bo Julia musi alokować closure dla testu lub robi dispatch na global-typed `stan`/`alg`.

**Why it happens:** `@allocated` mierzy *cały blok wyrażenia* — w global scope obejmuje boxing dispatchu na non-const globalach.

**How to avoid:**
```julia
function _alloc_test_helper(stan, params, alg)
    return @allocated symuluj_krok!(stan, params, alg)
end

@testset "@allocated == 0 (TEST-03)" begin
    # setup
    punkty = generuj_punkty(20; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan)
    params = Parametry(liczba_krokow=100)

    # warmup (3 calls — Julia recompiles on first call regardless of warmup count;
    # 3 jest bezpieczną granicą dla parametric type instantiation)
    for _ in 1:3
        symuluj_krok!(stan, params, alg)
    end

    @test _alloc_test_helper(stan, params, alg) == 0
end
```

**Warning signs:** `@allocated == 0` failuje z liczbą jak 16 / 32 / 48 (typowy alloc closure boxing); switching do helpera `_alloc_test_helper` redukuje do 0.

### Pitfall B: `@inferred` widening na `Union{...}` returns

**What goes wrong:** Funkcja może być type-stable ale wynikowy typ to `Union{Float64, Nothing}` (np. early return) — `@inferred` failuje bo `Float64 != Union{Float64, Nothing}`.

**How to avoid:**
- **Trzymać single concrete return type per funkcja** (ARCHITECTURE.md type-stability rule 3).
- W razie potrzeby użyć `@inferred Union{Float64,Nothing} f(x)` — drugi argument relaxuje matching [CITED: docs.julialang.org/en/v1/stdlib/Test/].
- W Phase 2 wszystkie 4 publiczne funkcje (`oblicz_energie`, `delta_energii`, `symuluj_krok!`, `kalibruj_T0`) muszą zwracać konkretny typ:
  - `oblicz_energie(...) :: Float64`
  - `delta_energii(...) :: Float64`
  - `symuluj_krok!(...) :: Nothing` (return `nothing` explicitly!)
  - `kalibruj_T0(...) :: Float64`
  - `trasa_nn(...) :: Vector{Int}`

**Warning signs:** `@inferred` errors z message "return type X does not match inferred return type Union{X, Y}".

### Pitfall C: JET 0.9 `@test_opt` na funkcji z anonymous function lambda

**What goes wrong:** JET widzi anonymous funkcje (`x -> x*2` w map/filter) jako fresh-typed callable per call site — może zgłosić "runtime dispatch" gdy w rzeczywistości compiler i tak inline-uje.

**How to avoid:**
- **Użyć `target_modules=(@__MODULE__,)`** w `@test_opt` aby JET ignorował dispatchu w `Base`/`Core` i skupił się na własnym module:
  ```julia
  @test_opt target_modules=(JuliaCity,) oblicz_energie(D, trasa, bufor)
  ```
- Avoid anonymous lambdas w hot path — predykaty preferuj jako wcześniej-zdefiniowane funkcje.

**Warning signs:** JET zgłasza "no matching method" lub "runtime dispatch" w `Base.iterate` / `Base.broadcast` — szum z `Base`. `target_modules` filtruje ten szum.

### Pitfall D: TEST-04 multi-thread determinism — `stan.energia` różni się sub-ULP

**What goes wrong:** Test asercja `stan_1.energia == stan_n.energia` failuje z różnicą ~1e-15 (jeden ULP) bo chunked sum `oblicz_energie` jest non-associative dla floating-point — kolejność redukcji `sum(bufor)` zależy od liczby chunków (= `Threads.nthreads()`).

**How to avoid (resolved by D-12):**
- **`stan.trasa == stan_n.trasa`** asercja **bit-identyczna** (assertion na `==`) — bo trasa jest funkcją *decyzji* (RNG calls), które są deterministycznie sekwencyjne (D-09).
- **`stan.energia ≈ stan_n.energia` (rtol=1e-12)** — tolerujemy sub-ULP differ z chunked sum (D-12).

**Warning signs:** `@test stan_1.energia == stan_n.energia` failuje na CI z różnicą ~1e-13. Ten test trzeba przeformulować jako `≈` z rtol — nie zmieniać algorytmu.

### Pitfall E: `rand(StableRNG(42), Punkt2D, 20)` może być nieobsługiwane

**What goes wrong:** `Phase 1 generuj_punkty(n, rng::AbstractRNG)` używa `rand(rng, Punkt2D, n)`. **StableRNGs.jl oficjalnie dokumentuje wsparcie tylko dla stdlib numeric types**: `Bool, Int*, UInt*, Float16/32/64`, arrays of these, `rand(rng, ::AbstractArray)`. Custom typy jak `Point2{Float64}` (= `Punkt2D`) **nie są wymienione**. [CITED: github.com/JuliaRandom/StableRNGs.jl/blob/master/README.md]

**Real-world experience:** Discourse community-reported że `rand(StableRNG(1), Point2f, 10)` działa w praktyce — dispatch via `GeometryBasics`' `Random.SamplerType{Point2{T}}` schodzi do skalarnego `rand(rng, Float64)` dwa razy, co StableRNG **DOES** wspierać. [MEDIUM confidence — discourse only; nie zweryfikowane lokalnie]

**How to avoid:**
- **Wave 0 smoke test (planner Phase 2 musi to dodać):**
  ```julia
  # test_baselines.jl lub test_symulacja.jl, na samej górze:
  @testset "Wave 0: StableRNG ↔ Punkt2D smoke" begin
      using StableRNGs
      pkty = generuj_punkty(5, StableRNG(42))
      @test eltype(pkty) == Punkt2D
      @test length(pkty) == 5
      # determinizm
      @test generuj_punkty(5, StableRNG(42)) == generuj_punkty(5, StableRNG(42))
  end
  ```
- **Jeśli smoke test failuje:** modyfikacja `src/punkty.jl::generuj_punkty(n, rng)` na fallback comprehension `[Punkt2D(rand(rng, Float64), rand(rng, Float64)) for _ in 1:n]` — ten wzorzec używa **tylko skalarnego `rand(rng, Float64)`** który StableRNG na pewno wspiera. **JEDNAKŻE** to zmienia stream Xoshiro też (dwa skalarne calls vs jeden `rand(Punkt2D)`) — może przesuwać Phase 1 generuj_punkty test golden values. **Mitigation:** rozważyć drugi entry point `generuj_punkty_stable(n, rng)` używany tylko w testach, lub po prostu zmienić zarówno ścieżkę produkcyjną jak i Phase 1 testy.
- **Smoke test PRZED napisaniem golden-value w TEST-08** — bo wartości referencyjne muszą być generowane z tym samym kanonicznym `generuj_punkty(20, StableRNG(42))`.

**Warning signs:** `MethodError: no method matching rand(::StableRNG, ::Random.SamplerType{Point2{Float64}})` z Phase 1 testów po wprowadzeniu StableRNG fixture w Phase 2.

### Pitfall F: Aqua.jl `unbound_args` false positive na `StanSymulacji{R}`

**What goes wrong:** Aqua zgłasza "unbound type parameter R" dla `mutable struct StanSymulacji{R<:AbstractRNG}` w określonych dispatch patternach. Issue Aqua.jl#139 — open dla 0.8.x.

**How to avoid:**
- **NIE disable** `unbound_args` całkowicie. Zamiast tego użyć `broken=true` oznacza znaną niedoskonałość:
  ```julia
  Aqua.test_all(JuliaCity;
      ambiguities = (recursive=false,),                   # już w Phase 1
      stale_deps = false,                                  # Phase 1 — re-enable in Phase 4
      deps_compat = (ignore=[:Random],
                     check_extras=(ignore=[:Test, :Unicode],)),  # Phase 1
      unbound_args = (broken=true,),                       # NEW Phase 2 if false-positive
      # piracies = false,                                  # NIGDY — chcemy te wykrywać
  )
  ```
- **Tylko jeśli faktycznie failuje** — najpierw uruchom Aqua bez `unbound_args` override; jeśli czysto, zostaw bez override.

**Warning signs:** Aqua pokazuje `unbound_args: 1 violation: StanSymulacji{R<:AbstractRNG}`. To znana false-positive na parametric mutable structs — **nie** prawdziwy problem.

### Pitfall G: NN-baseline-beat fixture cost na CI (TEST-05)

**What goes wrong:** SA z `liczba_krokow=50_000` na N=1000 może zająć ~30-60s na CI (jeden seed). Razy 3 OS x 3 Julia = 9 jobs × ~45s = ~7 minut tylko na ten jeden test. CI timeouts/budgets są realne.

**How to avoid:**
- **Decyzja CONTEXT Claude's Discretion**: użyć `liczba_krokow=50_000` (default; spójność z `examples/`) **lub** `liczba_krokow=20_000` dla CI speed.
- **Estimate dla 20_000:** geometric cooling z α=0.9999 daje α^20_000 ≈ 0.135 (vs α^50_000 ≈ 0.0067). **Jakość trasy** przy 20k kroków:
  - SA z dobrą inicjalizacją NN startuje już z dobrego basena; 20k kroków zwykle wystarczy by zbić energię ≥10% pod NN dla N=1000 [MEDIUM confidence; ekstrapolacja z literatury PMC list-based SA].
  - **Ryzyko:** dla nietypowego `seed=42` może się zdarzyć że 20k jest borderline; wtedy test flakey-fails na CI.
- **Rekomendacja Phase 2:** Start z `liczba_krokow=20_000` w TEST-05; **jeśli failuje na CI**, podnieść do 50_000. Single seed test (seed=42) jest deterministyczny — albo zawsze pass albo zawsze fail. **Nie ma flakiness**, tylko binary outcome.
- Plan task: dodać benchmark step "TEST-05 czas na CI" w Wave późnej, by potwierdzić lub zwiększyć.

**Warning signs:** TEST-05 timeout na GitHub Actions runner. Konkretnie macOS-latest jest najwolniejszy z trójki.

## Code Examples

### Example 1: `oblicz_macierz_dystans!` (in-place D fill)

```julia
# Source: ARCHITECTURE.md Phase 1 D-08 + idiomatyczne Julia
"""
    oblicz_macierz_dystans!(stan::StanSymulacji)

Wypełnia pre-alokowaną `stan.D` (n×n) odległościami euklidesowymi między
wszystkimi parami punktów. Macierz symetryczna: D[i,j] == D[j,i]. D[i,i] == 0.

Wywoływane raz w `inicjuj_nn!` (Phase 2 init flow).
"""
function oblicz_macierz_dystans!(stan::StanSymulacji)
    n = length(stan.punkty)
    @assert size(stan.D) == (n, n) "D dimension mismatch"
    @inbounds for j in 1:n
        for i in 1:j-1
            p_i = stan.punkty[i]
            p_j = stan.punkty[j]
            dx = p_i[1] - p_j[1]
            dy = p_i[2] - p_j[2]
            d = sqrt(dx*dx + dy*dy)
            stan.D[i, j] = d
            stan.D[j, i] = d
        end
        stan.D[j, j] = 0.0
    end
    return nothing
end
```

### Example 2: `kalibruj_T0` (D-03)

```julia
# Source: CONTEXT D-03 (locked) + PITFALLS Pitfall 11 recipe (T₀ = 2σ_worsening)
"""
    kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng) -> Float64

Sample 1000 random 2-opt par (i, j), oblicz Δ-energie, zwróć T₀ = 2σ
spośród *worsening* delts (δ > 0).

Pure funkcja — używa `delta_energii(stan, i, j)`. Wymaga że `stan.D` jest wypełniona
(czyli wywołujemy PO `oblicz_macierz_dystans!` / `inicjuj_nn!`).
"""
function kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng)
    n = length(stan.trasa)
    worsening = Float64[]                                  # alloc — wywoływana raz, OK
    sizehint!(worsening, n_probek)                          # avoid resize
    for _ in 1:n_probek
        i = rand(rng, 1:(n - 1))
        j = rand(rng, (i + 2):n)
        delta = delta_energii(stan, i, j)
        if delta > 0.0
            push!(worsening, delta)
        end
    end
    @assert !isempty(worsening) "no worsening moves sampled"
    sigma = std(worsening)                                  # using Statistics
    return 2.0 * sigma
end
```

**Note:** `kalibruj_T0` używa `Statistics.std` — **NIE** jest w Phase 1 deps. Plan Phase 2 musi:
1. Albo dodać `Statistics` jako stdlib do `[deps]` (idiomatic Julia — stdlib też trafia do deps gdy używana w `src/`).
2. Albo policzyć `std` ręcznie: `mean = sum(worsening) / length(worsening); sigma = sqrt(sum((x - mean)^2 for x in worsening) / (length(worsening) - 1))`.

Rekomendacja: **dodać `Statistics`** — jest stdlib (wpis w `[deps]` bez compat), zero kosztu, idiomatic.

### Example 3: TEST-04 multi-thread determinism z subprocess

```julia
# test/test_symulacja.jl, dla TEST-04
# Source: juliatesting.github.io/PerformanceTestTools.jl
using PerformanceTestTools

# pomocniczy script — zapisuje wynik do tymczasowego pliku
sa_run_script = """
using JuliaCity, Random, Serialization
punkty = generuj_punkty(1000; seed=42)
stan = StanSymulacji(punkty; rng=Xoshiro(42))
inicjuj_nn!(stan)
alg = SimAnnealing(stan)
params = Parametry(liczba_krokow=20_000)
for _ in 1:params.liczba_krokow
    symuluj_krok!(stan, params, alg)
end
out_path = ENV["JC_OUT"]
serialize(out_path, (trasa=stan.trasa, energia=stan.energia))
"""

# zapisz do mktemp script + run twice
script_path = tempname() * ".jl"
write(script_path, sa_run_script)
out_1 = tempname() * ".jls"
out_n = tempname() * ".jls"

@testset "multi-thread determinism (TEST-04)" begin
    PerformanceTestTools.@include_foreach(
        script_path,
        [
            ["JULIA_NUM_THREADS" => "1", "JC_OUT" => out_1],
            ["JULIA_NUM_THREADS" => "8", "JC_OUT" => out_n],
        ]
    )
    r1 = deserialize(out_1)
    rn = deserialize(out_n)
    @test r1.trasa == rn.trasa                              # bit-identical (D-12)
    @test isapprox(r1.energia, rn.energia; rtol=1e-12)      # sub-ULP tolerance (D-12)
end
```

**Caveats:**
- `PerformanceTestTools.@include_foreach` jest w **Phase 2 testowych deps** — dodać do `[extras]+[targets]`. UUID: `juliatesting/PerformanceTestTools.jl`.
- Subprocess overhead: ~10s startup (precompile JuliaCity) × 2 runs = ~20s extra na CI. Akceptowalne dla pojedynczego testu.
- **Alternatywa (lower-fidelity):** w-process test "trasa jest jednoznaczną funkcją (master_seed, n, alg)" — uruchomić SA dwa razy w **tym samym procesu** z dwóch świeżych state'ów, asercja `==`. To NIE testuje threadingu, ale daje poziom pewności w **single-threaded** wykonaniu. Rekomendacja: **mieć obie**.

### Example 4: Aqua.test_all dla Phase 2

```julia
# test/runtests.jl, sekcja "Aqua.jl quality" (rozszerzona z Phase 1)
@testset "Aqua.jl quality (TEST-06)" begin
    Aqua.test_all(JuliaCity;
        # ambiguities — recursive scan w pakiecie i deps
        ambiguities = (recursive = false,),               # Phase 1 wzorzec; tighten w Phase 4 jeśli czysto
        # piracies — NIGDY nie disable; jeśli false-positive, użyj treat_as_own
        # piracies = ...
        # stale_deps — Phase 1 disabled bo GLMakie/Makie/Observables w [compat] ale nie [deps] do Phase 3
        stale_deps = false,                                # TODO Phase 4: re-enable po dodaniu BenchmarkTools do [deps]
        # deps_compat — stdlib (Random, Test, Unicode) NIE wymaga compat; ignoruj te
        deps_compat = (ignore = [:Random],
                       check_extras = (ignore = [:Test, :Unicode],)),
        # unbound_args — Phase 2 NEW: jeśli StanSymulacji{R} flaguje false-positive (Pitfall F)
        # unbound_args = (broken = true,),                 # uncomment po pierwszym uruchomieniu jeśli failuje
    )
end
```

**Note:** Phase 2 dodaje `ChunkSplitters` do `[deps]` — **wpis do `[compat]`**: `ChunkSplitters = "3"`. Aqua's `deps_compat` to wykryje automatycznie i zaakceptuje, ponieważ `ChunkSplitters` ma compat entry.

### Example 5: JET TEST-07 — `@test_opt` z target_modules

```julia
# test/runtests.jl, sekcja "JET smoke" rozszerzona dla TEST-07
@testset "JET type stability (TEST-07)" begin
    # fixture
    punkty = generuj_punkty(20; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    alg = SimAnnealing(stan)
    params = Parametry(liczba_krokow=100)
    bufor = zeros(Float64, Threads.nthreads())

    # warmup (JET analizuje skompilowany kod — warmup nie jest STRICT wymagany,
    # ale gwarantuje że typy są stabilne nawet po pierwszej kompilacji)
    oblicz_energie(stan.D, stan.trasa, bufor)
    delta_energii(stan, 5, 17)
    symuluj_krok!(stan, params, alg)
    kalibruj_T0(stan; n_probek=10)

    # @test_opt failuje testset jeśli JET znajdzie type-instability w **JuliaCity** module
    # target_modules — tylko nasz kod, nie Base/Core/stdlib szum
    @test_opt target_modules=(JuliaCity,) oblicz_energie(stan.D, stan.trasa, bufor)
    @test_opt target_modules=(JuliaCity,) delta_energii(stan, 5, 17)
    @test_opt target_modules=(JuliaCity,) symuluj_krok!(stan, params, alg)
    @test_opt target_modules=(JuliaCity,) kalibruj_T0(stan; n_probek=10)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Threads.threadid()`-indexed buffers | `ChunkSplitters.chunks` z `enumerate` | Julia ≥ 1.12 (threadid niestabilne dla migracji) | Phase 2 używa ChunkSplitters z dnia 1 — żadnej migracji w przyszłości |
| `@report_opt` + manual `isempty(get_reports(...))` | `@test_opt` | JET 0.7+ (~2024) | Krótsze, automatyczne testset failure |
| Hand-rolled subprocess for thread-test | `PerformanceTestTools.@include_foreach` | PerformanceTestTools.jl ~2022 | Single import, wbudowany pattern |
| `Random.MersenneTwister(42)` w testach | `StableRNGs.StableRNG(42)` | StableRNGs.jl ~2020 | Cross-Julia-version stable streams |
| `Vector{Vector{Float64}}` per-thread buffers | Pre-alokowany `Vector{Float64}(undef, nchunks)` | Idiomatic Julia (PITFALLS Pitfall 2 + ARCHITECTURE.md type-stability) | Single alloc per `oblicz_energie` call (≤4096 B per ENE-03) |

**Deprecated/outdated:**
- **JET 0.11.x** w Julia 1.10/1.11: niezgodne (JET 0.11 wymaga Julia 1.12). Phase 2 trzyma JET 0.9 — to jest current dla Julia 1.10 LTS.
- **`MersenneTwister`** dla deterministic testów: `StableRNG` jest wymagane dla cross-version reproducibility (PITFALLS Pitfall 8). `Xoshiro` jest fine dla **runtime** ale NIE dla golden values.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `rand(StableRNG(42), Punkt2D, 20)` działa via GeometryBasics' Random.SamplerType dispatch | Pitfall E, Pattern 3 (TEST-08) | **MEDIUM-HIGH** — TEST-08 i Wave 0 smoke test wymagają tego. Mitigated przez Wave 0 task: jeśli failuje, planner musi przewidzieć fallback w `src/punkty.jl::generuj_punkty(n, rng)`. |
| A2 | `liczba_krokow=20_000` wystarczy by SA pobił NN o ≥10% dla N=1000 seed=42 | Pitfall G (TEST-05) | LOW — można podnieść do 50_000 jeśli failuje. Single binary outcome (deterministic), nie flaky. |
| A3 | Aqua 0.8.x `unbound_args` zgłasza false-positive na `StanSymulacji{R<:AbstractRNG}` | Pitfall F | LOW — jeśli NIE zgłasza, nic robić; jeśli zgłasza, dodać `unbound_args=(broken=true,)`. |
| A4 | ChunkSplitters z `Threads.@threads :static` + `Consecutive()` (default) split jest właściwy dla `oblicz_energie` | Pattern 1, D-11 | LOW — uniform work per krawędź; nawet jeśli `RoundRobin()` jest ~10% szybszy, Phase 4 benchmark to wykryje. Phase 2 nie zmienia. |
| A5 | `Statistics.std` jest dostępne przez `using Statistics` w `src/energia.jl` (stdlib, brak compat entry) | Example 2 (kalibruj_T0) | LOW — stdlib jest gwarantowany dla Julia 1.10+. |

## Open Questions (RESOLVED)

1. **`ChunkSplitters.Consecutive()` vs `RoundRobin()` dla `oblicz_energie`**
   - What we know: `Consecutive()` jest default; `RoundRobin()` zalecany dla nieregularnej pracy w `:static`. `oblicz_energie` ma uniform work.
   - What's unclear: Czy lookup `D[trasa[k], trasa[mod1(k+1, n)]]` ma cache miss patterns które różnicują workload per chunk?
   - Recommendation: Default `Consecutive()` w Phase 2; benchmark obu w Phase 4 (`bench_energia.jl`).

2. **Czy `inicjuj_nn!` powinno tworzyć fresh `bufor` czy używać tego z konstruktora**
   - What we know: CONTEXT D-10 trzyma `bufor::Vector{Float64}` jako argument funkcji, nie pole structu.
   - What's unclear: Gdzie przeżywa `bufor`? `inicjuj_nn!` musi zaalokować ten lokalnie (alloc OK — wywoływane raz). Hot path SA NIE używa `oblicz_energie` (D-08 cache pattern), więc `bufor` jest potrzebne TYLKO w `inicjuj_nn!` + final assertion test.
   - Recommendation: lokalna alokacja w obu use sites. Brak shared bufora przez Phase 2.

3. **Powinno `liczba_krokow` w TEST-04 być takie samo jak w TEST-05?**
   - What we know: TEST-04 sprawdza determinizm (same seed → same trasa), niezależnie od jakości; nie wymaga "≥10% pod NN". TEST-05 sprawdza jakość. To dwa niezależne testy.
   - What's unclear: Czy ekonomicznie sensowne uruchomić te same 20_000 kroków dla obu, czy TEST-04 może być krótszy (np. 5_000) dla CI speed?
   - Recommendation: TEST-04 z `liczba_krokow=5_000` (determinizm sprawdzalny szybciej; nie wymaga konwergencji). TEST-05 z `liczba_krokow=20_000` (lub 50_000 jeśli niewystarczające). To dwa niezależne fixturey.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Julia 1.10+ | Wszystko | ✓ | 1.10+ assumed (Phase 1 verified) | — (compat hard floor) |
| ChunkSplitters.jl | `oblicz_energie` (D-11) | ✓ (registered, current 3.2.0) | 3.2.0 | OhMyThreads.tmapreduce — alternative; planner unlikely to switch |
| StableRNGs.jl | TEST-08 golden value | ✓ (Phase 1 [extras]) | 1.0.x | Hard fallback w `src/punkty.jl` (skalarne `rand(rng, Float64)`) — patrz Pitfall E |
| Statistics (stdlib) | `kalibruj_T0` | ✓ (stdlib, Julia 1.10+) | bundled | Manual std computation (formula explicit) |
| PerformanceTestTools.jl | TEST-04 multi-thread test | ✗ (NOT yet in [extras]) | Latest registered | In-process determinism test (lower fidelity) |

**Missing dependencies with no fallback:** żadne — wszystko ma fallback.

**Missing dependencies with fallback:**
- `PerformanceTestTools.jl` — Phase 2 plan musi dodać do `[extras]` + `[targets]`. UUID musi być zweryfikowane (planner uruchomi `Pkg.add("PerformanceTestTools")` + odczyta UUID z Project.toml).

## Validation Architecture

> Phase 2 jest fazą kompleksowego budowania test suite — jest to dosłownie celem fazy.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `Test` stdlib (Julia 1.10+, bundled) + Aqua 0.8.14 + JET 0.9 + StableRNGs 1.0 + PerformanceTestTools (NEW) |
| Config file | `test/runtests.jl` (orchestrator); `test/Project.toml` is implicit z `[extras]` w głównym Project.toml |
| Quick run command | `julia --project=. -e 'using Pkg; Pkg.test()'` (wszystkie testy) |
| Single-file run | `julia --project=. -e 'using JuliaCity, Test; include("test/test_energia.jl")'` |
| Full suite command | `julia --project=. -e 'using Pkg; Pkg.test()'` (full Pkg.test sandbox) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| ENE-01 | `oblicz_energie(punkty, trasa)` zwraca długość cyklu Hamiltona | unit | `julia --project=. -e 'include("test/test_energia.jl")'` | ❌ Wave 0 |
| ENE-02 | type-stable (`@inferred`) | unit + JET | jak wyżej | ❌ Wave 0 |
| ENE-03 | `@allocated < 4096 B` po rozgrzewce | unit | jak wyżej | ❌ Wave 0 |
| ENE-04 | `delta_energii` O(1), zero-alloc | unit | jak wyżej | ❌ Wave 0 |
| ENE-05 | `Threads.@threads :static` + ChunkSplitters | structural | grep on src/energia.jl + smoke run | ❌ Wave 0 |
| ALG-01 | `struct SimAnnealing <: Algorytm` z (T₀, α, cierpliwosc) | unit | `include("test/test_symulacja.jl")` | ❌ Wave 0 |
| ALG-02 | `symuluj_krok!` mutuje stan in-place | unit | jak wyżej | ❌ Wave 0 |
| ALG-03 | `@allocated == 0` po rozgrzewce | unit | jak wyżej | ❌ Wave 0 |
| ALG-04 | `trasa_nn` używana jako start + baseline | unit + integ | `include("test/test_baselines.jl")` | ❌ Wave 0 |
| ALG-05 | T₀ = 2σ z 1000 worsening delts | unit | `include("test/test_symulacja.jl")` | ❌ Wave 0 |
| ALG-06 | stagnation patience stop | unit | jak wyżej | ❌ Wave 0 |
| ALG-07 | per-thread RNG (interpretowane jako D-09 — single master seed → identical trajectory) | integ | TEST-04 (multi-thread determinism) | ❌ Wave 0 |
| ALG-08 | Hamilton invariant po każdym kroku | unit | TEST-01 | ❌ Wave 0 |
| TEST-01 | `sort(stan.trasa) == 1:n` po każdym kroku | unit | `include("test/test_symulacja.jl")` | ❌ Wave 0 |
| TEST-02 | `@inferred` na publicznym API | unit | included | ❌ Wave 0 |
| TEST-03 | `@allocated == 0` na `symuluj_krok!` | unit | included | ❌ Wave 0 |
| TEST-04 | multi-thread determinism (subprocess) | integ | `include("test/test_symulacja.jl")` (uses PerformanceTestTools) | ❌ Wave 0 |
| TEST-05 | NN-baseline-beat ≥ 10% | integ | `include("test/test_baselines.jl")` | ❌ Wave 0 |
| TEST-06 | Aqua.test_all clean | smoke | `include("test/runtests.jl")` (top-level @testset) | ❌ Wave 0 (extends Phase 1 stub) |
| TEST-07 | JET `@test_opt` clean | smoke | jak wyżej | ❌ Wave 0 (extends Phase 1 smoke) |
| TEST-08 | golden-value `StableRNG(42)` na N=20 | unit | `include("test/test_symulacja.jl")` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `julia --project=. -e 'using JuliaCity, Test; include("test/test_<bieżący_plik>.jl")'` (tylko aktualnie modyfikowany plik testowy — szybki feedback)
- **Per wave merge:** `julia --project=. -e 'using Pkg; Pkg.test()'` (full Pkg.test — wszystkie 8 testsetów + Aqua + JET)
- **Phase gate:** Full suite green PRZED `/gsd-verify-work`. CI matrix (3 OS × 3 Julia) musi być zielona.

### Wave 0 Gaps

- [ ] `test/test_energia.jl` — pokrywa ENE-01..05, częściowo TEST-02/03 (pure functions)
- [ ] `test/test_symulacja.jl` — pokrywa ALG-01..08, TEST-01/04/08 (SA hot path)
- [ ] `test/test_baselines.jl` — pokrywa ALG-04 częściowo (NN init wrapper) + TEST-05 (NN-baseline-beat)
- [ ] `test/runtests.jl` — rozszerzyć: `include("test_energia.jl")`, `include("test_symulacja.jl")`, `include("test_baselines.jl")`; rozszerzyć Aqua testset; przekształcić JET smoke w pełen `@test_opt`
- [ ] **Wave 0 smoke test** w `test/test_baselines.jl` lub `test_symulacja.jl`: `rand(StableRNG(42), Punkt2D, 5)` works — patrz Pitfall E (A1)
- [ ] `Project.toml`: dodać `ChunkSplitters` do `[deps]` + `[compat] = "3"`
- [ ] `Project.toml`: dodać `Statistics` do `[deps]` (stdlib, brak compat entry)
- [ ] `Project.toml`: dodać `PerformanceTestTools` do `[extras]` + `[targets].test`
- [ ] `src/JuliaCity.jl`: dodać `using ChunkSplitters: chunks` lub w `src/energia.jl`; rozszerzyć export

## Project Constraints (from CLAUDE.md)

CLAUDE.md (świeżo dodany 2026-04-29) zawiera następujące dyrektywy istotne dla Phase 2 — planner MUSI je honorować:

- **Tech stack:** Julia + GLMakie. Phase 2 nie używa GLMakie (locked headless), ale następne fazy będą.
- **Język UI/komentarzy: wyłącznie polski.** Wszystkie komentarze, docstring (oprócz `Source:` URL-i), nazwy zmiennych. Wyjątek: asercje wewnętrzne (`@assert ... "msg"`) po angielsku per LANG-04.
- **Struktura modułowa, mandated functions:** `generuj_punkty()` ✓, `oblicz_energie()` ← Phase 2 dodaje, `symuluj_krok!()` ← Phase 2 dodaje, `wizualizuj()` ← Phase 3.
- **Reprodukowalność:** domyślny seed PRNG. Phase 2: TEST-08 + TEST-04 + TEST-05 wszystkie używają deterministycznych seedów (StableRNG(42), Xoshiro(42)).
- **GSD Workflow Enforcement:** wszystkie zmiany w `src/` i `test/` muszą iść przez GSD command (Phase 2 to `/gsd-execute-phase 2`). Researcher faza nie modyfikuje kodu, tylko produkuje RESEARCH.md.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENE-01 | `oblicz_energie(punkty, trasa)::Float64` — długość cyklu Hamiltona | Pattern 1 (chunked sum), Example 1 (oblicz_macierz_dystans!) |
| ENE-02 | Type-stable | Pitfall B (@inferred + Union widening), Example 5 (JET @test_opt) |
| ENE-03 | `@allocated < 4096 B` po rozgrzewce | Pitfall A (warmup pattern + helper function), CONTEXT D-10 (bufor as arg) |
| ENE-04 | `delta_energii` O(1), zero-alloc, bez kopiowania trasy | CONTEXT D-06/D-08 (4 D-lookups + mod1), Pattern 2 |
| ENE-05 | `Threads.@threads :static` na chunkach krawędzi | Pattern 1 (ChunkSplitters), Don't Hand-Roll table |
| ALG-01 | `abstract type Algorytm end` + `struct SimAnnealing <: Algorytm` (T₀, α, cierpliwosc) | Phase 1 dziedziczone (typy.jl); CONTEXT D-01..D-04 |
| ALG-02 | `symuluj_krok!(stan, params, alg::SimAnnealing)` — Metropolis + 2-opt + cooling | Pattern 2, Example 3 |
| ALG-03 | `@allocated == 0` | Pitfall A; tighter wariant ENE-03 (zero, nie <4096) |
| ALG-04 | `trasa_nn(punkty)` używana jako start + baseline | Pattern 3 (dual entry-points: trasa_nn + inicjuj_nn!) |
| ALG-05 | T₀ kalibrowane z 1000 random delts (T₀ = 2σ) | Example 2 (kalibruj_T0) |
| ALG-06 | Stagnation patience stop | CONTEXT D-04 (reset tylko przy Δ<0); planner musi dodać `licznik_bez_poprawy::Int` lokalnie w `symuluj_krok!` (NIE pole `Stan` — Phase 1 D-06 lock) lub dorzucić jako pole w `Parametry` (krytyczne: counter zaktualizowany po teście Δ<0). Rekomendacja: counter w **closure scope outer loop** (nie pole `Stan`/`Parametry`), bo `symuluj_krok!` to JEDEN krok — outer loop w `examples/`/test owns stop logic. |
| ALG-07 | "per-thread RNG zbudowany deterministycznie z master seeda" — interpretowane przez D-09 jako "single master seed → identical trajectory" | Pitfall D (multi-thread determinism), Example 3 (TEST-04 subprocess) |
| ALG-08 | Hamilton invariant po każdym kroku | Pattern 2 (reverse! view zachowuje permutację), Pitfall D-12 |
| TEST-01 | `@testset` Hamilton invariant | Example sketch — `for k in 1:N; symuluj_krok!(...); @test sort(stan.trasa) == 1:n; end` |
| TEST-02 | `@testset` `@inferred` | Pitfall B; Example 5 |
| TEST-03 | `@testset` `@allocated == 0` na `symuluj_krok!` | Pitfall A (warmup helper) |
| TEST-04 | `@testset` determinizm wieloraetkowy | Example 3 (PerformanceTestTools.@include_foreach) |
| TEST-05 | `@testset` SA ≥ 10% pod NN | Pitfall G (CI cost balance); Pattern 3 (trasa_nn baseline) |
| TEST-06 | `@testset` Aqua.test_all | Example 4 (extended Phase 1 stub) |
| TEST-07 | `@testset` JET `@report_opt` clean | Example 5 (use @test_opt instead, target_modules) |
| TEST-08 | golden-value `StableRNG(42)` na N=20 | CONTEXT D-17 (fixture pattern); Pitfall E (A1 + Wave 0 smoke) |

## Sources

### Primary (HIGH confidence)
- [ChunkSplitters.jl Project.toml](https://github.com/JuliaFolds2/ChunkSplitters.jl/blob/main/Project.toml) — UUID `ae650224-84b6-46f8-82ea-d812ca08434e`, version 3.2.0, `julia = "1.10"`
- [ChunkSplitters Multithreading docs](https://juliafolds2.github.io/ChunkSplitters.jl/stable/multithreading/) — canonical `@threads :static for (i,c) in enumerate(chunks(...))` pattern, `Consecutive()` vs `RoundRobin()` tradeoffs
- [JET.jl Project.toml master](https://github.com/aviatesk/JET.jl/blob/master/Project.toml) — current 0.11.3 requires Julia 1.12; **0.9 series for Julia 1.10/1.11**
- [JET Optimization Analysis docs](https://aviatesk.github.io/JET.jl/dev/optanalysis/) — `@test_opt` vs `@report_opt` semantics, `target_modules` pattern
- [Test stdlib @inferred](https://docs.julialang.org/en/v1/stdlib/Test/) — semantics, Union widening with optional `AllowedType`
- [PerformanceTestTools.jl docs](https://juliatesting.github.io/PerformanceTestTools.jl/dev/) — `@include_foreach` pattern z env override
- [Aqua.jl docs (test_all)](https://juliatesting.github.io/Aqua.jl/dev/test_all/) — kwargs list and per-subcheck NamedTuple syntax
- [.planning/PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md] — locked decisions, requirements, milestones
- [.planning/research/PITFALLS.md] — Pitfall 2 (closure boxing), 8 (StableRNG), 11 (cooling), 15 (Aqua), 16 (BenchmarkTools)
- [.planning/research/ARCHITECTURE.md] — Holy-traits dispatch, parametric Stan, threading-inside-only, type stability
- [.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md] — Phase 1 D-01..D-25 inherited
- [.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md] — locked D-01..D-17 dla Phase 2

### Secondary (MEDIUM confidence)
- [Discourse: rand custom types](https://discourse.julialang.org/t/can-rand-generate-random-vectors-with-custom-type-entries/107028) — pattern `Random.SamplerType{T}` dla custom `rand` dispatch
- [WebSearch: StableRNG + Point2 community-reported](https://discourse.julialang.org/) — `rand(StableRNG(1), Point2f, 10)` reportedly works; not verified locally — Wave 0 smoke test resolves
- [JuliaLang October 2025 blog](https://julialang.org/blog/2025/11/this-month-in-julia-world/) — JET 0.11 announcement (only relevant if upgrading to Julia 1.12)
- [Discourse: Julia threads boxing](https://discourse.julialang.org/t/type-instability-because-of-threads-boxing-variables/78395) — boxing trap evidence
- [GitHub issue: Aqua.jl#139](https://github.com/JuliaTesting/Aqua.jl/issues/139) — open false-positive on parametric structs (referenced in Pitfall F)

### Tertiary (LOW confidence — heuristic / extrapolation)
- A2 (`liczba_krokow=20_000` wystarczy dla 10% beat) — extrapolacja z PMC list-based SA paper; deterministic single-seed test, nie flaky
- A4 (ChunkSplitters `Consecutive()` vs `RoundRobin()` dla `oblicz_energie`) — Phase 4 benchmark to potwierdzi

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — wszystkie wersje i UUID zweryfikowane przez oficjalne Project.toml na GitHub.
- Architecture: HIGH — CONTEXT.md i Phase 1 zlokowały kształt; ten dokument nie wprowadza nowych decyzji architektonicznych.
- Pitfalls: HIGH dla A,B,D,F,G; MEDIUM dla C (JET 0.9 specific behavior); MEDIUM dla E (StableRNG ↔ Punkt2D — community evidence).
- Test patterns: HIGH dla `@test_opt`/`@inferred`; HIGH dla `PerformanceTestTools.@include_foreach`; MEDIUM dla optimal `liczba_krokow` w TEST-05.

**Research date:** 2026-04-29
**Valid until:** ~2026-05-29 (30 days for stable Julia ecosystem; ChunkSplitters/JET/Aqua versions stable; if Julia 1.13 ships < this date, re-verify JET pin).

---

*Phase 2 research: filled technical gaps; CONTEXT.md owns design decisions.*
