---
phase: 04-demo-benchmarks-documentation
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - Project.toml
  - .gitignore
autonomous: true
requirements:
  - DEMO-02
  - BENCH-04
must_haves:
  truths:
    - "Project.toml [targets].test contains BenchmarkTools entry"
    - ".gitignore ignores assets/* but explicitly allows assets/demo.gif (per D-05 EXACTLY)"
  artifacts:
    - path: "Project.toml"
      provides: "BenchmarkTools available in test environment for bench/ scripts"
      contains: '"BenchmarkTools"'
    - path: ".gitignore"
      provides: "Selective allowlist for assets/demo.gif"
      contains: "assets/*"
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
Wave 1 prep: rozszerzyć [targets].test w Project.toml o BenchmarkTools (D-10) i dodać do .gitignore DOKŁADNIE dwie reguły dla assets/ z wyjątkiem demo.gif (D-05 LOCKED EXACTLY: `assets/*` + `!assets/demo.gif`, nic więcej).

Purpose: Niezależny config-touch który odblokowuje wszystkie bench/* scripts (Wave 2-3) i examples/eksport_mp4.jl (Wave 2). Wykonywany równolegle z 04-02 (bench/historyczne move) i 04-03 (CONTRIBUTING §4). Katalog `assets/` zostanie utworzony przez `examples/eksport_mp4.jl` (plan 04-07 dodaje `mkpath` defensywnie); brak placeholder'a `.gitkeep` — D-05 nie dopuszcza dodatkowych wyjątków poza `demo.gif`.
Output: Zmodyfikowany Project.toml + .gitignore (DOKŁADNIE 2 reguły assets + opcjonalny komentarz).
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

    UWAGA (per D-10 + Blocker #4 z iteracji 1): `--project=.` resolver NIE widzi pakietów z `[targets].test` w trybie "run a script". Dlatego standalone `julia --project=. bench/run_all.jl` NIE załaduje BenchmarkTools — to limit Pkg.jl. Workaround przez `bench/uruchom.{sh,ps1}` jest dostarczony w plan 04-06 Task 0 (temp-env recipe activuje throwaway env). D-10 (no `bench/Project.toml`) pozostaje honored — wrapper używa `Pkg.activate(temp=true) + Pkg.develop(path=".") + Pkg.add("BenchmarkTools")` w runtime.
  </action>
  <verify>
    <automated>grep -E '^test = .*"BenchmarkTools"' Project.toml &amp;&amp; grep -E '^test = .*"Aqua".*"BenchmarkTools".*"JET"' Project.toml</automated>
  </verify>
  <acceptance_criteria>
    - Project.toml linia z `test = [` zawiera literalny string `"BenchmarkTools"`.
    - Kolejność alfabetyczna zachowana: `"Aqua"` → `"BenchmarkTools"` → `"JET"` → ...
    - Sekcje [deps], [compat], [extras] niezmienione (grep tych sekcji daje identyczny output jak przed zmianą poza dodaniem).
    - `julia --project=. -e 'using Pkg; Pkg.test()'` (lub równoważny smoke) kończy się exit 0 — opcjonalna weryfikacja, jeśli toolchain dostępny.
  </acceptance_criteria>
  <done>Project.toml zawiera BenchmarkTools w [targets].test linii, alfabetyczne uporządkowanie zachowane.</done>
</task>

<task type="auto">
  <name>Task 2: Dodaj DOKŁADNIE 2 reguły assets/* + !assets/demo.gif do .gitignore (D-05 EXACT)</name>
  <read_first>
    - .gitignore (zobaczyć obecne 31 linii — gdzie wstawić nową sekcję, jaki styl komentarzy)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-05 — rationale; LOCKED EXACTLY: tylko 2 reguły, brak `.gitkeep` exception)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja ".gitignore MODIFY" — exact diff i kolejność reguł)
  </read_first>
  <action>
    Dopisać na końcu pliku .gitignore (po linii 31, jako nowa sekcja przed pustą linią końcową). DOKŁADNIE dwie reguły zgodnie z D-05 — brak `!assets/.gitkeep` lub innych exceptions:

    ```
    # Asset binaries (Phase 4 D-05) — commitujemy tylko canonical demo.gif,
    # wszystkie inne lokalne artefakty developera (np. assets/test.mp4) ignorowane.
    assets/*
    !assets/demo.gif
    ```

    KRYTYCZNE — D-05 LOCKED EXACTLY:
    1. Tylko `assets/*` i `!assets/demo.gif` — żadnych dodatkowych negacji (`!assets/.gitkeep`, `!assets/README.md`, etc.).
    2. `assets/*` MUSI być PRZED `!assets/demo.gif` (Git pattern-by-pattern, ostatni wygrywa dla danego pliku).
    3. Komentarz po polsku z odwołaniem do D-05 (audit trail).
    4. Po dodaniu plik kończy się znakiem `\n` (LF, no BOM, NFC) — zgodnie z CONTRIBUTING.md §1.

    Katalog `assets/` NIE jest tworzony w tym planie — `examples/eksport_mp4.jl` (plan 04-07) wykonuje `mkpath(dirname(SCIEZKA_GIF))` defensywnie przed pre-rm i wywołaniem `wizualizuj()`. Bez `.gitkeep` placeholder.

    Zachowane bez zmian: linie 1-31 (System / Editor / Julia / Backup / Test/diagnostic logs / Manifest komentarz).
  </action>
  <verify>
    <automated>grep -nE '^assets/\*$' .gitignore &amp;&amp; grep -nE '^!assets/demo\.gif$' .gitignore &amp;&amp; test "$(grep -cE '^!assets/' .gitignore)" = "1"</automated>
  </verify>
  <acceptance_criteria>
    - `.gitignore` zawiera linię literalnie `assets/*` (bez wiodącego `/`).
    - `.gitignore` zawiera linię literalnie `!assets/demo.gif`.
    - `.gitignore` zawiera DOKŁADNIE JEDNĄ linię zaczynającą się od `!assets/`: `grep -cE '^!assets/' .gitignore` zwraca `1` (tylko `!assets/demo.gif`, brak `!assets/.gitkeep`).
    - Pattern `assets/*` poprzedza `!assets/demo.gif` w pliku (numer linii grep z `assets/*` < linii z `!assets/demo.gif`).
    - Komentarz z D-05 obecny tuż przed regułami (`grep -B1 'assets/\*' .gitignore` pokazuje linijkę zaczynającą się od `#`).
    - `git check-ignore -v assets/demo.gif` zwraca exit 1 (NIE ignorowany — passthrough do repo).
    - `git check-ignore -v assets/test.mp4` zwraca exit 0 (ignorowany — losowy artefakt nie wpada).
  </acceptance_criteria>
  <done>.gitignore ma sekcję Asset binaries z DOKŁADNIE 2 regułami: `assets/*` ignorowanym i `!assets/demo.gif` jawnie odblokowanym (D-05 EXACT).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan modyfikuje 2 istniejące pliki konfiguracyjne. Brak wejścia użytkownika, brak network, brak persistence danych. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-01-01 | Tampering | Project.toml [targets].test list | accept | Dodanie BenchmarkTools (już w [extras]+[compat]) jest niezagrażające — Aqua TEST-06 ma `project_extras=false` udokumentowane w 02-08-SUMMARY.md. |
| T-04-01-02 | Information Disclosure | .gitignore reguła `assets/*` | accept | Reguła jawnie chroni przed accidental commit lokalnych artefaktów developera (np. assets/secrets.png). Brak PII, niska wartość — ASVS L1 nie wymaga dodatkowej kontroli. |

Brak ASVS L1 controls naruszonych — config-only changes, no auth/network/input.
</threat_model>

<verification>
- `grep -E '"BenchmarkTools"' Project.toml | grep -c 'test = '` zwraca 1.
- `grep -nE '^assets/\*$|^!assets/' .gitignore` pokazuje DOKŁADNIE 2 linie w kolejności: assets/*, !assets/demo.gif.
- `grep -cE '^!assets/' .gitignore` zwraca `1` (D-05 EXACT — brak dodatkowych exceptions).
</verification>

<success_criteria>
- Project.toml [targets].test rozszerzona o BenchmarkTools (alfabetycznie).
- .gitignore z 2 nowymi liniami reguł assets + 1 komentarz polski (D-05 EXACT — bez `.gitkeep`).
- examples/eksport_mp4.jl (plan 04-07) odpowiada za utworzenie katalogu `assets/` przez `mkpath` przed eksportem.
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-01-SUMMARY.md`
</output>
