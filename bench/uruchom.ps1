# bench/uruchom.ps1
#
# Canonical wrapper dla bench/run_all.jl (Phase 4 D-06 + checker BLOCKER #4).
# Aktywuje throwaway environment z BenchmarkTools — workaround dla limitu Pkg.jl.
# D-10 (no bench/Project.toml) honored — temp-env zyje wylacznie w runtime.

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir '..')
Set-Location $RepoRoot

# Auto-detect: jesli BenchmarkTools resolvable z --project=., uzywamy direct path.
& julia --project=. -e 'using BenchmarkTools' 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[uruchom.ps1] BenchmarkTools resolvable via --project=. — direct invocation"
    & julia --project=. --threads=auto bench/run_all.jl
} else {
    Write-Host "[uruchom.ps1] BenchmarkTools nie resolvable via --project=. — fallback do throwaway env"
    & julia --threads=auto --project=. -e @'
import Pkg
Pkg.activate(temp=true)
Pkg.develop(path=".")
Pkg.add("BenchmarkTools")
include("bench/run_all.jl")
'@
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
