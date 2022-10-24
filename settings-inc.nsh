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

!macro createKeyPanelButtonMacro x y w h text
	${NSD_CreateRadioButton} ${x} ${y} ${w} ${h} "${text}"
	Pop $radioButton
	nsArray::Set keyPanel $radioButton
!macroend

!define createKeyPanelButton `!insertmacro createKeyPanelButtonMacro`

Function createKeyPanelFunc
	Pop $R2
	Pop $R1
	Pop $R0

	nsArray::Clear keyPanel
	${createKeyPanelButton} $R0 10u 26% 12u "Applications"
	${NSD_AddStyle} $radioButton ${WS_GROUP}
	ToolTips::Classic $radioButton 'Also popular as "Menu" and "Context Menu"'
	${createKeyPanelButton} $R1 10u 20% 12u "Scroll Lock"
	${createKeyPanelButton} $R0 22u 26% 12u "Right Control"
	${createKeyPanelButton} $R1 22u 20% 12u "Right Alt"
	${createKeyPanelButton} $R0 34u 26% 12u "Right Windows"
	${createKeyPanelButton} $R1 34u 20% 12u "Right Shift"
	${createKeyPanelButton} $R0 46u 26% 12u "Left Control"
	${createKeyPanelButton} $R1 46u 20% 12u "Left Alt"
	${createKeyPanelButton} $R0 58u 26% 12u "Left Windows"
	${createKeyPanelButton} $R1 58u 20% 12u "Left Shift"
	${createKeyPanelButton} $R0 70u 26% 12u "Pause/Break"
	${createKeyPanelButton} $R1 70u 20% 12u "Caps Lock"
	${createKeyPanelButton} $R0 82u 26% 12u "Print Screen"
	${createKeyPanelButton} $R1 82u 20% 12u "None"

	ReadRegStr $0 HKCU "Software\WkbLayout" "$R2"
	${If} $0 == ""
	${OrIf} $0 == "Props"
		StrCpy $R3 0
	${Else}
        	StrCpy $R3 ""

		${ForEachIn} keyNameList $1 $2
			${If} $0 == $2
				StrCpy $R3 $1
				${Break}
			${EndIf}
		${Next}
	${EndIf}

	${If} $R3 == ""
		nsArray::Get keyPanel 0
		Pop $radioButton
	${Else}
		nsArray::Get keyPanel $R3
		Pop $radioButton
		${NSD_Check} $radioButton
	${EndIf}
FunctionEnd

!macro createKeyPanelMacro x1 x2 regName
	Push ${x1}
	Push ${x2}
	Push ${regName}
	Call createKeyPanelFunc
!macroend

!define createKeyPanel `!insertmacro createKeyPanelMacro`

Function setKeyTooltipFunc
	Pop $R1
	Pop $R0
	nsArray::Get keyPanel $R0
	Pop $radioButton
	ToolTips::Classic $radioButton "$R1"
FunctionEnd

!macro setKeyTooltipMacro idx text
	Push ${idx}
	Push "${text}"
	Call setKeyTooltipFunc
!macroend

!define setKeyTooltip `!insertmacro setKeyTooltipMacro`

!macro setKeyNShiftipMacro idx
	Push ${idx}
	Push "Not recommended as a shift-change key"
	Call setKeyTooltipFunc
!macroend

!define setKeyNShiftip `!insertmacro setKeyNShiftipMacro`

Function wkbSettingsPage
	nsArray::Split keyNameList "Apps|Scroll|RCtrl|RAlt|RWin|RShift|LCtrl|LAlt|LWin|LShift|Pause|Caps|Print|00" "|"
	nsDialogs::Create 1018
	Pop $0
	${If} $0 == error
		MessageBox MB_ICONSTOP|MB_OK "Failed to create settings dialog."
		Abort
	${EndIf}

	StrCpy $R0 "WKB Layout Settings"
	System::Call "advapi32::GetUserName(t .r0, *i ${NSIS_MAX_STRLEN}) i.r1"
	${If} $1 != 0
		StrCpy $R0 "$R0 [user: $0]"
	${EndIf}
	${NSD_SetText} $HWNDPARENT "$R0"

	${NSD_CreateGroupBox} 0 0 49% 96u "Change layout key"
	${createKeyPanel} 2% 28% "ToggleKey"
	StrCpy $R0 "1"
	${If} ${AtLeastWinVista}  # or 7even?
		ReadRegStr $0 HKCU "Control Panel\Accessibility\Keyboard Preference" "On"
	${EndIf}
	# without the dotted border, focusing is counter-intuitive
	${IfThen} $0 == "1" ${|} ${NSD_SetFocus} $radioButton ${|}
	${nsArray_Copy} keyPanel togglePanel
	${setKeyTooltip} 11 "Shift+Caps Lock may be used to toggle capital letters"
	${setKeyTooltip} 12 "Shift+Print Screen may be used to print the screen"

	${NSD_CreateGroupBox} 51% 0 49% 96u "Shift-change key"
	${createKeyPanel} 53% 79% "ShiftKey"
	${nsArray_Copy} keyPanel shiftPanel
	${setKeyNShiftip} 4
	${setKeyNShiftip} 8
	${setKeyNShiftip} 11
	${setKeyNShiftip} 12

	${NSD_CreateCheckBox} 0 100u 99% 20u "Use the Scroll Lock led as a keyboard layout indicator$\n\
		Uncheck if you use programs that rely on the Scroll Lock state"
	Pop $ledLight
	${NSD_AddStyle} $ledLight ${WS_GROUP}
	ReadRegStr $0 HKCU "Software\WkbLayout" "LedLight"
	${If} $0 != "No"
		${NSD_Check} $ledLight
	${EndIf}

	${NSD_CreateCheckBox} 0 120u 99% 12u "Unload layouts added by lock/unlock screen, Ctrl+Alt+Del etc."
	Pop $FixLayouts
	ReadRegStr $0 HKCU "Software\WkbLayout" "FixLayouts"
	${If} $0 == "Yes"
		${NSD_Check} $FixLayouts
	${EndIf}

	nsDialogs::Show
FunctionEnd

!macro writeRegSettingMacro name value
	WriteRegStr HKCU "Software\WkbLayout" "${name}" "${value}"
!macroend

!define writeRegSetting `!insertmacro writeRegSettingMacro`

!macro writeRegCheckStateMacro name state
	${If} ${state} == ${BST_CHECKED}
		WriteRegStr HKCU "Software\WkbLayout" "${name}" "Yes"
	${Else}
		WriteRegStr HKCU "Software\WkbLayout" "${name}" "No"
	${EndIf}
!macroend

!define writeRegCheckState `!insertmacro writeRegCheckStateMacro`

Function getKeyPanelSelection
	Push ""
	${ForEachIn} keyPanel $0 $1
		${NSD_GetState} $1 $2

		${If} $2 == ${BST_CHECKED}
			nsArray::Get keyNameList $0
			Pop $R0
			Exch $R0
			${Break}
		${EndIf}
	${Next}
FunctionEnd

Function writeSettings
	${nsArray_Copy} togglePanel keyPanel
	Call getKeyPanelSelection
	Pop $toggleKey

	${nsArray_Copy} shiftPanel keyPanel
	Call getKeyPanelSelection
	Pop $shiftKey

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
		MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 "These settings will keep WKB deactivated. \
			Are you sure?" IDYES +2
		Abort
	${EndIf}

	ClearErrors
	${IfThen} $toggleKey != "" ${|} ${writeRegSetting} "ToggleKey" $toggleKey ${|}
	${IfThen} $shiftKey != ""${|} ${writeRegSetting} "ShiftKey" $shiftKey ${|}
	${writeRegCheckState} "LedLight" $R1
	${writeRegCheckState} "FixLayouts" $R2
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONSTOP "Failed to write setting(s) to the registry."
	${EndIf}
FunctionEnd
