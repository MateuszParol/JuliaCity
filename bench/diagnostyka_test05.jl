# bench/diagnostyka_test05.jl
#
# Plan 02-14, Faza A: empiryczna diagnoza dlaczego TEST-05 (NN-baseline-beat)
# nie przechodzi z domyslna kalibracja kalibruj_T0 = 2σ.
#
# Reprodukuje fixture TEST-05 (N=1000, seed=42, NN-start) i mierzy:
#   1. T₀_calibrated (2σ) z kalibruj_T0
#   2. Statystyki rozkladu delta_energii dla NN-tour (mean/std/p50/p95)
#   3. Kandydatow T₀ dla techniki B3 (target acceptance closed-form)
#   4. 5 mini-runow SA z roznymi T₀, kazdy 50_000 krokow:
#         T₀ ∈ {0.01, 0.05, 0.1, 0.5, T₀_calibrated}
#      → ratio = energia_final / energia_nn
#      → acceptance_ratio_worsening_first1k (counter)
#   5. Rekomendacja: ktory T₀ daje najlepszy ratio
#
# Uruchomienie:
#   julia --project=. bench/diagnostyka_test05.jl
#
# Output: czyste linie do skopiowania do 02-14-SUMMARY.md.

using JuliaCity
using Random
using Statistics: mean, std, quantile

# ────────────────────────────────────────────────────────────────────────
# Lokalna replika symuluj_krok! z dodatkowymi licznikami acceptance ratio
# (NIE modyfikuje src/; tylko skrypt diagnostyczny).
# ────────────────────────────────────────────────────────────────────────
mutable struct DiagLicznik
    worsening_proposed::Int
    worsening_accepted::Int
    improvements::Int
end
DiagLicznik() = DiagLicznik(0, 0, 0)

function diag_krok!(stan::StanSymulacji, alg::SimAnnealing, lic::DiagLicznik)
    n = length(stan.trasa)
    i = rand(stan.rng, 1:(n - 2))
    j = rand(stan.rng, (i + 2):n)
    delta = delta_energii(stan, i, j)
    if delta < 0.0
        # improvement
        reverse!(view(stan.trasa, (i + 1):j))
        stan.energia += delta
        lic.improvements += 1
    else
        lic.worsening_proposed += 1
        if rand(stan.rng) < exp(-delta / stan.temperatura)
            reverse!(view(stan.trasa, (i + 1):j))
            stan.energia += delta
            lic.worsening_accepted += 1
        end
    end
    stan.temperatura *= alg.alfa
    stan.iteracja += 1
    return nothing
end

function fresh_stan_with_nn()
    punkty = generuj_punkty(1000; seed=42)
    stan = StanSymulacji(punkty; rng=Xoshiro(42))
    inicjuj_nn!(stan)
    return stan
end

function compute_nn_energia()
    stan = fresh_stan_with_nn()
    return stan.energia
end

# ────────────────────────────────────────────────────────────────────────
# Krok 1: T₀_calibrated z kalibruj_T0 (formula 2σ, D-03 LOCKED)
# ────────────────────────────────────────────────────────────────────────
println("="^72)
println("PLAN 02-14, FAZA A — diagnostyka TEST-05 (NN-baseline-beat)")
println("="^72)

println("\n[diagnostyka] N=1000, seed=42, NN-start (fresh stan)")
stan_diag = fresh_stan_with_nn()
energia_nn = stan_diag.energia
println("[diagnostyka] energia_nn (po inicjuj_nn!) = $(round(energia_nn, digits=4))")

T0_calibrated = kalibruj_T0(stan_diag)
println("[diagnostyka] T₀_calibrated (kalibruj_T0 = 2σ) = $(round(T0_calibrated, digits=6))")

# ────────────────────────────────────────────────────────────────────────
# Krok 2: rozklad delta_energii dla 1000 random 2-opt swapow na NN-tour
# ────────────────────────────────────────────────────────────────────────
function sample_deltas(stan::StanSymulacji, n_probek::Int, rng)
    n = length(stan.trasa)
    positives = Float64[]
    negatives = Float64[]
    for _ in 1:n_probek
        i = rand(rng, 1:(n - 2))
        j = rand(rng, (i + 2):n)
        delta = delta_energii(stan, i, j)
        if delta > 0.0
            push!(positives, delta)
        elseif delta < 0.0
            push!(negatives, delta)
        end
    end
    return positives, negatives
end

println("\n[diagnostyka] sample 1000 random 2-opt deltas, NN-start:")
positives, negatives = sample_deltas(stan_diag, 1000, Xoshiro(2026))
println("    n_positive = $(length(positives))")
println("    n_negative = $(length(negatives))")
println("    n_zero     = $(1000 - length(positives) - length(negatives))")
if length(positives) >= 2
    println("    mean(positive) = $(round(mean(positives), digits=6))")
    println("    std(positive)  = $(round(std(positives), digits=6))")
    println("    p50(positive)  = $(round(quantile(positives, 0.5), digits=6))")
    println("    p95(positive)  = $(round(quantile(positives, 0.95), digits=6))")
    println("    min(positive)  = $(round(minimum(positives), digits=6))")
    println("    max(positive)  = $(round(maximum(positives), digits=6))")
end

# ────────────────────────────────────────────────────────────────────────
# Krok 3: kandydaci T₀ dla techniki B3 (target acceptance closed-form)
#   T₀ = -mean(positive) / ln(χ₀)
# ────────────────────────────────────────────────────────────────────────
if length(positives) >= 2
    mean_pos = mean(positives)
    println("\n[diagnostyka] kandydaci T₀ dla B3 (target acceptance closed-form):")
    for chi0 in [0.5, 0.6, 0.8]
        T0_b3 = -mean_pos / log(chi0)
        println("    χ₀ = $(chi0)  →  T₀ = -mean(pos)/ln(χ₀) = $(round(T0_b3, digits=6))")
    end
end

# ────────────────────────────────────────────────────────────────────────
# Krok 4: 5 mini-runow SA, kazdy fresh stan + 50_000 krokow + counter
# ────────────────────────────────────────────────────────────────────────
function mini_run_sa(T0::Float64, n_steps::Int)
    stan = fresh_stan_with_nn()
    alg = SimAnnealing(stan; T_zero=T0)
    stan.temperatura = alg.T_zero
    lic = DiagLicznik()
    lic_first1k = DiagLicznik()

    for k in 1:n_steps
        if k <= 1000
            diag_krok!(stan, alg, lic_first1k)
        else
            diag_krok!(stan, alg, lic)
        end
    end
    total_improvements = lic.improvements + lic_first1k.improvements
    total_worsening_prop = lic.worsening_proposed + lic_first1k.worsening_proposed
    total_worsening_acc = lic.worsening_accepted + lic_first1k.worsening_accepted
    return (
        energia_final = stan.energia,
        improvements = total_improvements,
        worsening_proposed = total_worsening_prop,
        worsening_accepted = total_worsening_acc,
        first1k_worsening_proposed = lic_first1k.worsening_proposed,
        first1k_worsening_accepted = lic_first1k.worsening_accepted,
    )
end

function eksperymenty(candidates::Vector{Float64}, n_steps::Int, energia_nn::Float64,
                       T0_calibrated::Float64)
    println("\n[diagnostyka] mini-runy SA ($(n_steps) kroków, NN-start, fresh stan):")
    results = Dict{Float64, NamedTuple}()
    for T0 in candidates
        r = mini_run_sa(T0, n_steps)
        ratio = r.energia_final / energia_nn
        acc1k = r.first1k_worsening_proposed > 0 ?
                r.first1k_worsening_accepted / r.first1k_worsening_proposed * 100 :
                0.0
        acc_total = r.worsening_proposed > 0 ?
                    r.worsening_accepted / r.worsening_proposed * 100 :
                    0.0
        label = T0 == T0_calibrated ? "$(round(T0, digits=4)) [cal]" : "$(round(T0, digits=4))"
        println("    T₀=$(rpad(label, 14))  energia=$(rpad(round(r.energia_final, digits=4), 10))  " *
                "ratio=$(round(ratio, digits=4))  acc1k=$(round(acc1k, digits=2))%  " *
                "acc_tot=$(round(acc_total, digits=2))%  improv=$(r.improvements)")
        results[T0] = (ratio=ratio, energia=r.energia_final, acc1k=acc1k, acc_total=acc_total)
    end
    best_T0 = candidates[1]
    best_ratio = Inf
    for T0 in candidates
        if results[T0].ratio < best_ratio
            best_ratio = results[T0].ratio
            best_T0 = T0
        end
    end
    return best_T0, best_ratio, results
end

# Faza A.1: szeroki sweep T₀ przy 50k kroków
candidates_50k = [0.001, 0.005, 0.01, 0.02, 0.05, 0.1, 0.5, T0_calibrated]
best_T0_50k, best_ratio_50k, _ = eksperymenty(candidates_50k, 50_000, energia_nn, T0_calibrated)

# Faza A.2: greedy-friendly low T₀ przy 200k kroków (czy zwiększenie budżetu pomaga?)
candidates_200k = [0.001, 0.005, 0.01, 0.02]
best_T0_200k, best_ratio_200k, _ = eksperymenty(candidates_200k, 200_000, energia_nn, T0_calibrated)

# ────────────────────────────────────────────────────────────────────────
# Krok 5: rekomendacja
# ────────────────────────────────────────────────────────────────────────
println("\n" * "="^72)
println("[diagnostyka] REKOMENDACJA:")
println("    50k kroków:  najlepszy T₀=$(round(best_T0_50k, digits=6))  ratio=$(round(best_ratio_50k, digits=4))")
println("    200k kroków: najlepszy T₀=$(round(best_T0_200k, digits=6))  ratio=$(round(best_ratio_200k, digits=4))")
println("    Cel TEST-05: ratio ≤ 0.9")
if best_ratio_50k <= 0.9
    println("    STATUS: ✓ TEST-05 PASS przy 50_000 kroków z T₀=$(round(best_T0_50k, digits=4))")
elseif best_ratio_200k <= 0.9
    println("    STATUS: ⚠ TEST-05 PASS dopiero przy 200_000 kroków z T₀=$(round(best_T0_200k, digits=4))")
    println("    → Decyzja: low fixed T₀ + zwiększyć budżet TEST-05 do 200_000 (vs cel 50_000)")
else
    println("    STATUS: ✗ ŻADEN T₀ + budżet z testowanych nie daje ratio ≤ 0.9")
    println("    → Eskalacja: cooling tuning (alfa) LUB multi-start LUB or-opt move")
end
println("="^72)
