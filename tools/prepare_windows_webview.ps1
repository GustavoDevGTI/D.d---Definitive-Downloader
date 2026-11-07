$ErrorActionPreference='Stop'
$directory=Join-Path $env:LOCALAPPDATA 'DownloaderDevTools/nuget/6.11.1'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$exe=Join-Path $directory 'nuget.exe'
$expected='c0ddc9cb0633c4607da7e8028eb4f91248c8b74e45a68b0c79fcfa7d78c2a481'
if(-not(Test-Path -LiteralPath $exe)) {
    $temporary=Join-Path $directory ('download-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try {
        Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/v6.11.1/nuget.exe' -OutFile $temporary -TimeoutSec 45
        if((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected){throw 'Hash NuGet divergente.'}
        Move-Item -LiteralPath $temporary -Destination $exe
    } finally {if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}}
}
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected){throw 'NuGet local divergente.'}
$signature=Get-AuthenticodeSignature -LiteralPath $exe
if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation'){throw 'Assinatura NuGet inválida.'}
# Only the caller's process PATH changes. No global installation or registry edits.
Write-Output $directory
