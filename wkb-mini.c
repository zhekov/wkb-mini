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

#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#define STRICT
#include <windows.h>
#include <tlhelp32.h>

#define WKB_MINI_DLL __declspec(dllimport)
#include "wkb-hook.h"

#ifdef _WIN64
#include "wkb-mwow.h"
#endif

static inline BOOL keyPressed(BYTE key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }
static inline BOOL winKeyPressed(void) { return keyPressed(VK_LWIN) || keyPressed(VK_RWIN); }

static inline int windowClassEql(HWND hwnd, const char *className)
{
	char buffer[0x80];
	return GetClassName(hwnd, buffer, sizeof buffer) && strcmp(buffer, className) == 0;
}

static inline BOOL consoleWindow(HWND hWnd) { return windowClassEql(hWnd, "ConsoleWindowClass"); }

static inline void toggleScroll(void)
{
	// A real scan code can never be 0xE0, that's the extended-key scan code prefix.
	keybd_event(VK_SCROLL, 0xE0, KEYEVENTF_EXTENDEDKEY, 0);
	keybd_event(VK_SCROLL, 0xE0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
}

static BOOL lockScroll = TRUE;

static inline void clearScroll(void)
{
	if (lockScroll && (GetKeyState(VK_SCROLL) & 0x01))
		toggleScroll();
}

static inline void sendAsyncMessage(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	SendMessageTimeout(hWnd, message, wParam, lParam, SMTO_NORMAL, 40, NULL);
}

static UINT layoutMessage;

static inline void changeLayout(HWND hWnd, LPARAM layout)
{
	// layoutMessage doesn't work for the XP (only?) console, even
	// if the proper thread is used, but a CHANGEREQUEST works AFAICT.
	sendAsyncMessage(hWnd, consoleWindow(hWnd) ? WM_INPUTLANGCHANGEREQUEST : layoutMessage, 0, layout);
}

static BOOL notModifiedExcept(BYTE exc1, BYTE exc2)
{
	enum { MODIFIER_KEYS_COUNT = 8 };
	static const BYTE modifierKeys[MODIFIER_KEYS_COUNT] =
	{
		VK_LMENU, VK_RMENU, VK_LCONTROL, VK_RCONTROL, VK_LWIN, VK_RWIN,
		VK_LSHIFT, VK_RSHIFT
	};

	for (int i = 0; i < MODIFIER_KEYS_COUNT; i++)
	{
		BYTE key = modifierKeys[i];

		if (key != exc1 && key != exc2 && keyPressed(key))
			return FALSE;
	}

	return TRUE;
}

static BOOL pureToggle = FALSE, tabPressed = FALSE;

static LRESULT CALLBACK mouseLLProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	// The opposite is not true: MB+toggle switches the layout in all Windows-es.
	if (nCode == HC_ACTION && (wParam == WM_LBUTTONDOWN || wParam == WM_RBUTTONDOWN ||
		wParam == WM_MBUTTONDOWN || wParam == WM_XBUTTONDOWN))
	{
		pureToggle = FALSE;
	}

	return CallNextHookEx(0, nCode, wParam, lParam);
}

static unsigned toggleKey = VK_APPS, shiftKey = VK_APPS;
static int timerDelay = 0;
static HWND lastFocus = NULL;

static inline BOOL shouldRetainPress(BYTE key)
{
	switch (key)
	{
		case VK_LCONTROL :
		case VK_RCONTROL :
		case VK_LSHIFT :
		case VK_RSHIFT : return key != shiftKey;
		case VK_CAPITAL :
		case VK_SNAPSHOT : return key != shiftKey && !pureToggle;
		default : return FALSE;
	}
}

static inline BOOL shouldRetainRelease(BYTE key)
{
	switch (key)
	{
		case VK_LWIN : // fix Win state on 10 (8?) Win-L
		case VK_RWIN : return TRUE;
		case VK_LMENU : // unblock M-Tab, M-state on <= 7
		case VK_RMENU : return tabPressed || key != shiftKey;
		default : return shouldRetainPress(key);
	}
}

static BOOL isLockLogout(BYTE key)
{
	return (key == 'L' &&
			winKeyPressed() && notModifiedExcept(VK_LWIN, VK_RWIN)) ||
		((key == VK_DELETE || key == VK_DECIMAL) &&
			keyPressed(VK_MENU) && keyPressed(VK_CONTROL) && !keyPressed(VK_SHIFT) && !winKeyPressed());
}

static LRESULT CALLBACK keyboardLLProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	BOOL wmKeyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;

	if (nCode == HC_ACTION && (wmKeyDown || wParam == WM_KEYUP || wParam == WM_SYSKEYUP))
	{
		const KBDLLHOOKSTRUCT *const pkb = (const KBDLLHOOKSTRUCT *) lParam;
		const BYTE key = pkb->vkCode;

		if (key != VK_SCROLL || pkb->scanCode != 0xE0)
		{
			if (wmKeyDown && key != toggleKey)
				pureToggle = FALSE;

			if (key == toggleKey || key == shiftKey)
			{
				static BOOL toggleDown = FALSE, shiftDown = FALSE;
				static HWND shiftWindow = NULL;

				if (wmKeyDown)
				{
					if (key == toggleKey && !toggleDown)
					{
						// The right Alt may set a fake Left Control state.
						BYTE secondIgnore = (key == VK_RMENU) ? VK_LCONTROL : toggleKey;

						pureToggle = notModifiedExcept(toggleKey, secondIgnore);
						toggleDown = TRUE;
					}

					if (key == shiftKey && !shiftDown)
					{
						shiftWindow = GetForegroundWindow();
						changeLayout(shiftWindow, HKL_NEXT);
						shiftDown = TRUE;
					}

					tabPressed = (key == VK_TAB);

					if (!shouldRetainPress(key))
						return TRUE;
				}
				else
				{
					BOOL toggleHeld = toggleDown;
					BOOL shiftHeld = shiftDown;

					// The layout change may cause a fake left Control release,
					// so we need to update the key down states before that.
					toggleDown &= (key != toggleKey);
					shiftDown &= (key != shiftKey);

					if (key == toggleKey && toggleHeld && pureToggle)
					{
						if (toggleKey != shiftKey)
							changeLayout(GetForegroundWindow(), HKL_NEXT);
					}
					else if (key == shiftKey && shiftHeld)
					{
						changeLayout(shiftWindow, HKL_PREV);
						shiftWindow = NULL;
					}

					if (!shouldRetainRelease(key))
						return TRUE;
				}
			}
			else if (wmKeyDown)
			{
				if (isLockLogout(key))
				{
					clearScroll();
					timerDelay = 10;   // give lock time to kick in
					lastFocus = NULL;
				}
				else if (key == VK_TAB)
					tabPressed = TRUE;
			}
		}
	}

	return CallNextHookEx(0, nCode, wParam, lParam);
}

#ifdef __GNUC__
static void fatal(const char *format, ...) __attribute__ ((format(printf, 1, 2), noreturn));
#endif
static void fatal(const char *format, ...)
{
	va_list ap;
	char s[0x100];

	va_start(ap, format);
	vsnprintf(s, sizeof s, format, ap);
	va_end(ap);

	if (MessageBox(NULL, s, "wkb-mini", MB_OK | MB_ICONERROR) == 0)
		MessageBeep(MB_ICONERROR);

	ExitProcess(1);
}

static inline void checkFunc(const char *func, BOOL cond)
{
	if (!cond)
		fatal("%s failed with error code %lu.", func, (unsigned long) GetLastError());
}

static HWND wkbWindow;
static const char *const WKB_CLASS_NAME = "wkbMini83447E6D";
static const char *const WKB_WINDOW_NAME = "WkbMini45B95DF9";
static HHOOK hKeyboardLL, hMouseLL;
static HHOOK hWindowProc, hKeyboardProc;
static HINSTANCE hInstance, hLibrary;

static void connectLock(void)
{
	wkbWindow = CreateWindow(WKB_CLASS_NAME, WKB_WINDOW_NAME, WS_OVERLAPPED, 1, 1, 1, 1, NULL, NULL, hInstance, NULL);
	checkFunc("CreateWindow", wkbWindow != NULL);
	ShowWindow(wkbWindow, SW_HIDE);
	hKeyboardLL = SetWindowsHookEx(WH_KEYBOARD_LL, keyboardLLProc, hInstance, 0);
	checkFunc("SetWindowsHookEx(WH_KEYBOARD_LL)", hKeyboardLL != NULL);
	hMouseLL = SetWindowsHookEx(WH_MOUSE_LL, mouseLLProc, hInstance, 0);
	hWindowProc = SetWindowsHookEx(WH_CALLWNDPROC, windowProc, hLibrary, 0);
	checkFunc("SetWindowsHookEx(WH_CALLWNDPROC)", hWindowProc != NULL);
	hKeyboardProc = SetWindowsHookEx(WH_KEYBOARD, keyboardProc, hLibrary, 0);
	checkFunc("SetWindowsHookEx(WH_KEYBOARD)", hKeyboardProc != NULL);
}

static void disconnectHooks(void)
{
	checkFunc("UnhookWindowsHookEx(hKeyboardLL)", UnhookWindowsHookEx(hKeyboardLL));
	if (hMouseLL != NULL)
		checkFunc("UnhookWindowsHookEx(hMouseLL)", UnhookWindowsHookEx(hMouseLL));
	checkFunc("UnhookWindowsHookEx(hWindowProc)", UnhookWindowsHookEx(hWindowProc));
	checkFunc("UnhookWindowsHookEx(hKeyboardProc)", UnhookWindowsHookEx(hKeyboardProc));
}

#include "wkb-proc-inc.c"

#ifdef _WIN64
static void startWowHelper(void)
{
	STARTUPINFO startupInfo = { 0 };
	PROCESS_INFORMATION processInfo;

	startupInfo.cb = sizeof startupInfo;
	checkFunc("CreateProcess", CreateProcess(NULL, "wkb-mwow.exe " WOW_ARGUMENT, NULL, NULL, FALSE,
		NORMAL_PRIORITY_CLASS, NULL, NULL, &startupInfo, &processInfo));
	CloseHandle(processInfo.hThread);
	CloseHandle(processInfo.hProcess);
}
#endif

static BOOL CALLBACK compareHWnd(HWND hwnd, LPARAM lParam)
{
	return hwnd != (HWND) lParam;
}

static DWORD layoutThread = 0;

static void getConsoleThread(HWND focus)
{
	// For the console layout, we need a thread that contains the foreground
	// window, but is different from the window thread. Don't ask me why.
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);

	if (snap != INVALID_HANDLE_VALUE)
	{
		THREADENTRY32 tentry;
		tentry.dwSize = sizeof tentry;

		if (Thread32First(snap, &tentry))
		{
			do
			{
				if (tentry.th32ThreadID && tentry.th32ThreadID != layoutThread &&
					!EnumThreadWindows(tentry.th32ThreadID, compareHWnd, (LPARAM) focus))
				{
					layoutThread = tentry.th32ThreadID;
					break;
				}
			} while (Thread32Next(snap, &tentry));
		}

		CloseHandle(snap);
	}
}

static BOOL regOpenUserKey(const char *name, PHKEY phKey, const char *where)
{
	LONG result = RegOpenKeyEx(HKEY_CURRENT_USER, name, 0, KEY_QUERY_VALUE, phKey);

	if (result == ERROR_SUCCESS)
		return TRUE;

	if (result != ERROR_FILE_NOT_FOUND)
		fatal("RegOpenKeyEx(%s) failed with error code %ld.", where, (long) result);

	return FALSE;
}

enum { REG_BUFFER_SIZE = 11 };

static BOOL regReadString(HKEY hKey, const char *name, char *buffer, const char *where)
{
	DWORD type, size = REG_BUFFER_SIZE;
	LONG result = RegQueryValueEx(hKey, name, 0, &type, (BYTE *) buffer, &size);

	if (result == ERROR_SUCCESS)
	{
		if (type != REG_SZ)
			fatal("RegQueryValueEx(%s\\%s): invalid type", where, name);

		if (*buffer == '\0')
			fatal("RegQueryValueEx(%s\\%s): invalid value", where, name);

		return TRUE;
	}
	else if (result != ERROR_FILE_NOT_FOUND)
		fatal("RegQueryValueEx(%s\\%s) failed with error code %ld.", where, name, (long) result);

	return FALSE;
}

static BOOL fixLayouts = FALSE;

static void unloadWrongLayouts(void)
{
	HKEY hKey;

	if (regOpenUserKey("Keyboard Layout\\Preload", &hKey, "Preload"))
	{
		enum { MAX_LAYOUTS = 64 };
		DWORD nUserLayouts;
		WORD userLayouts[MAX_LAYOUTS];

		for (nUserLayouts = 0; nUserLayouts <= MAX_LAYOUTS; nUserLayouts++)
		{
			char name[REG_BUFFER_SIZE];
			char buffer[REG_BUFFER_SIZE];
			char *endptr;
			DWORD value;

			itoa(nUserLayouts + 1, name, 10);

			if (!regReadString(hKey, name, buffer, "Preload"))
				break;

			value = strtoul(buffer, &endptr, 0x10);

			if (strlen(buffer) > 8 || value == HKL_PREV || value == HKL_NEXT || *endptr != '\0')
				fatal("RegQueryValueEx(Preload\\%s): invalid value", name);

			if (nUserLayouts < MAX_LAYOUTS)
				userLayouts[nUserLayouts] = LOWORD(value);
		}

		RegCloseKey(hKey);

		if (nUserLayouts >= 1 && nUserLayouts <= MAX_LAYOUTS)
		{
			HKL unlockLayouts[MAX_LAYOUTS];
			DWORD nUnlockLayouts = GetKeyboardLayoutList(MAX_LAYOUTS, unlockLayouts);

			for (DWORD n = 0; n < nUnlockLayouts; n++)
			{
				if (n >= nUserLayouts)
					UnloadKeyboardLayout(unlockLayouts[n]);
				else if (LOWORD(unlockLayouts[n]) != userLayouts[n])
					break;
			}
		}
	}
}

static int wkbMainLoop(void)
{
	HKL defaultLayout = GetKeyboardLayout(GetCurrentThreadId());
	BOOL rc;
	MSG msg;

	while ((rc = GetMessage(&msg, NULL, 0, 0)) != 0 && rc != -1)
	{
		if (standardMainProc(&msg))
			continue;

		// PLAYBACK is required for keybd_event()
		HWND focus = getFocus(DESKTOP_HOOKCONTROL | DESKTOP_JOURNALPLAYBACK | DESKTOP_CREATEWINDOW);

		if (focus != NULL)
		{
			if (lockScroll)
			{
				HKL layout;

				if (focus != lastFocus)
				{
					layoutThread = GetWindowThreadProcessId(focus, NULL);

					if (consoleWindow(focus))
						getConsoleThread(focus);
				}

				layout = GetKeyboardLayout(layoutThread);

				if (layout != 0 && (GetKeyState(VK_SCROLL) & 0x01) != (layout != defaultLayout))
					toggleScroll();
			}

			if (fixLayouts && lastFocus == NULL)
				unloadWrongLayouts();
		}

		lastFocus = focus;
	}

	return rc ? 1 : msg.wParam;
}

static int wkbMain(void)
{
	WNDCLASS wkbClass = { 0 };
	BOOL rc;

	// WM_INPUTLANGCHANGEREQUEST does not work for many dialogs, especially if the user is not
      // a full administrator. The idea for using a custom message is from Eugene's "keyla".
	checkFunc("RegisterWindowMessage", (layoutMessage = RegisterWindowMessage(WKB_LAYOUT_MESSAGE)) != 0);

	wkbClass.lpfnWndProc = wkbWindowProc;
	wkbClass.hInstance = hInstance;
	wkbClass.lpszClassName = WKB_CLASS_NAME;
	checkFunc("RegisterClass", RegisterClass(&wkbClass) != (ATOM) 0);

	hLibrary = GetModuleHandle("wkb-hook.dll");
	connectLock();
	startTimer();
#ifdef _WIN64
	startWowHelper();
#endif
	rc = wkbMainLoop();
	disconnectHooks();
	clearScroll();
	return rc;
}

enum { KEY_UNDEF = 0xFFFF };

static unsigned translateKey(const char *str)
{
	static struct keyName
	{
		WPARAM key;
		const char *name;
	} keyNames[] =
	{
		{ VK_APPS,     "Apps" },
		{ VK_APPS,     "Props" },  // for compatibility
		{ VK_SCROLL,   "Scroll" },
		{ VK_RCONTROL, "RCtrl" },
		{ VK_RMENU,    "RAlt" },
		{ VK_RWIN,     "RWin" },
		{ VK_RSHIFT,   "RShift" },
		{ VK_LCONTROL, "LCtrl" },
		{ VK_LMENU,    "LAlt" },
		{ VK_LWIN,     "LWin" },
		{ VK_LSHIFT,   "LShift" },
		{ VK_PAUSE,    "Pause" },
		{ VK_CAPITAL,  "Caps" },
		{ VK_SNAPSHOT, "Print" },
		{ 0, NULL }
	};

	int i = (str[0] == '0' && toupper(str[1]) == 'X') ? 2 : 0;

	for (struct keyName *kn = keyNames; kn->name; kn++)
		if (!_stricmp(str, kn->name))
			return kn->key;

	if (isxdigit(str[i]) && isxdigit(str[i + 1]) && str[i + 2] == '\0')
		return strtoul(str + i, NULL, 0x10);

	return KEY_UNDEF;
}

static const char *const USAGE =
	"Usage: wkb-mini [/T:KEY] [/S:KEY] [/N|/I] [/O|/U]\n"
	"\n"
	"/T - switch layout key\n"
	"/S - shift-switch key\n"
	"\n"
	"KEY = Apps (Props), Scroll, RCtrl, RAlt, RWin, RShift, LCtrl, LAlt, LWin,\n"
	"LShift, Pause, Caps, Print or a 2-digit winuser.h VK_ hex value (00 = none).\n"
	"\n"
	"Using LWin or RWin as a shift-switch key is NOT recommended\n"
	"\n"
	"/N - Do not use the Scroll Lock led as a keyboard layout indicator,\n"
	"/I - Use the Scroll Lock led as an indicator.\n"
	"\n"
	"/O - Do not unload layouts added by lock/unlock screen,\n"
	"/U - Unload layouts added by lock/unlock screen."
	"\n"
	"/S:00 /T:00 /N /O - unload wkb-mini from memory.";

static const char *parseArguments(int argc, char **argv)
{
	while (--argc > 0)
	{
		const char *const arg = *++argv;

		if (arg[0] != '/')
			return arg;

		switch (toupper(arg[1]))
		{
			case '?' :
			{
				MessageBox(NULL, USAGE, "wkb-mini", MB_OK);
				ExitProcess(0);
			}
			case 'T' :
			case 'S' :
			{
				unsigned *key = (toupper(arg[1]) == 'T') ? &toggleKey : &shiftKey;

				if (arg[2] != ':' || (*key = translateKey(arg + 3)) == KEY_UNDEF)
					return arg;

				break;
			}
			case 'N' : lockScroll = FALSE; break;
			case 'I' : lockScroll = TRUE; break;
			case 'O' : fixLayouts = FALSE; break;
			case 'U' : fixLayouts = TRUE; break;
			default : return arg;
		}
	}

	return NULL;
}

static unsigned obtainKey(HKEY hKey, const char *name)
{
	char buffer[REG_BUFFER_SIZE];
	unsigned key = VK_APPS;

	if (regReadString(hKey, name, buffer, "WkbLayout") && (key = translateKey(buffer)) == KEY_UNDEF)
		fatal("RegQueryValueEx(WkbLayout\\%s): invalid value", name);

	return key;
}

static void readSettings(void)
{
	HKEY hKey;

	if (regOpenUserKey("Software\\WkbLayout", &hKey, "WkbLayout"))
	{
		char buffer[REG_BUFFER_SIZE];

		toggleKey = obtainKey(hKey, "ToggleKey");
		shiftKey = obtainKey(hKey, "ShiftKey");

		if (regReadString(hKey, "LedLight", buffer, "WkbLayout"))
			lockScroll = _stricmp(buffer, "No");

		if (regReadString(hKey, "FixLayouts", buffer, "WkbLayout"))
			fixLayouts = !_stricmp(buffer, "Yes");

		RegCloseKey(hKey);
	}
}

static inline void findWkbWindows(HWND *windows)
{
	windows[0] = FindWindow(WKB_CLASS_NAME, WKB_WINDOW_NAME);
#ifdef _WIN64
	windows[1] = FindWindow(WOW_CLASS_NAME, WOW_WINDOW_NAME);
#endif
}

// EnumWindows and all desktop functions may return FALSE without setting the last
// error (unless we consider values like 106, 6 and even 0 to be valid errors).
// So we avoid EnumWindows, and ignore/handle some FALSE-s instead of terminating.

static BOOL CALLBACK enumDesktop(LPSTR desktopName, LPARAM lParam)
{
	HDESK desktop = OpenDesktop(desktopName, 0, FALSE, 0);
	HWND *windows = (HWND *) lParam;

	if (desktop)
	{
		if (SetThreadDesktop(desktop))
			findWkbWindows(windows);

		CloseHandle(desktop);
	}

	return windows[0] == NULL && windows[1] == NULL;
}

static BOOL unloadWkbs(void)
{
	HDESK desktop = GetThreadDesktop(GetCurrentThreadId());
	DWORD interval = getTimerInterval();
	unsigned found = 0;

	for (;;)
	{
		HWND windows[2] = { NULL, NULL };

		EnumDesktops(GetProcessWindowStation(), enumDesktop, (LPARAM) windows);
		SetThreadDesktop(desktop);

		if (windows[0] == NULL && windows[1] == NULL)
			findWkbWindows(windows);

		if (windows[0] == NULL && windows[1] == NULL)
			break;

		if (found++ == 5)
		{
			fatal("Failed to unload %s from memory.\n"
				"You may need administrator rights.",
				windows[0] != NULL ? "wkb-mini" : "wkb-mwow");
		}

		if (windows[0] != NULL)
			sendAsyncMessage(windows[0], WM_CLOSE, 0, 0);

		if (windows[1] != NULL)
			sendAsyncMessage(windows[1], WM_CLOSE, 0, 0);

		Sleep(interval + 10);
	}

	CloseHandle(desktop);
	return found > 0;
}

int CALLBACK WinMain(HINSTANCE hThisInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	BOOL applyArg = (__argc == 2) && !strcmp(__argv[1], "/wkb:apply");
	const char *badArgument;
	BOOL anyUnloaded;

	(void) hPrevInstance;
	(void) lpCmdLine;
	(void) nCmdShow;

	readSettings();

	if (!applyArg && (badArgument = parseArguments(__argc, __argv)) != NULL)
		fatal("Invalid argument: %s", badArgument);

	anyUnloaded = unloadWkbs();
	hInstance = hThisInstance;
	// Don't start if (a) nothing to do or (b) apply only, and there were no WKB-s running.
	return (toggleKey || shiftKey || lockScroll || fixLayouts) && (!applyArg || anyUnloaded) ? wkbMain() : 0;
}
