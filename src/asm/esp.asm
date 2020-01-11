; esp.asm

SLIP                    proc
  Sync:                 db $C0                          ; SLIP Frame start
                        db $00                          ; Header
                        db $08                          ; ESP_SYNC command op
                        dw 36                           ; Payload length word
                        dl 0                            ; Checksum long word
                        dh "07071220"                   ; Payload part 1
                        ds 32, $55                      ; Payload part 2
                        db $C0                          ; SLIP Frame end
  SyncLen               equ $-Sync
pend

ESPSendBytesProc        proc                            ; hl = Buffer, de = Length
                        ld bc, UART_GetStatus           ; UART Tx port also gives the UART status when read
WaitNotBusy:            in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy              ; If busy, keep trying until not busy
                        ld a, (hl)                      ; Otherwise read the next byte of the text to be sent
                        out (c), a                      ; and end it to the UART TX port
                        inc hl                          ; Move to next byte of the text
                        dec de                          ; Check whether there are any more bytes of text
                        ld a, d
                        or e
                        jr nz, WaitNotBusy              ; If there are, read and repeat
                        ret                             ; Otherwise return
pend

ESPFlush                proc
                        ld bc, UART_GetStatus
ReadLoop:               ld a, high UART_GetStatus       ; Are there any characters waiting?
                        in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        ret nc                          ; Return immmediately if no data ready to be read
                        inc b                           ; Otherwise Read the byte
                        in a, (c)                       ; from the UART Rx port
                        dec b
                        jr ReadLoop                     ; then check if there are more data bytes ready to read
pend

ESPSendTestBytes        proc                            ; Send 256 bytes to UART, with values 0..255
                        ld h, 0
                        ld bc, $133B                    ; UART Tx port also gives the UART status when read
WaitNotBusy:            in a, (c)                       ; Read the UART status
                        and 2                           ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy              ; If busy, keep trying until not busy
                        ld a, h                         ; Otherwise read the next byte of the text to be sent
                        out (c), a                      ; and end it to the UART TX port
                        inc h
                        jr nz, WaitNotBusy
                        ret
pend

ESPRead                 proc
                        ld a, (FRAMES)
                        add a, 5
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
                        ei
WaitNotBusy:            ld a, high UART_GetStatus       ; Are there any characters waiting?
                        in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if Available
                        ld a, (FRAMES)
TimeoutFrame equ $+1:   cp SMC
                        jp nz, WaitNotBusy              ; Try again for at least another N frames (5)
                        di
                        ret                             ; Return if N frames (5) has elapsed with no data
HasData:
                        inc b                           ; Otherwise Read the byte
                        in a, (c)                       ; from the UART Rx port
                        push bc
                        call PrintAHex
                        pop bc
                        dec b
                        jr WaitNotBusy                  ; then check if there are more data bytes ready to read
pend

ESPReadPrint            proc
                        ld a, (FRAMES)
                        add a, 5
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
                        ei
WaitNotBusy:            ld a, high UART_GetStatus       ; Are there any characters waiting?
                        in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if Available
                        ld a, (FRAMES)
TimeoutFrame equ $+1:   cp SMC
                        jp nz, WaitNotBusy              ; Try again for at least another N frames (5)
                        di
                        ret                             ; Return if N frames (5) has elapsed with no data
HasData:
                        inc b                           ; Otherwise Read the byte
                        in a, (c)                       ; from the UART Rx port
                        push bc
                        call PrintChar
                        pop bc
                        dec b
                        jr WaitNotBusy                  ; then check if there are more data bytes ready to read
pend

ClearBuffer:            proc
                        FillLDIR(Buffer, BufferLen, 0)
                        ret
pend

ESPReadIntoBuffer       proc
                        call ClearBuffer
                        ld a, (FRAMES)
                        add a, 5
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
                        ld hl, Buffer
                        ld de, BufferLen
                        ei
WaitNotBusy:            in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if available
                        ld a, (FRAMES)
TimeoutFrame equ $+1:   cp SMC
                        jp nz, WaitNotBusy              ; Try again for at least another N frames (5)
                        di
                        scf                             ; Set carry to signal error if N frames with no data,
                        ret                             ; and return
HasData:                inc b                           ; Otherwise Read the byte,
                        in a, (c)                       ; from the UART Rx port,
                        dec b
                        ld (hl), a                      ; and write into buffer
                        inc hl
                        dec de                          ; See if any more buffer left
                        ld a, d
                        or e
                        jr nz, WaitNotBusy              ; If so, check if there are more data bytes ready to read,
                        or a                            ; otherwise clear carry to signal success,
                        di
                        ret                             ; and return
pend

ValidateCmdProc         proc
                        ld hl, Buffer
                        ld bc, BufferLen
FindFrame:              ld a, $C0
                        cpir                            ; Find next SLIP frame marker
                        jp po, Fail                     ; If we ran out of buffer, exit with failure
                        jr nz, Fail                     ; If we didn't find a $C0, exit with failure
                        ld a, (hl)                      ; Read req/resp
                        dec bc
                        cp 1                            ; Is cmd response?
                        jp nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read Op
Opcode equ $+1:         cp SMC                          ; Is expected Op?
                        jp nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld e, (hl)
                        inc hl
                        dec bc
                        ld d, (hl)                      ; Read length word
                        for n = 1 to 4
                          inc hl                        ; Skip 4 bytes of data (for now)
                          dec bc                        ; (maybe we will save a pointer to this later)
                        next
                        add hl, de                      ; Skip <length> bytes of value (for now)
                        push hl                         ; (maybe we will save a pointer to this later)
                        ld hl, bc
                        or a
                        sbc hl, de                      ; And reduce remaining buffer len by <length>
                        ld bc, hl
                        pop hl
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read SLIP frame end
                        cp $C0                          ; Is expected frame marker?
                        jp nz, FindFrame                ; If not, find next frame marker

                        or a                            ; Clear carry for success,
                        ret                             ; and return
Fail:                   scf                             ; Set carry for error,
                        ret                             ; and return
pend

ErrorProc               proc
                        call PrintRst16Error
Stop:                   Border(2)
                        jr Stop
pend

