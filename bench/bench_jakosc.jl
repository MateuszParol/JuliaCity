# bench/bench_jakosc.jl
#
# Quality bench SA vs NN baseline (Phase 4 BENCH-03, BENCH-04).
# 5 seedow x N=1000 punktow x 50 000 krokow SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).
# Raportuje mean +/- std, min, max dla ratio = stan.energia / energia_nn (D-08).
# Headline dla README: "SA znajduje trase srednio ~6% krotsza niz NN baseline (5 seedow)".
#
# Uruchomienie standalone:
#   julia --project=. --threads=auto bench/bench_jakosc.jl
# Lub przez orchestrator:
#   julia --project=. --threads=auto bench/run_all.jl
#
# UWAGA: ~5 min wallclock'a (5 x 50_000 SA steps). Nie uzywa BenchmarkTools - mierzy ratio,
# nie czas. Czas SA-loop nie jest wymagany dla BENCH-03 (BENCH-02 = symuluj_krok! one-step).

using JuliaCity
using Random: Xoshiro
using Statistics: mean, std

function main()
    # D-08: 5 fixed seeds - deterministyczne, stabilne miedzy uruchomieniami
    SEEDS = [42, 123, 456, 789, 2025]
    N = 1000
    LICZBA_KROKOW = 50_000

    @info "[bench_jakosc] Start: $(length(SEEDS)) seedow x N=$N x $LICZBA_KROKOW krokow, threads=$(Threads.nthreads())"

    ratios = Float64[]

    for seed in SEEDS
        # Fixture per seed (Phase 2 fixture pattern, deterministyczny RNG)
        punkty = generuj_punkty(N; seed=seed)
        stan = StanSymulacji(punkty; rng=Xoshiro(seed))
        inicjuj_nn!(stan)
        energia_nn = stan.energia                # NN baseline = stan.energia po inicjuj_nn!

        # SA z T_zero=0.001 override (Phase 2 plan 02-14 erratum, 02-CONTEXT.md D-03).
        # Default 2sigma kalibracja wyrzuca SA z basena NN-start; T_zero=0.001 utrzymuje SA blisko
        # NN-start zeby 2-opt local search mial szanse zejsc nizej.
        alg = SimAnnealing(stan; T_zero=0.001)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=LICZBA_KROKOW)

        t_start = time()
        uruchom_sa!(stan, params, alg)
        dt = time() - t_start

        ratio = stan.energia / energia_nn
        push!(ratios, ratio)

        @info "  seed=$seed: ratio=$(round(ratio; digits=4)), iter=$(stan.iteracja), czas=$(round(dt; digits=1))s"
    end

    mean_r = mean(ratios)
    std_r = std(ratios)
    min_r = minimum(ratios)
    max_r = maximum(ratios)

    @info "[bench_jakosc] GOTOWE: mean=$(round(mean_r; digits=4)) +/- $(round(std_r; digits=4)), min=$(round(min_r; digits=4)), max=$(round(max_r; digits=4))"

    return (
        seeds = SEEDS,
        ratios = ratios,
        mean_ratio = mean_r,
        std_ratio = std_r,
        min_ratio = min_r,
        max_ratio = max_r,
        n = N,
        liczba_krokow = LICZBA_KROKOW,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    wynik = main()
    println("="^60)
    println("[bench_jakosc] Aggregate (5 seedow x N=$(wynik.n)):")
    println("="^60)
    println("  mean ratio: $(round(wynik.mean_ratio; digits=4))")
    println("  std ratio:  $(round(wynik.std_ratio; digits=4))")
    println("  min ratio:  $(round(wynik.min_ratio; digits=4))")
    println("  max ratio:  $(round(wynik.max_ratio; digits=4))")
    println()
end
