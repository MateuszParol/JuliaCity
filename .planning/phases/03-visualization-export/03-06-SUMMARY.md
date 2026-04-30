---
phase: 03-visualization-export
plan: 06
subsystem: testing
tags:
  - julia
  - testing
  - viz-06-grep-guard
  - headless
  - phase-3-complete
dependency_graph:
  requires:
    - 03-05-SUMMARY.md  # wizualizacja.jl z using GLMakie na top-level (VIZ-06 invariant)
  provides:
    - VIZ-06 formal grep guard testset w runtests.jl
  affects:
    - test/runtests.jl
tech_stack:
  added: []
  patterns:
    - pkgdir(JuliaCity) jako anchor w Pkg.test sandbox (mirror encoding hygiene testset)
    - walkdir(src/) + per-line startswith match — eliminuje false-positives w komentarzach
    - @info diagnostics w else branch (wskazuje konkretny plik naruszajacy VIZ-06)
key_files:
  created: []
  modified:
    - test/runtests.jl  # +47 linii: @testset "VIZ-06: GLMakie isolation" (przed Aqua)
decisions:
  - VIZ-06 invariant pokryty formalnym testem (walkdir+read+per-line) zamiast tylko grep w verify sections
  - Per-line iteration (startswith(strip(linia), "using GLMakie")) zamiast occursin na calym pliku — eliminuje false-positives w docstringach
metrics:
  duration: 3m
  completed: "2026-04-30"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 3 Plan 6: VIZ-06 GLMakie Isolation Guard Summary

**One-liner:** Grep-level testset weryfikujacy ze src/wizualizacja.jl jest jedynym plikiem w src/ importujacym GLMakie — headless-safe, pkgdir-anchored, per-line match eliminuje false-positives.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Dodac @testset "VIZ-06: GLMakie isolation" do runtests.jl | c851d40 | test/runtests.jl (+47 linii) |

## Implementation Details

Nowy testset umieszczony jako sekcja "9b" w `test/runtests.jl`, przed istniejacym blokiem Aqua (sekcja "9"). Logiczne grupowanie: encoding hygiene (sekcja 1) → VIZ-06 isolation (9b) → Aqua quality gate (9) → JET stability (10).

**Pozycja w runtests.jl:** po `include("test_symulacja.jl")` (linia ~198), przed `@testset "Aqua.jl quality (TEST-06)"`.

**Liczba testow przed/po:** 226 → 230 (+4 asercje):
1. `@test isdir(src_dir)` — sanity: anchor poprawnie znalezione
2. `@test !isempty(pliki_jl)` — sanity: walkdir znalazl pliki .jl
3. `@test length(pliki_z_glmakie) == 1` — dokladnie 1 plik z `using GLMakie`
4. `@test endswith(pliki_z_glmakie[1], "wizualizacja.jl")` — to jest wizualizacja.jl

**Dlaczego per-line zamiast occursin:** `src/wizualizacja.jl` zawiera komentarze opisujace VIZ-06 invariant w formie "VIZ-06: jedyne miejsce w src/ z tym importem" — occursin na calym pliku moglby dac false-positives jezeli inny plik zawieralby taki komentarz. Per-line `startswith(strip(linia), "using GLMakie")` jest anchored na poczatek linii.

## Verification

Pkg.test() exit 0, wszystkie 230 testow PASS:

```
Test Summary: | Pass  Total     Time
JuliaCity     |  230    230  1m48.3s
     Testing JuliaCity tests passed
```

Sanity grep (dokladnie 1 plik w src/ z `using GLMakie` jako instrukcja importu):
```bash
$ grep -l "^using GLMakie" src/
src/wizualizacja.jl
```

## Phase 3 REQ Coverage

| REQ-ID | Nazwa | Plan | Status |
|--------|-------|------|--------|
| VIZ-01 | Okno GLMakie z animacja | 03-01 + 03-03 | IMPL |
| VIZ-02 | Polish tytul/etykiety/overlay | 03-02 | IMPL |
| VIZ-03 | Dark theme + dual panel | 03-02 | IMPL |
| VIZ-04 | Observable{Vector{Point2f}} + cycle closure | 03-02 | IMPL |
| VIZ-05 | Throttling KROKI_NA_KLATKE >= 10 | 03-03 | IMPL |
| VIZ-06 | wizualizacja.jl jedyny plik z using GLMakie | **03-06** | TEST (formalny grep guard) |
| VIZ-07 | GOTOWE overlay po SA stop | 03-05 | IMPL |
| EKS-01 | eksport= argument, detekcja mp4/gif | 03-04 | IMPL |
| EKS-02 | Makie.record() export loop | 03-04 | IMPL |
| EKS-03 | ProgressMeter podczas eksportu | 03-04 | IMPL |
| EKS-04 | isfile() hard-fail / bezpieczne nadpisanie | 03-04 | IMPL |

**Phase 3 COMPLETE: 11/11 REQ-IDow (VIZ-01..07, EKS-01..04) zaimplementowanych lub testowo-pokrytych.**

## Phase 3 ROADMAP Success Criteria Audit

| SC | Kryterium | Plan | Status |
|----|-----------|------|--------|
| SC #1 | wizualizuj() otwiera GLMakie window z animacja trasy | 03-03 | DONE (manual smoke) |
| SC #2 | Polskie tytuly/etykiety/overlay z diakrytykami (NFC D-21) | 03-02 | DONE |
| SC #3 | Throttling KROKI_NA_KLATKE, okno responsywne | 03-03 | DONE |
| SC #4 | wizualizacja.jl jedyny plik z `using GLMakie` (grep test) | **03-06** | DONE (formal test) |
| SC #5 | eksport=mp4/gif z ProgressMeter + safe overwrite | 03-04 | DONE |

**Wszystkie 5 ROADMAP SC Phase 3 osiagniete.**

## Deviations from Plan

None — plan wykonany dokladnie zgodnie ze specyfikacja. Testset dodany zgodnie z wzorcem z PATTERNS.md z poprawnymi szczegolami (pkgdir anchor, per-line match, 2 asercje hard + 2 sanity).

## Known Stubs

None — plan 03-06 nie wprowadza zadnych stubs. Modyfikacja tylko `test/runtests.jl`.

## Threat Flags

Brak nowych zagrozeniach bezpieczenstwa. Test czyta tylko pliki .jl jako String (read-only I/O), nie wykonuje zadnego kodu zewnetrznego.

## Self-Check: PASSED

- [x] test/runtests.jl istnieje i zawiera "@testset \"VIZ-06: GLMakie isolation\""
- [x] Commit c851d40 istnieje w git log
- [x] Pkg.test() exit 0, 230/230 PASS
- [x] Brak niechcianych deletions w commicie
