; vars.asm

; Application
SavedArgs:              dw 0

; UART
Buffer:                 ds 1024
BufferLen               equ $-Buffer
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

Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

Cmd                     proc
 Header                 db $C0, $00                     ; Frame start, Request
 HeaderOp:              db SMC                          ; <SMC Patched before sending command
 HeaderDataLen:         dw SMC                          ; <SMC Patched before sending command
 HeaderCS:              dl 0                            ; Usually 0 when sending, could be patched
 HeaderLen              equ $-Header                    ; The header is always 9 bytes
 Footer:                db $C0                          ; Frame end
 FooterLen:             equ $-Footer                    ; The footer is always 1 byte
 Stub1:                 dl 0x00001F60
                        dl 0x00000002
                        dl 0x00001800
                        dl 0x4010E000
 Stub1Len               equ $-Stub1                     ; Stub1 should be 16 bytes long
 LastErr:               ds 0
pend

