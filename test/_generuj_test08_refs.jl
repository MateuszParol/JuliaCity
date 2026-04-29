# Helper script Task 3b: generuje TRASA_REF / ENERGIA_REF dla TEST-08.
# Uruchom: julia --project=. test/_generuj_test08_refs.jl
# Wpisz wyprintowane linie do test/test_symulacja.jl (zastepujac placeholdery
# `const TRASA_REF = Int[]` i `const ENERGIA_REF = NaN`).
# USUN ten plik po Task 3b (jest jednorazowy - regeneration jest deterministyczne).
#
# Procedura jest deterministyczna - dla danej wersji algorytmu (Plan 02-04) i tych
# samych argumentow (StableRNG(42), N=20, 1000 krokow, alfa=0.9999, cierpliwosc=5000)
# wartosci sa unikalne. Jezeli ALGORYTM SIE ZMIENI, wartosci sie zmienia - to jest
# INTENCJONALNY alarm regresji.

using JuliaCity
using StableRNGs

punkty = generuj_punkty(20, StableRNG(42))
stan = StanSymulacji(punkty; rng=StableRNG(42))
inicjuj_nn!(stan)
alg = SimAnnealing(stan; alfa=0.9999, cierpliwosc=5000)
stan.temperatura = alg.T_zero
params = Parametry(liczba_krokow=1000)
for _ in 1:1000
    symuluj_krok!(stan, params, alg)
end

# Format do copy-paste (zastapuje placeholdery w test/test_symulacja.jl):
println("const TRASA_REF = ", stan.trasa)
println("const ENERGIA_REF = ", stan.energia)
