param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$Device='emulator-5560'
)
$ErrorActionPreference='Stop'
if($Device -notmatch '^emulator-\d+$'){throw 'Esta automação de ciclo de vida usa somente emulador dedicado.'}
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$avd=(& $adb -s $Device emu avd name) -join "`n"
if($avd -notmatch '^Definitive_API_36'){throw 'Use o emulador dedicado do D.d, sem contas ou biblioteca pessoal.'}
$log=Join-Path $env:LOCALAPPDATA ('DefinitiveDownloaderDev/android-bg-'+[guid]::NewGuid().ToString('N')+'.log')
New-Item -ItemType File -Path $log | Out-Null
$watcher=Start-Job -ArgumentList $adb,$Device,$log -ScriptBlock {
    param($adb,$serial,$log)
    foreach($marker in @('ANDROID_BG_REOPEN_AUDIO','ANDROID_BG_REOPEN_DOWNLOAD')) {
        $clock=[Diagnostics.Stopwatch]::StartNew()
        while(-not (Select-String -LiteralPath $log -Pattern $marker -Quiet)) {
            if($clock.Elapsed.TotalSeconds -gt 300){throw "Marcador de ciclo de vida não recebido: $marker"}
            Start-Sleep -Milliseconds 250
        }
        & $adb -s $serial shell am start -n br.com.definitivedownloader.app.integration/br.com.definitivedownloader.app.MainActivity | Out-Null
        if($LASTEXITCODE -ne 0){throw 'Falha ao reabrir somente a Activity de teste.'}
    }
}
try {
    & (Join-Path $WorkspaceRoot 'tools/test_android.ps1') -WorkspaceRoot $WorkspaceRoot -Device $Device -TestFile integration_test/android_background_test.dart -GrantNotifications *> $log
    $done=Wait-Job $watcher -Timeout 5
    if(-not $done -or $watcher.State -ne 'Completed'){throw 'A automação de reabertura não concluiu.'}
    Receive-Job $watcher -ErrorAction Stop
} finally {
    Get-Content -LiteralPath $log -Tail 65
    if($watcher.State -eq 'Running'){Stop-Job $watcher}
    Remove-Job $watcher
    Write-Output "Log privado: $log"
}
