---
phase: 04-demo-benchmarks-documentation
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Project.toml
  - .gitignore
  - assets/.gitkeep
autonomous: true
requirements:
  - DEMO-02
  - BENCH-04
must_haves:
  truths:
    - "Project.toml [targets].test contains BenchmarkTools entry"
    - ".gitignore ignores assets/* but explicitly allows assets/demo.gif"
    - "assets/ directory exists in repo"
  artifacts:
    - path: "Project.toml"
      provides: "BenchmarkTools available in test environment for bench/ scripts"
      contains: '"BenchmarkTools"'
    - path: ".gitignore"
      provides: "Selective allowlist for assets/demo.gif"
      contains: "assets/*"
    - path: "assets/.gitkeep"
      provides: "assets/ directory is committed (empty placeholder until demo.gif lands)"
      min_lines: 0
  key_links:
    - from: "bench/*.jl"
      to: "BenchmarkTools"
      via: "Pkg test environment"
      pattern: "using BenchmarkTools"
    - from: ".gitignore"
      to: "assets/demo.gif"
      via: "negation rule"
      pattern: "!assets/demo.gif"
---

<objective>
Wave 1 prep: rozszerzyć [targets].test w Project.toml o BenchmarkTools (D-10), dodać .gitignore reguły dla assets/ z wyjątkiem demo.gif (D-05), i utworzyć katalog assets/ z .gitkeep żeby był obecny w repo zanim Wave 4 wygeneruje demo.gif.

Purpose: Niezależny config-touch który odblokowuje wszystkie bench/* scripts (Wave 2-3) i examples/eksport_mp4.jl (Wave 2). Wykonywany równolegle z 04-02 (bench/historyczne move) i 04-03 (CONTRIBUTING §4).
Output: Zmodyfikowany Project.toml + .gitignore + nowy katalog assets/ z .gitkeep.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md
@.planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md
@Project.toml
@.gitignore
</context>

<tasks>

<task type="auto">
  <name>Task 1: Dodaj BenchmarkTools do [targets].test w Project.toml</name>
  <read_first>
    - Project.toml (zobaczyć dokładny stan linii 33-44, format alfabetyczny w [targets].test)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-10 — rationale)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "Project.toml MODIFY" — exact diff)
  </read_first>
  <action>
    Otworzyć Project.toml i zmodyfikować linię 44 (sekcja [targets]).

    BEFORE (linia 44):
    ```
    test = ["Aqua", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
    ```

    AFTER (linia 44 — dodać "BenchmarkTools" po "Aqua", zachować kolejność alfabetyczną):
    ```
    test = ["Aqua", "BenchmarkTools", "JET", "PerformanceTestTools", "Serialization", "StableRNGs", "Test", "Unicode"]
    ```

    NIE zmieniać innych linii — `BenchmarkTools` jest już w `[extras]` (linia 35) i `[compat]` (linia 26), więc resolver jest spójny. Aqua TEST-06 (`test/runtests.jl` line 269-279) ma `project_extras = false` więc Aqua nie złapie tego jako naruszenie.
  </action>
  <verify>
    <automated>grep -E '^test = .*"BenchmarkTools"' Project.toml &amp;&amp; grep -E '^test = .*"Aqua".*"BenchmarkTools".*"JET"' Project.toml</automated>
  </verify>
  <acceptance_criteria>
    - Project.toml linia z `test = [` zawiera literalny string `"BenchmarkTools"`.
    - Kolejność alfabetyczna zachowana: `"Aqua"` → `"BenchmarkTools"` → `"JET"` → ...
    - Sekcje [deps], [compat], [extras] niezmienione (grep tych sekcji daje identyczny output jak przed zmianą poza dodaniem).
    - `julia --project=. -e 'using Pkg; Pkg.activate(".test"); Pkg.instantiate(); using BenchmarkTools; println("OK")'` (lub równoważny smoke) kończy się exit 0 — opcjonalna weryfikacja, jeśli toolchain dostępny.
  </acceptance_criteria>
  <done>Project.toml zawiera BenchmarkTools w [targets].test linii, alfabetyczne uporządkowanie zachowane.</done>
</task>

<task type="auto">
  <name>Task 2: Dodaj reguły assets/* + !assets/demo.gif do .gitignore</name>
  <read_first>
    - .gitignore (zobaczyć obecne 31 linii — gdzie wstawić nową sekcję, jaki styl komentarzy)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-05 — rationale)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja ".gitignore MODIFY" — exact diff i kolejność reguł)
  </read_first>
  <action>
    Dopisać na końcu pliku .gitignore (po linii 31, jako nowa sekcja przed pustą linią końcową):

    ```
    # Asset binaries (Phase 4 D-05) — commitujemy tylko canonical demo.gif,
    # wszystkie inne lokalne artefakty developera (np. assets/test.mp4) ignorowane.
    assets/*
    !assets/demo.gif
    ```

    KRYTYCZNE — kolejność:
    1. `assets/*` MUSI być PRZED `!assets/demo.gif` (Git pattern-by-pattern, ostatni wygrywa dla danego pliku).
    2. Komentarz po polsku z odwołaniem do D-05 (audit trail).
    3. Po dodaniu plik kończy się znakiem `\n` (LF, no BOM, NFC) — zgodnie z CONTRIBUTING.md §1.

    Zachowane bez zmian: linie 1-31 (System / Editor / Julia / Backup / Test/diagnostic logs / Manifest komentarz).
  </action>
  <verify>
    <automated>grep -nE '^assets/\*$' .gitignore &amp;&amp; grep -nE '^!assets/demo\.gif$' .gitignore</automated>
  </verify>
  <acceptance_criteria>
    - `.gitignore` zawiera linię literalnie `assets/*` (bez wiodącego `/`).
    - `.gitignore` zawiera linię literalnie `!assets/demo.gif`.
    - Pattern `assets/*` poprzedza `!assets/demo.gif` w pliku (numer linii grep z `assets/*` < linii z `!assets/demo.gif`).
    - Komentarz z D-05 obecny tuż przed regułami (`grep -B1 'assets/\*' .gitignore` pokazuje linijkę zaczynającą się od `#`).
    - Zaden istniejący wpis nie został usunięty (`grep -c '^' .gitignore` zwraca poprzednia_liczba + 4 lub więcej dla komentarza+2 reguł+pustej).
  </acceptance_criteria>
  <done>.gitignore ma sekcję Asset binaries z `assets/*` ignorowanym i `!assets/demo.gif` jawnie odblokowanym.</done>
</task>

<task type="auto">
  <name>Task 3: Utwórz katalog assets/ z .gitkeep placeholder</name>
  <read_first>
    - .gitignore (właśnie zmodyfikowany — żeby upewnić się że `.gitkeep` nie jest filtrowany przez `assets/*` — bo `assets/*` matchuje wszystko, ale `.gitkeep` musi przejść)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-05 — assets/ jako katalog repo)
  </read_first>
  <action>
    UWAGA: `.gitignore` reguła `assets/*` IGNORUJE również `.gitkeep`. Aby placeholder przeszedł do repo, musimy dodać do .gitignore drugą exception PRZED `!assets/demo.gif`:

    Zmodyfikować sekcję dodaną w Task 2 (z .gitignore) tak by była:

    ```
    # Asset binaries (Phase 4 D-05) — commitujemy tylko canonical demo.gif + .gitkeep,
    # wszystkie inne lokalne artefakty developera (np. assets/test.mp4) ignorowane.
    assets/*
    !assets/.gitkeep
    !assets/demo.gif
    ```

    Następnie utworzyć katalog `assets/` i pusty plik `assets/.gitkeep`:
    - `mkdir -p assets`
    - Utworzyć plik `assets/.gitkeep` jako pusty plik (0 bajtów lub jedna linia z komentarzem `# placeholder; usunięty po pierwszym commicie demo.gif (Phase 4 D-05)`).

    Po Wave 4 (gdy `assets/demo.gif` zostanie wygenerowany i scommitowany), `.gitkeep` może pozostać lub być usunięty — niekrytyczne.
  </action>
  <verify>
    <automated>test -d assets &amp;&amp; test -f assets/.gitkeep &amp;&amp; grep -E '^!assets/\.gitkeep$' .gitignore</automated>
  </verify>
  <acceptance_criteria>
    - Katalog `assets/` istnieje (`test -d assets` exit 0).
    - Plik `assets/.gitkeep` istnieje (`test -f assets/.gitkeep` exit 0).
    - `.gitignore` zawiera linię `!assets/.gitkeep` PRZED `!assets/demo.gif`.
    - `git check-ignore -v assets/.gitkeep` zwraca exit 1 (NIE ignorowany — placeholder przejdzie).
    - `git check-ignore -v assets/test.mp4` zwraca exit 0 (ignorowany — losowy artefakt nie wpada).
  </acceptance_criteria>
  <done>Katalog assets/ widoczny w repo z placeholder .gitkeep, gotowy na demo.gif w Wave 4.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan modyfikuje 2 istniejące pliki konfiguracyjne i tworzy 1 nowy plik 0-bajtowy w nowym katalogu. Brak wejścia użytkownika, brak network, brak persistence danych. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-01-01 | Tampering | Project.toml [targets].test list | accept | Dodanie BenchmarkTools (już w [extras]+[compat]) jest niezagrażające — Aqua TEST-06 ma `project_extras=false` udokumentowane w 02-08-SUMMARY.md. |
| T-04-01-02 | Information Disclosure | .gitignore reguła `assets/*` | accept | Reguła jawnie chroni przed accidental commit lokalnych artefaktów developera (np. assets/secrets.png). Brak PII, niska wartość — ASVS L1 nie wymaga dodatkowej kontroli. |

Brak ASVS L1 controls naruszonych — config-only changes, no auth/network/input.
</threat_model>

<verification>
- `grep -E '"BenchmarkTools"' Project.toml | grep -c 'test = '` zwraca 1.
- `grep -nE '^assets/\*$|^!assets/' .gitignore` pokazuje 3 linie w kolejności: assets/*, !assets/.gitkeep, !assets/demo.gif.
- `ls -la assets/.gitkeep` istnieje.
</verification>

<success_criteria>
- Project.toml [targets].test rozszerzona o BenchmarkTools (alfabetycznie).
- .gitignore z 3 nowymi liniami reguł assets + 1 komentarz polski.
- assets/ katalog istnieje, .gitkeep placeholder commitowalny, demo.gif gotowy do landingu.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-01-SUMMARY.md`
</output>
