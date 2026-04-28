# Generator losowych punktów testowych — pokrywa REQ PKT-01..04.
# Lokalny Xoshiro, brak mutacji Random.default_rng() (PKT-04, D-14).
# Dwie metody (D-11) — friendly default + composable.

"""
    generuj_punkty(n::Int=1000; seed::Integer=42) -> Vector{Punkt2D}

Generuje `n` losowych punktów 2D w `[0,1]²` używając lokalnego `Xoshiro(seed)`.
Domyślnie `n = 1000` (PKT-02), `seed = 42` (D-12). Deterministyczne dla danego
seeda — wielokrotne wywołania z tym samym seedem zwracają identyczne wektory.

NIE modyfikuje globalnego stanu PRNG (`Random.default_rng()`) — patrz PKT-04.
Test izolacji w `test/runtests.jl` (Phase 1 plan 06).

# Examples
```jldoctest
julia> punkty = generuj_punkty(3; seed=42);

julia> length(punkty)
3

julia> all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, punkty)
true

julia> generuj_punkty(3; seed=42) == generuj_punkty(3; seed=42)
true
```
"""
function generuj_punkty(n::Int=1000; seed::Integer=42)
    n > 0 || throw(ArgumentError("n must be positive"))   # asercja po angielsku (LANG-04)
    rng = Xoshiro(seed)
    return generuj_punkty(n, rng)
end

"""
    generuj_punkty(n::Int, rng::AbstractRNG) -> Vector{Punkt2D}

Wariant composable — testy mogą podać własny `StableRNG(42)` (Phase 2) dla
cross-version reproducibility (Pitfall 8 z PITFALLS — `Xoshiro` stream NIE jest
stabilny między minor versions Julii).

Argumenty:
- `n::Int` — liczba punktów, `n > 0` (rzuca `ArgumentError` w przeciwnym razie)
- `rng::AbstractRNG` — instancja RNG (np. `Xoshiro(42)`, `StableRNG(42)`)
"""
function generuj_punkty(n::Int, rng::AbstractRNG)
    n > 0 || throw(ArgumentError("n must be positive"))
    # D-13: rand(rng, Punkt2D, n) — Punkt2D dziedziczy z StaticVector przez GeometryBasics,
    # więc StaticArrays daje rand metodę zwracającą Vector{Point2{Float64}}.
    # ASUMPCJA A1 (research-flagged): jeśli rand zwraca Vector{SVector{...}} zamiast
    # Vector{Point2{Float64}}, smoke test w plan 06 wykryje regresję — wówczas
    # zamień na fallback: `[Punkt2D(rand(rng), rand(rng)) for _ in 1:n]`.
    return rand(rng, Punkt2D, n)
end
