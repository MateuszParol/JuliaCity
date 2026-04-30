# examples/podstawowy.jl
#
# Live demo SA-2-opt na 1000 punktach (Phase 4 DEMO-01, DEMO-03, DEMO-04, LANG-02).
# Otwiera okno GLMakie z dual-panel layoutem, animuje proces zaciagania trasy.
# Hardcoded sensible defaults: N=1000, seed=42, 50_000 krokow, 33s @30fps (D-11).
# Bez ENV/ARGS — edytuj stale ponizej zeby zmienic dlugosc demo.
#
# Uruchomienie:
#   julia --project=. --threads=auto examples/podstawowy.jl

using JuliaCity
using Random: Xoshiro

function main()
    # D-11: hardcoded sensible defaults (komentarze polskie nad kazda stala)
    N = 1000                  # liczba punktow (PROJECT.md core value)
    SEED = 42                 # deterministyczny seed (D-11)
    LICZBA_KROKOW = 50_000    # 33s @ 30fps z kroki_na_klatke=50 (D-11 + D-13)
    KROKI_NA_KLATKE = 50      # throttling Observable update (Phase 3 D-05)
    FPS = 30                  # unified live i eksport (Phase 3 D-11)

    # D-13: banner @info na starcie
    @info "JuliaCity demo — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

    # Build fixture (analog bench/historyczne/diagnostyka_test05.jl::fresh_stan_with_nn)
    punkty = generuj_punkty(N; seed=SEED)
    stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
    inicjuj_nn!(stan)
    energia_nn = stan.energia                     # captured PRZED SA dla post-summary ratio
    alg = SimAnnealing(stan)                      # default 2σ kalibracja — examples = typowe zachowanie
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=LICZBA_KROKOW)

    # Live demo (Phase 3 D-09 API consumer — pomijamy kwarg `eksport`, default => live mode)
    t_start = time()
    wizualizuj(stan, params, alg;
               liczba_krokow=LICZBA_KROKOW,
               fps=FPS,
               kroki_na_klatke=KROKI_NA_KLATKE)
    dt = time() - t_start

    # D-13: post-SA summary @info (NIE duplikuje overlay'u "GOTOWE" z Phase 3 D-06 —
    # overlay zyje w oknie GLMakie, summary w terminalu)
    ratio = round(stan.energia / energia_nn; digits=4)
    @info "GOTOWE: ratio=$ratio, czas=$(round(dt; digits=2))s, krokow=$(stan.iteracja)"

    return nothing
end

main()
