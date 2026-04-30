#!/usr/bin/env bash
# bench/uruchom.sh
#
# Canonical wrapper dla bench/run_all.jl (Phase 4 D-06 + checker iteracja 1 BLOCKER #4).
# Aktywuje throwaway environment z BenchmarkTools — workaround dla limitu Pkg.jl gdzie
# `--project=.` nie widzi pakietow z `[targets].test` przy plain script execution.
# D-10 (no bench/Project.toml) honored — temp-env zyje wylacznie w runtime.

set -euo pipefail

# Cwd niezalezny od miejsca wywolania — script zawsze cd'i do repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Auto-detect: jesli BenchmarkTools resolvable z `--project=.`, uzywamy direct path.
# Inaczej fallback do temp-env recipe.
if julia --project=. -e 'using BenchmarkTools' >/dev/null 2>&1; then
    echo "[uruchom.sh] BenchmarkTools resolvable via --project=. — direct invocation"
    exec julia --project=. --threads=auto bench/run_all.jl
else
    echo "[uruchom.sh] BenchmarkTools nie resolvable via --project=. — fallback do throwaway env"
    exec julia --threads=auto --project=. -e '
        import Pkg
        Pkg.activate(temp=true)
        Pkg.develop(path=".")
        Pkg.add("BenchmarkTools")
        include("bench/run_all.jl")
    '
fi
