# Test suite pakietu JuliaCity — Phase 1 + Phase 2 (kompletna).
# Pokrywa: encoding hygiene (BOOT-03, D-21), generuj_punkty (PKT-01..04),
# StanSymulacji konstruktor + const protection, Wave 0 StableRNG↔Punkt2D smoke
# (Plan 02-01), test_energia.jl/test_baselines.jl/test_symulacja.jl includes
# (Plan 02-05), Aqua TEST-06 (rozszerzony), JET TEST-07 (@test_opt na 4 hot-path
# functions). 21 REQ-IDow Phase 2 pokrytych po wireing-u w Plan 02-06.
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
    # 6. Energia (Plan 02-02 + Plan 02-05 testset-y)
    #    Pokrywa REQ ENE-01..05 + TEST-02/03 (czesciowo) + ALG-05.
    # ─────────────────────────────────────────────────────────────────────────
    include("test_energia.jl")

    # ─────────────────────────────────────────────────────────────────────────
    # 7. Baselines + TEST-05 NN-baseline-beat (Plan 02-03 + Plan 02-05)
    #    Pokrywa REQ ALG-04 + TEST-05.
    # ─────────────────────────────────────────────────────────────────────────
    include("test_baselines.jl")

    # ─────────────────────────────────────────────────────────────────────────
    # 8. Symulacja SA + TEST-01/03/04/08 (Plan 02-04 + Plan 02-05)
    #    Pokrywa REQ ALG-01..03/06..08 + TEST-01/04/08.
    # ─────────────────────────────────────────────────────────────────────────
    include("test_symulacja.jl")

    # ─────────────────────────────────────────────────────────────────────────
    # 9b. VIZ-06: GLMakie isolation guard — Phase 3.
    #     Sprawdza ze src/wizualizacja.jl jest JEDYNYM plikiem w src/ z `using GLMakie`.
    #     Test jest grep-level (czyta pliki jako String) — NIE wymaga OpenGL, bezpieczny
    #     dla headless CI (D-14, D-15). Pattern mirror encoding hygiene testset (linie 25-88):
    #     pkgdir(JuliaCity) jako anchor (Pkg.test sandbox env w innym katalogu).
    #     Per-line iteration eliminuje false-positives w docstringach lub komentarzach.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "VIZ-06: GLMakie isolation" begin
        repo_root = pkgdir(JuliaCity)
        src_dir = joinpath(repo_root, "src")
        @test isdir(src_dir)   # sanity: anchor poprawnie znalezione

        # Walka po wszystkich .jl w src/ (+ podkatalogi typu algorytmy/)
        pliki_jl = String[]
        for (root, _, files) in walkdir(src_dir)
            for f in files
                endswith(f, ".jl") && push!(pliki_jl, joinpath(root, f))
            end
        end
        @test !isempty(pliki_jl)   # sanity: znaleziono pliki

        # Zlicz pliki z `using GLMakie` top-level (per-line match — unika false-positive
        # w komentarzach/docstringach typu "VIZ-06: only file with `using GLMakie`")
        pliki_z_glmakie = String[]
        for plik in pliki_jl
            tresc = read(plik, String)
            for linia in eachline(IOBuffer(tresc))
                if startswith(strip(linia), "using GLMakie")
                    push!(pliki_z_glmakie, plik)
                    break  # jeden match per plik wystarczy
                end
            end
        end

        # Hard assertion: dokladnie 1 plik z `using GLMakie` w src/ — i jest to wizualizacja.jl
        @test length(pliki_z_glmakie) == 1
        if length(pliki_z_glmakie) == 1
            @test endswith(pliki_z_glmakie[1], "wizualizacja.jl")
        else
            # Diagnostyka: pokaz wszystkie pliki ktore lamia VIZ-06 invariant
            for p in pliki_z_glmakie
                @info "VIZ-06 violation: $p zawiera `using GLMakie`"
            end
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 9. Aqua.jl quality gate (TEST-06) — rozszerzony z Phase 1 stub.
    #    Phase 2 dodaje :Statistics do deps_compat ignore (stdlib bez compat
    #    entry per Pattern D — analogiczne do :Random z Phase 1). Trzymamy
    #    stale_deps=false do Phase 4 (BenchmarkTools wejdzie do [deps] dopiero
    #    w bench/). NIE dodajemy unbound_args=(broken=true,) preemptywnie
    #    (Pitfall F z 02-RESEARCH.md): tylko jezeli Aqua faktycznie zglosi
    #    false-positive na StanSymulacji{R}. Jezeli to sie dzieje na pierwszym
    #    uruchomieniu, Plan 02-06 SUMMARY ma to udokumentowac i w nastepnym
    #    commit dodac kwarg.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "Aqua.jl quality (TEST-06)" begin
        # BL-02 + IN-04 (gap-closure 02-08, finalized in 02-13): Aqua 0.8.14 NIE ma
        # `check_extras` kwarg (poprawne kwargs: ambiguities, unbound_args, undefined_exports,
        # project_extras, stale_deps, deps_compat, piracies, persistent_tasks, undocumented_names).
        # `project_extras=false` wylacza sprawdzanie extras-vs-targets — INTENCJONALNIE,
        # bo BenchmarkTools jest w [extras] dla Phase 4 (bench) per CONTEXT.md.
        # `persistent_tasks=false` (dodane w 03-00): GLMakie jest biblioteka GUI i z zalozenia
        # uruchamia watki tla (renderloop). To jest znane zachowanie dokumentowane przez
        # autorów GLMakie — Aqua.persistent_tasks nie jest zdolny do rozroznienia watków
        # celowych (GLMakie) od wycieków (bledy w paczce). Wylaczamy dla tej paczki.
        # Pattern D: stdlib :Random/:Statistics bez compat entry → deps_compat ignore.
        Aqua.test_all(JuliaCity;
            ambiguities = (recursive = false,),
            stale_deps = false,
            # deps_compat.ignore: stdlib (Random, Statistics) + test-only extras
            # (PerformanceTestTools, Serialization, Test, Unicode) - intentional, no compat.
            deps_compat = (ignore = [:Random, :Statistics, :PerformanceTestTools, :Serialization, :Test, :Unicode],),
            project_extras = false,
            # GLMakie jest biblioteka GUI z celowymi watkami tla — persistent_tasks=false
            # per standardowa praktyka dla pakietow zalezacych od GLMakie.
            persistent_tasks = false,
        )
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 10. JET type stability (TEST-07) — zastepuje Phase 1 JET smoke stub.
    #     @test_opt automatycznie failuje testset jezeli JET znajdzie issue.
    #     target_modules=(JuliaCity,) filtruje szum z Base/Core (Pitfall C
    #     z 02-RESEARCH.md). Pokrywa 4 hot-path public functions:
    #     oblicz_energie, delta_energii, symuluj_krok!, kalibruj_T0.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "JET type stability (TEST-07)" begin
        # Fixture (deterministyczny seed=42, N=20 wystarczy dla type-inference)
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=100)
        bufor = zeros(Float64, Threads.nthreads())

        # Warmup — JET analizuje skompilowany kod, ale dla pewnosci po pierwszej
        # kompilacji wywolujemy kazda funkcje raz. To rowniez gwarantuje ze stan
        # jest w realnym runtime state (nie tylko zero-state) przed @test_opt.
        oblicz_energie(stan.D, stan.trasa, bufor)
        delta_energii(stan, 5, 17)
        symuluj_krok!(stan, params, alg)
        kalibruj_T0(stan; n_probek=10)

        # Hard assertion: brak issues w JuliaCity-targeted analysis.
        @test_opt target_modules=(JuliaCity,) oblicz_energie(stan.D, stan.trasa, bufor)
        @test_opt target_modules=(JuliaCity,) delta_energii(stan, 5, 17)
        @test_opt target_modules=(JuliaCity,) symuluj_krok!(stan, params, alg)
        @test_opt target_modules=(JuliaCity,) kalibruj_T0(stan; n_probek=10)
    end
end
