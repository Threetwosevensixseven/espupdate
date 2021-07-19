:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\CompressAndHashFW.exe "RTOS_v340_2200_SP2.fac" -f=0x0221 > md5.txt
set /p MD5=<md5.txt

..\..\..\build\PackageFW.exe "RTOS_v340_2200_SP2.zfac" "RTOS_v340_2200_SP2.esp" -nc -md5=%MD5% -f=0x0221 -v=2.2.0.0SP2 -b=16384
copy "RTOS_v340_2200_SP2.???" "..\..\ESP Firmware\*.*"

pause