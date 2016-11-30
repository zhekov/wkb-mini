/* This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details. */

#include <windows.h>

#define WKB_MINI_DLL __declspec(dllexport)
#include "wkb-hook.h"

static UINT layoutMessage;

LRESULT CALLBACK windowProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	if (nCode == HC_ACTION)
	{
		const CWPSTRUCT *const cwp = (const CWPSTRUCT *) lParam;

		if (cwp->message == layoutMessage)
		{
			ActivateKeyboardLayout((HKL) cwp->lParam, 0);
			return TRUE;
		}
	}

	return CallNextHookEx(0, nCode, wParam, lParam);
}

LRESULT CALLBACK keyboardProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	if (nCode == HC_ACTION || nCode == HC_NOREMOVE)
		if (wParam == VK_SCROLL && ((lParam >> 16) & 0xFF) == 0xE0)
			return TRUE;

	return CallNextHookEx(0, nCode, wParam, lParam);
}

BOOL WINAPI DllMainCRTStartup(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
	(void) hinstDLL; (void) lpvReserved;

	if (fdwReason == DLL_PROCESS_ATTACH)
		layoutMessage = RegisterWindowMessage(WKB_LAYOUT_MESSAGE);

	return TRUE;
}
