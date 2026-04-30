---
phase: 04-demo-benchmarks-documentation
plan: 02
subsystem: bench
tags: [cleanup, archive, audit-trail, phase-2-carry-forward]
requires:
  - bench/diagnostyka_test05.jl (Phase 2 plan 02-14 erratum)
  - bench/diagnostyka_test05_budget.jl
  - bench/diagnostyka_test05_random_vs_nn.jl
provides:
  - bench/historyczne/ subdirectory (audit trail Phase 2 02-14)
  - bench/historyczne/README.md (Polish context document)
  - bench/ top-level cleared for Phase 4 new files
affects:
  - Phase 4 wave 2+ benchmark plans (now have clean bench/ namespace)
tech-stack:
  added: []
  patterns:
    - git mv (rename detection, not delete+add) for audit-trail integrity
    - Polish typography per D-18 (em-dash U+2014, NFC, BOM-free, LF)
key-files:
  created:
    - bench/historyczne/README.md
  modified:
    - bench/historyczne/diagnostyka_test05.jl (renamed from bench/, content unchanged)
    - bench/historyczne/diagnostyka_test05_budget.jl (renamed from bench/, content unchanged)
    - bench/historyczne/diagnostyka_test05_random_vs_nn.jl (renamed from bench/, content unchanged)
decisions:
  - D-16 enforced — files moved, NOT deleted (audit trail preserved)
  - Folder name "historyczne" ASCII per D-23 (Polish, no diacritics)
  - README documents 3 scripts + links to 02-14-SUMMARY.md + cites TEST-05 lock 0.9408
metrics:
  duration: ~3min
  completed: 2026-04-30
  tasks_completed: 2
  files_changed: 4
requirements:
  - BENCH-05
---

# Phase 4 Plan 02: bench/historyczne/ archive Summary

Wave 1 cleanup: 3 pliki diagnostyki Phase 2 plan 02-14 erratum przeniesione przez `git mv` do `bench/historyczne/` (audit trail zachowany, history preserved as renames), plus polski `bench/historyczne/README.md` wyjaśniający kontekst — top-level `bench/` namespace czysty dla 4 nowych plików Phase 4.

## What Was Done

### Task 1: Przenieś 3 pliki diagnostyki do bench/historyczne/

- Utworzono katalog `bench/historyczne/` (ASCII per D-23, polski bez diakrytyku).
- Wykonano `git mv` dla 3 plików — git status pokazał `R` (rename) zamiast delete+add:
  - `bench/diagnostyka_test05.jl` → `bench/historyczne/diagnostyka_test05.jl` (218 linii, niezmieniony)
  - `bench/diagnostyka_test05_budget.jl` → `bench/historyczne/diagnostyka_test05_budget.jl` (31 linii, niezmieniony)
  - `bench/diagnostyka_test05_random_vs_nn.jl` → `bench/historyczne/diagnostyka_test05_random_vs_nn.jl` (90 linii, niezmieniony)
- Suma 339 linii zachowana 1:1 — sprawdzone `wc -l` przed i po move.
- Zawartość plików nietknięta (read-only audit trail Phase 2 02-14 erratum).
- **Commit:** `c010a70`

### Task 2: Utwórz bench/historyczne/README.md

- Plik 29-liniowy, polski, NFC-normalized, BOM-free, LF endings, final newline.
- Sekcje: nagłówek + opis tła + tabela 3 plików + sekcja "Wynik diagnozy" + "Uruchomienie".
- Cytuje TEST-05 lock `ratio = 0.9408` (z STATE.md).
- Linkuje do `.planning/phases/02-energy-sa-algorithm-test-suite/02-14-SUMMARY.md`.
- Em-dash `—` (U+2014) użyty 5× zgodnie z konwencją Phase 4 D-18.
- Cudzysłowy obecne wyłącznie w nazwach plików/kodzie ASCII (zgodne z konwencją).
- **Commit:** `9196248`

## Verification Results

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| `find bench/historyczne -name '*.jl' \| wc -l` | 3 | 3 | PASS |
| `find bench -maxdepth 1 -name 'diagnostyka_test05*.jl' \| wc -l` | 0 | 0 | PASS |
| `test -f bench/historyczne/README.md` | exit 0 | exit 0 | PASS |
| `grep -c 'plan 02-14' README.md` | ≥ 1 | 2 | PASS |
| `grep -c '0.9408' README.md` | ≥ 1 | 1 | PASS |
| `grep -c '02-14-SUMMARY.md' README.md` | ≥ 1 | 1 | PASS |
| `grep -c '—' README.md` (em-dash) | ≥ 1 | 5 | PASS |
| `grep -c '^\\|.*diagnostyka_test05' README.md` | ≥ 3 | 3 | PASS |
| BOM check (`head -c3 \| xxd`) | NO efbbbf | `2320 41` (just `# A`) | PASS |
| Last byte (`tail -c1 \| xxd`) | `0a` | `0a` | PASS |
| CRLF check (`grep -c $'\\r'`) | 0 | 0 | PASS |
| NFC normalized | True | True | PASS |
| Git status (Task 1) shows renames | R | R R R | PASS |
| Line count integrity | 218+31+90 | 218+31+90 | PASS |

Wszystkie acceptance criteria z PLAN.md spełnione (oba taski).

## Deviations from Plan

None — plan executed exactly as written. No Rule 1/2/3 auto-fixes triggered. No checkpoints encountered (`autonomous: true`).

## Authentication Gates

None — pure local filesystem operation.

## Key Decisions Made

- D-16 enforcement: `git mv` zamiast `mv` + `rm`/`add` — gwarantuje rename detection w git log (audit trail integrity).
- README umieszczony **w katalogu archiwum** (`bench/historyczne/README.md`) zamiast w `bench/wyniki.md` header, ponieważ:
  - Lokalność: czytelnik archiwum natychmiast widzi kontekst.
  - Separacja: `bench/wyniki.md` Phase 4 nie miesza się z opisem deferred archiwum.

## Threat Model Compliance

| Threat ID | Status | Notes |
|-----------|--------|-------|
| T-04-02-01 (Repudiation) | mitigated | `git status` potwierdza renames (R) — git log śledzi historię plików przez `--follow`. |
| T-04-02-02 (Tampering) | accepted | Plan zabronił modyfikacji; sprawdzone `wc -l` 218+31+90 = 339 linii niezmienione. |

## Files Touched

| Path | Operation | Lines | Commit |
|------|-----------|-------|--------|
| `bench/historyczne/diagnostyka_test05.jl` | renamed (R 100%) | 218 (=) | c010a70 |
| `bench/historyczne/diagnostyka_test05_budget.jl` | renamed (R 100%) | 31 (=) | c010a70 |
| `bench/historyczne/diagnostyka_test05_random_vs_nn.jl` | renamed (R 100%) | 90 (=) | c010a70 |
| `bench/historyczne/README.md` | created | 29 | 9196248 |

## Commits

| Hash | Type | Subject |
|------|------|---------|
| c010a70 | chore | move diagnostyka_test05*.jl to bench/historyczne/ |
| 9196248 | docs | add bench/historyczne/README.md explaining Phase 2 02-14 audit trail |

## Known Stubs

None — all artifacts substantive and final (no placeholders, no TODO markers, no empty containers in rendered output).

## Self-Check: PASSED

- Created file `bench/historyczne/README.md`: FOUND
- Renamed file `bench/historyczne/diagnostyka_test05.jl`: FOUND
- Renamed file `bench/historyczne/diagnostyka_test05_budget.jl`: FOUND
- Renamed file `bench/historyczne/diagnostyka_test05_random_vs_nn.jl`: FOUND
- Old location `bench/diagnostyka_test05.jl`: ABSENT (as expected)
- Old location `bench/diagnostyka_test05_budget.jl`: ABSENT (as expected)
- Old location `bench/diagnostyka_test05_random_vs_nn.jl`: ABSENT (as expected)
- Commit `c010a70`: FOUND in git log
- Commit `9196248`: FOUND in git log
