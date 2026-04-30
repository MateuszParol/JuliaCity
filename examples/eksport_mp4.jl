# examples/eksport_mp4.jl
#
# Eksport krotkiego ~10s demo SA-2-opt do assets/demo.gif (Phase 4 DEMO-02, DEMO-03, DEMO-04, D-01..D-05).
# UWAGA: Pomimo nazwy "eksport_mp4", produkujemy GIF — D-01 wybiera GIF dla auto-play
# w README (embed `![](assets/demo.gif)`). Nazwa zachowana zgodnie z REQUIREMENTS DEMO-02
# i ROADMAP Phase 4 SC #2 (oba dopuszczaja .gif). Phase 3 wizualizuj() rozpoznaje rozszerzenie
# `.gif` automatycznie (Phase 3 D-09 + EKS-02).
#
# Uruchomienie:
#   julia --project=. --threads=auto examples/eksport_mp4.jl

using JuliaCity
using Random: Xoshiro

function main()
    # D-02 + D-11: 15_000 krokow / 50 kroki_na_klatke = 300 klatek / 30 fps = 10s GIF (~3-5 MB)
    N = 1000
    SEED = 42
    LICZBA_KROKOW = 15_000
    KROKI_NA_KLATKE = 50
    FPS = 30
    SCIEZKA_GIF = "assets/demo.gif"

    @info "JuliaCity eksport GIF — N=$N, seed=$SEED, threads=$(Threads.nthreads())"

    # Checker iteracja 1 BLOCKER #1: katalog `assets/` NIE jest commitowany w repo
    # (D-05 EXACT — brak `.gitkeep`). Defensywnie tworzymy parent dir przed pre-rm/eksport.
    # Idempotent: bez bledu jezeli juz istnieje.
    mkpath(dirname(SCIEZKA_GIF))

    # D-04: pre-rm istniejacego pliku (swiadoma regeneracja, NIE accident overwrite).
    # Phase 3 D-10 hard-fail (src/wizualizacja.jl ~line 270) chroni API users przed
    # przypadkowym nadpisaniem; demo skrypt = explicit regen, wiec usuwamy plik PRZED
    # wywolaniem wizualizuj(). To celowe obejscie hard-fail tylko w skrypcie demo.
    isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)

    # Build fixture (analog examples/podstawowy.jl)
    punkty = generuj_punkty(N; seed=SEED)
    stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
    inicjuj_nn!(stan)
    energia_nn = stan.energia
    alg = SimAnnealing(stan)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=LICZBA_KROKOW)

    # Eksport (Phase 3 D-09 API consumer — eksport=path => Makie.record + ProgressMeter)
    t_start = time()
    wizualizuj(stan, params, alg;
               liczba_krokow=LICZBA_KROKOW,
               fps=FPS,
               kroki_na_klatke=KROKI_NA_KLATKE,
               eksport=SCIEZKA_GIF)
    dt = time() - t_start

    ratio = round(stan.energia / energia_nn; digits=4)
    @info "GOTOWE eksport: $SCIEZKA_GIF, ratio=$ratio, czas=$(round(dt; digits=2))s"

    return nothing
end

main()
