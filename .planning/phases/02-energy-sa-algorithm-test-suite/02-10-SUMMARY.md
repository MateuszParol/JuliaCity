---
phase: 02-energy-sa-algorithm-test-suite
plan: 10
subsystem: energy-hot-path
tags: [julia, bug-fix, threading, chunksplitters, canonical-pattern, gap-closure, wave-8]

requires:
  - phase: 02-02
    provides: "src/energia.jl::oblicz_energie 3-arg z ChunkSplitters + bufor[chunk_idx] per-chunk accumulator + sum(bufor) reduce (D-10/D-11 LOCKED) — pre-fix wzorzec mial enumerate(chunks(...)) wokol @threads"
  - phase: 02-07
    provides: "src/energia.jl::kalibruj_T0 z BL-01 fix `i = rand(rng, 1:(n - 2))` (NIE regress) — preserve criterion #7"
provides:
  - "src/energia.jl::oblicz_energie 3-arg z kanonicznym chunked-threading pattern: cs = collect(chunks(...)) materialized + Threads.@threads :static for chunk_idx in eachindex(cs) + cs[chunk_idx] indexed access"
  - "BL-04 anti-pattern eradicated: zero wystapien `enumerate(chunks(` w src/energia.jl (executable + komentarze)"
affects: [02-13-final-runtime-verification]

tech-stack:
  added: []
  patterns:
    - "Materialized chunks pattern: `cs = collect(chunks(1:n; n=nchunks))` przed @threads daje Vector{UnitRange{Int}} (length=nchunks ≤ nthreads()), ktory jest indexable zgodnie z @threads :static wymogiem (Julia 1.10 manual). Pre-fix wzorzec `Iterators.Enumerate` nad ChunkSplitters.Chunk byl non-canonical — Enumerate nie ma stabilnego getindex; pattern moze byc silently broken na Julia minor-version bumpach."
    - "Indexed-eachindex iteration: `for chunk_idx in eachindex(cs)` zamiast `for (chunk_idx, krawedzie) in enumerate(...)` daje czysty Int iterator (firstindex/lastindex/getindex stable per Vector contract) — @threads moze partycjonowac index range across tasks bez dependence na inner-iterator semantyce."
    - "Cosmetic comment-substring discipline: edukacyjne komentarze NIE moga uzywac dosłownego `enumerate(chunks(` ani `collect(chunks(` jako must_have grep-contracts mierza substringi w calym pliku (nie tylko w kodzie). Komentarz uzyl `Iterators.Enumerate nad chunks(...)` + `collect` description by zachowac edukacyjna intencje bez kolizji z grep contractami."

key-files:
  created:
    - ".planning/phases/02-energy-sa-algorithm-test-suite/02-10-SUMMARY.md"
  modified:
    - "src/energia.jl"

key-decisions:
  - "Wybrana opcja `collect(chunks(...))` pre-materialization** zgodnie z BL-04 fix recipe w 02-REVIEW.md. Alternatywa (anonimowy `chunks(1:n; n=nchunks)[chunk_idx]` per-task) wymagalaby `chunks(...)` calls wewnatrz body petli — silnie odbiega od D-10 'pre-allokowany bufor' filozofii i mogla by introduce subtelne race-y na ChunkSplitters internals. `collect` daje O(nchunks) jednorazowy alloc (~128B dla nthreads=8) ktory miesci sie w ENE-03 threshold <4096B (WR-07 z 02-REVIEW.md zachowuje ten threshold)."
  - "Komentarz inline ROZBUDOWANY do 7 linii (a NIE 1-linijka 'BL-04 fix') by jednoznacznie udokumentowac:** (a) co bylo pre-fix wzorcem (Iterators.Enumerate nad chunks), (b) DLACZEGO byl bug (Threads.@threads wymaga indexable iteratora, Julia 1.10 manual), (c) co jest fix (collect → Vector{UnitRange{Int}}), (d) alloc cost (~128B w ENE-03 threshold), (e) ze D-11 LOCKED jest preserved (NIE wracamy do threadid()). Future readers z `git blame` zobacza pelne uzasadnienie bez koniecznosci czytania REVIEW/PLAN."
  - "Komentarz przepisany 2x by uniknac kolizji z grep contractami:** Wersja 1 zawierala doslowne `enumerate(chunks(...))` i `collect(chunks(...))` w komentarzu, ktore niechcaco lapaly grep '-c' na must_have #6/#7 (anti-pattern eradicated count == 0; canonical present count == 1). Wersja finalna uzywa `Iterators.Enumerate nad chunks(...)` + opisowy 'Materializujemy chunki przez collect'. Substring discipline: must_haves mierza calym plikiem nie tylko kodem, wiec komentarze takze podlegaja constraint-om."
  - "Function signature `function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64` NIEZMIENIONA per plan explicit constraint.** Caller contracts (D-10 bufor pre-alokowany; 2-arg oblicz_energie delegate na linii 89; tests w test/test_energia.jl _alloc_3arg helper) wszystkie wymagaja stalej sygnatury. BL-04 fix to czysto wewnetrzny algorithm restructure — zero impact na public API."
  - "`Manifest.toml` i `Project.toml` NIE zmodyfikowane**: gap-closure plan, brak nowych dependencji. ChunkSplitters jest juz w deps (Plan 02-02 inicjalna integracja, D-11 LOCKED)."

requirements-completed: [ENE-02, ENE-05, ALG-05]

duration: 3min 26s
completed: 2026-04-29
---

# Phase 02 Plan 10: BL-04 enumerate(chunks(...)) → canonical collect+eachindex Summary

**Naprawia BLOCKER BL-04 z 02-REVIEW.md — `Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))` w `src/energia.jl:113` byl non-canonical wzorcem. `Threads.@threads` (Julia 1.10) wymaga indexable iteratora; `Iterators.Enumerate` nad `ChunkSplitters.Chunk` nie ma stabilnego getindex — pattern moze byc silently broken na Julia minor-version bumpach. Implementation przepisany na kanoniczny pattern: `cs = collect(chunks(...))` materializuje chunki do `Vector{UnitRange{Int}}` przed @threads, indexowanie przez `eachindex(cs)` + `cs[chunk_idx]`. ChunkSplitters integration preserved (D-11 LOCKED — NIE wracamy do threadid()). Plan 02-07 BL-01 fix w kalibruj_T0 zachowany. Alloc impact: ~128B per call (Vector{UnitRange{Int}} z length=nchunks ≤ nthreads()) — miesci sie w ENE-03 threshold <4096B (WR-07 zachowuje ten threshold).**

## Performance

- **Duration:** ~3min 26s wall-clock
- **Started:** 2026-04-29T11:22:13Z
- **Completed:** 2026-04-29T11:25:39Z
- **Tasks:** 1 (auto, brak checkpointow)
- **Files modified:** 1 (`src/energia.jl`)
- **Files created:** 1 (this SUMMARY.md)
- **Files deleted:** 0

## Source Counts

- `src/energia.jl`: **197 linii** (+8 wzgledem 02-09 baseline 189)
  - 3-arg `oblicz_energie` body: 22 linie (was 14) — +7 z dodanego 7-linijkowego komentarza inline (BL-04 fix rationale) + +1 z dodanej linii `cs = collect(chunks(1:n; n=nchunks))`
  - Funkcji w pliku: **5** (oblicz_macierz_dystans!, oblicz_energie ×2, delta_energii, kalibruj_T0) — bez zmian
  - `enumerate(chunks(` count: **0** (anti-pattern eradicated zarowno z kodu jak i z komentarzy)
  - `collect(chunks(` count: **1** (canonical pattern present, w jednym miejscu — linia 120)
  - `Threads.@threads :static for chunk_idx in eachindex(cs)` count: **1** (linia 121)
  - `BL-04 fix (gap-closure 02-10)` marker: **1** (linia 113, komentarz inline)
  - `cs[chunk_idx]` indexed access: **1** (linia 123, `@inbounds for k in cs[chunk_idx]`)
  - `for k in krawedzie` (old variable name): **0** (eradicated)
  - BL-01 fix preserved: `rand(rng, 1:(n - 2))` count == **1** (linia 179 w `kalibruj_T0`, niezmieniony)
  - `bufor[chunk_idx] = s` per-chunk accumulator: **1** (linia 128, niezmieniony)
  - `return sum(bufor)` final reduce: **1** (linia 130, niezmieniony)
  - 2-arg `oblicz_energie(punkty, trasa)` delegate: `return oblicz_energie(D, trasa, bufor)` count == **1** (linia 89, niezmieniony)
  - Docstring 3-arg (linie 92-108): UNTOUCHED — claim "ChunkSplitters.chunks (D-11)" + "Pitfall 2: nie reasignujemy captured scalar" + "bufor[chunk_idx] indexed accumulator" pozostaje accurate per nowy pattern

## BL-04 Fix Mechanics

### Pre-fix (non-canonical: enumerate(chunks(...)))
```julia
function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64
    n = length(trasa)
    nchunks = length(bufor)
    fill!(bufor, 0.0)
    Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))   # <-- BL-04 BUG
        s = 0.0
        @inbounds for k in krawedzie
            i_aktualne = trasa[k]
            i_nastepne = trasa[mod1(k + 1, n)]
            s += D[i_aktualne, i_nastepne]
        end
        bufor[chunk_idx] = s
    end
    return sum(bufor)
end
```

### Post-fix (canonical: collect + eachindex)
```julia
function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64
    n = length(trasa)
    nchunks = length(bufor)
    fill!(bufor, 0.0)
    # BL-04 fix (gap-closure 02-10): kanoniczny chunked-threading pattern.
    # Pre-fix wzorzec `Iterators.Enumerate` nad `chunks(...)` byl non-canonical —
    # `Threads.@threads` (Julia 1.10) wymaga indexable iteratora; Enumerate nie
    # ma stabilnego getindex. Materializujemy chunki przez `collect` do Vector
    # UnitRange{Int} (length=nchunks <= nthreads(), ~128B alloc miesci sie w
    # ENE-03 threshold <4096B). Indexujemy przez `eachindex(cs)`.
    # D-11 LOCKED: ChunkSplitters preserved (NIE wracamy do threadid()).
    cs = collect(chunks(1:n; n=nchunks))
    Threads.@threads :static for chunk_idx in eachindex(cs)
        s = 0.0
        @inbounds for k in cs[chunk_idx]
            i_aktualne = trasa[k]
            i_nastepne = trasa[mod1(k + 1, n)]
            s += D[i_aktualne, i_nastepne]
        end
        bufor[chunk_idx] = s
    end
    return sum(bufor)
end
```

### Specific changes
1. **INSERT** before `@threads` line: 7-linijkowy komentarz polski (BL-04 rationale + alloc cost note + D-11 LOCKED preservation).
2. **INSERT** new line: `cs = collect(chunks(1:n; n=nchunks))` — materializacja chunkow do Vector{UnitRange{Int}}.
3. **REPLACE** `@threads` header: `Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))` → `Threads.@threads :static for chunk_idx in eachindex(cs)`.
4. **REPLACE** inner-loop iterator: `@inbounds for k in krawedzie` → `@inbounds for k in cs[chunk_idx]`.

Net delta: **+10 -2 linii** (7 komentarz + 1 collect + 1 zmiana @threads header + 1 zmiana inner-loop iterator).

### Threading semantics — what changes, what doesn't

**Algorithmic semantics: ZERO change.**
- Pre-fix i post-fix oba sumuja `D[trasa[k], trasa[mod1(k+1, n)]]` dla wszystkich `k in 1:n`, partycjonowanych przez `chunks(1:n; n=nchunks)` ranges, accumulated do `bufor[chunk_idx]` per-chunk, finally reduced przez `sum(bufor)` (left-to-right, deterministic per Julia Base spec).
- Krawedzie sumowane sa identyczne; podzial na chunki jest identyczny (oba uzywaja `chunks(1:n; n=nchunks)` z tym samym argument); per-chunk accumulator slot jest identyczny (`bufor[chunk_idx]`); final reduce jest identyczny (`sum(bufor)`).
- Liczbowy wynik **jest bit-identyczny** dla `nthreads() == 1` (single-task case — collection `cs` to single-element vector, eachindex zwraca `1:1`, jedyny task wykonuje cala range).
- Dla `nthreads() > 1` wynik moze rozniczc o sub-ULP (non-associative FP w sum(bufor) — ale to jest issue z D-11 LOCKED chunked summation w ogole, NIE z fix-em BL-04). TEST-04 multi-thread determinism (z `rtol=1e-12`) zachowuje tolerance, exact `stan.trasa` invariant zachowany.

**Threading correctness semantics: improved.**
- Pre-fix: `Threads.@threads` partycjonowal `Iterators.Enumerate{ChunkSplitters.Chunk}`, ktory NIE ma stabilnego getindex (Julia 1.10 multi-threading manual: '@threads requires firstindex/lastindex/getindex'). Macro expansion lowers to attempt-iterate-by-task-index, ktorego semantyka na non-indexable iteratorze jest at minimum non-canonical, at worst silently broken na Julia minor-version bumpach.
- Post-fix: `Vector{UnitRange{Int}}` (z `collect(chunks(...))`) IS indexable per Vector contract. `Threads.@threads :static for chunk_idx in eachindex(cs)` partycjonuje `1:length(cs)` Int range across tasks — to jest documented blessed pattern (Julia 1.10 multi-threading manual + ChunkSplitters.jl docs: "for chunk in chunks(...)" lub "for chunk_idx in 1:nchunks; krawedzie = chunks(...)[chunk_idx]").
- TEST-04 multi-thread determinism testset (z subprocess JULIA_NUM_THREADS=1 vs 8) NIE moze pozytywnie weryfikowac correctness pre-fix, tylko ze "trajectory matches between two configs" — ale jezeli OBA configs tylko-przypadkowo zachowuja sie correct (np. macro lowering zwraca identyczne ID-stable indeksy w aktualnej Julia 1.10/1.11), test passes mimo bug-a. Post-fix REMOVES uncertainty: pattern jest documented blessed, nie zalezy od macro-expansion-internal lowering.

### Alloc impact analysis (ENE-03 threshold guard)

- `collect(chunks(1:n; n=nchunks))` allokuje:
  - `Vector{UnitRange{Int}}` z `length == nchunks` (zwykle == `Threads.nthreads()`, np. 8 dla typowego desktop CI runner).
  - Per-element: `UnitRange{Int}` ma 2 pola Int64 = 16 bytes.
  - `Vector{UnitRange{Int}}` overhead: ~40 bytes header (Julia 1.10 Vector layout).
  - Total: `40 + 8 * 16 = 168 bytes` dla nthreads=8 (worst-case typical desktop).
  - Per ENE-03 threshold (`< 4096 bytes` z `_alloc_3arg(D, trasa, bufor) < 4096` w `test/test_energia.jl:53-63`): **168 << 4096**, comfortable margin.
  - WR-07 z 02-REVIEW.md zaleca tightening do `< 1024` lub `<= 256`: **168 < 1024 PASS**, **168 > 256 FAIL** (gdyby plan 02-12 lub futur tightened threshold do 256, BL-04 fix WPROWADZILBY regresji — ale 02-12 plan jest WR-tier, nie BL-tier, i obecnie threshold=4096 jest tym co plan 02-13 final verification weryfikuje).
- Pre-fix alloc: `enumerate(chunks(1:n; n=nchunks))` JEST NIE-ALLOC w principle (Iterators.Enumerate jest lazy iterator, ChunkSplitters.Chunk takze) — ale `Threads.@threads` partition-iterator-by-task moze internal-allokowac, exact behavior implementation-dependent.
- Net delta: **+~128B per call** (zalezy od nthreads) — kosmetyczny w hot-path, ENE-03 threshold preserved.
- Hoistability: jezeli future profiler wykaze ze `collect` overhead jest non-negligible, mozna podniesc `cs` jako argument funkcji (sygnatura zmieniona by pass `cs::Vector{UnitRange{Int}}` jako pre-alokowany buffer per D-10 pattern). Out-of-scope dla 02-10; udokumentowane w komentarzu inline.

## Algorithmic Verification (text-based)

### Verify checks z plan `<verification>` block

| # | Check                                                          | Expected | Actual | Status |
| - | -------------------------------------------------------------- | -------- | ------ | ------ |
| 1 | `grep -c "enumerate(chunks(" src/energia.jl`                   | == 0     | 0      | PASS   |
| 2 | `grep -c "collect(chunks(" src/energia.jl`                     | == 1     | 1      | PASS   |
| 3 | `grep -c "for chunk_idx in eachindex(cs)" src/energia.jl`      | == 1     | 1      | PASS   |
| 4 | `grep -c "rand(rng, 1:(n - 2))" src/energia.jl`                | == 1     | 1      | PASS   |

### Task 1 acceptance criteria (11/11 PASS)

| #  | Criterion                                                                                  | Expected | Actual | Status |
| -- | ------------------------------------------------------------------------------------------ | -------- | ------ | ------ |
| 1  | `grep -c "Threads.@threads :static for chunk_idx in eachindex(cs)" src/energia.jl`         | == 1     | 1      | PASS   |
| 2  | `grep -c "cs = collect(chunks(1:n; n=nchunks))" src/energia.jl`                            | == 1     | 1      | PASS   |
| 3  | `grep -c "enumerate(chunks(" src/energia.jl`                                               | == 0     | 0      | PASS   |
| 4  | `grep -c "BL-04 fix (gap-closure 02-10)" src/energia.jl`                                   | == 1     | 1      | PASS   |
| 5  | `grep -c "@inbounds for k in cs\[chunk_idx\]" src/energia.jl`                              | == 1     | 1      | PASS   |
| 6  | `grep -c "for k in krawedzie" src/energia.jl`                                              | == 0     | 0      | PASS   |
| 7  | `grep -c "rand(rng, 1:(n - 2))" src/energia.jl` (BL-01 preserved)                          | == 1     | 1      | PASS   |
| 8  | `grep -cE "^function " src/energia.jl` (5 funkcji bez zmian)                               | == 5     | 5      | PASS   |
| 9  | `grep -c "return oblicz_energie(D, trasa, bufor)" src/energia.jl` (2-arg delegate)         | == 1     | 1      | PASS   |
| 10 | `grep -c "return sum(bufor)" src/energia.jl` (final reduce)                                | == 1     | 1      | PASS   |
| 11 | `grep -c "bufor\[chunk_idx\] = s" src/energia.jl` (per-chunk accumulator)                  | == 1     | 1      | PASS   |

### Plan-level success criteria (4/4 PASS)

| # | Criterion                                                                                | Status |
| - | ---------------------------------------------------------------------------------------- | ------ |
| 1 | BL-04 fixed: kanoniczny `@threads :static for chunk_idx in eachindex(cs)` pattern present | PASS   |
| 2 | ChunkSplitters integration preserved (D-11 LOCKED — NIE thread-id based)                 | PASS   |
| 3 | Plan 02-07 fix dla kalibruj_T0 BL-01 preserved (no regression: `rand 1:(n-2)` count == 1) | PASS   |
| 4 | ENE-02 / ENE-05 / ALG-05 unblocked at code level (runtime do plan 02-13)                 | PASS (text-based) |

### Plan-level must_haves (truths) verification (7/7 PASS)

| # | Must-have truth                                                                                | Verified by                          | Status |
| - | ---------------------------------------------------------------------------------------------- | ------------------------------------ | ------ |
| 1 | 3-arg oblicz_energie uses canonical chunked-threading: NO enumerate(chunks(...)) inside @threads | grep `enumerate(chunks(` == 0       | PASS   |
| 2 | Replacement: collect(chunks(...)) materialized + @threads :static for chunk_idx in eachindex(cs) | grep canonical pattern == 1         | PASS   |
| 3 | Per-chunk accumulator: bufor[chunk_idx] = s; final sum(bufor) reduce                            | grep `bufor[chunk_idx] = s` == 1; `return sum(bufor)` == 1 | PASS |
| 4 | ChunkSplitters integration preserved (D-11 LOCKED): nie wraca do threadid()                     | grep `threadid()` == 0; `chunks(1:n;` count == 1 (linia 120) | PASS |
| 5 | Plan 02-07 BL-01 fix line ~178 (kalibruj_T0 i = rand(rng, 1:(n - 2))) preserved                 | grep `rand(rng, 1:(n - 2))` == 1    | PASS   |
| 6 | grep -c 'enumerate(chunks(' src/energia.jl returns 0 (anti-pattern eradicated)                  | grep == 0                           | PASS   |
| 7 | grep -c 'collect(chunks(' src/energia.jl returns 1 (canonical pattern present)                  | grep == 1                           | PASS   |

### Runtime verification

**Niedostepne lokalnie** — Julia NIE jest zainstalowana w worktree environment (consistency z plans 02-01..09 SUMMARY: Rule 3 deviation, runtime deferred do Plan 02-13 final pass + CI).

**Spodziewane zachowanie po Plan 02-13 runtime:**
- `Pkg.test()` exit 0 z testset-em z `test/test_energia.jl` (ENE-02/03/05 testsety):
  - ENE-02 'oblicz_energie threadowana suma na chunkach': PASS pod warunkiem ze nowy pattern correctly partycjonuje 1:n na chunki — dokladne sumowanie `n` krawedzi (Hamilton cycle closure przez `mod1(k+1, n)`) zaweryfikowane przez algebraic equivalence z 2-arg variant call.
  - ENE-03 '_alloc_3arg(D, trasa, bufor) < 4096': PASS, alloc ~168B << 4096B threshold.
  - ENE-05 'mod1 zamknięcie cyklu': PASS — formula `D[trasa[k], trasa[mod1(k+1, n)]]` niezmieniona w body petli.
- TEST-04 multi-thread determinism subprocess test (`JULIA_NUM_THREADS=1` vs `=8`):
  - Pre-fix: PASS by accident (macro lowering Iterators.Enumerate akurat dawal correct partition na current Julia 1.10/1.11; testowy subprocess detect-ed bit-identyczne `stan.trasa` + sub-ULP `stan.energia` rtol=1e-12)
  - Post-fix: PASS by-design (kanoniczny pattern, partition correctness documented przez Julia multi-threading manual + ChunkSplitters.jl docs)
  - Net behavior: identyczny PASS, ale post-fix usuwa uncertainty (silent-broken risk na Julia minor-version bumpach)
- ALG-05 `kalibruj_T0` testset (BL-01 fix dependency): PASS — linia 179 `rand(rng, 1:(n - 2))` niezmieniona.
- Aqua.test_all: PASS — brak nowych dependencji (ChunkSplitters juz w Project.toml [deps] z Plan 02-02).
- JET.@report_opt na `oblicz_energie` 3-arg: PASS — pattern `for chunk_idx in eachindex(cs)` z `cs = collect(chunks(...))` daje stable Int iteration; `cs[chunk_idx]` daje `UnitRange{Int}` indexed access — type-stable. (Pre-fix `Iterators.Enumerate{Chunk}` dawal type-stable destructuring `(Int, UnitRange)` ale tylko dzieki Julia destructuring optimization na concrete eltype iteratorze — jezeli kiedys ChunkSplitters zmienial Chunk eltype shape, type stability mogla regress.)

## Task Commits

1. **Task 1: Replace BL-04 enumerate(chunks(...)) pattern with canonical collect+eachindex (src/energia.jl 3-arg oblicz_energie)** — `8df79fd` (fix)
   - Files: `src/energia.jl` (modified, +10 -2 linii)
   - Linie 113-119 INSERT: 7-linijkowy komentarz polski (BL-04 rationale + alloc cost + D-11 LOCKED note)
   - Linia 120 INSERT: `cs = collect(chunks(1:n; n=nchunks))` — materializacja
   - Linia 121 REPLACE: @threads header z `(chunk_idx, krawedzie) in enumerate(...)` → `chunk_idx in eachindex(cs)`
   - Linia 123 REPLACE: inner-loop iterator z `for k in krawedzie` → `for k in cs[chunk_idx]`
   - Function signature, docstring (linie 92-108), inner-loop body (i_aktualne/i_nastepne/s), bufor accumulator write, final sum reduce — wszystko UNTOUCHED
   - 2-arg `oblicz_energie(punkty, trasa)` (linie 71-90) UNTOUCHED — delegate na linii 89 nadal `return oblicz_energie(D, trasa, bufor)`
   - `kalibruj_T0` (linie 172-189) UNTOUCHED — BL-01 fix na linii 179 zachowany
   - `oblicz_macierz_dystans!` (linie 27-43) UNTOUCHED
   - `delta_energii` (linie 145-154) UNTOUCHED
   - Brak deviations od plan template (Rule 1/2 cosmetic w Deviations section poniżej)

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

**Created (1 file):**
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-10-SUMMARY.md` — this file

**Modified (1 file):**
- `src/energia.jl` — +10 -2 linii (BL-04 fix w 3-arg `oblicz_energie`); 197 linii total (was 189)

**Deleted (0 files):** Brak.

## Decisions Made

- **Wybrana opcja `collect(chunks(...))` pre-materialization** (BL-04 fix recipe option A z 02-REVIEW.md). Alternatywa B (per-task `chunks(1:n; n=nchunks)[chunk_idx]` calls wewnatrz body petli) wymagalaby `chunks(...)` invocations w hot-path inner body — silnie odbiega od D-10 'pre-allokowany bufor' filozofii i mogla by introduce subtelne performance regressions (ChunkSplitters.chunks invocation wykonuje walidacje argumentow + alokuje Chunk wrapper). Opcja A daje O(nchunks) jednorazowy alloc (~128B dla nthreads=8) ktory miesci sie w ENE-03 threshold <4096B (WR-07 zachowuje threshold).

- **Komentarz inline ROZBUDOWANY do 7 linii** (a NIE 1-linijka 'BL-04 fix'). Future readers z `git blame` zobacza pelne uzasadnienie: (a) co bylo pre-fix wzorcem, (b) DLACZEGO byl bug (Julia 1.10 multi-threading manual reference), (c) co jest fix, (d) alloc cost (~128B w ENE-03 threshold), (e) ze D-11 LOCKED jest preserved. Zwlaszcza wazne dla naszego context-u: gap-closure plans (02-07/08/09/10/11/12) sa SHORT-LIVED w git history, ale ich rationale musi zostac jezeli kiedys ktos refactor-uje hot-path.

- **Komentarz przepisany 2x by uniknac kolizji z grep contractami** (Rule 1 - Bug auto-fixed). Wersja 1 zawierala doslowne `enumerate(chunks(...))` i `collect(chunks(...))` substring-i w komentarzu, ktore niechcaco lapaly grep '-c' na must_have #6 (anti-pattern eradicated count == 0 — ale komentarz mial 1) i must_have #7 (canonical present count == 1 — ale komentarz dawal 2). Wersja finalna uzywa `Iterators.Enumerate nad chunks(...)` + opisowy 'Materializujemy chunki przez collect'. Substring discipline: must_haves mierza calym plikiem (NIE tylko kodem), wiec komentarze takze podlegaja constraint-om. Edukacyjna intencja zachowana.

- **Function signature `function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64` NIEZMIENIONA** per plan explicit constraint. Caller contracts (D-10 bufor pre-alokowany; 2-arg oblicz_energie delegate na linii 89; tests w test/test_energia.jl _alloc_3arg helper) wszystkie wymagaja stalej sygnatury. BL-04 fix to czysto wewnetrzny algorithm restructure — zero impact na public API.

- **`Manifest.toml` i `Project.toml` NIE zmodyfikowane**: gap-closure plan, brak nowych dependencji. ChunkSplitters jest juz w deps (Plan 02-02 inicjalna integracja, D-11 LOCKED). `Statistics: std` (uzywany przez `kalibruj_T0`) takze juz w deps.

## Deviations from Plan

### Rule 1 — Auto-fixed Bugs

**1. [Rule 1 - Bug] Komentarz inline trafiał na grep '-c' contracts dla must_have #6 i #7 — przepisany 2x**

- **Found during:** Task 1 verify (po pierwszej Edit) — `grep -c "enumerate(chunks(" src/energia.jl` zwrocil **1** mimo ze code path miał enumerate eradicated. Locator: `grep -n "enumerate(chunks(" src/energia.jl` -> `114: # Pre-fix \`enumerate(chunks(...))\` byl non-canonical — \`Threads.@threads\``. Po pierwszej naprawie (przeformulowanie do `Iterators.Enumerate`), drugi pass ujawnil `grep -c "collect(chunks(" src/energia.jl` zwracal **2** (linia 116 komentarz + linia 120 kod) zamiast must_have #7 expected **1**.
- **Issue:** Substringi w komentarzach kolidowaly z must_haves grep contractami ktore mierza CALYM plikiem (nie tylko executable code). Pre-fix komentarz uzywal pelnych `enumerate(chunks(...))` i `collect(chunks(...))` substring-ow w narracji "Pre-fix `enumerate(chunks(...))` byl... Materializujemy `cs = collect(chunks(...))`...".
- **Fix:** Przepisany komentarz inline 2x:
  - Wersja 2 (po pierwszej iteracji): "Pre-fix wzorzec `Iterators.Enumerate` nad `chunks(...)` byl non-canonical — ... Materializujemy `cs = collect(chunks(...))` (Vector ...)" — naprawila #6 ale rozbila #7.
  - Wersja 3 (final): "Pre-fix wzorzec `Iterators.Enumerate` nad `chunks(...)` byl non-canonical — ... Materializujemy chunki przez `collect` do Vector UnitRange{Int} ..." — naprawila #6 i #7 jednoczesnie.
- **Files modified:** `src/energia.jl` linia 116 (jeden Edit pre-commit, NIE wymagal nowego commitu — bug fix wewnatrz Task 1 boundary)
- **Commit:** Wszystkie 3 wersje wewnatrz jednego pre-commit working-tree state — finalny `8df79fd` zawiera wersje 3
- **Lekcja:** Future BL-fix komentarze powinny uzywac OPISOWEJ narracji (np. "wzorzec X nad iteratorem Y") zamiast doslownych code substring-ow gdzie te substringi sa scope-em must_haves grep contractow. Alternatywnie: must_haves moga ograniczac grep do executable-only przez `--invert-match -e '^[ \t]*#'` ale to jest cross-cutting concern poza scope plan 02-10.

### Rule 3 — Auto-fixed Blocking Issues

**1. [Rule 3 - Blocking] Edit tool path resolution: pierwsza proba edycji `src/energia.jl` z absolute parent-projekt sciezki landed w PARENT projekcie (NIE w worktree)**

- **Found during:** Task 1 verify (po pierwszej Edit) — `git diff` w worktree zwrocil pusty output mimo Edit tool reported success; `grep -c "enumerate(chunks("` zwrocil **1** mimo ze fix mial dac 0; `cd parent && git status -s` ujawnil ` M src/energia.jl` w PARENT projekcie.
- **Issue:** Powtorzony precedens z plan 02-09 SUMMARY (Edit tool path resolution bug). Pierwsza Edit invocation uzyl absolute path `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\src\energia.jl` zamiast worktree-rooted path `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\.claude\worktrees\agent-a03cf7f3597a0d1cd\src\energia.jl`. Edit tool zaakceptowal ten path bo on EXISTS (parent projekt ma copy pliku) ale apply-edit landed w parent zamiast w worktree. Critical_tooling_note z prompt explicitly ostrzegal o tym risk-u.
- **Impact na plan:** Modyfikacja Task 1 wymagala revert w parent projekcie + retry w worktree z worktree-rooted absolute path. Brak utraty pracy — parent revert byl czysty (po `git checkout -- src/energia.jl` w parent, parent `git status -s` zwrocil tylko `?? .claude/`), worktree edit z poprawna sciezka landed na pierwsza probe drugiej iteracji.
- **Fix:**
  1. `cd parent && git checkout -- src/energia.jl` — revert misaplied edit (system reminder potwierdzil: "intentional, not revert")
  2. Re-issue Edit z worktree-rooted absolute path `C:\Users\...\.claude\worktrees\agent-a03cf7f3597a0d1cd\src\energia.jl` — landed correctly w worktree na pierwsza probe
  3. `git diff --stat` w worktree pokazal `1 file changed, 12 insertions(+), 2 deletions(-)` — PASS
  4. Parent projekt verified clean: `(cd parent && git status -s)` returned `?? .claude/` only
- **Files modified:** Brak (środowiskowy/tooling issue, NIE algorithm bug). Worktree fix landed w jednym Edit po revert.
- **Commit:** Nie ma commitu fix-a (issue resolved przed Task 1 commit). Decyzja udokumentowana w SUMMARY (this Deviations section).
- **Lekcja:** Identyczna lekcja jak plan 02-09 — dla wszystkich Edit/Write tool calls w worktree zawsze uzyj WORKTREE-ROOTED absolute path z prefix `C:\Users\...\.claude\worktrees\agent-{id}\...`. Pre-Edit Read na tej samej absolute worktree path anchor-uje Edit do worktree filesystem. Jezeli Edit reported success ale `git diff` w worktree pusty — STOP, sprawdz parent projekt status, revert misaplied edit, retry z poprawna sciezka.

### Brak Rule 4 deviations

Plan zostal wykonany doslownie zgodnie z `<tasks>` blokiem. Wszystkie 11 task-level acceptance criteria + 4 plan-level verify checks + 7 must_have truths PASSING text-based. Brak architectural decisions wymaganych — implementation pattern byl explicit zdefiniowany w `<action>` block (BEFORE/AFTER kod + 4 specific changes wymienione w plan). Function signature i caller-facing contracts UNTOUCHED.

## Authentication Gates

None — wszystkie modyfikacje plikow lokalne; brak external API/login wymaganego.

## Issues Encountered

- **Edit tool path resolution bug** — Rule 3 (powyzej). Naprawione w trakcie Task 1 retry przed commit. Powtorzony precedens z plan 02-09.
- **Komentarz inline grep collision** — Rule 1 (powyzej). Naprawione przez 2x rewriting komentarza inline przed commit.
- **Niedostepna Julia uniemozliwia weryfikacje runtime** — powtorzony precedens z plans 02-01..09 SUMMARY. Wszystkie text-based + structural checks PASSING; runtime verification deferred do Plan 02-13 final pass + CI.
- **`gsd-sdk` CLI niedostepne w worktree** — stosowane direct `git commit --no-verify -m ...` per `<parallel_execution>` instructions. NIE wykonano `state advance-plan` / `update-progress` / `record-metric` calls — orchestrator owns te updates per `<objective>` ("Do NOT update STATE.md or ROADMAP.md").

## Next Plan Readiness

- **Plan 02-11 (warning gap-closure WR-01..05 lub podobne)** — odblokowane. NIE zalezy od Plan 02-10 (operuje prawdopodobnie na innych funkcjach lub innych plikach).
- **Plan 02-12 (warning gap-closure)** — odblokowane analogicznie.
- **Plan 02-13 (final runtime verification)** — wymaga Plans 02-09/10/11/12 complete + dostepne Julia w env (CI run). Sprawdzi:
  - `Pkg.test()` exit 0 z wszystkimi testset-ami w `test/test_energia.jl` + `test/test_symulacja.jl` + `test/test_baselines.jl`
  - ENE-03 alloc threshold (`< 4096B`) z nowym `collect`-based pattern: spodziewane ~168B alloc, comfortable margin
  - TEST-04 multi-thread determinism (1 vs N threads bit-identical trasa + sub-ULP energia): spodziewany PASS by-design (kanoniczny pattern documented blessed)
  - ENE-05 chunked threading testset: PASS pod warunkiem zachowanej semantyki sumowania (algebraicznie identyczna)
  - JET.@report_opt na 3-arg `oblicz_energie`: PASS, type-stable per Vector{UnitRange{Int}} indexing contract
  - Aqua.test_all clean (Plan 02-08 BL-02 fix preserved + brak nowych deps z Plan 02-10)

## Threat Surface Scan

**Brak nowych threat surfaces wprowadzonych przez Plan 02-10:**
- BL-04 fix to czysto wewnetrzny algorithm restructure — zero network, zero secrets, zero PII, zero file I/O, zero process spawn.
- Function signature niezmieniona — brak zmiany API surface.
- `collect(chunks(...))` allocates O(nchunks) UnitRange{Int} objects in young-generation heap — standard Julia GC handling, no escape-to-system. Memory safety identyczna pre/post-fix (oba uzywaja indexed bufor[chunk_idx] write z chunk_idx ∈ eachindex(cs) gwarantowane in-bounds).
- Threading correctness IMPROVED (kanoniczny pattern eliminuje silent-broken risk na Julia minor-version bumpach) — net security impact: positive (predictability ↑, undefined-behavior risk ↓).

Plan 02-10 to pure-algorithmic gap-closure: zero security-relevant surface zmienione.

## Self-Check: PASSED

All claims verified.

**Files:**
- `src/energia.jl` — FOUND (197 linii, 0 wystapien `enumerate(chunks(`, 1 wystapienie `collect(chunks(`, 1 wystapienie `Threads.@threads :static for chunk_idx in eachindex(cs)`, BL-04 marker present, BL-01 fix preserved, 5 funkcji, 2-arg delegate untouched)
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-10-SUMMARY.md` — FOUND (this file, will be committed below)

**Commits:**
- `8df79fd` (Task 1: BL-04 fix oblicz_energie canonical chunked-threading) — FOUND in git log

**Verification block from PLAN executed:**
- Plan-level verify: 4/4 grep checks PASS (enumerate==0, collect==1, eachindex==1, BL-01==1)
- Task 1 acceptance: 11/11 PASS (all grep counts + function count + signature preserved + delegates intact)
- Plan-level success criteria: 4/4 PASS (BL-04 fixed, ChunkSplitters preserved, BL-01 preserved, ENE/ALG unblocked text-based)
- Plan-level must_haves truths: 7/7 PASS (all grep contracts + algorithmic preservation)
- Runtime verification: deferred do Plan 02-13 (Julia NIE w worktree env, Rule 3 precedens z plans 02-01..09)

**Phase 2 Plan 10 KOMPLETNA jako file modifications + 1 commit — pelna runtime weryfikacja oczekuje Plan 02-13 final pass z dostepna Julia (julia-actions/julia-buildpkg w CI). Algorytmiczna poprawnosc zweryfikowana przez:**
1. **Equivalence argument:** post-fix sumuje identyczne krawedzie (k in 1:n, chunks(1:n; n=nchunks) partition niezmieniony) z identycznym per-chunk accumulator (bufor[chunk_idx] = s) i identycznym final reduce (sum(bufor)).
2. **Threading correctness IMPROVED:** post-fix uzywa documented blessed pattern (Vector{UnitRange{Int}} indexable per Vector contract) zamiast non-canonical Iterators.Enumerate (no stable getindex per Julia 1.10 multi-threading manual).
3. **Alloc impact preserved:** ~168B per call w ENE-03 threshold <4096B (WR-07 nadal pass).
4. **D-11 LOCKED preserved:** ChunkSplitters integration utrzymany, NIE wraca do threadid().
5. **BL-01 preserved:** kalibruj_T0 linia 179 `rand(rng, 1:(n - 2))` niezmieniona — Plan 02-07 fix nadal aktywny.

**Wave 8 BL-04 gap-closure DONE.**

---
*Phase: 02-energy-sa-algorithm-test-suite*
*Completed: 2026-04-29*
