# Wizualizacja TSP — okno GLMakie + eksport MP4/GIF.
# Pokrywa REQ VIZ-01..07, EKS-01..04 (11 wymagan).
#
# WAZNE (VIZ-06 LOCKED): src/wizualizacja.jl jest JEDYNYM plikiem w src/
# importujacym `using GLMakie`. Core (`punkty.jl`, `energia.jl`, `baselines.jl`,
# `algorytmy/`, `typy.jl`) pozostaje pure-headless — `runtests.jl` nie wymaga
# OpenGL. Dowod: `grep -rl "using GLMakie" src/` zwraca tylko ten plik.
#
# Architektura (D-09):
#   - eksport === nothing  → live renderloop (okno interaktywne GLMakie)
#   - eksport isa String   → blocking Makie.record() + ProgressMeter
#
# Decyzje uzytkownika (15 LOCKED w 03-CONTEXT.md):
#   D-01 dual-panel; D-02 NN baseline szara linia; D-03 dark theme + aspect 1:1;
#   D-04 7-pol overlay po polsku; D-05 KROKI_NA_KLATKE=50; D-06 GOTOWE freeze;
#   D-07 domyslna interaktywnosc Makie; D-08 TTFP @info; D-09 single API entry;
#   D-10 file-exists hard error; D-11 unified fps; D-12 export klatek;
#   D-13 GLMakie hard-fail polski.
#
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
# Komunikaty user-facing (error msg, @info, overlay strings) po polsku per LANG-02.
#
# Zaleznosci (`StanSymulacji`, `Parametry`, `Algorytm`, `SimAnnealing`,
# `symuluj_krok!`, `trasa_nn`) sa w scope'ie modulu — typy.jl + baselines.jl +
# algorytmy/simulowane_wyzarzanie.jl sa include-owane wczesniej w JuliaCity.jl.

using GLMakie                       # VIZ-06: jedyne miejsce w src/ z tym importem
using ProgressMeter                 # EKS-03: pasek postepu eksportu
using GeometryBasics: Point2f       # Float32 dla Makie GPU pipeline (RESEARCH Q8)
# Observable jest re-eksportowane przez using GLMakie (Makie 0.15+ integration).
# Makie.record(), Figure, Axis, AxisAspect, Relative, colsize!, scatter!, lines!,
# text! — wszystko w scope przez `using GLMakie`. Dark theme API takze.

# ---------------------------------------------------------------------------
# Helpery wewnetrzne (prefiks `_` per PATTERNS.md "dwustopniowe API public/internal")
# Nie sa eksportowane — uzywane wylacznie przez wizualizuj() i jej helpers.
# ---------------------------------------------------------------------------

"""
Konwersja stan.trasa (Vector{Int}) -> Vector{Point2f} z domknieciem cyklu Hamiltona
(n+1 punktow, ostatni == pierwszy). Alokuje raz per klatka — akceptowalne (~8KB
dla N=1000). @inbounds bezpieczne: stan.trasa to permutacja 1:n (invariant Phase 2
ALG-08), wiec stan.punkty[stan.trasa[k]] jest zawsze w granicach.
RESEARCH Pattern 3 + Q8.
"""
function _trasa_do_punkty(stan::StanSymulacji)::Vector{Point2f}
    n = length(stan.trasa)
    pts = Vector{Point2f}(undef, n + 1)   # +1 dla zamkniecia cyklu (VIZ-02)
    @inbounds for k in 1:n
        pts[k] = Point2f(stan.punkty[stan.trasa[k]])
    end
    pts[n + 1] = pts[1]  # zamkniecie cyklu Hamiltona
    return pts
end

"""
Buduje multiline string overlay'u (D-04 — 7 pol). Per RESEARCH Q1 + A3 — uzywamy
JEDNEGO typowanego Observable dla tekstu z \\n separatorem (Opcja B), zamiast 7 osobnych
Observables — minimalizuje liczbe Makie notify per klatke do 1 (vs 7 przy Opcji A).
fps_est/eta_sec/accept_rate moga byc NaN przed zebraniem danych (pierwsza klatka).
Polskie diakrytyki (blona, Pozostalo, Akceptacja) — Phase 1 D-21 NFC gwarantuje
poprawne kodowanie; RESEARCH Q5 potwierdza ze TeX Gyre Heros Makie pokrywa Latin Extended.
"""
function _zbuduj_overlay_string(stan::StanSymulacji, alg::Algorytm,
                                fps_est::Float64, eta_sec::Float64,
                                accept_rate::Float64)::String
    # alg.alfa istnieje tylko dla SimAnnealing — degraduj do NaN dla innych <:Algorytm
    alfa_val = hasproperty(alg, :alfa) ? getproperty(alg, :alfa) : NaN

    # Format wartosci: czytelne, polskie diakrytyki (Phase 1 D-21 NFC OK).
    fps_str = isnan(fps_est)     ? "—" : string(round(fps_est; digits=1))
    eta_str = isnan(eta_sec)     ? "—" : string(round(Int, eta_sec), " s")
    acc_str = isnan(accept_rate) ? "—" : string(round(accept_rate * 100; digits=1), "%")

    return """Iteracja: $(stan.iteracja)
Energia: $(round(stan.energia; digits=4))
Temperatura: $(round(stan.temperatura; digits=6))
Alfa: $(alfa_val)
FPS: $(fps_str)
Pozostało: $(eta_str)
Akceptacja worsening: $(acc_str)"""
end

"""
Buduje dual-panel Figure (D-01): lewy panel `ax_trasa` z aspect 1:1 (D-03) na 2D
trase + NN baseline overlay (D-02); prawy panel `ax_energia` na krzywa energii.
Renderuje NN baseline jako szara przerywana linia (raz, statyczne — bez Observable).
Polskie tytuly/etykiety (VIZ-04). RESEARCH Pattern 1 + Q7.
Uwaga: wywolywane wewnatrz bloku dark-theme (motywy dziedziczone przez Figure).
"""
function _setup_figure(stan::StanSymulacji, nn_trasa::Vector{Int})
    n_punktow = length(stan.punkty)
    fig = Figure(size=(1400, 700))

    # Lewy panel — trasa SA z aspect 1:1 (domena [0,1]² unit square, D-03)
    ax_trasa = Axis(fig[1, 1];
        title  = "Trasa TSP — błona mydlana (N=$(n_punktow))",
        xlabel = "Współrzędna X",
        ylabel = "Współrzędna Y",
        aspect = AxisAspect(1))

    # Prawy panel — wykres energii vs iteracja
    ax_energia = Axis(fig[1, 2];
        title  = "Energia trasy vs iteracja",
        xlabel = "Iteracja",
        ylabel = "Energia (długość trasy)")

    # Lewy panel ~60% szerokosci, prawy ~40% (D-01: szerokos prawego ~40-50% lewego)
    colsize!(fig.layout, 1, Relative(0.6))

    # NN baseline overlay (D-02) — szara przerywana linia, raz, statyczne (brak Observable).
    # Pokazuje "od czego startujemy" (baseline SA musi pokonac NN o >=5% — SC #4).
    # RESEARCH Q7: linestyle=:dash potwierdzony dla GLMakie 0.13.x.
    nn_points = Vector{Point2f}(undef, length(nn_trasa) + 1)
    @inbounds for k in 1:length(nn_trasa)
        nn_points[k] = Point2f(stan.punkty[nn_trasa[k]])
    end
    nn_points[end] = nn_points[1]  # zamkniecie cyklu NN baseline
    lines!(ax_trasa, nn_points; color=:gray, linestyle=:dash, alpha=0.3, linewidth=1)

    return fig, ax_trasa, ax_energia
end

"""
Tworzy KONKRETNIE-typowane Observables (RESEARCH Q12 — unika Observable{Any}
closure boxing pitfall — Pitfall 5) i podlacza je do plotow w juz utworzonych
ax_trasa/ax_energia. Zwraca NamedTuple z 3 obserwablami.

obs_trasa    — route points (scatter + lines) aktualizowane per klatka
obs_historia — historia energii jako Vector{Point2f}(iteracja, energia) per klatka
obs_overlay  — multiline string overlay 7-pol (D-04, Opcja B: 1 Observable dla calego tekstu)
"""
function _init_observables(stan::StanSymulacji, alg::Algorytm,
                           ax_trasa::Axis, ax_energia::Axis)
    # Konkretnie typowane Observables — bez Observable{Any} (Pitfall 5 + RESEARCH Q12)
    obs_trasa::Observable{Vector{Point2f}} =
        Observable(_trasa_do_punkty(stan))
    obs_historia::Observable{Vector{Point2f}} =
        Observable([Point2f(Float32(stan.iteracja), Float32(stan.energia))])
    obs_overlay::Observable{String} =
        Observable(_zbuduj_overlay_string(stan, alg, NaN, NaN, NaN))

    # Podlaczenie do lewego panelu — scatter (VIZ-03: markersize czytelne dla N=1000)
    # + lines (VIZ-02: cykl Hamiltonski domkniety przez _trasa_do_punkty n+1 punktow)
    scatter!(ax_trasa, obs_trasa; markersize=5, color=:cyan)
    lines!(ax_trasa, obs_trasa; color=:white, linewidth=1.5)

    # Podlaczenie do prawego panelu — krzywa energii vs iteracja
    lines!(ax_energia, obs_historia; color=:orange, linewidth=2)

    # Overlay tekstowy w lewym gornym rogu lewego panelu (D-04, top-left).
    # Pozycja w data coordinates: punkty leza w [0,1]² z aspect 1:1 → top-left z 2% marginem.
    # text!() zamiast textlabel!() — textlabel! moze byc niedostepne w GLMakie 0.13.x
    # (RESEARCH A5). space=:data dla poprawnej pozycji wzgledem osi.
    text!(ax_trasa, obs_overlay;
        position = Point2f(0.02f0, 0.98f0),
        align    = (:left, :top),
        fontsize = 11,
        color    = :white,
        space    = :data)

    return (; obs_trasa, obs_historia, obs_overlay)
end

# ---------------------------------------------------------------------------
# Publiczny API entry point (D-09)
# ---------------------------------------------------------------------------

"""
    wizualizuj(stan, params, alg; liczba_krokow, fps, kroki_na_klatke, eksport)

Animuje proces wyzarzania TSP w oknie GLMakie lub eksportuje animacje do pliku.

Otwiera okno GLMakie z dual-panel layoutem: lewy panel pokazuje trase SA
(punkty + linia cyklu Hamiltona) z NN baseline jako szara przerywana linia
(D-02); prawy panel pokazuje krzywa energia(iteracja) w czasie rzeczywistym.
Overlay tekstowy w lewym gornym rogu pokazuje 7 pol: Iteracja, Energia,
Temperatura, Alfa, FPS, Pozostalo, Akceptacja worsening (D-04). Wszystko
po polsku z poprawnym renderowaniem diakrytykow (D-03 dark theme).

Throttled updates: Observable aktualizowany raz na `kroki_na_klatke` SA
krokow (default 50, per D-05) — okno pozostaje responsywne.

# Argumenty pozycyjne
- `stan::StanSymulacji` — zainicjowany stan SA (po `inicjuj_nn!` i ustawieniu `stan.temperatura`)
- `params::Parametry` — parametry symulacji (m.in. `liczba_krokow`)
- `alg::Algorytm` — algorytm (np. `SimAnnealing`)

# Slowa kluczowe
- `liczba_krokow::Int=params.liczba_krokow` — liczba krokow SA do wykonania
- `fps::Int=30` — klatki na sekunde (live i eksport — unified per D-11)
- `kroki_na_klatke::Int=50` — krokow SA miedzy aktualizacjami Observables (throttling, VIZ-05)
- `eksport::Union{Nothing,String}=nothing` — sciezka do pliku MP4/GIF lub `nothing` dla live okna

# Zachowanie (D-09 — single API entry point)
- `eksport=nothing`: otwiera okno GLMakie, animuje w czasie rzeczywistym, czeka na zamkniecie
  (window pozostaje otwarty po SA stop z overlay'em "GOTOWE", D-06).
- `eksport="sciezka.mp4"` lub `"sciezka.gif"`: zapisuje animacje (blokujace; postep w terminalu
  przez ProgressMeter, EKS-03). Format wykrywany z extensji (EKS-02). Twardy error gdy plik
  docelowy juz istnieje (D-10, EKS-04).

Wymaga aktywnego kontekstu OpenGL. Headless cloud (CI, Docker bez X) NIE jest wspierany w v1
(D-13 — rzuca polski blad diagnostyczny).
"""
function wizualizuj(stan::StanSymulacji, params::Parametry, alg::Algorytm;
                    liczba_krokow::Int=params.liczba_krokow,
                    fps::Int=30,
                    kroki_na_klatke::Int=50,
                    eksport::Union{Nothing,String}=nothing)::Nothing
    # Walidacja argumentow wejsciowych (LANG-04 — asserty po angielsku)
    @assert liczba_krokow > 0 "liczba_krokow must be positive"
    @assert fps > 0 "fps must be positive"
    @assert kroki_na_klatke > 0 "kroki_na_klatke must be positive"

    # TTFP @info przed otwarciem okna — mierzy czas ladowania GLMakie (D-08).
    @info "Inicjalizacja wizualizacji TSP — ładowanie GLMakie..."

    # NN baseline trasa — uzywana dla overlay (D-02). Liczona raz (deterministyczne D-15).
    # Plan 03-05 pokaze ratio energia/energia_nn w overlay "GOTOWE".
    nn_trasa = trasa_nn(stan.D; start=1)

    # Motyw dark scoped — auto-reset po wyjsciu nawet przy throw (RESEARCH Pattern 7).
    # NIE uzywamy alternatywnego globalnego API — zanieczyszczaloby stan Makie po
    # powrocie z wizualizuj() (Pitfall E). Zakres try/finally wewnetrznie.
    with_theme(theme_dark()) do
        fig, ax_trasa, ax_energia = _setup_figure(stan, nn_trasa)
        obs = _init_observables(stan, alg, ax_trasa, ax_energia)

        # Branching live vs eksport (D-09) — wypelniane w plan 03-03 (live) i 03-04 (eksport).
        # Placeholder bledy po polsku (LANG-02) — usuwane w kolejnych planach.
        if eksport === nothing
            error("Live renderloop nie jest jeszcze zaimplementowany — wypelnienie w planie 03-03.")
        else
            error("Eksport nie jest jeszcze zaimplementowany — wypelnienie w planie 03-04.")
        end
    end
    return nothing
end
