param([switch]$SkipTests, [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath($WorkspaceRoot)
$flutter = Join-Path $env:LOCALAPPDATA 'DownloaderDevTools\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $command) { throw 'Instale o Flutter e as ferramentas C++ para Windows.' }
    $flutter = $command.Source
}

# Network workspaces cannot always host the symlinks required by Flutter plugins.
# Build locally and copy only the final portable package back to the workspace.
$stage = Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev\build-workspace'
$marker = Join-Path $stage '.dd-build-root'
if ((Test-Path -LiteralPath $stage) -and -not (Test-Path -LiteralPath $marker)) {
    throw "Pasta local existente sem identificação do projeto: $stage"
}
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Set-Content -LiteralPath $marker -Value $workspace -Encoding utf8
foreach ($folder in @('lib','assets','test','windows')) {
    & robocopy (Join-Path $workspace $folder) (Join-Path $stage $folder) /E /XD ephemeral build /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar $folder para compilação local." }
}
foreach ($name in @('pubspec.yaml','pubspec.lock','analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $workspace $name) -Destination (Join-Path $stage $name) -Force
}
Push-Location $stage
try {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) {
        # Junctions are an NTFS alternative when unprivileged symlinks are unavailable.
        $manifestPath = Join-Path $stage '.flutter-plugins-dependencies'
        if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Não foi possível resolver as dependências.' }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $links = Join-Path $stage 'windows\flutter\ephemeral\.plugin_symlinks'
        New-Item -ItemType Directory -Path $links -Force | Out-Null
        foreach ($plugin in $manifest.plugins.windows) {
            $link = Join-Path $links $plugin.name
            $target = [IO.Path]::GetFullPath($plugin.path).TrimEnd('\')
            if (Test-Path -LiteralPath $link) {
                $existing = Get-Item -LiteralPath $link
                if ($existing.LinkType -eq 'Junction') {
                    Remove-Item -LiteralPath $link -Force
                }
            }
            if (-not (Test-Path -LiteralPath $link)) {
                New-Item -ItemType Junction -Path $link -Target $target | Out-Null
            }
        }
        if (-not (Test-Path -LiteralPath '.dart_tool\package_config.json')) { throw 'Dependências não resolvidas.' }
    }
    # Keep generated plugin rules but resolve source paths directly. Some network
    # workspace/cache combinations expose reparse points that CMake cannot read.
    $manifest = Get-Content -LiteralPath '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
    $definitions = @()
    foreach ($plugin in $manifest.plugins.windows) {
        $target = [IO.Path]::GetFullPath($plugin.path).TrimEnd('\').Replace('\','/')
        $definitions += ('set(DD_PLUGIN_' + $plugin.name + ' "' + $target + '")')
    }
    $rules = Get-Content -LiteralPath 'windows\flutter\generated_plugins.cmake' -Raw
    $rules = $rules.Replace('flutter/ephemeral/.plugin_symlinks/${plugin}/windows', '"${DD_PLUGIN_${plugin}}/windows"')
    $rules = $rules.Replace('flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows', '"${DD_PLUGIN_${ffi_plugin}}/windows"')
    $localRules = ($definitions -join [Environment]::NewLine) + [Environment]::NewLine + $rules
    Set-Content -LiteralPath 'windows\flutter\plugins_local.cmake' -Value $localRules -Encoding utf8
    & $flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'A análise estática falhou.' }
    if (-not $SkipTests) {
        & $flutter test --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Os testes falharam.' }
    }
    & $flutter build windows --release --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'A compilação Windows falhou.' }
    $destination = Join-Path $workspace 'dist\DefinitiveDownloader'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    # The worker has its own build and must not be replaced by a stale staging copy.
    & robocopy (Join-Path $stage 'build\windows\x64\runner\Release') $destination /E /XD music_engine /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw 'Falha ao copiar o pacote final.' }
    Write-Output "Aplicativo gerado: $(Join-Path $destination 'definitive_downloader.exe')"
} finally { Pop-Location }
