# Install Spectre-mitigated MSVC libraries required by the upstream Windows
# native helpers. Used by GitHub Actions; safe to run locally if vswhere exists.
param(
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64"
)

$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe was not found. Install Visual Studio 2022 Build Tools."
}

$installPath = & $vswhere -products * -latest -property installationPath
if (-not $installPath) {
    throw "Visual Studio Build Tools are not installed."
}

$workload = if ($Arch -eq "arm64") {
    "Microsoft.VisualStudio.Component.VC.Runtimes.ARM64.Spectre"
} else {
    "Microsoft.VisualStudio.Component.VC.Runtimes.x86.x64.Spectre"
}

$setupExe = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$proc = Start-Process -FilePath $setupExe `
    -ArgumentList "modify", "--installPath", "`"$installPath`"", "--add", $workload, "--quiet", "--norestart" `
    -Wait -PassThru -NoNewWindow
if ($null -eq $proc -or $proc.ExitCode -ne 0) {
    $code = if ($null -ne $proc) { $proc.ExitCode } else { 1 }
    Write-Error "Visual Studio Installer failed with exit code $code"
    exit $code
}
