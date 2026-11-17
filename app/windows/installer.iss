; The Windows installer, built by CI with Inno Setup. For one user, so it needs no administrator
; rights, which also means no scary prompt. Version and output folder come from the command line.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef Output
  #define Output "."
#endif
#ifndef Source
  #define Source "..\build\windows\x64\runner\Release"
#endif

[Setup]
; Never change this once released: it's how Windows knows a new version replaces an old one. Kept
; from when the app was called ShiftDrop, so Arcvert replaces it rather than sitting beside it.
AppId={{6E0C9A0E-5B1F-4C6B-9D26-3F6B7A2C1E44}
AppName=Arcvert
AppVersion={#AppVersion}
AppPublisher=Arcvert contributors
AppPublisherURL=https://github.com/Navin-kumar0007/arcvert
DefaultDirName={autopf}\Arcvert
DefaultGroupName=Arcvert
; Not the old ShiftDrop folder Windows remembers for this AppId: [InstallDelete] removes that.
UsePreviousAppDir=no
UsePreviousGroup=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Output}
OutputBaseFilename=Arcvert-{#AppVersion}-windows-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\arcvert.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=force

[InstallDelete]
; What ShiftDrop, this app's name before 0.16, left: its program folder and shortcuts.
Type: filesandordirs; Name: "{autopf}\ShiftDrop"
Type: filesandordirs; Name: "{autoprograms}\ShiftDrop"
Type: files; Name: "{autodesktop}\ShiftDrop.lnk"

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Arcvert"; Filename: "{app}\arcvert.exe"
Name: "{autodesktop}\Arcvert"; Filename: "{app}\arcvert.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Add a desktop shortcut"; Flags: unchecked

[Registry]
; Created by the app's "Open at login" switch, not here. Uninstalling removes it.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "Arcvert"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\arcvert.exe"; Description: "Open Arcvert"; Flags: nowait postinstall skipifsilent

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';

// A ShiftDrop still running holds its files, so it is closed before they are removed.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM shiftdrop.exe', '', SW_HIDE,
    ewWaitUntilTerminated, Code);
  Result := '';
end;

// "Open at login" chosen under the old name carries on under the new one.
procedure CurStepChanged(CurStep: TSetupStep);
var
  Old: String;
begin
  if (CurStep = ssPostInstall) and RegQueryStringValue(HKCU, RunKey, 'ShiftDrop', Old) then
  begin
    RegDeleteValue(HKCU, RunKey, 'ShiftDrop');
    RegWriteStringValue(HKCU, RunKey, 'Arcvert',
      '"' + ExpandConstant('{app}\arcvert.exe') + '" --hidden');
  end;
end;
