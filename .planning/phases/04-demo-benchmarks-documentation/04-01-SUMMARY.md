---
phase: 04-demo-benchmarks-documentation
plan: 01
subsystem: config
tags: [config, gitignore, project-toml, benchmarktools, assets]
requires:
  - "Project.toml [extras] BenchmarkTools (Phase 1+2)"
  - "Project.toml [compat] BenchmarkTools = \"1.6\" (Phase 1+2)"
provides:
  - "BenchmarkTools dostępne w środowisku testowym przez [targets].test"
  - ".gitignore allowlist dla assets/demo.gif (D-05 EXACT — 2 reguły)"
affects:
  - "bench/* skrypty (wave 2-3) — będą mogły załadować BenchmarkTools w temp-env"
  - "examples/eksport_mp4.jl (plan 04-07) — assets/demo.gif commitowalny"
tech_stack_added: []
tech_stack_patterns:
  - "Pkg [targets].test extension dla bench-only deps (D-10, no separate bench/Project.toml)"
  - ".gitignore selective allowlist (assets/* + !assets/demo.gif, D-05 LOCKED EXACTLY)"
key_files_created: []
key_files_modified:
  - "Project.toml — [targets].test rozszerzona o BenchmarkTools (alfabetycznie)"
  - ".gitignore — sekcja Asset binaries (D-05) z 2 regułami"
decisions:
  - "Zachowana kolejność alfabetyczna w [targets].test: Aqua → BenchmarkTools → JET → ..."
  - "DOKŁADNIE 2 reguły assets/ (D-05 EXACT) — brak !assets/.gitkeep ani innych negacji"
  - "Komentarz polski przed regułami z odwołaniem do D-05 (audit trail)"
duration_minutes: 5
completed: "2026-04-30T11:50:44Z"
requirements_satisfied:
  - "DEMO-02 (partial — odblokowuje assets/demo.gif commit pipeline)"
  - "BENCH-04 (partial — odblokowuje BenchmarkTools w bench/* scripts)"
---

# Phase 4 Plan 1: Config, Extras, .gitignore, Assets Summary

Wave 1 prep — rozszerzenie środowiska testowego Project.toml o BenchmarkTools (D-10) i dodanie do .gitignore DOKŁADNIE dwóch reguł `assets/*` + `!assets/demo.gif` (D-05 LOCKED EXACTLY) — config-touch odblokowujący bench/* (Wave 2-3) i examples/eksport_mp4.jl (Wave 2).

## Objective

Niezależny config-touch wykonywany równolegle z 04-02 (bench/historyczne move) i 04-03 (CONTRIBUTING §4). Pure additive: 1-linijkowa zmiana w Project.toml + 5 linii w .gitignore (3 reguły: komentarz + assets/* + !assets/demo.gif, plus 2 linijki komentarza).

## Tasks Completed

| Task | Name | Commit | Files |
| ---- | ---- | ------ | ----- |
| 1 | Dodaj BenchmarkTools do [targets].test w Project.toml | `4157359` | Project.toml |
| 2 | Dodaj DOKŁADNIE 2 reguły assets/* + !assets/demo.gif do .gitignore (D-05 EXACT) | `717260d` | .gitignore |

## Implementation Details

### Task 1: Project.toml [targets].test extension

**Diff:**
```diff
- test = ["Aqua", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
+ test = ["Aqua", "BenchmarkTools", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
```

**Resolver consistency:** BenchmarkTools już obecny w [extras] (linia 35: `BenchmarkTools = "6e4b80f9-..."`) i [compat] (linia 26: `BenchmarkTools = "1.6"`). Dodanie do [targets].test nie wymaga regeneracji Manifest.toml (resolver widzi spójny stan).

**Aqua interaction:** TEST-06 ma `project_extras = false` w `Aqua.test_all` config (udokumentowane w 02-08-SUMMARY.md), więc dodanie BenchmarkTools do test targets nie złapie się jako naruszenie `unbound_args` ani `stale_deps`.

**Limit `--project=.` resolver (D-10 documented):** Standalone `julia --project=. bench/run_all.jl` NIE załaduje BenchmarkTools — to znany limit Pkg.jl (test deps z [targets] widoczne tylko w `Pkg.test()` env). Workaround = `bench/uruchom.{sh,ps1}` (plan 04-06 Task 0) z `Pkg.activate(temp=true) + Pkg.develop(path=".") + Pkg.add("BenchmarkTools")`. D-10 (no separate `bench/Project.toml`) honored.

### Task 2: .gitignore Asset binaries section

**Diff:**
```diff
  # WAŻNE: Manifest.toml NIE jest tutaj — jest commitowany (per D-25, to jest aplikacja, nie biblioteka)
+
+ # Asset binaries (Phase 4 D-05) — commitujemy tylko canonical demo.gif,
+ # wszystkie inne lokalne artefakty developera (np. assets/test.mp4) ignorowane.
+ assets/*
+ !assets/demo.gif
```

**D-05 LOCKED EXACTLY enforced:**
- DOKŁADNIE 2 reguły: `assets/*` + `!assets/demo.gif`
- ZERO dodatkowych negacji (`!assets/.gitkeep`, `!assets/README.md` itp.)
- Kolejność: `assets/*` poprzedza `!assets/demo.gif` (Git pattern-by-pattern, last-match wins dla danego pliku)
- Komentarz polski z odwołaniem do D-05 (audit trail)

**Encoding hygiene (CONTRIBUTING.md §1):**
- Plik kończy się znakiem `\n` (LF, no BOM, NFC)
- 36 LF, 0 CRLF, no BOM — verified

**Asset directory creation:** Katalog `assets/` NIE jest tworzony w tym planie. `examples/eksport_mp4.jl` (plan 04-07) wykona `mkpath(dirname(SCIEZKA_GIF))` defensywnie przed pre-rm + `wizualizuj()`. Bez `.gitkeep` placeholder (D-05 LOCKED — żadne dodatkowe negacje).

## Verification Results

Plan `<verification>` block:

| Check | Command | Result |
|-------|---------|--------|
| V1 | `grep -E '"BenchmarkTools"' Project.toml \| grep -c 'test = '` | `1` ✓ |
| V2 | `grep -nE '^assets/\*$\|^!assets/' .gitignore` | `35:assets/*` + `36:!assets/demo.gif` (correct order) ✓ |
| V3 | `grep -cE '^!assets/' .gitignore` | `1` (D-05 EXACT) ✓ |

Functional gitignore verification:

| File | `git check-ignore` exit | Expected | Result |
|------|-------------------------|----------|--------|
| `assets/demo.gif` | 1 (NOT ignored) | NOT ignored (passthrough do repo) | ✓ |
| `assets/test.mp4` | 0 (ignored) | ignored (lokalny artefakt dev) | ✓ |

**Note on plan acceptance criterion phrasing:** Plan Task 2 acceptance criterion mówi „`git check-ignore -v assets/demo.gif` zwraca exit 1". W rzeczywistości `git check-ignore -v` exit semantics: 0 jeśli pattern dopasowany (włączając negację), 1 jeśli żaden pattern. Funkcjonalna kontrola (czy plik faktycznie ignorowany) jest sprawdzana przez `git check-ignore` bez `-v` — zwraca 1 dla `demo.gif` (= NOT ignored), 0 dla `test.mp4` (= ignored). Behavior is correct per D-05 intent. Drobna nieścisłość w opisie acceptance criterion, NIE blocker — nie tworzy deviation.

## Deviations from Plan

None — plan executed exactly as written. Auto-fixed Issues / Auto-added Functionality / Architectural Decisions: brak.

## Acceptance Criteria

### Task 1
- [x] Project.toml linia z `test = [` zawiera literalny string `"BenchmarkTools"`
- [x] Kolejność alfabetyczna zachowana: `"Aqua"` → `"BenchmarkTools"` → `"JET"` → ...
- [x] Sekcje [deps], [compat], [extras] niezmienione
- [-] `julia --project=. -e 'using Pkg; Pkg.test()'` smoke — opcjonalna, nie wykonana (worktree bez julia toolchain dostępnego per session)

### Task 2
- [x] `.gitignore` zawiera linię literalnie `assets/*` (bez wiodącego `/`)
- [x] `.gitignore` zawiera linię literalnie `!assets/demo.gif`
- [x] DOKŁADNIE JEDNA linia `^!assets/` (`grep -cE '^!assets/' .gitignore` = 1)
- [x] Pattern `assets/*` (linia 35) poprzedza `!assets/demo.gif` (linia 36)
- [x] Komentarz z D-05 obecny tuż przed regułami
- [x] `git check-ignore assets/demo.gif` exit 1 (NIE ignorowany — passthrough do repo)
- [x] `git check-ignore assets/test.mp4` exit 0 (ignorowany — lokalny artefakt nie wpada)

## Success Criteria

- [x] Project.toml [targets].test rozszerzona o BenchmarkTools (alfabetycznie)
- [x] .gitignore z 2 nowymi liniami reguł assets + 1 komentarz polski (D-05 EXACT — bez `.gitkeep`)
- [x] examples/eksport_mp4.jl (plan 04-07) odpowiada za utworzenie katalogu `assets/` przez `mkpath` przed eksportem (delegowane do downstream plan)

## Threat Model Assessment

Plan threats register:

| Threat ID | Disposition | Status | Notes |
|-----------|-------------|--------|-------|
| T-04-01-01 | accept | mitigated by design | Aqua TEST-06 `project_extras=false` udokumentowane w 02-08-SUMMARY.md |
| T-04-01-02 | accept | mitigated by design | `assets/*` chroni przed accidental commit (assets/secrets.png itp.) — ASVS L1 nie wymaga dodatkowej kontroli |

No new threat surface introduced. Config-only changes, no auth/network/input. No threat flags raised.

## Self-Check: PASSED

**Files modified (verified):**
- FOUND: Project.toml (BenchmarkTools w [targets].test, linia 44)
- FOUND: .gitignore (assets/* + !assets/demo.gif, linie 35-36)

**Commits exist (verified):**
- FOUND: `4157359` (feat(04-01): add BenchmarkTools to [targets].test in Project.toml)
- FOUND: `717260d` (feat(04-01): add assets/* + !assets/demo.gif to .gitignore (D-05 EXACT))

## Metrics

- Duration: ~5 min (estimated)
- Tasks: 2/2
- Files modified: 2
- Commits: 2 (per task) + 1 SUMMARY (final)
- Lines changed: +6/-1 (1 line Project.toml replacement; 5 lines .gitignore append)
- Deviations: 0
- Blockers: 0
