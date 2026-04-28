# Pitfalls Research

**Domain:** Idiomatic Julia package — physics-inspired TSP heuristic with GLMakie animation, Polish-language UI, N=1000 points
**Researched:** 2026-04-28
**Confidence:** HIGH for Julia/GLMakie/Aqua mechanics, MEDIUM for SA-cooling specifics and threading thresholds (depend on hardware), HIGH for Polish-Unicode source-code aspects

This document is opinionated and project-specific. Generic advice ("write tests", "profile first") is excluded — every entry is a concrete failure mode the JuliaCity team will hit if not preempted, with detection signals, prevention code, and a roadmap-phase mapping.

---

## Critical Pitfalls

### Pitfall 1: Type-instability sneaking into `symuluj_krok!()` via field access on abstractly-typed struct

**What goes wrong:**
The hot-loop function `symuluj_krok!(stan, ...)` takes a `Stan` struct. If `Stan` has fields like `trasa::Vector` (no element type) or `temperatura::Real` (abstract), Julia cannot specialize. Every read of a field returns `Any`, every arithmetic op dispatches dynamically, and the loop allocates one boxed result per operation. A 1000-point inner loop becomes ~1000× slower than necessary, and the @threads version actively hurts because contention is added on top of dynamic dispatch.

**Why it happens:**
Developers write `mutable struct Stan; trasa; temperatura; energia; end` for quick prototyping, intending to "type it later". The code runs correctly, tests pass, only profiling reveals the disaster. Polish-language field names (`trasa`, `temperatura`) make grep-for-`::` checks easier to skip because reviewers focus on naming.

**How to avoid:**
- Define `Stan` as a *concrete-typed*, parametric struct from day one:
  ```julia
  struct Stan{T<:AbstractFloat, I<:Integer}
      trasa::Vector{I}                 # permutacja indeksów punktów
      punkty::Matrix{T}                # 2 × N
      temperatura::Base.RefValue{T}    # mutable scalar without `mutable struct`
      energia::Base.RefValue{T}
  end
  ```
- Avoid `mutable struct` for hot-path containers; use `Ref` or pre-sized buffers for the few mutable scalars.
- Add a test: `@test_opt symuluj_krok!(stan)` (JET.jl) AND `@test (@allocated symuluj_krok!(stan)) == 0` after warm-up.
- Run `@code_warntype symuluj_krok!(stan, ...)` in REPL — any red `Any`/`Union` annotation is a fail.

**Warning signs:**
- `@btime` shows non-zero `allocs estimate` for an in-place `!` function operating on existing buffers.
- Profile flame graph shows time inside `jl_apply_generic` / `jl_invoke`.
- Adding more threads makes the function *slower*, not faster.

**Phase to address:**
**Phase 2 (core data structures)** — define `Stan` correctly before any algorithm code is written. Phase 5 (test suite) adds the JET / `@allocated` regression tests.

---

### Pitfall 2: Closure capture in `Threads.@threads` boxes the loop variable, killing performance and risking races

**What goes wrong:**
A natural way to write parallel 2-opt move evaluation is:
```julia
najlepszy_zysk = 0.0
najlepsze_i, najlepsze_j = 0, 0
Threads.@threads for i in 1:N-1
    for j in i+2:N
        zysk = oblicz_zysk(trasa, i, j)
        if zysk > najlepszy_zysk
            najlepszy_zysk = zysk     # captured + reassigned → BOXED
            najlepsze_i, najlepsze_j = i, j
        end
    end
end
```
Three failures occur simultaneously: (1) `najlepszy_zysk` is captured as `Core.Box`, type becomes `Any`, every comparison dispatches dynamically (~100× slowdown reported in JuliaLang/julia#15276); (2) the unsynchronised write is a data race, producing nondeterministic best-move choices; (3) `@threads` overhead (a few µs per dispatch — discourse 53964) makes the slow result *also* nondeterministic across runs. Tests pass occasionally and fail occasionally, masking the bug as "flaky".

**Why it happens:**
- Idiom from single-threaded code transferred mechanically.
- Boxing is invisible without `@code_warntype` — function returns correct types externally.
- Polish identifier names look the same as the working sequential version, so reviewers miss the threading-correctness implication.

**How to avoid:**
- Per-thread accumulators in a pre-sized vector, reduced afterwards:
  ```julia
  zyski = zeros(T, Threads.nthreads())
  pary  = [(0, 0) for _ in 1:Threads.nthreads()]
  Threads.@threads for i in 1:N-1
      tid = Threads.threadid()         # OK for storage indexing only
      for j in i+2:N
          z = oblicz_zysk(trasa, i, j)
          if z > zyski[tid]
              zyski[tid] = z
              pary[tid]  = (i, j)
          end
      end
  end
  najlepszy = argmax(zyski)
  ```
  CAVEAT: `Threads.threadid()` is *not* stable for migration in nightly Julia >=1.12; if/when JuliaCity targets 1.12+, switch to `OhMyThreads.jl`'s `tmapreduce` or `ChunkSplitters.chunks` (chunk index is stable and each chunk gets its own buffer).
- For Julia 1.11 (current LTS-track), `threadid` storage is acceptable but document the assumption.
- Wrap any genuinely closure-capturing parallel block with `FastClosures.@closure`.

**Warning signs:**
- `@code_warntype` on the enclosing function shows `Core.Box` next to the captured variable name.
- Two runs with the same seed and `nthreads=4` produce different "best move" — clear race signature.
- `@btime` with `nthreads=1` is faster than with `nthreads=8`.

**Phase to address:**
**Phase 4 (parallelization)** — the parallel 2-opt loop is the canonical site. Add a determinism test in Phase 5: same seed + same `nthreads` → identical final tour.

---

### Pitfall 3: Sharing one RNG across threads → silent corruption, non-reproducible output, occasional segfaults

**What goes wrong:**
SA acceptance and proposal generation need many random numbers per step. If the team writes `rng = MersenneTwister(seed)` at top level and passes it into a parallel block, all threads call `rand!(rng, ...)` on the *same* generator state. MersenneTwister's state-update is not atomic; concurrent updates produce duplicate streams (broken acceptance probabilities), corrupted state (NaN later), or in extreme cases unsafe pointer mutation. The default global RNG (`Random.default_rng()`) is `TaskLocalRNG` and *is* thread-safe per Julia 1.3+, but a manually constructed `MersenneTwister`/`Xoshiro256++` is not.

**Why it happens:**
- Reproducibility requirement in PROJECT.md (`seed=42` default) pushes developers to construct an RNG manually.
- Discourse posts pre-1.3 and tutorials still recommend `MersenneTwister(seed)`.
- The "fast Xoshiro" advice is misread — `Xoshiro` *type* is fine, but each *instance* still has shared state.

**How to avoid:**
- Allocate one RNG per chunk/thread, derived from a master seed:
  ```julia
  using Random
  function buduj_rngi(seed::Integer, n::Integer)
      master = Xoshiro(seed)
      return [Xoshiro(rand(master, UInt64), rand(master, UInt64),
                      rand(master, UInt64), rand(master, UInt64)) for _ in 1:n]
  end
  rngi = buduj_rngi(42, Threads.nthreads())
  Threads.@threads for tid in 1:Threads.nthreads()
      rng = rngi[tid]
      # ... use rng locally only
  end
  ```
- For tests, use `StableRNGs.StableRNG(seed)` — its stream is guaranteed stable across Julia versions, so test golden values do not break on Julia upgrades.
- Never call `rand()` (no rng arg) inside `@threads` if reproducibility is required: `TaskLocalRNG`'s thread-safety is preserved but the *order* of consumption is not deterministic across thread schedules.

**Warning signs:**
- Same seed, same `nthreads` → different tour energies between runs.
- NaN appearing in `temperatura` or `energia` after long runs.
- Test that runs `simulate(seed=42)` twice and asserts equality fails on CI but not locally.

**Phase to address:**
**Phase 3 (SA / acceptance machinery)** — RNG plumbing is part of `symuluj_krok!`'s signature. Phase 5 adds the seed-determinism test.

---

### Pitfall 4: Force-directed updates break the Hamilton-cycle invariant

**What goes wrong:**
The "soap bubble" metaphor invites moving point *coordinates* under spring forces. But TSP requires a permutation `trasa::Vector{Int}` over fixed point coordinates — a Hamilton cycle. If forces are applied to coordinates while edges are also evaluated by index, the algorithm wanders into a meaningless space ("points moved, no longer the original problem"). If forces are applied to permutation indices, the permutation can develop duplicates ("vertex 5 appears twice, vertex 8 missing"), making the tour invalid. The visualization continues to render — colorful, animated, wrong.

**Why it happens:**
- The physical analogy (membrane minimization) operates on continuous geometry; TSP is combinatorial.
- The user-facing function name is `oblicz_energie()` — the same word for both "spring potential" and "tour length", encouraging conceptual conflation.
- A broken tour can still be shorter on average than a correct one if vertices are duplicated cheaply.

**How to avoid:**
- Pick *one* representation and document it loudly:
  - **Recommended:** SA over permutations with 2-opt/3-opt as the move set; "soap bubble" is a *cosmetic* visualization (interpolated edge curvature toward minimum-length straight lines as the tour cools), not a literal force model.
  - If a literal force model is chosen, define edges as virtual constraints maintaining cyclic-order, and apply forces only to a separate "rendered_position" matrix — the *original* coordinates and *index* permutation are immutable.
- Add a hard invariant check in every step (debug build):
  ```julia
  function sprawdz_cykl(trasa::Vector{Int}, n::Int)
      length(trasa) == n || error("Trasa ma niepoprawną długość")
      sort(trasa) == 1:n || error("Trasa nie jest permutacją 1:$n")
      return true
  end
  ```
  Run unconditionally in tests; gate with `@boundscheck` for production.
- Define `oblicz_energie(trasa, punkty)` and `oblicz_potencjał(rendered_pos)` as *two separate functions* with distinct names.

**Warning signs:**
- Final reported tour length is *better* than the global optimum (Concorde / Held-Karp lower bound for the seed) — impossible if the tour is valid.
- `unique(trasa)` length differs from N.
- Visualization shows a vertex with two incoming or two outgoing edges.

**Phase to address:**
**Phase 1 (algorithm research/decision)** — pick the representation. **Phase 2** — encode invariant checks. **Phase 5** — invariant must be in `runtests.jl`, not just `examples/`.

---

### Pitfall 5: GLMakie Observable update storms — animation runs faster than render, frames are dropped or queued indefinitely

**What goes wrong:**
A natural pattern: the simulation runs `symuluj_krok!` in a loop and after every step does `obs_trasa[] = nowa_trasa`. Each assignment synchronously triggers all listeners (Makie attribute pipelines, axis updates, render dirty flags). At N=1000 with many steps per second, the renderer cannot keep up; either the main thread becomes unresponsive (no zoom/pan), the GPU queue fills and stalls, or — for in-place `[] .=` updates — listeners do not fire at all and the screen freezes while the simulation appears to progress.

**Why it happens:**
- Observables are synchronous: every `obs[] = x` runs all callbacks before returning. Makie 0.21 docs explicitly call this out.
- In-place `obs[] .= x` does *not* trigger listeners; you must call `notify(obs)` manually — easy to forget.
- The natural mental model is "update the data, the view will catch up", which Observables violate.

**How to avoid:**
- Throttle simulation-to-render coupling: simulate K steps, then update observables once.
  ```julia
  const KROKI_NA_KLATKE = 50
  for klatka in 1:liczba_klatek
      for _ in 1:KROKI_NA_KLATKE
          symuluj_krok!(stan, rng)
      end
      obs_trasa[] = stan.trasa          # one notify per frame
      yield()                           # let Makie's renderloop process
  end
  ```
- For multi-attribute updates, use Makie 0.24+ `Makie.update!(plot, attr1=v1, attr2=v2)` — single batched compute-graph update.
- Use Makie's `Events.tick` observable to drive simulation from the renderloop, not the other way around — guarantees the render is ready for each frame.
- For long batches, mutate `.val` (no notify) and call `notify(obs)` once at the end.

**Warning signs:**
- Window title bar shows "Not Responding" (Windows) during simulation.
- Frame counter (your own counter) advances much faster than visually observable changes.
- CPU at 100% on one core, GPU at 0%.

**Phase to address:**
**Phase 6 (visualization)** — design the simulation/render coupling explicitly with `KROKI_NA_KLATKE` as a tunable parameter, not as an afterthought.

---

### Pitfall 6: `Makie.record(...)` blocks the REPL/main thread; users assume it crashed

**What goes wrong:**
`record(fig, "anim.mp4", 1:N) do i; ...; end` runs synchronously, encoding frame-by-frame via FFmpeg. For N=1000 simulation frames, this can take minutes. During recording, the GLMakie window may show only the *last* frame or be unresponsive; the REPL produces no output until done. New users abort with Ctrl-C and conclude the export is broken.

**Why it happens:**
- `record` is a function call, not a background task.
- No progress indicator by default.
- The visualization-during-recording is implementation-defined (depends on backend / OS / driver).

**How to avoid:**
- Always wrap with a `ProgressMeter.@showprogress`:
  ```julia
  using ProgressMeter
  prog = Progress(liczba_klatek; desc="Eksportuję MP4...")
  Makie.record(fig, sciezka, 1:liczba_klatek; framerate=30) do i
      symuluj_klatke!(stan, i)
      next!(prog)
  end
  ```
- Provide a separate `eksportuj_mp4()` function distinct from `wizualizuj()` (live) — the user explicitly opts into the blocking call.
- Document on first line of docstring: "Funkcja blokująca; używaj w skryptach, nie w pętli REPL z otwartym oknem."
- Always test the export path in CI on a small N (e.g., N=50, 30 frames) — catches FFmpeg/codec breakage early.

**Warning signs:**
- Issues filed about "export hangs" — almost certainly normal blocking + no progress UI.
- File size grows during export but no user-visible feedback.

**Phase to address:**
**Phase 7 (export)** — implement progress indicator and dedicated function before shipping.

---

### Pitfall 7: GLMakie does not run on headless CI / WSL without explicit setup; tests silently skipped or hang

**What goes wrong:**
Adding `using GLMakie` to `test/runtests.jl` causes one of: (a) the test runner segfaults on Linux CI without an X server, (b) Pkg installs but `using GLMakie` errors with "no display", (c) on Windows GitHub Actions runners, the OpenGL context creation hangs (issue #49743), (d) on WSL, intermittent libGL version mismatch. The team reacts by `try/catch`-ing the `using` and skipping all visualization tests, which means the visualization is never tested — a "looks done but isn't" failure.

**Why it happens:**
- GLMakie requires a real OpenGL context; CairoMakie does not.
- WSL OpenGL is unsupported by Makie team.
- Package extension boundaries make it hard to use a different backend in tests vs. runtime.

**How to avoid:**
- Split visualization API behind `Makie.AbstractPlotting` / use the backend-agnostic `Makie` API in `src/`.
- In `test/runtests.jl`, use `CairoMakie` (pure software, headless-compatible) for visual smoke tests:
  ```julia
  if get(ENV, "CI", "false") == "true"
      using CairoMakie
  else
      using GLMakie
  end
  ```
- For the GLMakie path on Linux CI, install `xvfb` and run `xvfb-run julia ...`. The official Makie CI workflow (`.github/workflows/glmakie.yaml`) is the authoritative reference.
- Test the export-to-MP4 path with CairoMakie + ffmpeg: produces a valid MP4 deterministically without GPU.
- Document in README: "Pakiet wymaga OpenGL; na WSL/headless CI używaj CairoMakie jako backend zastępczy."

**Warning signs:**
- CI passes but `test/runtests.jl` contains `try; using GLMakie; catch; @warn "Skipping"; end`.
- Local dev works on Windows host; fails on WSL or Linux dev container.

**Phase to address:**
**Phase 5 (test infrastructure)** AND **Phase 6 (visualization)** — backend abstraction must be in place before visualization code is written.

---

### Pitfall 8: `MersenneTwister`-style seed → user expectations of "exact reproducibility" break across Julia versions

**What goes wrong:**
The PROJECT decision says `seed=42` for determinism. Tests assert `oblicz_energie(symuluj(seed=42)) ≈ 12345.67`. On Julia upgrade (e.g., 1.10 → 1.11 changed `Xoshiro` initialization, 1.13 may again), the golden value changes by 0.001, tests fail, no algorithmic regression occurred. CI flips red, team wastes an afternoon.

**Why it happens:**
Stdlib `Random` does not guarantee stream stability across Julia minor versions; the docs say so but the warning is buried.

**How to avoid:**
- For *internal* algorithm reproducibility within a single run, use whatever RNG. For tests with golden values, use `StableRNGs.StableRNG(42)`. It guarantees the same stream forever.
- Test on *tour validity and energy bound* (`@test oblicz_energie(t) < energia_baseline`) rather than exact-equality of energy, except for the smallest fixture (e.g., N=10) where exact comparison is safe.
- Keep one "fingerprint" test with `StableRNG` that asserts an exact tour for a tiny instance — useful regression sentinel.

**Warning signs:**
- After `Pkg.update()`, only the determinism-related tests fail.
- Test diff shows a tiny numerical delta in tour length.

**Phase to address:**
**Phase 5 (testing)** — pick `StableRNG` for golden-value tests upfront. Document in test file.

---

### Pitfall 9: Polish-language identifiers and source files — encoding pitfalls on Windows

**What goes wrong:**
Polish identifiers like `oblicz_energię`, `temperatura_początkowa`, `współczynnik_chłodzenia` are *legal* Julia identifiers (Julia 1.x supports the full Unicode L\* category, NFC-normalised). The mistakes are at the toolchain edges:
1. Source file saved as Windows-1250 ("ANSI" in Notepad) instead of UTF-8 → Julia errors `invalid character` at parse time, confusing because it's the *file*, not the code.
2. UTF-8 *with BOM* (Notepad's "UTF-8" option) — Julia 1.x accepts a leading BOM but some tools (git-blame, ripgrep, some editors' linters) treat it as content. Inconsistent BOMs across files cause spurious diffs.
3. File names with Polish characters (e.g., `wizualizacja_ścieżki.jl`) work in `include()` on modern Windows, but break on older Linux containers with `LANG=C` locale and on some CI artifact uploaders.
4. Mixed normalization: `é` typed as composed (U+00E9, NFC) vs. decomposed (`e` + U+0301, NFD). Julia normalizes identifiers to NFC, but *strings* (e.g., GUI labels) are not normalized — `"Średnia" == "Średnia"` may be `false` if entered differently.

**Why it happens:**
- Notepad and older Windows tooling default to Windows-1250 for Polish locale.
- Git on Windows may auto-CRLF, but does not auto-fix encoding.
- IDE tooling differs (VS Code defaults to UTF-8 no BOM; Notepad++ defaults to ANSI on Polish Windows).

**How to avoid:**
- Add to repo root:
  - `.editorconfig`:
    ```
    root = true
    [*]
    charset = utf-8
    end_of_line = lf
    insert_final_newline = true
    indent_style = space
    indent_size = 4
    ```
  - `.gitattributes`:
    ```
    *.jl text working-tree-encoding=UTF-8 eol=lf
    *.toml text eol=lf
    ```
- Avoid BOMs explicitly: configure VS Code `"files.encoding": "utf8"` (not `utf8bom`).
- Do *not* put Polish diacritics in file names — keep file names ASCII (`wizualizacja_sciezki.jl`), put Polish only inside the file (comments, identifiers, strings). This is purely defensive against Linux/CI tooling; modern Windows handles it fine, but the project should run on GitHub Actions Linux runners.
- Add a CI guard:
  ```julia
  for f in readdir("src/"; join=true)
      content = read(f, String)
      @test !startswith(content, "﻿") || error("BOM w pliku $f")
      @test isvalid(content)             # UTF-8 well-formed
      @test Unicode.normalize(content, :NFC) == content
  end
  ```
- For runtime-comparison strings (e.g., parsing user input), normalize: `Unicode.normalize(s, :NFC)`.

**Warning signs:**
- Julia parser error like `invalid UTF-8 sequence` on a file that *looks* fine in the editor.
- Git diff shows an entire file as changed after only adding one Polish character.
- Test passes locally on Windows, fails on Linux CI with "file not found".

**Phase to address:**
**Phase 0 (project bootstrap)** — `.editorconfig`, `.gitattributes`, ASCII file names policy. Phase 5 — encoding-validation test.

---

## Moderate Pitfalls

### Pitfall 10: Distance matrix decision — precompute (~8 MB at N=1000, Float64) vs. on-the-fly

**What goes wrong:**
Recomputing `√((x_i-x_j)² + (y_i-y_j)²)` inside every 2-opt evaluation is fast (4 FLOPs + sqrt), but inside a billion-comparison SA run it dominates. Conversely, precomputing a 1000×1000 matrix consumes 8 MB (Float64) or 4 MB (Float32) — fits in L2 on modern CPUs but contends with point coordinates, RNG state, threading buffers. False-sharing risk: if multiple threads scan rows of the matrix simultaneously and write per-thread results to a small shared `gains` array, the small array thrashes; the matrix itself is read-only and safe.

**Why it happens:**
Premature decision before benchmarking either path.

**How to avoid:**
- For N=1000: **precompute** the matrix. 8 MB is trivial; ~10⁶ entries computed once at startup. Use Float64 for accuracy in 2-opt-gain comparisons (Float32 differences of nearby tours can flip sign incorrectly under noise of the last bit).
- Squared distances suffice for *comparisons* in 2-opt gain; defer `sqrt` until reporting energy. Saves the sqrt in the hot path entirely. CAVEAT: if the algorithm uses *additive* potentials (force-directed), squared cannot substitute — `sqrt` is required.
- Lay out as `Matrix{Float64}` (column-major); access by `D[i, j]` with `i` as inner loop index for cache locality.

**Warning signs:**
- Profile shows `sqrt` / `Base.power_by_squaring` as top hotspot.
- L2 cache miss rate from `perf stat` over 50% on the inner loop.

**Phase to address:**
**Phase 2 (data structures)** — decide upfront. **Phase 5** — benchmark both variants, lock in the winner.

---

### Pitfall 11: Cooling schedule mistakes — "geometric with α=0.99" sounds reasonable, often is not

**What goes wrong:**
- α too high (0.999): SA never effectively cools at the budget, tour stays random.
- α too low (0.9): SA freezes early in a poor local optimum, indistinguishable from greedy 2-opt.
- Initial T not calibrated to the problem: T₀ = 1.0 might accept everything (effectively random walk) or nothing (immediate freeze) depending on the energy scale. For N=1000 random uniform points in [0,1]², typical 2-opt gain magnitudes are ~0.01 to ~0.5 — T₀ should bracket the upper end of realistic *worsening* moves, e.g., T₀ ≈ 0.5–1.0 with energy in those units.
- "Adaptive" schedules sound smart; in practice list-based and Lundy-Mees often outperform geometric, but with extra hyperparameters that are easy to mistune.

**Why it happens:**
Cooling-schedule literature is large; defaults from textbooks are problem-agnostic.

**How to avoid:**
- Calibrate T₀ at startup: sample 1000 random 2-opt moves on the initial tour, take the standard deviation of `ΔE` of *worsening* moves only, set `T₀ = 2 × σ_ΔE`. Empirically chosen acceptance ratio at start ~80%.
- Use geometric cooling with α tuned so that `α^liczba_krokow = T_min/T₀` where `T_min ≈ 0.001 × T₀`. For 100k steps, this gives α ≈ 0.99993.
- Track and log the acceptance ratio per 1000 steps; healthy SA decays from ~80% to ~1% smoothly. A flat or jumpy curve is a misconfiguration.
- Consider list-based scheduling (Zhan et al. 2016) only after geometric is benchmarked.

**Warning signs:**
- Final tour energy varies wildly across seeds (>20% range) — under-cooled.
- Final tour energy identical to greedy 2-opt — over-cooled / SA has no effect.
- Acceptance ratio flat near 0% or 100%.

**Phase to address:**
**Phase 3 (SA tuning)** — calibration + acceptance-ratio logging are part of the algorithm, not optional UI.

---

### Pitfall 12: `@threads` on the outer 2-opt loop is slower for N=1000 than the sequential version

**What goes wrong:**
`Threads.@threads` overhead is several microseconds per dispatch. The outer loop in 2-opt is N-1 ≈ 999 iterations; the inner loop is variable size. If the team applies `@threads` naively to the outer loop, threads finish early ones in microseconds, late ones do real work, the dispatch overhead per iteration dominates, and 4-thread version is slower than 1-thread.

**Why it happens:**
- "Threads = faster" intuition.
- Default `@threads` chunking gives equally-sized index chunks regardless of work distribution. Triangle iteration `for i in 1:N-1; for j in i+2:N` has work `∝ N-i`, hugely uneven across chunks.

**How to avoid:**
- Use `@threads :static` only for uniform-work loops. For triangle iteration, use *dynamic* scheduling via `OhMyThreads.jl`'s `@tasks for ... @set scheduler=:dynamic` or manually chunk by *work* (sum of inner-loop sizes), not by index.
- Threshold: only thread the outer loop if the *total* inner work per outer iteration is >= ~10 µs (rule of thumb: ~10k FLOPs). For N=1000, the average inner-loop work is ~500 ops × ~3 FLOPs ≈ 1.5k FLOPs — borderline. Benchmark both.
- Alternative: thread the *batch evaluation* of independent SA proposals (each thread runs its own 2-opt search on its own tour copy, periodically syncing) — coarser granularity, much better speedup.

**Warning signs:**
- `JULIA_NUM_THREADS=4` slower than `=1` in `@btime`.
- Profile shows >50% time in `partr` / `task scheduling` symbols.

**Phase to address:**
**Phase 4 (parallelization)** — choose granularity based on benchmark, not intuition.

---

### Pitfall 13: GC pauses visible as animation stutter

**What goes wrong:**
Even an "allocation-free" hot path may allocate occasionally (logging, observable updates, garbage from the renderer). Julia's GC is stop-the-world and a major collection can pause for tens to hundreds of milliseconds — visible as a frame freeze. For 60-FPS animation (~16 ms/frame budget), even a "minor" 30 ms pause is two dropped frames.

**Why it happens:**
- Strings allocated per frame for status labels.
- Implicit `Float64`-to-`String` conversions in `lift(t -> "Temperatura: $t", obs_T)`.
- Event-handler closures created and discarded each frame.

**How to avoid:**
- Pre-allocate buffer string once; mutate in place via `IOBuffer` or `print` to a `String` ref:
  ```julia
  const buf_status = IOBuffer()
  function aktualizuj_status!(obs, T, E)
      truncate(buf_status, 0)
      print(buf_status, "T=", round(T, digits=3), " E=", round(E, digits=2))
      obs[] = String(take!(buf_status))   # one alloc per frame, unavoidable
  end
  ```
- Or use `Format.jl` with pre-compiled format strings.
- During recording (where stutter is invisible — fixed framerate), call `GC.gc(false)` at deterministic intervals (e.g., every 100 frames) to *force* small collections rather than letting a large one happen at a bad moment.
- Track allocations: print `Sys.maxrss()` and `GC.gc_num()` at start and end of simulation; investigate if delta is large.

**Warning signs:**
- Animation looks smooth then jerks every 10–20 seconds.
- `@time` reports >5% GC time on the simulation loop.

**Phase to address:**
**Phase 6 (visualization)** — design status-label updates with allocation in mind. **Phase 5** — `@allocated` regression test on `symuluj_krok!`.

---

### Pitfall 14: PackageCompiler sysimage created prematurely — locks GLMakie version, slow upgrades

**What goes wrong:**
To beat GLMakie's notorious time-to-first-plot (60+ seconds reported, issue Makie.jl#1164), the team builds a sysimage with `PackageCompiler.create_sysimage(:GLMakie)`. Subsequent `Pkg.update` does not refresh the sysimage; users get an outdated GLMakie even though `Project.toml` says newer. Worse, the sysimage is per-platform and per-Julia-version; the team ships a Linux sysimage that breaks on Windows.

**Why it happens:**
- Sysimage creation is a one-time investment.
- The cache is invisible — `Pkg.status()` shows the new version even though sysimage carries the old.
- Trade-off (locked versions) is documented but easy to miss.

**How to avoid:**
- Defer sysimage to **Phase 8 (polish)**, not earlier. Native precompilation in Julia 1.9+ already eliminates most TTFP cost; verify with measurement first.
- Make sysimage opt-in via a `scripts/build_sysimage.jl` script the user runs explicitly, not part of `using` flow.
- Document tradeoff loudly in README: "Po `Pkg.update` należy przebudować sysimage skryptem X."
- For demos/CI, prefer `--compile=min --optimize=0` to *speed up* test runs at the cost of runtime — sysimage is overkill.

**Warning signs:**
- `Pkg.status` shows GLMakie 0.21, but feature only present in 0.22 doesn't work.
- CI fails after `Pkg.update` even though local works (local has stale sysimage).

**Phase to address:**
**Phase 8 (polish/release)** — evaluate sysimage need based on actual measured TTFP. Often unnecessary.

---

### Pitfall 15: Aqua.jl false positives push team to disable checks rather than understand

**What goes wrong:**
Aqua.jl's `test_unbound_args` produces false positives on legitimate parametric structs (issue Aqua.jl#139 still open in 2025-era versions). `test_stale_deps` may flag a dep used only in a `@require` block (Requires.jl pattern, now superseded by package extensions). Team disables the check entirely with `Aqua.test_all(JuliaCity; ambiguities=false, unbound_args=false, ...)`, losing the value.

**Why it happens:**
- Reading the Aqua.jl manual for each false positive is friction.
- Disabling is one line; understanding takes 30 minutes per check.

**How to avoid:**
- For each Aqua check, *configure* not *disable*:
  ```julia
  Aqua.test_unbound_args(JuliaCity; broken=true)   # mark as known-broken, still run
  Aqua.test_ambiguities([JuliaCity, Base, Core])    # narrow scope to package own
  Aqua.test_stale_deps(JuliaCity; ignore=[:Random])  # explicit allowlist with comment
  ```
- Each `ignore` / `broken` *must* have a code comment explaining why and a reference to upstream issue.
- For genuine ambiguities, fix them (add a more specific method); ambiguities silently break dispatch correctness.

**Warning signs:**
- `Aqua.test_all` is replaced with a long argument list of `false`s.
- No comments next to disabled checks.

**Phase to address:**
**Phase 5 (testing/QA)** — include Aqua from the start with full strictness; document each suppression.

---

### Pitfall 16: BenchmarkTools used without `$` interpolation, reports wrong allocations

**What goes wrong:**
`@btime symuluj_krok!(stan, rng)` (no `$`) treats `stan` and `rng` as global, type-unstable lookups. The reported allocations include the wrapper closure's allocations, *not* the function's. A function that allocates 0 may appear to allocate 32 bytes. Worse, `@btime sum(rand(1000))` may report 1 ns due to constant folding when the values are compile-time known.

**Why it happens:**
- `@btime` is a macro and the `$` syntax is non-obvious to newcomers.
- Examples in tutorials sometimes omit `$` for brevity.

**How to avoid:**
- ALWAYS use `$` for any non-const global in `@btime`:
  ```julia
  @btime symuluj_krok!($stan, $rng)
  @btime oblicz_energie($trasa, $D)
  ```
- For functions taking immutable arrays, also interpolate to prevent constant-folding:
  ```julia
  @btime sum($x) setup=(x=rand(1000))    # rebuild x each sample
  ```
- For *any* in-place benchmark, use `setup=` to provide fresh data — otherwise after the first run the data is in the desired final state and subsequent samples measure no-op:
  ```julia
  @btime sortuj!(y) setup=(y = copy($trasa)) evals=1
  ```
- Treat allocation counts <10 bytes as "real zero, possibly noise"; counts <100 bytes are very likely framework overhead — verify with a manual `@allocated` measurement in a function context.

**Warning signs:**
- `@btime` reports allocations on a function that `@allocated` (in a wrapping function) reports as 0.
- Suspiciously fast results (<1 ns).
- Benchmark for the second run is ~0 because the in-place data is already sorted/optimal.

**Phase to address:**
**Phase 5 (benchmarking)** — adopt `$` and `setup=` discipline from the first benchmark.

---

## Minor Pitfalls

### Pitfall 17: `Plots.jl` accidentally added as a dependency alongside Makie

**What goes wrong:**
PROJECT.md mentions Plots.jl as fallback. If a contributor adds `using Plots` for a quick debug plot, Plots.jl pulls in ~30 sub-packages, adds 5–10 seconds of TTFX, and may cause method ambiguities with Makie. Once in `Project.toml`, removing it is annoying.

**How to avoid:** Pick one (Makie). Remove the "Plots fallback" wording from PROJECT.md after Phase 1 decision. CI: `Aqua.test_stale_deps` will catch a Plots.jl dep that nothing imports.

**Phase to address:** Phase 1 (decision lock-in).

---

### Pitfall 18: Polish error messages obscure stack traces

**What goes wrong:**
Polish-language `error("Trasa zawiera duplikaty")` is fine for users, but combined with English Julia-internal messages produces a mixed stack trace that is harder to grep in issues / paste into search.

**How to avoid:** Polish messages for *user-facing* assertions (`error`, `@assert`, `throw(ArgumentError(...))`); English for *internal* invariant breaks (`@assert _internal_consistency(state) "internal: state corrupted"`). Document the convention in `CONTRIBUTING.md`.

**Phase to address:** Phase 0 (conventions).

---

### Pitfall 19: `examples/` scripts use top-level mutation, won't run as packages

**What goes wrong:**
A typical `examples/podstawowy.jl` does `trasa = generuj_punkty(...); for i in 1:100; trasa = symuluj_krok!(trasa); end`. Top-level loops in Julia are slow (no specialization) — example *appears* to indicate package is slow.

**How to avoid:** Wrap each `examples/*.jl` body in `function main(); ...; end; main()`. Add a CI test that runs every example end-to-end with small N to catch breakage.

**Phase to address:** Phase 7 (examples).

---

### Pitfall 20: Saving animation frames to `/tmp` fills disk during long records

**What goes wrong:**
Internally `Makie.record` may stream frames; in some configurations or when using `record_events` it buffers. A 5-minute MP4 export at 1080p, 30 FPS, before encoding, is ~30 GB raw. CI runners with small `/tmp` (often 10 GB) crash with `ENOSPC`.

**How to avoid:** Use `record(...; framerate=30, profile="...", visible=false)` to ensure direct streaming to ffmpeg; avoid `record_events` for production exports; in CI, test exports at small N (50) and short duration (5 s) only.

**Phase to address:** Phase 7 (export polish).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `mutable struct Stan` with untyped fields ("we'll type later") | Faster prototyping in Phase 1 | Type instability spreads through every function touching Stan; hot-path 100× slower; rewrite cost grows quadratically | Never — type Stan correctly from day one |
| Single global RNG passed everywhere | Less plumbing in function signatures | Forecloses parallelization (race conditions); breaks reproducibility under threads | Acceptable in Phase 1 single-threaded prototype only; refactor before Phase 4 |
| Skipping `@allocated == 0` test, relying on `@btime` allocs | Tests faster, fewer red CI runs | Allocation regressions land silently; perf debt accumulates | Never — the hot-path zero-allocation guarantee is a stated requirement |
| Using `try/catch using GLMakie` in tests to "make CI pass" | Green CI in 5 minutes | Visualization is never tested; ships broken at unpredictable times | Never — fix CI properly with CairoMakie + xvfb |
| Disable Aqua check rather than fix root cause | Green CI in 1 minute | Real ambiguities ship; package quality erodes | Acceptable for confirmed Aqua.jl bug with linked upstream issue + `broken=true`, *not* `false` |
| Hardcoded `seed=42` everywhere instead of threading-aware seeding | Tests pass first try | Parallel tests become flaky once threading lands | Acceptable in Phase 1; replace with per-thread seeding in Phase 4 |
| Polish file names | Authentic Polish project | Tooling friction on Linux/CI; not all editors handle | Never for `.jl` files; OK in `docs/` and human-readable artifacts |
| Skip CairoMakie fallback, ship GLMakie-only | Saves ~50 lines of backend abstraction | Cannot test visuals on CI; cannot run on headless server | Never if the package claims testability |
| Build PackageCompiler sysimage in Phase 1 | Fast TTFP for demos | Locks versions, hides perf bugs in user code, painful upgrades | Phase 8 only, opt-in via separate script |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **GLMakie ↔ FFmpeg** | Assume `Makie.record` "just works"; no FFmpeg version pin | `FFMPEG_jll` is a transitive dep; `Pkg.test` in clean environment validates. Test export in CI. |
| **GLMakie ↔ OS OpenGL drivers** | "Works on my machine" syndrome — ships requiring driver version not all users have | Document min OpenGL version (3.3+); provide CairoMakie fallback path; CI on Linux+Mac+Windows |
| **`Threads.@threads` ↔ user-supplied RNG** | Function takes `rng::AbstractRNG` arg, internally uses `@threads`, races on rng | API takes `rngs::Vector{<:AbstractRNG}` (one per thread) OR builds them internally from a master seed |
| **`@code_warntype` ↔ recursive calls** | Warntype on outer fn looks clean; type instability hidden in `oblicz_energie` called inside | Run JET.jl `@report_opt` for whole-call-graph analysis; @code_warntype for spot-checks |
| **CairoMakie ↔ MP4 export** | Assume CairoMakie can record MP4 directly | CairoMakie can write per-frame PNGs and combine via FFMPEG_jll, or use `record(fig, "out.mp4", ...)` which delegates to FFmpeg — works, just slower than GLMakie |
| **StableRNGs ↔ algorithm RNG** | Use `StableRNG` in production for "stability" — but it's slower than Xoshiro | StableRNG only in tests; Xoshiro (default) in production |
| **Polish UI ↔ Makie text rendering** | Special characters render as boxes ("tofu") if font missing | Specify fontfamily in theme; `using FreeType_jll`; CI test renders a PNG and asserts non-empty pixels in label region |
| **Pkg test ↔ artifacts** | First test run on CI hangs downloading GLMakie artifacts (>500 MB) | Pre-warm artifact cache or use `actions/cache` for `~/.julia/artifacts` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Recomputing distances inside SA inner loop | sqrt is top profile entry; loop scales as O(N²·iterations) instead of O(iterations) | Precompute `D::Matrix{Float64}` once, use squared distances for comparisons | Always, but tolerable for N<100 |
| `Vector{Any}` accidentally created via abstract container | Allocation per iteration; type warntype red | `Vector{T}` with concrete T; use `eltype()` to verify in tests | At any N, gets worse with iterations |
| `@threads` on too-small loops | Threading slower than serial | Threshold guard: `if N > THREAD_THRESHOLD; @threads for ...; else; for ...; end` | N < ~500 for typical inner loops |
| False sharing on per-thread accumulator | Linear scaling stops; flat after 4 threads | Pad accumulators: `Vector{Tuple{Float64, NTuple{7,Float64}}}` so each entry is ≥64 B | N threads ≥ 4, hot updates |
| Allocating string per frame for status label | Animation jitter; GC time >2% | Pre-allocated `IOBuffer`; mutate in place | After ~1000 frames |
| Observable update per simulation step | UI unresponsive; FPS drops below sim rate | Batch K steps per render; throttle | When `KROKI_NA_KLATKE = 1` |
| `BoundsCheck` enabled in production hot loop | 20–30% overhead | `@inbounds` after correctness verified; pair with `@boundscheck` + assertions in tests | Always for tightest loops |
| Float32 accumulation for tour energy | Last-bit errors flip 2-opt gain sign for nearly-equal moves | Use Float64 for comparisons; Float32 only acceptable for visualization positions | At N>100 with subtle moves |

---

## Security Mistakes

(For an offline scientific package, classical web security largely doesn't apply. The relevant concerns are reproducibility integrity and supply-chain risk.)

| Mistake | Risk | Prevention |
|---------|------|------------|
| `[compat]` left blank in Project.toml | Silent breakage when a dep makes a breaking release | Pin minor versions; e.g., `Makie = "0.21"` (caret-implicit), bump deliberately |
| Loading user-supplied `.jl` script via `include()` for "custom heuristic" feature | Arbitrary code execution if the package ever takes external input | Out of scope per PROJECT.md (no API/server) — keep it that way |
| Saving exported MP4 with predictable filename `/tmp/anim.mp4` shared between users | Shared-host data leakage | Use `tempname()` for output, document explicit user path |
| Distributing a sysimage built from compromised dep | Hidden malicious code in shipped binary | Build sysimage in clean CI; reproducible via lockfile; do not distribute prebuilt binaries from contributor laptops |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Window opens but nothing animates for 60 seconds (TTFP) | User thinks it crashed, force-quits | Show "Kompilowanie..." status before starting simulation; benchmark TTFP, use sysimage if >10s |
| Tour shown but no axis labels / units | Plot looks pretty but unscientific | "Współrzędna X" / "Współrzędna Y" labels; "Energia (długość trasy)" on time-series; title with N and final energy |
| Animation too fast to follow (1000 frames in 2 seconds) | User can't see the algorithm work | Frame-rate cap (30 FPS) with `framerate=30`; expose `predkosc_animacji` parameter |
| Animation too slow (5 minutes for 100 steps) | User loses interest | Tune `KROKI_NA_KLATKE` so total animation is 30–60 seconds for typical demo |
| MP4 export silently overwrites existing file | Lost previous result | Default to `tempname() * ".mp4"` or check existence and prompt/error |
| No baseline comparison shown | User can't tell if "soap bubble" is good | Display nearest-neighbor baseline length on plot legend: "Trasa wynikowa: 25.3 (baseline NN: 31.2)" |
| Polish typography uses ASCII quotes (`"foo"` instead of „foo") | Looks unprofessional in screenshots | Use proper Polish quotation marks in user-facing strings |
| Window size hardcoded, doesn't fit small screens | Demo unusable on laptop | `figure_padding=10`; query screen size or default to 800×600 |

---

## "Looks Done But Isn't" Checklist

- [ ] **Type stability:** `oblicz_energie`, `symuluj_krok!`, `oblicz_zysk_2opt` pass `JET.@report_opt` with zero issues — verify with `julia --project test/aqua.jl`.
- [ ] **Zero-alloc hot path:** `@allocated symuluj_krok!(stan, rng) == 0` after one warm-up call — verify in `test/runtests.jl`.
- [ ] **Hamilton invariant:** Tour validity test runs *every step* in the test suite for at least one short simulation — verify by reading test file.
- [ ] **Threading determinism:** `simulate(seed=42, nthreads=1) == simulate(seed=42, nthreads=8)` final tour identical (or energies equal within 1e-12) — verify with explicit determinism test.
- [ ] **Reproducibility across Julia upgrades:** Golden-value test uses `StableRNG`, not `MersenneTwister` or default — grep for `MersenneTwister` in `test/`.
- [ ] **Headless test pass:** CI passes on Linux without GLMakie — backend is configurable, CairoMakie fallback works.
- [ ] **MP4 export reproducible:** Two runs of same export produce byte-identical MP4 (modulo container-level metadata) — verify by `sha256` or feature equivalence.
- [ ] **Polish encoding:** No BOMs in `.jl` files; all files NFC-normalised; CI guard runs.
- [ ] **No global state:** `grep -n "^const " src/` review — only true compile-time constants (e.g., default seed value), no working buffers.
- [ ] **Aqua passes with strict config:** No checks disabled without comment+issue link.
- [ ] **Benchmark numbers in README current:** Re-run benchmark suite in clean env before each release, update numbers.
- [ ] **Examples actually run:** `julia --project examples/podstawowy.jl` exits 0 — included in CI.
- [ ] **Window opens on Windows + Linux + Mac:** Manual or CI verification on all three.
- [ ] **Baseline comparison present:** `wizualizuj` shows NN baseline alongside current tour.
- [ ] **Polish UI strings consistent:** No mixed English/Polish in axis labels or status — grep for `"[A-Z][a-z]+ "` in src/.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Type instability shipped (P1) | MEDIUM | Run JET.jl across whole package; fix one function at a time; add `@allocated == 0` regression test per fix; release patch |
| Closure-capture race (P2) | LOW–MEDIUM | Identify via `@code_warntype` finding `Core.Box`; refactor to per-thread storage; add determinism test; release patch |
| Shared-RNG corruption (P3) | LOW | Refactor to per-thread RNG vector built from master seed; reseed all callers; users notice no behavior change |
| Hamilton-cycle invariant broken (P4) | HIGH | Bug is algorithmic; may require representation change. Add invariant assertions in debug; rewrite move-application in `symuluj_krok!`; rerun all benchmarks |
| Observable update storm (P5) | LOW | Add throttling parameter `KROKI_NA_KLATKE`; document; release patch — users see better animation immediately |
| `record` blocking surprise (P6) | LOW | Wrap with `ProgressMeter`; doc update; minor release |
| Headless CI failure (P7) | MEDIUM | Add CairoMakie fallback to test infra; refactor visualization API to backend-agnostic; one PR |
| Reproducibility breaks on Julia upgrade (P8) | LOW | Replace `MersenneTwister` with `StableRNG` in golden-value tests; rerun, commit new golden values; document |
| Polish encoding corruption (P9) | LOW | Run `iconv -f WINDOWS-1250 -t UTF-8` on affected files; add `.editorconfig`; CI guard |
| Distance-matrix decision wrong (P10) | LOW | Add `precomputed_distances::Bool` flag; benchmark both; choose default |
| Cooling schedule mistuned (P11) | LOW | Add T₀ calibration; expose schedule choice as parameter; benchmark on standard fixture |
| Threading slows things down (P12) | LOW | Add `MIN_N_THREAD` threshold; benchmark; document |
| GC stutter visible (P13) | MEDIUM | Audit allocations frame-by-frame with `@allocated` wrap; fix top offenders; consider `GC.gc(false)` between batches |
| Sysimage version-locked (P14) | LOW | Document rebuild script; add `Pkg.update` post-hook reminder |
| Aqua suppression accumulated (P15) | MEDIUM | Re-enable each suppressed check; fix or document with link; one PR per check |
| Benchmark numbers misleading (P16) | LOW | Audit with `$` and `setup=`; rerun; update README |

---

## Pitfall-to-Phase Mapping

Phase numbering is illustrative. Roadmap synthesis owns the canonical numbering — this table communicates *prevention timing* relative to phase semantics.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Type instability in `Stan` | Phase 2 (data structures) | JET clean + `@allocated == 0` test |
| 2. Closure capture in `@threads` | Phase 4 (parallelization) | Determinism test (same seed → same tour); `@code_warntype` no `Box` |
| 3. Shared RNG | Phase 3 (SA core) | Per-thread seeding; reproducibility test under `JULIA_NUM_THREADS=1,8` |
| 4. Broken Hamilton cycle | Phase 1 (algorithm choice) + Phase 2 (data) | Invariant check `sort(trasa)==1:n` in every step in tests |
| 5. Observable update storm | Phase 6 (visualization) | FPS counter; manual demo; window stays responsive |
| 6. `record` blocks unexpectedly | Phase 7 (export) | Progress bar visible; documented blocking behavior |
| 7. Headless CI breakage | Phase 5 (test infra) + Phase 6 (vis) | CI green on Linux without GLMakie; CairoMakie path works |
| 8. Cross-version reproducibility | Phase 5 (testing) | Golden tests use `StableRNG`; CI on Julia LTS+stable+nightly |
| 9. Polish encoding | Phase 0 (bootstrap) | `.editorconfig`, `.gitattributes`, encoding-validation CI test |
| 10. Distance-matrix decision | Phase 2 (data) | Benchmark both; locked decision in code comment |
| 11. Cooling schedule | Phase 3 (SA) | Acceptance-ratio plot per run; tuning notebook archived |
| 12. `@threads` overhead | Phase 4 (parallelization) | Benchmark single vs. multi; speedup curve in benchmarks/ |
| 13. GC stutter | Phase 6 (vis) | `@allocated` per frame ≤ small constant; `@time` reports <2% GC |
| 14. Sysimage version lock | Phase 8 (release polish) | TTFP measurement; sysimage opt-in script with rebuild instructions |
| 15. Aqua suppression drift | Phase 5 (QA) | Aqua all-on; each suppression has comment+link |
| 16. BenchmarkTools misuse | Phase 5 (benchmarking) | Code review checks for `$` interpolation |
| 17. Plots.jl creep | Phase 1 (decision lock) | Aqua `test_stale_deps` |
| 18. Mixed-language errors | Phase 0 (conventions) | `CONTRIBUTING.md` documents convention |
| 19. Slow examples | Phase 7 (examples) | Each example wraps in `function main()`; CI runs all |
| 20. Disk fill on export | Phase 7 (export) | CI test exports a small MP4; checks file size sane |

---

## Sources

**Julia Performance & Threading (HIGH confidence — official docs + recent issues):**
- [Performance Tips · The Julia Language](https://docs.julialang.org/en/v1/manual/performance-tips/)
- [Multi-Threading · The Julia Language](https://docs.julialang.org/en/v1/manual/multi-threading/)
- [Random Numbers · The Julia Language](https://docs.julialang.org/en/v1/stdlib/Random/) — TaskLocalRNG semantics
- [JuliaLang/julia#15276 — performance of captured variables in closures](https://github.com/JuliaLang/julia/issues/15276)
- [Discourse: Overhead of Threads.@threads](https://discourse.julialang.org/t/overhead-of-threads-threads/53964) — µs-scale dispatch cost
- [Discourse: Random numbers and threads](https://discourse.julialang.org/t/random-numbers-and-threads/77364)
- [FastClosures.jl](https://github.com/c42f/FastClosures.jl) — `@closure` macro
- [How to optimise Julia code: A practical guide](https://viralinstruction.com/posts/optimise/)
- [Optimizing your code (Modern Julia Workflows)](https://modernjuliaworkflows.org/optimizing/)

**GC & Latency (MEDIUM confidence — community reports + open issues):**
- [JuliaLang/julia#8543 — Implement a low-latency, incremental garbage collector](https://github.com/JuliaLang/julia/issues/8543)
- [Discourse: How difficult is it to write allocation-free code](https://discourse.julialang.org/t/how-difficult-is-it-to-write-allocation-free-code-to-avoid-gc-pauses/40235)
- [Discourse: Slow Makie animations](https://discourse.julialang.org/t/slow-makie-animations/103626)

**Makie / GLMakie (HIGH confidence — official docs + current issues):**
- [Animations | Makie](https://docs.makie.org/dev/explanations/animation)
- [Observables | Makie](https://docs.makie.org/dev/explanations/observables)
- [Events | Makie](https://docs.makie.org/dev/explanations/events) — tick observable
- [Makie Changelog](https://docs.makie.org/dev/changelog) — ComputeGraph, batch update! API
- [GLMakie/GLMakie.jl](https://github.com/JuliaPlots/GLMakie.jl) — README, headless CI workflow
- [MakieOrg/Makie.jl#1164 — Why so slow even after sysimage?](https://github.com/MakieOrg/Makie.jl/issues/1164)
- [JuliaLang/julia#49743 — GLMakie precompile hangs on Windows 10, Julia 1.9](https://github.com/JuliaLang/julia/issues/49743)
- [MakieOrg/Makie.jl#1953 — GLMakie fails on headless Ubuntu 22.04](https://github.com/MakieOrg/Makie.jl/issues/1953)
- [MakieOrg/Makie.jl#420 — Update scene after all nodes have been updated](https://github.com/JuliaPlots/Makie.jl/issues/420)

**Aqua & Quality (HIGH confidence — official docs):**
- [Home · Aqua.jl](https://juliatesting.github.io/Aqua.jl/dev/)
- [Unbound Type Parameters · Aqua.jl](https://juliatesting.github.io/Aqua.jl/dev/unbound_args/)
- [JuliaTesting/Aqua.jl#139 — False positive for unbound type parameters](https://github.com/JuliaTesting/Aqua.jl/issues/139)

**BenchmarkTools (HIGH confidence — official docs):**
- [Manual · BenchmarkTools.jl](https://juliaci.github.io/BenchmarkTools.jl/stable/manual/)
- [Discourse: Setup and teardown in BenchmarkTools](https://discourse.julialang.org/t/setup-and-teardown-in-benchmarktools/20972)

**PackageCompiler (HIGH confidence):**
- [PackageCompiler.jl docs](https://julialang.github.io/PackageCompiler.jl/dev/)
- [Sysimages](https://julialang.github.io/PackageCompiler.jl/dev/sysimages.html)

**Unicode / Polish identifiers (HIGH confidence — official docs):**
- [Unicode · The Julia Language](https://docs.julialang.org/en/v1/stdlib/Unicode/)
- [Variables / Allowed identifier characters](https://github.com/JuliaLang/julia/blob/master/doc/src/manual/variables.md) — NFC normalization

**TSP / SA Background (MEDIUM confidence — academic sources):**
- [List-Based Simulated Annealing for TSP (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC4808530/)
- [Hybrid SA with adaptive cooling for TSP](https://dl.acm.org/doi/abs/10.1145/1543834.1543969)
- [Cooling Schedules for Optimal Annealing — Math. of Operations Research](https://pubsonline.informs.org/doi/10.1287/moor.13.2.311)
- [Simulated annealing — Wikipedia](https://en.wikipedia.org/wiki/Simulated_annealing) (overview only)

**False Sharing / Cache (MEDIUM confidence):**
- [False sharing in multi-threading (jling.dev)](https://blog.jling.dev/blog/false_share/)

**Numerical (MEDIUM confidence):**
- [Distances.jl](https://github.com/JuliaStats/Distances.jl)
- [Discourse: Faster squared euclidean distance](https://discourse.julialang.org/t/faster-squared-euclidean-distance-calculation/68969)

---
*Pitfalls research for: Julia + GLMakie + TSP soap-bubble heuristic + Polish UI*
*Researched: 2026-04-28*
