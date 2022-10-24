Discontinued. Use https://github.com/zhekov/wkb-micro instead.


WKB Layout Switcher (wkb-mini) README file
**Please** spare a minute to read p.1 to 3


1. Antivirus warnings.

As a keyboard switcher, WKB needs access to the keyboard, and to the input
queues of all threads. So, an antivirus may mistake it for a key logger or
another malware. If you are suspicious, get the source code and compile it
yourself (see p.5 below), or ask somebody to do so. "It's the only way to
be sure".


2. User accounts.

WKB does not affect the programs started "as administrator" (unless it's
also started as administrator). It does not work in the Login, Lock and
Ctrl-Alt-Del screens, though the non-default layout may be retained, and the
Scroll Lock light may remain on. You can change them via the normal means.

Whether WKB will work in the UAC prompts and in Windows (File) Explorer
started "as administrator" depends on your Windows version and settings.


3. Power usage.

WKB constantly checks whether the current desktop is valid, and attemps to
re-connect to it if needed. It checks less frequently on battery power, but
may still affect the battery life. You have been warned.


--- Less important points ---


4. Uninstallation.

Unloading WKB from memory and deleting of it's files may fail, be it because
another user on the same computer uses it, or because Windows keeps some
files locked. If that happens, run the uninstaller again after the computer
is restarted or all users log (sign) off, and it'll complete the job.


5. Compilation.

To compile WKB, you will need the GNU make, gcc 32-bit, and gcc 64-bit for
the 64-bit version. Use the supplied Makefile-s to build WKB, correcting the
tool names if needed, for example:

C:\...> mingw32-make.exe -f Makefile.gcc32 GCC32=path/to/executable/gcc.exe

To create the installation package, you will need the Nullsoft Install
System (NSIS) version 2.46 or later, with the nsArray and Tooltips plugins.
After building WKB, compile settings.nsi, and then either install-32.nsi or
install-64.nsi.

The compilation is not a trivial process, so if you have problems, please
consult with a specialist.


6. Compatibility.

Requires Windows 2000 or later.
Tested with Windows XP, 7 and 10.
Tested with Metro (Modern) applications.
Tested with virtual machines. See the notes below.
Tested with Windows 10 and Sysinternals virtual desktops.
Not tested with NVidia virtual desktops, they seem obsolete.
Not tested with Windows Vista, 8, and server operating systems.


7. Notes.

With the indicator enabled, the Scroll Lock key should work normally, but
it's state will reflect that of the indicator.

WKB will not disable your default layout change keys, and will not change
any Windows settings.

When using virtual machines, the host and guest Scroll Lock indicators will
be conflicting. Disable one of them.


8. Changes.

0.92: Removed the experimental service/accesibility code.
0.94: Restored the Scroll Lock key functionality, except for the state.
1.06: Rewritten for compatibility with 64-bit systems, common dialogs etc.
1.07: Fixed Start Menu -> Start, Stop, Settings from a non-default desktop.
1.08: Ignore W10 error 170 on (un)install or when started as administrator.
1.09: Option to unload the wrong lock/unlock, Ctrl-Alt-Del etc. layouts.
1.10: Added Caps Lock and Print Screen to the list of toggle/shift keys.
1.11: Simpler unload, display unload error message on the starting desktop.


9. Legal information.

WKB Layout version 1.11, Copyright (C) 2016-2020 Dimitar Toshkov Zhekov.
Report bugs to <dimitar.zhekov@gmail.com>

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc., 51
Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

The gucharmap icon is part of the GNOME icon theme, designed by the GNOME
icon artists, and licensed under the Creative Commons Attribution-Share
Alike 3.0 Unported license.
