---
phase: 02-energy-sa-algorithm-test-suite
reviewed: 2026-04-29T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - Project.toml
  - src/JuliaCity.jl
  - src/typy.jl
  - src/energia.jl
  - src/baselines.jl
  - src/algorytmy/simulowane_wyzarzanie.jl
  - test/runtests.jl
  - test/test_energia.jl
  - test/test_baselines.jl
  - test/test_symulacja.jl
  - test/_generuj_test08_refs.jl
findings:
  blocker: 4
  warning: 9
  info: 5
  total: 18
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-29
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Phase 02 implements the energy hot path, NN baseline, and Simulated Annealing
algorithm with a comprehensive test suite. The code is generally well-structured
and the documentation discipline is strong, but several real correctness defects
were found:

1. **A probabilistic crash** in `symuluj_krok!` and `kalibruj_T0` from sampling
   an empty range (acknowledged in `deferred-items.md` but never fixed in
   shipped code — the suggested patch is sitting unapplied while tests rely on
   not hitting the bad seed).
2. **A likely Aqua test failure** because `[extras]` contains four packages
   (`BenchmarkTools`, `GLMakie`, `Makie`, `Observables`) not used by any
   target and not on the Aqua ignore list.
3. **A semantic mismatch between docstring/comment and implementation** of
   the patience reset rule in `uruchom_sa!`.
4. **A fragile/likely-broken `Threads.@threads :static` over `enumerate(chunks(...))`
   pattern** in `oblicz_energie` that may not iterate in the way the author
   expects.

In addition there are hidden-edge-case latent bugs in `kalibruj_T0` (`std`
returning `NaN` for ≤1 worsening sample), a wasted O(n) reverse on the (i=1, j=n)
swap, dead `params` argument, and several documentation/precision concerns.

The review treats locked-but-known issues from `deferred-items.md` as still in
scope: a deferred bug is still a bug. The phase ships code that can crash; the
fact that the crash is documented does not change the severity.

## Blockers

### BL-01: `symuluj_krok!` and `kalibruj_T0` crash on empty range when `i = n-1`

**File:** `src/algorytmy/simulowane_wyzarzanie.jl:108-109`
**File:** `src/energia.jl:178-179`

**Issue:** Both call sites use:
```julia
i = rand(stan.rng, 1:(n - 1))
j = rand(stan.rng, (i + 2):n)
```
When `i == n - 1` is sampled, `(i + 2):n` is `(n+1):n`, an empty `UnitRange`.
`rand(rng, empty_range)` raises `ArgumentError("collection must be non-empty")`.

For `n = 20` (the fixture used throughout the test suite) this fires with
probability `1/(n-1) = 1/19 ≈ 5.3 %` per call. The TEST-01/TEST-08 paths each
execute 1000–2000 `symuluj_krok!` calls — expected ~50–100 crashes per run.
The cache-invariant test runs 500 steps. ALG-06 patience test runs up to 10_000.
**Every one of these tests is one bad RNG draw away from crashing.**

The issue is acknowledged in `.planning/phases/02-energy-sa-algorithm-test-suite/deferred-items.md`
("Pre-existing pattern from Plan 02-02") with a one-line suggested fix that was
not applied. Marking a crash as "deferred" does not make it not-a-crash; this
phase ships the bug.

**Fix:** Apply the patch already documented in `deferred-items.md`:
```julia
# src/algorytmy/simulowane_wyzarzanie.jl:108
i = rand(stan.rng, 1:(n - 2))   # was: 1:(n - 1)
j = rand(stan.rng, (i + 2):n)

# src/energia.jl:178
i = rand(rng, 1:(n - 2))        # was: 1:(n - 1)
j = rand(rng, (i + 2):n)
```
Then add a regression test that runs `symuluj_krok!` on `n = 3` (smallest valid
fixture) for ≥10_000 iterations and asserts no exception. With `n = 3` the only
valid `(i, j)` is `(1, 3)`, exercising the boundary.

The locked-decision argument in `deferred-items.md` does not survive scrutiny:
D-05/D-06 lock the *2-opt sampling shape*, not the off-by-one bug. Fixing
`1:(n-1)` to `1:(n-2)` preserves the `(i, i+2..n)` shape — it removes a sample
that would always yield an empty range. There is no decision-locked behavior
being changed here.

---

### BL-02: Aqua `check_extras` will fail — four extras have no target

**File:** `Project.toml:24-37`
**File:** `test/runtests.jl:211-218`

**Issue:** `[extras]` declares ten packages:
```
Aqua, BenchmarkTools, GLMakie, JET, Makie, Observables,
PerformanceTestTools, StableRNGs, Test, Unicode
```
but `[targets].test` lists only six:
```
Aqua, JET, PerformanceTestTools, StableRNGs, Test, Unicode
```
which leaves `BenchmarkTools`, `GLMakie`, `Makie`, `Observables` declared as
extras but never added to any target. Aqua's `check_extras` flags exactly this
(extras that are not in any target). The `runtests.jl` ignore list is:
```julia
deps_compat = (ignore = [:Random, :Statistics],
               check_extras = (ignore = [:Test, :Unicode],))
```
The `check_extras` ignore list contains only `:Test` and `:Unicode` — the four
unused extras are not ignored. **`Aqua.test_all(JuliaCity; ...)` will report
four `check_extras` failures.**

(Note: `:Test` and `:Unicode` are *in* the test target, so ignoring them is
unnecessary at best and may itself be wrong syntax — Aqua expects to ignore
extras that are *intentionally* unused-in-targets, not ones that are used.)

**Fix:** Either remove the unused extras from `Project.toml`:
```toml
# Remove from [extras]:
#   BenchmarkTools, GLMakie, Makie, Observables
# (These are needed in dev/Phase 3, but not by the test suite — install them
#  ad-hoc into the dev environment via Pkg.add, do not require them as test extras.)
```
or, if they must remain, add them to the `check_extras` ignore list:
```julia
Aqua.test_all(JuliaCity;
    ambiguities = (recursive = false,),
    stale_deps = false,
    deps_compat = (ignore = [:Random, :Statistics],),
    piracies = (broken = false,),
    deps_compat = (ignore = [:Random, :Statistics],),
    # Do NOT pass duplicate keys; collapse:
    # Correct shape:
    # Aqua.test_all(...; check_extras = (ignore = [:BenchmarkTools, :GLMakie, :Makie, :Observables],))
)
```
Note the `runtests.jl` snippet also has a structural problem: `check_extras` is
nested *inside* `deps_compat` (`deps_compat = (ignore=..., check_extras=...)`),
but `check_extras` is its own top-level Aqua check, not a sub-key of
`deps_compat`. The current call almost certainly does not configure
`check_extras` at all — Aqua will run it with defaults and fail on the four
unused extras.

Correct shape:
```julia
Aqua.test_all(JuliaCity;
    ambiguities = (recursive = false,),
    stale_deps  = false,
    deps_compat = (ignore = [:Random, :Statistics],),
    # check_extras is a separate top-level option:
    # ignore the unused extras explicitly OR remove them from Project.toml.
)
```

---

### BL-03: `uruchom_sa!` patience reset rule contradicts its own docstring/comment

**File:** `src/algorytmy/simulowane_wyzarzanie.jl:127-175`

**Issue:** The docstring claims two different reset rules in the same comment
block:

1. Line 130-131: *"po kazdym `symuluj_krok!` sprawdzamy: czy `stan.energia`
   faktycznie zmalalo wzgledem ostatniego best-known minimum?"* — reset on
   improvement vs **best-known minimum**.
2. Line 133, 164: *"D-04: reset tylko przy strict improvement (delta < 0)"* —
   reset on **per-step strict improvement** (`delta < 0`).

These are different rules and produce different stop behaviors:

- Rule (1) — the implementation:
  ```julia
  if stan.energia < energia_min
      energia_min = stan.energia
      licznik_bez_poprawy = 0
  ```
  Counter resets only when energy drops *below the running minimum*. After a
  Metropolis-accepted worsening move, subsequent small improvements that don't
  reach the previous best do **not** reset.

- Rule (2) — what the comment text claims:
  Counter resets every time `delta < 0` (greedy improvement step), regardless
  of whether it reaches a new best.

These produce visibly different early-stop counts; the ALG-06 patience test
(`alg.cierpliwosc=10`) only verifies *that* early-stop fires, not *which*
semantics. The bug is hidden: someone reading D-04 to mean rule (2) (which the
comment explicitly says) will believe they've validated rule (2) when they've
actually shipped rule (1).

If D-04 in `02-CONTEXT.md` actually locks rule (2), the implementation is wrong.
If the implementation is correct, the comment is wrong. Either way, ship date
should not have a public function whose docstring lies about its semantics.

**Fix:** Reconcile against `02-CONTEXT.md` D-04. If rule (1) (best-known) is
correct, replace the misleading "delta < 0" line:
```julia
# D-04: reset only when stan.energia drops below the running best-known minimum.
# Metropolis-accepted worsening moves never reset; they are exploration, not progress.
```
If rule (2) is correct, change the implementation:
```julia
# Track the previous-step energy and reset on any strict improvement step.
energia_prev = stan.energia
while ...
    symuluj_krok!(stan, params, alg)
    if stan.energia < energia_prev      # delta < 0 was actually applied
        licznik_bez_poprawy = 0
    else
        licznik_bez_poprawy += 1
    end
    energia_prev = stan.energia
end
```
Add a unit test that distinguishes the two rules: 2 worsening steps followed by
1 improvement that's still above `energia_min` — rule (1) does not reset, rule
(2) does.

---

### BL-04: `Threads.@threads :static for ... in enumerate(chunks(...))` is unsupported / undefined

**File:** `src/energia.jl:113-121`

**Issue:** The pattern is:
```julia
Threads.@threads :static for (chunk_idx, krawedzie) in enumerate(chunks(1:n; n=nchunks))
    s = 0.0
    @inbounds for k in krawedzie
        ...
    end
    bufor[chunk_idx] = s
end
```
`Threads.@threads` (Julia 1.10) requires the iteration argument to support
`firstindex` / `lastindex` / `getindex` so the macro can partition the index
range across tasks. `Base.Iterators.Enumerate` does **not** support `getindex`
in general; it implements `iterate`, `length`, and (for indexable inner
iterators) `getindex`, but `ChunkSplitters.Chunk` is its own iterator type and
the indexing story over `enumerate(chunks(...))` is at minimum non-canonical
and at worst silently broken.

The blessed ChunkSplitters pattern is:
```julia
@threads :static for chunk in chunks(1:n; n=nchunks)
    ...
end
```
or, with explicit chunk index:
```julia
@threads :static for chunk_idx in 1:nchunks
    krawedzie = chunks(1:n; n=nchunks)[chunk_idx]
    ...
end
```

If the current pattern works at all, it is by accident of how the macro
expansion lowers `enumerate`. JET will likely flag it; even if it passes,
behavior on Julia minor-version bumps is not guaranteed. This is a correctness
risk in addition to a maintainability hazard.

The TEST-04 multi-thread determinism test only exercises `nthreads()` ∈ {1, 8}
on a script — it cannot detect "all chunks ran on thread 1" or "two threads
wrote the same `bufor[chunk_idx]`" failure modes.

**Fix:** Switch to the canonical pattern:
```julia
function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64
    n = length(trasa)
    nchunks = length(bufor)
    fill!(bufor, 0.0)
    cs = collect(chunks(1:n; n=nchunks))   # materialize ranges
    Threads.@threads :static for chunk_idx in eachindex(cs)
        s = 0.0
        @inbounds for k in cs[chunk_idx]
            i_aktualne = trasa[k]
            i_nastepne = trasa[mod1(k + 1, n)]
            s += D[i_aktualne, i_nastepne]
        end
        bufor[chunk_idx] = s
    end
    return sum(bufor)
end
```
The `collect(...)` allocates O(nchunks) `UnitRange`s once per call (negligible
for nchunks ≤ Threads.nthreads()), and is hoistable to the caller for true
zero-alloc by passing `cs` in. Verify with `@allocated` after the fix.

## Warnings

### WR-01: `kalibruj_T0` returns `NaN` when only one worsening sample collected

**File:** `src/energia.jl:172-188`

**Issue:** `Statistics.std(v)` defaults to `corrected=true`, dividing by
`n - 1`. For `length(v) == 1`, `std(v) == NaN`. The function then returns
`2.0 * NaN == NaN`, the caller assigns `T_zero = NaN`, and the entire SA run is
silently broken (`exp(-delta / NaN) == NaN`, Metropolis comparison `rand() < NaN`
is always `false`, so SA degenerates to greedy descent).

The current `@assert !isempty(worsening)` guard catches `length == 0` but not
`length == 1`. The JET test calls `kalibruj_T0(stan; n_probek=10)` — for `n = 20`
and a near-uniform NN tour, the chance of ≤1 worsening sample in 10 draws is
not zero (and gets worse as `n_probek` is dropped further by future callers).

**Fix:**
```julia
@assert length(worsening) >= 2 "need at least 2 worsening samples for std()"
```
Or use uncorrected std:
```julia
sigma = std(worsening; corrected = length(worsening) > 1)
isfinite(sigma) || throw(ArgumentError("kalibruj_T0: insufficient worsening samples ($(length(worsening)))"))
```

---

### WR-02: `delta_energii` allows `j == i + 1` but `symuluj_krok!` would no-op

**File:** `src/energia.jl:145-154`

**Issue:** `delta_energii` asserts `1 <= i < j <= n`, allowing `j == i + 1`
(adjacent positions). When called with `j == i + 1`:
- `i_next == j`, so the formula reads `D[t[i],t[j]] - D[t[i],t[j]] = 0` for the
  outer pair and `D[t[i+1],t[j_next]] - D[t[j],t[j_next]] = 0` for the inner.
- `delta == 0.0`.

This is mathematically correct (a 2-opt swap of adjacent positions is a no-op),
but the `symuluj_krok!` sampler explicitly excludes it via `j = rand(rng, (i+2):n)`.
The looser assertion is misleading: a future caller (e.g., a custom test) that
calls `delta_energii(stan, 5, 6)` will get `0.0` and may not realize this is
the no-op case rather than an actual evaluable swap.

**Fix:** Tighten the assertion to match the algorithmic precondition:
```julia
@assert 1 <= i && i + 2 <= j <= n "i+2 <= j required for non-trivial 2-opt swap"
```
or document `j == i + 1` semantics in the docstring.

---

### WR-03: (i=1, j=n) sample produces an O(n) reverse with delta ≡ 0

**File:** `src/algorytmy/simulowane_wyzarzanie.jl:114-117`

**Issue:** When `i == 1` and `j == n`, the 2-opt swap reverses positions
`2:n` of `stan.trasa`. For a Hamilton cycle, reversing the tail of the
cycle simply produces the same cycle traversed in the opposite direction —
energetically identical: `delta == 0.0`.

Because `delta == 0.0`:
- `delta < 0.0` is false.
- `rand(stan.rng) < exp(0.0) == 1.0` is **always** true (rand returns < 1.0).

So the swap is **always accepted**, paying an O(n) `reverse!(view(...))` cost
to permute a tour into its mirror — an SA step that does no useful work.
Probability is `1/(n-1) * 1/(n-1) ≈ 1/n²` (≈0.001 for n=20, ≈10⁻⁶ for n=1000),
so it's not a hot-path issue, but:

1. It contradicts the `symuluj_krok!` docstring claim of O(1) per step.
2. The (i=1, j=n) case wastes one whole RNG state advance + O(n) reverse on a
   guaranteed-rejection-equivalent swap.

**Fix:** Either reject the (i=1, j=n) case at sample time:
```julia
i = rand(stan.rng, 1:(n - 2))
j = rand(stan.rng, (i + 2):n)
# Reject the symmetric (1, n) case which is always a no-op cycle reversal.
if i == 1 && j == n
    return nothing
end
```
or accept the cost and update the docstring to say "expected O(1), worst case
O(n) at probability 1/n²".

---

### WR-04: `params::Parametry` argument is unused inside `symuluj_krok!`

**File:** `src/algorytmy/simulowane_wyzarzanie.jl:106`

**Issue:** `function symuluj_krok!(stan, params::Parametry, alg::SimAnnealing)`
takes `params` but the function body never reads it. The docstring acknowledges
this ("`params` jest argumentem przez interfejs (Holy-traits dispatch
konsystencja), ale NIE uzywany w samym kroku"), but the API still gives a
caller no way to know that.

Two real consequences:
1. Aqua may flag it (depending on `unbound_args` config — currently not enabled,
   so probably not, but `piracy` and `unbound_args` checks evolve).
2. A reader sees `params` and reasonably assumes mutating `params.liczba_krokow`
   would change behavior — it doesn't.

**Fix:** Either remove the parameter from the public signature and define a
2-arg overload, or annotate clearly:
```julia
"""
    symuluj_krok!(stan, params, alg::SimAnnealing) -> Nothing

NOTE: `params` is **not consumed** in a single step (interface-uniformity
placeholder); only `alg.alfa` and `stan.rng` / `stan.temperatura` are read.
Outer-loop stop logic in `uruchom_sa!` consumes `params.liczba_krokow`.
"""
function symuluj_krok!(stan::StanSymulacji, _params::Parametry, alg::SimAnnealing)
```
The leading underscore in `_params` is the standard "intentionally unused"
signal in Julia.

---

### WR-05: `kalibruj_T0` advances `stan.rng` as a side effect of constructor default

**File:** `src/algorytmy/simulowane_wyzarzanie.jl:62-67`

**Issue:** `T_zero=kalibruj_T0(stan)` runs *every time* the kwarg ctor is
invoked without an explicit `T_zero`. `kalibruj_T0` mutates `stan.rng` (1000
samples × 2 `rand` calls = 2000 RNG state advances by default). This is
extremely surprising for a constructor.

Concrete consequence: TEST-04 in-process determinism comes out OK because it
constructs SimAnnealing identically in both runs, but a user who:
```julia
stan = StanSymulacji(punkty; rng=Xoshiro(42))
inicjuj_nn!(stan)
alg1 = SimAnnealing(stan)            # advances stan.rng by ~2000
alg2 = SimAnnealing(stan; T_zero=alg1.T_zero)  # does NOT advance rng
# alg1 and alg2 run in different RNG states despite same seed origin
```
will get inconsistent results between two seemingly equivalent setups.

The kwarg evaluation timing is also non-obvious: the *default-arg expression* is
`kalibruj_T0(stan)`, evaluated lazily when no `T_zero` is provided. There is no
way to know from the call site that the constructor will mutate `stan.rng`.

**Fix:** Pass a separate calibration RNG or document loudly:
```julia
function SimAnnealing(stan::StanSymulacji;
                      alfa::Float64=0.9999,
                      cierpliwosc::Int=5000,
                      T_zero::Union{Nothing,Float64}=nothing,
                      rng_kalibracji::AbstractRNG=copy(stan.rng))   # explicit
    if T_zero === nothing
        T_zero = kalibruj_T0(stan; rng=rng_kalibracji)
    end
    return SimAnnealing(T_zero, alfa, cierpliwosc)
end
```
Using `copy(stan.rng)` decouples calibration from the SA stream — a separate,
deterministic stream that doesn't pollute the simulation state.

---

### WR-06: `oblicz_energie` 2-arg variant ignores threading correctness with tiny n

**File:** `src/energia.jl:71-90`

**Issue:** The 2-arg `oblicz_energie(punkty, trasa)` builds a local `bufor =
zeros(Float64, Threads.nthreads())` and calls the 3-arg variant. For `n = 1`
or `n = 2`, `chunks(1:n; n=Threads.nthreads())` produces `min(n, nthreads())`
non-empty chunks; remaining `bufor[i]` slots stay 0.0 from `fill!`. Behavior
is correct but undocumented.

More importantly, for `n < Threads.nthreads()`, threading overhead vastly
exceeds the work. This is only relevant in tests but inflates TEST-02 alloc
budgets and noise. Out of v1 perf scope per review rules, but flagged because
it interacts with the WR-04 thread/enumerate concern.

**Fix:** Skip threading for tiny `n`:
```julia
if n < 64   # below this, single-threaded inner loop is faster
    s = 0.0
    @inbounds for k in 1:n
        s += D[trasa[k], trasa[mod1(k + 1, n)]]
    end
    return s
end
# else current threaded path
```

---

### WR-07: `_alloc_3arg(D, trasa, bufor)` allocation tolerance hides threading allocations

**File:** `test/test_energia.jl:53-63`

**Issue:** The test uses:
```julia
@test _alloc_3arg(D, trasa, bufor) < 4096
```
A 4096-byte ceiling is nearly two pages of memory — that's not "approximately
zero". On Julia 1.10 with `JULIA_NUM_THREADS=8`, `Threads.@threads :static`
allocates ~16-64 bytes per task for scheduling; total ≈128-512 bytes. A 4096
budget masks everything up to a 64-element `Vector{Float64}` allocation,
which would be a real bug in the hot path.

The TEST-03 / ALG-03 contract per Phase 2 docs is "zero-alloc po rozgrzewce"
(zero-alloc after warmup). 4096 bytes is not zero.

**Fix:** Tighten the bound or split into two checks:
```julia
# Threading bookkeeping only — should be a few hundred bytes max:
@test _alloc_3arg(D, trasa, bufor) < 1024   # was 4096
# Or, more precisely, ban heap allocations in the inner loop:
@test _alloc_3arg(D, trasa, bufor) <= 256
```
If 1024 fails on the runner, investigate before relaxing. The current 4096
threshold lets a 256-element float vector slip in undetected.

---

### WR-08: TEST-04 subprocess: `JULIA_NUM_THREADS=8` will not work on single-core CI

**File:** `test/test_symulacja.jl:225-231`

**Issue:** The subprocess test hardcodes `JULIA_NUM_THREADS=8`. On a CI runner
with fewer logical cores, Julia happily oversubscribes (no error) but:

1. The "1 vs 8" comparison degenerates to "1 vs N" where N might be 2 or 4 —
   the test still passes if `oblicz_energie` reduction-order changes don't
   exceed `rtol=1e-12`, but the test name is now misleading.
2. On a true 1-core sandbox (some containerized CI environments), `nthreads()`
   may be capped at the logical CPU count — the 8-thread spawn could effectively
   run on 1 thread, defeating the test purpose silently.

**Fix:** Use `max(2, Sys.CPU_THREADS)` or the runner's thread count:
```julia
nthr_high = string(max(2, Sys.CPU_THREADS))   # at least 2 for a real comparison
PerformanceTestTools.@include_foreach(
    script_path,
    [
        ["JULIA_NUM_THREADS" => "1",       "JC_OUT" => out_1],
        ["JULIA_NUM_THREADS" => nthr_high, "JC_OUT" => out_n],
    ]
)
```
And gate the test:
```julia
if Sys.CPU_THREADS < 2
    @test_skip "TEST-04 subprocess requires ≥ 2 logical cores"
end
```

---

### WR-09: `oblicz_macierz_dystans!` and 2-arg `oblicz_energie` duplicate the distance-matrix loop verbatim

**File:** `src/energia.jl:27-43` and `src/energia.jl:71-90`
**File:** `test/test_baselines.jl:95-105` and `test/test_energia.jl:41-48`

**Issue:** The same `for j in 1:n; for i in 1:j-1; ... D[i,j] = D[j,i] = sqrt(...)`
loop appears in 4 places (2 in src, 2 in tests). They drift independently —
the 2-arg `oblicz_energie` won't pick up changes to `oblicz_macierz_dystans!`
(e.g., a future precision improvement, switch to `hypot`, or numerical
optimization).

This is a maintainability/correctness risk: a test (`test_energia.jl:41-48`)
that builds D inline will pass even if `oblicz_macierz_dystans!` has a bug,
because the test never calls it.

**Fix:** Extract the loop into a private `_compute_distance_matrix!(D, punkty)`
helper:
```julia
function _compute_distance_matrix!(D::AbstractMatrix{Float64}, punkty::AbstractVector)
    n = length(punkty)
    @assert size(D) == (n, n) "D dimension mismatch"
    @inbounds for j in 1:n
        for i in 1:j-1
            p_i = punkty[i]; p_j = punkty[j]
            dx = p_i[1] - p_j[1]; dy = p_i[2] - p_j[2]
            d = sqrt(dx*dx + dy*dy)
            D[i, j] = d; D[j, i] = d
        end
        D[j, j] = 0.0
    end
    return D
end

oblicz_macierz_dystans!(stan) = (_compute_distance_matrix!(stan.D, stan.punkty); nothing)
# 2-arg oblicz_energie: just allocate D and call the helper.
```
Update tests to use `_compute_distance_matrix!` (or to call
`oblicz_macierz_dystans!` via a `StanSymulacji` constructor so the production
path is exercised).

## Info

### IN-01: TEST-08 ships with placeholder constants and `@test_broken` guard

**File:** `test/test_symulacja.jl:42-46, 159-167`
**File:** `test/_generuj_test08_refs.jl`

**Issue:** Per `deferred-items.md`, the TEST-08 golden values (`TRASA_REF`,
`ENERGIA_REF`) are intentionally placeholders (`Int[]` and `NaN`); the
golden-value asserts are wrapped in `@test_broken` until a Julia-equipped CI
run produces real values via `_generuj_test08_refs.jl`. Per the review
context note, this is informational only.

**Fix (informational):** When the first CI run with Julia available executes,
follow the procedure in the top-of-file comment block of `test_symulacja.jl`:
1. Run `julia --project=. test/_generuj_test08_refs.jl`
2. Paste the two `const` lines into `test_symulacja.jl`
3. Delete `test/_generuj_test08_refs.jl`
4. Verify `grep -cE 'TRASA_REF = Int\[\]|ENERGIA_REF = NaN|TRASA_REF = \[\]' test/test_symulacja.jl` returns 0.

The placeholder gate and `@test_broken` mechanism are sound; this is a tracking
note, not a bug.

---

### IN-02: `kalibruj_T0` allocates `worsening` vector — not zero-alloc

**File:** `src/energia.jl:172-188`

**Issue:** `worsening = Float64[]; sizehint!(worsening, n_probek); push!(worsening, ...)`.
Each `push!` may grow the buffer. Total: O(n_probek) allocs amortized, plus
one heap object for the buffer. Not in any zero-alloc contract (`kalibruj_T0`
is called once at construction), but it's a sharp contrast with the
zero-alloc `delta_energii` it shells out to.

**Fix (optional):** Pre-allocate to fixed capacity and track length manually:
```julia
worsening = Vector{Float64}(undef, n_probek)
count = 0
for _ in 1:n_probek
    ...
    if delta > 0.0
        count += 1
        worsening[count] = delta
    end
end
@assert count >= 2 "need at least 2 worsening samples for std()"
sigma = std(@view worsening[1:count])
```

---

### IN-03: Polish-language comments mix encodings within a single file

**File:** `src/algorytmy/simulowane_wyzarzanie.jl` (no diacritics: "wyzarzanie", "petli")
**File:** `src/typy.jl` (with diacritics: "wyłącznie", "działa", "domyślnie")
**File:** `src/energia.jl` (mixed)
**File:** `test/test_symulacja.jl` (no diacritics)

**Issue:** Some files use full Polish diacritics ("wyłącznie", "kolejność"),
others use ASCII-folded forms ("wylacznie", "kolejnosc"). The encoding hygiene
test verifies UTF-8 well-formedness and NFC normalization, but does not enforce
consistent presence of diacritics. This is purely a style/consistency issue —
no bug.

**Fix (cosmetic):** Pick one convention and apply it. Per `CLAUDE.md` ("Język
UI/komentarzy: wyłącznie polski"), full Polish with diacritics is the project
norm; the no-diacritics files should be normalized.

---

### IN-04: `runtests.jl` Aqua call has structural duplicate-key risk

**File:** `test/runtests.jl:215-216`

**Issue:** The `deps_compat` kwarg is built as:
```julia
deps_compat = (ignore = [:Random, :Statistics],
               check_extras = (ignore = [:Test, :Unicode],)),
```
This puts `check_extras` *inside* `deps_compat`'s NamedTuple — but `check_extras`
is its own top-level Aqua check, not a sub-key of `deps_compat`. Aqua will
silently ignore the misplaced `check_extras` config and run its check with
defaults (which then fails — see BL-02).

**Fix:** Hoist `check_extras` to the top level:
```julia
Aqua.test_all(JuliaCity;
    ambiguities = (recursive = false,),
    stale_deps  = false,
    deps_compat = (ignore = [:Random, :Statistics],),
    check_extras = (ignore = [:Test, :Unicode, :BenchmarkTools, :GLMakie, :Makie, :Observables],),
)
```

---

### IN-05: `inicjuj_nn!` allocates a fresh `bufor` each call — accept or document

**File:** `src/baselines.jl:95-102`

**Issue:** `bufor = zeros(Float64, Threads.nthreads())` allocates a
`nthreads()`-element vector on every call. The comment says
"alloc OK — wywoływane raz". Acceptable for one-shot init, but if a future
caller uses `inicjuj_nn!` to *reset* a stan multiple times (e.g., random restart
SA), the alloc compounds.

**Fix (optional):** Accept a pre-allocated `bufor`:
```julia
function inicjuj_nn!(stan::StanSymulacji;
                     bufor::Vector{Float64}=zeros(Float64, Threads.nthreads()))
    oblicz_macierz_dystans!(stan)
    stan.trasa = trasa_nn(stan.D; start=1)
    stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
    stan.iteracja = 0
    return nothing
end
```

---

_Reviewed: 2026-04-29_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
