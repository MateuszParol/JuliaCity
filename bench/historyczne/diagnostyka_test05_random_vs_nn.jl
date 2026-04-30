# Faza A.3 (extension) — sprawdz czy random start (no NN-init) z T0_calibrated
# daje lepszy ratio niż NN-start. Jeżeli TAK: NN-init jest przeszkodą i należy
# albo (a) zmienić TEST-05 na random-start, albo (b) wprowadzić multi-start
# z perturbation.

using JuliaCity
using Random
using Statistics: mean, std

function fresh_stan_random_start()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    # Macierz dystansów z inicjuj_nn (potrzebujemy D wypełnione)
    inicjuj_nn!(stan)
    # Po inicjuj_nn! mamy NN tour; teraz ZSTĄP do random tour, ale zachowaj D
    n = length(stan.trasa)
    Random.shuffle!(stan.rng, stan.trasa)
    # Recompute energy
    energia = 0.0
    for k in 1:(n - 1)
        energia += stan.D[stan.trasa[k], stan.trasa[k + 1]]
    end
    energia += stan.D[stan.trasa[n], stan.trasa[1]]
    stan.energia = energia
    stan.iteracja = 0
    return stan
end

function compute_nn_energia()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    return stan.energia
end

function run_sa(stan::StanSymulacji, alg::SimAnnealing, params::Parametry, n_steps::Int)
    for _ in 1:n_steps
        symuluj_krok!(stan, params, alg)
    end
    return stan.energia
end

println("="^72)
println("Faza A.3 — random start vs NN start (50k + 200k kroków)")
println("="^72)

energia_nn = compute_nn_energia()
println("[A.3] energia_nn = $(round(energia_nn, digits=4))")

println("\n[A.3] Random start + T₀_calibrated (kalibruj_T0 na random tour):")
for n_steps in [50_000, 200_000]
    stan = fresh_stan_random_start()
    energia_random_start = stan.energia
    T0 = kalibruj_T0(stan)
    alg = SimAnnealing(stan; T_zero=T0)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=n_steps)
    final_energia = run_sa(stan, alg, params, n_steps)
    ratio = final_energia / energia_nn
    println("    $(n_steps) kroków: random_start_E=$(round(energia_random_start, digits=2))  T₀=$(round(T0, digits=4))  final=$(round(final_energia, digits=4))  ratio=$(round(ratio, digits=4))")
end

# Multi-start: 5 random starts, take best
println("\n[A.3] Multi-start (5× random start, T₀_calibrated, 50k każdy):")
best_ratio = Inf
for restart in 1:5
    stan = StanSymulacji(generuj_punkty(1000; seed=42); rng=Xoshiro(1000 + restart))
    inicjuj_nn!(stan)
    Random.shuffle!(stan.rng, stan.trasa)
    n = length(stan.trasa)
    energia = 0.0
    for k in 1:(n - 1)
        energia += stan.D[stan.trasa[k], stan.trasa[k + 1]]
    end
    energia += stan.D[stan.trasa[n], stan.trasa[1]]
    stan.energia = energia
    stan.iteracja = 0
    T0 = kalibruj_T0(stan)
    alg = SimAnnealing(stan; T_zero=T0)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=50_000)
    final_energia = run_sa(stan, alg, params, 50_000)
    ratio = final_energia / energia_nn
    println("    restart $(restart): final=$(round(final_energia, digits=4))  ratio=$(round(ratio, digits=4))")
    if ratio < best_ratio
        global best_ratio = ratio
    end
end
println("    BEST z 5 restartów: ratio = $(round(best_ratio, digits=4))")
println("="^72)
