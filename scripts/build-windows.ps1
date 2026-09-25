param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("prs", "v2", "v2-prs")]
    [string]$Flavor,

    [string]$PrRefs,
    [switch]$Force,
    [switch]$SkipPackage,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$bashCandidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
$bash = $bashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) {
    throw "Git Bash is required. Install Git for Windows and re-run."
}

$bashArgs = @("./scripts/build-windows.sh", $Flavor)
if ($Force) { $bashArgs += "--force" }
if ($SkipPackage) { $bashArgs += "--skip-package" }
if ($SkipTests) { $bashArgs += "--skip-tests" }
if ($PrRefs) { $bashArgs += @("--pr-refs", $PrRefs) }

Write-Host "Running $($bashArgs -join ' ')"
& $bash --noprofile --norc @bashArgs
if ($LASTEXITCODE -ne 0) {
    throw "build-windows.sh exited with code $LASTEXITCODE"
}
