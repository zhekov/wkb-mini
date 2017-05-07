Var radioButton
Var toggleKey
Var shiftKey
Var ledLight

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
	${createKeyPanelButton} $R0 10u 26% 11u "Caps Lock"
	${createKeyPanelButton} $R1 10u 20% 11u "Scroll Lock"
	${createKeyPanelButton} $R0 21u 26% 11u "Right Control"
	${createKeyPanelButton} $R1 21u 20% 11u "Right Alt"
	${createKeyPanelButton} $R0 32u 26% 11u "Right Windows"
	${createKeyPanelButton} $R1 32u 20% 11u "Right Shift"
	${createKeyPanelButton} $R0 43u 26% 11u "Left Control"
	${createKeyPanelButton} $R1 43u 20% 11u "Left Alt"
	${createKeyPanelButton} $R0 54u 26% 11u "Left Windows"
	${createKeyPanelButton} $R1 54u 20% 11u "Left Shift"
	${createKeyPanelButton} $R0 65u 26% 11u "Applications"
	${NSD_AddStyle} $radioButton ${WS_GROUP}
	ToolTips::Classic $radioButton 'Also popular as "Menu" and "Context Menu"'
	${createKeyPanelButton} $R1 65u 20% 11u "Pause/Break"
	${createKeyPanelButton} $R0 76u 26% 11u "None"

	ReadRegStr $0 HKCU "Software\WkbLayout" "$R2"
	${If} $0 == ""
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

Function wkbSettingsPage
	nsArray::Split keyNameList "Caps|Scroll|RCtrl|RAlt|RWin|RShift|LCtrl|LAlt|LWin|LShift|Apps|Pause|00" "|"
	nsDialogs::Create 1018

	${NSD_CreateGroupBox} 0 0 49% 90u "Change layout key"
	${createKeyPanel} 2% 28% "ToggleKey"
	StrCpy $R0 "1"
	${If} ${AtLeastWinVista}  # or 7even?
		ReadRegStr $0 HKCU "Control Panel\Accessibility\Keyboard Preference" "On"
	${EndIf}
	# without the dotted border, focusing is counter-intuitive
	${IfThen} $0 == "1" ${|} ${NSD_SetFocus} $radioButton ${|}
	${nsArray_Copy} keyPanel togglePanel

	${NSD_CreateGroupBox} 51% 0 49% 90u "Shift-change key"
	${createKeyPanel} 53% 79% "ShiftKey"
	${nsArray_Copy} keyPanel shiftPanel
	${ForEach} $R0 4 8 + 4
		nsArray::Get shiftPanel $R0
		Pop $radioButton
		ToolTips::Classic $radioButton "Not recommended as a shift-change key"
	${Next}

	${NSD_CreateLabel} 0 93u 99% 8u "Please select key(s) that will not be used for any regular functions"
	${NSD_CreateHLine} 0 104u 100% 1u

	${NSD_CreateCheckBox} 0 107u 99% 23u "Use the Scroll Lock led as a keyboard layout indicator$\n\
		Uncheck this if you use programs that rely on the Scroll Lock state (rare)"
	Pop $ledLight
	${NSD_AddStyle} $ledLight ${WS_GROUP}
	ReadRegStr $0 HKCU "Software\WkbLayout" "LedLight"
	${If} $0 != "No"
		${NSD_Check} $ledLight
	${EndIf}

	nsDialogs::Show
FunctionEnd

!macro writeRegSettingMacro name value
	WriteRegStr HKCU Software\WkbLayout "${name}" "${value}"
	${If} ${Errors}
		MessageBox MB_OK|MB_ICONSTOP "Failed to write ${name} to the registry."
	${EndIf}
!macroend

!define writeRegSetting `!insertmacro writeRegSettingMacro`

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

	${If} $shiftKey == "RWin"
	${OrIf} $shiftKey == "LWin"
		MessageBox MB_YESNO|MB_ICONEXCLAMATION|MB_DEFBUTTON2 "Using the Left or Right Windows as \
			a shift-change key is not recommended. It conflicts with the build-in operating \
			system Windows+Key combinations, most notably Win+L (lock screen).$\n$\n\
			Proceed anyway?" IDYES +2
		Abort
	${ElseIf} $toggleKey == "00"
	${AndIf} $shiftKey == "00"
	${AndIf} $R1 == ${BST_UNCHECKED}
		MessageBox MB_YESNO|MB_ICONQUESTION "These settings will keep WKB deactivated. Are you sure?" IDYES +2
		Abort
	${EndIf}

	${IfThen} $toggleKey != "" ${|} ${writeRegSetting} "ToggleKey" $toggleKey ${|}
	${IfThen} $shiftKey != ""${|} ${writeRegSetting} "ShiftKey" $shiftKey ${|}

	${If} $R1 == ${BST_CHECKED}
		${writeRegSetting} "LedLight" "Yes"
	${Else}
		${writeRegSetting} "LedLight" "No"
	${EndIf}
FunctionEnd
