:: Set current directory
::@echo off
C:
CD %~dp0

PackageFW.exe ..\fw\ESP8266_FULL_V3.3_SPUGS\NONOS_v1_5_4_0.bin ..\fw\ESP8266_FULL_V3.3_SPUGS\NONOS_v1_5_4_0.nxesp -f=0x0221 -v=1.5.4.0 -b=16384

pause