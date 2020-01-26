; vars.asm

; Application
SavedArgs:              dw 0

; UART
Prescaler:              ds 3
Dummy32:                ds 4

; ESP
eFuses:
eFuse1:                 ds 4
eFuse2:                 ds 4
eFuse3:                 ds 4
eFuse4:                 ds 4
MAC0:                   ds 4
MAC1:                   ds 4
MAC3:                   ds 4
MAC:
OUI1:                   ds 1
OUI2:                   ds 1
OUI3:                   ds 1
OUI4:                   ds 1
OUI5:                   ds 1
OUI6:                   ds 1
FlashFreq:              ds 1
FlashParams:            ds 2;dw 0x2102
FWVersion:              ds 11                   ; 10 chars with terminating null
FWMD5:                  ds 32
FilePointer:            ds 4

Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

