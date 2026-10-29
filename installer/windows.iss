#ifndef AppVersion
  #error AppVersion must be supplied by the build script
#endif
#ifndef PackageDir
  #error PackageDir must be supplied by the build script
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by the build script
#endif

[Setup]
AppId={{C3BE3755-786D-4F55-9282-C58896FB6D7C}
AppName=Definitive Downloader
AppVersion={#AppVersion}
AppPublisher=Definitive Downloader
DefaultDirName={localappdata}\Programs\Definitive Downloader
DefaultGroupName=Definitive Downloader
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=Definitive-Downloader-{#AppVersion}-Setup-Windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\definitive_downloader.exe
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na área de trabalho"; Flags: unchecked

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Definitive Downloader"; Filename: "{app}\definitive_downloader.exe"; WorkingDir: "{app}"; IconFilename: "{app}\data\flutter_assets\assets\brand\dd-app-icon.ico"
Name: "{autodesktop}\Definitive Downloader"; Filename: "{app}\definitive_downloader.exe"; WorkingDir: "{app}"; IconFilename: "{app}\data\flutter_assets\assets\brand\dd-app-icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\definitive_downloader.exe"; Description: "Abrir o Definitive Downloader"; Flags: nowait postinstall skipifsilent
