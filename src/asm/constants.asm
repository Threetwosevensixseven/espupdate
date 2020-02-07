; constants.asm

; Application
CoreMinVersion          equ $3007                       ; 3.00.07 has ESP control pins
DotBank1:               equ 30
DotBank2:               equ 31
DotBank3:               equ 32
ResetWait               equ 5
DisableScroll           equ false
TestWorkflow            equ false
FastUART                equ false
WriteDelay              equ 80
Left5                   equ chr(8)+chr(8)+chr(8)+chr(8)+chr(8)
                        if enabled AppendFW
VerSuffix:                equ "e"
                        else
VerSuffix:                equ "n"
                        endif

; ESP
ESP_OTP_MAC0            equ 0x3ff00050
ESP_OTP_MAC1            equ 0x3ff00054
ESP_OTP_MAC3            equ 0x3ff0005c
ESP_FLASH_BEGIN         equ 0x02
ESP_MEM_BEGIN           equ 0x05
ESP_MEM_END             equ 0x06
ESP_MEM_DATA            equ 0x07
ESP_SPI_SET_PARAMS      equ 0x0b
ESP_CHANGE_BAUDRATE     equ 0x0f
ESP_FLASH_DEFL_BEGIN    equ 0x10
ESP_FLASH_DEFL_DATA     equ 0x11
ESP_FLASH_DEFL_END      equ 0x12
ESP_SPI_FLASH_MD5       equ 0x13
ESP_CHECKSUM_MAGIC      equ 0xef
ESP_IMAGE_MAGIC         equ 0xe9

; esxDOS
M_ERRH                  equ $95

; NextZXOS
IDE_BANK                equ $01BD

; UART
UART_RxD                equ $143B                       ; Also used to set the baudrate
UART_TxD                equ $133B                       ; Also reads status
UART_Sel                equ $153B                       ; Selects between ESP and Pi, and sets upper 3 bits of baud
UART_SetBaud            equ UART_RxD                    ; Sets baudrate
UART_GetStatus          equ UART_TxD                    ; Reads status bits
UART_mRX_DATA_READY     equ %xxxxx 0 0 1                ; Status bit masks
UART_mTX_BUSY           equ %xxxxx 0 1 0                ; Status bit masks
UART_mRX_FIFO_FULL      equ %xxxxx 1 0 0                ; Status bit masks

; Ports
Port                    proc
  NextReg               equ $243B
pend

; Registers
Reg                     proc
  MachineID             equ $00
  CoreMSB               equ $01
  Peripheral2           equ $06
  CPUSpeed              equ $07
  CoreLSB               equ $0E
  VideoTiming           equ $11
pend

; Chars
SMC                     equ 0
UP                      equ 11
CR                      equ 13
LF                      equ 10
Space                   equ 32
Copyright               equ 127

; Screen
SCREEN                  equ $4000                       ; Start of screen bitmap
ATTRS_8x8               equ $5800                       ; Start of 8x8 attributes
ATTRS_8x8_END           equ $5B00                       ; End of 8x8 attributes
ATTRS_8x8_COUNT         equ ATTRS_8x8_END-ATTRS_8x8     ; 768
SCREEN_LEN              equ ATTRS_8x8_END-SCREEN
PIXELS_COUNT            equ ATTRS_8x8-SCREEN
FRAMES                  equ 23672                       ; Frame counter
BORDCR                  equ 23624                       ; Border colour system variable
ULA_PORT                equ $FE                         ; out (254), a
STIMEOUT                equ $5C81                       ; Screensaver control sysvar
SCR_CT                  equ $5C8C                       ; Scroll counter sysvar

; Font
FWSpace                 equ 2
FWColon                 equ 4
FWFullStop              equ 3
FW0                     equ 4
FW1                     equ 4
FW2                     equ 4
FW3                     equ 4
FW4                     equ 4
FW5                     equ 4
FW6                     equ 4
FW7                     equ 4
FW8                     equ 4
FW9                     equ 4
FWA                     equ 4
FWB                     equ 4
FWC                     equ 4
FWD                     equ 4
FWE                     equ 4
FWF                     equ 4
FWG                     equ 4
FWH                     equ 4
FWI                     equ 4
FWJ                     equ 4
FWK                     equ 4
FWL                     equ 4
FWM                     equ 6
FWN                     equ 4
FWO                     equ 4
FWP                     equ 4
FWQ                     equ 4
FWR                     equ 4
FWS                     equ 4
FWT                     equ 4
FWU                     equ 4
FWV                     equ 4
FWW                     equ 6
FWX                     equ 4
FWY                     equ 4
FWZ                     equ 4
FWa                     equ 4
FWb                     equ 4
FWc                     equ 4
FWd                     equ 4
FWe                     equ 4
FWf                     equ 4
FWg                     equ 4
FWh                     equ 4
FWi                     equ 4
FWj                     equ 4
FWk                     equ 4
FWl                     equ 4
FWm                     equ 6
FWn                     equ 4
FWo                     equ 4
FWp                     equ 4
FWq                     equ 4
FWr                     equ 4
FWs                     equ 4
FWt                     equ 4
FWu                     equ 4
FWv                     equ 4
FWw                     equ 6
FWx                     equ 4
FWy                     equ 4
FWz                     equ 4

VersionPrefix           equ "1."

