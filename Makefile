#
# Copyright (C) 2016-2022 Dimitar Toshkov Zhekov <dimitar.zhekov@gmail.com>
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

all: wkb-mini.exe wkb-mwow.exe custom-ui.dll

GCC32 = i686-w64-mingw32-gcc
GCC64 = x86_64-w64-mingw32-gcc
CFLAGS = -Wall -Wextra -O2
LDFLAGS = -s -mwindows
DLLFLAGS = -shared -nostdlib -nostartfiles
RC32 = windres -F pe-i386
RC64 = windres -F pe-x86-64
RM = rm -f

wkb-hook.dll: wkb-hook.c wkb-hook.h Makefile
	$(GCC64) $(CFLAGS) $(LDFLAGS) $(DLLFLAGS) -o $@ wkb-hook.c -luser32

version-mini.o: version-mini.rc gucharmap1.ico Makefile
	$(RC64) -o $@ version-mini.rc

wkb-mini.exe: wkb-mini.c wkb-mwow.h wkb-proc-inc.c program-inc.c version-mini.o wkb-hook.dll Makefile
	$(GCC64) $(CFLAGS) $(LDFLAGS) -o $@ wkb-mini.c version-mini.o wkb-hook.dll

wkb-hk32.dll: wkb-hook.c wkb-hook.h Makefile
	$(GCC32) $(CFLAGS) $(LDFLAGS) $(DLLFLAGS) -o $@ wkb-hook.c -luser32

version-mwow.o: version-mwow.rc Makefile
	$(RC32) -o $@ version-mwow.rc

wkb-mwow.exe: wkb-mwow.c wkb-mwow.h wkb-proc-inc.c program-inc.c version-mwow.o wkb-hk32.dll Makefile
	$(GCC32) $(CFLAGS) $(LDFLAGS) -o $@ wkb-mwow.c version-mwow.o wkb-hk32.dll

custom-ui.o: custom-ui.rc Makefile
	$(RC32) -o $@ custom-ui.rc

custom-ui.dll: empty-dll-main.c custom-ui.o Makefile
	$(GCC32) $(CFLAGS) $(LDFLAGS) $(DLLFLAGS) -o $@ empty-dll-main.c custom-ui.o

clean:
	$(RM) *.o *.exe *.dll

.PHONY: all clean
