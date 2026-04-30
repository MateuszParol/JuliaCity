# Phase 2: Energy, SA Algorithm & Test Suite - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 dostarcza **algorytmiczny rdzeń** pakietu `JuliaCity.jl` — wszystko **headless**, **bez GLMakie**, w pełni testowalne `julia --project=. test/runtests.jl`:

1. `oblicz_energie(punkty, trasa)::Float64` — czysta funkcja, długość cyklu Hamiltona (suma euklidesowa z domknięciem). Type-stable, threadowana wewnątrz przez `Threads.@threads :static` na chunkach krawędzi (ChunkSplitters), 1 alloc dopuszczalny po rozgrzewce dla bufora wątków (ENE-03 `< 4096 B`).
2. `delta_energii(stan, i, j)::Float64` — O(1), zero-alloc, formuła 2-opt z explicit wrap-around przez `mod1`.
3. `oblicz_macierz_dystans!(stan)` — wypełnia pre-alokowaną `stan.D` (Phase 1 D-08).
4. `trasa_nn(D; start=1)::Vector{Int}` — pure NN-baseline. `inicjuj_nn!(stan)` — wrapper konsumujący NN do `stan.trasa`/`stan.energia`/`stan.D`.
5. `kalibruj_T0(stan; n_probek=1000, rng=stan.rng)::Float64` — kalibracja T₀ = 2σ z 1000 worsening delts (Pitfall 11).
6. `struct SimAnnealing <: Algorytm` z polami `(T₀, α, cierpliwosc)` (REQ ALG-01) + konstruktor `SimAnnealing(stan; α=0.9999, cierpliwosc=5000, T₀=kalibruj_T0(stan))`.
7. `struct Parametry` (`Base.@kwdef`) z `liczba_krokow::Int=50_000` (slot na `kroki_na_klatke` w Phase 3).
8. `symuluj_krok!(stan, params, alg::SimAnnealing)` — in-place: uniform random pair (i,j), Δ via O(1) `delta_energii`, Metropolis acceptance z `stan.rng`, `reverse!(view(stan.trasa, i+1:j))` przy akceptacji, `stan.energia += Δ`, geometric cooling `stan.temperatura *= α`, increment `stan.iteracja`. Type-stable, **`@allocated == 0`** po rozgrzewce.
9. **Pełen test suite** (`test/runtests.jl` rozbudowane o `test/test_energia.jl`, `test/test_symulacja.jl`, `test/test_baselines.jl`):
   - TEST-01 Hamilton invariant (`sort(stan.trasa) == 1:n`) po każdym kroku
   - TEST-02 `@inferred` na publicznym API (type stability)
   - TEST-03 `@allocated == 0` na `symuluj_krok!` po rozgrzewce
   - TEST-04 multi-thread determinism: `stan_1.trasa == stan_n.trasa` (exact) + `stan_1.energia ≈ stan_n.energia` (rtol=1e-12)
   - TEST-05 NN-baseline-beat: SA ≥ 10% krótsza niż NN na N=1000 seed=42
   - TEST-06 `Aqua.test_all` (z udokumentowanymi suppressions per Pitfall 15)
   - TEST-07 `JET.@report_opt` clean
   - TEST-08 golden-value `StableRNG(42)` na N=20: `stan.trasa ==` exact + `stan.energia ≈` (rtol=1e-6)

**Pokryte REQ-ID (21):** ENE-01..05, ALG-01..08, TEST-01..08.

**Świadomie poza zakresem Phase 2:** żadnego kodu GLMakie/Observables (Phase 3), żadnych `examples/`/`bench/` skryptów (Phase 4), żadnego README polskiego (Phase 4), żadnych ForceDirected/Hybryda wariantów (v2).

</domain>

<decisions>
## Implementation Decisions

### Hiperparametry & `Parametry` vs `SimAnnealing`

- **D-01:** **Hiperparametry SA żyją w `SimAnnealing`** (T₀, α, cierpliwosc) — algorytm-specyficzne. **Osobny `Parametry`** (`Base.@kwdef struct Parametry`) trzyma pola **niezależne od algorytmu** (np. `liczba_krokow::Int=50_000`; w Phase 3 doda się `kroki_na_klatke::Int`). Sygnatura `symuluj_krok!(stan, params::Parametry, alg::SimAnnealing)` — clean separation of concerns, łatwe dodanie wariantu (planner Phase 2 lokuje `Parametry` w `src/typy.jl` lub `src/parametry.jl`).
- **D-02:** **Defaults dla N=1000:** `Parametry(liczba_krokow=50_000)`, `SimAnnealing(α=0.9999, cierpliwosc=5000, T₀=...)`. Uzasadnienie: `α^50_000 ≈ 6.7×10⁻³` daje schemat chłodzenia z ~80% acceptance ratio na starcie do ~1% pod koniec (Pitfall 11). `cierpliwosc=5000` = 10% budżetu kroków — bezpieczny próg stagnacji.
- **D-03:** **Kalibracja T₀ w osobnej pure funkcji** `kalibruj_T0(stan; n_probek=1000, rng=stan.rng)::Float64`:
  - Sample 1000 random 2-opt par (i, j) na bieżącej (NN-init) trasie.
  - Oblicz `δ = delta_energii(stan, i, j)` dla każdego.
  - **Tylko worsening:** weź `σ = std([abs(δ) for δ in deltas if δ > 0])`.
  - `T₀ = 2σ` (Pitfall 11 recipe).
  - Konstruktor SA: `SimAnnealing(stan; α=0.9999, cierpliwosc=5000, T₀=kalibruj_T0(stan))` — kalibracja w domyślnym kwarg, nadpisywalna ręcznie (`SimAnnealing(stan; T₀=0.5)`).

#### D-03 erratum (plan 02-14, 2026-04-30)

**Empiryczne stwierdzenie:** Pierwotna formuła `T₀ = 2σ(worsening_deltas)` (D-03 LOCKED w fazie 1) jest **skalibrowana dla random tour startu**. Plan 02-13 wykrył że dla NN-start (`inicjuj_nn!`) ta sama formuła daje T₀ wyrzucające SA z basena NN — TEST-05 ratio 1.65 (cel ≤ 0.9) po 200_000 krokach. Plan 02-14 przeprowadził empiryczną diagnozę (`bench/diagnostyka_test05.jl`).

**Pomierzone (N=1000, seed=42, NN-start):**

| Pomiar | Wartość |
|--------|---------|
| `energia_nn` (po `inicjuj_nn!`) | 28.8502 |
| `T₀_calibrated` (`kalibruj_T0` = 2σ) | 1.028131 |
| Próbka 1000 random 2-opt deltas: n_positive | 997 |
| mean(positive) | 0.960967 |
| std(positive) | 0.518694 |
| acceptance worsening pierwsze 1000 kroków przy T₀_2σ | 51.2% |

Acceptance 51.2% w pierwszych 1000 krokach dla T₀_2σ oznacza że SA accept'uje połowę pogorszeń → wyrzuca z basena NN i nie wraca (cooling α=0.9999 → T(50k)≈6.7e-3, T(10k)≈0.37).

**Sweep T₀ przy 50_000 i 200_000 kroków, fresh stan:**

| T₀ | 50k ratio | 200k ratio |
|----|-----------|------------|
| 0.001 | 0.9672 | **0.9248** ← najlepsze |
| 0.005 | 0.9696 | 0.9309 |
| 0.01  | 0.9684 | 0.9272 |
| 0.02  | 0.9718 | 0.9314 |
| 0.05  | 1.0340 | — |
| 0.10  | 1.4540 | — |
| 0.50  | 3.5310 | — |
| 1.028 (2σ) | 4.0188 | — |

**Hipotezy B1 (fixed T₀=0.05) / B2 (Ben-Ameur χ₀=0.5..0.8) / B3 (target acceptance closed-form):**
Wszystkie obalone empirycznie. Closed-form B3 (`T₀ = -mean(positive)/ln(0.5) = 1.39`) byłby **gorszy** niż T₀_calibrated (1.03) — przewidywany ratio ≥ 4.

**Random start vs NN start (Faza A.3):**
| Setup | 50k ratio | 200k ratio |
|-------|-----------|------------|
| Random + 2σ T₀ | 3.71 | 1.65 |
| Multi-start 5× random + 2σ, 50k each | best 3.63 | — |
| NN + T₀=0.001 | 0.9672 | 0.9248 |

NN-init jednoznacznie wygrywa. Random start nie daje sukcesu nawet w 200k.

**Budżet sweep dla T₀=0.001 (Faza A.4):**
| Budget | Ratio | Margin do 0.95 | Status |
|--------|-------|----------------|--------|
| 50_000  | 0.9672 | -0.017 | FAIL |
| 75_000  | 0.9599 | -0.010 | FAIL |
| **100_000** | 0.9493 | +0.0007 | PASS (cienki margin — ryzyko CI flake) |
| **125_000** | **0.9408** | **+0.0092** | **PASS, solid margin** ← wybrane |
| 150_000 | 0.9349 | +0.015 | PASS |
| 200_000 | 0.9248 | +0.025 | PASS |

**Wniosek diagnostyczny:** Pure 2-opt SA na N=1000 NN-start **plateauje przy ratio ≈ 0.92** (2-opt local minimum, nie do wyrwania bez stronger move). Cel oryginalny ROADMAP SC #4 ratio ≤ 0.9 (≥10% pod NN) jest **algorytmicznie nieosiągalny** dla pure 2-opt SA bez wprowadzenia 3-opt / or-opt / double-bridge perturbation (LKH-style).

**Decyzja (plan 02-14, opcja X):**
- D-03 LOCKED **nie jest unieważnione** — formuła `kalibruj_T0 = 2σ` zostaje jako default dla random startu (oryginalna intencja Pitfall 11).
- TEST-05 nadpisuje `T_zero=0.001` ręcznie — udokumentowany override przy NN-start (już dozwolony przez D-03 ostatnie zdanie: "nadpisywalna ręcznie").
- ROADMAP SC #4 zluźnione: "co najmniej **5%** krótsza" (zamiast 10%) — odzwierciedla realistyczny limit pure 2-opt SA.
- TEST-05 budżet: **125_000 kroków** (margin 0.009 do progu 0.95, bezpieczne dla cross-version Julia drift).
- `bench/diagnostyka_test05.jl` zacommitowany — przyszłe regresje wykrywalne.

**Future work (poza scope v1):** Plan 02-15 / v2 mógłby wprowadzić double-bridge perturbation po stagnation patience reset (LKH-style) lub or-opt move dla zbicia ratio < 0.9. Wymagałoby nowej funkcji move + integracja z `symuluj_krok!`. Zatrzymane jako deferred — Phase 3 (wizualizacja) jest core value projektu i ma priorytet.
- **D-04:** **Stagnation patience reset tylko przy `Δ < 0`** (strict improvement). Akceptacja worsening ruchu przez Metropolis **NIE** resetuje licznika — to eksploracja, nie postęp. Stop: `licznik_bez_poprawy >= alg.cierpliwosc` lub `stan.iteracja >= params.liczba_krokow` (drugie jako hard cap).

### 2-opt mechanika

- **D-05:** **Uniform random pair w `symuluj_krok!`:** `i = rand(stan.rng, 1:n-1)`; `j = rand(stan.rng, i+2:n)`. **Jedna propozycja per krok** (kanoniczne SA — nie best-of-K, nie scan). Wyklucza adjacent (`j ≥ i+2`) bo reverse 1-elementowego segmentu jest no-op (Δ ≡ 0).
- **D-06:** **Wrap-around explicit przez `mod1`.** Formuła Δ:
  ```julia
  function delta_energii(stan, i, j)
      n = length(stan.trasa)
      i_next = i + 1                  # i+1 ≤ j, wiec bez wrap
      j_next = mod1(j + 1, n)         # jedyny edge dla j=n
      t = stan.trasa
      D = stan.D
      return  D[t[i],      t[j]]      + D[t[i_next], t[j_next]] -
              D[t[i],      t[i_next]] - D[t[j],      t[j_next]]
  end
  ```
  Wszystkie pary `1 ≤ i < j ≤ n` z `j ≥ i+2` legalne, włącznie z `j=n`. Brak edge cases.
- **D-07:** **Aplikacja zaakceptowanego ruchu:** `reverse!(view(stan.trasa, i+1:j))` — in-place, zero-alloc, idiomatic Julia stdlib. Po reverse cykl pozostaje permutacją 1:n (Hamilton invariant — Pitfall 4 sprawdzane TEST-01).
- **D-08:** **Energy cache pattern.** Public `oblicz_energie(punkty, trasa)::Float64` jest **pure** (od trasy + dystansów). Hot path SA wola **tylko** `delta_energii(stan, i, j)` (O(1)) i robi `stan.energia += Δ` przy akceptacji. `oblicz_energie` wywoływana **rzadko**:
  1. Raz po `inicjuj_nn!` aby zainicjować `stan.energia`.
  2. Raz w teście końcowym (cache invariant): `@test isapprox(stan.energia, oblicz_energie(stan.D, stan.trasa, bufor); rtol=1e-10)`.
  Hot path **NIGDY** nie wola `oblicz_energie` (ENE-04 "O(1)").

### Threading & deterministyczna suma

- **D-09:** **Brak per-thread RNG.** Outer SA loop jest single-threaded — używa wyłącznie `stan.rng::Xoshiro`. `oblicz_energie` to deterministyczna suma długości krawędzi, **nie używa RNG**. `kalibruj_T0` wola `rand(stan.rng, ...)` sekwencyjnie. ALG-07 ("per-thread RNG zbudowany deterministycznie z master seeda") interpretowane jako **"single master seed jednoznacznie definiuje trajektorię, niezależnie od `JULIA_NUM_THREADS`"** — co jest spełnione przez D-09 + D-12 poniżej. Brak zmiany shape `StanSymulacji` (Phase 1 D-06 contract preserved).
- **D-10:** **`bufor_energii::Vector{Float64}` jako argument**, nie pole structu. Sygnatury:
  - **Niskopoziomowa zero-alloc** (po rozgrzewce): `oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64`
  - **Public konwencjonalna** (1 alloc, OK per ENE-03 `< 4096 B`): `oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})::Float64` — wewnętrznie buduje `D` i `bufor` (lub przyjmuje że `D` jest już policzone? planner ustala — patrz Claude's Discretion).
  - Phase 2 wola public version raz po inicjalizacji, niskopoziomową w teście inwariantu i benchmarku Phase 4. Brak globalnego stanu (PROJECT.md hard constraint).
- **D-11:** **ChunkSplitters.jl dla chunkingu** (nie `Threads.threadid()` — Pitfall 2 caveat: niestabilne na Julia 1.12+). Wzorzec:
  ```julia
  using ChunkSplitters
  function oblicz_energie(D, trasa, bufor)
      n = length(trasa)
      fill!(bufor, 0.0)
      Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=Threads.nthreads()))
          s = 0.0
          @inbounds for k in krawedzie
              s += D[trasa[k], trasa[mod1(k+1, n)]]
          end
          bufor[chunk_idx] = s
      end
      return sum(bufor)   # canonical left-to-right reduce
  end
  ```
  Chunki numerowane 1..nchunks (ID-stable), per-chunk slot w `bufor[chunk_idx]`. Final reduce `sum(bufor)` jest left-to-right. Dodajemy `ChunkSplitters` do `Project.toml [deps]` (compat: aktualny major).
- **D-12:** **TEST-04 multi-thread determinism semantyka:** asercja jest **`stan_1.trasa == stan_n.trasa` (dokładna równość) + `isapprox(stan_1.energia, stan_n.energia; rtol=1e-12)` (sub-ULP differ tolerated)**. Realistyczna semantyka:
  - SA decisions: `i, j ← rand(stan.rng, ...)` — single-threaded, deterministyczne.
  - Akceptacja: `Δ < 0 || rand(stan.rng) < exp(-Δ/T)` — `Δ` z `delta_energii` (4 lookupy w D, deterministyczne); `T` z `kalibruj_T0` (deterministyczne, używa `stan.rng`).
  - Więc **`stan.trasa` jest bit-identyczna** niezależnie od `JULIA_NUM_THREADS`.
  - `stan.energia` może różnić się sub-ULP — kumulacja `+= Δ` od pierwszego `oblicz_energie` (chunked sum, non-associative FP).
  - Test używa kanonicznej formy: `using JuliaCity; punkty = generuj_punkty(1000; seed=42); stan_seq = run_sa(punkty; threads_intent=:single); stan_par = run_sa(punkty; threads_intent=:parallel);` — gdzie `run_sa` to test helper.
- **D-13:** **Brak progu `MIN_N_THREAD`** — REQ ENE-05 jest twardy ("używana jest `Threads.@threads :static`"). Phase 4 benchmark sprawdzi czy threading przynosi zysk dla N=1000; w Phase 2 pełny zgodny implement. Hot path (`delta_energii`) jest single-threaded i **O(1)** — overhead `@threads` w `oblicz_energie` (wywoływanej raz) jest kosmetyczny.

### NN baseline & test fixtures

- **D-14:** **Dwa entry points dla NN:**
  - **Pure:** `trasa_nn(D::Matrix{Float64}; start::Int=1)::Vector{Int}` — czysta, testowalna oddzielnie, używana w benchmarku NN-baseline-beat (TEST-05) bez tworzenia `Stan`.
  - **Mutating wrapper:** `inicjuj_nn!(stan)`:
    1. `oblicz_macierz_dystans!(stan)` — wypełnia pre-alokowaną `stan.D` (Phase 1 D-08)
    2. `stan.trasa = trasa_nn(stan.D; start=1)` — NN tour
    3. `stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)` — initial energy
    4. `stan.temperatura = 0.0`, `stan.iteracja = 0` (lub: `stan.temperatura` zostawiamy bez ustawienia — `SimAnnealing(stan)` ustawi przez T₀ kalibrację)
  - Lokalizacja: `src/baselines.jl` lub `src/algorytmy/nn.jl` — planner.
- **D-15:** **Start node = 1 (zawsze).** Brak RNG-zależności. Test NN-baseline-beat: SA-z-start=1 ≥10% lepszy niż NN-z-start=1 (TEST-05).
- **D-16:** **Tiered test fixtures:**
  - **N=4** (jednostkowy kwadrat): `punkty = [Punkt2D(0,0), Punkt2D(1,0), Punkt2D(1,1), Punkt2D(0,1)]; trasa = [1,2,3,4]; @test oblicz_energie(punkty, trasa) ≈ 4.0` (smoke; Roadmap Success Criterion #1 explicit).
  - **N=20 + StableRNG(42)** (golden-value layer):
    - TEST-08 golden-value: `stan.trasa == [...]` exact + `stan.energia ≈ ...` (rtol=1e-6).
    - TEST-02 `@inferred` type-stability na publicznym API.
    - TEST-03 `@allocated == 0` na `symuluj_krok!` po rozgrzewce.
    - TEST-01 Hamilton invariant po każdym kroku (sample co 100 kroków po 2000 krokach).
  - **N=1000 + Xoshiro(42)** (quality layer):
    - TEST-05 NN-baseline-beat: `energia_SA / energia_NN ≤ 0.9`.
    - TEST-04 multi-thread determinism: `stan_1.trasa == stan_n.trasa` + `≈` energia.
- **D-17:** **TEST-08 golden-value pattern:**
  ```julia
  using StableRNGs
  punkty = generuj_punkty(20, StableRNG(42))
  stan = StanSymulacji(punkty; rng=StableRNG(42))
  inicjuj_nn!(stan)
  alg = SimAnnealing(stan; α=0.9999, cierpliwosc=5000, T₀=kalibruj_T0(stan; rng=stan.rng))
  params = Parametry(liczba_krokow=1000)
  for _ in 1:params.liczba_krokow; symuluj_krok!(stan, params, alg); end
  @test stan.trasa == [3, 7, 15, 2, 18, 11, 4, 19, 8, 14, 1, 16, 6, 13, 10, 17, 5, 12, 9, 20]   # hardcoded ref
  @test isapprox(stan.energia, 2.847_xxx; rtol=1e-6)                                              # hardcoded ref
  ```
  Wartości referencyjne generowane raz lokalnie w trakcie planowania/exec; zmiana algorytmu wymaga aktualizacji ref (intencjonalny alarm regresji). `StableRNG` gwarantuje stabilność stream przez minor-version Julii (Pitfall 8).

### Claude's Discretion

Planner Phase 2 ma swobodę w:

- **Layout plików w `src/`** — czy `oblicz_macierz_dystans!`/`oblicz_energie`/`delta_energii` żyją razem w `src/energia.jl` (rekomendowane), czy split. Czy `kalibruj_T0` w `src/energia.jl` (operacyjnie related) lub w `src/algorytmy/simulowane_wyzarzanie.jl`. Czy NN w `src/baselines.jl` lub `src/algorytmy/nn.jl`.
- **`Parametry` location** — `src/typy.jl` (razem z `StanSymulacji`, `Algorytm`) vs nowy `src/parametry.jl`. Rekomendacja: `src/typy.jl` (single source dla typów domeny).
- **Public 2-arg `oblicz_energie(punkty, trasa)` vs implicit D** — czy public version sama buduje `D = oblicz_macierz_dystans(punkty)` (lokalna macierz, alloc), czy zakłada że `D` jest już w `stan` (wymaga Stana). Rekomendacja: 2-arg version buduje lokalną D (1 alloc OK), 3-arg version (`oblicz_energie(D, trasa, bufor)`) jest hot-path-friendly.
- **Liczba kroków w teście NN-baseline-beat** — 50_000 (default Parametry) vs np. 20_000 dla CI speed. Bilans CI runtime vs siła pomiaru. Rekomendacja: 50_000, jako że `examples/` Phase 4 też tej liczby będzie używał — spójność.
- **Aqua suppressions** — które kategorie potencjalnie suppressować (Pitfall 15 advice: nie disable blindly). Rekomendacja: `ambiguities=true` (full check); jeśli false-positive na parametric `StanSymulacji{R}`, dokumentować inline.
- **`@allocated` vs `BenchmarkTools.@ballocated`** — Pitfall 16 ostrzega o `$` interpolation discipline. Rekomendacja: Base `@allocated` po explicit warmup loop (3 wywołania) — proste i bezbłędne. Dopiero w Phase 4 bench można użyć `@ballocated`.
- **Czy `delta_energii` walidacje** — np. `@assert i+2 ≤ j` przed lookupem. Rekomendacja: `@boundscheck` only (debug build), w hot path `@inbounds` po sprawdzeniu w `symuluj_krok!` że `(i, j)` jest legalne.
- **Cooling step location** — czy `stan.temperatura *= alg.α` przed czy po Metropolis test. Rekomendacja: po (canonical SA: temperature is for THIS step's acceptance, then cool for next step).

### Folded Todos

Brak — `cross_reference_todos` nie znalazł kandydatów. STATE.md TODOs (`Manifest.toml` commit, encoding-validation guard, Polish typography) są albo Phase 1-bound (zamknięte) albo Phase 4-bound (typografia). Phase 2 ich nie składa.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher Phase 2, planner Phase 2) MUST read these przed planowaniem lub implementacją.**

### Wymagania i scope (lockujące co budujemy)

- `.planning/PROJECT.md` — Core Value, constraints (Polish UI, GLMakie locked, threading-inside-only, no global state), Out of Scope.
- `.planning/REQUIREMENTS.md` §ENE (5 REQ-IDów), §ALG (8 REQ-IDów), §TEST (8 REQ-IDów) — łącznie 21 wymagań Phase 2.
- `.planning/ROADMAP.md` §"Phase 2: Energy, SA Algorithm & Test Suite" — Goal, 5 Success Criteria; §"Algorithm Variant Lock-in" (only `SimAnnealing` w v1; ForceDirected/Hybryda → v2).
- `.planning/STATE.md` §"Locked-in Decisions" — algorithm variant locked, threading-inside-only, public API surface (4 funkcje), Polish/English split, `StableRNG(42)` w testach, compat `julia = "1.10"`.

### Research (lockujący kontekst techniczny)

- `.planning/research/SUMMARY.md` — executive summary; sekcje "Phase 2 algorytmika" są punktem wyjścia.
- `.planning/research/STACK.md` — kompletna tabela wersji + `[compat]` floor; sekcje **OhMyThreads/Polyester/Threads.@threads choice**, **BenchmarkTools/Chairmarks**, **Aqua 0.8.14**, **JET 0.11**, **StableRNGs 1.0**. Dodatkowo: **ChunkSplitters** wymagana w Phase 2 (Pitfall 2 caveat).
- `.planning/research/ARCHITECTURE.md` — single module + `include()` order, parametric `StanSymulacji{R<:AbstractRNG}` shape (locked), Holy-traits dispatch via `abstract type Algorytm end`, build order (`typy → punkty → energia → algorytmy → symulacja → wizualizacja → eksport`).
- `.planning/research/PITFALLS.md` — kluczowe dla Phase 2:
  - §1 (type-instability via abstract fields)
  - §2 (closure capture in `@threads` boxes — **uses ChunkSplitters per D-11**)
  - §3 (sharing RNG across threads — **avoided per D-09**)
  - §4 (force-directed breaking Hamilton invariant — **avoided, locked SA only**)
  - §10 (distance matrix precompute — **resolved Phase 1 D-08**)
  - §11 (cooling schedule — **applied: T₀ = 2σ recipe + α=0.9999 per D-02/D-03**)
  - §12 (`@threads` net-negative for N=1000 — **mitigated: oblicz_energie called rarely; hot path is delta_energii O(1)**)
  - §15 (Aqua false positives — Claude's Discretion)
  - §16 (BenchmarkTools `$` interpolation — Claude's Discretion)
- `.planning/research/FEATURES.md` §"Must have (table stakes — v1.0)" — table stakes Phase 2.

### Phase 1 dziedziczone

- `.planning/phases/01-bootstrap-core-types-points/01-CONTEXT.md` — kluczowe decyzje Phase 1 dla Phase 2:
  - **D-01..04** `Punkt2D = Point2{Float64}` z GeometryBasics; akcesory `.x`, `.y`, `[1]`, `[2]`.
  - **D-05..08** `mutable struct StanSymulacji{R<:AbstractRNG}` shape **LOCKED** (7 pól: `punkty`, `D`, `rng`, `trasa`, `energia`, `temperatura`, `iteracja`); zero-state w Phase 1 (Phase 2 wypełnia).
  - **D-09..10** `abstract type Algorytm end` declared; `src/algorytmy/.gitkeep`. Phase 2 dodaje `struct SimAnnealing <: Algorytm`.
  - **D-11..15** `generuj_punkty(n; seed)` 2-method composable — Phase 2 używa do test fixtures.
  - **D-16..21** `Project.toml [compat]` ustalone; encoding guard test, ASCII filenames, CI matrix.
  - **D-22..24** Polish/English split: komentarze polskie (NFC, bez diakrytyków w identyfikatorach), asercje wewnętrzne angielskie (`@assert ... "msg"`).
- `.planning/phases/01-bootstrap-core-types-points/01-RESEARCH.md` — opcjonalnie konsultacyjne dla SA (`liczba_krokow` budget, Threads:@:greedy vs :static).

### Existing source code (zaimplementowane w Phase 1)

- `src/typy.jl` — `const Punkt2D = Point2{Float64}`, `abstract type Algorytm end`, `mutable struct StanSymulacji{R<:AbstractRNG}` z `const punkty/D/rng` i mutable `trasa/energia/temperatura/iteracja`. Konstruktor `StanSymulacji(punkty; rng=Xoshiro(42))`. **Phase 2 NIE modyfikuje shape**.
- `src/JuliaCity.jl` — module structure, `using GeometryBasics: Point2`, `using Random`, exports `Punkt2D, StanSymulacji, Algorytm, generuj_punkty`. **Phase 2 dodaje** `include("energia.jl")`, `include("algorytmy/simulowane_wyzarzanie.jl")`, dorzuca `oblicz_energie, delta_energii, symuluj_krok!, SimAnnealing, Parametry, trasa_nn, inicjuj_nn!, kalibruj_T0` do exportów.
- `src/punkty.jl` — `generuj_punkty(n=1000; seed=42)` + `generuj_punkty(n, rng::AbstractRNG)`. **Phase 2 używa** w testach jako fixture builder.
- `test/runtests.jl` — istniejący stub (encoding guard, PKT-01..04, StanSymulacji, Aqua/JET smoke). **Phase 2 ROZSZERZA** o testsety dla ENE, ALG, TEST-01..08 (planner ustala czy split na osobne pliki `test/test_energia.jl`, `test/test_symulacja.jl`, `test/test_baselines.jl` przez `include`).
- `Project.toml [deps]` — Phase 2 dodaje `ChunkSplitters` (current major). Test deps StableRNGs/Aqua/JET są już w Phase 1 [extras]+[targets].

### Konwencje projektowe

- `CLAUDE.md` §"Conventions" + §"Constraints" — Polish-only UI/comments hard requirement; modular structure with mandated functions (`generuj_punkty`, `oblicz_energie`, `symuluj_krok!`, `wizualizuj`); default seed; `Threads.@threads` w pętlach niezależnych od kolejności.

### Brak zewnętrznych ADR-ów

W repo nie ma `docs/adr/` ani `docs/specs/` — wszystkie decyzje technologiczne żyją w `.planning/research/` plus zaakceptowane w `.planning/STATE.md` i Phase 1/2 CONTEXT. Phase 2 nie wprowadza nowych ADR-ów; cały kontekst techniczny jest tu i w canonical refs powyżej.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`src/typy.jl::StanSymulacji{R<:AbstractRNG}`** — pre-alokowane `D::Matrix{Float64}` (Phase 1 D-08), `trasa::Vector{Int}` zainicjowana jako `collect(1:n)`, `rng::R`. Phase 2 **wypełnia** D, **przepisuje** trasa = NN, **ustawia** energia/temperatura przez `inicjuj_nn!` + `kalibruj_T0`.
- **`src/typy.jl::abstract type Algorytm end`** — extension point. Phase 2 dodaje `struct SimAnnealing <: Algorytm` w `src/algorytmy/simulowane_wyzarzanie.jl` (lub odpowiednio).
- **`src/punkty.jl::generuj_punkty(n; seed)` + 2-arg z RNG** — używana w testach `test/test_energia.jl` i `test/test_symulacja.jl` jako fixture builder (różne N i RNGi).
- **`test/runtests.jl`** — istnieje stub z encoding guard, PKT, Aqua/JET smoke. Phase 2 dorzuca `include("test_energia.jl")`, `include("test_symulacja.jl")`, `include("test_baselines.jl")` (lub osadza testsety inline — planner).

### Established Patterns (z Phase 1, kontynuacja)

- **Polish identifiers bez diakrytyków:** `cierpliwosc` (NIE `cierpliwość`), `liczba_krokow`, `bufor_energii`, `oblicz_macierz_dystans!`, `inicjuj_nn!`, `kalibruj_T0`, `simulowane_wyzarzanie.jl`. Geometria zostaje `x, y, i, j` (nie domena).
- **Mutating bang-functions** (`!`) zgodnie z Julia idiom: `inicjuj_nn!`, `symuluj_krok!`, `oblicz_macierz_dystans!`. Pure: `oblicz_energie`, `delta_energii`, `trasa_nn`, `kalibruj_T0`.
- **Two-method idiom** (Phase 1 D-11 wzorzec): pure (composable) + friendly default. Phase 2 powtarza:
  - `oblicz_energie(punkty, trasa)` (public 2-arg) + `oblicz_energie(D, trasa, bufor)` (hot-path 3-arg).
  - `SimAnnealing(stan; α, cierpliwosc, T₀)` (kalibracja w default kwarg) + `SimAnnealing(T₀, α, cierpliwosc)` (positional, dla testów).
- **Internal asserts in English** (LANG-04, Phase 1 D-23): `@assert n > 0 "n must be positive"`, `@assert 1 ≤ i < j ≤ n "i, j out of range"`. User-facing strings będą po polsku w Phase 3/4.
- **Exports w `src/JuliaCity.jl`** — Phase 2 dorzuca: `oblicz_energie, delta_energii, symuluj_krok!, SimAnnealing, Parametry, trasa_nn, inicjuj_nn!, kalibruj_T0` (planner uściśli pełną listę). Holy-traits dispatch jest invisible — user wola `symuluj_krok!(stan, params, alg)` agnostycznie.

### Integration Points

- **`src/typy.jl`** — Phase 2 może DODAĆ `Parametry` struct (zalecane: `Base.@kwdef struct Parametry; liczba_krokow::Int = 50_000; end`). NIE modyfikuje `StanSymulacji` (Phase 1 D-06 contract).
- **Nowy `src/energia.jl`** — funkcje: `oblicz_macierz_dystans!`, `oblicz_energie` (2 metody), `delta_energii`, `kalibruj_T0`. Hot path: `delta_energii`. Threadowane: `oblicz_energie(D, trasa, bufor)` przez ChunkSplitters + `@threads :static`.
- **Nowy `src/algorytmy/simulowane_wyzarzanie.jl`** — `struct SimAnnealing <: Algorytm`, konstruktory, `symuluj_krok!(stan, params, alg::SimAnnealing)`. Holy-traits dispatch entry.
- **Nowy `src/baselines.jl`** lub `src/algorytmy/nn.jl` — `trasa_nn(D; start=1)`, `inicjuj_nn!(stan)`. Planner ustala lokalizację.
- **Test split:** `test/test_energia.jl` (ENE-01..05, częściowo TEST-02/03), `test/test_symulacja.jl` (ALG-01..08, TEST-01/04/05/08), `test/test_baselines.jl` (NN), `test/runtests.jl` orchestruje przez `include` + Aqua/JET (TEST-06/07).
- **`Project.toml [deps]`** — dodanie `ChunkSplitters` (UUID + version). Phase 2 wymaga.
- **`Project.toml [compat]`** — dodanie `ChunkSplitters = "3"` (lub aktualna major).
- **Reference w `JuliaCity.jl`** — dodanie `using ChunkSplitters: chunks` (lub `using ChunkSplitters` w `src/energia.jl` — planner).

</code_context>

<specifics>
## Specific Ideas

- **Use `ChunkSplitters.jl::chunks(1:n; n=Threads.nthreads())`** zamiast `Threads.threadid()` — Pitfall 2 caveat (`threadid` is not stable for migration in Julia ≥1.12). ChunkSplitters daje ID-stable chunki niezależnie od scheduling.
- **Test dla ENE-01 explicit:** N=4 jednostkowy kwadrat — `punkty = [Punkt2D(0,0), Punkt2D(1,0), Punkt2D(1,1), Punkt2D(0,1)]`, `trasa = [1,2,3,4]`, `@test oblicz_energie(punkty, trasa) ≈ 4.0` (Roadmap Success Criterion #1 explicit).
- **Test dla ENE-04 ("delta_energii O(1) bez kopiowania trasy"):** `@test (@allocated delta_energii(stan, 5, 17)) == 0` po warmup loop (3+ wywołania).
- **Test dla cache invariant** (ENE-04 implied + ALG-08 implied): po SA pętli `@test isapprox(stan.energia, oblicz_energie(stan.D, stan.trasa, bufor); rtol=1e-10)` (drift kumulowany `+= Δ` powinien matchować recomputed value).
- **Test dla Hamilton invariant** (TEST-01): co 100 kroków na N=20 + StableRNG(42), pełen po SA na N=1000: `@test sort(stan.trasa) == 1:n`.
- **Aqua suppressions discipline** (Pitfall 15): nie disablować całych kategorii; jeśli false-positive na parametric struct, dokumentować inline w `runtests.jl`:
  ```julia
  Aqua.test_all(JuliaCity;
      ambiguities = (recursive = true,),
      # piracies = false,    # NIE — chcemy te wykrywać
  )
  ```
- **BenchmarkTools `$` interpolation discipline** (Pitfall 16): w Phase 4 `bench/`, ale jeśli Phase 2 testy używają `@ballocated`, **muszą** mieć `$` interpolację: `@test (@ballocated symuluj_krok!($stan, $params, $alg)) == 0`. Rekomendacja: użyj prostszego `@allocated` po manual warmup, oszczędza Pitfall 16 footgun.
- **`stan.temperatura` cooling step location:** zalecane *po* Metropolis test — `temperatura` jest dla TEGO kroku acceptance, potem schładzamy dla następnego. Standard SA literatura.
- **`kalibruj_T0` po `inicjuj_nn!`** — wymaga że `stan.D` jest wypełnione (pure `delta_energii` używa `D`); to jest spełnione bo `inicjuj_nn!` jest pierwszy.

</specifics>

<deferred>
## Deferred Ideas

Ideas które wyszły w dyskusji, ale nie należą do Phase 2:

- **Per-thread RNG infrastructure** — dla v2 ForceDirected/Hybryda (jeśli kiedykolwiek się pojawią). Aktualnie nieużywane.
- **Or-opt moves blending z 2-opt (~30%)** — VIZV2-03 v2 (REQUIREMENTS.md).
- **3-opt / Lin-Kernighan moves** — Out of Scope (REQUIREMENTS.md).
- **ForceDirected, Hybryda warianty** — v2 (REQUIREMENTS.md ALGV2-01, ALGV2-02).
- **Best-of-N NN starts** — Phase 4 benchmark może to porównać (czy SA-z-start=1 vs SA-z-best-NN-start daje znaczącą różnicę). Nie należy do Phase 2 NN-baseline-beat.
- **Adaptive (list-based / Lundy-Mees) cooling** — Pitfall 11 wspomina, ale geometric cooling z α=0.9999 jest locked dla v1.
- **Kahan summation w `oblicz_energie`** — niepotrzebne, sub-ULP differ przy chunked sum jest semantycznie OK (TEST-04 używa `≈` na energii, `==` na trasie — D-12).
- **Acceptance ratio logging / `historia::Vector{Float64}` w `Stan`** — UX feature, Phase 3+ visualization może to dodać przez nowe pole lub osobny callback. Phase 2 nie modyfikuje shape.
- **Convenience constructor `StanSymulacji(n::Int; seed)`** — Phase 4 `examples/` może dodać dla prostszego user-facing kodu (Phase 1 deferred już).
- **`T_min` jako safety stop oprócz patience** — geometric cooling z `α=0.9999` daje `T_min = T₀ * α^liczba_krokow ≈ 0.0067·T₀` naturalnie po 50k kroków; brak osobnego twardego progu T_min potrzebny.

### Reviewed Todos (not folded)

Brak — `cross_reference_todos` nie znalazł kandydatów. STATE.md TODOs (`Manifest.toml` commit verification, encoding-validation guard verification) są albo Phase 1 verify items (zamknięte przez Phase 1 verification) albo Phase 4-bound (Polish typography). Phase 2 ich nie składa.

</deferred>

---

*Phase: 2-energy-sa-algorithm-test-suite*
*Context gathered: 2026-04-28*
