param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$Device='emulator-5560',
    [string]$PythonPath=(Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/music-engine-venv/Scripts/python.exe')
)
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if($Device -notmatch '^emulator-\d+$' -or ((& $adb -s $Device emu avd name) -join "`n") -notmatch '^Definitive_API_36') {
    throw 'Use somente o emulador dedicado, sem contas ou biblioteca pessoal.'
}
$log=Join-Path $env:LOCALAPPDATA ('DefinitiveDownloaderDev/android-storage-'+[guid]::NewGuid().ToString('N')+'.log')
New-Item -ItemType File -Path $log | Out-Null
$watcher=Start-Job -ArgumentList $PythonPath,$WorkspaceRoot,$adb,$Device,$log -ScriptBlock {
    param($python,$root,$adb,$serial,$log)
    & $python (Join-Path $root 'tools/android_storage_driver.py') --adb $adb --device $serial --log $log --audio (Join-Path $root 'assets/demo/tone.mp3')
    if($LASTEXITCODE -ne 0){throw 'Falha na automação de compartilhamento/SAF.'}
}
try {
    # A prior integration isolate may retain its cached engine/service. Start
    # this scenario from a stopped test process, preserving its persisted data.
    & $adb -s $Device shell am force-stop br.com.definitivedownloader.app.integration
    if($LASTEXITCODE -ne 0){throw 'Não foi possível encerrar a instância anterior do pacote de teste.'}
    & (Join-Path $WorkspaceRoot 'tools/test_android.ps1') -WorkspaceRoot $WorkspaceRoot -Device $Device -TestFile integration_test/android_storage_test.dart *> $log
    $done=Wait-Job $watcher -Timeout 10
    if(-not $done -or $watcher.State -ne 'Completed'){throw 'A automação SAF não concluiu.'}
    Receive-Job $watcher -ErrorAction Stop
} finally {
    Receive-Job $watcher -Keep -ErrorAction Continue
    Get-Content -LiteralPath $log -Tail 65
    if($watcher.State -eq 'Running'){Stop-Job $watcher}
    Remove-Job $watcher
    Write-Output "Log privado: $log"
}
