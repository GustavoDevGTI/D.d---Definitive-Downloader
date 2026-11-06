param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$StageRoot=(Join-Path $env:LOCALAPPDATA 'DdbAndroid'),
    [string]$FlutterPath=(Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/flutter/bin/flutter.bat'),
    [string]$JavaHome='',
    [string]$PythonPath='',
    [switch]$SkipTests,
    [switch]$SkipAnalysis
)
$ErrorActionPreference='Stop'
if(-not $PythonPath) {
    $candidates=@((Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/music-engine-venv/Scripts/python.exe'))
    # The desktop runtime may be updated and remove a venv's original base.
    # Preparation uses only stdlib; locate the currently installed runtime,
    # without installing Python or modifying any existing environment.
    $runtime=Get-AppxPackage '*CodexPrimaryRuntime*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if($runtime){$candidates+=Join-Path $runtime.InstallLocation 'dependencies/python/python.exe'}
    foreach($candidate in $candidates) {
        if(Test-Path -LiteralPath $candidate) {
            & $candidate --version *> $null
            if($LASTEXITCODE -eq 0){$PythonPath=$candidate;break}
        }
    }
    if(-not $PythonPath){throw 'Informe -PythonPath com Python disponível para preparar os módulos Android.'}
}
$workspace=[IO.Path]::GetFullPath($WorkspaceRoot)
$stage=[IO.Path]::GetFullPath($StageRoot)
if($stage.StartsWith('\\')) { throw 'O estágio Android deve ser local.' }
$marker=Join-Path $stage '.dd-android-build-root'
if((Test-Path -LiteralPath $stage) -and -not (Test-Path -LiteralPath $marker)) {
    throw "Estágio existente sem identificação Android: $stage"
}
if((Test-Path -LiteralPath $marker) -and
    ([IO.Path]::GetFullPath((Get-Content -LiteralPath $marker -Raw).Trim()) -ne $workspace)) {
    throw 'O estágio Android pertence a outro workspace.'
}
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Set-Content -LiteralPath $marker -Value $workspace
foreach($folder in @('lib','assets','test','integration_test','android','tools','runtime')) {
    & robocopy (Join-Path $workspace $folder) (Join-Path $stage $folder) /E /R:1 /W:1 /XD .gradle build .cxx __pycache__ /XF local.properties /NFL /NDL /NJH /NJS /NP | Out-Null
    if($LASTEXITCODE -ge 8) { throw "Falha ao copiar $folder." }
}
foreach($name in @('pubspec.yaml','pubspec.lock','analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $workspace $name) -Destination $stage -Force
}
$savedJava=$env:JAVA_HOME
$savedOptions=$env:JAVA_TOOL_OPTIONS
if(-not $JavaHome) {
    $candidate='C:\Program Files\Android\Android Studio\jbr'
    $JavaHome=if(Test-Path -LiteralPath $candidate){$candidate}else{$env:JAVA_HOME}
}
# Windows MSIX path virtualization can make Java's AF_UNIX temp socket fail.
# Scope its temporary directory to this process, outside virtualized AppData;
# no registry, firewall, TLS or system security settings are changed.
$socketTemp=Join-Path $env:USERPROFILE '.dd-android-sockets'
New-Item -ItemType Directory -Path $socketTemp -Force | Out-Null
Push-Location $stage
try {
    if($JavaHome){$env:JAVA_HOME=$JavaHome}
    $env:JAVA_TOOL_OPTIONS=($savedOptions+' "-Djdk.net.unixdomain.tmpdir='+$socketTemp+'"').Trim()
    & $PythonPath (Join-Path $stage 'tools/prepare_android_music.py') --root $stage --cache (Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/android-runtime-wheels') --output (Join-Path $stage 'android/app/src/main/assets')
    if($LASTEXITCODE -ne 0){throw 'Falha ao preparar os módulos portáteis Android.'}
    & $FlutterPath pub get
    if($LASTEXITCODE -ne 0){throw 'Falha ao resolver dependências Android.'}
    if(-not $SkipAnalysis){
        & $FlutterPath analyze --no-pub
        if($LASTEXITCODE -ne 0){throw 'A análise estática falhou.'}
    }
    if(-not $SkipTests){
        & (Join-Path $stage 'tools/test_project.ps1') -WorkspaceRoot $stage -FlutterPath $FlutterPath -Area mobile
    }
    & $FlutterPath build apk --debug --no-pub --target lib/main.dart --target-platform android-arm64,android-x64
    if($LASTEXITCODE -ne 0){throw 'A compilação do APK falhou.'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $stage 'build/app/outputs/flutter-apk/app-debug.apk'))
    try {
        $entries=@($archive.Entries.FullName)
        $abis=@($entries | Where-Object {$_ -match '^lib/([^/]+)/'} |
            ForEach-Object {($_ -split '/')[1]} | Sort-Object -Unique)
        if(@($abis | Where-Object {$_ -notin @('arm64-v8a','x86_64')}).Count -gt 0){
            throw 'APK anuncia uma ABI sem runtime Flutter completo.'
        }
        foreach($abi in @('arm64-v8a','x86_64')) {
            foreach($library in @('libflutter.so','libsqlite3.so','libpython.so','libffmpeg.so','libqjs.so','libpython.zip.so','libffmpeg.zip.so')) {
                if("lib/$abi/$library" -notin $entries){throw "Biblioteca ausente: $abi/$library"}
            }
        }
        foreach($asset in @('assets/dd_music_bundle.zip','assets/dd_music_bundle.sha256')) {
            if($asset -notin $entries){throw "Módulos Android ausentes: $asset"}
        }
    } finally {$archive.Dispose()}
    $version=(Select-String -LiteralPath pubspec.yaml -Pattern '^version:\s*([\d.]+)').Matches[0].Groups[1].Value
    $destination=Join-Path $workspace 'dist/Android'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $apk=Join-Path $destination "Definitive-Downloader-$version-Android-teste.apk"
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-debug.apk' -Destination $apk -Force
    $hash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath ($apk+'.sha256') -Value "$hash  $([IO.Path]::GetFileName($apk))" -Encoding ascii
    Write-Output "APK de teste (chave debug): $apk"
    Write-Output "SHA-256: $hash"
} finally {
    Pop-Location
    if($null -eq $savedJava){Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue}else{$env:JAVA_HOME=$savedJava}
    if($null -eq $savedOptions){Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue}else{$env:JAVA_TOOL_OPTIONS=$savedOptions}
}
