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

Var radioButton
Var toggleKey
Var shiftKey
Var ledLight
Var fixLayouts

!macro createKeyPanelButtonMacro keyPanel x y w h text
	${NSD_CreateRadioButton} ${x} ${y} ${w} ${h} "${text}"
	Pop $radioButton
	nsArray::Set ${keyPanel} $radioButton
!macroend

!define createKeyPanelButton `!insertmacro createKeyPanelButtonMacro`

!macro createKeyPanelMacro keyPanel x1 x2 regKeyVar regKeyName
	nsArray::Clear ${keyPanel}
	${createKeyPanelButton} ${keyPanel} ${x1} 10u 26% 12u "Applications"
	${NSD_AddStyle} $radioButton ${WS_GROUP}
	ToolTips::Classic $radioButton 'Also popular as "Menu" and "Context Menu"'
	${createKeyPanelButton} ${keyPanel} ${x2} 10u 20% 12u "Scroll Lock"
	${createKeyPanelButton} ${keyPanel} ${x1} 22u 26% 12u "Right Control"
	${createKeyPanelButton} ${keyPanel} ${x2} 22u 20% 12u "Right Alt"
	${createKeyPanelButton} ${keyPanel} ${x1} 34u 26% 12u "Right Windows"
	${createKeyPanelButton} ${keyPanel} ${x2} 34u 20% 12u "Right Shift"
	${createKeyPanelButton} ${keyPanel} ${x1} 46u 26% 12u "Left Control"
	${createKeyPanelButton} ${keyPanel} ${x2} 46u 20% 12u "Left Alt"
	${createKeyPanelButton} ${keyPanel} ${x1} 58u 26% 12u "Left Windows"
	${createKeyPanelButton} ${keyPanel} ${x2} 58u 20% 12u "Left Shift"
	${createKeyPanelButton} ${keyPanel} ${x1} 70u 26% 12u "Pause/Break"
	${createKeyPanelButton} ${keyPanel} ${x2} 70u 20% 12u "Caps Lock"
	${createKeyPanelButton} ${keyPanel} ${x1} 82u 26% 12u "Print Screen"
	${createKeyPanelButton} ${keyPanel} ${x2} 82u 20% 12u "None"

	StrCpy $R0 0
	!insertmacro readRegSettingMacro ${regKeyVar} "${regKeyName}"
	${ForEachIn} keyNameList $1 $2
		${If} ${regKeyVar} == $2
			StrCpy $R0 $1
			${Break}
		${EndIf}
	${Next}
	nsArray::Get ${keyPanel} $R0
	Pop $radioButton
	${NSD_Check} $radioButton
!macroend

!define createKeyPanel `!insertmacro createKeyPanelMacro`

!macro setKeyTooltipMacro keyPanel index text
	nsArray::Get ${keyPanel} ${index}
	Pop $radioButton
	ToolTips::Classic $radioButton "${text}"
!macroend

!define setKeyTooltip `!insertmacro setKeyTooltipMacro`

Function interSettings
	nsArray::Split keyNameList "Apps|Scroll|RCtrl|RAlt|RWin|RShift|LCtrl|LAlt|LWin|LShift|Pause|Caps|Print|00" "|"
	nsDialogs::Create 1018
	Pop $0
	${If} $0 == "error"
		MessageBox MB_ICONSTOP|MB_OK "Failed to create the settings dialog."
		SetErrorLevel 2
		Quit
	${EndIf}

	${NSD_CreateGroupBox} 0 0 49% 96u "Change layout key"
	${createKeyPanel} togglePanel 2% 28% $toggleKey "ToggleKey"
	!insertmacro focusSettingsMacro $radioButton
	${setKeyTooltip} togglePanel 11 "Shift+Caps Lock may be used to toggle capital letters"
	${setKeyTooltip} togglePanel 12 "Shift+Print Screen may be used to print the screen"

	${NSD_CreateGroupBox} 51% 0 49% 96u "Shift-change key"
	${createKeyPanel} shiftPanel 53% 79% $shiftKey "ShiftKey"
	StrCpy $R0 "Not recommended as a shift-change key"
	${setKeyTooltip} shiftPanel 4 $R0
	${setKeyTooltip} shiftPanel 8 $R0
	${setKeyTooltip} shiftPanel 11 $R0
	${setKeyTooltip} shiftPanel 12 $R0

	${NSD_CreateCheckBox} 0 100u 99% 20u "Use the Scroll Lock led as a keyboard layout indicator$\n\
		Uncheck if you use programs that rely on the Scroll Lock state"
	Pop $ledLight
	${NSD_AddStyle} $ledLight ${WS_GROUP}
	!insertmacro readRegSettingMacro $0 "LedLight"
	${If} $0 != "No"
		${NSD_Check} $ledLight
	${EndIf}

	${NSD_CreateCheckBox} 0 120u 99% 12u "Unload layouts added by lock/unlock screen, Ctrl+Alt+Del etc."
	Pop $FixLayouts
	!insertmacro readRegSettingMacro $0 "FixLayouts"
	${If} $0 == "Yes"
		${NSD_Check} $FixLayouts
	${EndIf}

	nsDialogs::Show
FunctionEnd

!define writeRegSetting `!insertmacro writeRegSettingMacro`

!macro writeRegCheckStateMacro name state
	${If} ${state} == ${BST_CHECKED}
		${writeRegSetting} "${name}" "Yes"
	${Else}
		${writeRegSetting} "${name}" "No"
	${EndIf}
!macroend

!define writeRegCheckState `!insertmacro writeRegCheckStateMacro`

!macro getKeyPanelSelectionMacro keyPanel result
	StrCpy ${result} ""
	${ForEachIn} ${keyPanel} $0 $1
		${NSD_GetState} $1 $2
		${If} $2 == ${BST_CHECKED}
			nsArray::Get keyNameList $0
			Pop ${result}
			${Break}
		${EndIf}
	${Next}
!macroend

!define getKeyPanelSelection `!insertmacro getKeyPanelSelectionMacro`

Function writeSettings
	${getKeyPanelSelection} togglePanel $toggleKey
	${getKeyPanelSelection} shiftPanel $shiftKey
	${NSD_GetState} $ledLight $R1
	${NSD_GetState} $fixLayouts $R2

	${If} $shiftKey == "RWin"
	${OrIf} $shiftKey == "LWin"
		MessageBox MB_YESNO|MB_ICONEXCLAMATION|MB_DEFBUTTON2 "Using the Left or Right Windows as \
			a shift-change key is not recommended. It conflicts with the build-in operating \
			system Windows+Key combinations, most notably Win+L (lock screen).$\n$\n\
			Proceed anyway?" IDYES +2
		Abort
	${ElseIf} $shiftKey == "Caps"
		MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 "Using Caps Lock as a shift-change key \
			is not recommended. You will not be able to toggle the capital letters state.$\n$\n\
			Proceed anyway?" IDYES +2
		Abort
	${ElseIf} $shiftKey == "Print"
		MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 "Using Print Screen as a shift-change \
			key is not recommended. You will not be able to print the entire screen, or the \
			current window.$\n$\n\
			Proceed anyway?" IDYES +2
		Abort
	${ElseIf} $toggleKey == "00"
	${AndIf} $shiftKey == "00"
	${AndIf} $R1 == ${BST_UNCHECKED}
	${AndIf} $R2 == ${BST_UNCHECKED}
		MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 "These settings will deactivate WKB. \
			Are you sure?" IDYES +2
		Abort
	${EndIf}

	ClearErrors
	${IfThen} $toggleKey != "" ${|} ${writeRegSetting} "ToggleKey" $toggleKey ${|}
	${IfThen} $shiftKey != "" ${|} ${writeRegSetting} "ShiftKey" $shiftKey ${|}
	${writeRegCheckState} "LedLight" $R1
	${writeRegCheckState} "FixLayouts" $R2
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONSTOP "Failed to write setting(s) to the registry."
	${EndIf}
FunctionEnd
