---
phase: 01-bootstrap-core-types-points
plan: 01
subsystem: infra
tags: [julia, juliaup, install, environment, lts]

requires: []
provides:
  - "Działający binary `julia` w PATH (`$HOME/.juliaup/bin/julia`)"
  - "juliaup version manager z kanałami `release` (1.12.6) oraz `1.10` (1.10.11)"
  - "Default channel pinned do `1.10` (zgodnie z `julia = \"1.10\"` compat floor)"
  - "Stdlib `Pkg` ładuje się bez błędów; globalne env pod `~/.julia/environments/v1.10/`"
affects: [01-02-skeleton, 01-03-project-toml, 01-04-module-types, 01-05-generuj-punkty, 01-06-tests-ci]

tech-stack:
  added: [juliaup, julia-1.12.6, julia-1.10.11]
  patterns: ["juliaup multi-channel runtime z pinned default na LTS"]

key-files:
  created: []
  modified: ["~/.zshrc (dodany wpis PATH przez juliaup)"]

key-decisions:
  - "Użyto oficjalnego instalatora `curl https://install.julialang.org` (D-17 — official channel)"
  - "Default channel = `1.10` (LTS), nie `release` (1.12) — gwarantuje, że dev local match z compat floor zadeklarowanym w Project.toml; zapobiega wykrywaniu post-1.10 syntax/API jako działającego"
  - "Dual-channel: 1.12.6 zachowane jako `release` dla opcjonalnego cross-version smoke-testu w przyszłości"

patterns-established:
  - "Runtime pinning: dev używa tego samego floora co `[compat]` Project.toml, żeby uniknąć false-pass syntax-only checks"

requirements-completed: []

duration: 3min
completed: 2026-04-28
---

# Plan 01-01: Julia 1.10+ Install Summary

**juliaup zainstalowany; default channel ustawiony na Julia 1.10.11 LTS (matching `julia = "1.10"` compat floor)**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-28T15:43:00Z
- **Completed:** 2026-04-28T15:46:32Z
- **Tasks:** 1 (checkpoint:human-verify, autoryzowany przez użytkownika do auto-execute)
- **Files modified:** 0 w repo (zmiany tylko w `~/.zshrc` i `~/.juliaup/`)

## Accomplishments

- juliaup zainstalowany pod `$HOME/.juliaup` (user-space, no sudo)
- Julia 1.12.6 zainstalowana jako kanał `release`
- Julia 1.10.11 LTS dodana (`juliaup add 1.10`) i ustawiona jako default (`juliaup default 1.10`)
- PATH dodany do `~/.zshrc` przez instalator
- Wszystkie acceptance criteria spełnione: `julia --version` → `1.10.11`, `julia -e 'using Pkg'` → exit 0, `which julia` → `/Users/mattparol/.juliaup/bin/julia`

## Task Commits

Plan był checkpointem human-verify (no in-repo file changes — tylko zmiany systemowe), więc nie ma per-task commitów kodu. Plan metadata commit obejmuje tylko `01-01-SUMMARY.md`.

## Files Created/Modified

W repo: brak (instalacja systemowa).
Poza repo:
- `~/.zshrc` — wpis PATH dodany przez juliaup installer
- `~/.juliaup/` — katalog instalacyjny juliaup
- `~/.julia/environments/v1.10/` — globalne env Pkg dla 1.10

## Decisions Made

- **Default channel = 1.10 LTS** zamiast 1.12 release — zgodnie z `julia = "1.10"` compat floor zaplanowanym dla Project.toml (D-17). Jeśli developer pracowałby na 1.12 a CI floor był 1.10, mogłyby przejść lokalnie features dostępne tylko od 1.11+ (np. ScopedValues, `:greedy` schedule). Pinning local default do 1.10 wymusza dyscyplinę.
- **Dual install (1.10 + 1.12)** — zachowano `release` channel (1.12.6) na wypadek opcjonalnego cross-version smoke-testu lub debugu różnic LTS vs current.

## Deviations from Plan

**1. [Rule: scope] Dodatkowy `juliaup add 1.10` + `juliaup default 1.10` po default-install (release)**
- **Found during:** Task 1 (post-install verification)
- **Issue:** Domyślny instalator `install.julialang.org` zainstalował kanał `release` (1.12.6). Plan w komentarzu `Opcjonalnie` zalecał pinning na 1.10. Zostawiając default `release`, ryzykowalibyśmy syntax/API odpalany lokalnie który nie zadziała na CI (compat floor 1.10).
- **Fix:** Dodano kanał 1.10 i ustawiono jako default (`juliaup default 1.10`).
- **Files modified:** żadne w repo
- **Verification:** `julia --version` → `1.10.11`; `julia -e 'VERSION >= v"1.10"'` → exit 0
- **Committed in:** plan metadata commit (no code commits in this plan)

**Total deviations:** 1 auto-fixed (scope alignment z compat floor)
**Impact on plan:** Wymusza paritet runtime ↔ compat floor dla całej fazy 1; zapobiega future false-positive testom.

## Issues Encountered

None — instalacja juliaup przeszła czysto, oba kanały zaciągnięte bez błędu, weryfikacja pierwszej iteracji zwróciła 0.

## User Setup Required

Brak dodatkowej konfiguracji wymaganej. `~/.zshrc` już zawiera wpis PATH dla `~/.juliaup/bin`. W nowych terminalach `julia` będzie dostępna automatycznie.

## Next Phase Readiness

- Wave 2 (`01-02` repo skeleton) odblokowane: nie wymaga `julia` ale przygotowuje grunt pod 01-03.
- Wave 3 (`01-03` Project.toml) gotowe do uruchomienia — `julia --project=. -e 'using Pkg; Pkg.add(...)'` zadziała, bo binarka jest w PATH i Pkg stdlib działa.
- Compat parity: lokalny binary (1.10.11) match z planowanym `julia = "1.10"` w Project.toml — żaden subagent nie skompiluje akcydentalnie kodu wymagającego 1.11+.

---
*Phase: 01-bootstrap-core-types-points*
*Completed: 2026-04-28*
