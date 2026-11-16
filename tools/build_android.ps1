param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$StageRoot=(Join-Path $env:LOCALAPPDATA 'DdbAndroid'),
    [string]$FlutterPath=(Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/flutter/bin/flutter.bat'),
    [string]$SdkRoot=(Join-Path $env:LOCALAPPDATA 'Android/Sdk'),
    [string]$JavaHome='',
    [string]$PythonPath='',
    [ValidatePattern('^$|^https://[A-Za-z0-9.-]+(?::[0-9]{1,5})?/?$')][string]$PlaylistGateway=$env:DD_PLAYLIST_GATEWAY,
    [switch]$SkipTests,
    [switch]$SkipAnalysis
)
$ErrorActionPreference='Stop'
# Android build/test caches live in the existing profile-quota exclusion.
if ($IsWindows) { $env:GRADLE_USER_HOME = Join-Path $env:LOCALAPPDATA 'Gradle' }
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
$savedSigning=$env:DD_ANDROID_TEST_SIGNING
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
    $env:DD_ANDROID_TEST_SIGNING='1'
    # Let Flutter regenerate the release registrant without dev-only plugins.
    $playlistDefines = @()
    if ($PlaylistGateway) { $playlistDefines += "--dart-define=DD_PLAYLIST_GATEWAY=$PlaylistGateway" }
    & $FlutterPath build apk --release --split-per-abi --target lib/main.dart --target-platform android-arm64,android-x64 @playlistDefines
    if($LASTEXITCODE -ne 0){throw 'A compilação do APK falhou.'}
    $buildTools=Get-ChildItem -LiteralPath (Join-Path $SdkRoot 'build-tools') -Directory |
        Where-Object {$_.Name -match '^\d+\.\d+\.\d+$'} |
        Sort-Object {[version]$_.Name} -Descending | Select-Object -First 1
    if(!$buildTools){throw 'Android build-tools não encontrado.'}
    $aapt=Join-Path $buildTools.FullName 'aapt.exe'
    $apksigner=Join-Path $buildTools.FullName 'apksigner.bat'
    $versionMatch=(Select-String -LiteralPath pubspec.yaml -Pattern '^version:\s*([\d.]+)\+(\d+)').Matches[0]
    $version=$versionMatch.Groups[1].Value
    $versionCode=$versionMatch.Groups[2].Value
    $abis=@('arm64-v8a','x86_64')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach($abi in $abis) {
        $built=Join-Path $stage "build/app/outputs/flutter-apk/app-$abi-release.apk"
        if((Get-Item -LiteralPath $built).Length -gt 80MB){
            throw "O APK $abi excede 80 MiB."
        }
        $badging=& $aapt dump badging $built
        if($LASTEXITCODE -ne 0 -or
            !($badging -like "package: name='br.com.definitivedownloader.app' versionCode='$versionCode' versionName='$version'*") -or
            $badging -match '^application-debuggable' -or
            !($badging -match "^native-code: '$abi'\s*$")){
            throw "Manifesto ou ABI inesperada no APK $abi."
        }
        & $apksigner verify $built
        if($LASTEXITCODE -ne 0){throw "Assinatura inválida no APK $abi."}
        $archive=[IO.Compression.ZipFile]::OpenRead($built)
        try {
            $entries=@($archive.Entries.FullName)
            if('assets/flutter_assets/kernel_blob.bin' -in $entries -or
                $entries -match '/libmpv\.so$'){
                throw "Código de depuração ou áudio Windows encontrado no APK $abi."
            }
            foreach($library in @('libapp.so','libflutter.so','libsqlite3.so','libpython.so','libffmpeg.so','libqjs.so','libpython.zip.so','libffmpeg.zip.so')) {
                if("lib/$abi/$library" -notin $entries){throw "Biblioteca ausente: $abi/$library"}
            }
            foreach($asset in @('assets/dd_music_bundle.zip','assets/dd_music_bundle.sha256')) {
                if($asset -notin $entries){throw "Módulos Android ausentes: $asset"}
            }
        } finally {$archive.Dispose()}
    }
    $destination=Join-Path $workspace 'dist/Android'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach($abi in $abis) {
        $name="Definitive-Downloader-$version-Android-$abi-teste.apk"
        $apk=Join-Path $destination $name
        Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$abi-release.apk" -Destination $apk -Force
        $hash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
        Set-Content -LiteralPath ($apk+'.sha256') -Value "$hash  $name" -Encoding ascii
        Write-Output "APK de teste otimizado: $apk"
        Write-Output "SHA-256: $hash"
    }
} finally {
    Pop-Location
    if($null -eq $savedJava){Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue}else{$env:JAVA_HOME=$savedJava}
    if($null -eq $savedOptions){Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue}else{$env:JAVA_TOOL_OPTIONS=$savedOptions}
    if($null -eq $savedSigning){Remove-Item Env:DD_ANDROID_TEST_SIGNING -ErrorAction SilentlyContinue}else{$env:DD_ANDROID_TEST_SIGNING=$savedSigning}
}
