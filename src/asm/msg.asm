; msg.asm

Msg                     proc
  Startup:              db "ESP Update Tool v1."
                        BuildNo()
                        db CR, 0
  SendSync:             db "Syncing...", CR, 0
  RcvSync:              db "Receiving sync", CR, 0
  ESPProg1:             db CR, "Setting ESP programming mode...", CR, 0
  //ESPProg2:           db "Enabling GPIO0 output", CR, 0
  //ESPProg3:           db "Setting RST low", CR, 0
  //ESPProg4:           db "Setting GPIO0 low", CR, 0
  //ESPProg5:           db "Setting RST high", CR, 0
  //ESPProg6:           db "Setting GPIO0 high", CR, 0
  //ESPProg7:           db "Disabling GPIO0 output", CR, 0
  //ESPProg8:           db "Reading UART buffer...", CR, CR, 0
  SyncOK:               db "Sync OK", CR, 0
  //Fuse1:              db "Reading eFuses...", CR, 0
  ESP8266EX:            db "Chip is ESP8266EX", CR, 0
  ESP8285:              db "Chip is ESP8285", CR, 0
  FWiFi:                db "Features: WiFi", CR, 0
  FFLash:               db "          Embedded Flash", CR, 0
  //MAC1:               db "Reading MAC...", CR, 0
  MAC2:                 db "MAC: ", 0
  Stub1:                db "Uploading stub...", CR, 0
pend

Err                     proc
  NoSync:               db "Sync failur", 'e'|128
  UnknownOUI:           db "Unknown OUI erro", 'r'|128
pend

PrintRst16              proc
                        ld a, 24                        ; Set upper screen to not scroll
                        ld (23692), a                   ; for another 24 rows of printing
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
                        jr Return
pend

PrintAHex               proc
                        ld b, a
                        ld a, 24                        ; Set upper screen to not scroll
                        ld (23692), a                   ; for another 24 rows of printing
                        ld a, b
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
                        ld a, 24                        ; Set upper screen to not scroll
                        ld (23692), a                   ; for another 24 rows of printing
                        ld a, b
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
                        ld a, 24                        ; Set upper screen to not scroll
                        ld (23692), a                   ; for another 24 rows of printing
                        ld a, b
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

Wait5Frames             proc
                        ei
                        for n = 1 to 5
                          halt
                        next
                        di
                        ret
pend

