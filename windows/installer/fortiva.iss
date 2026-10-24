; The Fortiva VPN installer for Windows. Needs Inno Setup 6.3 or later.
;
; .github/workflows/windows-release.yml builds it and passes what to pack:
;
;   iscc /DAppVersion=1.6.14 /DAppDir=<build\windows\x64\runner\Release>
;        /DCoreDir=<windows\core\dist> /DCrtDir=<the VC++ runtime DLLs>
;        /DOutDir=<where the setup .exe goes> windows\installer\fortiva.iss
;
; The app is only the window. The tunnel is the FortivaTunnel service in
; fortiva-core.exe (windows/core), which the app reaches over a named pipe,
; so besides copying files setup has three jobs, each one a fortiva-core
; command:
;   - before replacing files, `stop`, so the running service lets go of
;     them. An upgrade drops the tunnel; the user connects again after.
;   - after copying, `install`, which registers the service, or brings an
;     existing registration up to date, and starts it.
;   - on uninstall, `uninstall`, which stops the service and deletes it.

#if VER < EncodeVer(6, 3, 0)
  #error Inno Setup 6.3 or later is needed (ExecAndLogOutput, x64compatible)
#endif
#ifndef AppVersion
  #error Pass the app version: /DAppVersion=X.Y.Z
#endif
#ifndef AppDir
  #error Pass the Flutter release folder: /DAppDir=...
#endif
#ifndef CoreDir
  #error Pass windows\core\dist, with windows-amd64 and windows-arm64 built: /DCoreDir=...
#endif
#ifndef CrtDir
  #error Pass the folder holding msvcp140.dll, vcruntime140.dll and vcruntime140_1.dll: /DCrtDir=...
#endif
#ifndef OutDir
  #define OutDir "Output"
#endif

[Setup]
; Never change AppId: Windows finds the installed copy by it, for upgrades
; and for the uninstaller. The doubled brace is how Inno writes one.
AppId={{3056C354-A32A-4525-A7D6-FFA2E7A10C62}
AppName=Fortiva VPN
AppVersion={#AppVersion}
AppPublisher=NimusAI
AppPublisherURL=https://fortivavpn.com
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\Fortiva VPN
DisableProgramGroupPage=yes
; Registering a service takes an administrator, so setup always asks.
PrivilegesRequired=admin
; x64 Windows, and Windows 11 on Arm, which runs the x64 app under
; emulation. The service there is the arm64 build, see [Files].
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Go and Flutter both need Windows 10.
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Fortiva.exe
OutputDir={#OutDir}
OutputBaseFilename=FortivaVPN-{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
; An open app window holds its files; setup offers to close it. Setup
; starts the app itself at the end, so Windows does not restart it.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; The app: Fortiva.exe, the Flutter engine, the plugins and data\. The jni
; plugin, which path_provider_android pulls in, adds dartjni.dll when the
; build machine has a JDK; nothing on Windows loads it.
Source: "{#AppDir}\*"; Excludes: "dartjni.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; The Visual C++ runtime the app is built against, next to it, as Flutter's
; Windows release guide asks, so the PC needs no redistributable.
Source: "{#CrtDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CrtDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
; The service and Wintun, native to the PC: Windows on Arm gets the arm64
; build, which also loads the arm64 driver, instead of an emulated one.
Source: "{#CoreDir}\windows-amd64\fortiva-core.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#CoreDir}\windows-amd64\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsArm64
Source: "{#CoreDir}\windows-arm64\fortiva-core.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
Source: "{#CoreDir}\windows-arm64\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion; Check: IsArm64
; Routing data and Wintun's notice, the same for both.
Source: "{#CoreDir}\windows-amd64\geoip.dat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CoreDir}\windows-amd64\geosite.dat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#CoreDir}\windows-amd64\wintun-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Fortiva VPN"; Filename: "{app}\Fortiva.exe"
Name: "{autodesktop}\Fortiva VPN"; Filename: "{app}\Fortiva.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Fortiva.exe"; Description: "{cm:LaunchProgram,Fortiva VPN}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; The window first, so nothing holds the files, then the service.
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im Fortiva.exe"; Flags: runhidden; RunOnceId: "CloseApp"
Filename: "{app}\fortiva-core.exe"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveService"

[Code]
var
  CoreOutput: String;

procedure CollectCoreOutput(const S: String; const Error, FirstLine: Boolean);
begin
  Log('fortiva-core: ' + S);
  CoreOutput := CoreOutput + S + #13#10;
end;

{ Runs the installed fortiva-core with Command and logs what it prints.
  True when it ran and exited 0; what it printed is left in CoreOutput. }
function RunCore(const Command: String): Boolean;
var
  ResultCode: Integer;
begin
  CoreOutput := '';
  try
    Result := ExecAndLogOutput(ExpandConstant('{app}\fortiva-core.exe'), Command,
      ExpandConstant('{app}'), SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode,
      @CollectCoreOutput) and (ResultCode = 0);
    if not Result then
      Log(Format('fortiva-core %s failed with code %d', [Command, ResultCode]));
  except
    Log(GetExceptionMessage);
    Result := False;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  { An upgrade: the running service holds fortiva-core.exe and wintun.dll
    open. Setup calls this before it checks for files in use. }
  if FileExists(ExpandConstant('{app}\fortiva-core.exe')) then
    RunCore('stop');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    Exit;
  WizardForm.StatusLabel.Caption := 'Starting the Fortiva tunnel service...';
  { Stop first in case the registered service runs a copy somewhere else,
    which `install` would repoint but leave running. Nothing installed or
    nothing running is not an error. }
  RunCore('stop');
  if not RunCore('install') then
    SuppressibleMsgBox('Fortiva VPN is installed, but its tunnel service did not start, ' +
      'so the app cannot connect yet.' + #13#10#13#10 + Trim(CoreOutput) + #13#10#13#10 +
      'Restart Windows and run setup again. If it still fails, send this message to support.',
      mbError, MB_OK, IDOK);
end;
