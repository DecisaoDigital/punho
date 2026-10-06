; ================================================================
; Fist — Script Inno Setup
; ================================================================
; Gera Fist_Setup_vX.Y.Z.exe a partir de build\windows\x64\runner\Release\
; Paths relativos ao próprio .iss (runner GitHub Actions ou local).

#ifndef MyAppVersion
  #define MyAppVersion "0.0.1"
#endif

[Setup]
AppName=Fist
AppVersion={#MyAppVersion}
AppPublisher=Decisão Digital
AppPublisherURL=https://decisaodigital.pt
DefaultDirName={autopf}\Fist
DefaultGroupName=Fist
OutputDir=..\installer_output
OutputBaseFilename=Fist_Setup_v{#MyAppVersion}
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany=Decisão Digital
VersionInfoProductName=Fist
VersionInfoDescription=Fist — gestão operacional para empresas
VersionInfoCopyright=Copyright (C) 2026 Decisão Digital. Todos os direitos reservados.
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
MinVersion=10.0
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\fist.exe
UninstallDisplayName=Fist
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar ícone no Ambiente de Trabalho"; GroupDescription: "Atalhos:"
Name: "startmenuicon"; Description: "Criar atalho no Menu Iniciar"; GroupDescription: "Atalhos:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
Name: "{commonappdata}\Fist"; Permissions: everyone-full

[Icons]
Name: "{autodesktop}\Fist"; Filename: "{app}\fist.exe"; Tasks: desktopicon
Name: "{group}\Fist"; Filename: "{app}\fist.exe"; Tasks: startmenuicon

[Run]
Filename: "{app}\fist.exe"; Description: "Iniciar Fist"; Flags: nowait postinstall skipifsilent
