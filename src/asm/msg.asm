; msg.asm

Msg                     proc
  Startup:              db "ESP Update Tool v1."
                        BuildNo()
                        db CR, 0
  SendSync:             db "Sending Sync...", CR, 0
  RcvSync:              db "Receiving Sync...", CR, 0
pend

PrintRst16              proc
                        ld a, 24                        ; Set upper screen to not scroll
                        ld(23692), a                    ; for another 24 rows of printing
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

PrintAHex               proc
                        ld b, a
                        ld a, 24                        ; Set upper screen to not scroll
                        ld(23692), a                    ; for another 24 rows of printing
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



