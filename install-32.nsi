Name "WKB Layout"
OutFile "wkb-install-1.07-x86.exe"
RequestExecutionLevel admin
CRCCheck force
XPStyle on

InstallDir "$PROGRAMFILES32\wkb-mini"

!macro installWkbFiles
	File "wkb-mini.exe"
	File "wkb-hook.dll"
	File "settings.exe"
	File "ReadMe.txt"
!macroend

!include x64.nsh
!include WinVer.nsh

Function .onInit
	${If} ${RunningX64}
		MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "You are trying to install the 32-bit \
			version of WKB on a 64-bit system. That will work for the 32-bit processes only. \
			It would be better to install the 64-bit version.$\n$\n\
			Proceed anyway?" IDYES +2
		Quit
	${ElseIfNot} ${AtLeastWin2000}
		MessageBox MB_ICONSTOP|MB_OK "WKB Layout requires Windows 2000 or later."
		Quit
	${EndIf}
FunctionEnd

!include install-inc.nsh
