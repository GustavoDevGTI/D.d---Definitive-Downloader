param(
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$Device='emulator-5560',
    [switch]$RenamedJournal,
    [string]$PythonPath=(Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev/music-engine-venv/Scripts/python.exe')
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($WorkspaceRoot)
if($root.StartsWith('\\') -or -not (Test-Path -LiteralPath (Join-Path $root '.dd-android-build-root'))) {
    throw 'Use o estágio Android local identificado.'
}
if($Device -ne 'emulator-5560'){throw 'Use somente o emulador dedicado do Downloader.'}
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
if(((& $adb -s $Device emu avd name) -join "`n") -notmatch '^Definitive_API_36'){throw 'AVD incorreto.'}
$logs=Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev'
$options=@()
if($RenamedJournal){$options+='--renamed-journal'}
& $PythonPath (Join-Path $root 'tools/test_android_interruption.py') --root $root --adb $adb --device $Device --logs $logs @options
if($LASTEXITCODE -ne 0){throw 'A automação de interrupção falhou; confira o log privado da fase indicada.'}
