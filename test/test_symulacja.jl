# Testset dla src/algorytmy/simulowane_wyzarzanie.jl - pokrywa REQ ALG-01..03/06..08 + TEST-01/04/08.
# Wlaczany przez include("test_symulacja.jl") z test/runtests.jl (Plan 02-06) LUB standalone.
# Outer wrapper @testset "test_symulacja.jl" zapobiega podwojnemu liczeniu przy podwojnej inkluzji.
# TEST-04 multi-thread determinism uzywa PerformanceTestTools.@include_foreach (subprocess).
# TEST-08 golden value: HARDCODED dla StableRNG(42) N=20 1000 krokow (Task 3b dostarcza wartosci).
#
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.

using Test
using JuliaCity
using Random
using Random: Xoshiro
using StableRNGs
using Serialization
using PerformanceTestTools

# WARTOSCI WYGENEROWANE LOKALNIE - WPISYWANE PRZEZ Task 3b (test/_generuj_test08_refs.jl).
# Aktualizuj te wartosci jezeli zmienisz algorytm SA / RNG / liczbe krokow.
# Po Task 3a: PLACEHOLDERS - testset TEST-08 INTENCJONALNIE FAILUJE; Task 3b je nadpisuje.
const TRASA_REF = Int[]   # placeholder - Task 3b wpisuje vector z 20 Int
const ENERGIA_REF = NaN   # placeholder - Task 3b wpisuje konkretna Float64

@testset "test_symulacja.jl" begin

    # ─────────────────────────────────────────────────────────────────────────
    # 1. SimAnnealing struct + ctors (ALG-01)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "SimAnnealing struct + ctors (ALG-01)" begin
        # SimAnnealing <: Algorytm (Holy-traits dispatch)
        @test SimAnnealing <: Algorytm

        # default positional ctor (Julia generuje dla concrete-typed struct)
        alg_pos = SimAnnealing(0.5, 0.9999, 5000)
        @test alg_pos.T_zero == 0.5
        @test alg_pos.alfa == 0.9999
        @test alg_pos.cierpliwosc == 5000

        # kwarg ctor z auto-kalibracja T_zero=kalibruj_T0(stan) (D-03)
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg_kw = SimAnnealing(stan)
        @test alg_kw.T_zero > 0
        @test alg_kw.alfa == 0.9999  # default (D-02)
        @test alg_kw.cierpliwosc == 5000  # default (D-02)

        # kwarg ctor z explicit nadpisaniem
        alg_explicit = SimAnnealing(stan; alfa=0.99, cierpliwosc=100, T_zero=1.5)
        @test alg_explicit.T_zero == 1.5
        @test alg_explicit.alfa == 0.99
        @test alg_explicit.cierpliwosc == 100
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 2. symuluj_krok! type-stable + zero-alloc (ALG-02, ALG-03, TEST-02, TEST-03)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "symuluj_krok! type-stable + @allocated == 0 (ALG-02, ALG-03)" begin
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=50_000)

        # TEST-02: type-stable (@inferred ::Nothing wymaga literal `return nothing` w body)
        @test @inferred(symuluj_krok!(stan, params, alg)) === nothing

        # ALG-02: licznik kroków +=1 po kazdym wywolaniu
        iter_przed = stan.iteracja
        symuluj_krok!(stan, params, alg)
        @test stan.iteracja == iter_przed + 1

        # TEST-03 / ALG-03: zero-alloc po rozgrzewce (helper function - Pitfall A)
        function _alloc_krok(stan, params, alg)
            return @allocated symuluj_krok!(stan, params, alg)
        end
        # warmup
        for _ in 1:3
            symuluj_krok!(stan, params, alg)
        end
        @test _alloc_krok(stan, params, alg) == 0
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 3. TEST-01 / ALG-08 Hamilton invariant po kazdym kroku
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-01 / ALG-08: Hamilton invariant po kazdym kroku" begin
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=2000)

        n = length(stan.trasa)
        # 2000 krokow, sample co 100 + final - reverse!(view) permutuje fragment,
        # sort(stan.trasa) == 1:n caly czas
        for k in 1:2000
            symuluj_krok!(stan, params, alg)
            if k % 100 == 0
                @test sort(stan.trasa) == collect(1:n)
            end
        end
        # finalny check po 2000 krokach
        @test sort(stan.trasa) == collect(1:n)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 4. TEST-08 golden value StableRNG(42), N=20, 1000 krokow
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-08: golden value StableRNG(42), N=20, 1000 krokow" begin
        punkty = generuj_punkty(20, StableRNG(42))
        stan = StanSymulacji(punkty; rng=StableRNG(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan; alfa=0.9999, cierpliwosc=5000)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=1000)
        for _ in 1:1000
            symuluj_krok!(stan, params, alg)
        end
        # TEST-08 golden value - HARDCODED reference for cross-version stability (D-17).
        # Po Task 3a: TRASA_REF = Int[] i ENERGIA_REF = NaN -> testy FAILUJA INTENCJONALNIE.
        # Task 3b wygeneruje konkretne wartosci przez test/_generuj_test08_refs.jl
        # i zastapi placeholdery; po Task 3b oba @test sa zielone.
        @test stan.trasa == TRASA_REF
        @test isapprox(stan.energia, ENERGIA_REF; rtol=1e-6)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 5. TEST-04 in-process determinism: same seed, fresh stan -> identical trajectory
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-04 in-process: same seed, fresh stan -> identical trajectory" begin
        # Sanity check przed subprocess test - dwa fresh stan z tym samym seed
        # i tymi samymi krokami daja bit-identyczna trase i energie (sub-ULP tolerance).
        punkty = generuj_punkty(50; seed=42)

        function uruchom_run(seed::Int, krokow::Int)
            stan = StanSymulacji(punkty; rng=Xoshiro(seed))
            inicjuj_nn!(stan)
            alg = SimAnnealing(stan)
            stan.temperatura = alg.T_zero
            params = Parametry(liczba_krokow=krokow)
            for _ in 1:krokow
                symuluj_krok!(stan, params, alg)
            end
            return (trasa=copy(stan.trasa), energia=stan.energia)
        end

        r1 = uruchom_run(42, 1000)
        r2 = uruchom_run(42, 1000)
        # D-12 (LOCKED): bit-identical trasa, sub-ULP energia tolerance
        @test r1.trasa == r2.trasa
        @test isapprox(r1.energia, r2.energia; rtol=1e-12)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 6. TEST-04 subprocess: JULIA_NUM_THREADS=1 vs 8 -> identical trajektoria
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-04 subprocess: JULIA_NUM_THREADS=1 vs 8 -> identical trajektoria" begin
        # Pattern z RESEARCH Example 3 (linie 491-530) - PerformanceTestTools.@include_foreach
        # spawn-uje subprocess z env override (JULIA_NUM_THREADS) i serializuje wyniki
        # do tempname() plikow. Test sprawdza ze inicjuj_nn! + 5_000 krokow SA daje
        # bit-identyczna trase i sub-ULP energia tolerance dla 1 vs 8 watkow.
        sa_run_script = """
        using JuliaCity, Random, Serialization
        punkty = generuj_punkty(1000; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=5_000)
        for _ in 1:params.liczba_krokow
            symuluj_krok!(stan, params, alg)
        end
        out_path = ENV["JC_OUT"]
        serialize(out_path, (trasa=stan.trasa, energia=stan.energia))
        """

        script_path = tempname() * ".jl"
        write(script_path, sa_run_script)
        out_1 = tempname() * ".jls"
        out_n = tempname() * ".jls"

        PerformanceTestTools.@include_foreach(
            script_path,
            [
                ["JULIA_NUM_THREADS" => "1", "JC_OUT" => out_1],
                ["JULIA_NUM_THREADS" => "8", "JC_OUT" => out_n],
            ]
        )
        r1 = deserialize(out_1)
        rn = deserialize(out_n)
        # D-12 (LOCKED): bit-identical trasa, sub-ULP energia tolerance (rtol=1e-12)
        @test r1.trasa == rn.trasa
        @test isapprox(r1.energia, rn.energia; rtol=1e-12)
    end

end  # outer @testset "test_symulacja.jl"
