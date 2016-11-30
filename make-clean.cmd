@echo off
if not exist install-inc.nsh goto final
if not exist version-mwow.rc goto final
echo rm -f *.o *.exe *.dll
if exist *.o del *.o
if exist *.exe del *.exe
if exist *.dll del *.dll
:final
