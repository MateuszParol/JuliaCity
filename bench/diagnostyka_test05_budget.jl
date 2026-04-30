# Faza A.4 — sweep budzetu krokow dla NN-start + T₀=0.001 (best fixed config)
# Cel: znalezc minimalny budzet n_steps dla ratio <= 0.95 (opcja X user choice)
# z bezpiecznym marginem dla cross-version Julia drift (Xoshiro nie stable
# miedzy minor wersjami).

using JuliaCity
using Random

function run_with_budget(n_steps::Int, T0::Float64=0.001)
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    energia_nn = stan.energia
    alg = SimAnnealing(stan; T_zero=T0)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=n_steps)
    for _ in 1:n_steps
        symuluj_krok!(stan, params, alg)
    end
    return stan.energia / energia_nn
end

println("="^72)
println("Faza A.4 — budget sweep dla T₀=0.001 (NN-start)")
println("="^72)
for n_steps in [50_000, 75_000, 100_000, 125_000, 150_000, 200_000]
    ratio = run_with_budget(n_steps)
    margin_to_095 = 0.95 - ratio
    println("    $(rpad(n_steps, 7)) kroków: ratio=$(round(ratio, digits=4))   margin_do_0.95=$(round(margin_to_095, digits=4))   $(ratio <= 0.95 ? "✓ PASS" : "✗ FAIL")")
end
println("="^72)
