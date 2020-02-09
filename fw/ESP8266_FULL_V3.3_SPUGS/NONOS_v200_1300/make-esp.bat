:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\PackageFW.exe "NONOS_v200_1300.fac" "NONOS_v200_1300.esp" -f=0x0221 -v=2.0.0.0 -b=16384
copy "NONOS_v200_1300.*" "..\..\ESP Firmware\*.*"

pause