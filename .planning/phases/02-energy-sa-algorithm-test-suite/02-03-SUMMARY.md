---
phase: 02-energy-sa-algorithm-test-suite
plan: 03
subsystem: nn-baseline
tags: [julia, baseline, nearest-neighbor, initialization, wave-3]

requires:
  - phase: 02-02
    provides: "src/energia.jl z oblicz_macierz_dystans!(stan) i oblicz_energie(D, trasa, bufor) sygnaturami; oba w scope module-level via include w src/JuliaCity.jl"
  - phase: 01-04
    provides: "src/typy.jl ze parametrycznym StanSymulacji{R<:AbstractRNG}; mutable pola trasa, energia, iteracja"
  - phase: 01-05
    provides: "src/punkty.jl jako analog file-header / docstring / two-method idiom"
provides:
  - "src/baselines.jl z trasa_nn (pure) + inicjuj_nn! (mutating wrapper)"
  - "trasa_nn(D::Matrix{Float64}; start::Int=1)::Vector{Int} — pure NN tour, używana w TEST-05 NN-baseline-beat bez Stana (D-14)"
  - "inicjuj_nn!(stan::StanSymulacji) — 4-step mutating init (D-14): macierz dystansów, trasa NN, energia (cache invariant D-08), reset iteracji"
  - "src/JuliaCity.jl rozszerzony o include('baselines.jl') po energia.jl + export trasa_nn, inicjuj_nn!"
affects: [02-04-distance-init-temp-cooling, 02-05-test-suite-correctness, 02-06-quality-gates]

tech-stack:
  added: []
  patterns:
    - "src/baselines.jl mirror-uje konwencję src/punkty.jl + src/energia.jl: file-header polski hash-comment z REQ-IDs + D-decisions; Polish prose docstring + 1-linia signature + Examples jldoctest + Argumenty list; brak using statementów (wszystko w scope przez src/JuliaCity.jl)"
    - "Two-method idiom (D-14): pure trasa_nn(D; start) deleguje algorytm do funkcji niezależnej od Stana; mutating inicjuj_nn!(stan) wykonuje 4-step pipeline (oblicz_macierz_dystans! -> trasa_nn -> oblicz_energie -> reset iteracja) i jest jedyną drogą wypełnienia stan.D + stan.energia spójnie z cache invariantem D-08"
    - "@inbounds tylko na zewnętrznym for w trasa_nn (k in 2:n) — bezpieczne dzięki asercjom n+start; wewnętrzny for j in 1:n NIE ma @inbounds (mała funkcja, marginalny zysk, jasna intencja)"
    - "start=1 zafiksowane w inicjuj_nn! per D-15 — brak RNG-zależności; testy NN-baseline-beat (TEST-05) porównują SA-z-start=1 vs NN-z-start=1, więc determinizm baseline jest wymagany"
    - "Asercje wewnętrzne po angielsku per LANG-04: 'D must be square', 'start out of range'; ASCII identyfikatory (odwiedzone, biezacy, najblizszy, min_dist) per BOOT-04"

key-files:
  created:
    - "src/baselines.jl"
    - ".planning/phases/02-energy-sa-algorithm-test-suite/02-03-SUMMARY.md"
  modified:
    - "src/JuliaCity.jl"

key-decisions:
  - "trasa_nn explicit return type ::Vector{Int} dodany na sygnaturze (plan template: `function trasa_nn(D::Matrix{Float64}; start::Int=1)::Vector{Int}`) — single concrete return type aids type inference (RESEARCH Pitfall B); spójne z energia.jl gdzie kalibruj_T0 i obie metody oblicz_energie też mają explicit ::Float64. Type-stability zostanie zweryfikowana w Plan 02-05 (TEST-08 @inferred)."
  - "inicjuj_nn! BEZ explicit return type ::Nothing na sygnaturze (plan template: `function inicjuj_nn!(stan::StanSymulacji)`) — Julia infers void return; jednak `return nothing` literal pozostaje explicit per Pitfall B (@inferred ::Nothing wymaga literal return). Spójne z oblicz_macierz_dystans! w energia.jl, który stosuje identyczny wzorzec (no ::Nothing annotation, ale literal `return nothing`)."
  - "@inbounds TYLKO na zewnętrznym for k in 2:n w trasa_nn (jak plan template w PLAN <action>) — wewnętrzny for j in 1:n bez @inbounds (mała funkcja, niska wartość elision, jasna intencja). Zewnętrzny @inbounds jest bezpieczny: trasa[k-1] przy k>=2 jest legalne, a wewnętrzny for nie indeksuje trasa[i] dla i poza rozsądnym zakresem."
  - "Manifest.toml NIE zaktualizowany — Plan 02-03 NIE dodaje nowych zależności (`tech-stack.added: []`); brak akcji na pliku Project.toml ani Manifest.toml. Powtórzenie precedensu z Plan 02-01 i 02-02 nie ma zastosowania (te plany dotyczyły dodawania dependencji)."

requirements-completed: [ALG-04]

duration: 3min 12s
completed: 2026-04-29
---

# Phase 02 Plan 03: NN Baseline + Mutating Stan Initializer Summary

**NN-baseline (greedy nearest-neighbor) jako dual entry-point: pure `trasa_nn(D; start)` dla TEST-05 NN-baseline-beat, oraz mutating wrapper `inicjuj_nn!(stan)` który wypełnia `stan.D`, `stan.trasa`, `stan.energia` w spójnej sekwencji 4 kroków przed startem SA. Pokrywa REQ ALG-04 — flow inicjalizacji Phase 2 jest kompletny.**

## Performance

- **Duration:** ~3min 12s wall-clock
- **Started:** 2026-04-29T07:16:47Z
- **Completed:** 2026-04-29T07:19:59Z
- **Tasks:** 2 (auto, brak checkpointów)
- **Files modified:** 1 (`src/JuliaCity.jl`)
- **Files created:** 2 (`src/baselines.jl`, this SUMMARY.md)

## Source Counts

- `src/baselines.jl`: **102 linie** (sanity check >= 40 PASS — 2.5x ponad próg)
  - 2 funkcje: `trasa_nn` (line 50, pure) i `inicjuj_nn!` (line 95, mutating)
  - Polish docstrings + English asserts + Polish hash-comments
  - UTF-8 NFC bez BOM, ASCII filename, LF line endings (zweryfikowane przez `file` + Python decode + NFC porównanie)
- `src/JuliaCity.jl`: **43 linie** (po +5 -1 patchu z Wave 3)
  - `include("baselines.jl")` na linii 35, po `include("energia.jl")` na linii 32
  - Topologiczna kolejność includes: typy(26) -> punkty(29) -> energia(32) -> baselines(35)
  - Export rozszerzony o `trasa_nn`, `inicjuj_nn!` (line 41)

## Smoke Test Results

**Roadmap SC-1 + Test 1 (4-square deterministic — RNG-independent):**

```
pkty4 = [Punkt2D(0.0, 0.0), Punkt2D(1.0, 0.0), Punkt2D(1.0, 1.0), Punkt2D(0.0, 1.0)]
trasa = trasa_nn(D; start=1)  # NN starting at (0,0): -> (1,0) -> (1,1) -> (0,1) -> back
sort(trasa) == [1,2,3,4]      # TRUE (verified via Python algorithmic mirror)
oblicz_energie(pkty4, trasa) ≈ 4.0  # TRUE (perimeter sum, 4 unit edges)
```

**Test 2 — NN energia dla N=100 (algorithmic mirror via Python MT seed=42):**

```
energia ≈ 10.628  (Python MT — Julia Xoshiro będzie inne dla seed=42)
0 < energia < 100*sqrt(2) ≈ 141.42  # TRUE (sanity bound for N=100 unit-square points)
```

**WAŻNE:** Energia ~10.63 z Python MT NIE jest predykcją Julia Xoshiro. Julia z `seed=42` da inną liczbę (różne strumienie RNG między Python MT a Julia Xoshiro), ale jakościowo:
- Permutacja `sort(trasa) == 1:100` — gwarantowana algorytmicznie (NN nie pomija węzłów; struktura `odwiedzone` chroni)
- Energia w zakresie `(0, n*sqrt(2))` — gwarantowane geometrycznie (każda krawędź <= sqrt(2) bo punkty w unit-square)
- Stała wartość dla danego seeda — gwarantowana determinizmem (start=1, brak RNG w `trasa_nn` po wygenerowaniu punktów)

Empiryczna wartość referencyjna Julia Xoshiro `seed=42` zostanie zarejestrowana w Plan 02-05 (TEST-05 NN-baseline-beat) lub pierwszym CI runie.

**Test 3 — N=20 sanity check (mutating wrapper invariants — algorithmic mirror):**

```
inicjuj_nn!(stan):
  stan.trasa = [1, 8, 11, 19, 2, ...]   # przykładowa kolejność (zależy od RNG)
  sort(stan.trasa) == 1:20              # TRUE
  stan.D[1, 1] == 0.0                   # TRUE (diagonal zero — z oblicz_macierz_dystans!)
  stan.D[1, 2] == stan.D[2, 1]          # TRUE (symmetric — z oblicz_macierz_dystans!)
  stan.energia > 0                      # TRUE (positive perimeter sum)
  stan.iteracja == 0                    # TRUE (reset jako ostatni krok inicjuj_nn!)
```

Wszystkie 4 niezmienniki acceptance criteria z Plan 02-03 `<verify>` blocku są pokryte przez Python algorithmic mirror; Julia runtime confirmation pozostaje do CI.

## Exports Verification

Po Wave 3 export list w `src/JuliaCity.jl` (lines 38-41) zawiera:

```julia
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty,
       Parametry,
       oblicz_macierz_dystans!, oblicz_energie, delta_energii, kalibruj_T0,
       trasa_nn, inicjuj_nn!
```

**Wszystkie 2 nowe nazwy z Plan 02-03 są eksportowane** (`trasa_nn`, `inicjuj_nn!`) — zweryfikowane przez `grep` na liście `export`. Razem z 4 z Plan 02-02 i 5 z Plan 02-01/Phase 1, łączna lista exportu liczy **11 publicznych nazw**.

## Phase 1 + Wave 1 Tests Status

**Runtime verification niemożliwy lokalnie** (Julia nie jest zainstalowana w Windows worktree environment — zgodnie z `<environment_note>` w prompcie executora oraz precedensem z Plan 02-01 i 02-02 SUMMARY).

**Mitigacja:** Pierwszy `Pkg.test()` na maszynie z Julia (lokalnie u developera lub w GitHub Actions CI po pushu) wykona Phase 1 testy + Wave 0/1 smoke + sprawdzi czy `using JuliaCity; inicjuj_nn!(stan)` działa na realnym N=20.

**Spodziewane wyniki (algorithmic + structural reasoning):**
- **Phase 1 testy** (encoding, generuj_punkty, no-global-RNG, StanSymulacji, Aqua, JET smoke) — POWINNY pozostać zielone, bo Plan 02-03 NIE modyfikuje kodu na którym te testy operują (baselines.jl jest nowym plikiem; JuliaCity.jl ma tylko dodatkowy include + export bez zmiany istniejących nazw)
- **Wave 0/1 smoke** (Punkt2D, StableRNG, oblicz_energie, delta_energii, kalibruj_T0) — niezależne od baselines.jl, zachowują swój status
- **Plan 02-03 nie wprowadził nowych testów** (te przyjdą w 02-05/06) — SC kompletny strukturalnie

## Algorithmic Verification (Python Mirror)

Wszystkie 4 funkcjonalne kontrakty z planu zweryfikowane przez deterministyczny Python algorithmic mirror (NN greedy z `odwiedzone::falses(n)` + argmin po `D[biezacy, j]`, identyczny z RESEARCH Pattern 3):

1. **Permutacja**: `sort(trasa_nn(D)) == 1:n` — TRUE dla N ∈ {4, 20, 100}
2. **Determinizm**: dla danego (D, start) `trasa_nn(D; start=1) == trasa_nn(D; start=1)` — TRUE (algorytm jest pure)
3. **Cykl Hamiltona — energia**: `oblicz_energie(pkty4=square, trasa=[1,2,3,4]) == 4.0` — TRUE (perimeter)
4. **inicjuj_nn! invariants**: po wywołaniu `stan.D` symetryczne z zero-diagonalą, `sort(stan.trasa) == 1:n`, `stan.energia > 0`, `stan.iteracja == 0` — wszystkie TRUE

Algorytm w `src/baselines.jl` jest *literalnie* skopiowany z PLAN `<action>` (które są skopiowane z RESEARCH Pattern 3 lines 226-263), więc Python mirror logicznie odpowiada Julia kodowi (z wyjątkiem indeksowania 0-based vs 1-based, które jest oczywiste).

## Threading Pattern

`trasa_nn` jest **explicitly NOT threadowane** — analogicznie do `delta_energii` (D-08). Argumentacja: O(n²) algorytm jest sekwencyjny z natury (każdy krok `k` zależy od `trasa[k-1]`), więc threading można by zastosować tylko do wewnętrznego argmin loop (n iteracji), ale dla typowych N <= 1000 inner loop bierze ~10-20 µs, poniżej progu opłacalności threadingu (PROJECT.md: "Don't thread tighter than ~100 µs per task").

`inicjuj_nn!` korzysta z `oblicz_energie(stan.D, stan.trasa, bufor)` — która JEST threadowana przez ChunkSplitters (wzorzec D-11 z Plan 02-02). To jednorazowe wywołanie podczas inicjalizacji, więc allocation `bufor = zeros(Float64, Threads.nthreads())` jest akceptowalna (nie hot-path).

## Task Commits

1. **Task 1: Utworzyć src/baselines.jl z trasa_nn + inicjuj_nn!** — `85666a7` (feat)
   - Files: `src/baselines.jl` (created, 102 linie)
   - 2 funkcje z Polish docstrings + English asserts; pure trasa_nn z @inbounds na zewnętrznym for; mutating inicjuj_nn! z 4-step pipeline
   - Brak deviations (Write tool zadziałał poprawnie z forward-slash absolute path do worktree na pierwszą próbę — leveraged precedent z Plan 02-02)

2. **Task 2: Wire src/baselines.jl do src/JuliaCity.jl** — `ccdb8c4` (feat)
   - Files: `src/JuliaCity.jl` (modified, +5 -1 linii)
   - `include("baselines.jl")` po `include("energia.jl")`, export rozszerzony o 2 nazwy (trasa_nn, inicjuj_nn!)
   - Polski komentarz nad include zgodny z Phase 1 + Wave 1 konwencją

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

**Created (2 files):**
- `src/baselines.jl` — 102 linie, 2 funkcje (trasa_nn, inicjuj_nn!) z Polish docstrings i English asserts
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-03-SUMMARY.md` — this file

**Modified (1 file):**
- `src/JuliaCity.jl` — +5 linii (-1): include('baselines.jl') + Polski komentarz, export 2 nowych nazw na końcu istniejącej listy

## Decisions Made

- **trasa_nn z explicit return type `::Vector{Int}`** — single concrete return type aids type inference (RESEARCH Pitfall B). Spójne z energia.jl gdzie kalibruj_T0, obie metody oblicz_energie też mają explicit `::Float64`. Type-stability zostanie zweryfikowana w Plan 02-05 (TEST-08 `@inferred trasa_nn(D)`).

- **inicjuj_nn! BEZ explicit `::Nothing` na sygnaturze** — Julia infers void return; jednak `return nothing` literal pozostaje explicit per Pitfall B (@inferred ::Nothing wymaga literal return). Spójne z oblicz_macierz_dystans! w energia.jl, który stosuje identyczny wzorzec (no `::Nothing` annotation, ale literal `return nothing`).

- **`@inbounds` TYLKO na zewnętrznym for w trasa_nn** — plan template. Wewnętrzny `for j in 1:n` BEZ `@inbounds` (mała funkcja, niska wartość elision, jasna intencja). Argumenty bezpieczeństwa: zewnętrzny `for k in 2:n` indeksuje `trasa[k-1]` (legalne) i `trasa[k]` (legalne, k <= n); wewnętrzny `for j` indeksuje `D[biezacy, j]` (legalne, j w 1:n) i `odwiedzone[j]` (legalne).

- **`Manifest.toml` i `Project.toml` NIE zmodyfikowane** — Plan 02-03 NIE dodaje nowych dependencji (frontmatter `tech-stack.added: []`); cały kod baselines.jl używa tylko już-importowanych typów (`StanSymulacji` z `typy.jl`, `Threads.nthreads()` z stdlib `Threads`, `oblicz_macierz_dystans!`/`oblicz_energie` z `energia.jl`). Brak akcji na deps.

## Deviations from Plan

### Rule 3 — Auto-fixed Blocking Issues

**1. [Rule 3 - Blocking] Środowisko worktree NIE ma zainstalowanej Julii (powtórzony precedens z Plan 02-01 i 02-02)**

- **Found during:** Initial environment check przed Task 1 verify
- **Issue:** `<environment_note>` w prompcie executora explicit potwierdza: "Julia is NOT installed on this machine. Apply same protocol as plans 02-01 and 02-02: text-based acceptance only; document deferred runtime verification as Rule 3 deviation in SUMMARY.md".
- **Impact na plan:** Wszystkie `<verify><automated>julia --project=. -e ...</automated></verify>` blocks niewykonalne lokalnie. Plan-level integration `Pkg.test()` również blocked. Roadmap SC-1 (4-square = 4.0) zweryfikowany ALGORYTMICZNIE w Python (identyczny upper-triangle distance + NN greedy + mod1 cycle sum, wynik 4.0 exact).
- **Fix:** Wszystkie text-based acceptance criteria (grep counts, awk line counts, NFC/BOM/CR checks, file utility output) ZWERYFIKOWANE PASSING. Algorytmiczna correctness zweryfikowana przez Python mirror (3 test cases: 4-square, N=20, N=100). Runtime weryfikacja w Julii pozostaje DO CI lub dev-machine.
- **Files modified:** Brak (środowiskowy issue)
- **Commit:** Nie ma commitu fix-a (nie ma modyfikacji plików); decyzja udokumentowana w SUMMARY (decisions section).

### Brak Rule 1/2/4 deviations

Plan został wykonany dosłownie zgodnie z `<tasks>` i `<context><interfaces>` blokami. Obie funkcje mają sygnatury, asercje i algorytmy zgodne z lock-in patternami z CONTEXT.md (D-14 dual entry points, D-15 start=1) i RESEARCH.md (Pattern 3, lines 226-263).

**Brak deviation z Plan 02-02 typu "Write tool path resolution bug"** — Pierwszy `Write` w Task 1 używał forward-slash absolute path (`C:/Users/.../worktrees/agent-.../src/baselines.jl`), tak jak udokumentowane w 02-02 SUMMARY jako naprawiony pattern. Plik zalandował w worktree (NIE w parent project) na pierwszą próbę. Wszystkie kolejne Edit-y na `src/JuliaCity.jl` również używały forward-slash worktree path — bez problemu.

## Authentication Gates

None — wszystkie modyfikacje plików lokalne; brak external API/login wymaganego.

## Issues Encountered

- **Niedostępna Julia uniemożliwia weryfikację runtime** — Rule 3 (powyżej). Wszystkie text-based + algorithmic-Python mirror checks PASSING; runtime verification deferred do CI.
- **`gsd-sdk` CLI niedostępne w worktree** — stosowane direct `git commit --no-verify -m ...` per `<parallel_execution>` instructions. NIE wykonano `state advance-plan` / `update-progress` / `record-metric` calls — orchestrator owns te updates per `<objective>` ("Do NOT update STATE.md or ROADMAP.md").
- **Brak `Pkg.instantiate` / Manifest update** — Plan 02-03 NIE dodaje deps (`tech-stack.added: []`), więc nawet z dostępną Julią nie byłoby zmiany w `Manifest.toml`.

## Next Plan Readiness

- **Plan 02-04 (cooling schedule + symuluj_krok! SA)** — odblokowany. Wymaga: `inicjuj_nn!(stan)` (✓) jako entry point dla flow inicjalizacji SA, `delta_energii(stan, i, j)` (✓ z 02-02), `kalibruj_T0(stan)` (✓ z 02-02), `Parametry` (✓ z 02-01). SA hot loop wywoła `delta_energii` + Metropolis acceptance + `reverse!(view(stan.trasa, ...))` + `stan.energia += delta` cache invariant (D-08).
- **Plan 02-05 (test suite correctness — TEST-05 NN-baseline-beat)** — odblokowany. Test będzie:
  ```
  inicjuj_nn!(stan_nn); E_nn = stan_nn.energia
  inicjuj_nn!(stan_sa); ...; symuluj_krok! 50000 razy; E_sa = stan_sa.energia
  @test E_sa <= 0.9 * E_nn   # SA musi być >= 10% krótszy niż NN dla N=1000 seed=42
  ```
  trasa_nn jest gotowy jako baseline; `inicjuj_nn!` jest gotowy jako start dla SA.
- **Plan 02-06 (quality gates Aqua/JET)** — odblokowany. Aqua test pokrywa również baselines.jl (publiczne API). JET `@report_opt` na trasa_nn (czysty algorytm) + inicjuj_nn! (mutating wrapper, sprawdzi czy delegacja do oblicz_energie threadowanego nie wprowadza instability).

## Threat Surface Scan

Zagrożenia z `<threat_model>` planu 02-03 zaadresowane:

- **T-02-07 (Tampering, trasa_nn dla niekwadratowej D):** mitigate — `@assert n == size(D, 2) "D must be square"` na linii 51 baselines.jl. PASS przez grep verification.
- **T-02-08 (Tampering, trasa_nn dla start poza 1:n):** mitigate — `@assert 1 <= start <= n "start out of range"` na linii 52 baselines.jl. PASS przez grep verification.
- **T-02-09 (Information Disclosure, error messages):** accept — Standard Julia error message convention; brak sekretów w D.

**Brak nowych threat surfaces poza zarejestrowanymi.** Plan 02-03 to pure-algorithmic baseline kod: zero network, zero secrets, zero PII, zero file I/O, zero process spawn. Asercje są minimalne i nie ujawniają wewnętrznych szczegółów ponad niezbędne dla diagnostyki.

## Self-Check: PASSED

All claims verified.

**Files:**
- `src/baselines.jl` — FOUND (102 linie, 2 funkcje, all 9 grep acceptance criteria PASS)
- `src/JuliaCity.jl` — FOUND (43 linie, include("baselines.jl") na linii 35, export rozszerzony o 2 nazwy na linii 41, all 5 grep acceptance criteria PASS)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-03-SUMMARY.md` — FOUND (this file, will be committed below)

**Commits:**
- `85666a7` (Task 1: src/baselines.jl creation) — FOUND in git log
- `ccdb8c4` (Task 2: wire baselines.jl into JuliaCity.jl) — FOUND in git log

**Verification block from PLAN executed:**
- Task 1 acceptance criteria: 9/9 text-based PASS (grep counts, line counts, NFC/BOM/ASCII filename, encoding); Roadmap SC-1 algorithmically verified PASS via Python mirror simulation (4.0 exact match); runtime `julia --project=. -e ...` blocked by no-Julia env
- Task 2 acceptance criteria: 5/6 text-based PASS (grep counts, topological order); 1 deferred (`Pkg.test()` exit 0 — runtime blocked)
- Plan-level integration smoke (NN energy on N=100 in expected range): algorithmically verified PASS via Python mirror (energia=10.628 dla Python MT — Julia Xoshiro będzie inne, ale w tym samym sanity range 0..141.42)

**Phase 2 Plan 03 KOMPLETNA jako file modifications + 2 commits — pełna runtime weryfikacja oczekuje pierwszego CI runa (julia-actions/julia-buildpkg uruchomi Pkg.test). Algorytmiczna poprawność zweryfikowana przez Python mirror na 3 test cases (4-square SC-1, N=20 mutating invariants, N=100 sanity range).**

---
*Phase: 02-energy-sa-algorithm-test-suite*
*Completed: 2026-04-29*
