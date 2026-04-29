# Wariant SimAnnealing - simulowane wyzarzanie (Simulated Annealing) z 2-opt + Metropolis.
# Pokrywa REQ ALG-01, ALG-02, ALG-03, ALG-06 (patience field), ALG-07, ALG-08.
#
# Hyperparametry zyja w SimAnnealing (D-01: algorytm-specyficzne).
# Parametry trzymaja pola niezalezne od algorytmu (D-01) - liczba_krokow.
# Outer loop w examples/Phase 4 + testy Plan 02-05 owns stop logic
# (cierpliwosc + liczba_krokow konsumowane tam).
#
# Hot path: symuluj_krok! type-stable, zero-alloc po rozgrzewce (TEST-03, ALG-03).
# Single master RNG: stan.rng - brak per-thread (D-09).
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# Zaleznosci (`StanSymulacji`, `Algorytm`, `Parametry`, `delta_energii`, `kalibruj_T0`)
# sa w scope'ie modulu - typy.jl + energia.jl sa include-owane wczesniej w JuliaCity.jl.

"""
    SimAnnealing <: Algorytm

Wariant Simulowane Wyżarzanie - geometric cooling z patience stop. Hyperparametry
zyja w strukturze (D-01) - Parametry trzyma pola niezalezne od algorytmu.

Wszystkie pola maja CONCRETE typy (Pitfall 1: abstract field type powoduje
type instability). Struct jest immutable - constructor reset stan.temperatura
musi byc wykonany przez callera (patrz konstruktor kwarg).

Pokrywa REQ ALG-01 (definicja struct + ALG <: Algorytm dla Holy-traits dispatch).

# Pola
- `T_zero::Float64`  - poczatkowa temperatura (kalibrowana przez `kalibruj_T0`, D-03)
- `alfa::Float64`    - wspolczynnik geometric cooling, default 0.9999 (D-02);
                       po N krokach: T(N) = T_zero * alfa^N
- `cierpliwosc::Int` - stagnation patience threshold, default 5000 (D-02);
                       outer loop konsumuje to pole (D-04: reset tylko przy Δ < 0)
"""
struct SimAnnealing <: Algorytm
    T_zero::Float64
    alfa::Float64
    cierpliwosc::Int
end

"""
    SimAnnealing(stan::StanSymulacji; alfa=0.9999, cierpliwosc=5000, T_zero=kalibruj_T0(stan))

Konstruktor zewnetrzny z auto-kalibracja temperatury startowej (REQ ALG-05).
Default kwarg `T_zero=kalibruj_T0(stan)` jest evaluated KAZDORAZOWO przy
wywolaniu bez explicit `T_zero` - wymaga ze stan ma juz wypelniona `stan.D`
(czyli caller wczesniej wywolal `inicjuj_nn!(stan)` lub `oblicz_macierz_dystans!(stan)`).

Realizuje D-03 (kalibruj_T0 w default kwarg konstruktora) + D-02 (defaults
alfa=0.9999, cierpliwosc=5000).

UWAGA: Po skonstruowaniu `SimAnnealing` caller MUSI ustawic `stan.temperatura =
alg.T_zero` przed pierwszym `symuluj_krok!` (SimAnnealing jest immutable struct
i nie wie o stan; sama konstrukcja nie modyfikuje stan.temperatura).

# Argumenty
- `stan::StanSymulacji`        - stan po `inicjuj_nn!` (D-14) - wypelniona stan.D
- `alfa::Float64` (kwarg)      - geometric cooling factor, default 0.9999 (D-02)
- `cierpliwosc::Int` (kwarg)   - patience threshold, default 5000 (D-02)
- `T_zero::Float64` (kwarg)    - startowa temperatura, default `kalibruj_T0(stan)` (D-03)
"""
function SimAnnealing(stan::StanSymulacji;
                      alfa::Float64=0.9999,
                      cierpliwosc::Int=5000,
                      T_zero::Float64=kalibruj_T0(stan))
    return SimAnnealing(T_zero, alfa, cierpliwosc)
end

"""
    symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing) -> Nothing

Wykonuje JEDEN krok Simulowanego Wyzarzania (2-opt + Metropolis acceptance +
geometric cooling). Mutuje `stan` in-place: `trasa` (przez reverse! na akceptacji),
`energia` (cache invariant D-08: += delta), `temperatura` (*= alfa po Metropolis,
przed iteracja D-04), `iteracja` (+= 1).

Hot path - wywolywany ~50_000 razy per pelen run SA. Type-stable, zero-alloc po
rozgrzewce (TEST-02, TEST-03, REQ ALG-03). Uzywa wylacznie `stan.rng` (single
master RNG per D-09; brak per-thread RNG).

Mechanika 2-opt (D-05/D-06/D-07 - LOCKED):
- `i = rand(stan.rng, 1:(n-1))`
- `j = rand(stan.rng, (i+2):n)` - wyklucza adjacent (j >= i+2)
- `delta = delta_energii(stan, i, j)`
- accept iff `delta < 0` OR `rand(stan.rng) < exp(-delta / stan.temperatura)`
- na akceptacji: `reverse!(view(stan.trasa, (i+1):j))` + `stan.energia += delta`

Po Metropolis: `stan.temperatura *= alg.alfa` (geometric cooling - D-04 timing),
`stan.iteracja += 1`. Hamilton invariant zachowany (REQ ALG-08): reverse! permutuje
fragment, sort(stan.trasa) == 1:n caly czas.

Outer loop (cierpliwosc + liczba_krokow stop) zyje w `uruchom_sa!` ponizej
i w examples/Phase 4 + testach Plan 02-05.

`params` jest argumentem przez interfejs (Holy-traits dispatch konsystencja),
ale NIE uzywany w samym kroku - patience i hard cap sa konsumowane przez outer loop.

Pokrywa REQ ALG-02 (jeden krok SA), ALG-03 (zero-alloc), ALG-07 (deterministyczny
dla single master seed), ALG-08 (Hamilton invariant).

# Argumenty
- `stan::StanSymulacji` - stan po `inicjuj_nn!` + `stan.temperatura = alg.T_zero`
- `params::Parametry`   - obecny dla interfejsu (NIE uzywany w pojedynczym kroku)
- `alg::SimAnnealing`   - `alg.alfa` konsumowane do cooling
"""
function symuluj_krok!(stan::StanSymulacji, params::Parametry, alg::SimAnnealing)
    n = length(stan.trasa)
    i = rand(stan.rng, 1:(n - 1))
    j = rand(stan.rng, (i + 2):n)
    @assert 1 <= i < j <= n "i, j out of range"

    delta = delta_energii(stan, i, j)
    zaakceptowano = delta < 0.0 || rand(stan.rng) < exp(-delta / stan.temperatura)
    if zaakceptowano
        reverse!(view(stan.trasa, (i + 1):j))
        stan.energia += delta
    end
    stan.temperatura *= alg.alfa
    stan.iteracja += 1
    return nothing
end
