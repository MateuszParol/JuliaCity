# Archiwum diagnostyki Phase 2 (plan 02-14 erratum)

Trzy pliki w tym katalogu pochodzą z Phase 2 plan 02-14 — empirycznej diagnozy
dlaczego pure 2-opt SA na N=1000 NN-start plateauje przy `ratio ≈ 0.92` zamiast
osiągnąć pierwotnie zakładane `ratio ≤ 0.9` (cel ROADMAP SC #4 zluźniony 10% → 5%).

## Pliki

| Plik | Przeznaczenie |
|------|---------------|
| `diagnostyka_test05.jl` | Sweep candidate `T_zero` × budget krokow; pokazuje że nawet `T_zero=10⁻⁶` przy 50 000 krokow plateauje przy `ratio ≈ 0.94`. |
| `diagnostyka_test05_budget.jl` | Sweep budgetu krokow (50 000 → 250 000) dla `T_zero=0.001` — potwierdza brak dalszej poprawy po ~125 000 krokow. |
| `diagnostyka_test05_random_vs_nn.jl` | Porównanie SA z random-start vs NN-start — pokazuje że random-start z full 2σ kalibracją osiąga `ratio ≈ 0.97` (gorzej niż NN-start, dlatego TEST-05 hardcoduje `T_zero=0.001`). |

## Wynik diagnozy

Pure 2-opt SA z NN-start jest w lokalnym minimum 2-opt graph'u. Cel `ratio ≤ 0.9`
wymagałby silniejszego ruchu (3-opt, or-opt, double-bridge perturbation) — poza scope v1.
ROADMAP SC #4 zluźniony do `≥ 5%` shorter than NN baseline; TEST-05 lock = `ratio = 0.9408`.

Pełen kontekst: `.planning/phases/02-energy-sa-algorithm-test-suite/02-14-SUMMARY.md`.

## Uruchomienie (jeśli potrzeba reprodukcji)

```bash
julia --project=. --threads=auto bench/historyczne/diagnostyka_test05.jl
```

Skrypty są **niezależne od `bench/run_all.jl`** (Phase 4 D-16) — orchestrator ich nie wywołuje.
