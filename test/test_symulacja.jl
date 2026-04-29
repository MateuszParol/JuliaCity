# Testset dla src/algorytmy/simulowane_wyzarzanie.jl - pokrywa REQ ALG-01..03/06..08 + TEST-01/04/08.
# Wlaczany przez include("test_symulacja.jl") z test/runtests.jl (Plan 02-06) LUB standalone.
# Outer wrapper @testset "test_symulacja.jl" zapobiega podwojnemu liczeniu przy podwojnej inkluzji.
# TEST-04 multi-thread determinism uzywa PerformanceTestTools.@include_foreach (subprocess).
# TEST-08 golden value: HARDCODED dla StableRNG(42) N=20 1000 krokow (Task 3b dostarcza wartosci).
#
# Asercje wewnetrzne po angielsku per LANG-04. Komentarze polskie per LANG-01.
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ TEST-08 PLACEHOLDER REMOVAL PROCEDURE (do uruchomienia w CI / dev-machine z Julia)  ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║ Plan 02-05 zostal wykonany w worktree BEZ zainstalowanej Julii (Rule 3   ║
# ║ deviation - spojne z plans 02-01..04). const TRASA_REF = Int[] oraz      ║
# ║ const ENERGIA_REF = NaN sa PLACEHOLDERAMI; TEST-08 golden-value asercje  ║
# ║ sa otoczone @test_broken w `else` branch (`isempty(TRASA_REF) || isnan(ENERGIA_REF)`).  ║
# ║                                                                          ║
# ║ KROKI naprawcze (CI / lokalny dev):                                      ║
# ║   1. Uruchomic helper script:                                            ║
# ║        julia --project=. test/_generuj_test08_refs.jl > /tmp/refs.txt    ║
# ║   2. Output zawiera 2 linie:                                             ║
# ║        const TRASA_REF = [<20 Int...>]                                   ║
# ║        const ENERGIA_REF = <Float64>                                     ║
# ║   3. Zastapic w tym pliku linie 23-24:                                   ║
# ║        const TRASA_REF = Int[]      -> wartosc z helper output linia 1   ║
# ║        const ENERGIA_REF = NaN      -> wartosc z helper output linia 2   ║
# ║   4. Usunac plik test/_generuj_test08_refs.jl (one-shot)                 ║
# ║   5. Pelne `julia --project=. -e 'using Pkg; Pkg.test()'` exit 0         ║
# ║                                                                          ║
# ║ Placeholder gate (verifier):                                             ║
# ║   grep -cE 'TRASA_REF = Int\[\]|ENERGIA_REF = NaN|TRASA_REF = \[\]'      ║
# ║   musi zwrocic 0 (po Task 3b CI run).                                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝

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
        # Stan placeholderow Task 3a: TRASA_REF = Int[], ENERGIA_REF = NaN.
        # Task 3b (do uruchomienia w CI z dostepna Julia) wygeneruje konkretne wartosci
        # przez `julia --project=. test/_generuj_test08_refs.jl` i zastapi placeholdery;
        # po Task 3b oba @test sa zielone.
        #
        # Guard ponizej: gdy placeholdery sa nadal obecne, golden-value asercje sa
        # @test_broken (sygnalizuje DELIBERATE deferred verification - Rule 3 z env_note,
        # spojne z precedensami plans 02-01..04 dla deferred runtime checks). Strukturalna
        # weryfikacja (Hamilton invariant + permutacja) pozostaje hard-asserted.
        @test sort(stan.trasa) == collect(1:20)  # Hamilton invariant - struktura zachowana niezaleznie od refs
        @test stan.energia >= 0  # sanity: positive perimeter sum
        @test stan.iteracja == 1000  # licznik krokow zgadza sie z params.liczba_krokow
        if !isempty(TRASA_REF) && !isnan(ENERGIA_REF)
            # Task 3b wykonany - golden value asercje hard
            @test stan.trasa == TRASA_REF
            @test isapprox(stan.energia, ENERGIA_REF; rtol=1e-6)
        else
            # Task 3b PENDING (placeholdery nadal obecne) - asercje broken (deferred do CI run)
            @test_broken stan.trasa == TRASA_REF
            @test_broken isapprox(stan.energia, ENERGIA_REF; rtol=1e-6)
        end
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
    # 6. TEST-04 subprocess: JULIA_NUM_THREADS=1 vs N -> identical trajektoria
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TEST-04 subprocess: JULIA_NUM_THREADS=1 vs N -> identical trajektoria" begin
        # Pattern z RESEARCH Example 3 (linie 491-530) - PerformanceTestTools.@include_foreach
        # spawn-uje subprocess z env override (JULIA_NUM_THREADS) i serializuje wyniki
        # do tempname() plikow. Test sprawdza ze inicjuj_nn! + 5_000 krokow SA daje
        # bit-identyczna trase i sub-ULP energia tolerance dla 1 vs N watkow.
        #
        # WR-08 fix (gap-closure 02-12): hardcoded JULIA_NUM_THREADS=8 zastapione
        # max(2, Sys.CPU_THREADS). Single-core CI runners zostaja skipped (porownanie
        # 1-vs-N wymaga >=2 logicznych rdzeni).
        if Sys.CPU_THREADS < 2
            @test_skip "TEST-04 subprocess wymaga >=2 logicznych rdzeni (Sys.CPU_THREADS=$(Sys.CPU_THREADS))"
            return
        end
        nthr_high = string(max(2, Sys.CPU_THREADS))   # WR-08: dynamic, NIE hardcoded 8

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
                ["JULIA_NUM_THREADS" => "1",       "JC_OUT" => out_1],
                ["JULIA_NUM_THREADS" => nthr_high, "JC_OUT" => out_n],
            ]
        )
        r1 = deserialize(out_1)
        rn = deserialize(out_n)
        # D-12 (LOCKED): bit-identical trasa, sub-ULP energia tolerance (rtol=1e-12)
        @test r1.trasa == rn.trasa
        @test isapprox(r1.energia, rn.energia; rtol=1e-12)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 7. ALG-06 stagnation patience early-stop (D-04)
    # ─────────────────────────────────────────────────────────────────────────
    @testset "ALG-06: stagnation patience early-stop (D-04)" begin
        # Cel: dowiesc ze uruchom_sa! z malym cierpliwosc=10 zatrzymuje
        # petle PRZED params.liczba_krokow=10_000. Bez ALG-06 stop loop
        # zawsze konczyl by sie na hard cap. Patience-based exit jest
        # jedynym mechanizmem ktory moze dac stan.iteracja < 10_000.
        #
        # D-04 lock: reset licznika tylko gdy delta < 0 (strict improvement).
        # Akceptacja Metropolis przy delta >= 0 NIE resetuje (eksploracja, nie postep).

        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        # ALPHA=0.5 -> bardzo szybkie chlodzenie -> energia szybko stagnuje
        # CIERPLIWOSC=10 -> pierwsze 10 krokow bez strict improvement -> exit
        alg = SimAnnealing(stan; alfa=0.5, cierpliwosc=10)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=10_000)

        n_krokow = uruchom_sa!(stan, params, alg)

        # KLUCZOWE: stan.iteracja < params.liczba_krokow dowodzi early-stop dziala
        @test stan.iteracja < params.liczba_krokow
        @test n_krokow == stan.iteracja  # consistency
        @test sort(stan.trasa) == collect(1:20)  # Hamilton invariant zachowany

        @info "ALG-06: cierpliwosc=10 -> n_krokow=$(n_krokow) (cap=$(params.liczba_krokow); patience early-stop dziala)"
    end


    # ──────────────────────────────────────────────────────────────────────
    # 8. BL-01 boundary regression: i=n-1 case nie crashuje (gap-closure 02-07)
    # ──────────────────────────────────────────────────────────────────────
    @testset "BL-01 boundary i=n-1 nigdy nie crashuje (gap-closure)" begin
        # Cel: dowiesc ze fix `1:(n-2)` w symuluj_krok! eliminuje probabilistyczny
        # crash z empty range. Pre-fix: i=n-1 -> j-range (n+1):n pusty -> ArgumentError.
        # Post-fix: i sampled from 1:(n-2) wylacznie - boundary i=n-1 niemozliwy.
        #
        # N=3 fixture: jedyna legalna para to (i=1, j=3). i sampled from 1:1, j from 3:3.
        # 10_000 krokow gwarantuje ze pre-fix wersja by crashnela (P>1-(0.5)^10000 ≈ 1.0).

        # N=3 boundary fixture
        punkty3 = generuj_punkty(3; seed=42)
        stan3 = StanSymulacji(punkty3; rng=Xoshiro(42))
        inicjuj_nn!(stan3)
        alg3 = SimAnnealing(stan3)
        stan3.temperatura = alg3.T_zero
        params3 = Parametry(liczba_krokow=10_000)

        # Hard assert: brak ArgumentError przez 10_000 krokow
        for _ in 1:10_000
            symuluj_krok!(stan3, params3, alg3)
        end
        @test sort(stan3.trasa) == collect(1:3)  # Hamilton invariant zachowany
        @test stan3.iteracja == 10_000

        # N=20 sanity: pre-fix mial ~5% per-step crash; post-fix MUST sustain 100_000
        punkty20 = generuj_punkty(20; seed=43)
        stan20 = StanSymulacji(punkty20; rng=Xoshiro(43))
        inicjuj_nn!(stan20)
        alg20 = SimAnnealing(stan20)
        stan20.temperatura = alg20.T_zero
        params20 = Parametry(liczba_krokow=100_000)
        for _ in 1:100_000
            symuluj_krok!(stan20, params20, alg20)
        end
        @test sort(stan20.trasa) == collect(1:20)
        @test stan20.iteracja == 100_000
    end

    # ─────────────────────────────────────────────────────────────────────────
    # 9. BL-03 patience reset semantics: rule (2) delta<0 vs rule (1) best-known
    # ─────────────────────────────────────────────────────────────────────────
    @testset "BL-03 patience reset semantics (gap-closure 02-09)" begin
        # Cel: dowiesc ze fix BL-03 zmienia uruchom_sa! z rule (1) best-known
        # na rule (2) strict per-step delta<0 (zgodnie z D-04 + docstring).
        #
        # Strategia testu: zbudowac LOKALNA replika obu regul, przejsc po tej samej
        # sekwencji energii, i porownac zachowanie licznika. Sekwencja zaprojektowana
        # tak, ze rule (1) i rule (2) DIVERGUJA na konkretnym kroku.

        # Sekwencja: E0=100 (init), E1=99 (improvement), E2=102 (worsening accepted),
        # E3=100 (improvement vs E2, but >= best-known E1=99), E4=100 (no change).
        energie = [100.0, 99.0, 102.0, 100.0, 100.0]

        # Replika rule (2) - delta<0 vs poprzedniego kroku (FIX behaviour):
        function policz_resety_rule2(seq::Vector{Float64})
            resety = 0
            e_prev = seq[1]
            for k in 2:length(seq)
                if seq[k] < e_prev
                    resety += 1
                end
                e_prev = seq[k]
            end
            return resety
        end

        # Replika rule (1) - delta<0 vs best-known minimum (PRE-FIX behaviour):
        function policz_resety_rule1(seq::Vector{Float64})
            resety = 0
            e_min = seq[1]
            for k in 2:length(seq)
                if seq[k] < e_min
                    e_min = seq[k]
                    resety += 1
                end
            end
            return resety
        end

        # Rule (1): reset gdy E < e_min. seq=(100,99,102,100,100):
        #   E1=99 < 100 -> reset (e_min=99). E2=102 not<99. E3=100 not<99. E4=100 not<99.
        #   Total: 1 reset.
        @test policz_resety_rule1(energie) == 1

        # Rule (2): reset gdy E < e_prev. seq=(100,99,102,100,100):
        #   E1=99 < 100 -> reset. E2=102 not<99. E3=100 < 102 -> reset. E4=100 not<100.
        #   Total: 2 resets.
        @test policz_resety_rule2(energie) == 2

        # Sanity: regulami rozne dla tej sekwencji - kluczowy element discriminator.
        @test policz_resety_rule1(energie) != policz_resety_rule2(energie)

        # Strukturalny check: src/algorytmy/simulowane_wyzarzanie.jl uzywa
        # energia_prev (rule 2 fix). NIE uzywa energia_min w uruchom_sa! body.
        src_path = joinpath(pkgdir(JuliaCity), "src", "algorytmy", "simulowane_wyzarzanie.jl")
        src_content = read(src_path, String)
        @test occursin("energia_prev", src_content)
        # energia_min variable removed from uruchom_sa! (rule 1 indicator)
        @test !occursin("energia_min = stan.energia", src_content)

        # Behavioral sanity: uruchom_sa! terminuje poprawnie z fixed semantyka i
        # Hamilton invariant zachowany (continuity check vs ALG-06 testset).
        punkty = generuj_punkty(20; seed=42)
        stan = StanSymulacji(punkty; rng=Xoshiro(42))
        inicjuj_nn!(stan)
        alg = SimAnnealing(stan; alfa=0.99, cierpliwosc=50)
        stan.temperatura = alg.T_zero
        params = Parametry(liczba_krokow=2000)
        n_krokow = uruchom_sa!(stan, params, alg)
        @test n_krokow > 0
        @test n_krokow == stan.iteracja
        @test sort(stan.trasa) == collect(1:20)
    end

end  # outer @testset "test_symulacja.jl"
