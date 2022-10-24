#
# Copyright (C) 2016-2020 Dimitar Toshkov Zhekov <dimitar.zhekov@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

VIProductVersion "1.11.0.0"
VIAddVersionKey ProductName "WKB Layout"
VIAddVersionKey LegalCopyright "Copyright (C) 2016-2020 Dimitar Toshkov Zhekov"
VIAddVersionKey FileDescription  "WKB Layout Installer"
VIAddVersionKey FileVersion 1.11
VIAddVersionKey ProductVersion 1.11

!include nsDialogs.nsh
!include LogicLib.nsh
!include FileFunc.nsh
!include nsArray.nsh
!include StrFunc.nsh
${StrStrAdv}

Var previousDir
Var installDir
Var allUsers
Var runAfter
Var showRead
Var tempName

Function unlockBackPage
FunctionEnd

ChangeUI IDD_INST custom-ui.dll
Page custom unlockBackPage  # setting CB fails if Back is unblocked by Show/Enable
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

Function generateTempName
	System::Call "kernel32::GetTickCount()i .r0"
	SetShellVarContext all
	StrCpy $tempName "$APPDATA\TEMP"
	IfFileExists "$tempName" +2
	StrCpy $tempName "$APPDATA"
	StrCpy $tempName "$tempName\ns$0_gpl_v2.txt"
FunctionEnd

Function licenseClicked
	${If} $tempName == ""
		Call generateTempName
		ClearErrors
		File "/oname=$tempName" "COPYING.txt"
		${If} ${Errors}
			MessageBox MB_OK "Failed to extract the license file.$\n$\nSee https://www.gnu.org/licenses/"
			delete "$tempName"
			StrCpy $tempName ""
			Abort
		${EndIf}
	${EndIf}
	SetFileAttributes "$tempName" READONLY
	ExecWait '"$WINDIR\explorer.exe" "$tempName"'
	Abort
FunctionEnd

Function .onGUIEnd
	${If} $tempName != ""
		Delete "$tempName"
		StrCpy $tempName ""
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
	Pop $0
	${If} $0 == error
		MessageBox MB_ICONSTOP|MB_OK "Failed to create installation dialog."
		Abort
	${EndIf}

	${NSD_CreateLabel} 0% 0 50% 8u "Installation directory:"
	${NSD_CreateFileRequest} 0% 8u 95% 12u ""
	Pop $installDir
	Call getPreviousDir
	${If} $previousDir == ""
		${NSD_SetText} $installDir "$INSTDIR"
	${Else}
		${NSD_SetText} $installDir "$previousDir"
	${EndIf}
	${NSD_CreateBrowseButton} 95% 8u 5% 12u "..."
	Pop $0
	${NSD_OnClick} $0 browseClicked

	${NSD_CreateCheckBox} 0% 24u 31% 12u "Install for all users"
	Pop $allUsers
	${NSD_Check} $allUsers

	${NSD_CreateCheckBox} 35% 24u 31% 12u "Run after installation"
	Pop $runAfter
	${NSD_Check} $runAfter

	${NSD_CreateCheckBox} 70% 24u 31% 12u "Show ReadMe"
	Pop $showRead
	${NSD_Check} $showRead

	${NSD_CreateHLine} 0 40u 100% 1u
	Pop $0
	${NSD_AddStyle} $0 ${WS_GROUP}

	${NSD_CreateLabel} 2% 48u 96% 8u "WKB Layout version 1.11, \
		Copyright (C) 2016-2020 Dimitar Toshkov Zhekov."
	${NSD_CreateLabel} 2% 60u 96% 32u "This program is free software; \
		you can redistribute it and/or modify it under the terms of \
		the GNU General Public License as published by the Free \
		Software Foundation; either version 2 of the License, or \
		(at your option) any later version."
	${NSD_CreateLabel} 2% 96u 96% 32u "This program is distributed in \
		the hope that it will be useful, but WITHOUT ANY WARRANTY; \
		without even the implied warranty of MERCHANTABILITY or \
		FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General \
		Public License for more details."

	GetDlgItem $0 $HWNDPARENT 3
	${NSD_SetText} $0 "License"
	${NSD_OnBack} licenseClicked

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
	${NSD_GetState} $showRead $0
	StrCpy $showRead $0
FunctionEnd

!include settings-inc.nsh

Function wkbSettingsPageLeave
	Call writeSettings
FunctionEnd

!macro deleteFileMacro fileName suggestion
	ClearErrors
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

!macro destroyWkbMacro caller miniPath
	${deleteLink} "$SMSTARTUP\WKB Layout.lnk" "${caller}"

	ExecWait '"${miniPath}\wkb-mini.exe" /T:00 /S:00 /N /O'
	Sleep 250
	# no result check: we run as Administrator, and the file deletion will fail with a proper text

	StrCpy $0 "wkb-mini.exe|wkb-hook.dll|COPYING.txt|ReadMe.txt|settings.exe|uninstal.exe"
	${If} ${RunningX64}
		StrCpy $0 "$0|wkb-mwow.exe|wkb-hk32.dll"
	${EndIf}
	nsArray::Split deleteFilesList "$0" "|"

	${ForEachIn} deleteFilesList $0 $R0
		${deleteFile} "$INSTDIR\$R0" "Please run the ${caller} again after the computer is restarted, \
			or all users log off (sign off)"
	${Next}
!macroend

!define wkbLinkDir "$SMPROGRAMS\WKB Layout"

Section "Install"
	File "/oname=$PLUGINSDIR\wkb-mini.exe" "wkb-mini.exe"
	File "/oname=$PLUGINSDIR\wkb-hook.dll" "wkb-hook.dll"
	!insertmacro destroyWkbMacro "installer" "$PLUGINSDIR"

	ClearErrors
	WriteRegStr HKLM "${uninstallKey}" "DisplayIcon" "${wkbMiniExe}"
	WriteRegStr HKLM "${uninstallKey}" "DisplayName" "WKB Layout"
	WriteRegStr HKLM "${uninstallKey}" "DisplayVersion" "1.11"
	WriteRegStr HKLM "${uninstallKey}" "Publisher" "Dimitar Toshkov Zhekov"
	WriteRegStr HKLM "${uninstallKey}" "UninstallString" '"$INSTDIR\uninstal.exe"'
	WriteRegDWORD HKLM "${uninstallKey}" "NoModify" 1
	WriteRegDWORD HKLM "${uninstallKey}" "NoRepair" 1
	WriteRegDWORD HKLM "${uninstallKey}" "VersionMajor" 1
	WriteRegDWORD HKLM "${uninstallKey}" "VersionMinor" 11
	WriteRegDWORD HKLM "${uninstallKey}" "EstimatedSize" "${estimatedSize}"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK "Failed to create the uninstall registry keys."
		Abort
	${EndIf}

	SetOutPath "$INSTDIR"
	ClearErrors
	WriteUninstaller "uninstal.exe"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to create "uninstal.exe" in "$INSTDIR".'
		Abort
	${EndIf}

	ClearErrors
	CopyFiles /SILENT /FILESONLY "$PLUGINSDIR\wkb-mini.exe" "$INSTDIR"
	CopyFiles /SILENT /FILESONLY "$PLUGINSDIR\wkb-hook.dll" "$INSTDIR"
	!insertmacro installWkbFiles
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to copy/extract file(s) to "$INSTDIR".'
		Abort
	${EndIf}

	${If} $allUsers == ${BST_CHECKED}
		SetShellVarContext all
	${Else}
		SetShellVarContext current
	${EndIf}

	ClearErrors
	CreateShortCut "$SMSTARTUP\WKB Layout.lnk" "${wkbMiniExe}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "WKB Layout.lnk" in "$SMSTARTUP".'
	${EndIf}

	ClearErrors
	CreateDirectory "${wkbLinkDir}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "${wkbLinkDir}."'
	${EndIf}

	CreateShortCut "${wkbLinkDir}\License.lnk" "$INSTDIR\COPYING.txt"
	CreateShortCut "${wkbLinkDir}\ReadMe.lnk" "$INSTDIR\ReadMe.txt"
	CreateShortCut "${wkbLinkDir}\Settings.lnk" "$INSTDIR\settings.exe"
	CreateShortCut "${wkbLinkDir}\Start.lnk" "${wkbMiniExe}"
	CreateShortCut "${wkbLinkDir}\Stop.lnk" "${wkbMiniExe}" "/S:00 /T:00 /N /O"

	# running via explorer drops the priviledges on most systems
	${If} $runAfter == ${BST_CHECKED}
		Exec '"$WINDIR\explorer.exe" "${wkbMiniExe}"'
	${EndIf}

	${If} $showRead == ${BST_CHECKED}
		Exec '"$WINDIR\explorer.exe" "$INSTDIR\ReadMe.txt"'
	${EndIf}
SectionEnd

Section "Uninstall"
	MessageBox MB_ICONQUESTION|MB_YESNO "Do you really want to uninstall WKB layout?" IDYES +2
	Quit

	!insertmacro destroyWkbMacro "uninstaller" "$INSTDIR"

	${deleteLink} "${wkbLinkDir}\License.lnk" "uninstaller"
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
