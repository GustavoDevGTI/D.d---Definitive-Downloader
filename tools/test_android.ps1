param(
    [string]$TestFile='integration_test/android_smoke_test.dart',
    [string]$Device='emulator-5560',
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$FlutterPath=(Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/flutter/bin/flutter.bat'),
    [string]$SdkRoot=(Join-Path $env:LOCALAPPDATA 'Android/Sdk'),
    [string]$PlainName='',
    [switch]$LiveSources,
    [switch]$GrantNotifications
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath($WorkspaceRoot)
if($workspace.StartsWith('\\') -or -not (Test-Path -LiteralPath (Join-Path $workspace '.dd-android-build-root'))) {
    throw 'Use o estágio Android local identificado, preparado por build_android.ps1.'
}
if($TestFile -notmatch '^integration_test/[a-z_]+_test\.dart$' -or
    -not (Test-Path -LiteralPath (Join-Path $workspace $TestFile))) {
    throw 'Teste nativo inválido ou ausente.'
}
if($Device -notmatch '^[a-zA-Z0-9_.:\-]+$'){throw 'Identificador de dispositivo inválido.'}
$aapt=Get-ChildItem -LiteralPath (Join-Path $SdkRoot 'build-tools') -Directory |
    Where-Object {$_.Name -match '^\d+\.\d+\.\d+$'} |
    Sort-Object {[version]$_.Name} -Descending |
    Select-Object -First 1 | ForEach-Object {Join-Path $_.FullName 'aapt.exe'}
if(-not $aapt){throw 'Android build-tools/aapt não encontrado.'}
$apk=Join-Path $workspace 'build/app/outputs/flutter-apk/app-debug.apk'
function Test-IntegrationApk {
    if(-not (Test-Path -LiteralPath $apk)){return $false}
    $badging= & $aapt dump badging $apk
    return $LASTEXITCODE -eq 0 -and [bool]($badging -match "^package: name='br\.com\.definitivedownloader\.app\.integration'")
}
$savedJava=$env:JAVA_HOME
$savedOptions=$env:JAVA_TOOL_OPTIONS
$socketTemp=Join-Path $env:USERPROFILE '.dd-android-sockets'
New-Item -ItemType Directory -Path $socketTemp -Force | Out-Null
Push-Location $workspace
try {
    $env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
    $env:JAVA_TOOL_OPTIONS=($savedOptions+' "-Djdk.net.unixdomain.tmpdir='+$socketTemp+'"').Trim()
    $defines=@('--dart-define=DD_ANDROID_INTEGRATION=true')
    if($LiveSources){$defines+='--dart-define=DD_ANDROID_LIVE_SOURCES=true'}
    # Flutter captures a package BEFORE building and uses that ID for cleanup.
    # Seed its cache with the isolated APK, never a previously built normal app.
    if(-not (Test-IntegrationApk)) {
        & $FlutterPath build apk --debug --no-pub --target $TestFile --target-platform android-arm64,android-x64 @defines
        if($LASTEXITCODE -ne 0){throw 'Falha ao preparar o pacote isolado de testes.'}
    }
    if(-not (Test-IntegrationApk)){throw 'APK de teste não possui o identificador isolado esperado.'}
    if($GrantNotifications) {
        $adb=Join-Path $SdkRoot 'platform-tools/adb.exe'
        if(-not ([bool]((& $aapt dump permissions $apk) -match 'android.permission.POST_NOTIFICATIONS'))) {
            throw 'Compile o APK de integração atualizado antes de testar notificações.'
        }
        & $adb -s $Device install -r $apk
        if($LASTEXITCODE -ne 0){throw 'Falha ao preparar permissões do pacote isolado.'}
        $sdk=& $adb -s $Device shell getprop ro.build.version.sdk
        if([int]$sdk -ge 33) {
            & $adb -s $Device shell pm grant br.com.definitivedownloader.app.integration android.permission.POST_NOTIFICATIONS
            if($LASTEXITCODE -ne 0){throw 'Falha ao conceder notificações somente ao pacote de teste.'}
        }
    }
    $selection=@()
    if($PlainName){$selection=@('--plain-name',$PlainName)}
    & $FlutterPath test $TestFile --no-pub -d $Device --timeout 360s --disable-dds --no-uninstall @defines @selection
    if($LASTEXITCODE -ne 0){throw "Teste nativo falhou (código $LASTEXITCODE)."}
    if(-not (Test-IntegrationApk)){throw 'O build perdeu o isolamento do pacote de teste.'}
} finally {
    Pop-Location
    if($null -eq $savedJava){Remove-Item Env:JAVA_HOME -ErrorAction SilentlyContinue}else{$env:JAVA_HOME=$savedJava}
    if($null -eq $savedOptions){Remove-Item Env:JAVA_TOOL_OPTIONS -ErrorAction SilentlyContinue}else{$env:JAVA_TOOL_OPTIONS=$savedOptions}
}
