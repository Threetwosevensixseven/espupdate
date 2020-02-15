:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\PackageFW.exe "NONOS_v221_1620.fac" "NONOS_v221_1620.esp" -f=0x0221 -v=2.2.1.0 -b=16384
copy "NONOS_v221_1620.*" "..\..\ESP Firmware\*.*"

pause