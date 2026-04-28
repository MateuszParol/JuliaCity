# Phase 2: Energy, SA Algorithm & Test Suite - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 2-energy-sa-algorithm-test-suite
**Areas discussed:** Hiperparametry & Parametry, 2-opt mechanika, Threading & deterministyczna suma, NN baseline & test fixtures

---

## Hiperparametry & Parametry

### Q1.1 — Gdzie żyją hiperparametry SA (T₀, α, cierpliwosc)?

| Option | Description | Selected |
|--------|-------------|----------|
| SA-only + Parametry global | `SimAnnealing(T₀, α, cierpliwosc)` algorytm-specific; `Parametry` global (liczba_krokow, kroki_na_klatke). Clean separation. | ✓ |
| Wszystko w SimAnnealing | Tylko `SimAnnealing` z wszystkim; `params` placeholder. Najprostsze, ale gubi Holy-traits flexibility. | |
| Parametry trzyma wszystko | `SimAnnealing` empty tag-type. Rozprasza hiperparametry algorytmu poza algorytm. | |

**User's choice:** SA-only + Parametry global (Recommended)
**Notes:** Sygnatura `symuluj_krok!(stan, params::Parametry, alg::SimAnnealing)` — `Parametry(liczba_krokow=50_000)`, `SimAnnealing(T₀, α, cierpliwosc)`.

### Q1.2 — Defaults dla `SimAnnealing` i `Parametry` dla N=1000

| Option | Description | Selected |
|--------|-------------|----------|
| 50k kroków, α=0.9999, patience=5000 | α^50k ≈ 6.7×10⁻³, schemat ~80% → ~1% acceptance ratio. 5k = 10% budżetu. | ✓ |
| 20k kroków, α=0.9995, patience=2000 | Szybsze CI; potencjalnie over-cooled dla N=1000. | |
| 100k kroków, α=0.99993, patience=10000 | Pełen Pitfall 11 budget; długi CI runtime. | |

**User's choice:** 50k kroków, α=0.9999, patience=5000 (Recommended)

### Q1.3 — Lokalizacja kalibracji T₀

| Option | Description | Selected |
|--------|-------------|----------|
| Osobna `kalibruj_T0(stan; n_probek=1000, rng)` | Pure funkcja zwracająca Float64. Konstruktor SA: `SimAnnealing(stan; α, cierpliwosc, T₀=kalibruj_T0(stan))` w default kwarg. Worsening delts only, σ z |Δ| dla Δ>0. | ✓ |
| Kalibracja in-place w 1. `symuluj_krok!` | Lazy init — łamie zero-alloc invariant. | |
| Kalibracja w `inicjuj_nn!` | Coupling NN-init + kalibracji nieczyste. | |

**User's choice:** Osobna `kalibruj_T0(stan; n_probek=1000, rng)` (Recommended)

### Q1.4 — Stagnation patience semantyka

| Option | Description | Selected |
|--------|-------------|----------|
| Reset tylko na Δ < 0 (strict improvement) | Akceptacja worsening Metropolis NIE resetuje. Najczystszy semantycznie. | ✓ |
| Reset na każdej akceptacji | Myli "activity" z "progress" — może zatrzymać się zbyt wcześnie. | |
| Reset na poprawie globalnej best-so-far | Wymaga dodatkowych pól w Stan — łamie Phase 1 contract. | |

**User's choice:** Reset tylko na Δ < 0 (strict improvement) (Recommended)

---

## 2-opt mechanika

### Q2.1 — Strategia generowania ruchu 2-opt per `symuluj_krok!`

| Option | Description | Selected |
|--------|-------------|----------|
| Uniform random pair | `i = rand(rng, 1:n-1)`, `j = rand(rng, i+2:n)` — 1 propozycja per krok. Kanoniczne SA. | ✓ |
| Random i + best-of-K losowych j | Lepsza jakość; komplikuje budget cierpliwości; K×delta computations per krok. | |
| Systematic neighborhood scan | O(n²) per krok; bliżej greedy 2-opt; łamie ALG-03 zero-alloc. | |

**User's choice:** Uniform random pair (Recommended)

### Q2.2 — Wrap-around w `delta_energii`

| Option | Description | Selected |
|--------|-------------|----------|
| Eksplicytna mod-arytmetyka, j+1 mod n | Wszystkie pary (1≤i<j≤n, j≥i+2) legalne. Brak edge cases. | ✓ |
| Wykluczamy parę (i=1, j=n) | Mikro-optymalizacja; gubi 1 z O(n²) ruchów — nieistotne. | |
| Rotuj cykl (anchor t[1]=1) | Niestandardowe; ogranicza przestrzeń search. | |

**User's choice:** Eksplicytna mod-arytmetyka, j+1 mod n (Recommended)

### Q2.3 — Aplikacja zaakceptowanego ruchu

| Option | Description | Selected |
|--------|-------------|----------|
| `reverse!(view(stan.trasa, i+1:j))` | In-place, zero-alloc, idiomatic Julia stdlib. | ✓ |
| Per-element swap loop | Manualne; równoważne, niepotrzebne. | |
| Buffer-and-copy | Wprowadza redundancję; reverse! na view jest in-place. | |

**User's choice:** `reverse!(view(stan.trasa, i+1:j))` (Recommended)

### Q2.4 — Energy cache pattern

| Option | Description | Selected |
|--------|-------------|----------|
| `oblicz_energie` pure, cache aktualizowany w `symuluj_krok!` | `delta_energii` O(1) i `stan.energia += Δ` przy akceptacji. SA-loop NIGDY nie wola `oblicz_energie`. | ✓ |
| Zawsze przelicz `oblicz_energie` w `symuluj_krok!` | O(n) per krok zamiast O(1) — łamie ENE-04. | |
| Drift recovery co K kroków | Dla 50k kroków sub-ULP błąd nieistotny. | |

**User's choice:** `oblicz_energie` pure, cache aktualizowany w `symuluj_krok!` (Recommended)

---

## Threading & deterministyczna suma

### Q3.1 — Per-thread RNG (ALG-07)

| Option | Description | Selected |
|--------|-------------|----------|
| Nie potrzebujemy per-thread RNG | Outer SA single-threaded `stan.rng`; `oblicz_energie` deterministyczna suma bez RNG. ALG-07 reinterpretowane jako "single master seed = trajektoria niezależna od nthreads". | ✓ |
| Per-thread RNG defensywnie (pole `bufor_rng` w Stan) | Łamie Phase 1 D-06 shape contract. | |
| Per-thread RNG lazy (helper, dead code w Phase 2) | Niepotrzebne; do v2. | |

**User's choice:** Nie potrzebujemy per-thread RNG (Recommended)

### Q3.2 — Lokalizacja `bufor_energii::Vector{Float64}`

| Option | Description | Selected |
|--------|-------------|----------|
| Pre-alokowany lokalnie w `oblicz_energie` | 1 alloc per wywołanie; OK per ENE-03 < 4096B; `oblicz_energie` jest rzadko wołane. | |
| Nowe pole `bufor_energii` w `StanSymulacji` | Łamie Phase 1 D-06 shape contract. | |
| Argument do `oblicz_energie(D, trasa, bufor)` | Niskopoziomowa zero-alloc; public 2-arg internally allocates. Brak globalnego stanu. | ✓ |

**User's choice:** Argument do `oblicz_energie` (Recommended)

### Q3.3 — Deterministyczna suma multi-thread

| Option | Description | Selected |
|--------|-------------|----------|
| ChunkSplitters + canonical reduce | `chunks(1:n; n=Threads.nthreads())` ID-stable, per-chunk slot, `sum(bufor)` left-to-right. **Decyzja zaakceptowana jako infrastruktura chunkingu** (zamiast `Threads.threadid()`, Pitfall 2 caveat). | ✓ |
| Akceptujemy ≈ na multi-thread; trasy identyczne | Realna semantyka SA — interpretacja testu, nie chunking strategy. | (zastosowane w Q3.4) |
| Zawsze sumuj sekwencyjnie w canonical loop | Nie da się bit-identycznie bez Kahan summation. | |

**User's choice:** ChunkSplitters + canonical reduce (Recommended)
**Notes:** Asystent skomentował że Q3.3 i Q3.4 są ortogonalne — ChunkSplitters to chunking infrastructure, akceptacja `≈` na energii to interpretacja testu TEST-04. Obie decyzje zastosowane razem.

### Q3.4 — TEST-04 multi-thread determinism asercja

| Option | Description | Selected |
|--------|-------------|----------|
| trasa == trasa_ref, energia ≈ (rtol=1e-12) | Realistyczne; SA decisions są deterministyczne nawet z bit-różnymi sumami początkowymi. | ✓ |
| stan.trasa == stan_n.trasa, ignorujemy energię | Gubi cache invariant (testowany single-threaded). | |
| Bit-identyczne (==) trasa I energia | Wymaga Kahan summation; niepotrzebne. | |

**User's choice:** trasa == trasa_ref, energia ≈ (Recommended)

### Q3.5 — Próg `MIN_N_THREAD`

| Option | Description | Selected |
|--------|-------------|----------|
| Brak progu — zawsze threadujemy zgodnie z REQ ENE-05 | `oblicz_energie` wołane rzadko (raz na inicjalizację, raz na end-test); hot path `delta_energii` jest O(1) bez threading. | ✓ |
| Próg `if length(trasa) >= MIN_N_THREAD` | Niepotrzebna komplikacja dla N=1000. | |
| Bench gate (Phase 4) | Łamie ENE-05 implementation contract. | |

**User's choice:** Brak progu — zawsze threadujemy zgodnie z REQ (Recommended)

---

## NN baseline & test fixtures

### Q4.1 — Sygnatura NN

| Option | Description | Selected |
|--------|-------------|----------|
| `trasa_nn(D; start=1)::Vector{Int}` pure + `inicjuj_nn!(stan)` wrapper | Dwa entry points: pure dla baseline benchmark (TEST-05), mutating dla SA init. | ✓ |
| Tylko `inicjuj_nn!(stan)` mutating | Niepotrzebny boilerplate w teście NN-baseline-beat. | |
| Tylko `trasa_nn(D, start)` pure | User-facing kod brzydszy bez init wrapper. | |

**User's choice:** `trasa_nn(D; start=1)` pure + `inicjuj_nn!(stan)` wrapper (Recommended)

### Q4.2 — Start node dla NN

| Option | Description | Selected |
|--------|-------------|----------|
| Zawsze `start=1` | Determinizm; NN-from-1 to baseline kanoniczny. | ✓ |
| Best-of-N (start=1..n, najlepsza) | O(n²) konstrukcji; sztucznie utrudnia SA pobicie. | |
| Random start z `stan.rng` | Niepotrzebne; deterministyczne ale komplikuje TEST-04. | |

**User's choice:** Zawsze `start=1` (Recommended)

### Q4.3 — Test fixtures (N i seed)

| Option | Description | Selected |
|--------|-------------|----------|
| Tiered: N=4 (smoke), N=20 (golden, StableRNG), N=1000 (quality, Xoshiro) | N=4 dla sanity (Roadmap SC #1), N=20 dla golden + alloc + type-stability, N=1000 dla NN-beat + multi-thread determinism. | ✓ |
| Tylko N=1000 wszędzie | Long CI; type-stability i Hamilton invariant nie potrzebują N=1000. | |
| Tylko N=20 + N=1000 (skip N=4) | Pomijamy najprostszy correctness test. | |

**User's choice:** Tiered: N=4 + N=20 + N=1000 (Recommended)

### Q4.4 — TEST-08 golden-value pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Trasa exact + energia approx, ref hardcoded w teście | `@test stan.trasa == [...]` + `@test isapprox(stan.energia, ...; rtol=1e-6)`. Stabilne przez StableRNG; alarm regresji intencjonalny przy zmianie algorytmu. | ✓ |
| Tylko energia approx | Gubi wykrywanie błędów typu "trasa rotated" (energia identyczna). | |
| Tylko Hamilton invariant po N krokach | Najsłabsze; łamie TEST-08 intencję. | |

**User's choice:** Trasa exact + energia approx, ref hardcoded w teście (Recommended)

---

## Claude's Discretion

Areas where planner Phase 2 ma swobodę:

- Layout plików w `src/` (czy `kalibruj_T0` w `src/energia.jl` razem z `oblicz_energie`, czy w `src/algorytmy/simulowane_wyzarzanie.jl`)
- Lokalizacja `Parametry` (`src/typy.jl` rekomendowane vs nowy `src/parametry.jl`)
- Lokalizacja NN (`src/baselines.jl` vs `src/algorytmy/nn.jl`)
- Public 2-arg `oblicz_energie(punkty, trasa)` vs implicit D (czy alokuje lokalną D wewnątrz, czy zakłada że D jest w Stan)
- Liczba kroków w teście NN-baseline-beat (50_000 default vs np. 20_000 dla CI speed) — bilans CI runtime vs pomiar siły
- Aqua suppressions (jeśli false-positive na parametric `StanSymulacji{R}`, dokumentować inline) — Pitfall 15
- `@allocated` (Base) vs `@ballocated` (BenchmarkTools) w testach allocations — Pitfall 16 ostrzega o `$` interpolation
- `delta_energii` walidacje (`@boundscheck` only vs explicit assertions)
- Cooling step location (`stan.temperatura *= alg.α` po Metropolis test — canonical SA)

## Deferred Ideas

Wymienione w trakcie dyskusji, nie należą do Phase 2:

- Per-thread RNG infrastructure (v2 ForceDirected/Hybryda)
- Or-opt moves blending (VIZV2-03 v2)
- 3-opt / Lin-Kernighan (Out of Scope)
- ForceDirected, Hybryda warianty (v2 ALGV2)
- Best-of-N NN starts (Phase 4 benchmark może porównać)
- Adaptive (list-based / Lundy-Mees) cooling (Pitfall 11; geometric locked dla v1)
- Kahan summation w `oblicz_energie` (niepotrzebne)
- Acceptance ratio logging / `historia` w Stan (Phase 3+ feature)
- Convenience constructor `StanSymulacji(n::Int; seed)` (Phase 4)
- `T_min` jako safety stop (geometric cooling daje T_min naturalnie)
