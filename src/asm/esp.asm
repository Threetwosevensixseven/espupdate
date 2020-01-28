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
  Stub2:                dl 0x00000300
                        dl 0x00000001
                        dl 0x00001800
                        dl 0x3FFFABA4
  Stub2Len              equ $-Stub2                     ; Stub2 should be 16 bytes long
  DataBlock:            dl 0x00000000                   ; len(data)
                        dl 0x00000000                   ; block number
                        dl 0x00000000                   ; unk1
                        dl 0x00000000                   ; unk2
  DataBlockLen          equ $-DataBlock                 ; DataBlock should be 16 bytes long
  EntryBlock:           dl 0x00000000                   ; int(entrypoint == 0)
                        dl 0x4010E004                   ; entrypoint
  EntryBlockLen         equ $-EntryBlock                ; EntryBlock should be 8 bytes long
  CfgFlash:             dl 0x00000000                   ; fl_id
                        dl 0x00100000                   ; total_size
                        dl 0x00010000                   ; block_size
                        dl 0x00001000                   ; sector_size
                        dl 0x00000100                   ; page_size
                        dl 0x0000ffff                   ; status_mask
  CfgFlashLen           equ $-CfgFlash                  ; CfgFlash should be 24 bytes long
  ChgBaud:              dl 0x00119400                   ; New baud (1152000)
                        dl 0x0001c200                   ; Original baud (115200)
  ChgBaudLen            equ $-ChgBaud                   ; ChgBaud should be 8 bytes long
  FlashBlock:           dl 0x00100000                   ; uncompressed total size (1MB)
                        dl 0x0000001c                   ; total blocks (28)
                        dl 0x00004000                   ; flash write size (16KB)
                        dl 0x00000000                   ; address (0)
  FlashBlockLen         equ $-FlashBlock                ; FlashBlock should be 16 bytes long
  LastErr:              ds 0
pend

Baud                    proc Table:
b115200:                dw $8173, $8178, $817F, $8204, $820D, $8215, $821E, $816A
b1152000:               dw $8018, $8019, $801A, $801A, $801B, $801C, $801D, $8017
pend

Timings:                proc Table:
  ;   Text   Index  Notes
  db "VGA0", 0 ; 0  Timing 0
  db "VGA1", 0 ; 1  Timing 1
  db "VGA2", 0 ; 2  Timing 2
  db "VGA3", 0 ; 3  Timing 3
  db "VGA4", 0 ; 4  Timing 4
  db "VGA5", 0 ; 5  Timing 5
  db "VGA6", 0 ; 6  Timing 6
  db "HDMI", 0 ; 7  Timing 7
pend

ESPSetDataBlockHeaderProc proc
                        ld (SLIP.DataBlock), hl
                        ld (SLIP.DataBlock+4), de
                        ld hl, 0
                        ld (SLIP.DataBlock+2), hl
                        ld (SLIP.DataBlock+6), hl
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

ESPSendBytesEscProc     proc                            ; hl = Buffer, de = Length
                        ld bc, UART_GetStatus           ; UART Tx port also gives the UART status when read
WaitNotBusy:            in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy              ; If busy, keep trying until not busy
                        ld a, (hl)                      ; Otherwise read the next byte of the text to be sent
CheckC0:
                        cp $C0
                        jr nz, CheckDB
                        ld a, $DB                       ; Escape $C0 by replacing with $DB $DC
                        out (c), a
                        ld a, $DC
                        jr NoEsc
CheckDB:
                        cp $DB
                        jr nz, NoEsc
                        out (c), a                      ; Escape $DB by replacing with $DB $DD
                        ld a, $DD
NoEsc:
                        out (c), a                      ; and send it to the UART TX port
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

/*ESPRead                 proc
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
pend*/

/*ESPReadPrint            proc
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
pend*/

ESPClearBuffer:         proc
                        FillLDIR(Buffer, Buffer.Len, 0)
                        ret
pend

ESPReadIntoBuffer       proc
                        di
                        ld (SavedStack), sp             ; Save stack
                        ld sp, $8000                    ; Put stack in upper 16K so FRAMES gets update
                        ei
                        call ESPClearBuffer
                        ld a, (FRAMES)
                        add a, 5
                        ld (TimeoutFrame), a
                        ld bc, UART_GetStatus
                        ld hl, Buffer
                        ld de, Buffer.Len
WaitNotBusy:            in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if available
                        ld a, (FRAMES)
TimeoutFrame equ $+1:   cp SMC
                        jp nz, WaitNotBusy              ; Try again for at least another N frames (5)
                        di
                        scf                             ; Set carry to signal error if N frames with no data,
                        jr Return                       ; and return
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
Return:                 di
SavedStack equ $+1:     ld sp, SMC
                        ret                             ; and return
pend

ESPValidateCmdProc      proc                            ; a = Op, hl = ValWordAddr
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
FailWithReason:         ld (SLIP.LastErr), a            ; Save the error reason code for future use
                        or a
                        jp z, ErrorCd00                 ; Error code 00 is not a real error, it means success
                        push af
                        PrintMsg(Msg.ErrCd)             ; "Error code: "
                        pop af
                        push af
                        call PrintAHexNoSpace           ; Print A in hex
                        ld a, CR                        ; Print CR
                        call Rst16
                        pop af
ErrorCd00:              scf                             ; Set carry for error,
                        ret                             ; and return.
FailWithoutReason:      xor a                           ; This returns error reason 0
                        scf
                        ret
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

                        ld a, ixh                       ; if IX > $00FF then we want to treat it as an additional
                        or a                            ; 16 bytes of data to be sent at the beginning
                        jp z, NoDataBlock16             ; of the data block.

                        push ix
                        pop hl
                        ld de, 16
                        call ESPSendBytesProc           ; Send all DataLen bytes of the data (doesn't signal any error)
                        ld hl, (SLIP.HeaderDataLen)
                        ld de, 16
                        or a
                        sbc hl, de
                        ld (SLIP.HeaderDataLen), hl
NoDataBlock16:
                        pop hl                          ; Restore DataAddr (in hl this time)
                        ld de, (SLIP.HeaderDataLen)     ; This is the same DataLen we patched into the header
                        call ESPSendBytesEscProc        ; Send all DataLen bytes of the data (doesn't signal any error)

                        ld hl, SLIP.Footer              ; This is the footer send buffer containing $C0
                        ld de, SLIP.FooterLen           ; Footer send buffer is always 1 byte long
                        call ESPSendBytesProc           ; Send the single byte of the footer (doesn't signal any error)

                        //pop hl:call ESPRead:ret       ; This would print the response in hex instead of validating it

                        call ESPReadIntoBuffer          ; Read the UART dry into the buffer, or at least 1024 bytes
                        ld a, (SLIP.HeaderOp)           ; Validate for the same Op we sent the command for
                        ld hl, Dummy32                  ; We don't want to preserve the value
                        call ESPValidateCmdProc         ; a = Op, hl = ValWordAddr (carry set means error)
                        pop hl                          ; Retrieve ErrAddr (always, to balance stack)
                        ret nc                          ; If no error we can return
                        jp ErrorProc                    ; Otherwise signal a fatal error with the passed-in error msg
pend

ESPSetDataBlockProc     proc
                        push bc
                        ld a, ESP_CHECKSUM_MAGIC        ; Checksum seed: $EF
Loop:                   xor (hl)
                        dec bc
                        push af
                        ld a, b
                        or c
                        jp z, Finish
                        pop af
                        inc hl
                        jp Loop
Finish:                 pop af                          ; This is the calculated checksum
                        ld hl, SLIP.HeaderCS            ; Write it to the header
                        ld (hl), a
                        inc hl
                        ld (hl), 0
                        inc hl
                        ld (hl), 0
                        pop hl                          ; This is the passed in data length
                        ld (SLIP.DataBlock), hl         ; Write it to the first data block long word
                        ld hl, 0
                        ld (SLIP.DataBlock+2), hl
                        ret
pend

SetUARTBaudProc         proc                            ; hl = BaudTable, de = BaudMsg
                        push de
                        ld (BaudTable), hl
                        PrintMsg(Msg.SetBaud1)          ; "Using "
                        pop hl
                        call PrintRst16                 ; Print BaudMsg
                        PrintMsg(Msg.SetBaud2)          ; " baud, "
                        NextRegRead(Reg.VideoTiming)
                        and %111
                        push af
                        ld d, a
                        ld e, 5
                        mul
                        ex de, hl
                        add hl, Timings.Table
                        call PrintRst16                 ; "VGA0/../VGA6/HDMI"
                        PrintMsg(Msg.SetBaud3)          ; " timings"
                        pop af
                        add a,a
BaudTable equ $+1:      ld hl, SMC                      ; Restore BaudTable
                        add hl, a
                        ld e, (hl)
                        inc hl
                        ld d, (hl)
                        ex de, hl                       ; HL now contains the prescalar baud value
                        ld (Prescaler), hl
                        ld a, %x0x1 x000                ; Choose ESP UART, and set most significant bits
                        ld (Prescaler+2), a             ; of the 17-bit prescalar baud to zero,
                        ld bc, UART_Sel                 ; by writing to port 0x143B.
                        out (c), a
                        dec b                           ; Set baud by writing twice to port 0x143B
                        out (c), l                      ; Doesn't matter which order they are written,
                        out (c), h                      ; because bit 7 ensures that it is interpreted correctly.
                        inc b                           ; Write to UART control port 0x153B
                        ret
pend

