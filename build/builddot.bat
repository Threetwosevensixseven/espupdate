:: Set current directory
::@echo off
C:
CD %~dp0

AppendFW.exe 8192 ..\dot\ESPUPDATE ..\fw\ESP8266_FULL_V3.3_SPUGS\ESP8266_FULL_V3.3_SPUGS.bin
ZXVersion.exe

::pause