# Wizualizacja TSP — okno GLMakie + eksport MP4/GIF.
# Pokrywa REQ VIZ-01..07, EKS-01..04 (11 wymagan).
#
# WAZNE (VIZ-06 LOCKED): src/wizualizacja.jl jest JEDYNYM plikiem w src/
# importujacym `using GLMakie`. Core (`punkty.jl`, `energia.jl`, `baselines.jl`,
# `algorytmy/`, `typy.jl`) pozostaje pure-headless — `runtests.jl` nie wymaga
# OpenGL. Dowod: `grep -rl "using GLMakie" src/` zwraca tylko ten plik.
#
# Architektura (D-09):
#   - eksport === nothing  → live renderloop (display(fig) + while isopen(fig))
#   - eksport isa String   → blocking Makie.record() + ProgressMeter
#
# Decyzje uzytkownika (15 LOCKED w 03-CONTEXT.md):
#   D-01 dual-panel; D-02 NN baseline szara linia; D-03 dark theme + aspect 1:1;
#   D-04 7-pol overlay po polsku; D-05 KROKI_NA_KLATKE=50; D-06 GOTOWE freeze;
#   D-09 single API entry; D-10 file-exists hard error; D-11 unified fps;
#   D-12 export = liczba_krokow / KROKI_NA_KLATKE klatek; D-13 GLMakie hard-fail polski.
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
# Makie.record(), set_theme!, with_theme, theme_dark, Figure, Axis, AxisAspect,
# Relative, colsize!, scatter!, lines!, text!, textlabel! — wszystko w scope
# przez `using GLMakie`.

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
    # Body bedzie wypelniony w planach 03-02 (figure setup), 03-03 (live loop),
    # 03-04 (export branch), 03-05 (hard-fail wrapper + GOTOWE overlay).
    error("Wizualizacja nie jest jeszcze zaimplementowana — wypelnienie body w planach 03-02..03-05.")
    return nothing
end
