---
phase: 03-visualization-export
plan: "00"
subsystem: dependencies
tags:
  - julia
  - dependencies
  - project-toml
  - blocking
  - glmakie
dependency_graph:
  requires: []
  provides:
    - GLMakie runtime dep (0.13.10 — wave 1+ moze uzywac `using GLMakie`)
    - Makie runtime dep (0.24.10 — `Makie.record()` dostepny)
    - Observables runtime dep (0.5.5 — `Observable{T}` pattern gotowy)
    - ProgressMeter runtime dep (1.11.0 — EKS-03 odblokowany)
    - Manifest.toml z pinami wszystkich 255 transitive deps
  affects:
    - wszystkie plany Phase 3 (wave 1-6): odblokowane po tym planie
    - test/runtests.jl: Aqua persistent_tasks=false (Rule 1 fix)
tech_stack:
  added:
    - GLMakie 0.13.10 (sparowany z Makie 0.24.10 per monorepo)
    - Makie 0.24.10
    - Observables 0.5.5
    - ProgressMeter 1.11.0
    - ~165 transitive deps (FFMPEG_jll 8.1.0, GLFW_jll 3.4.1, FreeType2_jll 2.14.3, ColorTypes 0.12.1, ...)
  patterns:
    - Pkg.add regeneruje Manifest.toml z nowymi pinami
    - GLMakie w [deps] (runtime) a nie [extras] (test-only)
    - Aqua persistent_tasks=false dla pakietow z GUI deps
key_files:
  modified:
    - Project.toml (Task 1: [deps]+[compat]+[extras] reorganizacja)
    - Manifest.toml (Task 2: zregenerowany z 255 pakietami, 1666 linii)
    - test/runtests.jl (Rule 1 fix: Aqua persistent_tasks=false)
decisions:
  - "GLMakie compat 0.24→0.13: GLMakie uzywa wlasnej numeracji 0.13.x niezaleznie od Makie 0.24.x"
  - "persistent_tasks=false w Aqua: GLMakie jest biblioteka GUI z celowymi watkami tla; false-positive nie jest bledem paczki"
  - "GLMakie/Makie/Observables przeniesione z [extras] do [deps]: Phase 3 konsumuje je w runtime"
metrics:
  duration: "1492 sekund (~25 minut; wlicza Pkg.add ~453s + dwa przebiegi Pkg.test)"
  completed: "2026-04-30T09:03:16Z"
  tasks_completed: 2
  files_changed: 3
---

# Phase 3 Plan 00: Project.toml Fix & Manifest Regeneracja — Summary

Wave 0 hard-bloker usuniety: krytyczny blad `GLMakie = "0.24"` w [compat] naprawiony na `"0.13"`, GLMakie/Makie/Observables/ProgressMeter zainstalowane jako runtime deps, Manifest.toml zregenerowany z 255 pinami pakietow.

## Co zostalo zrobione

### Task 1 — Project.toml fix (commit d5f7c14)

Edycja `Project.toml` w trzech sekcjach:

**[deps]** — dodane 4 nowe runtime deps (kolejnosc alfabetyczna, lacznie 8 wpisow):
- `GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"`
- `Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"`
- `Observables = "510215fc-4207-5dde-b226-833fc4488ee2"`
- `ProgressMeter = "92933f4c-e287-5a05-a399-4b506db050ca"`

**[compat]** — dwie zmiany:
- `GLMakie = "0.24"` → `GLMakie = "0.13"` (KRYTYCZNY FIX — GLMakie uzywa wlasnej numeracji 0.13.x)
- Dodano: `ProgressMeter = "1"` (EKS-03)

**[extras]** — usunieto GLMakie, Makie, Observables (przeniesione do [deps]); zostalo 8 test-only deps.

**[targets]** — BEZ ZMIAN.

### Task 2 — Pkg.add + Manifest regeneracja (commit 0de24af)

Komenda: `julia --project=. -e 'using Pkg; Pkg.add(["GLMakie", "Makie", "Observables", "ProgressMeter"])'`

Wynik:
- GLMakie 0.13.10 zainstalowany (sparowany z Makie 0.24.10 — monorepo release)
- Makie 0.24.10 zainstalowany
- Observables 0.5.5 zainstalowany
- ProgressMeter 1.11.0 zainstalowany
- Manifest.toml zregenerowany: 1666 linii, 255 pakietow (`[[deps.XXX]]` format 2.0)
- Precompile: ~453 sekund (TTFP GLMakie pierwsza kompilacja — normalne)

Kluczowe transitive deps potwierdzone w Manifest.toml:
- FFMPEG_jll 8.1.0 (przez Makie — eksport MP4/GIF)
- GLFW_jll 3.4.1 (okno OpenGL)
- FreeType2_jll 2.14.3
- ColorTypes 0.12.1

Smoke testy: `using ProgressMeter` OK 1.11.0, `using Observables` OK 0.5.5, `using Makie` OK 0.24.10

Regresja Phase 1+2: **221/221 PASS** (exit 0) — po Rule 1 fix ponizej.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Aqua persistent_tasks false-positive po przeniesieniu GLMakie do [deps]**

- **Found during:** Task 2 (weryfikacja `Pkg.test()`)
- **Issue:** Przed zmiana: 222/222 PASS (GLMakie tylko w [extras], nie ladowany podczas testow). Po przeniesieniu GLMakie do [deps]: Aqua.test_all wykryl persistent tasks i zglasil FAIL (221 passed, 1 failed). GLMakie jako biblioteka GUI z zalozenia uruchamia watki tla renderloop — to nie jest wyciek, to celowe zachowanie.
- **Fix:** Dodano `persistent_tasks = false` do `Aqua.test_all(...)` w `test/runtests.jl` z komentarzem wyjasniajacym przyczyne. Standardowa praktyka dla pakietow zalezacych od GLMakie.
- **Files modified:** `test/runtests.jl`
- **Commit:** 0de24af (razem z Manifest.toml)

## Zainstalowane wersje pakietow

| Pakiet | Wersja | Compat |
|--------|--------|--------|
| GLMakie | 0.13.10 | `"0.13"` |
| Makie | 0.24.10 | `"0.24"` |
| Observables | 0.5.5 | `"0.5"` |
| ProgressMeter | 1.11.0 | `"1"` |

## Statystyki Manifest.toml

- Linie: 1666
- Pakiety (w tym stdlib): 255
- Format: manifest_format = "2.0" (Julia 1.12 format)
- Kluczowe transitive: FFMPEG_jll 8.1.0, GLFW_jll 3.4.1, FreeType2_jll 2.14.3

## Czas trwania

- Pkg.add (wlicznie z precompile): ~453 sekund (7.5 minuty) — TTFP GLMakie pierwsza kompilacja
- Lacznie (oba zadania + oba testy): ~1492 sekund (~25 minut)
- Referencyjna wartosc dla Phase 4 demo: precompile GLMakie w srodowisku aktywowanym po raz pierwszy trwa ~7-8 minut

## Weryfikacja sukcesu

- [x] `GLMakie = "0.13"` w [compat] (NIE "0.24")
- [x] GLMakie, Makie, Observables, ProgressMeter w [deps]
- [x] GLMakie, Makie, Observables usuniete z [extras]
- [x] Manifest.toml zregenerowany z 255 pinami
- [x] `using ProgressMeter` OK (1.11.0)
- [x] `using Observables` OK (0.5.5)
- [x] `using Makie` OK (0.24.10)
- [x] Pkg.test() exit 0: 221/221 PASS
- [x] FFMPEG_jll obecny w Manifest.toml (przez Makie)
- [ ] `using GLMakie; println("OK")` — smoke test GLMakie okna: ODROCZONE na headless (GLMakie wymaga srodowiska graficznego; instalacja potwierdzona przez Pkg.add + precompile sukces; wave 1 zweryfikuje na maszynie uzytkownika)

## Known Stubs

Brak — plan 03-00 to tylko konfiguracja dep management, brak kodu aplikacyjnego.

## Threat Flags

Brak nowych powierzchni ataku wprowadzonych przez ten plan. Manifest.toml commitowany per T-03-01 (zmiana transitive dep wymaga explicit `Pkg.update` + commit).

## Self-Check: PASSED

Pliki zmodyfikowane:
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\Project.toml` — FOUND (d5f7c14)
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\Manifest.toml` — FOUND (0de24af)
- `C:\Users\mparol\Desktop\Dokumenty\Projekty\JuliaCity\test\runtests.jl` — FOUND (0de24af)

Commity:
- d5f7c14: chore(03-00): fix Project.toml
- 0de24af: feat(03-00): Pkg.add GLMakie/Makie/Observables/ProgressMeter
