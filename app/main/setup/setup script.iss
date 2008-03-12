[Setup]
AppName=Open Source Census
AppVerName=Open Source Census Discovery Client 2.0
AppVersion=2.0
AppPublisherURL={cm:CensusURL}
DefaultDirName={pf}\OSS Discovery
AllowUNCPath=false
OutputBaseFilename=OSS Discovery Setup
PrivilegesRequired=none
UsePreviousAppDir=false
WizardSmallImageFile=census-small.bmp
WizardImageFile=census.bmp
DisableProgramGroupPage=yes
DisableReadyPage=yes
DefaultGroupName=OSS Discovery
UninstallDisplayIcon={app}\oss_census.ico
UsePreviousGroup=false
OutputDir=..\pkg

[CustomMessages]
CensusURL=https://www.osscensus.org
CensusRegisterURL=%1/app/index.php?do=register
WhatIsCensusCodeResponse=The Census Code identifies you as a Census participant, allowing you to view Census reports and personalized inventory reports in addition to the freely available public reports.%n%nIf you have already registered, access your 'My Account' page on the OSS Census site to retrieve your Census Code.%nIf you have not registered, you'll need to before you can continue. Registration is free.%n%nWould you like to register and obtain a Census Code now?
WhatIsCensusCode=What is a Census Code?
CensusCodeEmptyError=You must enter a Census Code.%n%nWould you like to register and obtain a Census Code now?
FinishMessage=Thank you for participating in the open source census. The OSSDiscovery scanner client can be started again at any time by clicking on Start > All Programs > OSS Discovery > Scan Machine for Open Source, or by double-clicking the icon on your desktop.

[Messages]
WelcomeLabel2=This will install [name/ver] on your computer.%n%nUsing it, you will be able to scan your system for open source software and submit the results to the Open Source Census.

[Files]
Source: "..\lib\*"; DestDir: {app}\lib\; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\license\*"; DestDir: {app}\license\; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\log\*"; DestDir: {app}\log\; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\doc\*"; DestDir: {app}\doc\; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\jruby\*"; DestDir: {app}\jruby\; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\jre\jre-1.5.0_07-windows-ia32\*"; DestDir: {app}\jre\jre-1.5.0_07-windows-ia32; Excludes: ".svn"; Flags: recursesubdirs createallsubdirs
Source: "..\README.txt"; DestDir: {app};
Source: "..\setup\oss_census.ico"; DestDir: {app};
Source: "..\discovery_jre_windows.bat"; DestDir: {app}; DestName: "discovery.bat";
Source: "..\DiscoveryWinWrapper.bat"; DestDir: {app};

[Icons]
Name: {group}\Scan Machine For Open Source; Filename: {app}\DiscoveryWinWrapper.bat; Parameters: --census-code {code:GetCode|Name} --deliver-results; WorkingDir: {app}; IconFilename: {app}\oss_census.ico; Flags: dontcloseonexit
Name: {userdesktop}\Scan For Open Source; Filename: {app}\DiscoveryWinWrapper.bat; Parameters: --census-code {code:GetCode|Name} --deliver-results; WorkingDir: {app}; IconFilename: {app}\oss_census.ico;
Name: {group}\Uninstall OSS Census; Filename: {uninstallexe};

[Run]
Filename: {app}\DiscoveryWinWrapper.bat; Parameters: --census-code {code:GetCode|Name} --deliver-results; Description: Scan Machine For Open Source; Flags: postinstall

[Code]
procedure ButtonOnClick(Sender: TObject);
var
	ErrorCode: Integer;
begin
  if MsgBox(CustomMessage('WhatIsCensusCodeResponse'), mbConfirmation, MB_YESNO) = IDYES then
  begin
        ShellExec('open', FmtMessage(CustomMessage('CensusRegisterURL'), [CustomMessage('CensusURL')]), '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
  end;
end;

procedure URLLabelOnClick(Sender: TObject);
var
  ErrorCode: Integer;
begin
  ShellExec('open', CustomMessage('CensusURL'), '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;

var
  CensusCodePage: TInputQueryWizardPage;
  Button: TButton;
  URLLabel: TNewStaticText;
  CancelButton: TButton;
procedure InitializeWizard;
begin
  { Create the pages }

  CensusCodePage := CreateInputQueryPage(wpWelcome,
    'Census Code', 'What is your census code?',
    '');
  CensusCodePage.Add('Paste your Census Code here:', False);

  Button := TButton.Create(CensusCodePage);
  Button.Width := ScaleX(175);
  Button.Height := ScaleY(23);
  Button.Top := ScaleY(80);
  Button.Caption := CustomMessage('WhatIsCensusCode')
  Button.OnClick := @ButtonOnClick;
  Button.Parent := CensusCodePage.Surface;

  CancelButton := WizardForm.CancelButton;

  URLLabel := TNewStaticText.Create(WizardForm);
  URLLabel.Caption := CustomMessage('CensusURL')
  URLLabel.Cursor := crHand;
  URLLabel.OnClick := @URLLabelOnClick;
  URLLabel.Parent := WizardForm;
  { Alter Font *after* setting Parent so the correct defaults are inherited first }
  URLLabel.Font.Style := URLLabel.Font.Style + [fsUnderline];
  URLLabel.Font.Color := clBlue;
  URLLabel.Top := CancelButton.Top
  URLLabel.Left := ScaleX(20);

end;


function NextButtonClick(CurPageID: Integer): Boolean;
var
	ErrorCode: Integer;
begin
  { Validate certain pages before allowing the user to proceed }
  if CurPageID = CensusCodePage.ID then begin
    if CensusCodePage.Values[0] = '' then begin
      if MsgBox(CustomMessage('CensusCodeEmptyError'), mbConfirmation, MB_YESNO) = IDYES then
      begin
        ShellExec('open', FmtMessage(CustomMessage('CensusRegisterURL'), [CustomMessage('CensusURL')]), '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
      end;
      Result := False;
    end else begin
      Result := True;
    end;
  end else begin
    case CurPageID of
    wpFinished:
      MsgBox(CustomMessage('FinishMessage'), mbInformation, MB_OK);
    end;
    Result := True;
  end;
end;

function GetCode(Param: String): String;
begin
  { Return a user value }
  { Could also be split into separate GetUserName and GetUserCompany functions }
  Result := CensusCodePage.Values[0]
end;
