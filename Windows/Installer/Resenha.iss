#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#define AppPublisher "Luis Roquette"
#define AppExeName "Resenha.exe"
#ifdef SmokeUnsigned
  #define InstallerBaseName "Resenha-" + AppVersion + "-windows-x64-UNSIGNED-NOT-FOR-DISTRIBUTION"
#else
  #ifdef BetaUnsigned
    #define InstallerBaseName "Resenha-" + AppVersion + "-windows-x64-BETA-UNSIGNED"
  #else
    #define InstallerBaseName "Resenha-" + AppVersion + "-windows-x64-setup"
  #endif
#endif

[Setup]
AppId={{A83D31F2-02BC-4F04-A101-7120B87F8E38}
AppName=Resenha
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/luisroquette/resenha
AppSupportURL=https://github.com/luisroquette/resenha/issues
AppUpdatesURL=https://github.com/luisroquette/resenha/releases
DefaultDirName={localappdata}\Programs\Resenha
DefaultGroupName=Resenha
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19045
OutputDir={#OutputDir}
OutputBaseFilename={#InstallerBaseName}
#ifdef SmokeUnsigned
Compression=zip/1
SolidCompression=no
#else
Compression=lzma2/max
SolidCompression=yes
#endif
WizardStyle=modern
SetupIconFile={#SourcePath}\..\Resenha.Windows\Assets\Resenha.ico
UninstallDisplayIcon={app}\Resenha.exe
LicenseFile={#SourcePath}\LICENSES.txt
CloseApplications=yes
CloseApplicationsFilter=Resenha.exe,Resenha.TargetBroker.exe,whisper-cli.exe
RestartApplications=no
RestartIfNeededByRun=no
CreateUninstallRegKey=yes
Uninstallable=yes
#ifdef SmokeUnsigned
SignedUninstaller=no
#else
  #ifdef BetaUnsigned
SignedUninstaller=no
  #else
SignedUninstaller=yes
SignTool=resenha
SignToolRetryCount=2
SignToolRunMinimized=yes
  #endif
#endif
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=Resenha — ditado local para Windows
VersionInfoProductName=Resenha
VersionInfoProductVersion={#AppVersion}
VersionInfoCopyright=Copyright (c) 2026 Luis Roquette

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Resenha"; Filename: "{app}\Resenha.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\Resenha.exe"; Description: "Abrir o Resenha"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Resenha\sessions"

[Code]
var
  RemoveLocalData: Boolean;

function InitializeUninstall(): Boolean;
begin
  if UninstallSilent then
    RemoveLocalData := True
  else
    RemoveLocalData := MsgBox(
      'Remover também o modelo local e as preferências deste usuário?'#13#10#13#10 +
      '“Sim” é a opção recomendada. Arquivos importados de outras pastas e documentos pessoais não serão removidos.',
      mbConfirmation, MB_YESNO) = IDYES;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataRoot: String;
begin
  if CurUninstallStep = usPostUninstall then begin
    DataRoot := ExpandConstant('{localappdata}\Resenha');
    DelTree(DataRoot + '\sessions', True, True, True);
    if RemoveLocalData then begin
      DelTree(DataRoot + '\models', True, True, True);
      DeleteFile(DataRoot + '\settings.json');
      RemoveDir(DataRoot);
    end;
  end;
end;
