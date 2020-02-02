:: Set current directory
::@echo off
C:
CD %~dp0

AppendFW.exe ..\dot\ESPUPDATE ..\fw\ESP8266_FULL_V3.3_SPUGS\ESP8266_FULL_V3.3_SPUGS.nxesp 24576
ZXVersion.exe

::pause