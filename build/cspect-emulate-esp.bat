:: Set current directory
::@echo off
C:
CD %~dp0

AppendFW.exe 8192 ..\dot\ESPUPDATE ..\fw\ESP8266_FULL_V3.3_SPUGS\ESP8266_FULL_V3.3_SPUGS.bin
ZXVersion.exe
pskill.exe -t cspect.exe
hdfmonkey.exe put C:\spec\cspect-next-2gb.img ..\dot\espupdate dot
cd C:\spec\CSpect2_12_1
CSpect.exe -w2 -zxnext -nextrom -basickeys -exit -brk -tv -mmc=..\cspect-next-2gb.img


::pause