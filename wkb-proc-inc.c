static UINT getTimerInterval(void)
{
	SYSTEM_POWER_STATUS powerStat;
	UINT interval = 70;

	if (GetSystemPowerStatus(&powerStat))
	{
		if (powerStat.ACLineStatus == 1)
			interval = 40;
		else if (powerStat.ACLineStatus == 0)
			interval = 100;
	}

	return interval;
}

static UINT_PTR timerId = 0;

static void startTimer(void)
{
	checkFunc("SetTimer", (timerId = SetTimer(NULL, 0, getTimerInterval(), NULL)) != 0);
}

static LRESULT CALLBACK wkbWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	if (uMsg == WM_POWERBROADCAST)
	{
		if (wParam == PBT_APMRESUMEAUTOMATIC || wParam == PBT_APMPOWERSTATUSCHANGE)
		{
			timerDelay = 0;
			startTimer();
		}
		else if (wParam == PBT_APMSUSPEND && timerId)
		{
			KillTimer(NULL, timerId);
			timerId = 0;
		}
	}
	else if (uMsg == WM_CLOSE)  /* destroy is used in reconnect */
		PostQuitMessage(0);

	return DefWindowProc(hWnd, uMsg, wParam, lParam);
}

static BOOL standardMainProc(MSG *msg)
{
	if (msg->message != WM_TIMER)
	{
		TranslateMessage(msg);
		DispatchMessage(msg);
		return TRUE;
	}

	if (!timerId)
		return TRUE;

	if (timerDelay > 0)
	{
		timerDelay--;
		return TRUE;
	}

	return FALSE;
}

static void getDesktopName(HDESK desktop, char *buffer, size_t size)
{
	DWORD needed;

	if (!GetUserObjectInformation(desktop, UOI_NAME, buffer, size, &needed))
		*buffer = '\0';
}

static HWND getFocus(DWORD desktopAccess)
{
	HWND focus = GetForegroundWindow();

	if (!focus)
	{
		HDESK desktop = OpenInputDesktop(0, FALSE, desktopAccess);

		if (desktop)
		{
			char inputDesktopName[0x100];
			char threadDesktopName[0x100];

			getDesktopName(desktop, inputDesktopName, sizeof inputDesktopName);
			getDesktopName(GetThreadDesktop(GetCurrentThreadId()), threadDesktopName, sizeof threadDesktopName);

			if (*inputDesktopName == '\0' || strcmp(inputDesktopName, threadDesktopName))
			{
				disconnectHooks();
				checkFunc("DestroyWindow", DestroyWindow(wkbWindow));

				if (!SetThreadDesktop(desktop))
					timerDelay = 5;

				connectLock();
			}

			CloseHandle(desktop);
			focus = GetForegroundWindow();
		}
	}

	return focus;
}
