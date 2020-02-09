:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\PackageFW.exe "RTOS_v330_2100.fac" "RTOS_v330_2100.esp" -f=0x0221 -v=3.3.0.1 -b=16384
copy "RTOS_v330_2100.*" "..\..\ESP Firmware\*.*"

pause