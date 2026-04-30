# Phase 3: Visualization & Export - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-30
**Phase:** 3-Visualization & Export
**Areas discussed:** Układ okna + overlay, Rytm + UX animacji, Eksport behavior, Headless / no-OpenGL

---

## A. Układ okna + overlay

### A.1 — Layout okna (jeden panel czy dwa?)

| Option | Description | Selected |
|--------|-------------|----------|
| Single-panel (trasa + punkty) | Tylko okno z 2D wizualizacją trasy SA. Najprostsze, najmniej kodu, najbardziej w stylu "bańka mydlana się zaciska". | |
| Dual-panel: trasa + wykres energii | Lewy panel: 2D trasa. Prawy panel: wykres energia(iteracja) w czasie rzeczywistym. Bardziej edukacyjne. | ✓ |
| Dual-panel: trasa + temperatura/energia | J/w ale wykres pokazuje obie krzywe — energia (lewa oś) + temperatura (prawa oś log). | |

**User's choice:** Dual-panel: trasa + wykres energii
**Notes:** Edukacyjny aspect aligns z PROJECT.md core value ("eksperyment algorytmiczny + demonstracja wizualna").

### A.2 — Overlay tekstowy (ile informacji?)

| Option | Description | Selected |
|--------|-------------|----------|
| Minimum: iteracja + energia | Per VIZ-04 — tylko numer iteracji i bieżąca energia. Najmniej rozproszenia. | |
| Rich: + temperatura + ratio vs NN | Iteracja, energia, T, energia/energia_nn ratio. Edukacyjny — widać chłodzenie + postęp vs baseline. | |
| Full debug: + alfa, FPS, ETA, accept rate | Wszystko z rich + alfa, FPS, ETA, accept rate worsening. Dla developera/debug. | ✓ |

**User's choice:** Full debug: + alfa, FPS, ETA, accept rate
**Notes:** User chce pełną wizualizację dynamiki SA. Wymusza Observable{String} dla 7 pól + rolling window dla accept rate + FPS estimation.

### A.3 — NN baseline jako tło/przerywana linia?

| Option | Description | Selected |
|--------|-------------|----------|
| Tak — NN jako szara przerywana | NN renderowana raz przed SA jako tło (alpha=0.3, dashed). | ✓ |
| Nie — tylko aktualna trasa | Czyste minimum, tylko aktualny stan SA. | |

**User's choice:** Tak — NN jako szara przerywana

### A.4 — Theme okna i aspect ratio?

| Option | Description | Selected |
|--------|-------------|----------|
| Dark theme + aspect 1:1 | `theme_dark()` + `AxisAspect(1)`. Trasa świeci, dramatyczna. | ✓ |
| Light theme + aspect 1:1 | `theme_light()`. Czytelniejsze do screenshotów. | |
| Dark theme + auto aspect | Dark + auto aspect. Elastyczne dla nieuni-square'owych domen. | |

**User's choice:** Dark theme + aspect 1:1

---

## B. Rytm + UX animacji

### B.1 — KROKI_NA_KLATKE default

| Option | Description | Selected |
|--------|-------------|----------|
| 10 — wolna, każdy ruch widoczny | "Pieszczotliwa". 50_000 kroków = 5000 klatek = 167s @30fps. | |
| 50 — balans | Trasa zaciska się wyraźnie ale szybko. 50_000 kroków = 1000 klatek = 33s @30fps. | ✓ |
| 100 — szybka iteracja | Trasa skacze widocznie. 50_000 kroków = 500 klatek = 17s @30fps. | |

**User's choice:** 50 — balans

### B.2 — Co po zakończeniu SA?

| Option | Description | Selected |
|--------|-------------|----------|
| Freeze + "GOTOWE" overlay | Okno otwarte, last frame frozen, dodatkowy overlay z ratio. Manual close. | ✓ |
| Auto-close po 3s | Okno zamyka się automatycznie. | |
| Loop replay od początku | Animacja w pętli. | |

**User's choice:** Freeze + "GOTOWE" overlay

### B.3 — Interactive Makie controls (zoom/pan)?

| Option | Description | Selected |
|--------|-------------|----------|
| Włączone (Makie default) | Zoom/pan kółkiem myszy / drag. | ✓ |
| Wyłączone (lock view) | Stale 1:1 widok całej domeny [0,1]². | |

**User's choice:** Włączone (Makie default)

### B.4 — TTFP grace overlay przy starcie?

| Option | Description | Selected |
|--------|-------------|----------|
| Tak — "Ładowanie GLMakie..." przed pierwszą klatką | Pitfall 14 mitigation. | ✓ |
| Nie — niech sam użyje stdout | GLMakie sam loguje compile time. | |

**User's choice:** Tak — "Ładowanie GLMakie..." przed pierwszą klatką

---

## C. Eksport behavior

### C.1 — API eksportu (jeden czy dwa entry pointy?)

| Option | Description | Selected |
|--------|-------------|----------|
| Single API: `wizualizuj(...; eksport=path)` | Per VIZ-01. Gdy `eksport=path` — `Makie.record()` blocking. | ✓ |
| Split: `wizualizuj()` + `eksportuj(...)` | Per Pitfall 6 — user explicit opt-in do blocking call. | |
| Single API + tryb "both": `eksport=path, podgląd=true` | Eksport + live window jednocześnie. | |

**User's choice:** Single API: `wizualizuj(...; eksport=path)`
**Notes:** Plan musi zaadresować Pitfall 6 mitigation przez ProgressMeter + `@info` message przed startem record.

### C.2 — File-exists policy?

| Option | Description | Selected |
|--------|-------------|----------|
| Error z czytelną wiadomością | `error("Plik 'X' już istnieje. Usuń lub wybierz inną nazwę.")`. | ✓ |
| Auto-overwrite (silently) | Po prostu nadpisuje. | |
| Auto-suffix (`demo-1.mp4`) | Dodaje numer. | |

**User's choice:** Error z czytelną wiadomością

### C.3 — FPS eksportu

| Option | Description | Selected |
|--------|-------------|----------|
| = `fps` arg (jeden parametr) | Live i eksport używają tego samego FPS. | ✓ |
| Osobny `eksport_fps` (default 60) | Live 30fps, eksport 60fps. | |

**User's choice:** = `fps` arg (jeden parametr)

### C.4 — Eksport czas trwania

| Option | Description | Selected |
|--------|-------------|----------|
| Do `liczba_krokow` argumentu (kontrolowany) | User mówi ile kroków SA = ile klatek. | ✓ |
| Do patience stop (może być krótszy) | Eksport kończy się gdy SA hits stagnation. | |

**User's choice:** Do `liczba_krokow` argumentu

---

## D. Headless / no-OpenGL fallback

### D.1 — Failure mode gdy GLMakie nie startuje

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail z czytelną wiadomością | `error("GLMakie wymaga OpenGL...")`. Brak fallback. | ✓ |
| CairoMakie fallback (no live, render to PNG) | Per Pitfall 7. Dodatkowy backend code. | |
| Skip-with-warning (no-op) | `@warn` i return. | |

**User's choice:** Hard fail z czytelną wiadomością

### D.2 — Czy `runtests.jl` smoke-testuje `wizualizuj()`?

| Option | Description | Selected |
|--------|-------------|----------|
| Nie — core pure-headless, wizualizacja ręcznie | Najprostsze; CI nie potrzebuje OpenGL. | ✓ |
| Tak — smoke test z CairoMakie + xvfb | Lepsze pokrycie, więcej kodu. | |
| Tak — smoke test bez open-GL przez @test_throws | Symboliczne pokrycie. | |

**User's choice:** Nie — core pure-headless, wizualizacja ręcznie

### D.3 — Strategia GitHub Actions CI

| Option | Description | Selected |
|--------|-------------|----------|
| Brak GLMakie w CI — testy core'u na 1.10/1.11/1.12 × ubuntu/win/macos | Najprostsze, najszybsze CI. | ✓ |
| Linux CI z xvfb dla Phase 4 demo eksportu | Powolne (~2 min), ale gwarantuje że eksport działa. | |

**User's choice:** Brak GLMakie w CI

---

## Claude's Discretion

User explicitly powiedział "akceptuje wszystko" w sesji 02-14, ale dla Phase 3 wybrał konkretne opcje. Estetyczne detale (kolory punktów/linii, fonty, padding, markersize, position overlay'u) — pozostawione Claude'owi do decyzji w fazie planning, na podstawie Makie defaults z dark theme. Udokumentowane w 03-CONTEXT.md `### Claude's Discretion`.

## Deferred Ideas

(Pełna lista w 03-CONTEXT.md `<deferred>`. Skrócona:)

- CairoMakie backend abstraction (v2) — D-13 świadomie rejected
- Color gradients temperatura→energia (v2)
- Loop replay (v2) — D-06 freeze chosen
- `eksport_fps` osobny (v2) — D-11 unified
- Auto-suffix file naming (v2) — D-10 error chosen
- `nadpisz::Bool` kwarg (v2)
- Smoke test wizualizacji w runtests.jl (Phase 4 może rozważyć)
- Linux CI + xvfb dla README badge (Phase 4 dyskusja)
- PackageCompiler sysimage (v2/Phase 5)
- DataInspector per-point hover (v2)
- Multi-algorithm comparison view (v2)
- Stronger SA move (3-opt / or-opt / double-bridge) — z plan 02-14 deferred
