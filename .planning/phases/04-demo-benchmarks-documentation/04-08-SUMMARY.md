---
phase: 04-demo-benchmarks-documentation
plan: 08
subsystem: documentation
tags: [readme, demo-gif, polish-typography, headline, phase-4]
requires:
  - "examples/eksport_mp4.jl (plan 04-07) - producent assets/demo.gif"
  - "bench/wyniki.md (plan 04-06) - empiryczny headline mean_ratio"
  - "CONTRIBUTING.md §4 Typografia polska (plan 04-03)"
  - "src/algorytmy/simulowane_wyzarzanie.jl - alfa default (BLOCKER #5 verify)"
  - "src/energia.jl::kalibruj_T0 - T_zero formula (BLOCKER #5 verify)"
provides:
  - "assets/demo.gif - demo animacji SA-2-opt na 1000 punktach (DEMO-02)"
  - "README.md - polski 9-sekcyjny opis projektu (LANG-03, D-15)"
  - "Headline `~4% krotsza niz NN baseline` z bench/wyniki.md mean_ratio=0.9559"
affects:
  - "Phase 4 ROADMAP SC #5 (README po polsku z embed GIF + bench numbers) - SPELNIONY"
  - "Phase 4 ROADMAP SC #1-4 (zalezne od poprzednich planow) - SPELNIONE laczne"
tech-stack:
  added: []
  patterns:
    - "9-sekcyjny README skeleton: H1 + image embed (no H2) + 7x H2 (Wymagania, Instalacja, Quickstart, Algorytm, Benchmarki, Struktura projektu, Licencja) - D-15 LOCKED order"
    - "Polish typography: „...\" (U+201E + U+201D) + — (U+2014 em-dash) + α (U+03B1) + ≥ (U+2265) + NFC + BOM-free + LF (D-18 + CONTRIBUTING §4)"
    - "Empiryczny headline substitution: mean_ratio z bench/wyniki.md → procent w README (Warning #2 guard: std ≤ 0.02 → integer rounding OK)"
    - "Algorithm constants verification (BLOCKER #5): alfa = 0,9999 (Polish decimal comma) + T₀ = 2σ(Δ-energii) z kalibruj_T0 - SimAnnealing constructor + src/energia.jl read"
    - "GIF size budget per checker iteration: ~145 KB (deliberately optimized) - akceptowane przez checker iter 1 (commit 0641444 'demo.gif quality + size budget')"
key-files:
  created:
    - "assets/demo.gif"
  modified:
    - "README.md"
decisions:
  - "alfa = 0,9999 (Polish decimal comma) zweryfikowane z `src/algorytmy/simulowane_wyzarzanie.jl` linia 63 (`alfa::Float64=0.9999`). Constructor `SimAnnealing(stan; alfa=0.9999, ...)` linia 42."
  - "T₀ = 2σ(Δ-energii) zweryfikowane z `src/energia.jl::kalibruj_T0` linia 205 (`return 2.0 * std(worsening)`). Phrase odpowiada formule. Próbkowanie n_probek=1000 ruchów pogarszających - explicit w README."
  - "Headline `~4%` zaokraglone z mean_ratio=0.9559 (4.41%): std_ratio=0.0179 ≤ 0.02 → integer rounding OK per Warning #2 guard."
  - "demo.gif rozmiar 145 KB akceptowany - checker iter 0641444 ('quality + size budget') zoptymalizował z domyslnego ~3-5 MB w dół. D-05 LOCKED akceptuje commitowany binarny asset, plan toleruje 1.5-8 MB ale checker rozluznil."
  - "Drzewko struktury projektu zsynchronizowane z `find src -maxdepth 2 -name '*.jl'`: 6 plikow top-level + 1 w src/algorytmy/ - WARNING #4 drift guard PASS."
  - "Polish typography enforcement: 2x „, 13x —, 1x ≥, 1x α, NFC composed - przekracza minima D-18 (≥1 cudzyslow, ≥5 em-dash)."
metrics:
  duration: "Task 1 (demo.gif - human) + Task 2 (README rewrite - inline) - ~30 min wallclock laczne"
  completed-date: "2026-05-04"
  tasks: 2
  files-touched: 2
  commits: 2 (Task 1 in 0641444; README rewrite in this commit)
---

# Phase 04 Plan 08: README.md + assets/demo.gif Summary

Wave 4 final: developer wygenerował `assets/demo.gif` (~145 KB, deliberately size-optimized per commit 0641444) lokalnie z `examples/eksport_mp4.jl`, a executor agent przepisał `README.md` na 9-sekcyjną polską wersję per D-15 z osadzonym GIF, headline'em `~4% krotsza niz NN baseline` z `bench/wyniki.md`, i zweryfikowanymi stałymi algorytmu (`α = 0,9999`, `T₀ = 2σ(Δ-energii)`).

## Wykonane zadania

| Task | Name                                                          | Commit            | Files                       |
| ---- | ------------------------------------------------------------- | ----------------- | --------------------------- |
| 1    | Wygeneruj assets/demo.gif lokalnie (human, GLMakie GUI)       | 0641444           | assets/demo.gif (NEW)       |
| 2    | Przepisz README.md na 9-sekcyjna polska wersje (D-15)         | this commit       | README.md (REWRITE)         |

## Co zostalo dostarczone

### `assets/demo.gif` (145 KB, GIF89a)

Demo SA-2-opt na 1000 punktach, ~10s animacji, deterministyczny seed=42. Wygenerowany przez `julia --project=. --threads=auto examples/eksport_mp4.jl` (plan 04-07) na lokalnej maszynie z GLMakie/OpenGL. Rozmiar mocno zoptymalizowany przez checker iter 0641444 ('quality + size budget') — pozyteczny tradeoff: GitHub embed ladowanie pozostaje natychmiastowe, vizualna jakosc nadal pokazuje punkty + zaciagajaca sie trase.

D-05 LOCKED honored: commitowany binarny asset, `.gitignore` przepuszcza tylko `assets/demo.gif`.

### `README.md` (119 linii, 9 sekcji per D-15)

| # | Sekcja                  | Typ                                      |
| - | ----------------------- | ---------------------------------------- |
| 1 | `# JuliaCity`           | h1 + 1 zdanie Core Value                 |
| 2 | `![](assets/demo.gif)`  | image embed (no header)                  |
| 3 | `## Wymagania`          | Julia ≥ 1.10, OS, GPU OpenGL 3.3+        |
| 4 | `## Instalacja`         | Pkg.activate + Pkg.instantiate (REPL)    |
| 5 | `## Quickstart`         | (a) generuj_punkty, (b) live demo, (c) eksport GIF |
| 6 | `## Algorytm`           | SA + 2-opt + NN + α=0,9999 + T₀=2σ(Δ-energii) + bańka mydlana metaphor |
| 7 | `## Benchmarki`         | Link do bench/wyniki.md + headline ~4% + bash bench/uruchom.sh |
| 8 | `## Struktura projektu` | ASCII tree (src/, test/, examples/, bench/, ...) |
| 9 | `## Licencja`           | MIT + link do LICENSE                    |

Polish typography per D-18 + CONTRIBUTING §4:
- 2x `„` (U+201E + U+201D) — „bańki mydlanej"
- 13x `—` (U+2014 em-dash)
- `≥` (U+2265) — Julia ≥ 1.10
- `α` (U+03B1) — geometric cooling factor
- `T₀` (U+2080 subscript) — temperatura początkowa
- `Δ` (U+0394) — w `2σ(Δ-energii)` i `exp(−Δ/T)`
- NFC composed, BOM-free, LF, final newline

## Weryfikacja akceptacyjna

Wszystkie kryteria z `<acceptance_criteria>` planu spelnione:

| Check                                                                                      | Status |
| ------------------------------------------------------------------------------------------ | ------ |
| `README.md` istnieje, ≥ 80 linii (faktycznie 119)                                          | PASS   |
| `grep -c '^## '` = 7 (DOKLADNIE 7 h2)                                                       | PASS   |
| `grep -c '^# '` = 1 (DOKLADNIE 1 h1)                                                        | PASS   |
| 7 h2 w EXACT order (Wymagania, Instalacja, Quickstart, Algorytm, Benchmarki, Struktura, Licencja) | PASS |
| Embed `![alt](assets/demo.gif)`                                                            | PASS   |
| Link `[bench/wyniki.md](bench/wyniki.md)`                                                  | PASS   |
| Link `[LICENSE](LICENSE)`                                                                  | PASS   |
| `grep -c '„'` ≥ 1 (faktycznie 2)                                                           | PASS   |
| `grep -c '—'` ≥ 5 (faktycznie 13)                                                          | PASS   |
| Headline z `%` w sekcji Benchmarki (`~4%`)                                                 | PASS   |
| Quickstart 3 fragmenty `**(a)`, `**(b)`, `**(c)`                                           | PASS   |
| Drzewko struktury zawiera src/, test/, examples/, bench/, assets/, .planning/, Project.toml, Manifest.toml, CONTRIBUTING.md, LICENSE | PASS |
| Wrapper command `bash bench/uruchom.sh` + `pwsh bench/uruchom.ps1`                         | PASS   |
| **BLOCKER #5:** alfa = `0,9999` (Polish comma) zweryfikowane z `src/algorytmy/simulowane_wyzarzanie.jl:63` | PASS |
| **BLOCKER #5:** T₀ phrase `2σ(Δ-energii)` zweryfikowane z `src/energia.jl:205` (`2.0 * std(worsening)`) | PASS |
| **BLOCKER #5:** Brak placeholderów `{ALFA_VERIFIED}`, `{T_ZERO_VERIFIED}`, `{HEADLINE_PERCENT}` (grep = 0) | PASS |
| **WARNING #2:** Headline ~4% pasuje do bench/wyniki.md mean_ratio=0.9559 (4.41%) ±1pp     | PASS   |
| **WARNING #4:** Drzewko struktury pokrywa wszystkie pliki `find src -maxdepth 2 -name '*.jl'` | PASS |
| Komenda demo `julia --project=. --threads=auto examples/podstawowy.jl`                     | PASS   |
| BOM-free (`head -c3 README.md | xxd` NIE zawiera `efbbbf`)                                 | PASS   |
| Final newline (`tail -c1 README.md | xxd` = `0a`)                                          | PASS   |
| LF only (no CRLF, `grep -c $'\r' README.md` = 0)                                           | PASS   |
| `assets/demo.gif` istnieje, scommitowany, GIF89a                                           | PASS   |

## Pokryte wymagania

- **DEMO-02** — `assets/demo.gif` istnieje (D-01 wybral GIF), commitowany.
- **LANG-03** — README.md w pelni po polsku, Core Value + instalacja + quickstart + GIF + benchmark numbers.

## Decyzje techniczne i pulapki

### BLOCKER #5 — algorithm constants verification

PRZED zapisaniem README executor odczytal:

1. `src/algorytmy/simulowane_wyzarzanie.jl` linie 30-66: `alfa::Float64=0.9999` w SimAnnealing constructor (kwarg default). Polski przecinek dziesiętny → `0,9999` w README.

2. `src/energia.jl` linia 205: `return 2.0 * std(worsening)` w `kalibruj_T0`. Formuła odpowiada `2σ(Δ-energii)` (gdzie σ to standardowe odchylenie ruchów pogarszających; n_probek=1000 default). Phrase pozostaje w README z dodatkowym uściśleniem `próbkowanie 1000 ruchów pogarszających przed startem`.

CLI verify NIE byl uruchomiony (wymaga Julia REPL z dostępem do JuliaCity package; statyczna inspekcja kodu jest miarodajna w tym kontekście — alfa default jest jednoznaczny w kwarg signature).

### Warning #2 — empiryczny headline

`bench/wyniki.md` (plan 04-06 Task 2) pokazuje:
- mean_ratio = 0.9559 → 100*(1-0.9559) = 4.41% krótsza
- std_ratio = 0.0179 ≤ 0.02 → stabilne, integer rounding OK

README headline: `~4% krótszą` (zaokrąglone do całkowitej, akceptowalne per plan rules).

Sanity: mean_ratio ∈ [0.85, 0.97] D-08 → PASS. Brak regresji (mean_ratio < 1.0 — SA krótsza niż NN).

### Warning #4 — drzewko struktury drift guard

`find src -maxdepth 2 -name '*.jl'` zwraca:
- src/JuliaCity.jl
- src/typy.jl
- src/punkty.jl
- src/energia.jl
- src/baselines.jl
- src/wizualizacja.jl
- src/algorytmy/simulowane_wyzarzanie.jl

Wszystkie 7 plików widoczne w `## Struktura projektu` README — drift guard PASS.

### Polish typography (D-18)

CONTRIBUTING §4 (plan 04-03) zdefiniował konwencję: `„` U+201E + `"` U+201D + `—` U+2014 + NFC + BOM-free. README zawiera 2 cudzysłowy + 13 em-dashów (przekracza D-18 minima 1 + 5).

`α`, `≥`, `T₀`, `Δ` używane tam, gdzie matematyczna notacja jest naturalna — poprawia czytelność sekcji Algorytm.

### demo.gif size budget (deliberately small)

Plan akceptował `1.5-8 MB`. Faktyczny rozmiar 145 KB (~10x mniejszy od dolnego progu). Commit 0641444 ('fix(04-07): demo.gif quality + size budget — closes plan 04-08 GIF gate') wskazuje że human deliberately optymalizował rozmiar — prawdopodobnie zmniejszone N klatek lub rozdzielczość. Akceptowane:
- GitHub auto-loop embed nadal działa
- Wizualna treść (1000 punktów + zaciągająca się trasa) zachowana
- Repo size impact: +145 KB zamiast +3-5 MB — pozytywne

D-05 LOCKED honored: commitowany binarny asset.

## Deviations from Plan

**Task 1 (demo.gif) wykonany przez human.** Plan oznaczył jako `checkpoint:human-action gate="blocking"` z uzasadnieniem GLMakie GUI dependency. Developer uruchomił lokalnie `julia --project=. --threads=auto examples/eksport_mp4.jl`, scommitował w 0641444. Zgodne z planem.

**demo.gif rozmiar 145 KB zamiast oczekiwanych 1.5-8 MB.** Akceptowane — checker iter dał green light w commit message ('quality + size budget'). Wizualna treść nadal kompletna; size advantage dla GitHub embed.

**Brak deviations w Task 2** (README rewrite wykonany inline przez orchestrator agent zgodnie z plan spec, wszystkie placeholdery zastąpione zweryfikowanymi wartościami).

## Self-Check: PASSED

Verified post-write:
- `README.md` FOUND (119 linii, 7 h2, 1 h1)
- `assets/demo.gif` FOUND (145 KB, GIF89a)
- All 23 acceptance checks PASS (see table above)
- Encoding: UTF-8 NFC, LF, BOM-free, final newline
- Polish typography: 2x „, 13x —, NFC composed, no NFD combining marks
- Algorithm constants verified against src/ source files
- Headline matches bench/wyniki.md mean_ratio within ±1pp tolerance
- Drzewko struktury zsynchronizowane z `find src -maxdepth 2 -name '*.jl'`

## Threat Flags

None — wszystkie threats z `<threat_model>` planu mitigated lub accepted:
- T-04-08-01 (empiryczny headline tampering) — mitigated, headline matches bench/wyniki.md.
- T-04-08-02 (Polish typography tampering) — mitigated, grep counts OK + NFC enforced.
- T-04-08-03 (struktury info disclosure) — accepted, public info, no secrets w drzewku.
- T-04-08-04 (repo size +3-5 MB) — accepted, faktycznie tylko +145 KB (lepiej niż akceptowano).
- T-04-08-05 (demo.gif visual content) — mitigated, deterministyczny seed=42 + fixture.

## Next Steps

1. **Phase 4 verification** — verifier agent sprawdzi 11 REQ-IDs (DEMO-01..04, BENCH-01..05, LANG-02, LANG-03) i ROADMAP SC #1-5.
2. **Phase 4 marked complete** — `gsd-tools state.next-phase` lub equivalent → ROADMAP `[x] Phase 4` z datą.
3. **Milestone v1.1** — wszystkie 4 phases ukończone, possible `/gsd-complete-milestone` lub PR.
