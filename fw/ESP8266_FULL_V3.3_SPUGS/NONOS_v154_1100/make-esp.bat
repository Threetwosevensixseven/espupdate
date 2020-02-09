:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\PackageFW.exe "NONOS_v154_1100.fac" "NONOS_v154_1100.esp" -f=0x0221 -v=1.5.4.0 -b=16384
copy "NONOS_v154_1100.*" "..\..\ESP Firmware\*.*"

pause