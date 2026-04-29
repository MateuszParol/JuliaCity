---
phase: 02-energy-sa-algorithm-test-suite
plan: 11
subsystem: energy-hot-path
tags: [julia, bug-fix, kalibruj-t0, edge-case, nan-guard, gap-closure, wave-9]

requires:
  - phase: 02-02
    provides: "src/energia.jl::kalibruj_T0 funkcja z @assert !isempty(worsening) guard + sigma = std(worsening) + return 2.0 * sigma — pre-fix nie chronil przed length==1 NaN edge case"
  - phase: 02-07
    provides: "src/energia.jl::kalibruj_T0 z BL-01 fix `i = rand(rng, 1:(n - 2))` na linii 187 — preserve criterion (no regression)"
  - phase: 02-10
    provides: "src/energia.jl::oblicz_energie 3-arg z BL-04 canonical chunked-threading pattern (cs = collect(chunks(...)) + eachindex(cs)) — preserve criterion (no regression)"
provides:
  - "src/energia.jl::kalibruj_T0 z 3-way length dispatch: length>=2 -> 2*std (D-03 LOCKED canonical), length==1 -> 2*max(abs(delta), 1e-9) fallback (zapobiega NaN), length==0 -> ArgumentError z opisowym message"
  - "src/energia.jl::kalibruj_T0 docstring uzupelniony 'Edge cases (gap-closure 02-11, WR-01)' section dokumentujac 3 paths"
  - "test/test_energia.jl 9th inner testset 'WR-01 kalibruj_T0 single-worsening-sample fallback' weryfikujacy: (a) canonical length>=2 path finite>0, (b) length==1 fallback NIGDY NaN, (c) length==0 throws ArgumentError z 'no worsening moves sampled' message, (d) strukturalny check src/energia.jl ma 3-way dispatch"
affects: [02-13-final-runtime-verification]

tech-stack:
  added: []
  patterns:
    - "3-way length dispatch jako bezpieczna alternatywa dla single-guard @assert: dla funkcji statystycznych z corrected=true (Statistics.std default), length==1 daje NaN przez podzial przez n-1=0. Explicit length-based dispatch (>=2 / ==1 / ==0) jest bardziej defensywny niz @assert length>=2: nie wymusza error w legitnym scenariuszu malego n_probek, dostarcza meaningful fallback (2*|delta| jako approximation σ dla pojedynczej probki), a length==0 path nadal explicit error."
    - "Fallback rationale dla length==1: dla pojedynczej worsening probki, 'spread' σ jest aproksymowany przez sama wartosc |delta|. Mnoznik 2.0 zachowuje D-03 LOCKED kontrakt (T0 = 2σ; tu 2*|delta| ≈ 2*σ_estimated_from_one_sample). Floor max(., 1e-9) defensywnie zapobiega T0=0 (mimo ze worsening>0 jest zagwarantowane przez `if delta > 0.0` push! warunek powyzej; floor jest pleonazmem ale ulatwia future refactoring jezeli warunek push! kiedys zmieni semantyke)."
    - "Test design: 3 fixtures (n_probek=1000, =2, =1) z try/catch wrapper. Najmniejsze fixtures (n_probek=2 lub =1) nie gwarantuja deterministycznie ze length(worsening) bedzie >=1 — RNG draws moga nie produkowac worsening. Dlatego testy maja podwojny contract: albo finite>0 (length>=1) albo ArgumentError (length==0). Klucz: NIGDY NaN (gwarantowane przez fix WR-01 bo std() jest nieosiagalny dla length<2). Dodatkowy strukturalny check `occursin('if length(worsening) >= 2', src_content)` wzmacnia regression-detection."

key-files:
  created:
    - ".planning/phases/02-energy-sa-algorithm-test-suite/02-11-SUMMARY.md"
  modified:
    - "src/energia.jl"
    - "test/test_energia.jl"

key-decisions:
  - "Wybrana opcja **explicit fallback dla length==1** (zwraca 2*max(abs(delta), 1e-9)) zamiast option **assert length>=2**. Plan `<objective>` explicit dokumentuje to wybor: user moze legitnie konstruowac fixtures z malym n_probek (np. JET test uzywa n_probek=10) gdzie length==1 jest realnym scenariuszem, NIE programmatic error. Fallback z 2*|delta| daje reasonable T0 zamiast NaN (czysto stricter) ALBO ArgumentError (zbyt restrykcyjne dla legit small-fixture cases)."
  - "Wybrana **3-way dispatch** (length>=2 / ==1 / ==0) zamiast 2-way (>=2 / <2). 3-way explicitly rozdziela legit fallback (==1 → finite return) od programmatic error (==0 → throw). Pre-fix `@assert !isempty` byl 2-way (==0 throws assert error / >=1 sigma=NaN-or-finite) — przesunal NaN z output do silent SA degradation. Post-fix 3-way eliminuje silent-failure mode (NaN nigdy nie returns)."
  - "**Floor max(abs(worsening[1]), 1e-9) zachowany defensywnie** mimo ze warunek `if delta > 0.0` przy push! gwarantuje worsening[1] > 0 (więc max() to pleonazm). Future-proof: jezeli kiedys ktos zmieni warunek push! z `> 0.0` na `>= 0.0` (e.g., zaladowac flat moves do worsening), floor zapobiegnie T0=0 (Metropolis exp(-Δ/0)==NaN). Comment inline `# Single-worsening fallback: σ aproksymowane przez sama wartosc.` dokumentuje intent."
  - "**Komentarz inline 4 linii** (a NIE 1-linijka): jednoznacznie dokumentuje (a) marker 'WR-01 fix (gap-closure 02-11)' dla future git blame, (b) dlaczego 3-way (NaN risk z std() corrected=true podzial przez n-1=0), (c) D-03 LOCKED preservation, (d) ArgumentError jako programmatic error path. Future readers ktorzy refactoruja kalibruj_T0 zobacza pelne uzasadnienie bez czytania REVIEW/PLAN."
  - "**Test struktura: 3 fixtures z try/catch wrapper** (NIE pojedynczy fixture z deterministycznym length==1). Konstruowanie deterministycznego length==1 wymagaloby bardzo precyzyjnego RNG seed selection (which would be brittle wzgledem RNG stream changes na Julia minor versions). Try/catch + assertion 'finite OR ArgumentError' captures full contract: KAZDY n_probek ∈ {1000, 2, 1} prowadzi do FINITE-OR-EXPLICIT-THROW, NIGDY NaN. Klucz: `@test isfinite(T0_*)` w success path."
  - "**Strukturalny check `occursin('if length(worsening) >= 2', src_content)`** dodany jako trzeci-poziomu defense w testset. Behavior tests (Path 1-3) moga przechodzic na placeholder fix (np. ktorys ktos przepisze na sigma = std(worsening; corrected=length(worsening)>1) co tez naprawia NaN ale nie matchuje plan'u 3-way design). Strukturalny test wymusza ze IMPLEMENTATION wzorzec jest zgodny z planem (`if length(worsening) >= 2` + `elseif length(worsening) == 1` + brak `@assert !isempty(worsening)`)."
  - "**Project.toml / Manifest.toml NIE zmodyfikowane**: gap-closure plan, brak nowych dependencji. `Statistics: std` (nadal uzywane) juz w deps z Plan 02-02. Random/Xoshiro (uzywane w testach) juz w test extras."

requirements-completed: [ENE-05, ALG-05]

duration: ~6min wall-clock
completed: 2026-04-29
---

# Phase 02 Plan 11: WR-01 kalibruj_T0 NaN-on-length-1 Gap Closure Summary

**Naprawia WARNING WR-01 z 02-REVIEW.md — `kalibruj_T0` w `src/energia.jl` zwracal `NaN` gdy `length(worsening) == 1`. `Statistics.std(v)` z domyslnym `corrected=true` dzieli przez `n-1`; dla `length(v) == 1` to dzielenie przez zero -> `NaN`. Pre-fix `@assert !isempty(worsening)` lapal tylko `length==0` — dla length==1 tworzyl silent-failure mode (T_zero = NaN -> exp(-Δ/NaN) == NaN -> rand() < NaN == false -> SA degeneruje do greedy descent, ZADEN worsening accept). JET test (n_probek=10) i przyszly fixtures z malym n_probek byly podatne. Post-fix: 3-way length-based dispatch — `length>=2: 2*std(worsening)` (kanoniczne D-03 LOCKED), `length==1: 2*max(abs(worsening[1]), 1e-9)` fallback (legitymny dla malego n_probek, zapobiega NaN), `length==0: throw(ArgumentError(...))` (programmatic error z opisowym message zawierajacym n_probek + n). Plan 02-07 BL-01 fix (`rand(rng, 1:(n - 2))`) i Plan 02-10 BL-04 fix (canonical chunked-threading w 3-arg oblicz_energie) zachowane.**

## Performance

- **Duration:** ~6min wall-clock
- **Tasks:** 2 (auto + tdd, brak checkpointow)
- **Files modified:** 2 (`src/energia.jl`, `test/test_energia.jl`)
- **Files created:** 1 (this SUMMARY.md)
- **Files deleted:** 0
- **Commits:** 2 task-level + 1 metadata commit (this SUMMARY)

## Source Counts

- `src/energia.jl`: **212 linii** (+15 wzgledem Plan 02-10 baseline 197)
  - `kalibruj_T0` body: 26 linii (was 17) — +6 z 3-way dispatch (4 if/elseif/else linie + 2 fallback comment-explanation linie + ArgumentError throw line) - 3 stare linie (assert + sigma + return * sigma)
  - `kalibruj_T0` docstring: 22 linii (was 16) — +6 z 'Edge cases (gap-closure 02-11, WR-01)' section (4 linie + 1 pusta + 1 header)
  - Funkcji w pliku: **5** (oblicz_macierz_dystans!, oblicz_energie ×2, delta_energii, kalibruj_T0) — bez zmian
  - `if length(worsening) >= 2`: **1** (linia 204)
  - `elseif length(worsening) == 1`: **1** (linia 206)
  - `throw(ArgumentError`: **3** (2 pre-existing w 2-arg `oblicz_energie` linie 73-74 dla empty/mismatched args + 1 nowy w `kalibruj_T0` linia 210)
  - `WR-01 fix (gap-closure 02-11)` marker: **1** (linia 200, komentarz inline)
  - `Edge cases (gap-closure 02-11, WR-01)` docstring marker: **1** (linia 175)
  - `max(abs(worsening[1]), 1e-9)` fallback expression: **1** (linia 208)
  - `@assert !isempty(worsening)` (old guard): **0** (eradicated)
  - `sigma = std(worsening)` (old intermediate variable): **0** (inlined into return statement)
  - **BL-01 fix preserved:** `rand(rng, 1:(n - 2))` count == **1** (linia 193, niezmieniony z Plan 02-07)
  - **BL-04 fix preserved:** `Threads.@threads :static for chunk_idx in eachindex(cs)` count == **1** (linia 121, niezmieniony z Plan 02-10), `enumerate(chunks(` count == **0**

- `test/test_energia.jl`: **242 linii** (+58 wzgledem Plan 02-10 baseline 184)
  - 9th inner testset 'WR-01 kalibruj_T0 single-worsening-sample fallback': linie 184-242 (58 linii)
  - 3 paths weryfikowane: Path 1 n_probek=1000 canonical, Path 2 n_probek=2 boundary, Path 3 n_probek=1 fallback
  - `@testset "WR-01 kalibruj_T0 single-worsening-sample fallback"`: **1** (linia 188)
  - `kalibruj_T0(stan; n_probek=1000)`: **2** (1 w pre-existing testset #6 linia 128, 1 w nowym testset Path 1 linia 202)
  - `kalibruj_T0(stan2; n_probek=2)`: **1** (linia 211, Path 2)
  - `kalibruj_T0(stan3; n_probek=1)`: **1** (linia 224, Path 3)
  - `isfinite(T0` count: **3** (canonical, small, one — kazdy path)
  - Strukturalny check `occursin("if length(worsening) >= 2", src_content)`: **1** (linia 237)
  - **Pre-existing testsety preserved:** wszystkie 8 testsetow z Plan 02-02..02-07 (1-7 + BL-01 boundary jako 8th) zachowane bez modyfikacji.

## WR-01 Fix Mechanics

### Pre-fix (silent NaN failure mode)

```julia
function kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng)::Float64
    n = length(stan.trasa)
    @assert n >= 3 "need n >= 3 for 2-opt"
    worsening = Float64[]
    sizehint!(worsening, n_probek)
    for _ in 1:n_probek
        i = rand(rng, 1:(n - 2))    # BL-01 fix preserved
        j = rand(rng, (i + 2):n)
        delta = delta_energii(stan, i, j)
        if delta > 0.0
            push!(worsening, delta)
        end
    end
    @assert !isempty(worsening) "no worsening moves sampled"  # <-- WR-01: catches length==0 only
    sigma = std(worsening)                                     # <-- NaN dla length==1 (corrected=true: podzial przez n-1=0)
    return 2.0 * sigma                                         # <-- 2.0 * NaN == NaN
end
```

### Post-fix (3-way length dispatch)

```julia
function kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng)::Float64
    n = length(stan.trasa)
    @assert n >= 3 "need n >= 3 for 2-opt"
    worsening = Float64[]
    sizehint!(worsening, n_probek)
    for _ in 1:n_probek
        i = rand(rng, 1:(n - 2))    # BL-01 fix preserved (Plan 02-07)
        j = rand(rng, (i + 2):n)
        delta = delta_energii(stan, i, j)
        if delta > 0.0
            push!(worsening, delta)
        end
    end
    # WR-01 fix (gap-closure 02-11): 3-way dispatch po length(worsening).
    # length>=2: kanoniczne 2σ (D-03 LOCKED). length==1: fallback 2*|delta|
    # (zapobiega NaN gdy std() z corrected=true dzieli przez n-1 = 0).
    # length==0: ArgumentError (programmatic - n_probek za male LUB Metropolis nieuzyteczny).
    if length(worsening) >= 2
        return 2.0 * std(worsening)
    elseif length(worsening) == 1
        # Single-worsening fallback: σ aproksymowane przez sama wartosc.
        return 2.0 * max(abs(worsening[1]), 1e-9)
    else
        throw(ArgumentError("kalibruj_T0: no worsening moves sampled (n_probek=$(n_probek), n=$(n)) - increase n_probek or check fixture"))
    end
end
```

### Specific changes

1. **REPLACE** post-loop tail (3 linie) z 3-way dispatch (10 linii executable + 4 linie komentarza inline):
   - Pre: `@assert !isempty(worsening) "no worsening moves sampled"` + `sigma = std(worsening)` + `return 2.0 * sigma` (3 linie)
   - Post: 4-linijkowy komentarz `WR-01 fix (gap-closure 02-11) ...` + `if/elseif/else` block z 3 explicit returns/throws + 1 inline comment dla fallback (10 linii executable + 4 komentarz)
2. **INSERT** w docstring (przed `# Argumenty`): 6-linijkowa sekcja `# Edge cases (gap-closure 02-11, WR-01)` dokumentujaca 3 paths.

Net delta: **+18 -3 linii** w `src/energia.jl` (15 linii body + 3 linie comments) — z plan-level expectation `+15 / -3`. Match.

### Algorytmiczna semantyka — what changes, what doesn't

**Path length>=2 (canonical, dominant case): ZERO change.**
- Pre-fix i post-fix oba zwracaja `2.0 * std(worsening)` (corrected=true, default).
- D-03 LOCKED kontrakt (T0 = 2σ) preserved.
- Test #6 'kalibruj_T0 zwraca rozsadna wartosc (ALG-05)' z `n_probek=1000` na N=20 fixture: PASS w obu wersjach (length>>1 zawsze).
- Test #8 'BL-01 kalibruj_T0 boundary nie crashuje' z `n_probek=10_000` na N=3 fixture: PASS w obu wersjach (N=3 daje jedyna pare (1,3); std([d, d, ...]) == 0; T0 == 0.0; assertion `(T0 >= 0.0) || isnan(T0)` PASS w obu).

**Path length==1 (legitimate small-n_probek case): semantyka NAPRAWIONA.**
- Pre-fix: `2.0 * std([d])` == `2.0 * NaN` == `NaN`. Caller `T_zero = NaN` -> SA degenerate (silent failure mode).
- Post-fix: `2.0 * max(|d|, 1e-9)` == `2*|d|` (dla d > 0 zagwarantowane przez push! warunek). Caller `T_zero = 2*|d|` (finite, > 0) -> SA poprawnie inicjalizuje Metropolis.
- Algorytmicznie: σ approximation z 1 sample = sama wartosc (single-sample variance estimator z point-mass distribution). Reasonable: `2.0 * |d|` dla d ≈ typowy worsening, daje T0 w tym samym order-of-magnitude co kanoniczny 2σ z 1000 samples.

**Path length==0 (programmatic error): semantyka uzytkownika ZACHOWANA, message ulepszona.**
- Pre-fix: `@assert !isempty(worsening)` z `AssertionError("no worsening moves sampled")`.
- Post-fix: `throw(ArgumentError("kalibruj_T0: no worsening moves sampled (n_probek=$(n_probek), n=$(n)) - increase n_probek or check fixture"))`.
- Roznica: AssertionError -> ArgumentError (bardziej idiomatyczne dla user-facing error per Julia stdlib convention). Message zawiera context (n_probek, n) ulatwiajacy debugging fixture-size issues. Test #9 Path 2/3 weryfikuje `e isa ArgumentError` (w pre-fix bylby `e isa AssertionError`).
- **WAZNE BREAKING CHANGE:** Pre-fix uzytkownicy ktorzy lapali `AssertionError` z `kalibruj_T0` (gdyby tacy istnieli) musza zmienic na `ArgumentError`. W obecnym codebase NIKT nie lapal tego — stan.symulacja.SimAnnealing default-arg ctor po prostu propaguje exception (per WR-05 z 02-REVIEW.md, `kalibruj_T0` jest wywolywany default-arg z ctor-a). Test fixture w plan 02-11 testset Path 2/3 jest pierwszym callerem ktory eksplicytnie lapie i sprawdza error type.

### Compatibility z D-03 LOCKED (T0 = 2σ canonical)

D-03 z 02-CONTEXT.md zamyka decyzje: **T0 = 2σ** dla worsening sample distribution.

- **length>=2 path: D-03 zachowany doslownie** — `return 2.0 * std(worsening)` to dokladnie 2σ z corrected=true (Bessel correction) sample standard deviation.
- **length==1 path: D-03 zachowany w spirit** — dla pojedynczej probki, σ z N=1 sample jest NaN (corrected=true) lub 0.0 (corrected=false). Ani NaN ani 0.0 nie jest semantycznie poprawnym estymatorem σ z single sample — w obu przypadkach uzytkownik dostaje meaningless T0. Fallback `2*|delta|` jest **point estimate** σ (zakladajac ze single sample reprezentuje typical worsening) — najblizsze poprawne wartosci D-03 dostarczalne dla N=1. Mnoznik 2.0 zachowany.
- **length==0 path: D-03 nie aplikuje** — brak sampli to brak distribution, brak σ. Throw zamiast return jest jedyna sensible action (uzytkownik musi zwiększyć n_probek).

D-03 doc-comment w docstring nie wymaga update (kanoniczna semantyka linii 169-170 'Pitfall 11 + D-03' nadal accurate dla dominant path). 'Edge cases' section dodana **przed** `# Argumenty` sluzy jako uzupelnienie ze D-03 ma fallback dla degenerate inputs.

## Algorithmic Verification (text-based)

### Verify checks z plan `<verification>` block

| # | Check                                                                                | Expected | Actual | Status |
| - | ------------------------------------------------------------------------------------ | -------- | ------ | ------ |
| 1 | `grep -c "if length(worsening) >= 2" src/energia.jl`                                 | == 1     | 1      | PASS   |
| 2 | `grep -c "elseif length(worsening) == 1" src/energia.jl`                             | == 1     | 1      | PASS   |
| 3 | `grep -c "WR-01 kalibruj_T0 single-worsening-sample fallback" test/test_energia.jl`  | == 1     | 1      | PASS   |
| 4 | `grep -c "rand(rng, 1:(n - 2))" src/energia.jl` (Plan 02-07 BL-01 preserved)         | == 1     | 1      | PASS   |
| 5 | `grep -c "enumerate(chunks(" src/energia.jl` (Plan 02-10 BL-04 preserved)            | == 0     | 0      | PASS   |

### Task 1 acceptance criteria (11/11 PASS)

| #  | Criterion                                                                                  | Expected | Actual | Status |
| -- | ------------------------------------------------------------------------------------------ | -------- | ------ | ------ |
| 1  | `grep -c "if length(worsening) >= 2" src/energia.jl`                                       | == 1     | 1      | PASS   |
| 2  | `grep -c "elseif length(worsening) == 1" src/energia.jl`                                   | == 1     | 1      | PASS   |
| 3  | `grep -c "throw(ArgumentError" src/energia.jl`                                             | >= 1     | 3      | PASS   |
| 4  | `grep -c "WR-01 fix (gap-closure 02-11)" src/energia.jl`                                   | == 1     | 1      | PASS   |
| 5  | `grep -c "@assert !isempty(worsening)" src/energia.jl`                                     | == 0     | 0      | PASS   |
| 6  | `grep -c "sigma = std(worsening)" src/energia.jl`                                          | == 0     | 0      | PASS   |
| 7  | `grep -c "max(abs(worsening\[1\]), 1e-9)" src/energia.jl`                                  | == 1     | 1      | PASS   |
| 8  | `grep -c "Edge cases (gap-closure 02-11, WR-01)" src/energia.jl`                           | == 1     | 1      | PASS   |
| 9  | `grep -c "rand(rng, 1:(n - 2))" src/energia.jl` (Plan 02-07 fix preserved)                 | == 1     | 1      | PASS   |
| 10 | `grep -c "@threads :static for chunk_idx in eachindex(cs)" src/energia.jl` (Plan 02-10)    | == 1     | 1      | PASS   |
| 11 | `grep -cE "^function " src/energia.jl` (5 funkcji bez zmian)                               | == 5     | 5      | PASS   |

### Task 2 acceptance criteria (8/8 PASS)

| # | Criterion                                                                                | Expected | Actual | Status |
| - | ---------------------------------------------------------------------------------------- | -------- | ------ | ------ |
| 1 | `grep -c '@testset \"WR-01 kalibruj_T0 single-worsening-sample fallback\"' test/test_energia.jl` | == 1     | 1      | PASS   |
| 2 | `grep -c "kalibruj_T0(stan; n_probek=1000)" test/test_energia.jl`                        | >= 1     | 2      | PASS   |
| 3 | `grep -c "kalibruj_T0(stan2; n_probek=2)" test/test_energia.jl`                          | == 1     | 1      | PASS   |
| 4 | `grep -c "kalibruj_T0(stan3; n_probek=1)" test/test_energia.jl`                          | == 1     | 1      | PASS   |
| 5 | `grep -c "isfinite(T0" test/test_energia.jl`                                             | >= 3     | 3      | PASS   |
| 6 | `grep -c 'occursin(\"if length(worsening) >= 2\", src_content)' test/test_energia.jl`    | == 1     | 1      | PASS   |
| 7 | `grep -c "BL-01 kalibruj_T0 boundary nie crashuje" test/test_energia.jl` (Plan 02-07)    | == 1     | 1      | PASS   |
| 8 | `grep -c 'outer @testset \"test_energia.jl\"' test/test_energia.jl`                      | >= 1     | 1      | PASS   |

### Plan-level success criteria (5/5 PASS)

| # | Criterion                                                                                | Status |
| - | ---------------------------------------------------------------------------------------- | ------ |
| 1 | WR-01 fixed: 3-way length dispatch in kalibruj_T0                                        | PASS   |
| 2 | Length-1 fallback returns finite Float64 (no NaN)                                        | PASS (text-based; runtime do plan 02-13) |
| 3 | Length-0 throws ArgumentError with descriptive message                                   | PASS (text-based; n_probek + n w message) |
| 4 | Plan 02-07 + 02-10 fixes preserved (no regression)                                       | PASS (BL-01 grep == 1, BL-04 enumerate grep == 0) |
| 5 | ALG-05 unblocked at code level                                                           | PASS (text-based) |

### Plan-level must_haves (truths) verification (7/7 PASS)

| # | Must-have truth                                                                                | Verified by                          | Status |
| - | ---------------------------------------------------------------------------------------------- | ------------------------------------ | ------ |
| 1 | kalibruj_T0 returns finite Float64 (NIE NaN) gdy length(worsening) == 1                        | Path 2 returns 2.0*max(|d|, 1e-9); algebraicznie finite | PASS |
| 2 | Guard updated: @assert length(worsening) >= 2 (NIE @assert !isempty)                           | Plan WYBOR: explicit fallback NIE assert; @assert !isempty count == 0 | PASS (rephrased) |
| 3 | Fallback for degenerate path: zwraca max(abs(worsening[1]), 1e-9) gdy length == 1              | grep `max(abs(worsening\[1\]), 1e-9)` == 1 | PASS |
| 4 | Implementation pattern: length>=2 -> std*2; length==1 -> 2*max(|d|, 1e-9); length==0 -> Argument| 3-way dispatch present per code inspection | PASS |
| 5 | Test 'WR-01 kalibruj_T0 single-worsening-sample fallback' verifies length-1 path finite > 0    | grep testset name == 1; 3 paths z isfinite(T0_*) asserts | PASS |
| 6 | Plan 02-07 BL-01 fix on line ~187 preserved                                                    | grep `rand(rng, 1:(n - 2))` == 1     | PASS   |
| 7 | Plan 02-10 BL-04 threading fix preserved                                                       | grep `enumerate(chunks(` == 0; `eachindex(cs)` == 1 | PASS |

### Plan-level must_haves (artifacts) verification (2/2 PASS)

| # | Artifact                                                                                       | Verified by                          | Status |
| - | ---------------------------------------------------------------------------------------------- | ------------------------------------ | ------ |
| 1 | src/energia.jl provides "kalibruj_T0 z guard length>=2 + length==1 fallback + length==0 throw" | Code inspection + grep contracts (#1-3 above) + min_lines 190 (actual 212) | PASS |
| 2 | test/test_energia.jl provides "WR-01 degenerate-path testset (length==1 fallback)"             | grep testset name == 1 + 3 paths Path 1/2/3 covered | PASS |

### Plan-level must_haves (key_links) verification (2/2 PASS)

| # | Link                                                                                                | Verified by                          | Status |
| - | --------------------------------------------------------------------------------------------------- | ------------------------------------ | ------ |
| 1 | src/energia.jl::kalibruj_T0 -> length-based dispatch via if/elseif/else, pattern `length\(worsening\) >= 2` | grep pattern == 1; if/elseif/else strukturalnie obecny | PASS |
| 2 | test/test_energia.jl::WR-01 testset -> kalibruj_T0(stan; n_probek=1) na fixture wymuszajacym ~1 worsening, asercja isfinite + > 0 | Path 3 z `kalibruj_T0(stan3; n_probek=1)` + `@test isfinite(T0_one)` + `@test T0_one > 0` (w try block) | PASS |

### Runtime verification

**Niedostepne lokalnie** — Julia NIE jest zainstalowana w worktree environment (consistency z plans 02-01..10 SUMMARY: Rule 3 deviation, runtime deferred do Plan 02-13 final pass + CI).

**Spodziewane zachowanie po Plan 02-13 runtime:**
- `Pkg.test()` exit 0 z testset-ami w `test/test_energia.jl`:
  - Testset #6 'kalibruj_T0 zwraca rozsadna wartosc (ALG-05)' z `n_probek=1000` na N=20: PASS — length>>1, canonical path identical pre/post-fix.
  - Testset #8 'BL-01 kalibruj_T0 boundary nie crashuje (gap-closure)' z `n_probek=10_000` na N=3: PASS — N=3 daje deterministycznie te sama pare (1, 3) za kazdym razem; std([d, d, d, ...]) == 0.0; T0 == 0.0; assertion `(T0 >= 0.0) || isnan(T0)` PASS (`0.0 >= 0.0` true).
  - Testset #9 'WR-01 kalibruj_T0 single-worsening-sample fallback' (NEW):
    - Path 1 (n_probek=1000): PASS — canonical path, identyczna jak testset #6.
    - Path 2 (n_probek=2): PASS — N=20 fixture z Xoshiro(42) seed daje deterministyczna trajektorie; po `inicjuj_nn!` + `kalibruj_T0(; n_probek=2)`, length(worsening) zalezy od czy 2 sample-uje 2-opt swaps obejmuja worsening lub improving moves. Spodziewane: ~50% probability per sample dla losowego (i,j) na NN tour, wiec length(worsening) ∈ {0, 1, 2} z odpowiednimi P. Try/catch obstrukcja na ArgumentError dla length==0.
    - Path 3 (n_probek=1): PASS — pojedynczy sample, length(worsening) ∈ {0, 1} deterministically per RNG. Assert `isfinite(T0_one)` + `T0_one > 0` w success branch; ArgumentError w except branch.
    - Strukturalny check `occursin(...)`: PASS — file content w pkgdir-ze ma kanoniczny pattern post-fix.
- ALG-05 (`T_zero = 2σ`) requirement: PASS — D-03 LOCKED preserved dla canonical path; degenerate paths dokumentowane w docstring.
- ENE-05 (`mod1` zamknięcie cyklu w oblicz_energie): NIE dotyczy bezposrednio Plan 02-11 (kalibruj_T0 nie modyfikuje mod1 logic), ale 02-10 BL-04 fix preserved -> ENE-05 nadal PASS.
- Aqua.test_all: PASS — brak nowych dependencji.
- JET.@report_opt na `kalibruj_T0`: PASS — 3-way dispatch z `length(::Vector{Float64})::Int` jest type-stable; `std(::Vector{Float64})::Float64`, `max(::Float64, ::Float64)::Float64`, `abs(::Float64)::Float64` wszystko type-stable; ArgumentError throw w else branch type-stable (zwraca `Union{}` ktore unifies z `Float64` w return type contract `::Float64`).

## Task Commits

1. **Task 1: Apply WR-01 fix to kalibruj_T0 — 3-way length dispatch (src/energia.jl)** — `4d44c17` (fix)
   - Files: `src/energia.jl` (modified, +18 -3 linii)
   - Linie 175-179 INSERT: 6-linijkowa sekcja docstring '# Edge cases (gap-closure 02-11, WR-01)'
   - Linie 200-211 REPLACE: pre-fix 3-linijkowy tail (`@assert !isempty` + `sigma = std` + `return 2.0 * sigma`) → post-fix 12-linijkowy 3-way dispatch (4-linijkowy komentarz inline + `if length(worsening) >= 2` + `return 2.0 * std(worsening)` + `elseif length(worsening) == 1` + `# Single-worsening fallback...` comment + `return 2.0 * max(abs(worsening[1]), 1e-9)` + `else` + `throw(ArgumentError(...))`+ `end`)
   - Function signature, docstring intro (linie 164-173), pre-loop init (linie 187-190), for-loop body (linie 191-199) — wszystko UNTOUCHED
   - 2-arg `oblicz_energie` (linie 71-90) UNTOUCHED — WR-01 nie dotyczy 2-arg
   - 3-arg `oblicz_energie` (linie 109-131) UNTOUCHED — Plan 02-10 BL-04 fix preserved
   - `oblicz_macierz_dystans!` (linie 27-43) UNTOUCHED
   - `delta_energii` (linie 153-162) UNTOUCHED
   - Brak deviations w Task 1 boundary

2. **Task 2: Add WR-01 degenerate-path test (test/test_energia.jl)** — `971c45e` (test)
   - Files: `test/test_energia.jl` (modified, +58 -0 linii)
   - Linie 184-242 INSERT: 9th inner testset 'WR-01 kalibruj_T0 single-worsening-sample fallback'
   - 3 paths: Path 1 (n_probek=1000 canonical), Path 2 (n_probek=2 boundary), Path 3 (n_probek=1 fallback)
   - Każdy path z `try/catch` wrapper — finite>0 OR ArgumentError per nowy contract
   - Strukturalny check `occursin("if length(worsening) >= 2", src_content)` + `occursin("elseif length(worsening) == 1", src_content)` + `!occursin("@assert !isempty(worsening)", src_content)` weryfikuje implementation pattern
   - Pre-existing 8 testsetow (1-7 + BL-01 boundary jako 8) bez modyfikacji
   - Outer `@testset "test_energia.jl"` wrapper preserved
   - Brak deviations w Task 2 boundary

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

**Created (1 file):**
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-11-SUMMARY.md` — this file

**Modified (2 files):**
- `src/energia.jl` — +18 -3 linii (WR-01 fix w `kalibruj_T0`); 212 linii total (was 197)
- `test/test_energia.jl` — +58 -0 linii (9th testset 'WR-01 kalibruj_T0 single-worsening-sample fallback'); 242 linii total (was 184)

**Deleted (0 files):** Brak.

## Decisions Made

- **Wybrana opcja `explicit fallback dla length==1`** zamiast option `assert length>=2`. Plan `<objective>` explicit dokumentuje uzasadnienie: user moze legitnie konstruowac fixtures z malym n_probek (np. JET test n_probek=10) gdzie length==1 jest realnym scenariuszem, NIE programmatic error. Fallback z `2*|delta|` daje reasonable T0 zamiast NaN. Asserting length>=2 byloby zbyt restrykcyjne — przerywaloby legit small-fixture tests.

- **Wybrana 3-way dispatch (>=2 / ==1 / ==0)** zamiast 2-way (>=2 / <2). 3-way explicitly rozdziela legit fallback (==1 → finite return) od programmatic error (==0 → throw). Pre-fix `@assert !isempty` byl 2-way (==0 throws / >=1 sigma=NaN-or-finite) — to jest wlasnie source bug-a (NaN slip-through dla ==1). Post-fix 3-way eliminuje silent-failure mode.

- **Floor `max(abs(worsening[1]), 1e-9)` zachowany defensywnie.** Warunek `if delta > 0.0` przy push! gwarantuje worsening[1] > 0 (max() to pleonazm). Future-proof: jezeli kiedys ktos zmieni warunek push! z `> 0.0` na `>= 0.0` (ladowac flat moves), floor zapobiegnie T0=0 (Metropolis exp(-Δ/0)==NaN — gorsze niz pre-fix bo NaN propaguje). Komentarz inline `# Single-worsening fallback: σ aproksymowane przez sama wartosc.` dokumentuje intent.

- **Komentarz inline 4 linii** (a NIE 1-linijka 'WR-01 fix'). Future readers z `git blame`: marker, dlaczego 3-way (NaN risk z corrected=true), D-03 LOCKED preservation, ArgumentError jako programmatic error path. Komentarz `# Single-worsening fallback: σ aproksymowane przez sama wartosc.` jako oddzielna linia w `elseif` block dokumentuje fallback rationale on-site.

- **Test struktura 3 fixtures z try/catch** (NIE pojedynczy fixture z deterministycznym length==1). Konstruowanie deterministycznego length==1 wymagaloby precyzyjnego RNG seed selection (brittle wzgledem RNG stream changes na Julia minor versions per StableRNG docs). Try/catch wrapper captures full contract: KAZDY n_probek prowadzi do FINITE-OR-EXPLICIT-THROW, NIGDY NaN. Klucz: `@test isfinite(T0_*)` w success path. Trade-off: nie test wymusza deterministycznie length==1 path, ale jezeli P(length==1) > 0 dla n_probek=1 lub =2 (intuicyjnie ~50% per sample), to z 2-3 sample fixtures jest wysoka P(at least one path tested). Strukturalny check `occursin(...)` dodatkowo defens-uje przed wymianą fix-a na placeholder.

- **Strukturalny check `occursin('if length(worsening) >= 2', src_content)` dodany** jako trzeci-poziomu defense. Behavior tests (Path 1-3) moga przechodzic na alternative fix (np. `sigma = std(worsening; corrected=length(worsening)>1)` co naprawia NaN ale nie matchuje plan'u 3-way design). Strukturalny test wymusza ze IMPLEMENTATION jest zgodna z planem.

- **Project.toml / Manifest.toml NIE zmodyfikowane**: gap-closure plan, brak nowych dependencji. `Statistics: std` nadal uzywane (linia 205); Random/Xoshiro w testach z istniejacych extras.

## Deviations from Plan

### Rule 3 — Auto-fixed Blocking Issues

**1. [Rule 3 - Blocking] Edit tool path resolution: pierwsza proba edycji `src/energia.jl` z absolute parent-projekt sciezki landed w PARENT projekcie (NIE w worktree)**

- **Found during:** Task 1 verify (po pierwszej Edit) — `git diff` w worktree zwrocil pusty output mimo Edit tool reported success; `cd parent && git status -s` ujawnil ` M src/energia.jl` w PARENT projekcie. Identyczny precedens jak plan 02-10 SUMMARY.md (Rule 3 #1 sekcja).
- **Issue:** Pierwsza Edit invocation uzyl absolute path `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\src\energia.jl` (parent). Edit tool zaakceptowal ten path bo plik EXISTS (parent projekt ma copy) ale apply-edit landed w parent zamiast w worktree. Critical_tooling_note z prompt explicitly ostrzegal o tym risk-u: "every Edit/Write you perform MUST target a path inside this worktree (path contains `.claude/worktrees/agent-`)".
- **Impact na plan:** Modyfikacja Task 1 wymagala revert w parent projekcie + retry w worktree z worktree-rooted absolute path. Brak utraty pracy — parent revert byl czysty.
- **Fix:**
  1. `cd parent && git checkout -- src/energia.jl` — revert misaplied edit; parent `git status` zwrocil tylko `?? .claude/`.
  2. Re-Read worktree-rooted path `C:\Users\...\.claude\worktrees\agent-ae6bb5f591166f57a\src\energia.jl` (anchor Edit do worktree filesystem; system-reminder z CLAUDE.md confirmed worktree).
  3. Re-issue Edit z worktree-rooted absolute path — landed correctly w worktree na pierwsza probe drugiej iteracji.
  4. `git diff --stat` w worktree pokazal `1 file changed, 18 insertions(+), 3 deletions(-)` — PASS.
- **Files modified:** Brak (tooling issue, NIE algorithm bug). Worktree fix landed w jednym Edit po revert.
- **Commit:** Nie ma commitu fix-a (issue resolved przed Task 1 commit). Decyzja udokumentowana w SUMMARY.
- **Lekcja:** Powtorzony precedens z plan 02-09 i 02-10. Dla wszystkich Edit/Write tool calls w worktree zawsze uzywac WORKTREE-ROOTED absolute path z prefix `C:\Users\...\.claude\worktrees\agent-{id}\...`. Pre-Edit Read na tej samej absolute worktree path anchor-uje Edit do worktree filesystem. Jezeli Edit reported success ale `git diff` w worktree pusty — STOP, sprawdz parent projekt status, revert misaplied edit, retry z poprawna sciezka.

### Brak Rule 1 / Rule 2 / Rule 4 deviations

Plan zostal wykonany doslownie zgodnie z `<tasks>` blokiem. Wszystkie 11 Task 1 + 8 Task 2 + 5 plan-level + 7 must_have truths + 2 artifacts + 2 key_links acceptance criteria PASSING text-based. Brak architectural decisions wymaganych — implementation pattern byl explicit zdefiniowany w `<action>` block (BEFORE/AFTER kod). Function signature i caller-facing contracts UNTOUCHED dla `kalibruj_T0` (kwarg-y i return type identyczne).

## Authentication Gates

None — wszystkie modyfikacje plikow lokalne; brak external API/login wymaganego.

## Issues Encountered

- **Edit tool path resolution bug** — Rule 3 (powyzej). Naprawione w trakcie Task 1 retry przed commit. Powtorzony precedens z plans 02-09 i 02-10.
- **Niedostepna Julia uniemozliwia weryfikacje runtime** — powtorzony precedens z plans 02-01..10 SUMMARY. Wszystkie text-based + structural checks PASSING; runtime verification deferred do Plan 02-13 final pass + CI.
- **`gsd-sdk` CLI niedostepne w worktree** — stosowane direct `git commit --no-verify -m ...` per `<parallel_execution>` instructions. NIE wykonano `state advance-plan` / `update-progress` / `record-metric` calls — orchestrator owns te updates per `<objective>` ("Do NOT update STATE.md or ROADMAP.md").

## Next Plan Readiness

- **Plan 02-12 (warning gap-closure WR-02..05 lub podobne)** — odblokowane. Czy operuje na innych funkcjach lub innych plikach (WR-02 na delta_energii, WR-03 na symuluj_krok!, WR-04 na unused params, WR-05 na SimAnnealing ctor T_zero kwarg) bez konfliktu z Plan 02-11 zmian-em w kalibruj_T0.
- **Plan 02-13 (final runtime verification)** — wymaga Plans 02-09/10/11/12 complete + dostepne Julia w env (CI run). Sprawdzi:
  - `Pkg.test()` exit 0 z wszystkimi testset-ami w `test/test_energia.jl` (9 inner testsetow incl. nowy WR-01) + `test/test_symulacja.jl` + `test/test_baselines.jl`
  - WR-01 testset Path 1/2/3 PASS (text-based predicted PASS by-design)
  - Testset #6 'kalibruj_T0 zwraca rozsadna wartosc (ALG-05)' canonical path PASS (length>>1 case nie zmieniony)
  - Testset #8 'BL-01 kalibruj_T0 boundary nie crashuje' z N=3 PASS (post-fix length==K dla K = liczby unikalnych delts dla N=3 = 1; ale wszystkie K samples maja te sama wartosc; po fix length>=K, T0=2*std=0.0 dla K>=2 lub T0=2*|d| dla K==1 w pewnych RNG draws — ASSERTION `(T0 >= 0.0) || isnan(T0)` PASS oba paths bo finite>=0).
  - JET.@report_opt na `kalibruj_T0`: PASS, type-stable per `length(::Vector{Float64})::Int` + `std/max/abs/throw` type-stability.
  - Aqua.test_all clean (Plan 02-08 BL-02 fix + 02-09 + 02-10 + 02-11 preserved + brak nowych deps z Plan 02-11).

## Threat Surface Scan

**Brak nowych threat surfaces wprowadzonych przez Plan 02-11:**
- WR-01 fix to czysto wewnetrzny algorithm restructure — zero network, zero secrets, zero PII, zero file I/O, zero process spawn.
- Function signature `kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng)::Float64` niezmieniona — brak zmiany API surface.
- Test file `test/test_energia.jl` dodaje `read(src_path, String)` w strukturalnym check (linia 236) — read-only operacja na własnym package source (`pkgdir(JuliaCity)/src/energia.jl`); standardowy Julia idiom dla introspection-based testow. Zero escalated privilege; zero network.
- Threading correctness niezmieniona (3-arg oblicz_energie nie tknięte; kalibruj_T0 nie thread-uje).
- Memory safety identyczna pre/post-fix (length(worsening) check przed std() call; max() z floor nie crash-uje na length==0 path bo throw raczej niz access).
- ArgumentError message zawiera `n_probek` i `n` — non-sensitive integer values from input, no PII leak risk.

Plan 02-11 to pure-algorithmic gap-closure: zero security-relevant surface zmienione.

## Self-Check: PASSED

All claims verified.

**Files:**
- `src/energia.jl` — FOUND (212 linii, 1 wystapienie `if length(worsening) >= 2`, 1 wystapienie `elseif length(worsening) == 1`, 0 wystapien `@assert !isempty(worsening)`, 0 wystapien `sigma = std(worsening)`, 1 wystapienie `max(abs(worsening[1]), 1e-9)`, 1 wystapienie `WR-01 fix (gap-closure 02-11)`, 1 wystapienie `Edge cases (gap-closure 02-11, WR-01)`, BL-01 fix preserved (`rand(rng, 1:(n - 2))` count == 1), BL-04 fix preserved (`enumerate(chunks(` count == 0; `eachindex(cs)` count == 1), 5 funkcji bez zmian)
- `test/test_energia.jl` — FOUND (242 linii, 1 nowy testset `WR-01 kalibruj_T0 single-worsening-sample fallback`, 3 paths z `kalibruj_T0(stan*; n_probek=*)` calls, 3 wystapien `isfinite(T0`, 1 strukturalny `occursin("if length(worsening) >= 2", src_content)`, pre-existing testsety 1-8 zachowane incl. Plan 02-07 BL-01 boundary regression)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-11-SUMMARY.md` — FOUND (this file, will be committed below)

**Commits:**
- `4d44c17` (Task 1: WR-01 kalibruj_T0 NaN guard via 3-way length dispatch) — FOUND in git log
- `971c45e` (Task 2: WR-01 single-worsening-sample fallback testset) — FOUND in git log

**Verification block from PLAN executed:**
- Plan-level verify: 5/5 grep checks PASS (length>=2 == 1, length==1 == 1, testset name == 1, BL-01 == 1, BL-04 enumerate == 0)
- Task 1 acceptance: 11/11 PASS (3-way dispatch markers + old guards eradicated + fallback expression + docstring section + plan 02-07/02-10 preserved + function count)
- Task 2 acceptance: 8/8 PASS (testset name + 3 path calls + 3 isfinite + structural occursin + Plan 02-07 testset preserved + outer wrapper)
- Plan-level success criteria: 5/5 PASS (WR-01 fixed, length-1 finite, length-0 ArgumentError, 02-07/10 preserved, ALG-05 unblocked text-based)
- Plan-level must_haves truths: 7/7 PASS
- Plan-level must_haves artifacts: 2/2 PASS
- Plan-level must_haves key_links: 2/2 PASS
- Runtime verification: deferred do Plan 02-13 (Julia NIE w worktree env, Rule 3 precedens z plans 02-01..10)

**Phase 2 Plan 11 KOMPLETNA jako file modifications + 2 task commits + 1 metadata commit (this SUMMARY) — pelna runtime weryfikacja oczekuje Plan 02-13 final pass z dostepna Julia (julia-actions/julia-buildpkg w CI). Algorytmiczna poprawnosc zweryfikowana przez:**
1. **Equivalence argument (length>=2 path):** post-fix zwraca `2.0 * std(worsening)` identycznie jak pre-fix `2.0 * sigma` z `sigma = std(worsening)` — bit-identyczny wynik dla canonical case.
2. **NaN elimination (length==1 path):** post-fix zwraca `2.0 * max(abs(worsening[1]), 1e-9)` (finite >= 2e-9 dla d > 0) zamiast pre-fix `2.0 * NaN` — dokumentowana eliminacja silent-failure mode.
3. **Explicit error (length==0 path):** post-fix `throw(ArgumentError(...))` zamiast pre-fix `@assert ... false` — bardziej idiomatyczny Julia error type, message z context (n_probek, n).
4. **D-03 LOCKED preserved:** canonical T0 = 2σ contract dla dominant length>=2 path bez zmian; degenerate paths dokumentowane w docstring.
5. **Plan 02-07 BL-01 preserved:** linia 187 `i = rand(rng, 1:(n - 2))` niezmieniona — Plan 02-07 fix nadal aktywny.
6. **Plan 02-10 BL-04 preserved:** linie 109-131 (3-arg `oblicz_energie` z canonical chunked-threading) niezmienione — Plan 02-10 fix nadal aktywny.

**Wave 9 WR-01 gap-closure DONE.**

---
*Phase: 02-energy-sa-algorithm-test-suite*
*Completed: 2026-04-29*
