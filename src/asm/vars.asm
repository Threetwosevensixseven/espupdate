; vars.asm

;  Copyright 2020-2023 Robin Verhagen-Guest
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; Application
SavedArgs:              dw 0
SavedArgsLen            dw 0
SavedStackPrint:        dw $0000
IsNext:                 ds 0
ArgBuffer:              ds 256
WantsHelp:              ds 1
Force:                  ds 1
WaitKeyRet:             ds 1
Progress:               ds 16                   ; 15 chars with terminating null
CRbeforeErr:            ds 1                    ; Zero = no CR, Non-zero = CR
FlashSizeChar:          ds 2                    ; 0 = unassigned, '1' = 1MB, '4' = 4MB
FlashSizeNum:           ds 1                    ; 0 = unassigned,  1  = 1MB,  4  = 4MB
DumpFW:                 ds 1                    ; 0 = flash ESP FW, 1 = dump ESP FW

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
TimeoutBackup:          ds 2
InProgMode:             ds 1
CountC0:                ds 1
ReceivedNow:            ds 4
ReceivedTotal:          ds 4
ReceivedTotalLen        equ $-ReceivedTotal
NumBuffer:              db "00000", 0
Tot16:                  db "16", 0
Tot256:                 db "256", 0
Tot1024:                db "1024", 0
ColsPerLine:            ds 1
UpBuffer:               ds 32, 8:db 0           ; Will get overwritten with db 11, 0 if not in LAYER 0


; Features
Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

; Files
FWFileName:             ds 256                  ; Filename buffer to load firmware from
HasFWFileName:          ds 1
DumpFacFileName:        db "ESPDump.fac", 0
DumpFacFileNameLen:     equ $-DumpFacFileName-1
DumpMD5FileName:        db "ESPDump.md5", 0

Issue                   proc Table:
  ;  IssueID                 Size  MB        Blocks  Patch  BlockSizeAddr  PercentInc    Pad ; BoardID
  db "2", CR,       ds 7, db 1,    "1", 0: dw $0100, $1000,        Tot256,      $0064: ds 12 ;       0
  db "3", CR,       ds 7, db 4,    "4", 0: dw $0400, $4000,       Tot1024,      $0019: ds 12 ;       1
  db "4", CR,       ds 7, db 4,    "4", 0: dw $0400, $4000,       Tot1024,      $0019: ds 12 ;       2
  db "Unknown", CR, ds 1, db 4,    "4", 0: dw $0400, $4000,       Tot1024,      $0019        ;       3
pend

