Caption "WKB Layout Settings"
OutFile settings.exe
RequestExecutionLevel user
CRCCheck force

XPStyle on
Icon "gucharmap.ico"
InstallButtonText "OK"
BrandingText " "

!include nsDialogs.nsh
!include LogicLib.nsh
!include nsArray.nsh
!include WinVer.nsh

Page custom wkbSettingsPage wkbSettingsPageLeave
Page instfiles

!include settings-inc.nsh

Function wkbSettingsPageLeave
	Call writeSettings
	Exec "wkb-mini.exe /wkb:apply"
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONSTOP "Failed to run the WKB executable."
	${EndIf}
	Quit
FunctionEnd

Section Install
SectionEnd
