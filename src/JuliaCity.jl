"""
    JuliaCity

Pakiet rozwiązujący problem komiwojażera (TSP) heurystyką inspirowaną fizyką
błony mydlanej. Publiczne API:

- `generuj_punkty(n; seed)` — losowe punkty w `[0,1]²` (Phase 1)
- `Punkt2D` — alias na `Point2{Float64}` (Phase 1)
- `StanSymulacji(punkty; rng)` — stan symulacji (Phase 1, zero-state)
- `Algorytm` — abstract type, extension point dla wariantów (Phase 1)
- `oblicz_energie(punkty, trasa)` — długość cyklu (Phase 2)
- `symuluj_krok!(stan, params, alg)` — krok SA (Phase 2)
- `wizualizuj(stan, params, alg; ...)` — animacja GLMakie (Phase 3)

Phase 1 dostarcza tylko typy + `generuj_punkty`. Reszta dochodzi w fazach 2/3.
"""
module JuliaCity

# Zewnętrzne zależności runtime
using GeometryBasics: Point2
using Random

# Typy domenowe (Punkt2D, Algorytm, StanSymulacji)
include("typy.jl")

# Generator punktów testowych (PKT-01..04)
include("punkty.jl")

# Eksport publicznego API
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty

end # module
