; Cloudify installer, by weepingcloud
#define AppName "Cloudify"
#define AppVersion "0.17.0"
#define Publisher "weepingcloud"

[Setup]
AppId={{6B8F6D1E-4C0E-4F5A-9A57-3C1D0C10D0A1}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=Cloudify-Setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\cloud-music.exe
WizardStyle=modern
CloseApplications=yes
RestartApplications=yes
SetupIconFile=..\assets\cloud-music.ico

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\stage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\NOTICE.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\fonts\GoogleSansFlex-OFL.txt"; DestDir: "{app}\fonts"; Flags: ignoreversion
Source: "..\fonts\MaterialIcons-LICENSE.txt"; DestDir: "{app}\fonts"; Flags: ignoreversion

[Registry]
; run on the power-saving (integrated) GPU: on laptops with two GPUs the cursor stutters when a
; light app is drawn on the discrete one and copied across. Windows Settings > Graphics shows it.
Root: HKCU; Subkey: "Software\Microsoft\DirectX\UserGpuPreferences"; ValueType: string; ValueName: "{app}\cloud-music.exe"; ValueData: "GpuPreference=1;"; Flags: uninsdeletevalue

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\cloud-music.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\cloud-music.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cloud-music.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Cloud Music\cache"
