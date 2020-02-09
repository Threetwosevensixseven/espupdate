; vars.asm

; Application
SavedArgs:              dw 0
SavedArgsLen            dw 0
SavedStackPrint:        dw $0000
IsNext:                 ds 0
ArgBuffer:              ds 256
WantsHelp:              ds 1
Force:                  ds 1
Progress:               ds 16                   ; 15 chars with terminating null
CRbeforeErr:            ds 1                    ; Zero = no CR, Non-zero = CR

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
FlashParams:            ds 2
FWVersion:              ds 11                   ; 10 chars with terminating null
FWMD5:                  ds 16                   ; 16 bytes (binary not hex string)
GotMD5:                 ds 16                   ; MDS we got back from the ESP
DataBlockSize:          ds 2
FWCompLen:              ds 4
FWCompLenStr:           ds 11
HeaderBlockSize:        ds 2                    ; MSB is always zero
BlockCount:             ds 2
BlockHeaderStart:       ds 2
TimeoutBackup:          ds 1
InProgMode:             ds 1

; Features
Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

; Files
FWFileName:             ds 256                  ; Filename buffer to load firmware from
HasFWFileName:          ds 1

