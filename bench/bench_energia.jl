# bench/bench_energia.jl
#
# Microbench `oblicz_energie` (3-arg, threaded) na fixture N=1000 (Phase 4 BENCH-01, BENCH-04).
# Mierzy median time + memory + alokacje (D-07).
# Phase 2 D-08 gwarancja: zero-alloc po warmup — sprawdzone w teście TEST (PerformanceTestTools).
#
# Pattern fresh-per-sample: setup= rebuilduje fixture przed kazda probka dla
# stationarity (uniform pattern z bench_krok.jl — checker iteracja 1 BLOCKER #2 + Warning #1).
# `oblicz_energie` jest non-mutating, ale konsystentnosc setup-pattern uproszcza review
# i pasuje do Phase 2 D-08 zero-alloc warmup discipline.
#
# Uruchomienie WYLACZNIE przez orchestrator (D-06 + checker iteracja 1 BLOCKER #4):
#   bash bench/uruchom.sh        (POSIX)
#   pwsh bench/uruchom.ps1       (PowerShell)
# Standalone: include z Julia REPL z BenchmarkTools dostepnym, potem main() — main()
# zwraca BenchmarkTools.Trial.

using JuliaCity
using BenchmarkTools
using StableRNGs: StableRNG

function main()
    # BENCH-04: $ interpolacja eliminuje boxing globals (Pitfall „@btime bez $").
    # Fresh fixture per sample przez setup= — uniform z bench_krok.jl (checker BLOCKER #2).
    # evals=1: trial.allocs odpowiada jednemu wywolaniu oblicz_energie (czysty pomiar
    # zero-alloc gwarancji per Phase 2 D-08).
    # samples=200, seconds=5: ograniczenie wallclock'a — bench_energia jest szybki (~us).
    wynik = BenchmarkTools.@benchmark begin
        oblicz_energie(stan.D, stan.trasa, bufor)
    end setup = (
        rng = StableRNG(42);
        punkty = generuj_punkty(1000; seed=42);
        stan = StanSymulacji(punkty);
        inicjuj_nn!(stan);
        bufor = zeros(Float64, Threads.nthreads())
    ) evals = 1 samples = 200 seconds = 5

    return wynik
end
