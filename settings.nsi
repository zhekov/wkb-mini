#
# Copyright (C) 2016-2022 Dimitar Toshkov Zhekov <dimitar.zhekov@gmail.com>
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

Caption "WKB Layout Settings"
OutFile settings.exe
RequestExecutionLevel user
CRCCheck force

XPStyle on
Icon "gucharmap1.ico"
InstallButtonText "OK"
BrandingText " "

!include version-inc.nsh
VIAddVersionKey FileDescription  "WKB Layout Settings Executable"

!include LogicLib.nsh
!include nsArray.nsh
!include nsDialogs.nsh
!include WinVer.nsh

ChangeUI IDD_INST custom-ui.dll
Page custom settingsPage settingsPageLeave
Page instfiles  # avoid warning "no sections will be executed"

Function .onInit
	System::Call "User32::SetProcessDPIAware"
	SetSilent normal  # silent makes no sense for Settings
FunctionEnd

!macro focusSettingsMacro toggleButton
	${NSD_SetFocus} ${toggleButton}
!macroend

!macro readRegSettingMacro result name
	ReadRegStr ${result} HKCU "Software\WkbLayout" "${name}"
!macroend

!macro writeRegSettingMacro name value
	WriteRegStr HKCU "Software\WkbLayout" "${name}" "${value}"
!macroend

!include settings-inc.nsh

!macro checkDisabledMacro result
	${If} $toggleKey == "00"
	${AndIf} $shiftKey == "00"
	${AndIf} $R1 == "No"
	${AndIf} $R2 == "No"
		StrCpy ${result} 1
	${Else}
		StrCpy ${result} 0
	${EndIf}
!macroend

Function settingsPage
	Call interSettings
FunctionEnd

Function settingsPageLeave
	# start wkb-mini if switching from disabled
	# to enabled settings, otherwise apply only
	!insertmacro readRegSettingMacro $R1 "LedLight"
	!insertmacro readRegSettingMacro $R2 "FixLayouts"
	!insertmacro checkDisabledMacro $0
	${If} $0 == 1
		StrCpy $R0 ""
	${Else}
		StrCpy $R0 " /wkb:apply"
	${EndIf}
	Call writeSettings
	!insertmacro checkDisabledMacro $0
	${IfThen} $0 == 1 ${|} StrCpy $R0 " /wkb:apply" ${|}

	${If} ${Errors}
		SetErrorLevel 2
	${Else}
		Exec ".\wkb-mini.exe$R0"
		${If} ${Errors}
			MessageBox MB_ICONSTOP|MB_OK "Failed to run the WKB executable."
			SetErrorLevel 2  # important, unlike install
		${Else}
			SetErrorLevel 0
		${EndIf}
	${EndIf}
	Quit  # don't display the instfiles page
FunctionEnd

Function .onGUIEnd
	# Settings.exe -> Cancel is 0/OK, not 1 as in install
	GetErrorLevel $0
	${If} $0 == -1
	${OrIf} $0 == 1
		SetErrorLevel 0
	${EndIf}
FunctionEnd

Section Install
SectionEnd
