# bench/bench_krok.jl
#
# Microbench `symuluj_krok!` (jeden krok SA z delta-energy + Metropolis) na fixture N=1000 (BENCH-02, BENCH-04).
# Mierzy median time + memory + alokacje (D-07).
# Phase 2 TEST-03 gwarantuje @allocated == 0 po warmup; bench potwierdza empirycznie.
#
# Fresh-stan-per-sample (checker iteracja 1 BLOCKER #2):
# setup= rebuildujce fresh `stan` + jeden warmup `symuluj_krok!` PRZED kazdym pomiarem.
# Bez tego stan akumuluje state przez tysiace samples (stan.iteracja przekracza
# Parametry.liczba_krokow=50_000) i SA-loop semantyka drifts od pomiaru fresh single-step.
#
# Uruchomienie WYLACZNIE przez orchestrator (D-06 + checker BLOCKER #4):
#   bash bench/uruchom.sh        (POSIX)
#   pwsh bench/uruchom.ps1       (PowerShell)
# Standalone: include z Julia REPL z BenchmarkTools dostepnym, potem main() — main()
# zwraca BenchmarkTools.Trial.

using JuliaCity
using BenchmarkTools
using StableRNGs: StableRNG

function main()
    # BENCH-04: $ interpolacja eliminuje boxing globals (przez setup= captured locals).
    # Fresh stan per sample (BLOCKER #2): kazda probka dostaje swiezo zainicjowany stan
    # z 1x warmup step (mid-flight measurement, NIE first-step compile).
    # evals=1: pojedyncze wywolanie per probka, czytelne allocs (Phase 2 TEST-03 lock).
    # samples=200, seconds=5: bound wallclock — pojedynczy krok ~us, full setup ~ms,
    # 200 probek × ~ms = ~sec (akceptowalne).
    wynik = BenchmarkTools.@benchmark begin
        symuluj_krok!(stan, params, alg)
    end setup = (
        rng = StableRNG(42);
        punkty = generuj_punkty(1000; seed=42);
        stan = StanSymulacji(punkty);
        inicjuj_nn!(stan);
        params = Parametry(liczba_krokow=50_000);
        alg = SimAnnealing(stan);
        stan.temperatura = alg.T_zero;
        symuluj_krok!(stan, params, alg)
    ) evals = 1 samples = 200 seconds = 5

    return wynik
end
