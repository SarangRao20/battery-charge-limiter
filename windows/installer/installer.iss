#define MyAppName "Battery Charge Limiter"
#define MyAppVersion "1.2.0"
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
WizardImageFile=theme\wizard.png
WizardSmallImageFile=theme\small.png
UninstallDisplayIcon={app}\app.ico
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\icons\app.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\app\publish\BatteryCapApp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\drivers\EC-Access-Tool.exe"; DestDir: "{app}"
Source: "..\drivers\WinRing0x64.sys"; DestDir: "{app}"
Source: "..\daemon.ps1"; DestDir: "{app}"
Source: "..\icons\*.ico"; DestDir: "{app}"
Source: "postinstall.ps1"; DestDir: "{app}"
Source: "uninstall.ps1"; DestDir: "{app}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File {app}\postinstall.ps1"; StatusMsg: "Installing driver and registering scheduled task..."; Flags: runhidden waituntilterminated
Filename: "{app}\BatteryCapApp.exe"; Description: "Launch Battery Charge Limiter"; Flags: nowait postinstall

[Icons]
Name: "{autoprograms}\Battery Charge Limiter"; Filename: "{app}\BatteryCapApp.exe"; IconFilename: "{app}\app.ico"; Comment: "Battery charge limiter dashboard"
Name: "{autodesktop}\Battery Charge Limiter"; Filename: "{app}\BatteryCapApp.exe"; IconFilename: "{app}\app.ico"; Comment: "Battery charge limiter dashboard"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File {app}\uninstall.ps1"; Flags: runhidden waituntilterminated; RunOnceId: "UninstallCleanup"

[Code]
function IsDotNet8Installed(): Boolean;
begin
  Result := DirExists(ExpandConstant('{autopf64}\dotnet\shared\Microsoft.WindowsDesktop.App')) or
            DirExists(ExpandConstant('{autopf}\dotnet\shared\Microsoft.WindowsDesktop.App'));
end;

procedure InitializeWizard();
begin
  if not IsDotNet8Installed() then begin
    MsgBox('BatteryCapApp requires .NET 8 Desktop Runtime, which was not found.' + #13#10 +
           'Please install it from: https://dotnet.microsoft.com/download/dotnet/8.0' + #13#10 + #13#10 +
           'The core battery limiter (daemon) will still work without it.', mbInformation, MB_OK);
  end;
end;
