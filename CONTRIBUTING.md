# Wkład w JuliaCity

Dziękujemy za zainteresowanie projektem! Poniżej zebrane są konwencje, których trzymamy się
we wszystkich plikach repozytorium. Encoding-guard test w `test/runtests.jl` (Phase 1)
automatycznie waliduje punkty 1–4.

## 1. Encoding plików

- **Kodowanie:** UTF-8, **bez BOM-a** (sygnatury 0xEF 0xBB 0xBF na początku pliku).
- **Końce linii:** LF (`\n`), nie CRLF (`\r\n`). Polityka wymuszona przez `.gitattributes`
  (`* text=auto eol=lf`) — nawet contributor na Windowsie z `core.autocrlf=true` dostanie
  LF w repo.
- **Final newline:** każdy plik kończy się znakiem `\n`. EditorConfig wymusza
  (`insert_final_newline = true`).
- **Trailing whitespace:** usuwany w `.jl`/`.toml`. W `.md` zachowany (markdown trailing
  dwóch spacji = hard line break).
- **Normalizacja Unicode:** komentarze i stringi w `.jl` muszą być NFC (composed). macOS HFS+
  i niektóre IME wprowadzają NFD — encoding guard test łapie regresje.

### Quick fix dla CRLF (jeśli klonowałeś z `core.autocrlf=true`):

```bash
git config --local core.autocrlf input    # Linux/macOS
git add --renormalize .
git commit -m "fix: normalize line endings"
```

## 2. Nazwy plików — wyłącznie ASCII

Wszystkie nazwy plików w `src/`, `test/`, `examples/`, `bench/` są ASCII (znaki 0x20–0x7E).
**Brak polskich diakrytyków w ścieżkach** (`ą`, `ę`, `ł` itp.). Powód: niektóre Linux locale
i CI runners mają problem z UTF-8 w nazwach plików; Git path handling staje się non-portable.

Polskie identyfikatory są **OK wewnątrz plików**, ale piszemy je BEZ diakrytyków:

```julia
# Dobrze
cierpliwosc = 100
parametry = (...)

# Źle (łamie portability)
cierpliwość = 100
```

## 3. Polski / angielski split

| Gdzie | Język | Powód |
|-------|-------|-------|
| Komentarze w `src/*.jl`, `test/*.jl` | **polski** | Twardy wymóg projektu (CLAUDE.md). |
| Docstringi (`"""..."""`) | **polski** | Spójność z komentarzami; user-facing. |
| Stringi UI (tytuły, etykiety, overlay w `wizualizacja.jl`, README) | **polski** | LANG-02, LANG-03. |
| Asercje wewnętrzne (`@assert`, `error()`, `throw(ArgumentError)`) | **angielski** | Kompatybilność ekosystemu Julia, łatwiejsze szukanie issue na GitHubie. LANG-04. |
| Nazwy funkcji domenowych (`generuj_punkty`, `oblicz_energie`, `symuluj_krok!`, `wizualizuj`) | **polski** (bez diakrytyków) | Twardy kontrakt projektu. |
| Nazwy zmiennych/pól struktur (`punkty`, `trasa`, `energia`, `iteracja`, `cierpliwosc`) | **polski** (bez diakrytyków) gdzie ma sens domenowy | Czytelność dla autora. |
| Współrzędne (`x`, `y`) | angielski / matematyczny | To geometria, nie domena polska. |

Przykład w pliku `src/typy.jl`:

```julia
# Typy domenowe pakietu JuliaCity

"""
    StanSymulacji{R<:AbstractRNG}

Stan symulacji TSP — pola const ustawiane raz w konstruktorze.
"""
mutable struct StanSymulacji{R<:AbstractRNG}
    const punkty::Vector{Punkt2D}        # niezmienne — punkty 2D w [0,1]²
    const D::Matrix{Float64}              # macierz dystansów (Phase 2 wypełnia)
    # ...
end

function StanSymulacji(punkty::Vector{Punkt2D}; rng=Xoshiro(42))
    n = length(punkty)
    n > 0 || throw(ArgumentError("punkty must be non-empty"))   # asercja po angielsku
    # ... reszta po polsku
end
```

## 4. Style przed commit

Przed commit:
1. Uruchom `julia --project=. test/runtests.jl` — encoding guard test musi przejść.
2. Sprawdź `git diff --check` — brak whitespace conflicts.
3. Sprawdź `git status` — brak nieoczekiwanych plików (np. `.DS_Store`, `*.bak`).

## 5. Workflow GSD

Repo używa GSD (`/gsd-execute-phase`, `/gsd-quick`) — patrz `CLAUDE.md` § "GSD Workflow Enforcement".
Nie commituj zmian do `src/`/`test/` poza GSD workflow.
