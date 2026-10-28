param([Parameter(Mandatory=$true)][string]$Python,[string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath($WorkspaceRoot)
$stage=Join-Path $env:LOCALAPPDATA 'DefinitiveDownloaderDev\music-engine-build'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
& robocopy (Join-Path $workspace 'runtime\music_worker') (Join-Path $stage 'source') /E /XD __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null
if($LASTEXITCODE -ge 8){throw 'Falha ao copiar fontes do motor.'}
$ffmpeg= & $Python -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())'
if($LASTEXITCODE -ne 0){throw 'Instale runtime/music_worker/requirements.txt no ambiente de build.'}
Copy-Item -LiteralPath $ffmpeg -Destination (Join-Path $stage 'ffmpeg.exe') -Force
Push-Location $stage
try {
  & $Python -m PyInstaller --noconfirm --clean --onedir --noupx --name dd_music_worker --distpath dist --workpath build --specpath . --add-binary 'ffmpeg.exe;.' --collect-data ytmusicapi --collect-submodules yt_dlp --exclude-module spotdl source/main.py
  if($LASTEXITCODE -ne 0){throw 'Falha na compilação do motor musical.'}
  # The bundled build Python enforces certificate distrust using this public
  # PEM beside ssl.py. Preserve that policy when freezing; do not patch TLS out.
  $ddRejectedCa= & $Python -c 'import ssl,pathlib; print(pathlib.Path(ssl.__file__).with_name("codex-rejected-cas.pem"))'
  if(Test-Path -LiteralPath $ddRejectedCa){
    Copy-Item -LiteralPath $ddRejectedCa -Destination 'dist\dd_music_worker\_internal\codex-rejected-cas.pem' -Force
  }
  $target=Join-Path $workspace 'dist\DefinitiveDownloader\music_engine'
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  & robocopy 'dist\dd_music_worker' $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
  if($LASTEXITCODE -ge 8){throw 'Falha ao publicar o motor local.'}
  Copy-Item -LiteralPath (Join-Path $workspace 'runtime\music_worker\requirements.txt') -Destination $target -Force
  Write-Output "Motor gerado: $(Join-Path $target 'dd_music_worker.exe')"
} finally {Pop-Location}
