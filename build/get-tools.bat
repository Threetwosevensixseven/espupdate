@echo off
if exist "%~dpn0.1sp" (
    if not exist "%~dpn0.ps1" (
        echo Copying "%~dpn0.1sp"
        echo to "%~dpn0.ps1"...
        copy "%~dpn0.1sp" "%~dpn0.ps1"
    ) else goto :scriptexists
) else goto :scriptexists
:scriptexists
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dpn0.ps1'"
PAUSE