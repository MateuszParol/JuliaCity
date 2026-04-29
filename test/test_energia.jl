# Testset dla src/energia.jl - pokrywa REQ ENE-01..05 + TEST-02/03 czesciowo (pure functions).
# Wlaczany przez include("test_energia.jl") z test/runtests.jl (Plan 02-06).
# Mozna tez uruchomic standalone: include("test/test_energia.jl") po `using JuliaCity, Test, Random`.
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# Outer @testset "test_energia.jl" zapobiega podwojnemu liczeniu testow gdy plik
# jest wlaczany 2x (standalone include + runtests.jl include) - jeden node w drzewie testow.

using Test
using JuliaCity
using Random
using Random: Xoshiro

@testset "test_energia.jl" begin

    # ─────────────────────────────────────────────────────────────────────────
    # 1. oblicz_energie - jednostkowy kwadrat (ENE-01, Roadmap SC-1)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "oblicz_energie - jednostkowy kwadrat (ENE-01, Roadmap SC-1)" begin
        # 4-punktowy kwadrat - obwod = 4.0 (kazda krawedz dlugosci 1.0)
        punkty = [Punkt2D(0.0, 0.0), Punkt2D(1.0, 0.0), Punkt2D(1.0, 1.0), Punkt2D(0.0, 1.0)]
        trasa = [1, 2, 3, 4]
        @test oblicz_energie(punkty, trasa) ≈ 4.0
        # Permutacja - kazdy cykl Hamiltona daje ta sama energie (cykl jest symetryczny)
        @test oblicz_energie(punkty, [2, 3, 4, 1]) ≈ 4.0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 2. oblicz_energie type-stable + alloc (ENE-02, ENE-03)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "oblicz_energie type-stable + < 4096 B (ENE-02, ENE-03)" begin
        punkty = generuj_punkty(20; seed=42)
        trasa = collect(1:20)

        # ENE-02: type-stable
        @test @inferred(oblicz_energie(punkty, trasa)) isa Float64

        # 3-arg hot-path version - budujemy lokalnie macierz D + bufor
        n = length(punkty)
        D = Matrix{Float64}(undef, n, n)
        @inbounds for j in 1:n, i in 1:j-1
            dx = punkty[i][1] - punkty[j][1]
            dy = punkty[i][2] - punkty[j][2]
            D[i, j] = D[j, i] = sqrt(dx * dx + dy * dy)
        end
        @inbounds for j in 1:n
            D[j, j] = 0.0
        end
        bufor = zeros(Float64, Threads.nthreads())

        @test @inferred(oblicz_energie(D, trasa, bufor)) isa Float64

        # ENE-03: < 4096 B po rozgrzewce. Wrap @allocated w funkcji helper (Pitfall A).
        function _alloc_3arg(D, trasa, bufor)
            return @allocated oblicz_energie(D, trasa, bufor)
        end
        # warmup
        for _ in 1:3
            oblicz_energie(D, trasa, bufor)
        end
        # Hot-path version: powinno byc 0 alloc po warmup (per D-10 - bufor pre-alokowany).
        # Tolerujemy <4096 B per ENE-03 (margines dla closure / @threads bookkeeping).
        @test _alloc_3arg(D, trasa, bufor) < 4096
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 3. oblicz_energie chunked threading (ENE-05)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "oblicz_energie chunked threading (ENE-05)" begin
        # Strukturalny check - source uzywa Threads.@threads :static + ChunkSplitters.
        # Verifikacja behavioralna: dwa wywolania na tych samych danych daja exact equality.
        # Multi-thread determinism per JULIA_NUM_THREADS test jest w test_symulacja.jl (TEST-04).
        punkty = generuj_punkty(100; seed=42)
        trasa = shuffle!(Xoshiro(7), collect(1:100))
        e1 = oblicz_energie(punkty, trasa)
        e2 = oblicz_energie(punkty, trasa)
        @test e1 == e2  # in-process determinism (no threading variation in single call)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 4. delta_energii O(1) + zero-alloc (ENE-04)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "delta_energii O(1) + zero-alloc (ENE-04)" begin
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)

        # type-stable
        @test @inferred(delta_energii(stan, 5, 17)) isa Float64

        # zero-alloc po rozgrzewce (helper function - Pitfall A)
        function _alloc_delta(stan, i, j)
            return @allocated delta_energii(stan, i, j)
        end
        for _ in 1:3
            delta_energii(stan, 5, 17)
        end
        @test _alloc_delta(stan, 5, 17) == 0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 5. Cache invariant (D-08 implied, ENE-04)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "cache invariant: stan.energia += delta zgadza sie z oblicz_energie" begin
        # Po SA krokach z delta-update, stan.energia powinno byc bliskie wynikowi
        # ponownie obliczonemu z oblicz_energie (drift kumulowany +=).
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=500)
        for _ in 1:500
            symuluj_krok!(stan, params, alg)
        end
        bufor = zeros(Float64, Threads.nthreads())
        e_recompute = oblicz_energie(stan.D, stan.trasa, bufor)
        @test isapprox(stan.energia, e_recompute; rtol=1e-10)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 6. kalibruj_T0 (ALG-05)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "kalibruj_T0 zwraca rozsadna wartosc (ALG-05)" begin
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        T0 = kalibruj_T0(stan; n_probek=1000)
        @test T0 isa Float64
        @test T0 > 0  # 2σ na worsening delts musi byc > 0
        @test T0 < 10  # rozsadny upper bound dla N=20 jednostkowy kwadrat (max delta ≈ 2*sqrt(2))
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 7. oblicz_macierz_dystans! (D-08, fundament dla delta_energii)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "oblicz_macierz_dystans! - symetria + diagonal" begin
        punkty = generuj_punkty(10; seed=1)
        stan = StanSymulacji(punkty)
        oblicz_macierz_dystans!(stan)
        @test size(stan.D) == (10, 10)
        @test all(stan.D[i, i] == 0.0 for i in 1:10)  # diagonal
        @test all(stan.D[i, j] == stan.D[j, i] for i in 1:10, j in 1:10)  # symmetry
        # spot check: D[1,2] = euklidesowa odleglosc punkty[1] do punkty[2]
        p1, p2 = punkty[1], punkty[2]
        @test stan.D[1, 2] ≈ sqrt((p1[1] - p2[1])^2 + (p1[2] - p2[2])^2)
    end

end  # outer @testset "test_energia.jl"
