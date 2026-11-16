param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$Device='emulator-5560',
    [ValidateSet('Export','Destination')][string]$Scenario='Export',
    [string]$PythonPath=(Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/music-engine-venv/Scripts/python.exe')
)
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if($Device -eq 'emulator-5560') {
    & (Join-Path $PSScriptRoot 'start-test-emulator.ps1') -Project Downloader | Out-Host
}
if($Device -notmatch '^emulator-\d+$' -or ((& $adb -s $Device emu avd name) -join "`n") -notmatch '^Definitive_API_36') {
    throw 'Use somente o emulador dedicado, sem contas ou biblioteca pessoal.'
}
$log=Join-Path $env:LOCALAPPDATA ('DefinitiveDownloaderDev/android-storage-'+[guid]::NewGuid().ToString('N')+'.log')
New-Item -ItemType File -Path $log | Out-Null
$driver=if($Scenario -eq 'Destination'){'tools/android_managed_driver.py'}else{'tools/android_storage_driver.py'}
$testFile=if($Scenario -eq 'Destination'){'integration_test/android_managed_documents_test.dart'}else{'integration_test/android_storage_test.dart'}
$watcher=Start-Job -ArgumentList $PythonPath,$WorkspaceRoot,$adb,$Device,$log,$driver -ScriptBlock {
    param($python,$root,$adb,$serial,$log,$driver)
    & $python (Join-Path $root $driver) --adb $adb --device $serial --log $log --audio (Join-Path $root 'assets/demo/tone.mp3')
    if($LASTEXITCODE -ne 0){throw 'Falha na automação de compartilhamento/SAF.'}
}
try {
    # A prior integration isolate may retain its cached engine/service. Start
    # this scenario from a stopped test process, preserving its persisted data.
    & $adb -s $Device shell am force-stop br.com.definitivedownloader.app.integration
    if($LASTEXITCODE -ne 0){throw 'Não foi possível encerrar a instância anterior do pacote de teste.'}
    & (Join-Path $WorkspaceRoot 'tools/test_android.ps1') -WorkspaceRoot $WorkspaceRoot -Device $Device -TestFile $testFile *> $log
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
