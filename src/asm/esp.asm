; esp.asm

SLIP                    proc
  Sync:                 db $C0                          ; SLIP Frame start - timeout 5
                        db $00                          ; Request
                        db $08                          ; ESP_SYNC command op
                        dw 36                           ; Payload length word
                        dl 0                            ; Checksum long word
                        dh "07071220"                   ; Payload part 1
                        ds 32, $55                      ; Payload part 2
                        db $C0                          ; SLIP Frame end
  SyncLen               equ $-Sync

  ReadReg:              db $C0, $00                     ; Frame, request - timeout 3
                        db $0A                          ; ESP_READ_REG command op
                        dw 4                            ; Length 4 (of register address)
                        dl 0                            ; Checksum
  ReadRegAddr:          dl 0x3ff0005c                   ; Register address SMC (4 bytes)
                        db $C0                          ; SLIP Frame end
  ReadRegLen            equ $-ReadReg
  Header                db $C0, $00                     ; Frame start, Request
  HeaderOp:             db SMC                          ; <SMC Patched before sending command
  HeaderDataLen:        dw SMC                          ; <SMC Patched before sending command
  HeaderCS:             dl 0                            ; Usually 0 when sending, could be patched
  HeaderLen             equ $-Header                    ; The header is always 9 bytes
  Footer:               db $C0                          ; Frame end
  FooterLen:            equ $-Footer                    ; The footer is always 1 byte
  Stub1:                dl 0x00001F60
                        dl 0x00000002
                        dl 0x00001800
                        dl 0x4010E000
  Stub1Len              equ $-Stub1                     ; Stub1 should be 16 bytes long
  DataBlock:            dl 0x00000000
                        dl 0x00000000
                        dl 0x00000000
                        dl 0x00000000
  DataBlockLen          equ $-DataBlock                 ; DataBlock should be 16 bytes long
  LastErr:              ds 0
pend

ESPSetDataBlockHeaderProc proc
                        ld (SLIP.DataBlock), hl
                        ld (SLIP.DataBlock+2), de
                        ld (SLIP.DataBlock+4), bc
                        ld (SLIP.DataBlock+6), ix
                        ret
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

/*ESPSendTestBytes      proc                            ; Send 256 bytes to UART, with values 0..255
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
pend*/

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
HasData:                inc b                           ; Otherwise Read the byte
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
HasData:                inc b                           ; Otherwise Read the byte
                        in a, (c)                       ; from the UART Rx port
                        push bc
                        call PrintChar
                        pop bc
                        dec b
                        jr WaitNotBusy                  ; then check if there are more data bytes ready to read
pend

ESPClearBuffer:         proc
                        FillLDIR(Buffer, Buffer.Len, 0)
                        ret
pend

ESPReadIntoBuffer       proc
                        call ESPClearBuffer
                        ld a, (FRAMES)
                        add a, 5
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
                        ld hl, Buffer
                        ld de, Buffer.Len
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

ESPValidateCmdProc       proc                            ; a = Op, hl = ValWordAddr
                        ld (Opcode), a
                        ld (ValWordAddr4), hl
                        inc hl
                        ld (ValWordAddr3), hl
                        inc hl
                        ld (ValWordAddr2), hl
                        inc hl
                        ld (ValWordAddr1), hl
                        ld hl, Buffer
                        ld bc, Buffer.Len
FindFrame:              ld a, $C0
                        cpir                            ; Find next SLIP frame marker
                        jp po, FailWithoutReason        ; If we ran out of buffer, exit with failure
                        jr nz, FailWithoutReason        ; If we didn't find a $C0, exit with failure
                        ld a, (hl)                      ; Read req/resp
                        dec bc
                        cp 1                            ; Is cmd response?
                        jr nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read Op
Opcode equ $+1:         cp SMC                          ; Is expected Op?
                        jr nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld e, (hl)
                        inc hl
                        dec bc
                        ld d, (hl)                      ; Read length word
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 1
ValWordAddr1 equ $+1:   ld (SMC), a                     ; Save value byte 1
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 2
ValWordAddr2 equ $+1:   ld (SMC), a                     ; Save value byte 2
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 3
ValWordAddr3 equ $+1:   ld (SMC), a                     ; Save value byte 3
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 4
ValWordAddr4 equ $+1:   ld (SMC), a                     ; Save value byte 4
                        ld a, e                         ; Simplistic version of checking DE is at least 2
                        or d                            ; Should always be larger hopefully, given the nature or ORing 0, 1 or 2 with the MSB
                        cp 2                            ; TODO: If we get unexpected failures later, revisit this compare
                        jr c, FailWithoutReason         ; If Data length is smaller than 2 bytes, signal an error
                        inc hl                          ; Look ahead to the first data byte
                        ld a, (hl)
                        or a
                        jr z, DataSuccess               ; If data first byte is 00 we can continue treating as a success
                        inc hl                          ; We have a failure,
                        ld a, (hl)                      ; so read the data second byte as the reason
                        jr FailWithReason               ; and return a failure    */
DataSuccess:            dec hl                          ; If data first byte is 00 (success), return to the original position before looking ahead
                        add hl, de                      ; Skip <length> bytes of data (for now)
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
                        jr nz, FindFrame                ; If not, find next frame marker
                        or a                            ; Clear carry for success,
                        ret                             ; and return.
FailWithoutReason:      xor a                           ; This returns error reason 0
FailWithReason:         ld (SLIP.LastErr), a            ; Save the error reason code for future use
                        scf                             ; Set carry for error,
                        ret                             ; and return.
pend

ESPWaitFlushWait        proc
                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ret
pend

ESPSendCmdWithDataProc  proc                            ; a = Op, de = DataAddr, hl = DataLen
                        ld (SLIP.HeaderOp), a           ; SMC> Copy Op into send buffer
                        ld (SLIP.HeaderDataLen), hl     ; SMC> Copy DataLen into send buffer
                        push bc                         ; Save ErrAddr till we're ready to check the result
                        push de                         ; Save DataAddr till we're ready to send data
                        call ESPWaitFlushWait

                        ld hl, SLIP.Header              ; This is the send buffer, freshly patched
                        ld de, SLIP.HeaderLen           ; Header send buffer is always 9 bytes long
                        call ESPSendBytesProc           ; Send all 9 bytes of the header (doesn't signal any error)

                        pop hl                          ; Restore DataAddr (in hl this time)
                        ld de, (SLIP.HeaderDataLen)     ; This is the same DataLen we patched into the header
                        call ESPSendBytesProc           ; Send all DataLen bytes of the data (doesn't signal any error)

                        ld hl, SLIP.Footer              ; This is the footer send buffer containing $C0
                        ld de, SLIP.FooterLen           ; Footer send buffer is always 1 byte long
                        call ESPSendBytesProc           ; Send the single byte of the footer (doesn't signal any error)

                        //pop hl:call ESPRead:ret       ; This would print the response in hex instead of validating it

                        call ESPReadIntoBuffer          ; Read the UART dry into the buffer, or at least 1024 bytes
                        ld a, (SLIP.HeaderOp)           ; Validate for the same Op we sent the command for
                        ld hl, Dummy32                  ; We don't want to preserve the value
                        //CSBreak()
                        call ESPValidateCmdProc         ; a = Op, hl = ValWordAddr (carry set means error)
                        pop hl                          ; Retrieve ErrAddr (always, to balance stack)
                        ret nc                          ; If no error we can return
                        jp ErrorProc                    ; Otherwise signal a fatal error with the passed-in error msg
pend

