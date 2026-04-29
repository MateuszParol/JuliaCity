# Energia trasy + macierz dystansów + delta 2-opt + kalibracja T0.
# Pokrywa REQ ENE-01..05 + ALG-05.
# Threadowane przez Threads.@threads :static + ChunkSplitters (D-11).
# Hot path (delta_energii) jest single-threaded i O(1) (D-08).
# Asercje wewnętrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# Zależności (`ChunkSplitters`, `Statistics: std`) są importowane raz w
# src/JuliaCity.jl — tutaj zakładamy ich dostępność w scope'ie modułu.

"""
    oblicz_macierz_dystans!(stan::StanSymulacji) -> Nothing

Wypełnia pre-alokowaną macierz `stan.D` (n×n) symetrycznymi euklidesowymi
odległościami między `stan.punkty[i]` a `stan.punkty[j]`. Iteracja po górnym
trójkącie (i in 1:j-1), kopiowanie `D[i,j] = D[j,i] = d`, zerowa diagonala.

Wywoływana raz po konstrukcji `StanSymulacji` (lub po podmianie `punkty`,
choć pole jest `const`). `delta_energii` korzysta z tej macierzy w hot-path
2-opt (D-06) — bez precompute miałby `sqrt` w każdej iteracji.

Pokrywa kontekst dla REQ ENE-04 (delta_energii potrzebuje gotowej D).
Patrz też PROJECT.md "Distance matrix precompute" decision (Phase 1 D-08).

# Argumenty
- `stan::StanSymulacji` — stan z pre-alokowaną `stan.D` o rozmiarze n×n
"""
function oblicz_macierz_dystans!(stan::StanSymulacji)
    n = length(stan.punkty)
    @assert size(stan.D) == (n, n) "D dimension mismatch"
    @inbounds for j in 1:n
        for i in 1:j-1
            p_i = stan.punkty[i]
            p_j = stan.punkty[j]
            dx = p_i[1] - p_j[1]
            dy = p_i[2] - p_j[2]
            d = sqrt(dx * dx + dy * dy)
            stan.D[i, j] = d
            stan.D[j, i] = d
        end
        stan.D[j, j] = 0.0
    end
    return nothing
end

"""
    oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int}) -> Float64

Public 2-arg wariant — buduje lokalną macierz dystansów `D` (n×n) i lokalny
`bufor` (length = `Threads.nthreads()`), po czym deleguje do hot-path
3-arg metody. Alokuje O(n² + nthreads) Float64 (D-10) — OK dla użycia
poza pętlą SA (np. assert cache invariant w testach, smoke check).

Pokrywa REQ ENE-01 (długość cyklu Hamiltona = suma euklidesowych
odległości między kolejnymi `punkty[trasa[k]]` i `punkty[trasa[k+1]]`,
z zamknięciem `mod1(k+1, n)`).

# Examples
```jldoctest
julia> using JuliaCity

julia> pkty = [Punkt2D(0.0, 0.0), Punkt2D(1.0, 0.0), Punkt2D(1.0, 1.0), Punkt2D(0.0, 1.0)];

julia> isapprox(oblicz_energie(pkty, [1, 2, 3, 4]), 4.0; atol=1e-12)
true
```

# Argumenty
- `punkty::Vector{Punkt2D}` — wektor punktów 2D, `length(punkty) > 0`
- `trasa::Vector{Int}` — permutacja `1:n` reprezentująca cykl Hamiltona
"""
function oblicz_energie(punkty::Vector{Punkt2D}, trasa::Vector{Int})::Float64
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))
    length(trasa) == n || throw(ArgumentError("trasa length mismatch"))
    D = Matrix{Float64}(undef, n, n)
    @inbounds for j in 1:n
        for i in 1:j-1
            p_i = punkty[i]
            p_j = punkty[j]
            dx = p_i[1] - p_j[1]
            dy = p_i[2] - p_j[2]
            d = sqrt(dx * dx + dy * dy)
            D[i, j] = d
            D[j, i] = d
        end
        D[j, j] = 0.0
    end
    bufor = zeros(Float64, Threads.nthreads())
    return oblicz_energie(D, trasa, bufor)
end

"""
    oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64}) -> Float64

Hot-path 3-arg wariant — zero-alloc po rozgrzewce z pre-alokowanym `bufor`.
Threadowany przez `Threads.@threads :static` + `ChunkSplitters.chunks` (D-11),
gdzie `nchunks = length(bufor)` (zwykle = `Threads.nthreads()`). Każdy chunk
sumuje swoje krawędzie do `bufor[chunk_idx]` (Pitfall 2: nie reasignujemy
captured scalar — używamy indexed accumulator). Końcowe `sum(bufor)` agreguje.

Pokrywa REQ ENE-02 (threadowana suma) + REQ ENE-03 (zero-alloc po rozgrzewce
z pre-alokowanym buforem) + REQ ENE-05 (`mod1` zamknięcie cyklu) + ENE-01.

# Argumenty
- `D::Matrix{Float64}` — n×n macierz dystansów (z `oblicz_macierz_dystans!`)
- `trasa::Vector{Int}` — permutacja `1:n`
- `bufor::Vector{Float64}` — pre-alokowany akumulator per-chunk (length = nchunks)
"""
function oblicz_energie(D::Matrix{Float64}, trasa::Vector{Int}, bufor::Vector{Float64})::Float64
    n = length(trasa)
    nchunks = length(bufor)
    fill!(bufor, 0.0)
    # BL-04 fix (gap-closure 02-10): kanoniczny chunked-threading pattern.
    # Pre-fix wzorzec `Iterators.Enumerate` nad `chunks(...)` byl non-canonical —
    # `Threads.@threads` (Julia 1.10) wymaga indexable iteratora; Enumerate nie
    # ma stabilnego getindex. Materializujemy chunki przez `collect` do Vector
    # UnitRange{Int} (length=nchunks <= nthreads(), ~128B alloc miesci sie w
    # ENE-03 threshold <4096B). Indexujemy przez `eachindex(cs)`.
    # D-11 LOCKED: ChunkSplitters preserved (NIE wracamy do threadid()).
    cs = collect(chunks(1:n; n=nchunks))
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

"""
    delta_energii(stan::StanSymulacji, i::Int, j::Int) -> Float64

Oblicza zmianę energii (długości trasy) dla 2-opt swap `[i+1 .. j]` reverse.
Implementacja O(1): tylko 4 lookupy w macierzy dystansów (D-06) — krawędzie
`(i, i+1)` i `(j, j+1)` znikają, krawędzie `(i, j)` i `(i+1, j+1)` powstają.
Wynik dodatni = pogorszenie, ujemny = poprawa.

Hot path SA — wywoływana ~50_000 razy per pełen run (Parametry.liczba_krokow,
D-02). Single-threaded (D-08). NIE używamy `@inbounds` (asercja sprawdza i, j;
Phase 4 może ewaluować elision).

Pokrywa REQ ENE-04. Cache invariant: `symuluj_krok!` utrzymuje
`stan.energia += delta_energii(...)` po akceptacji ruchu (D-08).

# Argumenty
- `stan::StanSymulacji` — stan z wypełnioną `stan.D` i poprawną `stan.trasa` (permutacja 1:n)
- `i::Int` — pierwsza pozycja swap, `1 <= i`
- `j::Int` — druga pozycja swap, `i < j <= n`
"""
function delta_energii(stan::StanSymulacji, i::Int, j::Int)::Float64
    n = length(stan.trasa)
    @assert 1 <= i < j <= n "i, j out of range"
    i_next = i + 1                  # i+1 <= j, więc bez wrap
    j_next = mod1(j + 1, n)         # jedyny edge case dla j == n
    t = stan.trasa
    D = stan.D
    return D[t[i],      t[j]]      + D[t[i_next], t[j_next]] -
           D[t[i],      t[i_next]] - D[t[j],      t[j_next]]
end

"""
    kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng) -> Float64

Auto-kalibracja temperatury startowej `T0` SA przez próbkowanie `n_probek`
losowych ruchów 2-opt (i, j) z `i < j` o odstępie `>= 2`. Zbiera dodatnie
delts (pogorszenia), liczy ich odchylenie standardowe σ i zwraca `2σ`
(Pitfall 11 + D-03). Skutek: początkowy acceptance ratio ≈ 60–80% dla
typowych pogorszeń, schemat chłodzenia α^N daje ~1% pod koniec (D-02).

Pokrywa REQ ALG-05.

# Argumenty
- `stan::StanSymulacji` — stan po `oblicz_macierz_dystans!` z `n >= 3`
- `n_probek::Int` (kwarg) — liczba próbek, domyślnie 1000
- `rng` (kwarg) — RNG do próbkowania, domyślnie `stan.rng` (D-09)
"""
function kalibruj_T0(stan::StanSymulacji; n_probek::Int=1000, rng=stan.rng)::Float64
    n = length(stan.trasa)
    @assert n >= 3 "need n >= 3 for 2-opt"
    worsening = Float64[]
    sizehint!(worsening, n_probek)
    for _ in 1:n_probek
        # BL-01 fix: 1:(n-2) zamiast 1:(n-1) - i=n-1 dawalo pusty (i+2):n range
        i = rand(rng, 1:(n - 2))
        j = rand(rng, (i + 2):n)
        delta = delta_energii(stan, i, j)
        if delta > 0.0
            push!(worsening, delta)
        end
    end
    @assert !isempty(worsening) "no worsening moves sampled"
    sigma = std(worsening)
    return 2.0 * sigma
end
