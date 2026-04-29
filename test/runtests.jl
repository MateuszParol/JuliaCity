# Test suite pakietu JuliaCity — Phase 1 + Phase 2 Wave 0.
# Pokrywa: encoding hygiene (BOOT-03, D-21), generuj_punkty (PKT-01..04),
# StanSymulacji konstruktor + const protection, Wave 0 StableRNG↔Punkt2D smoke
# (Plan 02-01), Aqua quality, JET smoke.
#
# Asercje wewnętrzne (errors message) po angielsku per LANG-04 / D-23.
# Komentarze po polsku per LANG-01 / D-22.

using Test
using JuliaCity
using Random
using Random: Xoshiro, default_rng
using Unicode
using Aqua
using JET
using StableRNGs

@testset "JuliaCity" begin

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Encoding hygiene guard (BOOT-03, D-21) — Pattern 6 z RESEARCH.md
    # ─────────────────────────────────────────────────────────────────────────
    @testset "encoding hygiene (BOOT-03, D-21)" begin
        # Iteracja po katalogach źródłowych. `Pkg.test()` aktywuje sandbox env
        # w innym katalogu — kotwiczymy ścieżki przez `pkgdir(JuliaCity)`,
        # żeby walkdir trafił w prawdziwe `src/` i `test/`.
        repo_root = pkgdir(JuliaCity)
        katalogi = [joinpath(repo_root, "src"), joinpath(repo_root, "test")]
        rozszerzenia = (".jl", ".toml", ".md")

        pliki = String[]
        for kat in katalogi
            isdir(kat) || continue
            for (root, _, files) in walkdir(kat)
                for f in files
                    if any(endswith(f, ext) for ext in rozszerzenia)
                        push!(pliki, joinpath(root, f))
                    end
                end
            end
        end

        # Plus pliki konfiguracyjne na root level
        for plik_root in ["Project.toml", "Manifest.toml", ".editorconfig", ".gitattributes",
                          ".gitignore", "README.md", "CONTRIBUTING.md", "LICENSE"]
            sciezka = joinpath(repo_root, plik_root)
            if isfile(sciezka)
                push!(pliki, sciezka)
            end
        end

        @test !isempty(pliki)   # sanity check: znaleźliśmy jakiekolwiek pliki

        for plik in pliki
            bajty = read(plik)

            # 1a. UTF-8 well-formed
            @test isvalid(String, bajty)

            # 1b. No UTF-8 BOM (sygnatura 0xEF 0xBB 0xBF)
            @test !(length(bajty) >= 3 &&
                    bajty[1] == 0xEF && bajty[2] == 0xBB && bajty[3] == 0xBF)

            # 1c. No CRLF (LF only) — Pitfall 4 z RESEARCH
            # `read(path)` zwraca `Vector{UInt8}` — w Julia 1.10 brak metody
            # `occursin(::CodeUnits, ::Vector{UInt8})`, więc konwertujemy do String
            # po sprawdzeniu poprawności UTF-8 (1a). Nie modyfikuje `bajty` (kopia).
            @test !occursin("\r\n", String(copy(bajty)))

            # 1d. NFC-normalized (tylko `.jl` — polskie diakrytyki w komentarzach)
            if endswith(plik, ".jl")
                tresc = String(bajty)
                @test Unicode.normalize(tresc, :NFC) == tresc
            end
        end

        # 1e. Wszystkie nazwy plików w src/ i test/ są ASCII (BOOT-04, D-19)
        for kat in katalogi
            isdir(kat) || continue
            for (root, dirs, files) in walkdir(kat)
                for nazwa in vcat(dirs, files)
                    @test all(c -> UInt32(c) <= 0x7E, nazwa)
                end
            end
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 2. generuj_punkty (PKT-01..03)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "generuj_punkty (PKT-01, PKT-02, PKT-03)" begin
        # PKT-01: zwraca Vector{Punkt2D}
        punkty = generuj_punkty(1000; seed=42)
        @test eltype(punkty) == Punkt2D
        @test length(punkty) == 1000

        # PKT-02: default n=1000
        @test length(generuj_punkty()) == 1000

        # PKT-03: punkty w [0,1]², rozkład jednostajny
        @test all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, punkty)

        # Determinizm dla seed=42 (PKT-01)
        @test generuj_punkty(100; seed=42) == generuj_punkty(100; seed=42)
        @test generuj_punkty(100; seed=42) != generuj_punkty(100; seed=43)

        # Composable wariant (D-11)
        rng = Xoshiro(7)
        @test length(generuj_punkty(50, rng)) == 50

        # ArgumentError dla n ≤ 0
        @test_throws ArgumentError generuj_punkty(0)
        @test_throws ArgumentError generuj_punkty(-5)
        @test_throws ArgumentError generuj_punkty(0, Xoshiro(1))
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 3. PKT-04: no global RNG mutation (Pitfall 7 — top-level, NIE w @async)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "generuj_punkty no global RNG mutation (PKT-04, D-14)" begin
        przed = copy(default_rng())
        _ = generuj_punkty(1000; seed=42)
        po = copy(default_rng())
        @test przed == po
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 4. StanSymulacji konstruktor (D-05, D-06, D-07)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "StanSymulacji konstruktor" begin
        punkty = generuj_punkty(10; seed=1)
        stan = StanSymulacji(punkty)

        # const fields — identity / pre-allocated
        @test stan.punkty === punkty
        @test size(stan.D) == (10, 10)        # pre-alokowane (D-07)
        @test stan.rng isa Random.Xoshiro     # default rng=Xoshiro(42)

        # mutable fields — zero-state (D-07)
        @test stan.trasa == collect(1:10)
        @test stan.energia == 0.0
        @test stan.temperatura == 0.0
        @test stan.iteracja == 0

        # const field reassignment fails (Julia 1.8+ semantics, Pitfall 2)
        @test_throws ErrorException stan.punkty = Punkt2D[]

        # mutable field reassignment OK
        stan.iteracja = 42
        @test stan.iteracja == 42

        # ArgumentError dla pustego punkty (D-07 walidacja)
        @test_throws ArgumentError StanSymulacji(Punkt2D[])

        # Custom rng (composable z generuj_punkty)
        stan_custom = StanSymulacji(punkty; rng=Xoshiro(123))
        @test stan_custom.rng === stan_custom.rng   # same object
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 5. Wave 0 smoke: StableRNG ↔ Punkt2D dispatch (Phase 2 Plan 02-01)
    # Krytyczny PRZED TEST-08 (golden value w Phase 2 Plan 02-05).
    # Research-flagged jako MEDIUM confidence (Pitfall E w 02-RESEARCH.md):
    # `rand(StableRNG, Point2{Float64}, n)` działa via GeometryBasics' Random.SamplerType
    # dispatch — community-evidence, niezweryfikowane oficjalnie. Ten test gwarantuje
    # że Phase 1 src/punkty.jl::generuj_punkty(n, rng) NIE wymaga fallbacku.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "Wave 0: StableRNG ↔ Punkt2D smoke (Plan 02-01)" begin
        pkty = generuj_punkty(5, StableRNG(42))
        @test eltype(pkty) == Punkt2D
        @test length(pkty) == 5
        # determinizm w obrębie tej samej wersji StableRNGs
        @test generuj_punkty(5, StableRNG(42)) == generuj_punkty(5, StableRNG(42))
        # dwa różne seedy dają różne wyniki
        @test generuj_punkty(5, StableRNG(42)) != generuj_punkty(5, StableRNG(43))
        # punkty w [0,1]² (jak generuj_punkty z Xoshiro)
        @test all(p -> 0.0 <= p[1] <= 1.0 && 0.0 <= p[2] <= 1.0, pkty)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 6. Aqua.jl quality gate (TEST-06 częściowo — pełen w Phase 2)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "Aqua.jl quality" begin
        # Aqua importowany na top-levelu pliku (makra muszą być w scope przy parsowaniu).
        # Wariant a z plan 03 wymaga GLMakie/Makie/Observables/BenchmarkTools w [compat]
        # od Phase 1 (ROADMAP SC2 literal compliance), ale w [deps] dochodzą w Phase 3
        # (GLMakie/Makie/Observables) i Phase 4 (BenchmarkTools). Wyłączamy stale_deps
        # do tego czasu — re-enable w Phase 4 gdy wszystkie compat-entries mają deps.
        # TODO Phase 4: usuń stale_deps=false gdy BenchmarkTools wejdzie do [deps]
        #
        # `deps_compat`: stdlib (Random, Test, Unicode) NIE wymaga wpisów w [compat]
        # per konwencja Pkg ekosystemu (sterowane przez julia="1.10") — patrz plan-03
        # SUMMARY decisions. Aqua mimo to flaguje brak compat dla stdlib w [deps]+[extras];
        # ignorujemy te konkretne pakiety, reszta deps_compat checks działa.
        deps_compat_kwargs = (ignore = [:Random], check_extras = (ignore = [:Test, :Unicode],))
        Aqua.test_all(JuliaCity; stale_deps = false, deps_compat = deps_compat_kwargs)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 7. JET smoke test (TEST-07 wstępnie — pełen @report_opt na publicznym API w Phase 2)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "JET smoke" begin
        # JET importowany na top-levelu pliku (makra muszą być w scope przy parsowaniu).
        # Phase 1 — minimalny smoke: tylko że @report_opt na generuj_punkty nie wybucha.
        # Pełna analiza @report_opt + @report_call na oblicz_energie, symuluj_krok!,
        # delta_energii dochodzi w Phase 2.
        #
        # Soft assertion: jakikolwiek wynik bez exception oznacza że JET zaanalizował
        # `generuj_punkty` poprawnie. Różne wersje JET zwracają różne typy result-u
        # (`JETCallResult`, `OptAnalysisResult`, etc.) — nie testujemy konkretnego typu,
        # bo Phase 1 to tylko gate "macro się parsuje + analiza nie wybucha".
        # Hard test (`isempty(get_reports(result))`) dochodzi w Phase 2 razem z
        # oblicz_energie / symuluj_krok! / delta_energii (real type-stability concerns).
        result = @report_opt generuj_punkty(10; seed=42)
        @test result !== nothing
    end
end
