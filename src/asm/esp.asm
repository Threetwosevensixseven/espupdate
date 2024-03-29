; esp.asm

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
  FlashBlock:           dl 0x00100000                   ; uncompressed total size (1MB, hardcoded for now)
                        dl 0x00000000                   ; total blocks (28, will be written from FW header)
                        dl 0x00000000                   ; flash write size (16KB, will be written from FW header)
                        dl 0x00000000                   ; address (0, hardcoded for now)
  FlashBlockLen         equ $-FlashBlock                ; FlashBlock should be 16 bytes long
  Md5Block:             dl 0x00000000                   ; address (0, hardcoded for now)
                        dl 0x00100000                   ; uncompressed total size (1MB, hardcoded for now)
                        dl 0x00000000                   ; unk1
                        dl 0x00000000                   ; unk2
  Md5BlockLen           equ $-Md5Block                  ; Md5Block should be 16 bytes long
  FinalizeBlock:        dl 0x00000000                   ; erase_size (0, hardcoded)
                        dl 0x00000000                   ; num_blocks (0, hardcoded)
                        dl 0x00000000                   ; FLASH_WRITE_SIZE (16KB, will be written from FW header)
                        dl 0x00000000                   ; offset (0, hardcoded)
  FinalizeBlockLen      equ $-FinalizeBlock             ; FinalizeBlock should be 16 bytes long
  ExitBlock:            dl 0x00000001                   ; int(not reboot) (1, hardcoded)
  ExitBlockLen          equ $-ExitBlock                 ; ExitBlock should be 4 bytes long
  Dump:                 dl 0x00000000                   ; offset (start of FLASH, hardcoded)
  DumpSize equ $+1:     dl 0x00004000                   ; length (length to dump, 1MB or 4MB, default 16K)
                        dl 0x00001000                   ; FLASH_SECTOR_SIZE (4KB, hardcoded, can't change)
                        dl 0x00000001                   ; packets (1, hardcoded, higher values are same as 1)
  DumpLen               equ $-Dump                      ; Dump should be 16 bytes long
  DumpAck:              db $C0
  DumpAckBytesRcvd:     dl 0x00000000                   ; 32bit number of chars received in dump packet
                        db $C0                          ; Will have packet size added to it each time
  DumpAckLen            equ $-DumpAck
  LastErr:              ds 0
pend

Baud                    proc Table:
b115200:                dw $8173, $8178, $817F, $8204, $820D, $8215, $821E, $816A
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
WaitNotBusy1:           in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy1             ; If busy, keep trying until not busy
                        ld a, (hl)                      ; Otherwise read the next byte of the text to be sent
CheckC0:                cp $C0
                        jr nz, CheckDB
                        ld a, $DB                       ; Escape $C0 by replacing with $DB $DC without changing hl or de
                        out (c), a
WaitNotBusy2:           in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy2             ; If busy, keep trying until not busy
                        ld a, $DC
                        jr NoEsc
CheckDB:                cp $DB
                        jr nz, NoEsc
                        out (c), a                      ; Escape $DB by replacing with $DB $DD without changing hl or de
WaitNotBusy3:           in a, (c)                       ; Read the UART status
                        and UART_mTX_BUSY               ; and check the busy bit (bit 1)
                        jr nz, WaitNotBusy3             ; If busy, keep trying until not busy
                        ld a, $DD
NoEsc:                  out (c), a                      ; and send it to the UART TX port
                        inc hl                          ; Move to next byte of the text
                        dec de                          ; Check whether there are any more bytes of text
                        ld a, d
                        or e
                        jr nz, WaitNotBusy1             ; If there are, read and repeat
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
                        ld hl, (FRAMES)
                        add hl, [WaitNFrames]5
                        ld (TimeoutFrame), hl
                        ld bc, UART_GetStatus
                        ld hl, [BufferAddr]Buffer
                        ld de, [BufferLen]Buffer.Len
WaitNotBusy:            in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jp c, HasData                   ; Read Data if available
                        push hl
                        push bc
                        ld hl, (FRAMES)
                        ld bc, [TimeoutFrame]SMC
                        CpHL(bc)
                        pop bc
                        pop hl
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
                        ld sp, [SavedStack]SMC
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
                        jp nz, FailWithoutReason        ; If we didn't find a $C0, exit with failure
                        ld a, (hl)                      ; Read req/resp
                        call SlipUnescape
                        dec bc
                        cp 1                            ; Is cmd response?
                        jr nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read Op
                        call SlipUnescape
                        cp [Opcode]SMC                  ; Is expected Op?
                        jr nz, FindFrame                ; If not, find next frame marker
                        inc hl
                        dec bc
                        ld a, (hl)
                        call SlipUnescape
                        ld e, a
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read length word
                        call SlipUnescape
                        ld d, a
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 1
                        call SlipUnescape
                        ld ([ValWordAddr1]SMC), a       ; Save value byte 1
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 2
                        call SlipUnescape
                        ld ([ValWordAddr2]SMC), a       ; Save value byte 2
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 3
                        call SlipUnescape
                        ld ([ValWordAddr3]SMC), a       ; Save value byte 3
                        inc hl
                        dec bc
                        ld a, (hl)                      ; Read value byte 4
                        call SlipUnescape
                        ld ([ValWordAddr4]SMC), a       ; Save value byte 4
                        ld a, e                         ; Simplistic version of checking DE is at least 2
                        or d                            ; Should always be larger hopefully, given the nature or ORing 0, 1 or 2 with the MSB
                        cp 2                            ; TODO: If we get unexpected failures later, revisit this compare
                        jr c, FailWithoutReason         ; If Data length is smaller than 2 bytes, signal an error
                        inc hl                          ; Look ahead to the first data byte
                        ld a, (hl)
                        call SlipUnescape
                        or a
                        jr z, DataSuccess               ; If data first byte is 00 we can continue treating as a success
                        inc hl                          ; We have a failure,
                        ld a, (hl)                      ; so read the data second byte as the reason
                        call SlipUnescape
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
                        ld a, (CRbeforeErr)
                        or a
                        jr z, NoCRBefore
                        PrintMsg(Msg.EOL)
                        xor a
                        ld (CRbeforeErr), a
NoCRBefore:             PrintMsg(Msg.ErrCd)             ; "Error code: "
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

SlipUnescape            proc                            ; a = byte to unescape, hl = input buffer address
                        cp $DB                          ; $DB $DC needs unescaping to $C0, and
                        ret nz                          ; $DB $DD needs unescaping to $DB.
                        inc hl                          ; Advance pointer without changing counter or destination
                        ld a, (hl)                      ; Peek at second byte of potential escaping pair
                        cp $DC
                        jr nz, TryDD
                        ld a, $C0                       ; We have unescaped to $C0,
                        ret                             ; so return.
TryDD:                  cp $DD
                        jr nz, Not2ndOfPair
                        ld a, $DB                       ; We have unescaped to $DB,
                        ret                             ; so return.
                        ret
Not2ndOfPair:           dec hl                          ; Not an escaped pair,
                        ld a, $DB                       ; so unwind
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

                        ld hl, SLIP.Footer              ; First byte of SLIP header mustn't be escaped
                        ld de, SLIP.FooterLen           ; It is always 1 byte long
                        call ESPSendBytesProc           ; Send first byte of the header (doesn't signal any error)

                        ld hl, SLIP.Header+1            ; This is the remaining send buffer, freshly patched
                        ld de, SLIP.HeaderLen-1         ; Always eight bytes, and MUST be escaped!
                        call ESPSendBytesEscProc        ; Send all 8 bytes of the header (doesn't signal any error)

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
                        call [ValidateProcSMC]ESPValidateCmdProc ; < SMC a = Op, hl = ValWordAddr (carry set means error)
                        pop hl                          ; Retrieve ErrAddr (always, to balance stack)
                        ret nc                          ; If no error we can return
                        jp ErrorProc                    ; Otherwise signal a fatal error with the passed-in error msg
pend

ESPNoValidateCmdProc    proc
                        or a
                        ret
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
                        ld hl, [BaudTable]SMC           ; Restore BaudTable
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

ResetESP                proc                            ; Reset ESP with a normal (non-programming) reset
                        ld a, (InProgMode)
                        or a
                        jr z, NoReset
                        nextreg 2, 128                  ; Set RST low
                        call Wait5Frames                ; Hold in reset
                        nextreg 2, 0                    ; Set RST high
NoReset:                ret
pend

; Each SLIP packet begins and ends with 0xC0. Within the packet, all occurrences of 0xC0 and 0xDB
; are replaced with 0xDB 0xDC and 0xDB 0xDD, respectively. The replacing is to be done after the
; checksum and lengths are calculated, so the packet length may be longer than the size field below.
ESPReadandDecodePacket  proc
                        di
                        ld (SavedStack), sp             ; Save stack
                        ld sp, $8000                    ; Put stack in upper 16K so FRAMES gets update
                        //ld a, 24
                        //ld (SCR_CT), a
                        //ld a, '.'
                        //rst 16
                        ei
                        //FillLDIR(BigBuffer, BigBufferLen, 0) ; Clear big read buffer
                        xor a
                        ld (CountC0), a                 ; Start off with C0 count as zero
                        ld bc, UART_GetStatus
                        ld hl, BigBuffer
                        ld de, BigBufferLen
AnotherByte:            call GetByte
                        cp $C0
                        jr nz, NotC0
                        ld a, (CountC0)
                        cp 1
                        jr z, Success
                        inc a
                        ld (CountC0), a
                        jr NextChar
NotC0:                  cp $DB                          ; $DB is a SLIP escape character
                        jr nz, Decoded
                        call GetByte
                        cp $DC
                        jr nz, NotDC
                        ld a, $C0                       ; $DB $DC becomes $CO (without incrementing CountC0)
                        jr Decoded
NotDC:                  cp $DD
                        jr nz, Error
                        ld a, $DB                       ; $DB DD becomes $DB
Decoded:                ld (hl), a                      ; Write decoded char into buffer
                        inc hl
                        dec de                          ; See if any more buffer left
NextChar:               ld a, d
                        or e
                        jr nz, AnotherByte              ; If so, check if there are more data bytes ready to read,
                        jr Error
GetByte:                in a, (c)                       ; This inputs from the 16-bit address UART_GetStatus
                        rrca                            ; Check UART_mRX_DATA_READY flag in bit 0
                        jr nc, GetByte                  ; Read Data if available
HasData:                inc b                           ; Otherwise Read the byte,
                        in a, (c)                       ; from the UART Rx port,
                        dec b
                        ret
Error:                  ld a, 24
                        ld (SCR_CT), a
                        ld a, CR
                        rst 16
                        scf                             ; Signal error
                        jr Return
Success:                or a                            ; otherwise clear carry to signal success,
Return:                 di
                        ld sp, [SavedStack]SMC
                        ret                             ; and return
pend

