#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#define STRICT
#include <windows.h>

#ifdef __GNUC__
static void fatal(const char *format, ...) __attribute__ ((format(printf, 1, 2), noreturn));
#endif
static void fatal(const char *format, ...)
{
	va_list ap;
	char s[0x100];

	va_start(ap, format);
	if (vsnprintf(s, sizeof s, format, ap) == sizeof s - 1)
		memset(s + sizeof s - 4, '.', 3);
	va_end(ap);

	if (MessageBox(NULL, s, PROGRAM_NAME, MB_OK | MB_ICONERROR) == 0)
		MessageBeep(MB_ICONERROR);

	ExitProcess(1);
}

static inline void checkFunc(const char *func, BOOL cond)
{
	if (!cond)
		fatal("%s failed with error code %lu.", func, (unsigned long) GetLastError());
}
