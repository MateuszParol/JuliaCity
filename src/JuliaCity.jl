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
using ChunkSplitters                       # Phase 2 (D-11) — chunked threading
using Statistics: std                      # Phase 2 — kalibruj_T0 używa std()

# Typy domenowe (Punkt2D, Algorytm, StanSymulacji, Parametry)
include("typy.jl")

# Generator punktów testowych (PKT-01..04)
include("punkty.jl")

# Energia + macierz dystansów + delta 2-opt + kalibracja T0 (REQ ENE-01..05 + ALG-05)
include("energia.jl")

# Baseline NN + mutujący inicjalizator Stana (REQ ALG-04)
include("baselines.jl")

# Algorytmy <:Algorytm (Holy-traits dispatch) — REQ ALG-01..03, ALG-06..08
include("algorytmy/simulowane_wyzarzanie.jl")

# Eksport publicznego API
export Punkt2D, StanSymulacji, Algorytm, generuj_punkty,
       Parametry, SimAnnealing,
       oblicz_macierz_dystans!, oblicz_energie, delta_energii, kalibruj_T0,
       trasa_nn, inicjuj_nn!,
       symuluj_krok!

end # module
