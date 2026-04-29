# Testset dla src/baselines.jl - pokrywa REQ ALG-04 + TEST-05 (NN-baseline-beat ≥10%).
# Wlaczany przez include("test_baselines.jl") z test/runtests.jl (Plan 02-06).
# Mozna tez uruchomic standalone: include("test/test_baselines.jl") po `using JuliaCity, Test, Random`.
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# TEST-05 jest CI-tezki (~30s na N=1000); rekomendacja Pitfall G:
# liczba_krokow=20_000 (start); podnies do 50_000 jezeli single-seed deterministic test fail.
#
# Outer @testset "test_baselines.jl" zapobiega podwojnemu liczeniu testow gdy plik
# jest wlaczany 2x (standalone include + runtests.jl include) - jeden node w drzewie testow.

using Test
using JuliaCity
using Random
using Random: Xoshiro

@testset "test_baselines.jl" begin

    # ─────────────────────────────────────────────────────────────────────────
    # 1. trasa_nn jest permutacja 1:n (ALG-04)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "trasa_nn - permutacja 1:n (ALG-04)" begin
        # Maly fixture - 5 punktow w roznych miejscach (rozneic na linii prostej)
        punkty = [Punkt2D(0.0, 0.0), Punkt2D(1.0, 0.0), Punkt2D(2.0, 0.0),
                  Punkt2D(3.0, 0.0), Punkt2D(4.0, 0.0)]
        # D recznie - punkty na linii prostej, dystans = roznica indeksow
        n = 5
        D = Matrix{Float64}(undef, n, n)
        for i in 1:n, j in 1:n
            D[i, j] = abs(i - j) * 1.0
        end
        # NN z start=1: powinno byc [1, 2, 3, 4, 5] (greedy idzie po sasiadach)
        trasa = trasa_nn(D; start=1)
        @test trasa == [1, 2, 3, 4, 5]
        @test sort(trasa) == collect(1:5)  # permutacja invariant

        # NN z start=3: greedy idzie do najblizszego sasiada (2 lub 4 - tie); sprawdz tylko
        # ze permutacja
        trasa3 = trasa_nn(D; start=3)
        @test sort(trasa3) == collect(1:5)
        @test trasa3[1] == 3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 2. trasa_nn determinizm + asercja niekwadratowa D
    # ─────────────────────────────────────────────────────────────────────────
    @testset "trasa_nn determinizm + walidacja" begin
        punkty = generuj_punkty(50; seed=42)
        stan = StanSymulacji(punkty)
        oblicz_macierz_dystans!(stan)
        t1 = trasa_nn(stan.D; start=1)
        t2 = trasa_nn(stan.D; start=1)
        @test t1 == t2  # determinizm (D-15: start=1, brak RNG)

        # niekwadratowa D - asercja
        D_bad = zeros(Float64, 5, 4)
        @test_throws AssertionError trasa_nn(D_bad)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 3. inicjuj_nn! pelny init flow (ALG-04, D-14)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "inicjuj_nn! - pelny init flow (ALG-04, D-14)" begin
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))

        # przed init: pre-alokowane D, trasa = collect(1:n), energia = 0
        @test stan.energia == 0.0
        @test stan.trasa == collect(1:20)

        inicjuj_nn!(stan)

        # po init: D wypelnione, trasa = NN, energia = oblicz_energie(NN)
        @test sort(stan.trasa) == collect(1:20)  # permutacja
        @test stan.energia > 0
        @test stan.iteracja == 0
        @test stan.D[1, 1] == 0.0  # diagonal
        @test stan.D[1, 2] == stan.D[2, 1]  # symmetry

        # cache invariant - stan.energia ≈ oblicz_energie(stan.D, stan.trasa, bufor)
        bufor = zeros(Float64, Threads.nthreads())
        @test isapprox(stan.energia, oblicz_energie(stan.D, stan.trasa, bufor); rtol=1e-12)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 4. TEST-05 NN-baseline-beat (KRYTYCZNY)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-05: NN-baseline-beat - SA ≥10% pod NN (N=1000 seed=42)" begin
        # Pitfall G level 2 activated (gap-closure 02-13 / Task 3):
        #   - 20_000 krokow: ratio 9.63 (SA znacznie gorszy niz NN — za malo eksploracji)
        #   - 50_000 krokow: ratio 4.04 (SA wciaz gorszy — late-phase greedy nie zdarza sie wracac)
        #   - 200_000 krokow: T(200k) = 1.03 * 0.9999^200000 ≈ 2e-9 (full greedy descent),
        #     dla N=1000 (C(N,2) = 499_500 par) zapewnia ~40% pokrycie samples.
        # Single-seed deterministic — binary outcome, brak flakiness. ~30s na typowym CPU.
        punkty = generuj_punkty(1000; seed=42)

        # NN baseline (pure - bez Stana)
        n = length(punkty)
        D = Matrix{Float64}(undef, n, n)
        for j in 1:n, i in 1:j-1
            dx = punkty[i][1] - punkty[j][1]
            dy = punkty[i][2] - punkty[j][2]
            d = sqrt(dx * dx + dy * dy)
            D[i, j] = d
            D[j, i] = d
        end
        for j in 1:n
            D[j, j] = 0.0
        end
        nn = trasa_nn(D; start=1)
        bufor = zeros(Float64, Threads.nthreads())
        energia_nn = oblicz_energie(D, nn, bufor)

        # SA run
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=200_000)
        for _ in 1:params.liczba_krokow
            symuluj_krok!(stan, params, alg)
        end

        # SA musi byc ≥10% krotsze niz NN
        @test stan.energia / energia_nn <= 0.9
        @info "TEST-05: NN energia=$(round(energia_nn, digits=4)), SA energia=$(round(stan.energia, digits=4)), ratio=$(round(stan.energia/energia_nn, digits=4))"
    end

end  # outer @testset "test_baselines.jl"
