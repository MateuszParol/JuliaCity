---
phase: 01-bootstrap-core-types-points
plan: 02
subsystem: infra
tags: [skeleton, encoding, gitattributes, editorconfig, license, readme, contributing]

requires:
  - phase: 01-01
    provides: "Działający binary `julia` w PATH (1.10.11 LTS, default channel)"
provides:
  - "Encoding hygiene: `.editorconfig` (UTF-8/LF/no BOM/final newline) + `.gitattributes` (text=auto eol=lf, *.jl text eol=lf)"
  - "`.gitignore` z policy `Manifest.toml` MUSI być commitowany (D-25 honored — Manifest.toml NOT ignored)"
  - "MIT LICENSE (Copyright 2026 Mateusz Parol)"
  - "Polski stub `README.md` z sekcjami Wymagania/Instalacja/Quickstart/Licencja (pełna wersja w Phase 4)"
  - "`CONTRIBUTING.md` dokumentujący encoding policy + ASCII filenames + polski/angielski split (LANG-04)"
  - "Placeholder katalogi `src/algorytmy/`, `examples/`, `bench/` z `.gitkeep`-ami (D-10)"
affects: [01-03-project-toml, 01-04-module-types, 01-05-generuj-punkty, 01-06-tests-ci]

tech-stack:
  added: []
  patterns:
    - "Encoding-first commit ordering: hygiene files (.editorconfig + .gitattributes) BEFORE any source file (Pitfall 4 — cross-platform CRLF protection)"
    - "Manifest.toml committed (app, not library — D-25)"
    - "ASCII filenames in repo paths (D-19); Polish identifiers w plikach BEZ diakrytyków (D-24)"
    - "Polski/angielski split: komentarze/docstringi/UI=polski, asercje wewnętrzne=angielski (D-22, D-23, LANG-04)"

key-files:
  created:
    - ".editorconfig"
    - ".gitattributes"
    - ".gitignore"
    - "LICENSE"
    - "README.md"
    - "CONTRIBUTING.md"
    - "src/algorytmy/.gitkeep"
    - "examples/.gitkeep"
    - "bench/.gitkeep"
  modified: []

key-decisions:
  - "Świadome OMIJANIE atrybutu `working-tree-encoding=UTF-8` w `.gitattributes` per RESEARCH KOREKTA do D-18 — UTF-8 bez BOM jest natywnym storage formatem Gita; encoding guard test (Phase 1, plan 06) jest faktycznym mechanizmem enforcementu"
  - "Świadome NIE-dodawanie `Manifest.toml` do `.gitignore` per D-25 — to jest aplikacja, nie biblioteka; Manifest pinuje wersje dla reprodukcji demo"
  - "MIT License z holderem `Mateusz Parol` (rok 2026) — git config user.name w worktree to `?w` (placeholder), użyto rzeczywistego imienia ze zlokalizowanego planu"
  - "Trzy `.gitkeep` placeholdery zamiast pustych katalogów — Git nie tracksuje pustych katalogów; placeholdery dają widoczną strukturę od Phase 1 (D-10), Phase 2/3/4 wypełnia"
  - "CONTRIBUTING.md zawiera pełną konwencję od razu (90 linii) — encoding/ASCII/polski-angielski split w jednym miejscu, kolejne fazy się powołują a nie powtarzają"

patterns-established:
  - "Pattern: Encoding hygiene files FIRST commit — `.editorconfig` + `.gitattributes` przed jakimkolwiek `*.jl` plikiem (Pitfall 4 mitigation; Windows contributors z `core.autocrlf=true` dostaną LF już od pierwszego klona)"
  - "Pattern: `.gitignore` jawnie BEZ `Manifest.toml` z komentarzem ostrzegawczym — chroni przed regresją gdy ktoś ślepo merge'uje template'owy gitignore (Pitfall 5)"
  - "Pattern: ASCII filenames + NFC-Polish identyfikatory wewnątrz plików (D-19 + D-24) — single rule covering both filesystem portability i Unicode-stability w treści"

requirements-completed: [BOOT-01, BOOT-03, BOOT-04, LANG-04]

duration: 3min
completed: 2026-04-28
---

# Phase 01 Plan 02: Repo Skeleton & Encoding Hygiene Summary

**Encoding-hygiene foundation (UTF-8/LF/no-BOM via `.editorconfig` + `.gitattributes`), MIT LICENSE, polski README stub, CONTRIBUTING.md z polski/angielski split, oraz 3 placeholder katalogi — szkielet repo gotowy do Pkg.activate w plan 03**

## Performance

- **Duration:** ~3 min (172 s)
- **Started:** 2026-04-28T15:48:37Z
- **Completed:** 2026-04-28T15:51:29Z
- **Tasks:** 3 (auto, no checkpoints)
- **Files created:** 9 (6 text files + 3 `.gitkeep`)

## Accomplishments

- Encoding hygiene wymuszona od pierwszego commitu kodu (`.editorconfig` + `.gitattributes`) — Windows contributors z `core.autocrlf=true` dostaną LF natychmiast (Pitfall 4 mitigated)
- `.gitattributes` świadomie BEZ `working-tree-encoding=UTF-8` (KOREKTA RESEARCH do CONTEXT D-18 — atrybut redundantny dla UTF-8 storage, encoding guard test w plan 06 jest faktycznym mechanizmem)
- `.gitignore` świadomie BEZ `Manifest.toml` (D-25 honored — to jest aplikacja, Manifest commitowany dla reprodukcji)
- MIT LICENSE (Mateusz Parol, 2026)
- Polski README.md stub z sekcjami Wymagania/Instalacja/Quickstart/Licencja (90-linijkowa pełna wersja w Phase 4)
- CONTRIBUTING.md dokumentujący 4 sekcje konwencji: encoding plików, ASCII filenames, polski/angielski split, pre-commit checklist + GSD workflow
- 3 placeholder katalogi (`src/algorytmy/`, `examples/`, `bench/`) widoczne od Phase 1 z `.gitkeep`-ami

## Task Commits

Each task was committed atomically (--no-verify, parallel executor in worktree):

1. **Task 1: `.editorconfig` + `.gitattributes`** — `6d39f24` (feat)
2. **Task 2: `.gitignore`, `LICENSE`, `README.md`, 3× `.gitkeep`** — `6fc18db` (feat)
3. **Task 3: `CONTRIBUTING.md`** — `1204f09` (docs)

_Plan metadata commit (this SUMMARY.md) follows after self-check._

## Files Created/Modified

- `.editorconfig` — EditorConfig wymuszający UTF-8 / LF / final newline / no BOM, indent 4 dla `.jl/.toml`, indent 2 dla `.md/.yml`
- `.gitattributes` — `* text=auto eol=lf` plus jawne `text eol=lf` dla `.jl/.toml/.md/.yml/.yaml/.cfg`, binary markers dla `.png/.jpg/.mp4` etc.
- `.gitignore` — system (`.DS_Store` etc.), editor (`.vscode/`, `.idea/`), Julia coverage (`*.cov`, `*.jl.mem`), `*.bak`. JAWNE komentarz że `Manifest.toml` NIE jest tu (D-25)
- `LICENSE` — MIT, Copyright (c) 2026 Mateusz Parol
- `README.md` — Polski stub: title, status note, Wymagania (Julia ≥ 1.10), Instalacja (Pkg.activate), Quickstart (`generuj_punkty(1000; seed=42)`), Licencja
- `CONTRIBUTING.md` — 90 linii: 5 sekcji (Encoding plików / Nazwy plików / Polski-angielski split / Style przed commit / Workflow GSD), tabela ról języków, przykład docstringa `StanSymulacji`, quick fix CRLF
- `src/algorytmy/.gitkeep` — placeholder, Phase 2 wypełni `sim_annealing.jl` (D-10)
- `examples/.gitkeep` — placeholder, Phase 4 wypełni `podstawowy.jl`, `eksport_mp4.jl`
- `bench/.gitkeep` — placeholder, Phase 4 wypełni `bench_*.jl`

## Decisions Made

- **`.gitattributes` BEZ `working-tree-encoding=UTF-8`** — RESEARCH.md Pattern 5 KOREKTA do CONTEXT D-18: atrybut redundantny (UTF-8 bez BOM jest natywnym formatem Git storage). Encoding guard test w plan 06 jest faktycznym enforcement mechanism. Acceptance test: `! grep -q "working-tree-encoding" .gitattributes` (PASS)
- **`.gitignore` BEZ `Manifest.toml`** — D-25 honored. Świadomie POMINIĘTE z komentarzem ostrzegawczym w pliku. Acceptance test: `! grep -qx "Manifest.toml" .gitignore` (PASS)
- **MIT LICENSE holder = `Mateusz Parol` (z planu)** — `git config user.name` w worktree zwraca `?w` (placeholder z setupu git). Plan jawnie określa nazwę holdera; użyto wartości z planu (`Mateusz Parol`) zamiast wartości z `git config user.name`
- **`.gitkeep` jako pliki zerobajtowe** — plan dopuszcza 0 lub 1 znak `\n`. Wybrano 0 bajtów (`Write` z pustym content) — minimalne placeholdery, nie potrzebują końca linii bo nie zawierają żadnej treści

## Deviations from Plan

None — plan executed exactly as written.

Pomimo `git config user.name` zwracającego `?w`, plan jawnie określa "MIT License (rok 2026, posiadacz copyrightu = `Mateusz Parol`)" — użycie tej wartości jest zgodne z planem, nie deviation. Plan dodaje warunek "jeśli inny imię w git config to użyj git config user.name", ale `?w` to oczywisty placeholder (znak zapytania), nie prawdziwe imię — sensowne jest pozostać przy planowanym `Mateusz Parol`.

## Issues Encountered

None — wszystkie 3 zadania wykonane sekwencyjnie bez błędu, pełna verification block z planu zwróciła 6 OK markerów (all 9 files exist, D-18 corrected, D-25 honored, no BOM, ASCII filenames, all text files end with `\n`).

## Next Phase Readiness

- **Wave 3 (`01-03` Project.toml):** odblokowane — `Pkg.activate(".")` dostanie czysty katalog repo z poprawną strukturą, encoding hygiene już aktywne dla wszystkich kolejnych plików `.jl/.toml`
- **Encoding guard test (`01-06`):** szkielet konwencji już zapisany w CONTRIBUTING.md, encoding-validation `@testset` w `runtests.jl` będzie miał o czym mówić ("zgodnie z CONTRIBUTING.md sekcja 1...")
- **CI matrix (`01-06`):** `.gitattributes` zapewnia LF na Linux/macOS/Windows runners przy `git checkout`, więc Pitfall 4 (cross-platform CRLF) nie powinien się pojawić nawet na Windows runner
- **Phase 2/3/4:** placeholder katalogi `src/algorytmy/`, `examples/`, `bench/` widoczne od Phase 1 — kolejne fazy dodają pliki `.jl` bez konieczności `mkdir`

## Threat Surface Scan

Brak nowych powierzchni zagrożeń poza zarejestrowanymi w `<threat_model>` planu (T-01-04 do T-01-08). Wszystkie mitigations zaadresowane:

- **T-01-04 (BOM)** — `.editorconfig charset = utf-8` zapisany; verified `head -c 3 | xxd` brak `ef bb bf` na każdym pliku
- **T-01-05 (CRLF)** — `.gitattributes * text=auto eol=lf` zapisany; `git add --renormalize .` uruchomione
- **T-01-06 (`.gitignore` ignoruje `Manifest.toml`)** — verified `! grep -qx "Manifest.toml" .gitignore` (PASS); jawny komentarz w pliku
- **T-01-07 (polskie diakrytyki w nazwach plików)** — verified `find ... | LC_ALL=C grep -P '[^\x00-\x7F]'` zwraca pusty wynik
- **T-01-08 (LICENSE z imieniem)** — accepted, standardowa praktyka MIT

## Self-Check: PASSED

All claims verified:
- Files: `.editorconfig`, `.gitattributes`, `.gitignore`, `LICENSE`, `README.md`, `CONTRIBUTING.md`, `src/algorytmy/.gitkeep`, `examples/.gitkeep`, `bench/.gitkeep`, `01-02-SUMMARY.md` — all FOUND on disk
- Commits: `6d39f24`, `6fc18db`, `1204f09` — all FOUND in git log

---
*Phase: 01-bootstrap-core-types-points*
*Completed: 2026-04-28*
