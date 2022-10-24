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

Name "WKB Layout"
OutFile "wkb-install-1.11-win64.exe"
RequestExecutionLevel admin
CRCCheck force
XPStyle on

InstallDir "$PROGRAMFILES64\wkb-mini"

!define estimatedSize "200"

!macro installWkbFiles
	File "wkb-mwow.exe"
	File "wkb-hk32.dll"
	File "settings.exe"
	File "ReadMe.txt"
	File "COPYING.txt"
!macroend

!include x64.nsh
!include WinVer.nsh

Function .onInit
	System::Call "User32::SetProcessDPIAware"
	${IfNot} ${RunningX64}
		MessageBox MB_ICONSTOP|MB_OK "You are trying to install the 64-bit \
			version of WKB on a 32-bit system. That will not work."
		Quit
	${EndIf}
FunctionEnd

!include install-inc.nsh
