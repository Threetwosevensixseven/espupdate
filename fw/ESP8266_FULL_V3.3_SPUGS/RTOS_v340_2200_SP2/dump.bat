:: Set current directory
@echo off
C:
CD %~dp0

:: You need a full Python install,  added to the PATH.
:: If esptool.py complains about 'no module named serial.tools.list_ports' 
:: you may need to upgrade pyserial with: pip install pyserial

@echo on

python ..\esptool.py --chip esp8266 --port COM5 --baud 115200 read_flash 0 0x100000 "RTOS_v340_2200_SP2.facdump"

@echo off

pause