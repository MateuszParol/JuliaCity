# examples/eksport_mp4.jl
#
# Eksport ~10s demo HYBRYDA edukacyjna do assets/demo.gif (Phase 4.1 DEMO-02, DEMO-04, EKS-04).
#
# UWAGA: Pomimo nazwy "eksport_mp4", produkujemy GIF — Phase 4 D-01 wybiera GIF dla auto-play
# w README (embed `![](assets/demo.gif)`). Nazwa zachowana zgodnie z REQUIREMENTS DEMO-02
# i ROADMAP Phase 4 SC #2 (oba dopuszczaja .gif).
#
# Architektura 3-fazowej hybrydy (Phase 4.1 D-04 LOCKED):
#   - Faza 1 (~5s, ~143 klatek @30fps): NN-construction edge-by-edge od pustej trasy
#   - Faza 2 (~0.7s, 20 klatek @30fps): wizualny separator (czarne tlo + tekst "Optymalizacja SA-2-opt")
#   - Faza 3 (~5s, 150 klatek @30fps): SA-2-opt optimization (T_zero=0.001 lock z plan 02-14)
#   Lacznie ~10.5s @30fps.
#
# Implementacja: 3 osobne `Makie.record()` calls -> 3 GIFy posrednie -> ffmpeg concat ->
# ffmpeg palette+downscale Lanczos do SZEROKOSC_GIF=1600 -> assets/demo.gif (~600-1500 KB).
#
# Phase 4.1 D-06 LOCKED: BRAK nowego publicznego `wizualizuj_hybrid()` — orkiestracja na
# poziomie skryptu, helper `JuliaCity._animuj_nn_construction!` konsumowany przez internal
# namespace (Wariant B per CONTEXT D-06 — lokalny inline closure ze wzgledu na monolityczna
# sygnature helpera; helper iteruje n_klatek wewnetrznie, a Makie.record() callback potrzebuje
# 1 chunk per klatka).
#
# Uruchomienie:
#   julia --project=. --threads=auto examples/eksport_mp4.jl

using JuliaCity
using GLMakie                       # Figure, Axis, text!, with_theme, theme_dark, Makie.record, Observable, Point2f
using GeometryBasics: Point2f       # explicit re-import dla jasnosci
using Random: Xoshiro
using FFMPEG_jll: ffmpeg

function main()
    # === Stale konfiguracji (Phase 4.1 D-04 + D-08 + D-09) ===
    N = 1000
    SEED = 42
    LICZBA_KROKOW_SA = 7500           # polowa poprzedniej (15_000) — faza 3 trwa ~5s
    KROKI_NA_KLATKE = 50              # zachowane z Phase 3 D-05
    FPS = 30
    SCIEZKA_GIF = "assets/demo.gif"
    SZEROKOSC_GIF = 1600              # Phase 4.1 D-09: bump z 700 -> 1600 (Lanczos downscale z 1920)
    FIGURE_SIZE = (1920, 960)         # Phase 4.1 D-08: bump z (1400, 700) -> (1920, 960) zrodla
    CHUNK_NN = 7                      # Phase 4.1 D-04: ceil(1000/150) = 7 krawedzi/klatka fazy 1
    N_KLATEK_NN = ceil(Int, N / CHUNK_NN)        # ~143 klatek (~4.8s @30fps)
    N_KLATEK_SEPARATOR = 20           # Phase 4.1 D-04: ~0.67s @30fps (15-30 klatek window)

    @info "JuliaCity hybrid GIF — N=$N, seed=$SEED, threads=$(Threads.nthreads())"
    @info "Faza 1: NN-construction edge-by-edge (~5s)..."
    @info "Faza 2: Separator (0.5-1s)..."
    @info "Faza 3: SA-2-opt optimization (~5s)..."

    # Defensywnie tworzymy parent dir (Phase 4 D-04 — assets/ nie jest commitowany jako pusty folder)
    mkpath(dirname(SCIEZKA_GIF))

    # Phase 4 D-04: pre-rm istniejacego pliku (swiadoma regeneracja, NIE accident overwrite).
    # Phase 3 D-10 hard-fail w wizualizuj() chroni API users przed przypadkowym nadpisaniem;
    # demo skrypt = explicit regen, wiec usuwamy plik PRZED kazdym record(). Idempotent.
    isfile(SCIEZKA_GIF) && rm(SCIEZKA_GIF)

    # Sciezki posrednie — czyscimy przed regen i na koncu (T-04.1-02-02 mitigation)
    sciezka_faza1 = SCIEZKA_GIF * ".faza1.gif"
    sciezka_faza2 = SCIEZKA_GIF * ".faza2.gif"
    sciezka_faza3 = SCIEZKA_GIF * ".faza3.gif"
    sciezka_concat_list = SCIEZKA_GIF * ".concat.txt"
    sciezka_raw = SCIEZKA_GIF * ".raw.gif"
    sciezka_palette = SCIEZKA_GIF * ".palette.png"
    for f in (sciezka_faza1, sciezka_faza2, sciezka_faza3,
              sciezka_concat_list, sciezka_raw, sciezka_palette)
        isfile(f) && rm(f)
    end

    # === Setup wspolny dla faz 1 + 3 ===
    punkty = generuj_punkty(N; seed=SEED)
    stan = StanSymulacji(punkty; rng=Xoshiro(SEED))
    oblicz_macierz_dystans!(stan)              # MUSI byc PRZED faza 1 (helper czyta stan.D)
    stan.trasa = [1]                           # reset do start=1 dla helpera (D-05 contract)
    stan.iteracja = 0

    # NN baseline (potrzebny dla _setup_figure overlay) — zawsze zgodny z trasa_nn(D; start=1)
    nn_trasa_pelna = trasa_nn(stan.D; start=1)

    t_start_total = time()

    # ============================================================
    # FAZA 1: NN-construction edge-by-edge
    # ============================================================
    # Wariant B per Phase 4.1 D-06 — lokalny chunk-stepper closure ze wzgledu na monolityczna
    # sygnature helpera (`_animuj_nn_construction!` iteruje n_klatek wewnetrznie, a Makie.record()
    # callback potrzebuje 1 chunk per klatka). Closure zamyka nad mutowanymi captured locals.
    # Refactor do Wariantu A (helper zwracajacy iterator/callback) jest todo dla v1.2.
    odwiedzone_nn = falses(N)
    odwiedzone_nn[1] = true
    pelna_trasa_nn = Vector{Int}(undef, N)
    pelna_trasa_nn[1] = 1
    k_nn = Ref(1)   # ile elementow trasy juz wybralismy (mutowalne wewnatrz closure)

    with_theme(theme_dark()) do
        fig, ax_trasa, ax_energia = JuliaCity._setup_figure(stan, nn_trasa_pelna; figure_size=FIGURE_SIZE)
        # alg_dummy potrzebne tylko do _init_observables overlay (T_zero zostanie nadpisane w fazie 3)
        alg_dummy = SimAnnealing(stan; T_zero=0.001)
        obs = JuliaCity._init_observables(stan, alg_dummy, ax_trasa, ax_energia)

        # 1 chunk per klatka closure (zgodny algorytmicznie z trasa_nn(D; start=1) + _animuj_nn_construction!)
        function _jeden_chunk_nn!()
            for _ in 1:CHUNK_NN
                k_nn[] >= N && break
                biezacy = pelna_trasa_nn[k_nn[]]
                najblizszy = 0
                min_dist = Inf
                for j in 1:N
                    if !odwiedzone_nn[j] && stan.D[biezacy, j] < min_dist
                        min_dist = stan.D[biezacy, j]
                        najblizszy = j
                    end
                end
                k_nn[] += 1
                pelna_trasa_nn[k_nn[]] = najblizszy
                odwiedzone_nn[najblizszy] = true
            end
            # Update stan.trasa do prefix dlugosci k_nn[] + Observable mutation
            stan.trasa = pelna_trasa_nn[1:k_nn[]]
            pts = Vector{Point2f}(undef, k_nn[] + 1)
            for i in 1:k_nn[]
                pts[i] = Point2f(stan.punkty[stan.trasa[i]])
            end
            pts[k_nn[] + 1] = pts[1]
            obs.obs_trasa[] = pts
            return nothing
        end

        Makie.record(fig, sciezka_faza1, 1:N_KLATEK_NN; framerate=FPS) do frame_i
            if frame_i == 1
                # Klatka 1: tylko punkty + start (stan.trasa = [1]) — pusta linia (must_haves truth #2)
                # Niczego nie mutujemy — observable obs_trasa juz pokazuje [punkt(1), punkt(1)] degenerate.
            else
                _jeden_chunk_nn!()
            end
        end
    end

    # Po fazie 1 stan.trasa to PELEN cykl Hamiltona (zgodnosc z trasa_nn dzieki algorytmicznej replice).
    @assert k_nn[] == N "Faza 1 nie ukonczyla pelnego cyklu Hamiltona (k=$(k_nn[]) != N=$N)"

    # ============================================================
    # FAZA 2: Separator (czarna klatka + tekst)
    # ============================================================
    with_theme(theme_dark()) do
        fig_sep = Figure(size=FIGURE_SIZE; backgroundcolor=:black)
        ax_sep = Axis(fig_sep[1, 1]; backgroundcolor=:black)
        hidedecorations!(ax_sep)
        hidespines!(ax_sep)
        text!(ax_sep, 0.5, 0.5;
              text="Optymalizacja SA-2-opt",
              align=(:center, :center),
              fontsize=48,
              color=:white,
              space=:relative)
        xlims!(ax_sep, 0, 1)
        ylims!(ax_sep, 0, 1)

        Makie.record(fig_sep, sciezka_faza2, 1:N_KLATEK_SEPARATOR; framerate=FPS) do _
            # static frame — nic nie mutujemy, separator stoi
        end
    end

    # ============================================================
    # FAZA 3: SA-2-opt optimization (PO NN-construction stan.trasa = pelen cykl NN)
    # ============================================================
    # Po fazie 1 stan.trasa to pelna trasa NN (helper konczy z pelnym cyklem). Tutaj
    # musimy upewnic sie, ze stan.energia jest zaktualizowana — w fazie 1 nie liczymy
    # energii per chunk (incremental NN-construction nie potrzebuje energii dla wizualizacji).
    bufor_e = zeros(Float64, Threads.nthreads())
    stan.energia = oblicz_energie(stan.D, stan.trasa, bufor_e)
    energia_nn = stan.energia                  # baseline po NN-construction (== inicjuj_nn! result)

    # T_zero=0.001 lock-in (Phase 2 plan 02-14 erratum) — utrzymuje SA blisko NN-start, 2-opt schodzi nizej
    alg = SimAnnealing(stan; T_zero=0.001)
    stan.temperatura = alg.T_zero
    params = Parametry(liczba_krokow=LICZBA_KROKOW_SA)

    wizualizuj(stan, params, alg;
               liczba_krokow=LICZBA_KROKOW_SA,
               fps=FPS,
               kroki_na_klatke=KROKI_NA_KLATKE,
               eksport=sciezka_faza3,
               figure_size=FIGURE_SIZE)

    # ============================================================
    # CONCAT 3 GIFow przez ffmpeg (T-04.1-02-01: -safe 0 wymagane dla wzglednych sciezek)
    # ============================================================
    # ffmpeg concat-demuxer wymaga listy plikow w pliku tekstowym z `file 'NAZWA'` per linia.
    # Sciezki RELATYWNE wzgledem cwd procesu ffmpeg (uruchamianego z dirname(SCIEZKA_GIF)).
    open(sciezka_concat_list, "w") do io
        println(io, "file '$(basename(sciezka_faza1))'")
        println(io, "file '$(basename(sciezka_faza2))'")
        println(io, "file '$(basename(sciezka_faza3))'")
    end

    ffmpeg() do exe
        run(pipeline(`$exe -y -hide_banner -loglevel error -f concat -safe 0 -i $(basename(sciezka_concat_list)) -c copy $(basename(sciezka_raw))`;
                     dir=dirname(SCIEZKA_GIF)))
    end

    # ============================================================
    # FFMPEG palette + downscale do SZEROKOSC_GIF=1600 (Lanczos)
    # ============================================================
    rozmiar_raw_mb = round(filesize(sciezka_raw) / 1024 / 1024; digits=2)
    @info "[ffmpeg] Optymalizuje palete + downscale do $(SZEROKOSC_GIF)px (input: $(rozmiar_raw_mb) MB)..."
    filtr_skala = "fps=$FPS,scale=$SZEROKOSC_GIF:-1:flags=lanczos"
    ffmpeg() do exe
        run(pipeline(`$exe -y -hide_banner -loglevel error -i $sciezka_raw -vf "$filtr_skala,palettegen=stats_mode=diff" $sciezka_palette`))
        run(pipeline(`$exe -y -hide_banner -loglevel error -i $sciezka_raw -i $sciezka_palette -lavfi "$filtr_skala [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" $SCIEZKA_GIF`))
    end

    # Cleanup posrednich plikow (T-04.1-02-02 mitigation — Phase 4 D-05 .gitignore allowlist
    # chroni przed accidental commit jezeli cleanup zawiedzie)
    for f in (sciezka_faza1, sciezka_faza2, sciezka_faza3,
              sciezka_concat_list, sciezka_raw, sciezka_palette)
        isfile(f) && rm(f)
    end

    rozmiar_mb = round(filesize(SCIEZKA_GIF) / 1024 / 1024; digits=2)
    ratio = round(stan.energia / energia_nn; digits=4)
    dt_total = round(time() - t_start_total; digits=2)
    @info "GOTOWE hybryda: $SCIEZKA_GIF = $(rozmiar_mb) MB, ratio_SA/NN=$ratio, czas=$(dt_total)s"

    # Phase 4.1 D-11 contract: zwracamy tuple dla testu (plan 04.1-03 wykorzysta).
    return (stan, energia_nn)
end

main()
