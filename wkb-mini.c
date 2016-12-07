/* This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details. */

/* Q: How many years of CEIP will it take to write a normal keyboard switcher? */

#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <windows.h>
#include <tlhelp32.h>

#define WKB_MINI_DLL __declspec(dllimport)
#include "wkb-hook.h"

#ifdef _WIN64
#include "wkb-mwow.h"
#endif

static void toggleScroll(void)
{
	/* A real scan code can never be 0xE0, that's the extended-key scan code prefix. */
	keybd_event(VK_SCROLL, 0xE0, KEYEVENTF_EXTENDEDKEY, 0);
	keybd_event(VK_SCROLL, 0xE0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
}

static int lockScroll = TRUE;

static void clearScroll(void)
{
	if (lockScroll && (GetKeyState(VK_SCROLL) & 0x01))
		toggleScroll();
}

static BOOL consoleWindow(HWND hWnd)
{
	char name[20];

	return GetClassName(hWnd, name, sizeof name) == 18 && !strcmp(name, "ConsoleWindowClass");
}

#define sendAsyncMessage(hWnd, message, wParam, lParam) \
	SendMessageTimeout((hWnd), (message), (wParam), (lParam), 0, 100, NULL)

static UINT layoutMessage;

static void changeLayout(HWND hWnd, LPARAM layout)
{
	/* layoutMessage doesn't work for the XP (only?) console, even if the proper
	   thread is used, but a CHANGEREQUEST always works for the consoles AFAICT. */
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

	int i;

	for (i = 0; i < MODIFIER_KEYS_COUNT; i++)
	{
		BYTE key = modifierKeys[i];

		if (key != exc1 && key != exc2 && (GetAsyncKeyState(key) & 0x8000))
			return FALSE;
	}

	return TRUE;
}

static BOOL pureToggle = FALSE, tabPressed = FALSE;

static LRESULT CALLBACK mouseLLProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	/* The opposite is not true: MB+toggle switches the layout in all Windows-es. */
	if (nCode == HC_ACTION && (wParam == WM_LBUTTONDOWN || wParam == WM_RBUTTONDOWN ||
		wParam == WM_MBUTTONDOWN || wParam == WM_XBUTTONDOWN))
	{
		pureToggle = FALSE;
	}

	return CallNextHookEx(0, nCode, wParam, lParam);
}

static unsigned toggleKey = VK_APPS, shiftKey = VK_APPS;
static int timerDelay = 0;

static BOOL shouldRetainPress(DWORD key)
{
	switch (key)
	{
		case VK_LCONTROL :
		case VK_RCONTROL :
		case VK_LSHIFT :
		case VK_RSHIFT : return key != shiftKey;
		default : return FALSE;
	}
}

static BOOL shouldRetainRelease(DWORD key)
{
	switch (key)
	{
		case VK_LWIN : /* fix Win state on 10 (8?) Win-L */
		case VK_RWIN : return TRUE;
		case VK_LMENU : /* unblock M-Tab, M-state on <= 7 */
		case VK_RMENU : return tabPressed || key != shiftKey;
		default : return shouldRetainPress(key);
	}
}

#define eitherPressed(key1, key2) ((GetAsyncKeyState(key1) | GetAsyncKeyState(key2)) & 0x8000)

static BOOL isLockLogout(BYTE key)
{
	return (key == 'L' && eitherPressed(VK_LWIN, VK_RWIN) && notModifiedExcept(VK_LWIN, VK_RWIN)) ||
		/* Ctrl-Alt-Del with other shifts is unlikely, the check is 
		   too long, and there is no harm if Scroll blinks a bit. */
		((key == VK_DELETE || key == VK_DECIMAL) && eitherPressed(VK_LMENU, VK_RMENU) &&
		eitherPressed(VK_LCONTROL, VK_RCONTROL));
}

static LRESULT CALLBACK keyboardLLProc(INT nCode, WPARAM wParam, LPARAM lParam)
{
	BOOL wmKeyDown = wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN;

	if (nCode == HC_ACTION && (wmKeyDown || wParam == WM_KEYUP || wParam == WM_SYSKEYUP))
	{
		const KBDLLHOOKSTRUCT *const pkb = (const KBDLLHOOKSTRUCT *) lParam;
		DWORD key = pkb->vkCode;

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
						/* The right Alt may set a fake left control state. */
						BYTE secondIgnore = (key == VK_RMENU) ? VK_LCONTROL : 0;

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

					/* The layout change may cause a fake left Control release,
					   so we need to update the key down states before that. */
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
					timerDelay = 10;  /* give lock time to kick in */
				}
				else if (key == VK_TAB)
					tabPressed = TRUE;
			}
		}
	}

	return CallNextHookEx(0, nCode, wParam, lParam);
}

static BOOL CALLBACK compareHWnd(HWND hwnd, LPARAM lParam)
{
	return hwnd != (HWND) lParam;
}

#ifdef __GNUC__
static void fatal(const char *format, ...) __attribute__ ((format(printf, 1, 2)));
#endif
static void fatal(const char *format, ...)
{
	va_list ap;
	char s[0x80];

	va_start(ap, format);
	vsnprintf(s, sizeof s, format, ap);
	va_end(ap);

	if (MessageBox(NULL, s, "wkb-mini", MB_OK | MB_ICONERROR) == 0)
		MessageBeep(MB_ICONERROR);

	ExitProcess(1);
}

static void checkFunc(const char *func, BOOL cond)
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
	CloseHandle(processInfo.hProcess);
	CloseHandle(processInfo.hThread);
}
#endif

static int wkbMain(void)
{
	WNDCLASS wkbClass = { 0 };
	HKL defaultLayout;
	HWND lastFocus = NULL;
	DWORD layoutThread = 0;
	BOOL rc;
	MSG msg;

	/* WM_INPUTLANGCHANGEREQUEST does not work for many dialogs, especially if the user is not
         a full administrator. The idea for using a custom message is from Eugene's "keyla". */
	checkFunc("RegisterWindowMessage", (layoutMessage = RegisterWindowMessage(WKB_LAYOUT_MESSAGE)) != 0);

	wkbClass.lpfnWndProc = wkbWindowProc;
	wkbClass.hInstance = hInstance;
	wkbClass.lpszClassName = WKB_CLASS_NAME;
	checkFunc("RegisterClass", RegisterClass(&wkbClass) != (ATOM) 0);

	hLibrary = GetModuleHandle("wkb-hook.dll");
	connectLock();
	startTimer();
	defaultLayout = GetKeyboardLayout(GetCurrentThreadId());
#ifdef _WIN64
	startWowHelper();
#endif

	while ((rc = GetMessage(&msg, NULL, 0, 0)) != 0 && rc != -1)
	{
		HWND focus;

		if (standardMainProc(&msg))
			continue;

		/* PLAYBACK is required for keybd_event() */
		focus = getFocus(DESKTOP_HOOKCONTROL | DESKTOP_JOURNALPLAYBACK | DESKTOP_CREATEWINDOW);

		if (focus && lockScroll)
		{
			HKL layout;

			if (focus != lastFocus)
			{
				layoutThread = GetWindowThreadProcessId(focus, NULL);

				if (consoleWindow(focus))
				{
					/* For the console layout, we need a thread that contains the foreground
					   window, but is different from the window thread. Don't ask me why. */
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
			}

			layout = GetKeyboardLayout(layoutThread);

			if (layout != 0 && (GetKeyState(VK_SCROLL) & 0x01) != (layout != defaultLayout))
				toggleScroll();
		}

		lastFocus = focus;
	}

	disconnectHooks();
	clearScroll();
	return rc ? 1 : msg.wParam;
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
		{ VK_APPS, "Apps" },
		{ VK_APPS, "Props" },  /* for compatibility */
		{ VK_SCROLL, "Scroll" },
		{ VK_RCONTROL, "RCtrl" },
		{ VK_RMENU, "RAlt" },
		{ VK_RWIN, "RWin" },
		{ VK_RSHIFT, "RShift" },
		{ VK_LCONTROL, "LCtrl" },
		{ VK_LMENU, "LAlt" },
		{ VK_LWIN, "LWin" },
		{ VK_LSHIFT, "LShift" },
		{ VK_PAUSE, "Pause" },
		{ 0, NULL }
	};

	struct keyName *k;
	int i = str[0] == '0' && toupper(str[1]) == 'X' ? 2 : 0;

	for (k = keyNames; k->name; k++)
		if (!_stricmp(str, k->name))
			return k->key;

	if (isxdigit(str[i]) && isxdigit(str[i + 1]) && str[i + 2] == '\0')
		return strtol(str + i, NULL, 0x10);

	return KEY_UNDEF;
}

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
				static const char *const USAGE =
					"Usage: wkb-mini [/T:KEY] [/S:KEY] [/N|/I]\n"
					"\n"
					"/T - switch layout key\n"
					"/S - shift-switch key\n"
					"\n"
					"KEY = Apps (Props), Scroll, RCtrl, RAlt, RWin, RShift, LCtrl, LAlt, LWin,\n"
					"LShift, Pause or a two-digit winuser.h VK_ hex value (00 = none).\n"
					"\n"
					"Using LWin or RWin as a shift-switch key is NOT recommended\n"
					"\n"
					"/N - Do not use the Scroll Lock led as a keyboard layout indicator,\n"
					"/I - Use the Scroll Lock led as an indicator.\n"
					"\n"
					"/S:00 /T:00 /N - unloads wkb-mini from memory.";

				MessageBox(NULL, USAGE, "wkb-mini", MB_OK);
				ExitProcess(0);
			}
			case 'T' :
			case 'S' :
			{
				unsigned *key = toupper(arg[1]) == 'T' ? &toggleKey : &shiftKey;

				if (arg[2] != ':' || (*key = translateKey(arg + 3)) == KEY_UNDEF)
					return arg;

				break;
			}
			case 'N' : lockScroll = FALSE; break;
			case 'I' : lockScroll = TRUE; break;
			default : return arg;
		}
	}

	return NULL;
}

#define REG_BUFFER_SIZE 11

static BOOL regReadValue(HKEY hKey, const char *name, char *buffer)
{
	DWORD type, size = REG_BUFFER_SIZE;
	LONG result = RegQueryValueEx(hKey, name, 0, &type, (BYTE *) buffer, &size);

	if (result == ERROR_SUCCESS)
		return TRUE;

	checkFunc("RegQueryValueEx", result == ERROR_FILE_NOT_FOUND);
	return FALSE;
}

static unsigned obtainKey(HKEY hKey, const char *name)
{
	char keyBuffer[REG_BUFFER_SIZE];
	unsigned key = VK_APPS;

	if (regReadValue(hKey, name, keyBuffer) && (key = translateKey(keyBuffer)) == KEY_UNDEF)
		fatal("Invalid registry value: %s = %s", name, keyBuffer);

	return key;
}

static void readSettings(void)
{
	HKEY hKey;
	LONG result = RegOpenKeyEx(HKEY_CURRENT_USER, "Software\\WkbLayout", 0, KEY_QUERY_VALUE, &hKey);

	if (result != ERROR_SUCCESS)
		checkFunc("RegOpenKeyEx", result == ERROR_FILE_NOT_FOUND || result == ERROR_PATH_NOT_FOUND);
	else
	{
		char ledBuffer[REG_BUFFER_SIZE];

		toggleKey = obtainKey(hKey, "ToggleKey");
		shiftKey = obtainKey(hKey, "ShiftKey");

		if (regReadValue(hKey, "LedLight", ledBuffer))
			lockScroll = _stricmp(ledBuffer, "No");
	}
}

static void findWkbWindows(HWND *windows)
{
	windows[0] = FindWindow(WKB_CLASS_NAME, WKB_WINDOW_NAME);
#ifdef _WIN64
	windows[1] = FindWindow(WOW_CLASS_NAME, WOW_WINDOW_NAME);
#endif
}

/* EnumWindows and all desktop functions may return FALSE without setting the last
   error (unless we consider values like 106, 6 and even 0 to be valid errors). So
   we avoid EnumWindows, and ignore/handle some FALSE-s instead of terminating. */

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
	UINT interval = getTimerInterval();
	int clean = 0, found = 0;

	checkFunc("GetThreadDesktop", desktop != NULL);
	do
	{
		HWND windows[2] = { NULL, NULL };

		EnumDesktops(GetProcessWindowStation(), enumDesktop, (LPARAM) windows);

		if (windows[0] == NULL && windows[1] == NULL)
			findWkbWindows(windows);

		if (windows[0] != NULL || windows[1] != NULL)
		{
			if (++found % 5 == 0)
			{
				fatal("Failed to unload %s from memory.\n"
					"You may need administrator rights.",
					windows[0] ? "wkb-mini" : "wkb-mwow");
			}

			if (windows[0])
				sendAsyncMessage(windows[0], WM_CLOSE, 0, 0);

			if (windows[1])
				sendAsyncMessage(windows[1], WM_CLOSE, 0, 0);

			Sleep(50);
			clean = 0;  /* found something, restart the search */
		}
		else
		{
			Sleep(interval + 10);
			clean++;
		}
	} while (clean < 5);

	SetThreadDesktop(desktop);
	CloseHandle(desktop);
	return found > 0;
}

int CALLBACK WinMain(HINSTANCE hThisInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	BOOL applyArg = __argc == 2 && !strcmp(__argv[1], "/wkb:apply");
	const char *badArgument;
	BOOL anyUnloaded;

	(void) hPrevInstance; (void) lpCmdLine; (void) nCmdShow;

	readSettings();

	if (!applyArg && (badArgument = parseArguments(__argc, __argv)) != NULL)
		fatal("Invalid argument: %s", badArgument);

	anyUnloaded = unloadWkbs();
	hInstance = hThisInstance;
	/* Don't start if (a) /S:00 /T:00 /N or (b) apply only, and there were no WKB-s running. */
	return (toggleKey || shiftKey || lockScroll) && (!applyArg || anyUnloaded) ? wkbMain() : 0;
}
