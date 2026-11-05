param(
    [ValidateSet('Local','Essential','Regression')][string]$Profile='Local',
    [string[]]$Area=@(),
    [string[]]$TestFiles=@(),
    [switch]$ListOnly,
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$FlutterPath='',
    [string]$PythonPath=''
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath($WorkspaceRoot)
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'test_suites.json') -Raw | ConvertFrom-Json
if($Profile -ne 'Local' -and ($Area.Count -gt 0 -or $TestFiles.Count -gt 0)) {
    throw 'Area/TestFiles pertencem ao perfil Local. Regression já inclui todos os testes.'
}
$areas=@($Area | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
$knownAreas=@($manifest.areas.PSObject.Properties.Name)
foreach($name in $areas) {
    if($name -notin $knownAreas) { throw "Área desconhecida: $name. Opções: $($knownAreas -join ', ')." }
}
$files=@($manifest.essential)
foreach($name in $areas) { $files+=@($manifest.areas.$name) }
$files+=@($TestFiles)
$allFiles=@(Get-ChildItem -LiteralPath (Join-Path $workspace 'test') -Filter '*_test.dart' -File -Recurse |
    ForEach-Object { $_.FullName.Substring($workspace.TrimEnd('\','/').Length+1).Replace('\','/') })
$classified=@($manifest.essential)+@($manifest.regression_only)+@($TestFiles)
foreach($property in $manifest.areas.PSObject.Properties) { $classified+=@($property.Value) }
$unclassified=@($allFiles | Where-Object { $_ -notin $classified })
if($unclassified.Count -gt 0 -and $Profile -ne 'Regression') {
    throw "Testes sem classificação: $($unclassified -join ', '). Atualize test_suites.json ou selecione-os em TestFiles."
}
if($Profile -eq 'Regression') {
    $files=$allFiles
}
$files=@($files | ForEach-Object { $_.Replace('\','/') } | Sort-Object -Unique)
foreach($file in $files) {
    if($file -notmatch '^test/(?:[a-zA-Z0-9_\-]+/)*[a-zA-Z0-9_\-]+_test\.dart$' -or
        -not (Test-Path -LiteralPath (Join-Path $workspace $file) -PathType Leaf)) {
        throw "Arquivo de teste inválido ou ausente: $file"
    }
}
$worker=($Profile -eq 'Regression' -or 'worker' -in $areas)
$plan=[pscustomobject]@{ profile=$Profile; areas=$areas; files=$files; worker=$worker }
if($ListOnly) { $plan | ConvertTo-Json -Depth 5; return }
if($workspace.StartsWith('\\')) {
    throw 'Flutter não deve rodar pela UNC. Sincronize um estágio local preparado e passe -WorkspaceRoot. build_windows.ps1 faz essa preparação automaticamente.'
}
if(-not (Test-Path -LiteralPath (Join-Path $workspace '.dart_tool/package_config.json'))) {
    throw 'Workspace local sem dependências preparadas. Execute flutter pub get nele antes dos testes.'
}
if(-not $FlutterPath) {
    $candidate=Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/flutter/bin/flutter.bat'
    $FlutterPath=if(Test-Path -LiteralPath $candidate) { $candidate } else { (Get-Command flutter -ErrorAction Stop).Source }
}
if($worker) {
    if(-not $PythonPath) {
        $candidate=Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/music-engine-venv/Scripts/python.exe'
        if(Test-Path -LiteralPath $candidate) { $PythonPath=$candidate }
        else { throw 'Informe -PythonPath com o ambiente de testes do motor. Nenhuma ferramenta global foi instalada.' }
    }
    if(-not (Test-Path -LiteralPath (Join-Path $workspace 'runtime/music_worker/test_policy.py'))) {
        throw 'Fontes/testes do motor ausentes no workspace local. Sincronize runtime/music_worker.'
    }
}
Write-Output "Testes: $Profile; $($files.Count) arquivos Dart; motor offline: $worker."
if($Profile -eq 'Local' -and $areas.Count -eq 0 -and $TestFiles.Count -eq 0) {
    Write-Output 'Somente essencial selecionado. Para validar mudança funcional, informe Area ou TestFiles.'
}
# Profiles stay offline and do not inherit expensive screenshot/probe flags.
$optional=@('DD_PLAYLIST_REAL_OUTPUT','DD_LOCAL_REAL_DLL','DD_LOCAL_REAL_OUTPUT','DD_LOCAL_REAL_INPUT',
    'DD_SOUNDCLOUD_REAL_WORKER','DD_SOUNDCLOUD_REAL_OUTPUT',
    'DD_LAYOUT_OUTPUT','DD_PLAYER_SCREENSHOTS')
$saved=@{}
foreach($name in $optional) {
    $saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
    [Environment]::SetEnvironmentVariable($name,$null,'Process')
}
Push-Location $workspace
try {
    if($Profile -eq 'Regression') { & $FlutterPath test --no-pub }
    else { & $FlutterPath test --no-pub @files }
    if($LASTEXITCODE -ne 0) { throw "Testes Flutter falharam (código $LASTEXITCODE)." }
    if($worker) {
        & $PythonPath -m unittest discover -s runtime/music_worker -p 'test_*.py'
        if($LASTEXITCODE -ne 0) { throw "Testes offline do motor falharam (código $LASTEXITCODE)." }
    }
} finally {
    Pop-Location
    foreach($name in $optional) { [Environment]::SetEnvironmentVariable($name,$saved[$name],'Process') }
}
