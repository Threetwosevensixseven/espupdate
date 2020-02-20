:: Set current directory and paths
::@echo off
C:
CD %~dp0
CD ..\

copy .\dot\ESPUPDATE. ..\tbblue\dot\ESPUPDATE
copy .\build\readme.txt  ..\tbblue\src\asm\espupdate\*.*
copy .\build\get*.??t  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\AppendFW.exe.config  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\CombineFW.exe.config  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\NormalizeESPLogs.exe.config  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\PackageFW.exe.config  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\ZXVersion.exe.config  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\builddot.bat  ..\tbblue\src\asm\espupdate\build\*.*
copy .\build\*.bas  ..\tbblue\src\asm\espupdate\build\*.*
copy .\src\asm\*.asm  ..\tbblue\src\asm\espupdate\src\asm\*.*

pause