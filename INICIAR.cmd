@echo off
setlocal
if not exist "%~dp0dist\DefinitiveDownloader\definitive_downloader.exe" (
  echo Compile primeiro com tools\build_windows.ps1
  pause
  exit /b 1
)
rem Native worker DLLs failed when started by Flutter from the network share.
rem Run the complete package locally; user data and account vault stay separate.
set "DdPackage=%~dp0dist\DefinitiveDownloader"
set "DdLocalApp=%LOCALAPPDATA%\DefinitiveDownloader\app"
if not defined LOCALAPPDATA (
  echo Nao foi possivel localizar a pasta local do Windows.
  pause
  exit /b 1
)
robocopy "%DdPackage%" "%DdLocalApp%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo Nao foi possivel atualizar o D.d local. Feche o aplicativo e tente novamente.
  pause
  exit /b 1
)
start "Definitive Downloader" /D "%DdLocalApp%" "%DdLocalApp%\definitive_downloader.exe"
