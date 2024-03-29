; msg.asm

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

Msg                     proc
  Startup:              db "ESP UPDATE TOOL v1.", BuildNoValue//, VerSuffix
                        //db " (", BuildTimeSecsValue, ")"
                        db CR, Copyright, " 2020-2023 Robin Verhagen-Guest", CR, CR, 0
  EOL:                  db CR, 0
  NoScroll:             db 26, 0, -1
  ReadFW:               db "Reading firmware...", CR, 0
  ExternalFW:           db "Pick an .ESP file from the file browser in NextZXOS, or specify filename as the first argument.", CR, 0
  FWVer:                db "Updating firmware to v", 0
  SetBaud1:             db "Using ", 0
  b115200:              db "115200", 0
  b1152000:             db "1152000", 0
  SetBaud2:             db " baud, ", 0
  SetBaud3:             db " timings", CR, 0
  SendSync:             db "Syncing...", CR, 0
  RetryESP:             db "Resetting ESP and retrying...", CR, 0
  ESPProg1:             db "Setting ESP programming mode...", CR, 0
  ESP8266EX:            db "Chip is ESP8266EX", CR, 0
  ESP8285:              db "Chip is ESP8285", CR, 0
  FWiFi:                db "Features: WiFi", CR, 0
  FFLash:               db "          Embedded Flash", CR, 0
  Success:              db "ESP updated successfully!", CR, 0
  ErrCd:                db "Error code: ", 0
  MAC2:                 db "MAC: ", 0
  Issue:                db "Next issue: ", 0
  FlashSize1:           db "Using flash size: ", 0
  FlashSize2:           db "MB", CR, 0
  Confirm:              db "Are you sure? (y/n) ", 0
  Abort:                db "Not updating ESP", CR, 0
  Stub1:                db "Uploading stub...", CR, 0
  Stub2:                db "Stub running", CR, 0
  FlashParams:          db "Flash params set to 0x", 0
  Upload1:              db "Uploading ", 0
  Upload2:              db " bytes...", CR, 0
  Upload3:              db "Writing at 0x", 0
  UploadLeft:           ds 28, 8:db 0
  Written1:             db "Written ", 0
  Written2:             db " bytes to flash  ", CR, 0
  GoodMd5:              db "MD5 hash verified", CR, 0
  HashExp:              db "Expecting MD5 hash:", CR, 0
  HashGot:              db CR, "ESP reports MD5 hash:", CR, 0
  Finalize:             db "Finalising new firmware...", CR, 0
  ResetESP:             db "Resetting ESP...", CR, 0
  DumpingFW:            db "Dumping firmware...", CR, 0
  Dump1:                db "4KB block ", 0
  Dump2:                db "/", 0
  Dump3:                db " (", 0
  Dump4:                db "%)...", CR, 0
  DumpingCS:            db "Getting MD5 hash...", CR, 0
  DumpFile:             db "Dump file: ", 0
  HashFile:             db CR, "Hash file: ", 0
  DumpSuccess:          db "ESP dumped successfully!", CR, 0
  PressEnter:           db CR, "Press ENTER to exit...", CR, 0
  Help:                 db "Updates firmware for ESP8266-01 WiFi module on the Spectrum Next", CR, CR
                        if enabled AppendFW
                          db "espupdate [-y] [-k] [-h]", CR
                          db "Update ESP with default firmware", CR, CR
                          db "espupdate FILENAME [-y] [-s=SZ]", CR, "  [k] [-h]", CR
                          db "Update ESP with the firmware in an external file", CR, CR
                        else
                          db "espupdate FILENAME [-y] [-s=SZ]", CR, "  [-k] [-h]", CR
                          db "Update ESP with the firmware in an external file", CR, CR
                          db "espupdate -h", CR
                          db "Display this help", CR, CR
                        endif
                        db "OPTIONS", CR, CR
                        db "  FILENAME", CR
                        db "  A file containing ESP firmware", CR, "  in the NXESP format", CR
                        db "  For more info, see the FAQ at:", CR
                        db "  tinyurl.com/espfaq", CR, CR
                        db "  -y", CR
                        db "  Skip \"Are you sure?\"", CR, CR
                        db "  -s=SZ", CR
                        db "  Specify a flash size for ESP", CR,"  module. If omitted, assumes", CR
                        db "  Issue 2 Nexts have 1MB, and", CR, "  everything else has 4MB", CR, CR
                        db "  SZ", CR
                        db "  Either 1 or 4 (in MB)", CR, CR
                        db "  -k", CR
                        db "  Wait for ENTER keypress before", CR, "  exiting", CR, CR
                        db "  -h", CR
                        db "  Display this help", CR, CR
                        db "ESP UPDATE TOOL v1.", BuildNoValue, CR
                        db BuildDateValue, " ", BuildTimeSecsValue, CR
                        db Copyright, " 2020-2023 Robin Verhagen-Guest", CR, 0
pend

Err                     proc
                        ;    "<-Longest valid error>" ;
  Break:                dbtb "D BREAK - CONT repeats" ;
  NoMem:                dbtb "4 Out of memory"        ;
  NotNext:              dbtb "Spectrum Next required" ;
  NotOS:                dbtb "NextZXOS required"      ;
  CoreMin:              dbtb "Core 3.01.00 required"  ;
  ArgsTooBig:           dbtb "Arguments too long"     ;
  ArgsBad:              dbtb "Invalid Arguments"      ;
  NotNB:                dbtb "NextBASIC required"     ;
  NoSync:               dbtb "Sync error or no ESP"   ;
  UnknownOUI:           dbtb "Unknown OUI error"      ;
  BadDot:               dbtb "Error reading dot cmd"  ;
  StubUpload:           dbtb "Error uploading stub"   ;
  StubRun:              dbtb "Failed to start stub"   ;
  FlashSet:             dbtb "Flash param error 1"    ;
  FlashUpd:             dbtb "Flash param error 2"    ;
  ReadFW:               dbtb "Error reading firmware" ;
  FWMissing:            dbtb "Firmware missing"       ;
  FWNeeded:             dbtb "Firmware needed"        ;
  NotFW:                dbtb "Not a firmware file"    ;
  BadFW:                dbtb "Firmware is bad format" ;
  BaudChg:              dbtb "Error changing baud"    ;
  FlashStart:           dbtb "Error initiating flash" ;
  FlashUp:              dbtb "Error writing flash"    ;
  BadMd5:               dbtb "MD5 hash failure"       ;
  Finalize:             dbtb "Error finalizing write" ;
  ExitWrite:            dbtb "Error exiting write"    ;
  DumpInit:             dbtb "Error initiating dump"  ;
  DumpCreate:           dbtb "Can't create dump file" ;
  DumpParse:            dbtb "Error parsing dump"     ;
  DumpSave:             dbtb "Error saving dump file" ;
  HashCreate:           dbtb "Can't create hash file" ;
  HashSave:             dbtb "Can't save hash file"   ;
pend

PrintRst16              proc
                        SafePrintStart()
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
OverrideScroll:           ld (SCR_CT), a                ; for another 24 rows of printing
                        endif
                        ei
Loop:                   ld a, (hl)
                        inc hl
                        cp [Terminator]0                ; <SMC can be changed to different terminator
                        jp z, Return
                        rst 16
                        jr Loop
Return:                 SafePrintEnd()
                        ret
pend

PrintRst16Alt           proc
                        push af
                        ld a, -1
                        ld (PrintRst16.Terminator), a   ; Change terminator
                        pop af
                        call PrintRst16
                        push af
                        xor a
                        ld (PrintRst16.Terminator), a   ; Restore terminator
                        pop af
                        ret
pend

PrintRst16Error         proc
                        SafePrintStart()
Loop:                   ld a, (hl)
                        ld b, a
                        and %1 0000000
                        ld a, b
                        jp nz, LastChar
                        inc hl
                        rst 16
                        jr Loop
Return:                 jp PrintRst16.Return
LastChar                and %0 1111111
                        rst 16
                        ld a, CR                        ; The error message doesn't include a trailing CR in the
                        rst 16                          ; definition, so we want to add one when we print it
                        jr Return                       ; in the upper screen.
pend

/*PrintAHex               proc
                        SafePrintStart()
                        ld b, a
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                          ld a, b
                        endif
                        and $F0
                        swapnib
                        call Print
                        ld a, b
                        and $0F
                        call Print
                        ld a, 32
                        rst 16
                        ld a, 32
                        rst 16
                        jp PrintRst16.Return
Print:                  cp 10
                        ld c, '0'
                        jr c, Add
                        ld c, 'A'-10
Add:                    add a, c
                        rst 16
                        ret
pend*/

PrintAHexNoSpace        proc
                        SafePrintStart()
                        ld b, a
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                          ld a, b
                        endif
                        and $F0
                        swapnib
                        call Print
                        ld a, b
                        and $0F
                        call Print
                        jp PrintRst16.Return
Print:                  cp 10
                        ld c, '0'
                        jr c, Add
                        ld c, 'A'-10
Add:                    add a, c
                        rst 16
                        ret
pend

/*PrintChar               proc
                        SafePrintStart()
                        ld b, a
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                          ld a, b
                        endif
                        cp 32
                        jr c, NotPrintable
                        cp 127
                        jr nc, NotPrintable
                        rst 16
                        ret
NotPrintable:           ld a, '.'
                        rst 16
                        jp PrintRst16.Return
pend*/

Rst16                   proc
                        SafePrintStart()
                        rst 16
                        jp PrintRst16.Return
pend

PrintBufferHexProc      proc                            ; hl = Addr, de = Length
                        ld a, (hl)
                        call PrintAHexNoSpace
                        inc hl
                        dec de
                        ld a, d
                        or e
                        jr nz, PrintBufferHexProc
                        ret
pend

DisablePrintScroll      proc
                        if enabled DisableScroll
                          xor a                                 ; NOP out the ld (SCR_CT), a
                          ld (PrintRst16.OverrideScroll), a
                          ld (PrintRst16.OverrideScroll+1), a
                          ld (PrintRst16.OverrideScroll+2), a
                          inc a                                 ; Set up scroll to happen
                          ld (SCR_CT), a                        ; as soon as we hit the bottom of the screen
                        endif
                        ret
pend

PrintDumpProgress       proc
                        call UpOneLine                          ;  Go up one line (allowing for screen mode)
NoUp:                   PrintMsg(Msg.Dump1)                     ;  Print "4KB block "
                        ld hl, [BlockNum]SMC
                        inc hl                                  ; Increment block number (1..256 or 1..1024)
                        ld (BlockNum), hl
                        ld de, NumBuffer
                        call Num2Dec                            ; Convert block number to ASCII, padded to 5 digits
                        ld de, NumBuffer
                        call TrimZeroes                         ; Find first non-zero digit
                        call PrintRst16                         ; Print block number
                        PrintMsg(Msg.Dump2)                     ; Print "/"
                        ld hl, [BlockTot]Tot16
                        call PrintRst16                         ; Print total block count (256 or 1024)
                        PrintMsg(Msg.Dump3)                     ; Print " ("
                        ld hl, [PercentTot]0                    ; Calculate running percentage,
                        ld de, [PercentInc]$0640                ; by adding a fractional amount (100/256 or 100/1024),
                        add hl, de                              ; using 8.8 fixed point arithmetic.
                        ld (PercentTot), hl                     ; Store running percentage for next time.
                        ld l, h                                 ; Take integer portion in MSB,
                        ld h, 0                                 ; and discard fractional portion in LSB.
                        ld de, NumBuffer
                        call Num2Dec                            ; Convert percentage to ASCII, padded to 5 digits
                        ld de, NumBuffer
                        call TrimZeroes                         ; Find first non-zero digit
                        call PrintRst16                         ; Print percentage
                        PrintMsg(Msg.Dump4)                     ; Print "%)..." then go to next line
                        ret
pend

UpOneLine               proc
                        PrintMsg(UpBuffer)
                        ret
pend

