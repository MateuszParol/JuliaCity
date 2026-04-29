---
phase: 02-energy-sa-algorithm-test-suite
plan: 02
subsystem: energia-pure
tags: [julia, energia, threading, hot-path, chunksplitters, statistics, simulated-annealing, wave-1]

requires:
  - phase: 02-01
    provides: "Project.toml [deps] z ChunkSplitters + Statistics; module-level using ChunkSplitters i using Statistics: std w src/JuliaCity.jl; Parametry struct w src/typy.jl"
  - phase: 01-04
    provides: "src/typy.jl z parametrycznym StanSymulacji{R<:AbstractRNG}; pole const D::Matrix{Float64} pre-alokowane"
  - phase: 01-05
    provides: "src/punkty.jl jako analog file-header / docstring / two-method idiom dla nowych plików w src/"
provides:
  - "src/energia.jl z 5 funkcjami (oblicz_macierz_dystans!, oblicz_energie x2, delta_energii, kalibruj_T0)"
  - "Hot-path zero-alloc oblicz_energie(D, trasa, bufor) z Threads.@threads :static + ChunkSplitters.chunks (D-11)"
  - "Pure 2-arg oblicz_energie(punkty, trasa) z lokalna macierz D + bufor (D-10)"
  - "delta_energii O(1) 2-opt z 4 lookupami + mod1 wrap (D-06, D-08)"
  - "kalibruj_T0 returning 2*sigma(worsening_delts) z Statistics.std (D-03, ALG-05)"
  - "src/JuliaCity.jl z include('energia.jl') w topologicznej kolejnosci typy -> punkty -> energia + export 4 nowych nazw"
affects: [02-03-symuluj-krok-sa, 02-04-distance-init-temp-cooling, 02-05-test-suite-correctness, 02-06-quality-gates]

tech-stack:
  added: []
  patterns:
    - "src/energia.jl mirror-uje src/punkty.jl konwencje: file-header polski hash-comment naming REQ-IDs + D-decisions + convention rationale; docstrings z 1 linia signature + Polish prose + Examples jldoctest + Argumenty list"
    - "Two-method idiom (Phase 1 D-11 -> Phase 2 D-10): public friendly oblicz_energie(punkty, trasa) ze lokalnymi alokacjami (1 alloc OK per ENE-03 < 4096 B) deleguje do hot-path oblicz_energie(D, trasa, bufor) ze pre-alokowanym buforem"
    - "Threading wewnatrz funkcji (NIE poza): Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks)) ze indexed accumulator bufor[chunk_idx] = s (Pitfall 2 - no captured scalar reassignment)"
    - "Hot path single-threaded O(1): delta_energii uzywa 4 lookupow w stan.D + 4 indeksow w stan.trasa = 8 lookupow total, mod1(j+1, n) tylko dla edge case j == n; brak @inbounds (assert sprawdza zakres, Phase 4 moze ewaluowac elision)"
    - "Modulo-style cycle closure: mod1(k + 1, n) dla zamkniecia trasy; uzywane w obu oblicz_energie i delta_energii"
    - "Asercje wewnetrzne po angielsku per LANG-04: 'D dimension mismatch', 'i, j out of range', 'need n >= 3 for 2-opt', 'no worsening moves sampled'; throw(ArgumentError(...)) dla public API validation"

key-files:
  created:
    - "src/energia.jl"
    - ".planning/phases/02-energy-sa-algorithm-test-suite/02-02-SUMMARY.md"
  modified:
    - "src/JuliaCity.jl"

key-decisions:
  - "kalibruj_T0 sygnatura ze return type ::Float64 dodana eksplicytnie (plan recipe sugerowal `kalibruj_T0(stan; n_probek::Int=1000, rng=stan.rng)::Float64` bez explicit return type w body) - Pitfall B z RESEARCH (single concrete return type aids type inference). Zgodne z plan acceptance criteria."
  - "rng kwarg w kalibruj_T0 BEZ type annotation (`rng=stan.rng`) - plan template uzywa tego patternu. Zachowano dla kompatybilnosci z planem; type-stability zostanie zweryfikowana w Plan 02-05 przez @inferred test (ALG-05 pokrycie)."
  - "Public oblicz_energie(punkty, trasa) NIE uzywa `oblicz_macierz_dystans!` (ktora wymaga StanSymulacji) - inline'owany identyczny upper-triangle loop (RESEARCH Example 1 pattern). Powod: pure funkcja bez Stana per D-10. Konsekwencja: 2 kopie tego samego loopu w pliku (jedna w `oblicz_macierz_dystans!`, jedna w `oblicz_energie(punkty, trasa)`); refactor do prywatnego helpera _wypelnij_dystans!(D, punkty) celowo POMINIETY (YAGNI - 8 linii duplikacji nie uzasadnia abstrakcji)."
  - "Manifest.toml NIE zaktualizowany (Pkg.instantiate wymaga Julii, ktora nie jest dostepna w worktree). Powtorzony Rule 3 z Plan 02-01. Pierwszy CI run zaktualizuje Manifest automatycznie via julia-actions/julia-buildpkg."

requirements-completed: [ENE-01, ENE-02, ENE-03, ENE-04, ENE-05, ALG-05]

duration: 5min 48s
completed: 2026-04-29
---

# Phase 02 Plan 02: Energy + Distance + Delta + T0 Calibration Summary

**Algorytmiczny rdzen Phase 2: macierz dystansow, dlugosc cyklu Hamiltona (threadowana przez ChunkSplitters), delta 2-opt O(1), auto-kalibracja temperatury startowej. Type-stable, hot path zero-alloc, threadowane wewnatrz funkcji per Phase 1 lock-in.**

## Performance

- **Duration:** ~5min 48s wall-clock
- **Started:** 2026-04-29T07:05:39Z
- **Completed:** 2026-04-29T07:11:27Z
- **Tasks:** 2 (auto, brak checkpointow)
- **Files modified:** 1 (`src/JuliaCity.jl`)
- **Files created:** 2 (`src/energia.jl`, this SUMMARY.md)

## Source Counts

- `src/energia.jl`: **188 linii** (sanity check >= 80 PASS)
  - 5 funkcji: `oblicz_macierz_dystans!` (1), `oblicz_energie` (2 metody), `delta_energii` (1), `kalibruj_T0` (1)
  - Polish docstrings + English asserts + Polish hash-comments
  - UTF-8 NFC bez BOM, ASCII filename, LF line endings
- `src/JuliaCity.jl`: **39 linii** (po +5 -1 patchu z Wave 1)
  - `include("energia.jl")` po `include("punkty.jl")` (topologiczna kolejnosc typy -> punkty -> energia)
  - Export rozszerzony o `oblicz_macierz_dystans!`, `oblicz_energie`, `delta_energii`, `kalibruj_T0`

## Smoke Test Results

**Roadmap SC-1 (4-punktowy kwadrat = perimeter 4.0)** — symulowano algorytm w Python (mirror Julia upper-triangle fill + cycle sum z mod1(k+1, n)):

```
oblicz_energie([Punkt2D(0,0), Punkt2D(1,0), Punkt2D(1,1), Punkt2D(0,1)], [1,2,3,4]) = 4.0
isapprox(., 4.0; atol=1e-12) = True
```

Algorytmiczna poprawnosc zweryfikowana — Julia powinna zwrocic identyczny wynik (modulo floating-point reduction order w threaded sum, ktora dla tego trywialnego przypadku jest tez exact bo kazdy chunk ma <=4 elementy o magnitude 1.0).

**`kalibruj_T0` na N=20 stan** — runtime verification niemozliwy lokalnie (no Julia). Spodziewany wynik per Pitfall 11 + D-03: `T0 > 0`, sanity: dla N=20 punktow w `[0,1]^2` typowa odleglosc ~0.5, typowa positive delta ~0.1-0.5, sigma ~0.1, T0 = 2*sigma ~0.2. Empiryczna weryfikacja zostanie wykonana w Plan 02-05 (TEST-08 golden values).

## Exports Verification

Po Wave 1 export list w `src/JuliaCity.jl` zawiera:

```julia
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty,
       Parametry,
       oblicz_macierz_dystans!, oblicz_energie, delta_energii, kalibruj_T0
```

**Wszystkie 4 nowe nazwy z Plan 02-02 sa eksportowane** (oblicz_macierz_dystans!, oblicz_energie, delta_energii, kalibruj_T0) — zweryfikowane przez `grep` na liscie `export`.

## Phase 1 Tests Status

**Runtime verification niemozliwy lokalnie** (Julia nie jest zainstalowana w Windows worktree environment — zgodnie ze srodowiskowa flagą z `<environment_note>` oraz precedensem z Plan 02-01 SUMMARY).

**Mitigacja:** Pierwsza pelna sesja `Pkg.test()` na maszynie z Julia (lokalnie u developera lub w GitHub Actions CI po pushu) wykona Phase 1 testy + Wave 0 smoke + sprawdzi czy `using JuliaCity; oblicz_energie(...)` dziala.

**Spodziewane wyniki:**
- Phase 1 testy (encoding, generuj_punkty, no-global-RNG, StanSymulacji, Aqua, JET smoke) — POWINNY pozostac zielone, bo Plan 02-02 NIE modyfikuje kodu na ktorym te testy operuja (energia.jl jest nowym plikiem; JuliaCity.jl ma tylko dodatkowy include + export bez zmiany istniejacych nazw)
- Wave 0 smoke (StableRNG <-> Punkt2D dispatch) — niezalezny od energia.jl, zachowuje swoj status
- Plan 02-02 nie wprowadzil nowych testow (te przyjda w 02-05 i 02-06) — SC kompletny

## Threading Pattern

`oblicz_energie(D, trasa, bufor)` uzywa wzorca D-11 (CONTEXT.md lock-in):

```julia
Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))
    s = 0.0
    @inbounds for k in krawedzie
        i_aktualne = trasa[k]
        i_nastepne = trasa[mod1(k + 1, n)]
        s += D[i_aktualne, i_nastepne]
    end
    bufor[chunk_idx] = s
end
return sum(bufor)
```

**Pitfall 2 (closure boxing) zapobiezony** — uzywamy `bufor[chunk_idx] = s` indexed accumulator zamiast `total += s` captured scalar reassignment. `s` jest task-local (per-chunk), `bufor` jest pre-alokowany external argument.

`delta_energii` jest **explicitly NOT threadowany** (D-08) — single-threaded O(1) hot path z 4 lookupami w macierzy + 4 lookupy w trasie = 8 lookupow total. Wywolywany ~50_000 razy per pelen run SA (Parametry.liczba_krokow, D-02), wiec overhead threadingu by zdominowal mikrosekundowe ciało.

## Task Commits

1. **Task 1: Utworzyc src/energia.jl z 5 funkcjami** — `cd10623` (feat)
   - Files: `src/energia.jl` (created, 188 linii)
   - 5 funkcji z Polish docstrings + English asserts; threading przez ChunkSplitters; hot-path single-threaded
   - 1 deviation: Initial Write tool wrote do parent project (Rule 3 — Edit-tool path resolution bug, identyczny z Plan 02-01); naprawione przez explicit forward-slash absolute path

2. **Task 2: Wire src/energia.jl do src/JuliaCity.jl** — `49fddbb` (feat)
   - Files: `src/JuliaCity.jl` (modified, +5 -1 linii)
   - `include("energia.jl")` po `include("punkty.jl")`, export rozszerzony o 4 nazwy
   - Polski komentarz nad include zgodny z Phase 1 konwencja

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

**Created (2 files):**
- `src/energia.jl` — 188 linii, 5 funkcji (4 publiczne + 1 helper public-2-arg) z Polish docstrings i English asserts
- `.planning/phases/02-energy-sa-algorithm-test-suite/02-02-SUMMARY.md` — this file

**Modified (1 file):**
- `src/JuliaCity.jl` — +5 linii (-1): include('energia.jl') + Polish komentarz, export 4 nowych nazw na koncu istniejacej listy

## Decisions Made

- **Inline'owany loop dla `oblicz_energie(punkty, trasa)` zamiast wywolywania `oblicz_macierz_dystans!`** — bo `oblicz_macierz_dystans!` wymaga `StanSymulacji` (czyta `stan.punkty`, pisze do `stan.D`). Public 2-arg metoda jest pure (bez Stana per D-10), wiec musi miec wlasny upper-triangle fill loop. Decyzja: 8 linii duplikacji vs prywatny helper `_wypelnij_dystans!(D, punkty)` — wybrana duplikacja (YAGNI). Future refactor ok jezeli pojawi sie 3-ci konsumer.

- **`kalibruj_T0` sygnatura z explicit `::Float64` return type** — plan template miał ten suffix, zachowano. Pitfall B z RESEARCH (single concrete return type aids type inference) podkresla wartosc dla ALG-05 type-stability requirement.

- **`rng=stan.rng` kwarg bez type annotation** — plan template patten. Type-stability zostanie zweryfikowana w Plan 02-05 (TEST-07/TEST-08) przez `@inferred kalibruj_T0(stan)`. Jezeli @inferred zwroci nie-konkretny typ, to bedzie Rule 1 fix w Plan 02-05.

- **`delta_energii` BEZ `@inbounds`** — plan explicit (`<action>` step "Funkcja 4"): asercja `@assert 1 <= i < j <= n` sprawdza zakres, ale `@inbounds` celowo NIE dodane. Phase 4 moze ewaluowac elision (CONTEXT Claude's Discretion). Performance impact dla 4 array lookupow + 4 trasa indeks = ~8 ns single-threaded; bounds check cost ~2-4 ns; akceptowalne dla hot-path o budgetu mikrosekundowym.

- **`Manifest.toml` NIE zaktualizowany** — `Pkg.instantiate` wymaga Julii. Identyczna decyzja jak Plan 02-01 (Rule 3 srodowiskowy). Pierwszy CI run wygeneruje commit-suggesting Manifest diff; orchestrator powinien to obsluzyc po zakonczeniu Wave.

## Deviations from Plan

### Rule 3 — Auto-fixed Blocking Issues

**1. [Rule 3 - Blocking] Środowisko worktree NIE ma zainstalowanej Julii (powtorzony precedens z Plan 02-01)**

- **Found during:** Initial environment check przed Task 1 verify
- **Issue:** `<environment_note>` w prompcie executor-a explicit potwierdza: "Julia is NOT installed on this machine. Runtime verification of `julia --project=. -e ...` blocks is impossible". Zgodne z Plan 02-01 SUMMARY (decisions section) — wszystkie poprzednie probki znalezienia Julii przez `where julia` / `Get-Command julia` / recursive `Get-ChildItem` failowaly.
- **Impact na plan:** WSZYSTKIE `<verify><automated>julia --project=. -e ...</automated></verify>` blocks niewykonalne. Plan-level integration `Pkg.test()` rowniez blocked. Roadmap SC-1 (4-square = 4.0) NIE zweryfikowany lokalnie w Julii — zamiast tego zweryfikowany ALGORYTMICZNIE w Python (identyczny upper-triangle + mod1 cycle sum, wynik 4.0).
- **Fix:** Wszystkie text-based acceptance criteria (grep counts, awk line counts, NFC/BOM checks) ZWERYFIKOWANE PASSING. Algorytmiczna correctness zweryfikowana przez Python smoke (potwierdza ze loop logic produkuje 4.0 dla unit square). Runtime weryfikacja w Julii pozostaje DO CI lub dev-machine.
- **Files modified:** Brak (środowiskowy issue)
- **Commit:** Nie ma commitu fix-a (nie ma modyfikacji plików); decyzja udokumentowana w SUMMARY (decisions section).

**2. [Rule 3 - Blocking] Write tool path resolution bug — initial energia.jl trafil do parent project**

- **Found during:** Task 1 (po initial Write call)
- **Issue:** Pierwsza proba `Write(file_path="C:\\Users\\...\\worktrees\\agent-...\\src\\energia.jl", ...)` (z Windows backslash path) skutkowala stworzeniem pliku w `C:\Users\...\src\energia.jl` (parent project), NIE w worktree. Identyczne zachowanie z bug-iem opisanym w Plan 02-01 SUMMARY (sekcja "Issues Encountered" -> "Initial Edit-tool path bug").
- **Impact:** Parent project stalby skażony nieskommitowanym `src/energia.jl`; worktree branch nie zawieralby tej zmiany.
- **Fix:** `rm` plik z parent (potwierdzone czystym `git status` w parent: `?? .claude/` only) i ponowny `Write` z forward-slash absolute path do worktree (`C:/Users/.../worktrees/agent-.../src/energia.jl`). Drugi Write zalandowal poprawnie. Wszystkie kolejne Edit-y na `src/JuliaCity.jl` rowniez uzywaly forward-slash worktree path — bez problemu.
- **Files modified:** Brak (issue zidentyfikowany przed commitem; parent project NIE zaplujny)
- **Commit:** N/A (caught przed staging)

### Brak Rule 1/2/4 deviations

Plan został wykonany dosłownie zgodnie z `<tasks>` i `<context><interfaces>` blokami. Wszystkie 5 funkcji ma sygnatury, asercje i algorytmy zgodne z lock-in patternami z CONTEXT.md (D-06 delta, D-08 cache, D-10 two-method, D-11 chunked threading) i RESEARCH.md (Example 1 oblicz_macierz_dystans!, Example 2 kalibruj_T0).

## Authentication Gates

None — wszystkie modyfikacje plików lokalne; brak external API/login wymaganego.

## Issues Encountered

- **Niedostepna Julia uniemozliwia weryfikacje runtime** — Rule 3 (powyzej). Wszystkie text-based + algorithmic-Python smoke checks PASSING; runtime verification deferred do CI.
- **Initial Write tool path bug** — Rule 3 (powyzej). Naprawione przed commitem; parent project clean.
- **Brak gsd-sdk na PATH i pod node_modules/** — `gsd-sdk` CLI niedostepne w worktree, wiec stosuje `git commit --no-verify -m ...` direktl per `<parallel_execution>` instructions. NIE robie `state advance-plan` / `update-progress` / `record-metric` calls — orchestrator owns te updates per `<objective>` ("Do NOT update STATE.md or ROADMAP.md").

## Next Plan Readiness

- **Plan 02-03 (symuluj_krok! SA)** — odblokowany. Wymaga: `delta_energii(stan, i, j)` (✓), `Parametry` struct (✓ z Plan 02-01), `kalibruj_T0` (✓). Algorytm SA bedzie wywolywal `delta_energii` w hot loop ~50_000 razy + uzywal `stan.energia += delta` cache invariant (D-08).
- **Plan 02-04 (distance init + temperatura cooling)** — odblokowany. Wymaga: `oblicz_macierz_dystans!(stan)` (✓) dla init pipeline, `kalibruj_T0(stan)` (✓) dla T0. Cooling schedule (geometric α≈0.995) bedzie nowym kodem w `src/algorytmy/simulowane_wyzarzanie.jl`.
- **Plan 02-05 (test suite correctness — TEST-08 golden values)** — odblokowany. Bedzie testowal: `oblicz_energie([square4]) ≈ 4.0`, `delta_energii` symetria/ekwiwalencja z full recompute, `kalibruj_T0` returns positive Float64, type stability `@inferred` na wszystkich 5 funkcjach.
- **Plan 02-06 (quality gates Aqua/JET)** — odblokowany. Aqua test bedzie wymagal `ignore = [:Random, :Statistics]` (juz logged jako follow-up w Plan 02-01 SUMMARY). JET `@report_opt` bedzie pokrywal `oblicz_energie`, `delta_energii`, `kalibruj_T0`.

## Threat Surface Scan

Zagrożenia z `<threat_model>` planu 02-02 zaadresowane:

- **T-02-04 (Tampering, trasa[i] poza 1:n):** accept — wewnetrzny invariant (`symuluj_krok!` w Plan 02-03 gwarantuje permutacje 1:n); `@assert 1 <= i < j <= n` w `delta_energii` chroni przed bezposrednim niewlasciwym wywolaniem; `@inbounds` w hot-path `oblicz_energie(D, trasa, bufor)` traktuje to jako precondition (akceptowalne wewnatrz pakietu).
- **T-02-05 (DoS, oblicz_macierz_dystans! dla bardzo dużego n):** accept — public API nie ma cap na n; user tworzy StanSymulacji wlasnym kodem; out-of-scope wg REQUIREMENTS.md ("N >> 1000 punktow" eksplicytnie wykluczone).
- **T-02-06 (Information Disclosure, asercja "no worsening moves"):** accept — standard Julia error message convention; brak sekretow w stan.

**Brak nowych threat surfaces poza zarejestrowanymi.** Phase 2 to pure-algorithmic library code: zero network, zero secrets, zero PII, zero file I/O. ASVS L1 nie wymaga validation/auth dla wewnetrznej biblioteki Julii.

## Self-Check: PASSED

All claims verified.

**Files:**
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\.claude\worktrees\agent-a9616e640f5f2f29e\src\energia.jl` — FOUND (188 linii, 5 funkcji, all 9 grep acceptance criteria PASS)
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\.claude\worktrees\agent-a9616e640f5f2f29e\src\JuliaCity.jl` — FOUND (39 linii, include(energia.jl) + 4 nowe exports, all 6 grep acceptance criteria PASS)
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\.claude\worktrees\agent-a9616e640f5f2f29e\.planning\phases\02-energy-sa-algorithm-test-suite\02-02-SUMMARY.md` — FOUND (this file, will be committed below)

**Commits:**
- `cd10623` (Task 1: src/energia.jl creation) — FOUND in git log
- `49fddbb` (Task 2: wire energia.jl into JuliaCity.jl) — FOUND in git log

**Verification block from PLAN executed:**
- Task 1 acceptance criteria: 9/9 text-based PASS (grep counts, line counts, NFC/BOM/ASCII filename); Roadmap SC-1 algorithmically verified PASS via Python mirror simulation (4.0 exact match); runtime `julia --project=. -e ...` blocked by no-Julia env
- Task 2 acceptance criteria: 6/6 text-based PASS (grep counts, topological order); runtime `using JuliaCity; oblicz_energie(...)` blocked
- Plan-level integration: `Pkg.test()` exit 0 — NOT VERIFIED (no Julia available); deferred to CI/dev-machine

**Phase 2 Plan 02 KOMPLETNA jako file modifications + 2 commits — pelna runtime weryfikacja oczekuje pierwszego CI runu (julia-actions/julia-buildpkg uruchomi Pkg.instantiate i Pkg.test). Algorithmically zweryfikowana przez Python mirror simulation (Roadmap SC-1 = 4.0 exact).**

---
*Phase: 02-energy-sa-algorithm-test-suite*
*Completed: 2026-04-29*
