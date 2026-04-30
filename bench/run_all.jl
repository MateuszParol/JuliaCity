# bench/run_all.jl
#
# Orchestrator suite Phase 4 (BENCH-01..05, D-06, D-07): single entry point
# laduje 3 microbench scripts (bench_energia, bench_krok, bench_jakosc) w izolowanych
# anonimowych modulach (checker iteracja 1 BLOCKER #3 fix — uniknac kolizji Main.main),
# zbiera wyniki i renderuje markdown raport bench/wyniki.md (D-07 metadata + tabele).
#
# Uruchomienie (canonical, BLOCKER #4 fix — wrappery dostarczaja BenchmarkTools resolver):
#   bash bench/uruchom.sh        (POSIX)
#   pwsh bench/uruchom.ps1       (PowerShell / Windows)
# Wallclock ~5-10 min, dominuje bench_jakosc (5 seedow x 50_000 krokow SA).

using JuliaCity
using BenchmarkTools
using Statistics: median
using Dates: now
using Printf: @sprintf

# Helper 1: BLOCKER #3 fix — module isolation per bench script.
# Bez tego sekwencyjny include(bench_*.jl) w Main scope nadpisuje Main.main
# i top-level main() na koncu run_all.jl wywoluje OSTATNIO-zaladowany bench main,
# NIE orchestratora.
function _uruchom_bench(sciezka::String)
    # Isolacja: kazdy bench skrypt ladowany w osobnym anonimowym module,
    # by `function main()` z bench_*.jl nie nadpisal Main.main orchestratora.
    # Bez tego: top-level `main()` wywolanie na koncu run_all.jl wywolaloby
    # ostatnio-zaladowany bench main, NIE orchestratora.
    m = Module(:_BenchSandbox)
    Base.include(m, sciezka)
    return Base.invokelatest(m.main)
end

# Helper 2: zbiera metadane srodowiska wykonania (D-07: Julia, OS, CPU, threads, data).
function _zbierz_metadane()::String
    cpu = try
        Sys.cpu_info()[1].model
    catch
        "unknown"
    end
    return string(
        "- Julia: ", VERSION, "\n",
        "- OS: ", Sys.KERNEL, "\n",
        "- CPU: ", cpu, "\n",
        "- Wątki: ", Threads.nthreads(), "\n",
        "- Data: ", now(), "\n",
    )
end

# Helper 3: formatuje pojedyncza Trial do triady (median time us, memory bytes, alokacje).
function _formatuj_trial(t::BenchmarkTools.Trial)
    med = median(t)
    time_us = @sprintf("%.3f", med.time / 1000.0)   # nanoseconds -> microseconds
    memory_b = string(med.memory)
    allocs = string(med.allocs)
    return (time_us=time_us, memory_b=memory_b, allocs=allocs)
end

# Helper 4: renderuje sekcje microbenchmark'ow (BLOCKER Warning #3 fix — alfabetyczny order).
function _renderuj_microbench_tabele(wyniki::Dict{String, BenchmarkTools.Trial})::String
    bufor = IOBuffer()
    println(bufor, "## Microbenchmarki")
    println(bufor)
    println(bufor, "Pomiary `BenchmarkTools.@benchmark` (evals=1, fresh-per-sample setup) — median z 200 probek.")
    println(bufor)
    println(bufor, "| Funkcja | Median time (μs) | Memory (B) | Alokacje |")
    println(bufor, "| --- | --- | --- | --- |")
    # Warning #3 fix: stable alfabetical order — gwarantuje `oblicz_energie` < `symuluj_krok!`.
    for nazwa in sort(collect(keys(wyniki)))
        f = _formatuj_trial(wyniki[nazwa])
        println(bufor, "| `", nazwa, "` | ", f.time_us, " | ", f.memory_b, " | ", f.allocs, " |")
    end
    println(bufor)
    return String(take!(bufor))
end

# Helper 5: renderuje sekcje jakosci trasy (D-08 aggregate per seed + headline).
function _renderuj_jakosc_sekcje(j::NamedTuple)::String
    bufor = IOBuffer()
    println(bufor, "## Jakość trasy (bench_jakosc)")
    println(bufor)
    println(bufor, "Aggregate po ", length(j.seeds), " seedach × N=", j.n, " × ", j.liczba_krokow, " kroków SA z T_zero=0.001 (Phase 2 plan 02-14 erratum lock).")
    println(bufor)
    headline_pct = round((1 - j.mean_ratio) * 100; digits=1)
    println(bufor, "**Headline:** SA znajduje trasę średnio ", headline_pct, "% krótszą niż NN baseline.")
    println(bufor)
    println(bufor, "| Statystyka | Wartość |")
    println(bufor, "| --- | --- |")
    println(bufor, "| mean ratio | ", @sprintf("%.4f", j.mean_ratio), " |")
    println(bufor, "| std ratio | ", @sprintf("%.4f", j.std_ratio), " |")
    println(bufor, "| min ratio | ", @sprintf("%.4f", j.min_ratio), " |")
    println(bufor, "| max ratio | ", @sprintf("%.4f", j.max_ratio), " |")
    println(bufor)
    println(bufor, "Per-seed:")
    println(bufor)
    for (s, r) in zip(j.seeds, j.ratios)
        println(bufor, "- seed=", s, ": ", @sprintf("%.4f", r))
    end
    println(bufor)
    return String(take!(bufor))
end

# Glowna funkcja: orchestruje 3 bench scripts, zbiera wyniki, renderuje raport.
function main()
    println("="^72)
    println("[run_all] Suite benchmarkow JuliaCity (Phase 4 BENCH-01..05)")
    println("="^72)

    # Kontener wynikow microbench (Trial); jakosc osobno (NamedTuple).
    microbench = Dict{String, BenchmarkTools.Trial}()

    # Krok 1/3: oblicz_energie microbench.
    @info "[run_all] (1/3) bench_energia.jl — uruchamiam w izolowanym module..."
    microbench["oblicz_energie (3-arg, N=1000)"] = _uruchom_bench(joinpath(@__DIR__, "bench_energia.jl"))

    # Krok 2/3: symuluj_krok! microbench.
    @info "[run_all] (2/3) bench_krok.jl — uruchamiam w izolowanym module..."
    microbench["symuluj_krok! (SA-2-opt, N=1000)"] = _uruchom_bench(joinpath(@__DIR__, "bench_krok.jl"))

    # Krok 3/3: jakosc trasy (longest, ~5 min).
    @info "[run_all] (3/3) bench_jakosc.jl (~5 min) — uruchamiam w izolowanym module..."
    jakosc = _uruchom_bench(joinpath(@__DIR__, "bench_jakosc.jl"))

    # Render: zbierz metadane, sekcje microbench (alfabetycznie), sekcje jakosci.
    metadane = _zbierz_metadane()
    tabela_micro = _renderuj_microbench_tabele(microbench)
    sekcja_jakosc = _renderuj_jakosc_sekcje(jakosc)

    # Zapis bench/wyniki.md (D-06 single entry point + BLOCKER #4 — wrapper jako canonical command).
    sciezka_wyjscia = joinpath(@__DIR__, "wyniki.md")
    open(sciezka_wyjscia, "w") do io
        println(io, "# Wyniki benchmarków JuliaCity")
        println(io)
        println(io, "Wygenerowane przez `bench/run_all.jl` (D-06). Reprodukuj komendą:")
        println(io)
        println(io, "```bash")
        println(io, "bash bench/uruchom.sh")
        println(io, "# lub na Windows:")
        println(io, "pwsh bench/uruchom.ps1")
        println(io, "```")
        println(io)
        println(io, "## Środowisko")
        println(io)
        print(io, metadane)
        println(io)
        print(io, tabela_micro)
        print(io, sekcja_jakosc)
    end

    @info "[run_all] GOTOWE — wyniki zapisane do bench/wyniki.md"
    println("="^72)
    println("[run_all] Koniec suite benchmarkow")
    println("="^72)
    return nothing
end

main()
