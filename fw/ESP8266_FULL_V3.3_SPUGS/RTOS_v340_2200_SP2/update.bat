:: Set current directory
@echo off
C:
CD %~dp0

:: You need a full Python install,  added to the PATH.
:: If esptool.py complains about 'no module named serial.tools.list_ports' 
:: you may need to upgrade pyserial with: pip install pyserial

@echo on

python ..\esptool.py --chip esp8266 --port COM5 --baud 115200 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 26m --flash_size 1MB 0x0000 "RTOS_v340_2200_SP2.fac"

@echo off

pause