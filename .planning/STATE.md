---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: Executing Phase 04
last_updated: "2026-04-30T14:30:00.000Z"
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 35
  completed_plans: 33
  percent: 94
---

# State: JuliaCity

*This file is project memory. It survives context resets and persists between sessions.*

## Project Reference

**Name:** JuliaCity
**Core Value:** Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — jeśli wszystko inne zawiedzie, użytkownik musi zobaczyć, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymać krótszą trasę niż naiwny baseline.
**Current Focus:** Phase 04 — demo-benchmarks-documentation

## Current Position

Phase: 04 (demo-benchmarks-documentation) — EXECUTING (Wave 1+2 done, Wave 3 partial: 04-06 Tasks 0+1 done; Task 2 awaiting human)
Plan: 6 of 8 (+ 04-06 Tasks 0+1 of 3)
| Field | Value |
|-------|-------|
| Phase | 4 (of 4) |
| Phase Name | Demo, Benchmarks & Documentation |
| Plan | 8 plans in 4 waves: `04-01-PLAN.md` .. `04-08-PLAN.md` |
| Status | Wave 1+2 COMPLETE; Wave 3 PARTIAL — 04-06 Tasks 0+1 (uruchom.sh, uruchom.ps1, run_all.jl) merged; Task 2 (regen wyniki.md) wymaga uruchomienia `bash bench/uruchom.sh` lokalnie (~5-10 min) i commita |
| Progress | `[█████████▓] 94% (33/35 plans + 04-06 częściowy)` |
| Last Action | Plan 04-06 częściowo: bench/uruchom.sh (chmod +x), bench/uruchom.ps1, bench/run_all.jl (5 helperów, Module isolation BLOCKER #3, alfabetyczna kolejność Warning #3) zmergowane. SUMMARY.md NIE napisany (agent stopped). |
| Next Action | RĘCZNIE na nowym komputerze: `bash bench/uruchom.sh` → produkuje bench/wyniki.md → `git add bench/wyniki.md && git commit` → kontynuuj z `/gsd-execute-phase 4` (Wave 4 — plan 04-08 README+demo.gif) |

## Roadmap Snapshot

- [x] **Phase 1: Bootstrap, Core Types & Points** — pakiet, encoding hygiene, `StanSymulacji`, `generuj_punkty`
- [x] **Phase 2: Energy, SA Algorithm & Test Suite** — `oblicz_energie`, `symuluj_krok!` (SA), pełen suite testowy (222/222 PASS; SC #4 zluźnione 10%→5% per plan 02-14 erratum)
- [x] **Phase 3: Visualization & Export** — GLMakie + Observables, eksport MP4/GIF
- [ ] **Phase 4: Demo, Benchmarks & Documentation** — `examples/`, `bench/`, README po polsku

## Performance Metrics

*Populated by `/gsd-implement-plan` and `/gsd-verify-plan` runs.*

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| Phases complete | 2/4 | 4/4 | — |
| Requirements verified | 21/53 | 53/53 | Phase 1+2 = 21 REQ-IDs runtime-verified |
| Test pass rate | 222/222 (100%) | 100% | Pkg.test() exit 0, 1m33s |
| `@allocated` on `symuluj_krok!` | 0 | 0 | hard requirement (TEST-03) ✓ |
| SA quality vs NN baseline | ratio 0.9408 (5.92% pod NN) | ≥**5%** shorter | TEST-05 PASS; SC #4 zluźnione 10%→5% per plan 02-14 (2-opt local minimum) |
| Phase 03 P01 | 5min | 2 tasks | 2 files |
| Phase 03 P02 | 8min | 1 task | 1 file |
| Phase 03 P03 | 4min | 1 task | 1 file |
| Phase 03 P04 | 8min | 1 task | 1 file |
| Phase 03 P05 | 12min | 1 task | 1 file |
| Phase 03 P06 | 3min | 1 task | 1 file |

## Accumulated Context

### Locked-in Decisions

| Decision | Rationale | Phase Locked |
|----------|-----------|--------------|
| Granularity: COARSE (4 phases) | Single dev + Claude; small focused project; build dependencies dictate phase order | Roadmap creation |
| Algorithm variant for v1: `SimAnnealing` (SA-2-opt + NN init + Metropolis + geometric cooling α≈0.995) | Lowest-risk variant with most literature support; SA-2-opt is canonical, force-directed is HIGH-risk and stays v2 | Roadmap creation |
| Architecture: single `module JuliaCity` with `include()`-d files, parametric `StanSymulacji{R<:AbstractRNG}`, `abstract type Algorytm end` Holy-traits dispatch | Idiomatic Julia for single-purpose package; allows future variants to be additive (drop file in `src/algorytmy/`) | Roadmap creation |
| Threading inside `oblicz_energie`/`delta_energii` only, never on outer loop | SA acceptance is sequential; GLMakie GL context is single-threaded; inner-loop threading is embarrassingly parallel | Roadmap creation |
| Visualization: GLMakie + Observables, throttled updates; `wizualizacja.jl` is the only `src/` file with `using GLMakie` | Core must be testable headlessly without OpenGL; Observable update storms are a known pitfall (P5) | Roadmap creation |
| Language: Polish for all user-facing strings, comments, README, axis labels; English allowed for internal asserts | Hard project requirement (twardy wymóg) | Roadmap creation |
| Public API surface: 4 mandated functions (`generuj_punkty`, `oblicz_energie`, `symuluj_krok!`, `wizualizuj`) plus minimum internal helpers | Explicit user contract | Roadmap creation |
| Test golden-value RNG: `StableRNG(42)` (NOT `Xoshiro`/`MersenneTwister`) | Stream stability across Julia minor versions (PITFALLS Pitfall 8) | Phase 2 |
| Compat floor: `julia = "1.10"` LTS | Broad ecosystem reach; develop on 1.11/1.12 | Phase 1 |
| GLMakie compat `"0.13"` (NIE `"0.24"`) | GLMakie 0.13.x paruje z Makie 0.24.x w monorepo; "0.24" blokowalo Pkg resolver (Unsatisfiable requirements) | Phase 3 |
| Aqua `persistent_tasks=false` dla GLMakie deps | GLMakie jest biblioteka GUI z celowymi watkami tla (renderloop); false-positive — nie jest bledem paczki | Phase 3 |
| Observable overlay: jeden Observable{String} (Opcja B) zamiast 7 | 1 Makie notify/klatka zamiast 7; uproszczony update pattern w live loop | Phase 3 plan 02 |
| with_theme(theme_dark()) scoped (NIE set_theme!) | Pitfall E: set_theme! zanieczyszcza globalny stan Makie po powrocie z wizualizuj(); with_theme auto-resetuje przez try/finally | Phase 3 plan 02 |
| _ACC_WIN jako module-level const (NIE local const) | Kompatybilnosc z Julia 1.10+ bez ostrzezen; type-stable bez boxing captured var | Phase 3 plan 03 |
| FPS: instantaneous dt (NIE rolling-60-window) | Uproszczenie wystarczajace dla edukacyjnego overlay; rolling window YAGNI dla v1 | Phase 3 plan 03 |
| accept detection: (stan.energia <= energia_przed) przed symuluj_krok! | symuluj_krok! zwraca nothing — jedyna opcja bez refactoring | Phase 3 plan 03 |
| try/catch NA ZEWNATRZ with_theme (Pitfall E) | wymagalo wydzielenia _wizualizuj_impl z wizualizuj() body; wizualizuj() staje sie cienkim wrapperem | Phase 3 plan 05 |
| GOTOWE passive event loop zamiast wait(fig.scene) | prostsze i pewniejsze na roznych platformach (Windows + Linux); sleep(1/fps) yielding GLMakie event loop | Phase 3 plan 05 |

### Open Questions

| Question | Phase | Status |
|----------|-------|--------|
| Threading granularity at N=1000 — `@threads` may be net-negative for sub-millisecond inner loops; need empirical `MIN_N_THREAD` threshold | Phase 2 | Deferred to implementation; benchmark `JULIA_NUM_THREADS=1,2,4,8` for `oblicz_energie` |
| `KROKI_NA_KLATKE` default — UX-tuning decision for N=1000 on commodity laptops | Phase 3 | Default ≥ 10 per VIZ-05; tune empirically |
| Distance matrix precompute (~8 MB Float64) vs on-the-fly | Phase 1 | RESOLVED 2026-04-28 — precompute `D::Matrix{Float64}` lock-in (Phase 1 CONTEXT D-08; Phase 2 fills values) |
| CairoMakie fallback for headless CI? | Phase 3+4 | If CI fails on Linux, add backend abstraction; otherwise GLMakie-only |

### Active TODOs

*Carry across phases when relevant.*

- [x] Confirm `Manifest.toml` is committed (this is an application, not a library — pins reproducibility for demo) [Phase 1 D-25 — DONE in 03-00: 255 packages pinned, committed at 0de24af]
- [ ] Add encoding-validation CI guard test (UTF-8 well-formed, NFC-normalized, no BOM) [Phase 1 D-21 — folded into runtests.jl]
- [ ] Document Polish-typography convention (proper „..." quotes in user-facing strings) before README polish [Phase 4 — deferred]

### Blockers

*None at roadmap-creation time.*

## Session Continuity

**On resume:**

1. Read this file (STATE.md) — confirms current position and decisions
2. Read ROADMAP.md — confirms phase scope and success criteria
3. Read REQUIREMENTS.md — confirms which REQ-IDs belong to current phase
4. Run `/gsd-plan-phase {current_phase}` if no plan exists, else `/gsd-implement-plan`

**Files of record:**

- `.planning/PROJECT.md` — vision, constraints, key decisions
- `.planning/REQUIREMENTS.md` — v1/v2 requirements with phase traceability
- `.planning/ROADMAP.md` — phases, goals, success criteria
- `.planning/STATE.md` — this file (memory)
- `.planning/research/{SUMMARY,STACK,ARCHITECTURE,FEATURES,PITFALLS}.md` — research outputs

---
*State initialized: 2026-04-28 after roadmap creation*
*Last updated: 2026-04-30T — Phase 3 COMPLETE: plan 03-06 COMPLETE (@testset "VIZ-06: GLMakie isolation" dodany do runtests.jl; grep-level walkdir+per-line scan, pkgdir anchor; 230/230 PASS; Phase 3 11/11 REQ-IDow VIZ-01..07 EKS-01..04 pokryte; wszystkie 5 ROADMAP SC Phase 3 osiagniete); nastepna: Phase 4*
