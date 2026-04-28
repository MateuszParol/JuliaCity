# JuliaCity

## What This Is

`JuliaCity.jl` to pakiet w języku Julia, który rozwiązuje problem komiwojażera (TSP) dla 1000 losowych punktów 2D, wykorzystując heurystykę inspirowaną fizyką błony mydlanej — krawędzie trasy zachowują się jak elastyczne membrany napięte siłami napięcia powierzchniowego, „ściągając się" do trasy o minimalnej energii. Projekt jest zarówno eksperymentem algorytmicznym, jak i demonstracją wizualną: animacja procesu zaciągania trasy ma być fizycznie sugestywna i edukacyjna.

## Core Value

**Wizualnie przekonująca, fizycznie umotywowana heurystyka TSP w idiomatycznej Julii** — jeśli wszystko inne zawiedzie, użytkownik musi zobaczyć, jak trasa „bańki mydlanej" zaciska się wokół 1000 punktów w czasie rzeczywistym i otrzymać krótszą trasę niż naiwny baseline.

## Requirements

### Validated

(Brak — projekt świeży, każde wymaganie to hipoteza do walidacji przez wdrożenie)

### Active

- [ ] Generator 1000 losowych punktów 2D z opcjonalnym seedem (domyślnie deterministycznym)
- [ ] Heurystyka „bańki mydlanej" (wybór wariantu — force-directed, SA, lub hybryda — w fazie research)
- [ ] Funkcja `oblicz_energie()` jako miara długości trasy (type-stable, bez alokacji w hot path)
- [ ] Funkcja `symuluj_krok!()` aktualizująca stan symulacji in-place
- [ ] Wielowątkowość przez `Threads.@threads` w gorących pętlach
- [ ] Wizualizacja w GLMakie z animacją „zaciągania się" trasy w czasie rzeczywistym
- [ ] Eksport animacji do MP4/GIF (opcjonalny przełącznik)
- [ ] Polski język w kodzie, komentarzach, etykietach osi i tytułach
- [ ] Pełna struktura pakietu Julia (`src/`, `test/`, `examples/`, `Project.toml`)
- [ ] Benchmark jakości — porównanie wynikowej długości trasy z baselinem (np. nearest-neighbor)
- [ ] Suite testowa: poprawność cyklu Hamiltona, type stability, brak alokacji w gorącej pętli

### Out of Scope

- Inne metryki odległości niż euklidesowa — projekt to fizyczna analogia płaskiej błony, metryki nieeuklidesowe łamią analogię
- Punkty 3D lub wyższe wymiary — zakres wizualny i fizyczny ogranicza się do 2D
- Optymalizacja do dokładności Concorde'a — celem jest ładna heurystyka, nie state-of-the-art TSP solver
- Interfejs sieciowy / serwer / API — to pakiet do uruchamiania lokalnie z GLMakie
- Wsparcie dla N >> 1000 punktów (np. 100k) — algorytm i wizualizacja zoptymalizowane pod 1000 punktów
- Język inny niż polski w UI — twardy wymóg projektu

## Context

- **Środowisko:** Julia (najnowsza stabilna), uruchamiane lokalnie z dostępem do GPU/OpenGL przez GLMakie
- **Inspiracja algorytmiczna:** analogia błony mydlanej / minimalnych powierzchni / drzew Steinera — w fizyce błona mydlana minimalizuje powierzchnię, tu krawędzie minimalizują łączną długość trasy poprzez „napięcie powierzchniowe"
- **Możliwe warianty implementacyjne** (do rozstrzygnięcia w research):
  - **Force-directed na cyklu** — trasa = cykl Hamiltona, krawędzie jak sprężyny ściągają sąsiadów + ruchy 2-opt
  - **Simulated Annealing 2-opt** — energia = długość trasy, ruchy 2-opt/3-opt, harmonogram chłodzenia
  - **Hybryda** — SA jako szkielet decyzyjny + force-directed wygładzanie
- **Wymagania jakości kodu (twarde):**
  - Type stability (sprawdzane `@code_warntype` lub testem)
  - Brak global state — wszystko przekazywane jako argumenty
  - Wektoryzacja gdzie sensowne, brak zbędnych alokacji w gorącej pętli
  - `Threads.@threads` w pętlach niezależnych od kolejności

## Constraints

- **Tech stack**: Julia + GLMakie (preferowane) lub Plots.jl jako fallback — GLMakie daje płynniejszą animację dzięki backendowi OpenGL
- **Język UI/komentarzy**: wyłącznie polski — wymóg projektu, dotyczy też tytułów wykresów i opisów osi
- **Struktura kodu**: modułowa, wymagane funkcje `generuj_punkty()`, `oblicz_energie()`, `symuluj_krok!()`, `wizualizuj()` — kontrakt wprost zlecony przez użytkownika
- **Wydajność**: brak twardego deadline'u FPS, ale animacja musi być wizualnie płynna na zwykłym laptopie dla 1000 punktów
- **Reprodukowalność**: domyślny seed PRNG, by wynik był deterministyczny w testach

## Key Decisions

| Decyzja | Uzasadnienie | Status |
|---------|--------------|--------|
| Pakiet Julia z pełną strukturą `src/`, `test/`, `examples/` | Użytkownik chce „produkcyjną" jakość — testy + benchmark + struktura | — Pending |
| Nazwa pakietu: `JuliaCity` | Zgodne z nazwą katalogu, metafora „miasta punktów do odwiedzenia" | — Pending |
| Wybór wariantu algorytmu odroczony do fazy research | Researcher zbada literaturę i wybierze najlepszy wariant w kontekście fizycznej analogii | — Pending |
| Seed losowości domyślnie aktywny (np. `seed=42`) | Reprodukowalność dla testów i debugowania | — Pending |
| Wizualizacja: GLMakie + opcjonalny eksport MP4/GIF | Live window dla demonstracji, eksport dla dokumentacji/share | — Pending |
| Język: wyłącznie polski w kodzie i UI | Twardy wymóg użytkownika | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-28 after initialization*
