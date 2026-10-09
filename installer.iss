; Inno Setup Script — Catálogo Direct Evolution Bypass Installer
; Compilar: ISCC.exe installer.iss
; Resultado: Output\CatalogoBypass_Setup.exe

#define AppName    "Catalogo Direct Evolution Bypass"
#define AppVersion "1.0.0"
#define AppPublisher "Macolly Barbosa"
#define AppDir     "{pf}\CatalogoExpressoBypass"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppId={{B7A1C2D3-4E5F-6789-ABCD-EF0123456789}}
DefaultDirName={#AppDir}
DefaultGroupName=Catálogo Bypass
OutputDir=Output
OutputBaseFilename=CatalogoBypass_Setup
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
; UAC dialog
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile=
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\server_icon.ico
WizardStyle=modern
DisableProgramGroupPage=yes
DisableDirPage=yes

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "server.py";      DestDir: "{app}"; Flags: ignoreversion
Source: "service.py";     DestDir: "{app}"; Flags: ignoreversion
Source: "setup.ps1";      DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall.ps1";  DestDir: "{app}"; Flags: ignoreversion
Source: "start.bat";       DestDir: "{app}"; Flags: ignoreversion
Source: "autocadastro.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md";       DestDir: "{app}"; Flags: ignoreversion

[Run]
; Executa setup.ps1 (que instala pywin32, servico, hosts)
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\setup.ps1"""; \
    StatusMsg: "Configurando bypass (aguarde, pode demorar se Python precisar ser instalado)..."; \
    Flags: waituntilterminated

[UninstallRun]
; Executa uninstall.ps1
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"""; \
    Flags: runhidden waituntilterminated

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    MsgBox('Instalação concluída!' + #13#10 + #13#10 +
           'O serviço CatalogoExpressoBypass está ativo.' + #13#10 +
           'O Catálogo pode ser aberto normalmente.', mbInformation, MB_OK);
  end;
end;
