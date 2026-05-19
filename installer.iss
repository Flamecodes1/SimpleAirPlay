; Simple AirPlay - Inno Setup Installer v4.5

; App Metadata
#define AppName      "Simple AirPlay"
#define AppVersion   "4.5"
#define AppPublisher "Simple AirPlay"
#define AppURL       "https://github.com/FDH2/UxPlay"
#define AppExeName   "SimpleAirPlay.vbs"

; Source Paths
#define SrcRoot      "c:\Users\fritz\airplay\UxPlay\SimpleAirPlayApp"
#define EngineRoot   "C:\Program Files (x86)\uxplay-windows\_internal"

[Setup]
AppId={{9CE8E981-8EB9-477A-BD58-7E3E4D6ADB54}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.\InstallerOutput
OutputBaseFilename=Simple_AirPlay_Setup_v{#AppVersion}
Compression=lzma2/ultra64
InternalCompressLevel=ultra
SolidCompression=yes
WizardStyle=modern
SetupIconFile=app_icon.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Mit Windows starten"; GroupDescription: "Zusätzliche Optionen:"; Flags: unchecked

[Files]
; App Scripts
Source: "{#SrcRoot}\SimpleAirPlay.ps1";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcRoot}\SimpleAirPlay.vbs";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcRoot}\SimpleAirPlay.bat";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SrcRoot}\app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
; UxPlay Engine + GStreamer
Source: "{#EngineRoot}\*"; DestDir: "{app}\engine"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bonjour Dependency
Source: "{#SrcRoot}\BonjourPSSetup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
; wscript.exe is required because VBS files cannot be launched via CreateProcess directly
Name: "{group}\{#AppName}";       Filename: "wscript.exe"; Parameters: """{app}\{#AppExeName}"""; IconFilename: "{app}\app_icon.ico"
Name: "{autodesktop}\{#AppName}"; Filename: "wscript.exe"; Parameters: """{app}\{#AppExeName}"""; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "wscript.exe"; Parameters: """{app}\{#AppExeName}"""; IconFilename: "{app}\app_icon.ico"; Tasks: autostart

[Run]
; Silent VCRedist install if needed
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: VCRedistNeedsInstall; StatusMsg: "Installiere Visual C++ Redistributable..."
; Silent Bonjour install if not present
Filename: "{tmp}\BonjourPSSetup.exe"; Parameters: "/s /v""/qn"""; Check: NeedsBonjour; StatusMsg: "Konfiguriere AirPlay-Dienste (Bonjour)..."
; Start Bonjour service (in case it was stopped)
Filename: "net"; Parameters: "start ""Bonjour Service"""; Flags: runhidden nowait; StatusMsg: "Starte Bonjour-Dienst..."

; Bulletproof Firewall Rules (Fixed Ports + Bonjour)
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Simple AirPlay (App)"" dir=in action=allow program=""{app}\engine\bin\uxplay.exe"" enable=yes profile=any"; Flags: runhidden; StatusMsg: "Konfiguriere Windows-Firewall (1/4)..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Simple AirPlay (mDNS)"" dir=in action=allow protocol=UDP localport=5353 enable=yes profile=any"; Flags: runhidden; StatusMsg: "Konfiguriere Windows-Firewall (2/4)..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Simple AirPlay (TCP)"" dir=in action=allow protocol=TCP localport=7000,7001,7100 enable=yes profile=any"; Flags: runhidden; StatusMsg: "Konfiguriere Windows-Firewall (3/4)..."
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""Simple AirPlay (UDP)"" dir=in action=allow protocol=UDP localport=6000,6001,7011 enable=yes profile=any"; Flags: runhidden; StatusMsg: "Konfiguriere Windows-Firewall (4/4)..."

; Launch after install
Filename: "wscript.exe"; Parameters: """{app}\{#AppExeName}"""; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Clean up firewall rules on uninstall
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Simple AirPlay (App)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Simple AirPlay (mDNS)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Simple AirPlay (TCP)"""; Flags: runhidden
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""Simple AirPlay (UDP)"""; Flags: runhidden

[Code]
function NeedsBonjour(): Boolean;
begin
  Result := not (
    RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\Apple Inc.\Bonjour') or
    RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Apple Inc.\Bonjour')
  );
end;

function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    Result := False;
  end
  else
  begin
    Result := True;
  end;
end;

var
  DownloadPage: TDownloadWizardPage;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Successfully downloaded file to {tmp}: %s', [FileName]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), @OnDownloadProgress);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if (CurPageID = wpReady) and VCRedistNeedsInstall then
  begin
    DownloadPage.Clear;
    DownloadPage.Add('https://aka.ms/vs/17/release/vc_redist.x64.exe', 'vc_redist.x64.exe', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
        Result := True;
      except
        if DownloadPage.AbortedByUser then
          Log('Aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end else
    Result := True;
end;

// Try to run an uninstaller silently, returns True if executed
function RunUninstaller(UninstallStr: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if UninstallStr = '' then Exit;
  // Inno Setup uninstallers support /SILENT and /VERYSILENT
  if Pos('/SILENT', Uppercase(UninstallStr)) = 0 then
    UninstallStr := UninstallStr + ' /VERYSILENT /NORESTART /SUPPRESSMSGBOXES';
  Exec('>', UninstallStr, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;

// Scan a registry uninstall branch for old AirPlay-related apps
procedure CleanBranch(RootKey: Integer; const SubKey: String);
var
  Names: TArrayOfString;
  I: Integer;
  DisplayName, UninstallStr, KeyPath: String;
  NameUpper: String;
begin
  if not RegGetSubkeyNames(RootKey, SubKey, Names) then Exit;
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    KeyPath := SubKey + '\' + Names[I];
    if RegQueryStringValue(RootKey, KeyPath, 'DisplayName', DisplayName) then
    begin
      NameUpper := Uppercase(DisplayName);
      // Match any old AirPlay receiver (but skip Bonjour and our current install)
      if ((Pos('UXPLAY', NameUpper) > 0) or
          (Pos('VIBEPLAY', NameUpper) > 0) or
          (Pos('AIRPLAY', NameUpper) > 0)) and
         (Pos('BONJOUR', NameUpper) = 0) then
      begin
        if RegQueryStringValue(RootKey, KeyPath, 'UninstallString', UninstallStr) then
          RunUninstaller(UninstallStr);
      end;
    end;
  end;
end;

// Kill any running uxplay processes before cleanup
procedure KillUxPlay();
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/F /IM uxplay.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

// Delete leftover directories from old installations
procedure DeleteLeftovers();
begin
  DelTree(ExpandConstant('{autopf}\VibePlay AirPlay'), True, True, True);
  DelTree(ExpandConstant('{autopf}\VibePlay'), True, True, True);
  DelTree(ExpandConstant('{autopf}\UxPlay'), True, True, True);
end;

// Called by Inno Setup before installation begins
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  KillUxPlay();
  // Scan both 64-bit and 32-bit uninstall registry branches
  CleanBranch(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall');
  CleanBranch(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall');
  CleanBranch(HKEY_CURRENT_USER,  'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall');
  DeleteLeftovers();
end;

[Messages]
german.WelcomeLabel1=Simple AirPlay - Jetzt alles automatisch!
german.WelcomeLabel2=Dieses Setup installiert Simple AirPlay und konfiguriert alle notwendigen Dienste automatisch fuer dich.
german.FinishedLabel=Simple AirPlay wurde erfolgreich installiert! Dein PC ist jetzt bereit fuer AirPlay.
