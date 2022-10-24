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

Caption "WKB Layout Settings"
OutFile settings.exe
RequestExecutionLevel user
CRCCheck force

XPStyle on
Icon "gucharmap.ico"
InstallButtonText "OK"
BrandingText " "

VIProductVersion "1.11.0.0"
VIAddVersionKey ProductName "WKB Layout"
VIAddVersionKey LegalCopyright "Copyright (C) 2016-2020 Dimitar Toshkov Zhekov"
VIAddVersionKey FileDescription  "WKB Layout Settings Executable"
VIAddVersionKey FileVersion 1.11
VIAddVersionKey ProductVersion 1.11

!include nsDialogs.nsh
!include LogicLib.nsh
!include nsArray.nsh
!include WinVer.nsh

ChangeUI IDD_INST custom-ui.dll
Page custom wkbSettingsPage wkbSettingsPageLeave
Page instfiles

Function .onInit
	System::Call "User32::SetProcessDPIAware"
FunctionEnd

!include settings-inc.nsh

Function wkbSettingsPageLeave
	Call writeSettings
	Exec ".\wkb-mini.exe /wkb:apply"
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONSTOP "Failed to run the WKB executable."
	${EndIf}
	Quit
FunctionEnd

Section Install
SectionEnd
