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
using FFMPEG_jll: ffmpeg

function main()
    # D-02 + D-11: 15_000 krokow / 50 kroki_na_klatke = 300 klatek / 30 fps = 10s GIF (~3-5 MB)
    N = 1000
    SEED = 42
    LICZBA_KROKOW = 15_000
    KROKI_NA_KLATKE = 50
    FPS = 30
    SCIEZKA_GIF = "assets/demo.gif"
    # FFMPEG palettegen target — Makie raw GIF to ~30 MB; palettize+scale dociska do ~3-5 MB (D-02)
    SZEROKOSC_GIF = 700

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
    # T_zero=0.001 lock-in (Phase 2 plan 02-14 erratum): default 2σ kalibracja wyrzuca SA
    # z basena NN-start dla N=1000, ratio leci w górę. T_zero=0.001 utrzymuje SA blisko
    # NN-start, 2-opt schodzi niżej — spójne z bench_jakosc i z headline'em README.
    alg = SimAnnealing(stan; T_zero=0.001)
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
    @info "GOTOWE eksport (raw): $SCIEZKA_GIF, ratio=$ratio, czas=$(round(dt; digits=2))s"

    # Post-process: dwuprzebiegowy FFMPEG palettegen+paletteuse + skalowanie do SZEROKOSC_GIF.
    # Makie.record() pisze GIF z 256-color global palette per-frame (~30 MB dla 1400x700 @ 300 klatek);
    # palette zoptymalizowana statystycznie + downscale Lanczos zbija plik do ~3-5 MB (D-02).
    sciezka_raw     = SCIEZKA_GIF * ".raw.gif"
    sciezka_palette = SCIEZKA_GIF * ".palette.png"
    mv(SCIEZKA_GIF, sciezka_raw; force=true)
    rozmiar_raw_mb = round(filesize(sciezka_raw) / 1024 / 1024; digits=2)
    @info "[ffmpeg] Optymalizuję paletę + downscale do $(SZEROKOSC_GIF)px (input: $(rozmiar_raw_mb) MB)..."

    filtr_skala = "fps=$FPS,scale=$SZEROKOSC_GIF:-1:flags=lanczos"
    ffmpeg() do exe
        run(pipeline(`$exe -y -hide_banner -loglevel error -i $sciezka_raw -vf "$filtr_skala,palettegen=stats_mode=diff" $sciezka_palette`))
        run(pipeline(`$exe -y -hide_banner -loglevel error -i $sciezka_raw -i $sciezka_palette -lavfi "$filtr_skala [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" $SCIEZKA_GIF`))
    end
    rm(sciezka_raw)
    rm(sciezka_palette)
    rozmiar_mb = round(filesize(SCIEZKA_GIF) / 1024 / 1024; digits=2)
    @info "[ffmpeg] GOTOWE: $SCIEZKA_GIF = $(rozmiar_mb) MB (z $(rozmiar_raw_mb) MB)"

    return nothing
end

main()
