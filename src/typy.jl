# Typy domenowe pakietu JuliaCity
# - Punkt2D: alias na Point2{Float64} z GeometryBasics
# - Algorytm: abstract type — extension point dla Holy-traits dispatch (Phase 2+)
# - StanSymulacji: parametryczny mutable struct ze stanem SA

# Zależności są importowane raz w src/JuliaCity.jl (using GeometryBasics: Point2; using Random).
# Tutaj zakładamy ich dostępność w scope'ie modułu.

"""
    Punkt2D

Alias na `Point2{Float64}` z `GeometryBasics`. Float64 dla precyzji sumy
~1000 odległości euklidesowych w `oblicz_energie` (Phase 2). Bezpośrednio
konsumowany przez Makie scatter w Phase 3 — zero-cost konwersja.

Akcesory: `p.x`, `p.y`, `p[1]`, `p[2]` (z GeometryBasics — własnych nie definiujemy).
"""
const Punkt2D = Point2{Float64}

"""
    Algorytm

Abstract type — wszystkie konkretne algorytmy (`SimAnnealing`, `ForceDirected`,
`Hybryda`) są podtypami dodawanymi w `src/algorytmy/`. Extension point dla
Holy-traits dispatch w `symuluj_krok!`. Phase 1 deklaruje typ; Phase 2 wprowadza
`struct SimAnnealing <: Algorytm` (REQ ALG-01).
"""
abstract type Algorytm end

"""
    StanSymulacji{R<:AbstractRNG}

Stan symulacji TSP. Parametryzacja po typie RNG umożliwia type-stable dispatch
na operacjach próbkowania (Pitfall 1 z PITFALLS — abstract field type powoduje
type instability; konkret w polu `R<:AbstractRNG` ją eliminuje).

# Pola const (ustawiane raz w konstruktorze, niezmienne potem)
- `punkty::Vector{Punkt2D}` — punkty 2D w `[0,1]²`
- `D::Matrix{Float64}` — n×n macierz dystansów (pre-alokowana, wypełniana przez Phase 2)
- `rng::R` — lokalny RNG dla deterministycznej akceptacji Metropolisa

# Pola mutable (aktualizowane przez `symuluj_krok!` w Phase 2)
- `trasa::Vector{Int}` — permutacja `1:n` reprezentująca cykl Hamiltona
- `energia::Float64` — bieżąca długość trasy (cache; Phase 2 utrzymuje invariant)
- `temperatura::Float64` — bieżąca temperatura SA
- `iteracja::Int` — licznik kroków
"""
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}
    const D::Matrix{Float64}
    const rng::R
    trasa::Vector{Int}
    energia::Float64
    temperatura::Float64
    iteracja::Int
end

"""
    StanSymulacji(punkty; rng=Xoshiro(42))

Konstruktor zewnętrzny — pre-alokuje `D` (n×n, niewypełnione przez `undef`) oraz
`trasa = collect(1:n)`. Wartości pozostałych pól zerowe.

Phase 2 doda funkcje `oblicz_macierz_dystans!(stan)` i `inicjuj_nn!(stan)` które
wypełnią `D` i przepiszą `trasa` na NN-tour — ten konstruktor pozostaje
niezmieniony (D-07: zero-state).

Argumenty:
- `punkty::Vector{Punkt2D}` — wymagane, `length(punkty) > 0`
- `rng::R` (kwarg) — domyślnie `Xoshiro(42)` (deterministyczne testy)
"""
function StanSymulacji(punkty::Vector{Punkt2D}; rng::R=Xoshiro(42)) where {R<:AbstractRNG}
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))   # asercja po angielsku (D-23, LANG-04)
    D = Matrix{Float64}(undef, n, n)
    trasa = collect(1:n)
    return StanSymulacji{R}(punkty, D, rng, trasa, 0.0, 0.0, 0)
end
