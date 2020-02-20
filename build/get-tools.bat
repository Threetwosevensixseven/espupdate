@echo off
if exist "%~dpn0.txt" (
    echo Copying "%~dpn0.txt"
    echo to "%~dpn0.ps1"...
    copy "%~dpn0.txt" "%~dpn0.ps1"
) else goto :scriptexists
:scriptexists

@echo off
C:
CD %~dp0
cd ..
md fw
cd fw
md ESP8266_FULL_V3.3_SPUGS
cd ..\build
 
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dpn0.ps1'"
PAUSE