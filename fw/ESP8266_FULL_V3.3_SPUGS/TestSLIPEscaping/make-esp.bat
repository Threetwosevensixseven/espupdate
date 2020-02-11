:: Set current directory
::@echo off
C:
CD %~dp0

..\..\..\build\PackageFW.exe "TestSLIPEscaping.fac" "TestSLIPEscaping.esp" -f=0x0221 -v=TestMD5 -b=16384
copy "TestSLIPEscaping.*" "..\..\ESP Firmware\*.*"

pause