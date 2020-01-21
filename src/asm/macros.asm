; macros.asm

include "version.asm", 1                                ; Auto-generated by ..\build\cspect.bat or builddot.bat

Border                  macro(Colour)
                        if Colour=0
                          xor a
                        else
                          ld a, Colour
                        endif
                        out (ULA_PORT), a
                        if Colour=0
                          xor a
                        else
                          ld a, Colour*8
                        endif
                        ld (23624), a
mend

Freeze                  macro(Colour1, Colour2)
Loop:                   Border(Colour1)
                        Border(Colour2)
                        jr Loop
mend

CSBreak                 macro()                         ; Intended for CSpect debugging
                        push bc                         ; enabled when the -brk switch is supplied
                        noflow                          ; Mitigate the worst effect of running on real hardware
                        db $DD, $01                     ; On real Z80 or Z80N, this does NOP:LD BC, NNNN
                        nop                             ; so we set safe values for NN
                        nop                             ; and NN,
                        pop bc                          ; then we restore the value of bc we saved earlier
mend

CSExit                  macro()                         ; Intended for CSpect debugging
                        noflow                          ; enabled when the -exit switch is supplied
                        db $DD, $00                     ; This executes as NOP:NOP on real hardware
mend

PrintMsg                macro(Address)
                        ld hl, Address
                        call PrintRst16
mend

Rst8                    macro(Command)
                        rst $08
                        noflow
                        db Command
mend

ESPSendBytes            macro(BufferStart, BufferLength)
                        ld hl, BufferStart
                        ld de, BufferLength
                        call ESPSendBytesProc
mend

ESPReadReg              macro(Addr32)
                        ld hl, Addr32 and $FFFF
                        ld (SLIP.ReadRegAddr), hl
                        ld hl, Addr32 >> 16
                        ld (SLIP.ReadRegAddr+2), hl
                        ld hl, SLIP.ReadReg
                        ld de, SLIP.ReadRegLen
                        call ESPSendBytesProc
mend

NextRegRead             macro(Register)
                        ld bc, $243B
                        ld a, Register
                        out (c), a
                        inc b
                        in a, (c)
mend

WaitFrames              macro(Frames)
                        ei
                        for n = 1 to Frames
                          halt
                        next
                        di
mend

FillLDIR                macro(SourceAddr, Size, Value)
                        ld a, Value
                        ld hl, SourceAddr
                        ld (hl), a
                        ld de, SourceAddr+1
                        ld bc, Size-1
                        ldir
mend

ESPValidateCmd          macro(Op, ValWordAddr)
                        ld a, Op
                        ld hl, ValWordAddr
                        call ESPValidateCmdProc
mend

ErrorAlways             macro(ErrAddr)
                        ld hl, ErrAddr
                        jp ErrorProc
mend

ErrorIfCarry            macro(ErrAddr)
                        jp nc, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfNoCarry          macro(ErrAddr)
                        jp c, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

PrintBufferHex          macro(Addr, Len)
                        ld hl, Addr
                        ld de, Len
                        call PrintBufferHexProc
mend

Page16kZXBank           macro(Bank, ReEnableInterrupts)
                        ld a, ($5B5C)                   ; Previous value of port
                        and $F8
                        or Bank                         ; Select bank
                        ld bc, 0x7ffd
                        di
                        ld ($5B5C), a
                        out (c), a
                        if (ReEnableInterrupts)
                          ei
                        endif
mend

MirrorA                 macro()
                        noflow
                        db $ED, $24
mend

ESPSendCmdWithData      macro(Op, DataAddr, DataLen, ErrAddr)
                        ld a, Op
                        ld de, DataAddr                 ; This can be in de because it's just as quick to pop hl later
                        ld hl, DataLen                  ; This is faster being in hl because we copy to memory
                        ld bc, ErrAddr                  ; This can be in bc because it's just as quick to pop hl later
                        ld ix, 0
                        ld (SLIP.HeaderCS), ix          ; Clears the header checksum
                        call ESPSendCmdWithDataProc
mend

ESPSendDataBlock        macro(DataAddr, DataLen, Seq, ErrAddr)
                        ld hl, DataAddr
                        ld bc, DataLen
                        call ESPSetDataBlockProc

                        ld hl, DataLen
                        ld de, Seq
                        call ESPSetDataBlockHeaderProc

                        ld a, ESP_MEM_DATA
                        ld de, DataAddr                 ; This can be in de because it's just as quick to pop hl later
                        ld hl, DataLen+16               ; This is faster being in hl because we copy to memory
                        ld bc, ErrAddr                  ; This can be in bc because it's just as quick to pop hl later
                        ld ix, SLIP.DataBlock
                        call ESPSendCmdWithDataProc
mend

