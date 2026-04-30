---
phase: 04-demo-benchmarks-documentation
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - bench/diagnostyka_test05.jl
  - bench/diagnostyka_test05_budget.jl
  - bench/diagnostyka_test05_random_vs_nn.jl
  - bench/historyczne/diagnostyka_test05.jl
  - bench/historyczne/diagnostyka_test05_budget.jl
  - bench/historyczne/diagnostyka_test05_random_vs_nn.jl
  - bench/historyczne/README.md
autonomous: true
requirements:
  - BENCH-05
must_haves:
  truths:
    - "Stare diagnostyka_test05*.jl pliki nie znajdują się już w bench/ (top-level), tylko w bench/historyczne/"
    - "bench/historyczne/README.md wyjaśnia kontekst Phase 2 plan 02-14 erratum"
    - "Wszystkie 3 pliki diagnostyki zachowane (audit trail, NIE skasowane)"
  artifacts:
    - path: "bench/historyczne/diagnostyka_test05.jl"
      provides: "Phase 2 plan 02-14 erratum diagnostic — audit trail"
      contains: "diagnostyka"
    - path: "bench/historyczne/diagnostyka_test05_budget.jl"
      provides: "Phase 2 budget sweep diagnostic"
      contains: "budget"
    - path: "bench/historyczne/diagnostyka_test05_random_vs_nn.jl"
      provides: "Phase 2 random-vs-NN starting point sweep"
      contains: "random"
    - path: "bench/historyczne/README.md"
      provides: "Polski opis archiwum + link do plan 02-14 SUMMARY"
      min_lines: 8
  key_links:
    - from: "bench/historyczne/README.md"
      to: ".planning/phases/02-energy-sa-algorithm-test-suite/"
      via: "wzmianka w treści"
      pattern: "02-14"
---

<objective>
Wave 1 cleanup: Przenieść 3 pliki diagnostyki Phase 2 plan 02-14 (`bench/diagnostyka_test05*.jl`) do nowego podkatalogu `bench/historyczne/` (D-16 LOCKED — NIE usuwać, audit trail). Dodać krótki polski README.md w `bench/historyczne/` wyjaśniający kontekst.

Purpose: Czyści `bench/` top-level dla 4 nowych plików Phase 4 (`bench_energia.jl`, `bench_krok.jl`, `bench_jakosc.jl`, `run_all.jl`) bez utraty empirycznej diagnozy 2-opt local minimum z plan 02-14 erratum.
Output: Nowy katalog `bench/historyczne/` z 3 przeniesionymi plikami + README.md.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md
@.planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md
@.planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Przenieś 3 pliki diagnostyki do bench/historyczne/</name>
  <read_first>
    - bench/diagnostyka_test05.jl (zobaczyć top-of-file komentarz i upewnić się że to Phase 2 plan 02-14 artifact)
    - bench/diagnostyka_test05_budget.jl (j.w.)
    - bench/diagnostyka_test05_random_vs_nn.jl (j.w.)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-16 explicit)
  </read_first>
  <action>
    Wykonać git move (zachowuje historię) na 3 plikach:

    1. `mkdir -p bench/historyczne`
    2. `git mv bench/diagnostyka_test05.jl bench/historyczne/diagnostyka_test05.jl`
    3. `git mv bench/diagnostyka_test05_budget.jl bench/historyczne/diagnostyka_test05_budget.jl`
    4. `git mv bench/diagnostyka_test05_random_vs_nn.jl bench/historyczne/diagnostyka_test05_random_vs_nn.jl`

    Jeśli `git mv` niedostępne (np. plik nie był jeszcze tracked), użyć zwykłego `mv` + `git add`.

    NIE modyfikować zawartości plików — to artefakty audit trail. Komentarze, importy, funkcje — wszystko zostaje 1:1.

    KRYTYCZNE: nazwa katalogu `historyczne/` (ASCII per Phase 1 D-23, polski bez diakrytyku) — NIE `historycznę/`.
  </action>
  <verify>
    <automated>test -d bench/historyczne &amp;&amp; test -f bench/historyczne/diagnostyka_test05.jl &amp;&amp; test -f bench/historyczne/diagnostyka_test05_budget.jl &amp;&amp; test -f bench/historyczne/diagnostyka_test05_random_vs_nn.jl &amp;&amp; ! test -f bench/diagnostyka_test05.jl &amp;&amp; ! test -f bench/diagnostyka_test05_budget.jl &amp;&amp; ! test -f bench/diagnostyka_test05_random_vs_nn.jl</automated>
  </verify>
  <acceptance_criteria>
    - Katalog `bench/historyczne/` istnieje (`test -d bench/historyczne` exit 0).
    - Wszystkie 3 pliki obecne w nowej lokalizacji: `bench/historyczne/diagnostyka_test05.jl`, `bench/historyczne/diagnostyka_test05_budget.jl`, `bench/historyczne/diagnostyka_test05_random_vs_nn.jl`.
    - Wszystkie 3 pliki nieobecne w starej lokalizacji: `bench/diagnostyka_test05.jl`, `bench/diagnostyka_test05_budget.jl`, `bench/diagnostyka_test05_random_vs_nn.jl`.
    - Zawartość plików niezmieniona — `wc -l bench/historyczne/diagnostyka_test05.jl` zwraca tę samą liczbę linii co przed move (sprawdzenie integralności).
    - `git status` pokazuje renames (R), nie delete+add (status `R`/`renamed:` w git output).
  </acceptance_criteria>
  <done>3 pliki diagnostyki Phase 2 02-14 zachowane w bench/historyczne/, top-level bench/ czysty dla Phase 4.</done>
</task>

<task type="auto">
  <name>Task 2: Utwórz bench/historyczne/README.md</name>
  <read_first>
    - bench/historyczne/diagnostyka_test05.jl (świeżo przeniesiony — top-of-file komentarz pokaże co dokładnie ten plik robi)
    - .planning/phases/02-energy-sa-algorithm-test-suite/02-CONTEXT.md (sekcja D-03 erratum — opis 2-opt local minimum dla cytowania)
    - .planning/STATE.md (linia ~80 — TEST-05 ratio 0.9408 lock)
  </read_first>
  <action>
    Utworzyć plik `bench/historyczne/README.md` z następującą zawartością (polski, NFC, BOM-free, LF, final newline):

    ```markdown
    # Archiwum diagnostyki Phase 2 (plan 02-14 erratum)

    Trzy pliki w tym katalogu pochodzą z Phase 2 plan 02-14 — empirycznej diagnozy
    dlaczego pure 2-opt SA na N=1000 NN-start plateauje przy `ratio ≈ 0.92` zamiast
    osiągnąć pierwotnie zakładane `ratio ≤ 0.9` (cel ROADMAP SC #4 zluźniony 10% → 5%).

    ## Pliki

    | Plik | Przeznaczenie |
    |------|---------------|
    | `diagnostyka_test05.jl` | Sweep candidate `T_zero` × budget krokow; pokazuje że nawet `T_zero=10⁻⁶` przy 50 000 krokow plateauje przy `ratio ≈ 0.94`. |
    | `diagnostyka_test05_budget.jl` | Sweep budgetu krokow (50 000 → 250 000) dla `T_zero=0.001` — potwierdza brak dalszej poprawy po ~125 000 krokow. |
    | `diagnostyka_test05_random_vs_nn.jl` | Porównanie SA z random-start vs NN-start — pokazuje że random-start z full 2σ kalibracją osiąga `ratio ≈ 0.97` (gorzej niż NN-start, dlatego TEST-05 hardcoduje `T_zero=0.001`). |

    ## Wynik diagnozy

    Pure 2-opt SA z NN-start jest w lokalnym minimum 2-opt graph'u. Cel `ratio ≤ 0.9`
    wymagałby silniejszego ruchu (3-opt, or-opt, double-bridge perturbation) — poza scope v1.
    ROADMAP SC #4 zluźniony do `≥ 5%` shorter than NN baseline; TEST-05 lock = `ratio = 0.9408`.

    Pełen kontekst: `.planning/phases/02-energy-sa-algorithm-test-suite/02-14-SUMMARY.md`.

    ## Uruchomienie (jeśli potrzeba reprodukcji)

    ```bash
    julia --project=. --threads=auto bench/historyczne/diagnostyka_test05.jl
    ```

    Skrypty są **niezależne od `bench/run_all.jl`** (Phase 4 D-16) — orchestrator ich nie wywołuje.
    ```

    KRYTYCZNE — typografia polska (per Phase 4 D-18):
    - cudzysłowy: `„..."` (U+201E + U+201D) jeśli używane (w tym tekście tylko cudzysłowy w nazwach plików / kodzie ASCII są dopuszczalne)
    - em-dash `—` (U+2014) zamiast `--`
    - NFC normalization, BOM-free
  </action>
  <verify>
    <automated>test -f bench/historyczne/README.md &amp;&amp; grep -q "plan 02-14" bench/historyczne/README.md &amp;&amp; grep -q "0.9408" bench/historyczne/README.md</automated>
  </verify>
  <acceptance_criteria>
    - `bench/historyczne/README.md` istnieje (`test -f` exit 0).
    - Zawiera literalny string `plan 02-14` (audit trail link).
    - Zawiera literalny string `0.9408` (TEST-05 ratio z STATE.md).
    - Zawiera tabelę z 3 wierszami plików (`grep -c '^|.*diagnostyka_test05'` ≥ 3).
    - Zawiera link do SUMMARY: grep zawiera `02-14-SUMMARY.md`.
    - Plik kończy się znakiem `\n` (LF, BOM-free) — `tail -c1 bench/historyczne/README.md | xxd` pokazuje `0a`.
    - Em-dash `—` (U+2014) obecny przynajmniej raz: `grep -c '—' bench/historyczne/README.md` ≥ 1.
    - Brak BOM: `head -c3 bench/historyczne/README.md | xxd` NIE pokazuje `efbbbf`.
  </acceptance_criteria>
  <done>bench/historyczne/README.md wyjaśnia archiwum, linkuje do SUMMARY, polski + NFC zgodny z D-18.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem move | Plan przenosi 3 pliki Julia (audit trail) do podkatalogu i tworzy 1 plik markdown. Brak wejścia użytkownika, brak network, brak persistence danych. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-02-01 | Repudiation | Audit trail (plik historyczny) | mitigate | Używamy `git mv` zamiast `mv` żeby zachować historię w git log. Acceptance criteria sprawdza `git status` pokazuje rename (R), nie delete+add. |
| T-04-02-02 | Tampering | Zawartość przeniesionych plików | accept | Plan explicit zabrania modyfikacji zawartości — pliki to read-only audit trail Phase 2. Sprawdzenie `wc -l` przed/po jako sanity check. |

Brak ASVS L1 controls naruszonych — pure file move + new doc file.
</threat_model>

<verification>
- `find bench/historyczne -name '*.jl' | wc -l` zwraca 3.
- `find bench -maxdepth 1 -name 'diagnostyka_test05*.jl' | wc -l` zwraca 0.
- `bench/historyczne/README.md` istnieje, polish typography (em-dash) obecny.
</verification>

<success_criteria>
- 3 pliki diagnostyki Phase 2 02-14 przeniesione do bench/historyczne/ z zachowaną historią git.
- README.md w bench/historyczne/ wyjaśnia kontekst (D-16 LOCKED).
- top-level bench/ wolny dla 4 nowych plików Phase 4.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-02-SUMMARY.md`
</output>
