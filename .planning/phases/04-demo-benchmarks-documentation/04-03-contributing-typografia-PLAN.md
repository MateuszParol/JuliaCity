---
phase: 04-demo-benchmarks-documentation
plan: 03
type: execute
wave: 1
depends_on: []
files_modified:
  - CONTRIBUTING.md
autonomous: true
requirements:
  - LANG-02
  - LANG-03
must_haves:
  truths:
    - "CONTRIBUTING.md zawiera nową sekcję §4. Typografia polska"
    - "Tabela typografii z kodami U+201E, U+201D, U+2014, U+2013 obecna"
    - "Istniejące sekcje §4 i §5 przerumerowane na §5 i §6"
  artifacts:
    - path: "CONTRIBUTING.md"
      provides: "Polish typography convention dla user-facing strings"
      contains: "Typografia polska"
  key_links:
    - from: "CONTRIBUTING.md §4"
      to: "README.md user-facing strings"
      via: "konwencja typografii"
      pattern: "U\\+201E"
---

<objective>
Wave 1 doc-update: Dodać sekcję `## 4. Typografia polska` do `CONTRIBUTING.md` (D-18) i przerumerować obecne `## 4. Style przed commit` → `## 5.`, `## 5. Workflow GSD` → `## 6.`. Zamyka STATE.md TODO „Document Polish-typography convention".

Purpose: Phase 4 README.md i overlay'e w `wizualizacja.jl` używają polskiej typografii ( „..." cudzysłowy, — em-dash, NFC). Konwencja musi być udokumentowana zanim Wave 4 przepisze README.md.
Output: Zaktualizowany `CONTRIBUTING.md` z nową §4 + przerumerowanymi sekcjami.
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
@CONTRIBUTING.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Wstaw §4 Typografia polska + przerumeruj §4→§5, §5→§6</name>
  <read_first>
    - CONTRIBUTING.md (cały plik — szczególnie linie 78-91, struktura nagłówków, styl tabeli)
    - .planning/phases/04-demo-benchmarks-documentation/04-CONTEXT.md (D-18 — exact spec)
    - .planning/phases/04-demo-benchmarks-documentation/04-PATTERNS.md (sekcja "CONTRIBUTING.md UPDATE — append §4" — exact code excerpt)
  </read_first>
  <action>
    Zmodyfikować `CONTRIBUTING.md` w 2 krokach (oba w jednym Edit):

    **Krok A:** Wstawić nową sekcję `## 4. Typografia polska` PO linii 78 (koniec §3 — Polski/angielski split) i PRZED obecną linią 80 (`## 4. Style przed commit`).

    Treść nowej §4 (wstawiana DOKŁADNIE; ostatnia linia to pojedynczy `\n` jako separator przed §5):

    ```markdown
    ## 4. Typografia polska

    User-facing strings (`README.md`, overlay w `wizualizacja.jl`, `@info`/`@error` po polsku) używają
    **poprawnej polskiej typografii**:

    | Znak | Kod | Użycie |
    |------|-----|--------|
    | `„` | U+201E | Otwierający cudzysłów dolny (rozpoczyna cytat) |
    | `"` | U+201D | Zamykający cudzysłów górny (kończy cytat) |
    | `—` | U+2014 | Em-dash (myślnik wprost — bez spacji wokół, jak tu) |
    | `–` | U+2013 | En-dash (zakresy, np. „1–10") |

    **NIE używamy:** prostych ASCII `"..."` w prozie, `--` (podwójny minus) zamiast `—`.

    **Normalizacja:** wszystkie pliki tekstowe w **NFC** (composed). `.editorconfig` + encoding-guard
    test w `test/runtests.jl` walidują dla `.jl`; konwencja obejmuje również `.md` (sprawdzane manualnie
    w PR review — patrz §1).

    **Zasada „BOM-free":** brak sygnatury 0xEF 0xBB 0xBF na początku — zgodnie z §1.

    ```

    **Krok B:** Przerumerować nagłówki sekcji obecnych §4 i §5:
    - Zamienić `## 4. Style przed commit` → `## 5. Style przed commit`
    - Zamienić `## 5. Workflow GSD` → `## 6. Workflow GSD`

    NIE zmieniać treści tych sekcji — tylko numeracja w nagłówku.

    KRYTYCZNE — typografia samej §4 (eat your own dog food):
    - `„` musi być znakiem U+201E (sprawdzić w hex: `e2 80 9e`)
    - `"` musi być znakiem U+201D (sprawdzić w hex: `e2 80 9d`)
    - `—` musi być znakiem U+2014 (sprawdzić w hex: `e2 80 94`)
    - `–` musi być znakiem U+2013 (sprawdzić w hex: `e2 80 93`)
    - NFC normalization (composed); BOM-free; LF line endings; final newline
  </action>
  <verify>
    <automated>grep -q '^## 4\. Typografia polska$' CONTRIBUTING.md &amp;&amp; grep -q '^## 5\. Style przed commit$' CONTRIBUTING.md &amp;&amp; grep -q '^## 6\. Workflow GSD$' CONTRIBUTING.md &amp;&amp; grep -q 'U+201E' CONTRIBUTING.md &amp;&amp; grep -q 'U+2014' CONTRIBUTING.md</automated>
  </verify>
  <acceptance_criteria>
    - `CONTRIBUTING.md` zawiera linię `## 4. Typografia polska` (literalnie, exact match).
    - `CONTRIBUTING.md` zawiera linię `## 5. Style przed commit` (przerumerowane z 4).
    - `CONTRIBUTING.md` zawiera linię `## 6. Workflow GSD` (przerumerowane z 5).
    - `CONTRIBUTING.md` NIE zawiera już linii `## 4. Style przed commit` ani `## 5. Workflow GSD` (stare numery zniknęły).
    - Tabela typografii zawiera wszystkie 4 kody: `U+201E`, `U+201D`, `U+2014`, `U+2013`.
    - Plik zawiera literalny znak `„` (U+201E) — `grep -c '„' CONTRIBUTING.md` ≥ 1.
    - Plik zawiera literalny znak `—` (U+2014) — `grep -c '—' CONTRIBUTING.md` ≥ 2 (raz w tabeli, raz w "myślnik wprost").
    - Sekcje §1, §2, §3 niezmienione (grep `'^## 1\.', '^## 2\.', '^## 3\.'` zwracają jedną linię każda).
    - `head -c3 CONTRIBUTING.md | xxd` NIE pokazuje BOM (`efbbbf`).
    - `tail -c1 CONTRIBUTING.md | xxd` pokazuje LF (`0a`) jako ostatni znak.
    - Liczba linii pliku po edycji: `wc -l CONTRIBUTING.md` zwraca conajmniej `90 + 16 = 106` (oryginał ~91 linii + nowa sekcja ~16 linii; może być nieco więcej).
    - Encoding guard test w `test/runtests.jl` (Phase 1 D-21) NIE flaguje pliku — sprawdzane przy następnym `Pkg.test()`. Ten test skanuje root-level `.md`, więc musi być NFC + BOM-free.
  </acceptance_criteria>
  <done>CONTRIBUTING.md ma 6 sekcji (1-3 niezmienione, nowa 4, stare 4-5 przerumerowane do 5-6), §4 demonstruje sama swoje reguły typografii.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| filesystem write | Plan modyfikuje jeden plik markdown w root repo. Brak wejścia użytkownika, brak network, brak persistence danych użytkownika. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-03-01 | Tampering | CONTRIBUTING.md encoding | mitigate | Acceptance criteria sprawdza BOM-free + LF + NFC characters w hex (U+201E etc.). Phase 1 encoding guard test (`test/runtests.jl`) jest second line of defense — wykryje regresję przy następnym `Pkg.test()`. |
| T-04-03-02 | Information Disclosure | Section renumbering | accept | Brak PII; tylko typografia konwencja. ASVS L1 nie wymaga kontroli. |

Brak ASVS L1 controls naruszonych — pure documentation update.
</threat_model>

<verification>
- `grep -c '^## ' CONTRIBUTING.md` zwraca dokładnie 6 (sekcje §1..§6).
- Encoding guard test w `test/runtests.jl` przejdzie na zaktualizowanym pliku (sprawdzany przy regression).
</verification>

<success_criteria>
- §4 Typografia polska wstawiona z tabelą Unicode codepoints i regułami.
- Stare §4 (Style) → §5; stare §5 (GSD Workflow) → §6.
- Plik sam w sobie używa poprawnej polskiej typografii (eat your own dog food).
- STATE.md TODO „Polish-typography convention" zamykany (acceptance: pojawia się w 04-03-SUMMARY.md).
</success_criteria>

<output>
After completion, create `.planning/phases/04-demo-benchmarks-documentation/04-03-SUMMARY.md`
</output>
