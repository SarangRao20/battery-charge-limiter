#define MyAppName "Battery Charge Limiter"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "SarangRao20"

[Setup]
AppId={{7B1E4A2C-6B3D-4F2E-9A1C-8D5E7F3B2A1C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName=C:\EC-Tool
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputBaseFilename=BatteryCapSetup
OutputDir=..\..\dist
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\green.ico
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\drivers\EC-Access-Tool.exe"; DestDir: "{app}"
Source: "..\drivers\WinRing0x64.sys"; DestDir: "{app}"
Source: "..\daemon.ps1"; DestDir: "{app}"
Source: "..\icons\*.ico"; DestDir: "{app}"
Source: "postinstall.ps1"; DestDir: "{app}"
Source: "uninstall.ps1"; DestDir: "{app}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\postinstall.ps1"""; StatusMsg: "Installing driver and registering scheduled task..."; Flags: runhidden waituntilterminated

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "UninstallCleanup"
