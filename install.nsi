#
# Copyright (C) 2019-2022 Dimitar Toshkov Zhekov <dimitar.zhekov@gmail.com>
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

Name "WKB Layout"
OutFile "wkb-install-1.15-x64.exe"
RequestExecutionLevel admin
CRCCheck force

XPStyle on
InstallDir ""  # we need to know if /D= is passed

!include version-inc.nsh
VIAddVersionKey FileDescription  "WKB Layout Installer"

!include FileFunc.nsh
!include LogicLib.nsh
!include nsArray.nsh
!include nsDialogs.nsh
!include WinVer.nsh
!include x64.nsh

Var previousDir
Var installDir
Var allUsers
Var runAfter
Var showRead

Var programsDir
Var adminName
Var loginName
Var loginSSid
Var autoMatic  # originally created to test silent install

ChangeUI IDD_INST custom-ui.dll
Page custom unlockBackPage  # to unblock "Back" on wkbInstallPage, with Show/Enable Back callbacks will not work
Page custom installPage installPageLeave
Page custom settingsPage settingsPageLeave
Page instfiles


# -- Initialization --
!define NameSamCompatible 2
!define PROCESS_QUERY_INFORMATION 0x0400
!define TOKEN_QUERY 0x0008
!define TokenUser 1
!define ERROR_INSUFFICIENT_BUFFER 122

Function getUsersInfo
	StrCpy $adminName ""
	StrCpy $loginName ""
	StrCpy $loginSSid ""

	StrCpy $R6 ${NSIS_MAX_STRLEN}
	System::Call "Secur32::GetUserNameEx(i ${NameSamCompatible}, t.r0, *i R6) i.r1"
	${IfThen} $1 == 0 ${|} Return ${|}
	StrCpy $adminName $0

	FindWindow $0 "Shell_TrayWnd"
	${IfThen} $0 == 0 ${|} Return ${|}
	System::Call "User32::GetWindowThreadProcessId(i r0, *i.r1) i.r2"  # 1 = process id
	${IfThen} $0 == 0 ${|} Return ${|}

	System::Call "Kernel32::OpenProcess(i ${PROCESS_QUERY_INFORMATION}, i 0, i r1) i.r0"  # 0 = process handle
	${IfThen} $0 == 0 ${|} Return ${|}
	System::Call "Advapi32::OpenProcessToken(i r0, i ${TOKEN_QUERY}, *i.r1) i.r2"  # 1 = process token
	System::Call "Kernel32::CloseHandle(i r0)"
	${IfThen} $2 == 0 ${|} Return ${|}

	System::Call "Advapi32::GetTokenInformation(i r1, i ${TokenUser}, i 0, i 0, *i.r0) i.r2 ? e"  # 0 = required size
	Pop $3
	${If} $2 == 0
	${AndIf} $3 != ${ERROR_INSUFFICIENT_BUFFER}
		Return
	${EndIf}
	System::Alloc $3
	Pop $2
	System::Call "Advapi32::GetTokenInformation(i r1, i ${TokenUser}, i r2, i r3, *i) i.r4"  # 2 = ptr user token
	System::Call "Kernel32::CloseHandle(i r1)"
	${IfThen} $4 == 0 ${|} Return ${|}
	System::Call "*$2(i.r0)"  # 0 = user binary sid

	System::Call "Advapi32::LookupAccountSid(i 0, i r0, t.r3, *i R6, t.r1, *i R6, *i) i.r4"  # 1\3 = domain\login
	${If} $4 == 0
		System::Free $2
		Return
	${EndIf}
	StrCpy $loginName "$1\$3"
	System::Call "Advapi32::ConvertSidToStringSid(i r0, *t.r1) i.r3"  # 1 = string sid
	StrCpy $loginSSid $1
	System::Free $2
FunctionEnd

Function getAutoMatic
	StrCpy $autoMatic 0
	${GetParameters} $R0

	ClearErrors
	${GetOptions} $R0 "/?" $0
	${IfNot} ${Errors}
		MessageBox MB_OK "Usage: wkb-install [/S|/A] [/R] [/D=PATH]$\n\
			$\n\
			/S, /D - See the NSIS Users Manual.$\n\
			/A - Automatic installation for all users.$\n\
			/R - run WKB after successful installation."
		SetErrorLevel 0
		Quit
	${EndIf}

	${If} ${Silent}
		StrCpy $autoMatic 1
	${Else}
		ClearErrors
		${GetOptions} $R0 "/A" $0
		${IfNot} ${Errors}
			StrCpy $autoMatic 1
		${EndIf}
	${EndIf}

	${If} $autoMatic == 1
		ClearErrors
		${GetOptions} $R0 "/R" $0
		${IfNot} ${Errors}
		${AndIf} $adminName != ""
		${AndIf} $adminName == $loginName
			StrCpy $runAfter ${BST_CHECKED}
		${EndIf}
	${Else}
		StrCpy $R1 ""
		${If} $adminName == ""
			StrCpy $R1 "Failed to get the install user name."
		${ElseIf} $loginName == ""
			StrCpy $R1 "Failed to get the login user name."
		${ElseIf} $loginSSid == ""
			StrCpy $R1 "Failed to get the login user string ssid."
		${EndIf}
		${If} $R1 != ""
			MessageBox MB_ICONINFORMATION|MB_OKCANCEL "$R1$\n$\n\
				A default installation for all users will be performed." IDOK +2
			Abort
			StrCpy $autoMatic 1
			StrCpy $INSTDIR $previousDir  # agreed to defaults, ignore /D=
		${EndIf}
	${EndIf}
FunctionEnd

!define uninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\wkb_mini"

Function .onInit
	System::Call "User32::SetProcessDPIAware"

	${IfNot} ${AtLeastWin7}
		MessageBox MB_ICONSTOP|MB_OK "WKB Layout requires Windows 7 or later." /SD IDOK
		Abort
	${EndIf}

	${IfNot} ${RunningX64}
		MessageBox MB_ICONSTOP|MB_OK "WKB Layout requires a 64-bit operating system." /SD IDOK
		Abort
	${EndIf}

	StrCpy $previousDir ""
	ReadRegStr $0 HKLM "${uninstallKey}" "UninstallString"
	StrCpy $1 $0 1
	StrCpy $2 $0 14 -14
	${If} '$1$2' == '"\uninstal.exe"' 
		StrCpy $previousDir $0 -14 1
		${If} $previousDir != ""
			IfFileExists "$previousDir\uninstal.exe" +2
			StrCpy $previousDir ""
		${EndIf}
	${EndIf}

	StrCpy $allUsers ${BST_CHECKED}
	StrCpy $runAfter ${BST_UNCHECKED}
	StrCpy $showRead ${BST_UNCHECKED}
	StrCpy $programsDir $PROGRAMFILES64
	Call getUsersInfo
	Call getAutoMatic

	${If} $previousDir != ""
		${If} $autoMatic == 1
		${AndIf} $INSTDIR != ""
		${AndIf} $INSTDIR != $previousDir
			MessageBox MB_ICONSTOP|MB_OK 'WKB is already installed in "$previousDir"$\n$\n\
				To install in "$INSTDIR", please uninstall it first.' /SD IDOK
			Abort
		${EndIf}
		StrCpy $INSTDIR $previousDir
	${ElseIf} $INSTDIR == ""
		StrCpy $INSTDIR "$programsDir\wkb-mini"
	${EndIf}
FunctionEnd


# -- User interface --
Function unlockBackPage
FunctionEnd

Function browseClicked
	${NSD_GetText} $installDir $0
	IfFileExists $0 +2
	StrCpy $0 $programsDir
	nsDialogs::SelectFolderDialog "Installation Directory" $0
	Pop $0
	${If} $0 != "error"
		StrCpy $INSTDIR $0
		${NSD_SetText} $installDir $INSTDIR
	${EndIf}
FunctionEnd

Function licenseClicked
	StrCpy $0 "$PLUGINSDIR\COPYING.txt"
	IfFileExists $0 +2
	File "/oname=$0" "COPYING.txt"
	${If} ${FileExists} $0
		ExecShell "open" $0
		IfErrors +2
		Abort
	${EndIf}
	MessageBox MB_OK "Failed to display the license file.$\n$\nSee https://www.gnu.org/licenses/"
FunctionEnd

Function installPage
	${If} $autoMatic == 1
		Abort
	${EndIf}
	nsDialogs::Create 1018
	Pop $0
	${If} $0 == "error"
		MessageBox MB_ICONSTOP|MB_OK "Failed to create the installation dialog."
		SetErrorLevel 2
		Quit
	${EndIf}

	${NSD_CreateLabel} 0% 0 50% 8u "Installation directory:"
	${NSD_CreateFileRequest} 0% 8u 95% 12u $INSTDIR
	Pop $installDir
	${NSD_CreateBrowseButton} 95% 8u 5% 12u "..."
	Pop $R0
	${If} $previousDir == ""
		${NSD_OnClick} $R0 browseClicked
	${Else}
		SendMessage $installDir ${EM_SETREADONLY} 1 0
		ToolTips::Classic $installDir "Already installed here, uninstall it first to use another directory"
		EnableWindow $R0 0
	${EndIf}

	${NSD_CreateLabel} 0% 0 50% 8u "Installation directory:"
	${NSD_CreateFileRequest} 0% 8u 95% 12u $INSTDIR
	Pop $installDir
	${NSD_CreateBrowseButton} 95% 8u 5% 12u "..."
	Pop $R0
	${If} $previousDir == ""
		${NSD_OnClick} $R0 browseClicked
	${Else}
		SendMessage $installDir ${EM_SETREADONLY} 1 0
		ToolTips::Classic $installDir "Already installed here, uninstall it first to use another directory"
		EnableWindow $R0 0
	${EndIf}

	${NSD_CreateCheckBox} 0% 24u 31% 12u "Install for all users"
	Pop $allUsers
	${NSD_Check} $allUsers
	${If} $loginName != $adminName
		EnableWindow $allUsers 0
		${NSD_CreateLabel} 0% 24u 31% 12u ""
		Pop $0
		ToolTips::Classic $0 "Mandatory for different login and install users"
	${EndIf}

	${NSD_CreateCheckBox} 35% 24u 31% 12u "Run after installation"
	Pop $runAfter
	${If} $loginName == $adminName
		${NSD_Check} $runAfter
	${Else}
		EnableWindow $runAfter 0
		${NSD_CreateLabel} 35% 24u 31% 12u ""
		Pop $0
		ToolTips::Classic $0 "Not avaiilable for different login and install users"
	${EndIf}

	${NSD_CreateCheckBox} 73% 24u 31% 12u "Show ReadMe"
	Pop $showRead
	${NSD_Check} $showRead

	${NSD_CreateHLine} 0% 40u 100% 1u ""
	Pop $0
	${NSD_AddStyle} $0 ${WS_GROUP}

	${NSD_CreateLabel} 2% 48u 96% 8u "WKB Layout version 1.15, \
		Copyright (C) 2016-2022 Dimitar Toshkov Zhekov."
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

Function installPageLeave
	${NSD_GetText} $installDir $INSTDIR
	${If} $INSTDIR == ""
		MessageBox MB_ICONSTOP|MB_OK "The installation directory is required."
		Abort
	${EndIf}
	${NSD_GetState} $allUsers $0
	StrCpy $allUsers $0
	${NSD_GetState} $runAfter $0
	StrCpy $runAfter $0
	${NSD_GetState} $showRead $0
	StrCpy $showRead $0
FunctionEnd

!macro focusSettingsMacro toggleButton
	System::Call "UxTheme.dll::IsAppThemed() i.r0"
	${IfThen} $0 == 1 ${|} ${NSD_SetFocus} $radioButton ${|}
!macroend

!macro readRegSettingMacro result name
	ReadRegStr ${result} HKU "$loginSSid\Software\WkbLayout" "${name}"
!macroend

!macro writeRegSettingMacro name value
	WriteRegStr HKU "$loginSSid\Software\WkbLayout" "${name}" "${value}"
!macroend

!include settings-inc.nsh

Function settingsPage
	${If} $autoMatic == 1
		Abort
	${EndIf}
	Call interSettings
FunctionEnd

Function settingsPageLeave
	Call writeSettings
FunctionEnd


# -- (un)Installation --
!macro deleteFileMacro fileName suggestion
	ClearErrors
	Delete "${fileName}"
	${If} ${Errors}
		${If} "${suggestion}" != ""
			MessageBox MB_ICONSTOP|MB_OK 'Failed to delete "${fileName}"$\n$\n${suggestion}' /SD IDOK
			Abort
		${Else}
			DetailPrint 'Failed to delete "${fileName}"'
		${EndIf}
	${EndIf}
!macroend

!define deleteFile `!insertmacro deleteFileMacro`

!macro deleteLinkMacro fileName suggestion
	SetShellVarContext all
	${deleteFile} "${fileName}" "${suggestion}"
	SetShellVarContext current
	${deleteFile} "${fileName}" "${suggestion}"
!macroend

!define deleteLink `!insertmacro deleteLinkMacro`

!macro destroyWkbMacro caller miniPath
	${deleteLink} "$SMSTARTUP\WKB Layout.lnk" "Please delete it, and run the ${caller} again."

	ExecWait '"${miniPath}\wkb-mini.exe" /T:00 /S:00 /N /O'
	Sleep 250
	# no result check: we run as Administrator, and the file deletion will fail with a proper text

 	StrCpy $R0 "Please run the ${caller} again after the computer is restarted, or all users sign out (log off)."
	${deleteFile} "$INSTDIR\wkb-mini.exe" $R0
	${deleteFile} "$INSTDIR\wkb-hook.dll" $R0
	${deleteFile} "$INSTDIR\wkb-mwow.exe" $R0
	${deleteFile} "$INSTDIR\wkb-hk32.dll" $R0
	${deleteFile} "$INSTDIR\COPYING.txt"  ""
	${deleteFile} "$INSTDIR\ReadMe.txt"   ""
	${deleteFile} "$INSTDIR\settings.exe" ""
	${deleteFile} "$INSTDIR\uninstal.exe" $R0

	${deleteLink} "${wkbLinkDir}\License.lnk"  ""
	${deleteLink} "${wkbLinkDir}\ReadMe.lnk"   ""
	${deleteLink} "${wkbLinkDir}\Settings.lnk" ""
	${deleteLink} "${wkbLinkDir}\Start.lnk"    ""
	${deleteLink} "${wkbLinkDir}\Stop.lnk"     ""

	SetShellVarContext all
	RMDir "${wkbLinkDir}"
	SetShellVarContext current
	RMDir "${wkbLinkDir}"
!macroend

!define wkbLinkDir "$SMPROGRAMS\WKB Layout"
!define wkbMiniExe "$INSTDIR\wkb-mini.exe"

Section Install
	File "/oname=$PLUGINSDIR\wkb-mini.exe" "wkb-mini.exe"
	File "/oname=$PLUGINSDIR\wkb-hook.dll" "wkb-hook.dll"

	!insertmacro destroyWkbMacro "installer" $PLUGINSDIR

	ClearErrors
	WriteRegStr HKLM "${uninstallKey}" "DisplayIcon" "${wkbMiniExe}"
	WriteRegStr HKLM "${uninstallKey}" "DisplayName" "WKB Layout"
	WriteRegStr HKLM "${uninstallKey}" "DisplayVersion" "1.15"
	WriteRegStr HKLM "${uninstallKey}" "Publisher" "Dimitar Toshkov Zhekov"
	WriteRegStr HKLM "${uninstallKey}" "UninstallString" '"$INSTDIR\uninstal.exe"'
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK "Failed to create the uninstall registry keys." /SD IDOK
		Abort
	${EndIf}
	WriteRegDWORD HKLM "${uninstallKey}" "NoModify" 1
	WriteRegDWORD HKLM "${uninstallKey}" "NoRepair" 1
	WriteRegDWORD HKLM "${uninstallKey}" "VersionMajor" 1
	WriteRegDWORD HKLM "${uninstallKey}" "VersionMinor" 14
	WriteRegDWORD HKLM "${uninstallKey}" "EstimatedSize" 250

	ClearErrors
	SetOutPath $INSTDIR
	WriteUninstaller "uninstal.exe"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to create "uninstal.exe" in "$INSTDIR".' /SD IDOK
		Abort
	${EndIf}

	CopyFiles /SILENT /FILESONLY "$PLUGINSDIR\wkb-mini.exe" $INSTDIR
	CopyFiles /SILENT /FILESONLY "$PLUGINSDIR\wkb-hook.dll" $INSTDIR
	File "wkb-mwow.exe"
	File "wkb-hk32.dll"
	File "settings.exe"
	File "ReadMe.txt"
	File "COPYING.txt"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to copy/extract file(s) to "$INSTDIR".' /SD IDOK
		Abort
	${EndIf}

	${If} $allUsers == ${BST_CHECKED}
		SetShellVarContext all
	${Else}
		SetShellVarContext current
	${EndIf}

	CreateShortCut "$SMSTARTUP\WKB Layout.lnk" "${wkbMiniExe}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "WKB Layout.lnk" in "$SMSTARTUP".' /SD IDOK
	${EndIf}

	CreateDirectory "${wkbLinkDir}"
	${If} ${Errors}
		MessageBox MB_OK 'Failed to create "${wkbLinkDir}."' /SD IDOK
		Abort
	${EndIf}

	CreateShortCut "${wkbLinkDir}\License.lnk" "$INSTDIR\COPYING.txt"
	CreateShortCut "${wkbLinkDir}\ReadMe.lnk" "$INSTDIR\ReadMe.txt"
	CreateShortCut "${wkbLinkDir}\Settings.lnk" "$INSTDIR\settings.exe"
	CreateShortCut "${wkbLinkDir}\Start.lnk" "${wkbMiniExe}"
	CreateShortCut "${wkbLinkDir}\Stop.lnk" "${wkbMiniExe}" "/S:00 /T:00 /N /O"
	${If} ${Errors}
		MessageBox MB_ICONSTOP|MB_OK 'Failed to create link(s) in "${wkbLinkDir}".' /SD IDOK
		Abort
	${EndIf}

	${If} $runAfter == ${BST_CHECKED}
		Exec "${wkbMiniExe}"
		${If} ${Errors}
			MessageBox MB_OK 'Failed to run "${wkbMiniExe}".$\n$\n\
				You can run it from the Start menu.' /SD IDOK
		${EndIf}
	${EndIf}

	${If} $showRead == ${BST_CHECKED}
		ExecShell "open" "$INSTDIR\ReadMe.txt"
		${If} ${Errors}
			MessageBox MB_OK "Failed to display the ReadMe file.$\n$\n\
				See https://raw.githubusercontent.com/zhekov/wkb-mini/master/ReadMe.txt"
		${EndIf}
	${EndIf}

	SetDetailsView show
SectionEnd

Section Uninstall
	MessageBox MB_ICONQUESTION|MB_YESNO "Do you really want to uninstall WKB layout?" /SD IDYES IDYES +2
	Abort

	!insertmacro destroyWkbMacro "uninstaller" $INSTDIR

	RMDir /REBOOTOK $INSTDIR
	DeleteRegKey HKLM "${uninstallKey}"

	SetDetailsView show
SectionEnd
