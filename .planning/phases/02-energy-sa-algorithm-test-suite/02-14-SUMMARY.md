# Plan 02-14 — Summary

**Phase:** 02 (energy-sa-algorithm-test-suite)
**Plan:** 14 (gap-closure: TEST-05 NN-baseline-beat algorithm decision)
**Wave:** 11
**Depends on:** 02-13 (Aqua compat, TEST-08 refs, Manifest regen)
**Type:** execute (3-fazowy: empirical diagnosis → decision → implementation)
**Status:** ✅ COMPLETE
**Date:** 2026-04-30
**Julia:** 1.12.6 (lokalnie)

## Streszczenie

TEST-05 (NN-baseline-beat — SA ≥10% pod NN dla N=1000, seed=42) FAIL od planu 02-13 (handoff dd65a35) — SA z domyślnym `kalibruj_T0=2σ` aktywnie *pogarszał* NN tour (ratio 1.65 po 200_000 krokach).

Plan 02-14 przeprowadził **trzy fazy diagnostyczne** (`bench/diagnostyka_test05*.jl`) potwierdzając że problem jest **algorytmiczny, nie parametryczny** — pure 2-opt SA na N=1000 NN-start plateauje przy ratio ≈ 0.92 (2-opt local minimum). Wszystkie zaprojektowane techniki kalibracji (B1 fixed T₀ kwarg, B2 Ben-Ameur iterative, B3 closed-form target acceptance) zostały **empirycznie obalone** — żadna nie schodzi pod ratio 0.92.

Decyzja **opcja X** (user choice po przedstawieniu trade-offów): zluźnić ROADMAP SC #4 z "≥10%" na "≥5%" (ratio ≤ 0.95). Phase 2 zamknięta z TEST-05 PASS przy `T_zero=0.001` + 125_000 kroków, ratio **0.9408** (margin +0.009 do progu 0.95). Plan 02-15 (double-bridge perturbation à la LKH dla ratio < 0.9) **zatrzymany jako deferred** — Phase 3 (wizualizacja, core value projektu) ma priorytet.

## Faza A — empirical diagnosis (4 sub-fazy)

### A.1 — sweep T₀ na NN-start (50k + 200k kroków)

| T₀ | 50k ratio | 200k ratio |
|----|-----------|------------|
| 0.001 | 0.9672 | **0.9248** ← global best |
| 0.005 | 0.9696 | 0.9309 |
| 0.01  | 0.9684 | 0.9272 |
| 0.02  | 0.9718 | 0.9314 |
| 0.05  | 1.0340 | — |
| 0.10  | 1.4540 | — |
| 0.50  | 3.5310 | — |
| 1.028 (kalibruj_T0=2σ) | 4.0188 | — |

### A.2 — kandydaci B3 (target acceptance closed-form)

T₀ = -mean(positive)/ln(χ₀):
- χ₀=0.5 → T₀=1.39
- χ₀=0.6 → T₀=1.88
- χ₀=0.8 → T₀=4.31

**Wszystkie wyższe niż T₀_calibrated=1.03** → przewidywany ratio ≥ 4. **B3 obalone.**

### A.3 — random start vs NN start

| Setup | 50k | 200k |
|-------|-----|------|
| Random + 2σ T₀ | 3.71 | 1.65 |
| Multi-start 5× random + 2σ, 50k each | best 3.63 | — |
| **NN + T₀=0.001** | **0.9672** | **0.9248** |

NN-init jednoznacznie wygrywa. Random start nawet w 200k jest 80% gorszy. Multi-start nie pomaga.

### A.4 — budget sweep dla T₀=0.001

| Budget | Ratio | Margin do 0.95 | Status |
|--------|-------|----------------|--------|
| 50_000  | 0.9672 | -0.017 | FAIL |
| 75_000  | 0.9599 | -0.010 | FAIL |
| 100_000 | 0.9493 | +0.0007 | PASS (cienki margin) |
| **125_000** | **0.9408** | **+0.0092** | **PASS** ← wybrane |
| 150_000 | 0.9349 | +0.015 | PASS |
| 200_000 | 0.9248 | +0.025 | PASS |

## Faza B — decyzja

Hipotezy planu 02-14-PLAN.md (B1/B2/B3) **wszystkie odrzucone empirycznie**. Trzy ścieżki rzeczywiste przedstawione userowi:

- **Opcja X**: zluźnić ratio ≤ 0.95 (≥5% pod NN). 1 linia w teście, runtime ~20s. Update ROADMAP SC #4.
- **Opcja Y**: zluźnić ratio ≤ 0.93 + budżet 200k. Runtime ~60s.
- **Opcja Z**: plan 02-15 z double-bridge perturbation. 1–2 dni roboczych. Niepewne czy zejdzie pod 0.9.

**User wybrał X.** Uzasadnienie: PROJECT.md core value to wizualizacja, nie ostatnie 5%; SA bije NN realnie (~5.9%); Phase 3 ma priorytet.

## Faza C — implementacja

### Zmiany kodu

**`test/test_baselines.jl`** linie 86–127 (TEST-05):
```julia
# Przed:
alg = SimAnnealing(stan)                # 2σ kalibracja → ratio 4 dla NN-start
params = Parametry(liczba_krokow=200_000)
@test stan.energia / energia_nn <= 0.9  # nieosiągalne

# Po:
alg = SimAnnealing(stan; T_zero=0.001)   # NN-start specific override
params = Parametry(liczba_krokow=125_000)
@test stan.energia / energia_nn <= 0.95  # margin +0.009 (empirically: 0.9408)
```

**Komentarz odświeżony**: krótka diagnoza (Pitfall G level 2 history wycięty), referencja do plan 02-14 + 02-CONTEXT.md D-03 erratum.

**Nazwa testseta**: "SA ≥10% pod NN" → "SA ≥5% pod NN".

### Zmiany src/

**Brak.** `kalibruj_T0` (D-03 LOCKED) zostaje bez zmian — formuła 2σ jest **poprawna dla random startu** (oryginalna intencja Pitfall 11). NN-start używa override `T_zero=0.001`, który już był dozwolony przez D-03 ostatnie zdanie ("nadpisywalna ręcznie").

### Zmiany dokumentacji

- **`.planning/ROADMAP.md` SC #4**: "10%" → "**5%**" + dopisek o erratum + uzasadnienie (2-opt local minimum)
- **`.planning/REQUIREMENTS.md` TEST-05**: "10%" → "**5%**" + dopisek
- **`02-CONTEXT.md`**: dodano sekcję "D-03 erratum (plan 02-14)" z pełną empiryczną diagnozą (5 tabel z Faz A.1–A.4 + decyzja + future work)

### Nowe artefakty (zacommitowane)

- `bench/diagnostyka_test05.jl` — główny skrypt diagnostyczny (T₀ sweep × 8 kandydatów × {50k, 200k}, acceptance counters)
- `bench/diagnostyka_test05_random_vs_nn.jl` — porównanie random vs NN start + multi-start 5×
- `bench/diagnostyka_test05_budget.jl` — sweep budżetu kroków dla T₀=0.001

## Test Summary (Pkg.test, lokalnie Julia 1.12.6)

```
[ Info: TEST-05: NN energia=28.8502, SA energia=27.1433, ratio=0.9408

Test Summary: | Pass  Total     Time
JuliaCity     |  222    222  1m33.4s
     Testing JuliaCity tests passed
```

**222 / 222 PASS** — 0 FAIL, 0 ERROR, 0 BROKEN. Czas suite: 1m33s (vs 1m39s w planie 02-13 z TEST-05 FAIL — niezauważalna zmiana mimo zwiększenia budżetu z 200k → 125k bo runtime zdominowany jest przez Aqua + JET).

**Ratio 0.9408** — dokładnie na targecie z Faza A.4 (przewidywano 0.9408 ± noise). Margin do 0.95 = 0.009 (~1%) — bezpieczny dla cross-version Julia drift.

## Phase 2 closure

Wszystkie 21 REQ-IDów Phase 2 **runtime-verified**:

- ENE-01..05 — energia hot path ✓
- ALG-01..08 — SA algorithm ✓
- TEST-01..08 — test suite ✓ (TEST-05 z erratum: 5% nie 10%, udokumentowane w ROADMAP/REQUIREMENTS/CONTEXT)

**ROADMAP success criteria 1–5** wszystkie spełnione:
1. ✓ `oblicz_energie` correct + type-stable + `<4096B` allocations
2. ✓ `symuluj_krok!` type-stable + `@allocated == 0` + Hamilton invariant
3. ✓ Determinizm wieloraetkowy (TEST-04, JULIA_NUM_THREADS=1 vs 12)
4. ✓ SA ≥**5%** pod NN (ratio 0.9408 < 0.95) — zluźnione z 10% per plan 02-14
5. ✓ `Pkg.test()` exit 0, 222 PASS, 0 fail/error/broken

## Deferred (poza scope v1)

- **Plan 02-15**: double-bridge perturbation lub or-opt move dla ratio < 0.9 (LKH-style stronger move). Estymacja 1–2 dni; zostawione na v2 lub gdy user wprost zechce.

## Pointer

**Phase 2 → COMPLETE. Następny krok: Phase 3 (visualization & export).**

Sugerowany start: `/gsd-discuss-phase 3` (lub `/gsd-plan-phase 3` przy mniej wątpliwości designerskich).
