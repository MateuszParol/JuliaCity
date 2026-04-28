---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: unknown
last_updated: "2026-04-28T15:29:28.496Z"
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 6
  completed_plans: 0
  percent: 0
---

# State: JuliaCity

*This file is project memory. It survives context resets and persists between sessions.*

## Project Reference

**Name:** JuliaCity
**Core Value:** Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii — jeśli wszystko inne zawiedzie, użytkownik musi zobaczyć, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymać krótszą trasę niż naiwny baseline.
**Current Focus:** Phase 01 — bootstrap-core-types-points

## Current Position

Phase: 01 (bootstrap-core-types-points) — EXECUTING
Plan: 1 of 6
| Field | Value |
|-------|-------|
| Phase | 1 (of 4) |
| Phase Name | Bootstrap, Core Types & Points |
| Plan | 6 plans in 6 waves (`.planning/phases/01-bootstrap-core-types-points/01-{01..06}-PLAN.md`) |
| Status | Ready to execute |
| Progress | `[░░░░░░░░░░░░░░░░░░░░] 0% (0/4 phases complete)` |
| Last Action | Phase 1 plans created and verified (25/25 decisions, 10/10 REQ-IDs covered) |
| Next Action | `/gsd-execute-phase 1` (Wave 1 = juliaup install checkpoint, `autonomous: false`) |

## Roadmap Snapshot

- [ ] **Phase 1: Bootstrap, Core Types & Points** — pakiet, encoding hygiene, `StanSymulacji`, `generuj_punkty`
- [ ] **Phase 2: Energy, SA Algorithm & Test Suite** — `oblicz_energie`, `symuluj_krok!` (SA), pełen suite testowy
- [ ] **Phase 3: Visualization & Export** — GLMakie + Observables, eksport MP4/GIF
- [ ] **Phase 4: Demo, Benchmarks & Documentation** — `examples/`, `bench/`, README po polsku

## Performance Metrics

*Populated by `/gsd-implement-plan` and `/gsd-verify-plan` runs.*

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| Phases complete | 0/4 | 4/4 | — |
| Requirements verified | 0/53 | 53/53 | — |
| Test pass rate | n/a | 100% | suite jeszcze nie istnieje |
| `@allocated` on `symuluj_krok!` | n/a | 0 | hard requirement (TEST-03) |
| SA quality vs NN baseline | n/a | ≥10% shorter | hard requirement (TEST-05) |

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

### Open Questions

| Question | Phase | Status |
|----------|-------|--------|
| Threading granularity at N=1000 — `@threads` may be net-negative for sub-millisecond inner loops; need empirical `MIN_N_THREAD` threshold | Phase 2 | Deferred to implementation; benchmark `JULIA_NUM_THREADS=1,2,4,8` for `oblicz_energie` |
| `KROKI_NA_KLATKE` default — UX-tuning decision for N=1000 on commodity laptops | Phase 3 | Default ≥ 10 per VIZ-05; tune empirically |
| Distance matrix precompute (~8 MB Float64) vs on-the-fly | Phase 1 | RESOLVED 2026-04-28 — precompute `D::Matrix{Float64}` lock-in (Phase 1 CONTEXT D-08; Phase 2 fills values) |
| CairoMakie fallback for headless CI? | Phase 3+4 | If CI fails on Linux, add backend abstraction; otherwise GLMakie-only |

### Active TODOs

*Carry across phases when relevant.*

- [ ] Confirm `Manifest.toml` is committed (this is an application, not a library — pins reproducibility for demo) [Phase 1 D-25 — verify after execute]
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
*Last updated: 2026-04-28 after Phase 1 context discussion*
