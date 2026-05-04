---
status: testing
phase: 04-demo-benchmarks-documentation
source:
  - 04-01-SUMMARY.md
  - 04-02-SUMMARY.md
  - 04-03-SUMMARY.md
  - 04-04-SUMMARY.md
  - 04-05-SUMMARY.md
  - 04-06-SUMMARY.md
  - 04-07-SUMMARY.md
  - 04-08-SUMMARY.md
started: "2026-05-04T07:22:38.000Z"
updated: "2026-05-04T07:22:38.000Z"
---

## Current Test

number: 5
name: Benchmark wrapper produkuje bench/wyniki.md
expected: |
  Uruchom: `bash bench/uruchom.sh` (POSIX) LUB `pwsh bench/uruchom.ps1` (Windows).
awaiting: decyzja produktowa po fail testu 4 (przed Test 5/6 lub równolegle)

## Tests

### 1. README renderuje się poprawnie i zawiera wymagane sekcje
expected: |
  H1 + Core Value + embed GIF + 7 H2 (Wymagania → Licencja) + α=0,9999 + T₀=2σ(Δ-energii) + headline ~4% + linki do bench/wyniki.md i LICENSE.
result: pass

### 2. Live demo (examples/podstawowy.jl) otwiera okno GLMakie z animacją
expected: |
  Uruchom: `julia --project=. --threads=auto examples/podstawowy.jl`

  Powinno (w ~30-60s od pierwszej kompilacji JIT):
  - Otworzyć okno GLMakie (~1280×720)
  - Pokazać 1000 niebieskich punktów + linia trasy NN (na start)
  - Animacja: trasa zaciąga się stopniowo (~50k kroków SA), długość maleje
  - Polskie etykiety: tytuł „SA-2-opt — N=1000", oś X „x", oś Y „y", overlay z numerem iteracji + temperaturą + energią po polsku
  - Trasa końcowa wyraźnie krótsza niż NN start (mniej krzyżowań)
result: issue
reported: |
  Skrypt CRASHUJE natychmiast po `[ Info: Wizualizacja gotowa, rozpoczynam symulację...`.

  Błąd zewnętrzny (mylący — formatter z try/catch przekwalifikował na display issue):
    ERROR: LoadError: GLMakie wymaga aktywnego kontekstu OpenGL. Brak displayu? Spróbuj `xvfb-run -a julia ...`

  Faktyczna przyczyna (z `caused by:`):
    MethodError: no method matching isopen(::Makie.Figure)
    Closest candidates: isopen(::GLFW.Window)
    @ src/wizualizacja.jl:202 (w `_live_loop`)

  Komentarz w kodzie (wizualizacja.jl:200-201) sam ostrzega:
    "Stop conditions: window zamkniete (A2 — isopen dla Figure) LUB SA osiagnal limit.
     `isopen(fig)` z Makie events; jezeli MethodError, plan 03-05 doda try/catch
     z fallback `events(fig).window_open[]`."

  Czyli: planowany fallback NIE wszedł do kodu. Plus: outer try/catch (linia 449-462)
  na słowo "GLMakie" w stack trace string maskuje prawdziwy MethodError jako display issue.

  Środowisko: Julia 1.12.6, threads=12, Win11. Phase 3 oznaczony COMPLETE w STATE.md
  ze 230/230 testami PASS — testy nie pokrywają live mode (VIZ-06 to tylko grep-level
  walkdir + isolation check, NIE faktyczne wizualizuj() wywołanie).
severity: blocker

### 3. Eksport GIF (examples/eksport_mp4.jl) produkuje assets/demo.gif
expected: |
  Uruchom: `julia --project=. --threads=auto examples/eksport_mp4.jl`

  Powinno (w ~3-5 min):
  - Wypisać @info „Ładowanie GLMakie...", „JuliaCity eksport GIF — N=1000, seed=42, threads=...", „Eksport do assets/demo.gif..."
  - Pokazać ProgressMeter (300 klatek)
  - Wypisać @info „GOTOWE eksport: assets/demo.gif, ratio=..., czas=...s"
  - Plik `assets/demo.gif` powstaje (lub jest nadpisany jeśli już istnieje — pre-rm policy w skrypcie)
  - `file assets/demo.gif` raportuje GIF89a image data
result: pass
notes: |
  Run zakończony exit 0 w ~1.5 min wallclock (po JIT compile cache hot).
  Output potwierdza:
  - "GOTOWE eksport (raw): assets/demo.gif, ratio=0.9806, czas=32.43s"
  - "[ffmpeg] Optymalizuję paletę + downscale do 700px (input: 0.22 MB)..."
  - "[ffmpeg] GOTOWE: assets/demo.gif = 0.14 MB (z 0.22 MB)"
  - Plik: GIF image data, version 89a, 700 x 350, 148977 bytes (145 KB)
  - ProgressMeter 300/300 klatek widoczny, ETA prawidłowy
  - Git: brak modyfikacji w demo.gif po regen → deterministyczny seed=42 produkuje bit-identyczny output
  - Bonus: ffmpeg post-processing (palette + downscale do 700px) jest BUILTIN w skrypcie — to wyjaśnia
    "deliberately optimized" rozmiar 145 KB w commit 0641444 (NIE manual edit, lecz auto-pipeline).

### 4. demo.gif w repo zawiera czytelną animację
expected: |
  Otwórz `assets/demo.gif` w przeglądarce graficznej (lub w GitHub preview).

  Powinieneś zobaczyć:
  - 1000 niebieskich punktów (rozsianych w jednostkowym kwadracie)
  - Czerwoną/zieloną linię trasy zaciągającą się przez ~10s
  - Auto-loop (GIF format property)
  - Polskie etykiety osi/tytułu (mogą być małe ze względu na rozmiar GIF, ale czytelne)

  Rozmiar pliku ~145 KB (zoptymalizowany przez human w commit 0641444 — akceptowalny tradeoff: szybki embed, treść zachowana).
result: fail
reported: |
  Dwa odrębne problemy:

  1. ZACHOWANIE: GIF miał pokazywać „budowanie trasy od zera", a pokazuje „dziwne przeskoki".
     Przyczyna źródłowa (NIE bug — design mismatch w examples/eksport_mp4.jl):
       - linia 42-43: `inicjuj_nn!(stan)` ⇒ start jest pełną trasą Nearest-Neighbor
         (1000 punktów już POŁĄCZONYCH), a NIE pustym płótnem
       - linia 48: `T_zero=0.001` ⇒ SA jest „zimne" od początku, akceptuje głównie
         2-opt swapy schodzące w dół energii
       - co widać na ekranie: 2-opt swap odwraca odcinek trasy między dwiema krawędziami;
         wizualnie 2 niesąsiadujące krawędzie nagle się „przepinają" → wygląda jak
         teleport/przeskok, mimo że to poprawny krok algorytmu
     Mental model użytkownika był inny: chciał widzieć JAK trasa powstaje od zera
     (NN construction edge-by-edge), a nie JAK istniejąca trasa jest optymalizowana.

  2. ROZDZIELCZOŚĆ: GIF 700×350 (źródło 1400×700, ffmpeg downscale Lanczos do 700px).
     Za mały na nowoczesny ekran (FullHD/2K/4K) — README embed wygląda mikroskopijnie.
     Konfiguracja: examples/eksport_mp4.jl:26 SZEROKOSC_GIF=700 + src/wizualizacja.jl:93
     Figure(size=(1400, 700)).
severity: blocker
notes: |
  Decyzja produktowa wymagana zanim cokolwiek poprawiać:
  - (A) Zostawić SA-from-NN, ale dodać klatkę „intro" pokazującą NN construction
        (~1-2s przed startem SA), żeby widz rozumiał kontekst startowy
  - (B) Zmienić eksport na pure NN-construction (pusta scena → kolejne krawędzie),
        bez SA — czysto edukacyjne „jak powstaje trasa zachłannie"
  - (C) Hybrydowy: NN-construction (5s) + SA optimization (5s), z separatorem
  - Plus: bumpnąć rozdzielczość. SZEROKOSC_GIF=1200 (źródło 1400×700 zostaje)
        LUB Figure(size=(1920, 960)) + SZEROKOSC_GIF=1280 (cięższy plik, ~300-500 KB).

### 5. Benchmark wrapper produkuje bench/wyniki.md
expected: |
  Uruchom: `bash bench/uruchom.sh` (POSIX) LUB `pwsh bench/uruchom.ps1` (Windows).

  Powinno (w ~5-10 min, dominuje bench_jakosc):
  - Auto-detect BenchmarkTools (jeśli nie dostępny → fallback do throwaway env z `Pkg.activate(temp=true)`)
  - 3 etapy `@info` „[run_all] (1/3) bench_energia.jl ...", „(2/3) bench_krok.jl ...", „(3/3) bench_jakosc.jl (~5 min) ..."
  - `@info "[run_all] GOTOWE — wyniki zapisane do bench/wyniki.md"`
  - `bench/wyniki.md` istnieje, zawiera 3 sekcje: `## Środowisko` / `## Microbenchmarki` / `## Jakość trasy`
  - Microbench rows alfabetycznie: `oblicz_energie` PRZED `symuluj_krok!`
  - Headline `~4-5% krótsza niż NN`, mean_ratio ∈ [0.85, 0.97]

  (Test już raz wykonany — commit cb51bce dał mean_ratio=0.9559. Re-run weryfikuje stabilność.)
result: [pending]

### 6. CONTRIBUTING.md §4 Typografia polska istnieje i jest spójny z README
expected: |
  Otwórz `CONTRIBUTING.md`. Sekcja „§4. Typografia polska" powinna:
  - Definiować konwencję: `„` (U+201E) + `"` (U+201D) cudzysłowy, `—` (U+2014) em-dash, NFC, BOM-free, LF
  - Być stosowana w `README.md` (2× `„`, 13× `—`, NFC, BOM-free, LF — zweryfikowane w plan 04-08)
  - Linkować do `.editorconfig` (Phase 1 D-21)
  - Renumerowane: stare §4 → §5, stare §5 → §6
result: [pending]

## Summary

total: 6
passed: 2
issues: 1
failed: 1
pending: 2
skipped: 0
blocked: 0

## Gaps

- truth: "assets/demo.gif pokazuje czytelnie 'budowanie trasy od zera' w rozdzielczości adekwatnej do README embed na nowoczesnym ekranie"
  status: failed
  reason: "(1) Aktualna animacja startuje z gotowej trasy NN (inicjuj_nn! w examples/eksport_mp4.jl:42) i pokazuje SA-2-opt swapy, które wizualnie wyglądają jak nieczytelne 'przeskoki' (odwrócenia odcinków między dwiema niesąsiadującymi krawędziami). Mental model użytkownika to konstrukcja trasy edge-by-edge od pustej sceny, nie optymalizacja istniejącej trasy. (2) Rozdzielczość finalna 700×350 (downscale Lanczos w eksport_mp4.jl:26 SZEROKOSC_GIF=700) jest za mała dla README embed na FullHD/2K/4K."
  severity: blocker
  test: 4
  artifacts:
    - "examples/eksport_mp4.jl:42-43 — `inicjuj_nn!(stan)` ustawia pełną trasę NN przed wizualizuj()"
    - "examples/eksport_mp4.jl:48 — `T_zero=0.001` powoduje że SA głównie schodzi w dół = 2-opt swapy = wizualne 'przeskoki'"
    - "examples/eksport_mp4.jl:26 — `SZEROKOSC_GIF=700` (Lanczos downscale)"
    - "src/wizualizacja.jl:93 — `Figure(size=(1400, 700))` źródłowa rozdzielczość Makie"
  missing:
    - "Decyzja produktowa: (A) intro NN+SA, (B) pure NN-construction, (C) hybrydowy NN+SA z separatorem"
    - "Bump rozdzielczości eksportu: SZEROKOSC_GIF≥1200 lub Figure(size=(1920, 960))"
    - "Test smoke 'pierwsza klatka GIF jest pustą sceną LUB zawiera mniej niż K krawędzi' — żaden test Phase 4 nie weryfikuje content frame-level"

- truth: "examples/podstawowy.jl uruchamia live demo SA-2-opt w oknie GLMakie z polskim overlay'em po `julia --project=. --threads=auto examples/podstawowy.jl`"
  status: failed
  reason: "MethodError: no method matching isopen(::Makie.Figure) w src/wizualizacja.jl:202 (`_live_loop`). Makie 0.24+ wycofał `isopen(::Figure)` — pozostawiono tylko `isopen(::GLFW.Window)`. Komentarz nad linią 202 wprost wskazuje brak fallbacku planowanego dla plan 03-05. Dodatkowo: outer try/catch wrapper (wizualizacja.jl:449-462) na string match `\"GLMakie\"` w error message maskuje MethodError jako misleading display-context error."
  severity: blocker
  test: 2
  artifacts:
    - "src/wizualizacja.jl:202 — `while isopen(fig) && stan.iteracja < liczba_krokow` (Makie.Figure passed)"
    - "src/wizualizacja.jl:373 — `if isopen(fig) && stan.iteracja >= liczba_krokow` (drugi call)"
    - "src/wizualizacja.jl:377 — `while isopen(fig); sleep(1/fps); end` (passive event loop, trzeci call)"
    - "src/wizualizacja.jl:449-462 — outer try/catch reformats MethodError as GLMakie display error"
  missing:
    - "Fallback `events(fig).window_open[]` LUB konwersja `fig.scene` → GLFW.Window dla wszystkich 3 isopen() call sites"
    - "Test smoke `wizualizuj(...; liczba_krokow=10, kroki_na_klatke=2)` z mock GLFW context (lub xvfb-conditional skip) — Phase 3 testy nie pokrywają live mode"
    - "Tighter outer try/catch: wykluczyć MethodError z reklasyfikacji jako display error (allow rethrow lub odróżnić initialization-time GLMakie błędy od runtime MethodErrors)"
