:: Set current directory
::@echo off
C:
CD %~dp0

AppendFW.exe 24576 ..\dot\ESPUPDATE ..\fw\ESP8266_FULL_V3.3_SPUGS\ESP8266_FULL_V3.3_SPUGS.bin -f=0x0221 -v=3.3.0.1 -b=16384
ZXVersion.exe

::pause