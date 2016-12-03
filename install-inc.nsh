!include nsDialogs.nsh
!include LogicLib.nsh
!include FileFunc.nsh
!include nsArray.nsh
!include StrFunc.nsh
${StrStrAdv}

Var wkbInstall
Var previousDir
Var installDir
Var allUsers
Var runAfter

Page custom wkbInstallPage wkbInstallPageLeave
Page custom wkbSettingsPage wkbSettingsPageLeave
Page instfiles

Function browseClicked
	${NSD_GetText} $installDir $0
	IfFileExists "$0" +2
	StrCpy $0 "$PROGRAMFILES"
	nsDialogs::SelectFolderDialog "Installation Directory" "$0"
	Pop $0
	${If} $0 != "error"
		StrCpy $INSTDIR "$0"
		${NSD_SetText} $installDir "$INSTDIR"
	${EndIf}
FunctionEnd

!define uninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkb_mini"

Function getPreviousDir
	ReadRegStr $0 HKLM "${uninstallKey}" "UninstallString"
	${StrStrAdv} $1 $0 '\uninstal.exe"' < < 0 0 0
	${StrStrAdv} $previousDir $1 '"' > > 0 0 0
	${If} $previousDir != ""
		IfFileExists "$previousDir\uninstal.exe" +2
		StrCpy $previousDir ""
	${EndIf}
FunctionEnd

Function wkbInstallPage
	nsDialogs::Create 1018
	Pop $wkbInstall

	${NSD_CreateLabel} 0% 0 50% 8u "Installation directory:"
	${NSD_CreateFileRequest} 0% 9u 95% 12u ""
	Pop $installDir
	Call getPreviousDir
	${If} $previousDir == ""
		${NSD_SetText} $installDir "$INSTDIR"
	${Else}
		${NSD_SetText} $installDir "$previousDir"
	${EndIf}
	${NSD_CreateBrowseButton} 95% 9u 5% 12u "..."
	Pop $0
	${NSD_OnClick} $0 browseClicked

	${NSD_CreateCheckBox} 0% 32u 31% 12u "Install for all users"
	Pop $allUsers
	${NSD_Check} $allUsers
	${NSD_CreateCheckBox} 50% 32u 31% 12u "Run after installation"
	Pop $runAfter
	${NSD_Check} $runAfter

	${NSD_CreateHLine} 0 55u 100% 1u
	Pop $0
	${NSD_AddStyle} $0 ${WS_GROUP}
	${NSD_CreateLabel} 2% 61u 96% 24u "You can redistribute and/or \
		modify this program under the terms of the GNU General \
		Public License as published by the Free Software \
		Foundation; either version 2 of the License, or (at your \
		option) any later version."
	${NSD_CreateLabel} 2% 89u 96% 24u "This program is distributed in \
		the hope that it will be useful, but WITHOUT ANY WARRANTY; \
		without even the implied warranty of MERCHANTABILITY or \
		FITNESS FOR A PARTICULAR PURPOSE."
	${NSD_CreateLabel} 2% 117u 96% 12u "WKB Layout version 1.07, \
		Copyright (C) 2016 Dimitar Toshkov Zhekov."

	nsDialogs::Show
FunctionEnd

Function wkbInstallPageLeave
	${NSD_GetText} $installDir $INSTDIR
	Call getPreviousDir

	${If} $INSTDIR == ""
		MessageBox MB_ICONSTOP|MB_OK "The installation directory is required."
		Abort
	${ElseIf} $previousDir != ""
	${AndIf} $INSTDIR != $previousDir
		MessageBox MB_ICONSTOP|MB_OK 'WKB is already installed in "$previousDir"$\n$\n\
			Please uninstall it first, or install to the same directory.'
			${NSD_SetText} $installDir "$previousDir"
		Abort
	${EndIf}

	${NSD_GetState} $allUsers $0
	StrCpy $allUsers $0
	${NSD_GetState} $runAfter $0
	StrCpy $runAfter $0
FunctionEnd

!include settings-inc.nsh

Function wkbSettingsPageLeave
	Call writeSettings
FunctionEnd

!macro deleteFileMacro fileName suggestion
	Delete "${fileName}"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to delete "${fileName}"$\n$\n${suggestion}.'
		Abort
	${EndIf}
!macroend

!define deleteFile `!insertmacro deleteFileMacro`

!macro deleteLinkMacro fileName caller
	SetShellVarContext all
	${deleteFile} "${fileName}" "Please delete it, and run the ${caller} again"
	SetShellVarContext current
	${deleteFile} "${fileName}" "Please delete it, and run the ${caller} again"
!macroend

!define deleteLink `!insertmacro deleteLinkMacro`

!define wkbMiniExe "$INSTDIR\wkb-mini.exe"

!macro destroyWkbMacro caller
	${deleteLink} "$SMSTARTUP\WKB Layout.lnk" "${caller}"

	ExecWait '"${wkbMiniExe}" /T:00 /S:00 /N'
	Sleep 250
	# no result check: we run as Administrator, and the file deletion will fail with a proper text

	nsArray::Split deleteFileNameList "wkb-mini.exe|wkb-hook.dll|ReadMe.txt|settings.exe|uninstal.exe" "|"
	${If} ${RunningX64}
		NSArray::Set deleteFileNameList "wkb-mwow.exe"
		NSArray::Set deleteFileNameList "wkb-hk32.dll"
	${EndIf}

	${ForEachIn} deleteFileNameList $0 $R0
		${deleteFile} "$INSTDIR\$R0" "Please run the ${caller} again after the computer is restarted \
			or all users log off (sign off)"
	${Next}
!macroend

!define wkbLinkDir "$SMPROGRAMS\WKB Layout"

Section "Install"
	!insertmacro destroyWkbMacro "installer"

	WriteRegStr HKLM "${uninstallKey}" "DisplayName" "WKB Layout"
	WriteRegStr HKLM "${uninstallKey}" "UninstallString" '"$INSTDIR\uninstal.exe"'
	WriteRegDWORD HKLM "${uninstallKey}" "NoModify" 1
	WriteRegDWORD HKLM "${uninstallKey}" "NoRepair" 1

	SetOutPath "$INSTDIR"
	WriteUninstaller "uninstal.exe"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to create "uninstal.exe" in "$INSTDIR".'
		Abort
	${EndIf}

	# no result check: we removed all conflicting files, and created uninstal.exe in $INSTDIR
	!insertmacro installWkbFiles

	${If} $allUsers == ${BST_CHECKED}
		SetShellVarContext all
	${Else}
		SetShellVarContext current
	${EndIf}

	CreateShortCut "$SMSTARTUP\WKB Layout.lnk" "${wkbMiniExe}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "WKB Layout.lnk" in "$SMSTARTUP".'
	${EndIf}
	CreateDirectory "${wkbLinkDir}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "${wkbLinkDir}."'
	${EndIf}
	CreateShortCut "${wkbLinkDir}\ReadMe.lnk" "$INSTDIR\ReadMe.txt"
	CreateShortCut "${wkbLinkDir}\Settings.lnk" "$INSTDIR\settings.exe"
	CreateShortCut "${wkbLinkDir}\Start.lnk" "${wkbMiniExe}"
	CreateShortCut "${wkbLinkDir}\Stop.lnk" "${wkbMiniExe}" "/S:00 /T:00 /N"

	# running via explorer drops the priviledges on most systems
	${If} $runAfter == ${BST_CHECKED}
		Exec '"$WINDIR\explorer.exe" "${wkbMiniExe}"'
	${EndIf}

	Exec '"$WINDIR\explorer.exe" "$INSTDIR\ReadMe.txt"'
SectionEnd

Section "Uninstall"
	MessageBox MB_ICONQUESTION|MB_YESNO "Do you really want to uninstall WKB layout?" IDYES +2
	Quit

	!insertmacro destroyWkbMacro "uninstaller"

	${deleteLink} "${wkbLinkDir}\ReadMe.lnk" "uninstaller"
	${deleteLink} "${wkbLinkDir}\Settings.lnk" "uninstaller"
	${deleteLink} "${wkbLinkDir}\Start.lnk" "uninstaller"
	${deleteLink} "${wkbLinkDir}\Stop.lnk" "uninstaller"

	SetShellVarContext all
	RMDir "${wkbLinkDir}"
	SetShellVarContext current
	RMDir "${wkbLinkDir}"

	Delete "$INSTDIR\uninstal.exe"
	RMDir /REBOOTOK "$INSTDIR"
	DeleteRegKey HKLM "${uninstallKey}"
SectionEnd
