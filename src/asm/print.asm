; msg.asm

Msg                     proc
  Startup:              db "ESP UPDATE TOOL v1.", BuildNoValue
                        //db " (", BuildTimeSecsValue, ")"
                        db CR, Copyright, " 2020 Robin Verhagen-Guest", CR, CR, 0
  EOL:                  db CR, 0
  ReadFW:               db "Reading firmware...", CR, 0
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
  Stub1:                db "Uploading stub...", CR, 0
  //Stub2:                db "Running stub...", CR, 0
  Stub3:                db "Stub running", CR, 0
  FlashParams:          db "Flash params set to 0x", 0
  Upload1:              db "Uploading ", 0
  Upload2:              db " bytes...", CR, 0
  Upload3:              db "Writing at 0x", 0
  UploadLeft:           ds 28, 8:db 0
  Written1:             db "Written ", 0
  Written2:             db " bytes to flash  ", CR, 0
  GoodMd5:              db "MD5 hash verified", CR, 0
  Finalize:             db "Finalising new firmware...", CR, 0
  ResetESP:             db "Resetting ESP...", CR, 0
pend

Err                     proc
                        ;  "<-Longest valid erro>", 'r'|128
  Break:                db "D BREAK - CONT repeat", 's'|128
  NoMem:                db "4 Out of memor",        'y'|128
  NotNext:              db "Spectrum Next require", 'd'|128
  NotOS:                db "NextZXOS require",      'd'|128
  NotNB:                db "NextBASIC require",     'd'|128
  NoSync:               db "Sync error or no ES",   'P'|128
  UnknownOUI:           db "Unknown OUI erro",      'r'|128
  BadDot:               db "Error reading dot cm",  'd'|128
  StubUpload:           db "Error uploading stu",   'b'|128
  StubRun:              db "Failed to start stu",   'b'|128
  FlashSet:             db "Flash param error ",    '1'|128
  FlashUpd:             db "Flash param error ",    '2'|128
  ReadFW:               db "Error reading firmwar", 'e'|128
  NotFW:                db "Not a firmware fil",    'e'|128
  BadFW:                db "Firmware is bad forma", 't'|128
  BaudChg:              db "Error changing bau",    'd'|128
  FlashUp:              db "Error writing flas",    'h'|128
  BadMd5:               db "MD5 hash failur",       'e'|128
  Finalize:             db "Error finalizing writ", 'e'|128
  ExitWrite:            db "Error exiting writ",    'e'|128
pend

PrintRst16              proc
                        SafePrintStart()
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                        endif
                        ei
Loop:                   ld a, (hl)
                        inc hl
                        or a
                        jp z, Return
                        rst 16
                        jr Loop
Return:                 SafePrintEnd()
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

PrintChar               proc
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
pend

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

