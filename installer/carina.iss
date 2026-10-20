; Carina installer script for Inno Setup 6.3 or newer.
;
; Build from the repository root after `flutter build windows --release`:
;   iscc /DMyAppVersion=1.0.0 installer\carina.iss
; Output: dist\Carina-Setup-<version>-x64.exe
;
; Per-user install: no administrator rights, installs to
; %LOCALAPPDATA%\Programs\Carina, shortcuts go to the user's Start menu/desktop.

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

#define MyAppName "Carina"
#define MyAppPublisher "Carina"
#define MyAppExeName "carina.exe"
; Must stay identical to the id the app sets at startup
; (windows/runner/main.cpp) and registers for toast notifications.
#define MyAppUserModelID "Carina.Carina"

[Setup]
; AppId identifies the installation for upgrades and uninstall. Never change it.
AppId={{45CF6915-952D-41BC-9EBE-F6B4918BFA7A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright=Copyright (C) 2026 Carina
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
; Paths below are relative to the repository root.
SourceDir=..
OutputDir=dist
OutputBaseFilename=Carina-Setup-{#MyAppVersion}-x64
SetupIconFile=windows\runner\resources\app_icon.ico
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Carina
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Drop the previous version's Flutter assets so removed files do not linger.
Type: filesandordirs; Name: "{app}\data\flutter_assets"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; AppUserModelID: "{#MyAppUserModelID}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; AppUserModelID: "{#MyAppUserModelID}"; Tasks: desktopicon

[Registry]
; Display name and icon Windows shows on Carina's toast notifications.
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\{#MyAppUserModelID}"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\AppUserModelId\{#MyAppUserModelID}"; ValueType: string; ValueName: "IconUri"; ValueData: "{app}\data\flutter_assets\assets\brand\carina_icon_1024.png"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
