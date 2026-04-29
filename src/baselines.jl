# NN-baseline (Nearest Neighbor) tour + mutating Stan initializer.
# Pokrywa REQ ALG-04. Dwa entry points (D-14):
#   - trasa_nn(D; start) — pure, używana w TEST-05 NN-baseline-beat bez Stana
#   - inicjuj_nn!(stan) — mutating wrapper, wypełnia stan.D + stan.trasa + stan.energia
# NN nie jest <:Algorytm (brak symuluj_krok!) — dlatego src/baselines.jl, nie src/algorytmy/.
# start=1 zawsze (D-15) — brak RNG-zależności; test NN-baseline-beat porównuje
# SA-z-start=1 vs NN-z-start=1, więc determinizm baseline jest kluczowy.
# Asercje wewnętrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# Zależności (`StanSymulacji`, `oblicz_macierz_dystans!`, `oblicz_energie`) są
# w scope'ie modułu — typy.jl + energia.jl są include-owane wcześniej w JuliaCity.jl.

"""
    trasa_nn(D::Matrix{Float64}; start::Int=1) -> Vector{Int}

Greedy Nearest-Neighbor tour z pre-policzoną macierzą dystansów `D`.
Startuje od węzła `start`, w każdym kroku wybiera najbliższego nieodwiedzonego
sąsiada (argmin po `D[bieżący, j]` dla `j` jeszcze poza trasą). Zwraca
permutację `1:n` (cykl Hamiltona) — `sort(trasa_nn(D)) == 1:n`.

Pure funkcja — nie wymaga `StanSymulacji`. Używana w `inicjuj_nn!` (jako krok
2 inicjalizacji SA, D-14) oraz niezależnie w teście NN-baseline-beat (TEST-05),
gdzie SA musi zwrócić trasę co najmniej 10% krótszą niż NN dla N=1000.

`start=1` jest deterministyczne (D-15) — brak RNG-zależności; baseline ma być
porównywalny pomiędzy uruchomieniami. Złożoność: O(n²) (n iteracji × n-search).

Pokrywa REQ ALG-04 (entry point pure, używany niezależnie od Stana).

# Examples
```jldoctest
julia> using JuliaCity

julia> pkty = [Punkt2D(0.0, 0.0), Punkt2D(1.0, 0.0), Punkt2D(1.0, 1.0), Punkt2D(0.0, 1.0)];

julia> stan = StanSymulacji(pkty);

julia> oblicz_macierz_dystans!(stan);

julia> trasa = trasa_nn(stan.D; start=1);

julia> sort(trasa) == [1, 2, 3, 4]
true
```

# Argumenty
- `D::Matrix{Float64}` — n×n macierz dystansów (zwykle z `oblicz_macierz_dystans!`)
- `start::Int` (kwarg) — indeks startowego węzła, `1 <= start <= n`, domyślnie `1` (D-15)
"""
function trasa_nn(D::Matrix{Float64}; start::Int=1)::Vector{Int}
    n = size(D, 1)
    @assert n == size(D, 2) "D must be square"
    @assert 1 <= start <= n "start out of range"
    odwiedzone = falses(n)
    trasa = Vector{Int}(undef, n)
    trasa[1] = start
    odwiedzone[start] = true
    @inbounds for k in 2:n
        biezacy = trasa[k - 1]
        # argmin po D[biezacy, j] dla j jeszcze nie-odwiedzonego
        najblizszy = 0
        min_dist = Inf
        for j in 1:n
            if !odwiedzone[j] && D[biezacy, j] < min_dist
                min_dist = D[biezacy, j]
                najblizszy = j
            end
        end
        trasa[k] = najblizszy
        odwiedzone[najblizszy] = true
    end
    return trasa
end

"""
    inicjuj_nn!(stan::StanSymulacji) -> Nothing

Mutujący wrapper który przygotowuje `stan` do startu SA: wypełnia macierz
dystansów, ustawia trasę NN-baseline, oblicza energię i resetuje licznik
iteracji. Wykonuje 4 kroki w zafiksowanej kolejności (D-14):

1. `oblicz_macierz_dystans!(stan)` — wypełnia `stan.D` (symetryczne dystanse euklidesowe)
2. `stan.trasa = trasa_nn(stan.D; start=1)` — NN tour z `start=1` (D-15)
3. `stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)` — cache invariant SA (D-08)
4. `stan.iteracja = 0` — reset licznika

Wywoływana raz przed pętlą SA. Alokuje świeży `bufor` długości `Threads.nthreads()`
— akceptowalne, bo to jednorazowa inicjalizacja (NIE hot path).

Pokrywa REQ ALG-04 (entry point mutujący, integruje NN do flow inicjalizacji Stana).

# Argumenty
- `stan::StanSymulacji` — stan po konstrukcji (pre-alokowane `D` + `trasa = collect(1:n)`)
"""
function inicjuj_nn!(stan::StanSymulacji)
    oblicz_macierz_dystans!(stan)                          # wypełnia stan.D
    stan.trasa = trasa_nn(stan.D; start=1)                 # D-15: start=1 deterministycznie
    bufor = zeros(Float64, Threads.nthreads())             # alloc OK — wywoływane raz
    stan.energia = oblicz_energie(stan.D, stan.trasa, bufor)
    stan.iteracja = 0
    return nothing
end
