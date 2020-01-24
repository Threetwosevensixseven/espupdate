; msg.asm

Msg                     proc
  Startup:              db "ESP UPDATE TOOL v1."
                        BuildNo()
                        db CR, Copyright, " 2020 Robin Verhagen-Guest", CR, CR, 0
  SetBaud1:             db "Using 115200 baud, ", 0
  SetBaud2:             db " timings", CR, 0
  SendSync:             db "Syncing...", CR, 0
  ESPProg1:             db "Setting ESP programming mode...", CR, 0
  ESP8266EX:            db "Chip is ESP8266EX", CR, 0
  ESP8285:              db "Chip is ESP8285", CR, 0
  FWiFi:                db "Features: WiFi", CR, 0
  FFLash:               db "          Embedded Flash", CR, 0
  Success:              db "ESP updated successfully!", CR, 0
  ErrCd:                db "Error code: ", 0
  MAC2:                 db "MAC: ", 0

  Stub1:                db "Uploading stub...", CR, 0
  Stub2:                db "Running stub...", CR, 0
  Stub3:                db "Stub running", CR, 0
  Stub4:                db "Configuring flash size...", CR, 0
  Stub5:                db "Flash params set to 0x0221", CR, 0
  Stub6:                db "Uploading 457535 bytes...", CR, 0

  Write1:               db "Writing at 0x00000000 (03%)", 0
  Write2:               db Left11, "04000 (07%)", 0
  Write3:               db Left11, "08000 (10%)", 0
  Write4:               db Left11, "0C000 (14%)", 0
  Write5:               db Left11, "10000 (17%)", 0
  Write6:               db Left11, "14000 (21%)", 0
  Write7:               db Left11, "18000 (25%)", 0
  Write8:               db Left11, "1C000 (28%)", 0
  Write9:               db Left11, "20000 (32%)", 0
  Write10:              db Left11, "24000 (35%)", 0
  Write11:              db Left11, "28000 (39%)", 0
  Write12:              db Left11, "2C000 (42%)", 0
  Write13:              db Left11, "30000 (46%)", 0
  Write14:              db Left11, "34000 (50%)", 0
  Write15:              db Left11, "38000 (53%)", 0
  Write16:              db Left11, "3C000 (57%)", 0
  Write17:              db Left11, "40000 (60%)", 0
  Write18:              db Left11, "44000 (64%)", 0
  Write19:              db Left11, "48000 (67%)", 0
  Write20:              db Left11, "4C000 (71%)", 0
  Write21:              db Left11, "50000 (75%)", 0
  Write22:              db Left11, "54000 (78%)", 0
  Write23:              db Left11, "58000 (82%)", 0
  Write24:              db Left11, "5C000 (85%)", 0
  Write25:              db Left11, "60000 (89%)", 0
  Write26:              db Left11, "64000 (92%)", 0
  Write27:              db Left11, "68000 (96%)", 0
  Write28:              db Left11, "6C000 (100%)", Left11, Left11, Left6, 0

  Finish1:              db "Wrote 457535 bytes          ", CR, 0
  Finish2:              db "Hash of data verified", CR, 0
  Finish3:              db "Resetting ESP...", CR, 0

  //RcvSync:            db "Receiving sync", CR, 0
  //ESPProg2:           db "Enabling GPIO0 output", CR, 0
  //ESPProg3:           db "Setting RST low", CR, 0
  //ESPProg4:           db "Setting GPIO0 low", CR, 0
  //ESPProg5:           db "Setting RST high", CR, 0
  //ESPProg6:           db "Setting GPIO0 high", CR, 0
  //ESPProg7:           db "Disabling GPIO0 output", CR, 0
  //ESPProg8:           db "Reading UART buffer...", CR, CR, 0
  //SyncOK:             db "Sync OK", CR, 0
  //Fuse1:              db "Reading eFuses...", CR, 0
  //MAC1:               db "Reading MAC...", CR, 0
  //Scroll:             db "Testing scroll", CR, CR, CR, CR, CR, CR, CR, CR, CR
  //                    db CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR, CR
  //                    db "Last line", CR, 0
  //Speed1:             db "Restoring speed to ", 0
  //Speed35:            db "3.5MHz", 0
  //Speed07:            db "7MHz", 0
  //Speed14:            db "14MHz", 0
  //Speed28:            db "28MHz", 0
  //Speed2:             db "(0x", 0
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
pend

PrintRst16              proc
                        if DisableScroll
                          ld a, 24                      ; Set upper screen to not scroll
                          ld (SCR_CT), a                ; for another 24 rows of printing
                        endif
                        ei
Loop:                   ld a, (hl)
                        inc hl
                        or a
                        jr z, Return
                        rst 16
                        jr Loop
Return:                 di
                        ret
pend

PrintRst16Error         proc
                        ei
Loop:                   ld a, (hl)
                        ld b, a
                        and %1 0000000
                        ld a, b
                        jp nz, LastChar
                        inc hl
                        rst 16
                        jr Loop
Return:                 di
                        ret
LastChar                and %0 1111111
                        rst 16
                        ld a, CR                        ; The error message doesn't include a trailing CR in the
                        rst 16                          ; definition, so we want to add one when we print it
                        jr Return                       ; in the upper screen.
pend

PrintAHex               proc
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
                        ret
Print:                  cp 10
                        ld c, '0'
                        jr c, Add
                        ld c, 'A'-10
Add:                    add a, c
                        rst 16
                        ret
pend

PrintAHexNoSpace        proc
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
                        ret
Print:                  cp 10
                        ld c, '0'
                        jr c, Add
                        ld c, 'A'-10
Add:                    add a, c
                        rst 16
                        ret
pend

PrintChar               proc
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
                        ret
pend

PrintBufferHexProc      proc                            ; hl = Addr, de = Length
                        ld a, (hl)
                        call PrintAHex
                        inc hl
                        dec de
                        ld a, d
                        or e
                        jr nz, PrintBufferHexProc
                        ret
pend

