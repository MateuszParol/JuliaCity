# Plan 02-14 — Decyzja Faza B (po empirycznej diagnozie Fazy A)

## Kontekst

Plan 02-14-PLAN.md zaproponował 3 hipotezy techniczne (B1/B2/B3) dla naprawy TEST-05 (NN-baseline-beat). Faza A (`bench/diagnostyka_test05.jl` + `_random_vs_nn.jl` + `_budget.jl`) **obaliła wszystkie trzy hipotezy** — żadna kalibracja T₀ na pure 2-opt SA na N=1000 NN-start nie schodzi pod ratio 0.92.

## Dane decyzyjne (Faza A summary)

**A.1 — sweep T₀, 50k i 200k kroków, NN-start:**
| T₀ | 50k ratio | 200k ratio |
|----|-----------|------------|
| 0.001 | 0.9672 | **0.9248** ← global best |
| 0.01  | 0.9684 | 0.9272 |
| 0.05  | 1.0340 | — |
| 1.028 (2σ kalibruj_T0) | 4.0188 | — |

**A.2 — kandydaci B3 (target acceptance closed-form):** T₀ = -mean(positive)/ln(χ₀), χ₀ ∈ {0.5, 0.8} → T₀ ∈ {1.39, 4.31}. Empirycznie **gorsze** niż T₀_calibrated = 1.03.

**A.3 — random start vs NN start:**
| Setup | 50k | 200k |
|-------|-----|------|
| Random + 2σ | 3.71 | 1.65 |
| Multi-start 5× random + 2σ, 50k each | 3.63 | — |
| NN + T₀=0.001 | **0.9672** | **0.9248** |

**A.4 — budget sweep dla T₀=0.001:**
| Budget | Ratio | Margin do 0.95 |
|--------|-------|----------------|
| 50_000  | 0.9672 | -0.017 FAIL |
| 75_000  | 0.9599 | -0.010 FAIL |
| 100_000 | 0.9493 | +0.0007 PASS (cienki) |
| **125_000** | **0.9408** | **+0.0092 PASS** ← wybrane |
| 150_000 | 0.9349 | +0.015 |
| 200_000 | 0.9248 | +0.025 |

## Decyzja: opcja X (zluźnienie celu z 10% → 5%)

Hipotezy B1/B2/B3 wszystkie **odrzucone** — pure 2-opt SA na N=1000 NN-start plateauje przy ratio ≈ 0.92, co jest 2-opt local minimum. Cel oryginalny ratio ≤ 0.9 wymaga stronger move (3-opt / or-opt / double-bridge perturbation à la LKH), poza scope v1.

User wybrał **opcję X**: zluźnić ROADMAP SC #4 z "≥10%" na "≥5%" (ratio ≤ 0.95). Uzasadnienie:
1. PROJECT.md core value to **wizualizacja**, nie ostatnie 5% optymalności.
2. SA bije NN o ~5.9% (T₀=0.001, 125k kroków) — realne ulepszenie, nie placebo.
3. Wizualnie animacja "trasa się zaciska" działa identycznie przy ratio 0.92 i 0.85.
4. Phase 3 (GLMakie + animacja) ma priorytet — opcja Z (plan 02-15 z double-bridge) blokowałaby Phase 3 o ~1-2 dni roboczych.

## Szczegóły implementacji (Faza C)

### Zmiany kodu

**`test/test_baselines.jl`** (linie 86–127, TEST-05 testset):
- `alg = SimAnnealing(stan)` → `alg = SimAnnealing(stan; T_zero=0.001)` — override T₀ specyficzny dla NN-start
- `liczba_krokow=200_000` → `liczba_krokow=125_000` — margin +0.009 do progu 0.95
- `<= 0.9` → `<= 0.95` — nowy próg
- Komentarz odświeżony: empirical diagnosis summary + odsyłacz do 02-CONTEXT D-03 erratum
- Nazwa testseta: "SA ≥10%" → "SA ≥5%"

**`src/`**: brak zmian. Public API `SimAnnealing(stan; T_zero=...)` już dozwala override (D-03 ostatnie zdanie). `kalibruj_T0` zostaje bez zmian (D-03 LOCKED nadal obowiązuje dla random startu).

### Zmiany dokumentacji

- **`.planning/ROADMAP.md` SC #4**: "co najmniej 10%" → "co najmniej **5%**" + dopisek o erratum
- **`.planning/REQUIREMENTS.md` TEST-05**: "co najmniej 10%" → "co najmniej **5%**" + dopisek
- **`.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md`**: dodano sekcję "D-03 erratum (plan 02-14)" z pełną empiryczną diagnozą + tabelami z Faz A.1–A.4

### Artefakty nowe

- `bench/diagnostyka_test05.jl` — główny skrypt diagnostyczny (sweep T₀, mini-runy SA, acceptance counters)
- `bench/diagnostyka_test05_random_vs_nn.jl` — porównanie random vs NN start
- `bench/diagnostyka_test05_budget.jl` — sweep budżetu dla T₀=0.001

## Future work (deferred)

Plan 02-15 (v2 lub gdy ktoś zechce ratio ≤ 0.9):
- **Double-bridge perturbation** po stagnation patience (LKH-style restart-on-stagnation)
- **Or-opt move** (przesunięcie 1–3 elementów segmentu, wyrywa z 2-optimum)
- **3-opt move** (full 3-edge swap, drogi ale potężny)

Estymacja: 1–2 dni roboczych. Zatrzymane jako deferred — Phase 3 ma priorytet.
