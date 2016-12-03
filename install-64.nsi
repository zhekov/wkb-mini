Name "WKB Layout"
OutFile "wkb-install-1.07-x64.exe"
RequestExecutionLevel admin
CRCCheck force
XPStyle on

InstallDir "$PROGRAMFILES64\wkb-mini"

!macro installWkbFiles
	File "wkb-mini.exe"
	File "wkb-hook.dll"
	File "wkb-mwow.exe"
	File "wkb-hk32.dll"
	File "settings.exe"
	File "ReadMe.txt"
!macroend

!include x64.nsh
!include WinVer.nsh

Function .onInit
	${IfNot} ${RunningX64}
		MessageBox MB_ICONSTOP|MB_OK "You are trying to install the 64-bit \
			version of WKB on a 32-bit system. That will not work."
		Quit
	${EndIf}
FunctionEnd

!include install-inc.nsh
