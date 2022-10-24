/*
  Copyright (C) 2016-2020 Dimitar Toshkov Zhekov <dimitar.zhekov@gmail.com>

  This program is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include <stdio.h>
#include <string.h>
#define STRICT
#include <windows.h>

#define WKB_MINI_DLL __declspec(dllimport)
#include "wkb-hook.h"

static int timerDelay = 0;

#include "wkb-mwow.h"

static void fatal(const char *s)
{
	MessageBox(NULL, s, "wkb-mwow", MB_OK | MB_ICONERROR);
	ExitProcess(1);
}

static void checkFunc(const char *func, BOOL cond)
{
	if (!cond)
	{
		char s[0x100];

		snprintf(s, sizeof s, "%s failed with error code %lu.", func, (unsigned long) GetLastError());
		fatal(s);
	}
}

static HWND wkbWindow;
static const char *const WKB_CLASS_NAME = WOW_CLASS_NAME;
static const char *const WKB_WINDOW_NAME = WOW_WINDOW_NAME;
static HHOOK hWindowProc, hKeyboardProc;
static HINSTANCE hInstance, hLibrary;

static void connectLock(void)
{
	wkbWindow = CreateWindow(WKB_CLASS_NAME, WKB_WINDOW_NAME, WS_OVERLAPPED, 1, 1, 1, 1, NULL, NULL, hInstance, NULL);
	checkFunc("CreateWindow", wkbWindow != NULL);
	ShowWindow(wkbWindow, SW_HIDE);
	hWindowProc = SetWindowsHookEx(WH_CALLWNDPROC, windowProc, hLibrary, 0);
	checkFunc("SetWindowsHookEx(WH_CALLWNDPROC)", hWindowProc != NULL);
	// Looks like the 64-bit keyboardProc is enough, but the documentation
      // is not very clear, and having a 32-bit one will do no harm.
	hKeyboardProc = SetWindowsHookEx(WH_KEYBOARD, keyboardProc, hLibrary, 0);
	checkFunc("SetWindowsHookEx(WH_KEYBOARD)", hKeyboardProc != NULL);
}

static void disconnectHooks(void)
{
	checkFunc("UnhookWindowsHookEx(hWindowProc)", UnhookWindowsHookEx(hWindowProc));
	checkFunc("UnhookWindowsHookEx(hKeyboardProc)", UnhookWindowsHookEx(hKeyboardProc));
}

#include "wkb-proc-inc.c"

static int wowMain(void)
{
	WNDCLASS wkbClass = { 0 };
	BOOL rc;
	MSG msg;

	wkbClass.lpfnWndProc = wkbWindowProc;
	wkbClass.hInstance = hInstance;
	wkbClass.lpszClassName = WKB_CLASS_NAME;
	checkFunc("RegisterClass", RegisterClass(&wkbClass) != (ATOM) 0);

	hLibrary = GetModuleHandle("wkb-hk32.dll");
	connectLock();
	startTimer();

	while ((rc = GetMessage(&msg, NULL, 0, 0)) != 0 && rc != -1)
	{
		if (standardMainProc(&msg))
			continue;

		getFocus(DESKTOP_HOOKCONTROL | DESKTOP_CREATEWINDOW);
	}

	disconnectHooks();
	return rc ? 1 : msg.wParam;
}

int CALLBACK WinMain(HINSTANCE hThisInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	(void) hPrevInstance;
	(void) lpCmdLine;
	(void) nCmdShow;

	if (__argc != 2 || strcmp(__argv[1], WOW_ARGUMENT))
		fatal("This program should be started internally by wkb-mini.exe\n\nUsage: wkb-mwow " WOW_ARGUMENT);

	hInstance = hThisInstance;
	return wowMain();
}
