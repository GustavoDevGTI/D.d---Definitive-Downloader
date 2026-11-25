param(
    [string]$Iscc=(Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/InnoSetupNuGet/tools/ISCC.exe'),
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [ValidatePattern('^$|^[a-f0-9]{32}$')][string]$ProbeId='',
    [switch]$SkipUninstall
)
$ErrorActionPreference='Stop'
$identity=if($ProbeId){$ProbeId}else{[Guid]::NewGuid().ToString('N')}
$appId='D.d-Installer-Verification-'+$identity
$productName='D.d Installer Verification '+$identity
$testRoot=Join-Path $env:LOCALAPPDATA ('DdbInstallerProbe/'+$identity)
$package=Join-Path $testRoot 'package'
$output=Join-Path $testRoot 'output'
$installed=Join-Path $testRoot 'installed'
foreach($folder in @($package,$output,$installed)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}
if(!([IO.Path]::GetFullPath($installed).StartsWith([IO.Path]::GetFullPath($testRoot)+[IO.Path]::DirectorySeparatorChar))) {
    throw 'Destino do teste fora do diretório isolado.'
}
# Small executable fixture. The silent installer never launches it.
Copy-Item -LiteralPath (Join-Path $env:WINDIR 'System32/where.exe') -Destination (Join-Path $package 'definitive_downloader.exe')
$registry=''
$library=Join-Path $testRoot 'library.sqlite3'
[IO.File]::WriteAllText($library,'independent library fixture')
$libraryHash=(Get-FileHash -LiteralPath $library).Hash
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) ('Desinstalar '+$productName+'.lnk')
foreach($version in @('0.1.95','0.1.96')) {
    [IO.File]::WriteAllText((Join-Path $package 'build-marker.txt'),$version)
    $compileLog=Join-Path $testRoot ('compile-'+$version+'.log')
    & $Iscc "/DProductAppId=$appId" "/DProductName=$productName" "/DAppVersion=$version" "/DPackageDir=$package" "/DOutputDir=$output" (Join-Path $WorkspaceRoot 'installer/windows.iss') *> $compileLog
    if($LASTEXITCODE -ne 0){throw "Compilação do instalador de teste falhou: $compileLog"}
    $setup=Join-Path $output "Definitive-Downloader-$version-Setup-Windows-x64.exe"
    $arguments=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+(Join-Path $testRoot ('install-'+$version+'.log'))+'"'))
    if($version -eq '0.1.95'){$arguments+=('/DIR="'+$installed+'"')}
    $process=Start-Process -FilePath $setup -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if($process.ExitCode -ne 0){throw 'Instalação isolada falhou.'}
    # Inno can shorten a long AppId when it generates the registry key.
    $matches=@(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' |
        Get-ItemProperty | Where-Object {$_.DisplayName -eq $productName})
    if($matches.Count -ne 1){throw 'Cadastro de teste ausente ou duplicado.'}
    $entry=$matches[0]
    $registry=$entry.PSPath
    if($entry.DisplayVersion -ne $version -or
       [IO.Path]::GetFullPath($entry.InstallLocation).TrimEnd('\') -ne $installed.TrimEnd('\') -or
       (Get-Content -LiteralPath (Join-Path $installed 'build-marker.txt') -Raw) -ne $version){
        throw 'A atualização não substituiu a versão no mesmo destino.'
    }
    if(!(Test-Path -LiteralPath $shortcut)){throw 'Atalho de desinstalação ausente.'}
}
$entries=@(Get-ChildItem -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' |
    Get-ItemProperty | Where-Object {$_.DisplayName -eq $productName})
if($entries.Count -ne 1){throw 'A atualização duplicou o cadastro do aplicativo.'}
$uninstaller=Join-Path $installed 'unins000.exe'
if(!(Test-Path -LiteralPath $uninstaller)){throw 'Desinstalador ausente.'}
if($SkipUninstall){
    if((Get-FileHash -LiteralPath $library).Hash -ne $libraryHash){throw 'Biblioteca de teste alterada.'}
    Write-Output "WINDOWS_INSTALLER_OK upgrade; one entry; uninstaller and shortcut present. Uninstall execution skipped. Evidence: $testRoot"
    return
}
$unknownFile=Join-Path $installed 'user-created.txt'
[IO.File]::WriteAllText($unknownFile,'keep unknown user file')
$process=Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -WindowStyle Hidden -Wait -PassThru
if($process.ExitCode -ne 0){throw 'Desinstalação isolada falhou.'}
if((Test-Path -LiteralPath $registry) -or (Test-Path -LiteralPath $shortcut) -or
   (Test-Path -LiteralPath (Join-Path $installed 'definitive_downloader.exe')) -or
   !(Test-Path -LiteralPath $unknownFile) -or
   (Get-FileHash -LiteralPath $library).Hash -ne $libraryHash){
    throw 'A desinstalação não preservou os dados ou deixou o aplicativo cadastrado.'
}
Write-Output "WINDOWS_INSTALLER_OK upgrade 0.1.95 -> 0.1.96; one entry; uninstall; user files preserved. Evidence: $testRoot"
