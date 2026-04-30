---
phase: 04-demo-benchmarks-documentation
plan: 03
subsystem: documentation
tags: [contributing, polish-typography, unicode, nfc, encoding-hygiene]

# Dependency graph
requires:
  - phase: 01-bootstrap-setup
    provides: CONTRIBUTING.md (sections §1-§3) + encoding-guard test in test/runtests.jl
provides:
  - Polish-typography convention (D-18) documented in CONTRIBUTING.md §4
  - Unicode codepoint reference table (U+201E, U+201D, U+2014, U+2013) for downstream Wave 4 README rewrite (Plan 04-08)
  - Self-demonstrating typography (file uses correct glyphs in §4)
affects:
  - 04-08-readme-rewrite (consumer of typography rules)
  - 04-04-examples-podstawowy (Polish @info messages must follow convention)
  - 04-05-examples-eksport (Polish @info messages must follow convention)
  - all future user-facing strings in src/wizualizacja.jl overlays

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Section-renumber pattern: append new ##N before old ##N, renumber subsequent sections by +1"
    - "Eat-your-own-dog-food rule for typography sections (file demonstrates its own rules)"

key-files:
  created: []
  modified:
    - CONTRIBUTING.md (insert §4, renumber §4→§5 and §5→§6)

key-decisions:
  - "New §4 'Typografia polska' inserted between §3 (Polski/angielski split) and old §4 (Style przed commit) — keeps related-language conventions adjacent (§3 = which language, §4 = which glyphs)"
  - "Used U+201D (right double quotation mark, „) as closing quote, NOT U+0022 ASCII straight quote — Polish typographic convention"
  - "NFC normalization affirmed for .md files in body text even though encoding-guard test enforces NFC only for .jl (manual PR review covers .md per §1)"

patterns-established:
  - "Pattern 1: Polish typography in user-facing markdown — „...” for quotes, — for em-dash, – for en-dash, NFC + LF + BOM-free"
  - "Pattern 2: Section renumbering on insert — when adding a new numbered section, renumber all subsequent sections to maintain contiguous numbering"

requirements-completed: [LANG-02, LANG-03]

# Metrics
duration: 7min
completed: 2026-04-30
---

# Phase 4 Plan 03: Typografia polska Summary

**CONTRIBUTING.md §4 'Typografia polska' added with Unicode codepoint table (U+201E/U+201D/U+2014/U+2013) — self-demonstrates the convention; old §4/§5 renumbered to §5/§6.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-30T11:45:00Z
- **Completed:** 2026-04-30T11:52:15Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added new `## 4. Typografia polska` section to `CONTRIBUTING.md` with a 4-row Unicode glyph table covering opening/closing low/high quotation marks (U+201E, U+201D), em-dash (U+2014), and en-dash (U+2013) plus usage rules
- Renumbered old `## 4. Style przed commit` → `## 5.` and `## 5. Workflow GSD` → `## 6.`, preserving contiguous section numbering
- File self-demonstrates the convention: `„`, `”`, `—`, `–` glyphs appear literally in §4 body text (NOT as escape sequences)
- Verified all encoding-hygiene invariants on disk: UTF-8 well-formed, NFC-normalized, BOM-free, LF line endings, final newline present
- Closes STATE.md TODO „Document Polish-typography convention" — convention now exists for Wave 4 (README rewrite) to reference

## Task Commits

Each task was committed atomically:

1. **Task 1: Wstaw §4 Typografia polska + przerumeruj §4→§5, §5→§6** — `013050b` (docs)

_Note: STATE.md / ROADMAP.md / final metadata commit are deliberately skipped per parallel-executor scope (orchestrator handles those)._

## Files Created/Modified

- `CONTRIBUTING.md` — Inserted new §4 (Typografia polska, 19 lines including blank lines) between §3 and old §4; renumbered old §4 (Style) to §5 and old §5 (Workflow GSD) to §6. Net diff: 22 insertions, 2 deletions (heading-line replacements).

## Decisions Made

- **Placement of new §4 between §3 and old §4 (not at file end):** Plan explicitly prescribed this position (between „Polski/angielski split" and „Style przed commit"). Logical grouping: §3 answers „which language", §4 answers „which glyphs" — both are language conventions, kept adjacent.
- **Glyph encoding strategy:** Wrote glyphs literally in markdown source via the Edit tool's UTF-8 string handling (NOT via `\u` escapes or `printf` heredocs). Hex verification confirmed `e2809e` (U+201E), `e2809d` (U+201D), `e28094` (U+2014), `e28093` (U+2013) on disk.
- **Self-reference §1 footnote:** Added cross-reference „patrz §1" inside the NFC paragraph to anchor encoding rules to the existing §1 (Encoding plików), reducing duplication.

## Deviations from Plan

None — plan executed exactly as written.

The plan's task action included one minor verbatim discrepancy from the PATTERNS.md draft („w prozą" vs. „w prozie"). The plan's task action specified „w prozie" (correct Polish accusative) and that text was reproduced exactly. No rule-driven deviation occurred.

## Issues Encountered

- **First Edit tool invocation appeared to succeed but did not persist to disk** (verified via Bash `wc -l` returning the original 90 lines and Python byte-level inspection showing the unchanged file). The follow-up Edit call (using the absolute worktree-qualified path) wrote the change. Resolution: re-invoked Edit with the fully-qualified worktree path and confirmed `git status` showed `M CONTRIBUTING.md` and `wc -l` reported 110 lines. Final file matches all acceptance criteria.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- §4 convention is the canonical reference for Wave 4 Plan 04-08 (README.md rewrite) — README must use „...” quotes and — em-dashes per the table.
- Encoding-guard test (`test/runtests.jl` lines 25-88) will validate `CONTRIBUTING.md` on next `Pkg.test()`: UTF-8 valid, no BOM, no CRLF (NFC enforced for `.jl` only — manual review for `.md` per §1).
- No blockers for Wave 1 sibling plans 04-01 (Project.toml) and 04-02 (.gitignore).

## Self-Check: PASSED

**Files:**
- FOUND: `CONTRIBUTING.md` (modified, 110 lines, 4643 bytes)
- FOUND: `.planning/phases/04-demo-benchmarks-documentation/04-03-SUMMARY.md` (this file)

**Commits:**
- FOUND: `013050b` (docs(04-03): add Typografia polska section to CONTRIBUTING)

**Acceptance criteria checklist (from PLAN.md):**
- [x] `## 4. Typografia polska` heading present (literal match)
- [x] `## 5. Style przed commit` present (renumbered from 4)
- [x] `## 6. Workflow GSD` present (renumbered from 5)
- [x] Old `## 4. Style przed commit` and `## 5. Workflow GSD` removed
- [x] Table contains all 4 codes: U+201E, U+201D, U+2014, U+2013
- [x] Literal `„` (U+201E) appears ≥ 1 time (3 occurrences confirmed)
- [x] Literal `—` (U+2014) appears ≥ 2 times (14 occurrences confirmed)
- [x] §1, §2, §3 unchanged (each `^## N\.` returns exactly one line)
- [x] No BOM (`head -c3 | xxd` shows `2320 57` = `# W`, not `efbbbf`)
- [x] Final byte is LF (`tail -c1 | xxd` shows `0a`)
- [x] Line count: 110 (≥ 106)
- [x] NFC normalization: Python `unicodedata.normalize('NFC', text) == text` returns True
- [x] No CRLF (`grep -c $'\r'` returns 0)

---
*Phase: 04-demo-benchmarks-documentation*
*Plan: 03*
*Completed: 2026-04-30*
