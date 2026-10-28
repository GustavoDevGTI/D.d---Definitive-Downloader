param(
    [Parameter(Mandatory=$true)][string]$Iscc,
    [Parameter(Mandatory=$true)][string]$PackageDir,
    [Parameter(Mandatory=$true)][string]$OutputDir
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$pubspec = Get-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$')
if (-not $match.Success) { throw 'Versão inválida em pubspec.yaml.' }
foreach ($required in @('definitive_downloader.exe','music_engine\dd_music_worker.exe','data\flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageDir $required))) { throw "Pacote incompleto: $required" }
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
& $Iscc "/DAppVersion=$($match.Groups[1].Value)" "/DPackageDir=$([IO.Path]::GetFullPath($PackageDir))" "/DOutputDir=$([IO.Path]::GetFullPath($OutputDir))" (Join-Path $root 'installer\windows.iss')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar instalador.' }
