; macros.asm

include "version.asm", 1                                ; Auto-generated by ..\build\cspect.bat or builddot.bat. Has
                                                        ; date/time and git commit counts generated by an external tool.
Border                  macro(Colour)
                        if Colour=0                     ; Convenience macro to help during debugging. The dot command
                          xor a                         ; doesn't change the border colour during regular operation.
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

Freeze                  macro(Colour1, Colour2)         ; Convenience macro to help during debugging. Alternates
Loop:                   Border(Colour1)                 ; the border rapidly between two colours. This really helps
                        Border(Colour2)                 ; to show that the machine hasn't crashed. Also it give you
                        jr Loop                         ; 8*7=56 colour combinations to use, instead of 7.
mend

MFBreak                 macro()                         ; Intended for NextZXOS NMI debugging
                        push af                         ; MF must be enabled first, by pressing M1 button
                        ld a, r                         ; then choosing Return from the NMI menu.
                        di
                        in a, ($3f)
                        rst 8                           ; It's possible the stack will end up unbalanced
mend                                                    ; if the MF break doesn't get triggered!

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

Page16kZXBank           macro(Bank, ReEnableInterrupts) ; Parameterised wrapper for doing 128K-style paging. Not used
                        ld a, ($5B5C)                   ; in regular dot command.
                        and $F8                         ; Previous value of port
                        or Bank                         ; Select bank
                        ld bc, 0x7ffd
                        di
                        ld ($5B5C), a
                        out (c), a
                        if (ReEnableInterrupts)
                          ei
                        endif
mend

MirrorA                 macro()                         ; Macro for Z80N mirror a opcode
                        noflow
                        db $ED, $24
mend

CpHL                    macro(Register)                 ; Convenience wrapper to compare HL with BC or DE
                        or a                            ; Note that Zeus macros can accept register literals, so the
                        sbc hl, Register                ; call would be CPHL(de) without enclosing quotes.
                        add hl, Register
mend

ErrorAlways             macro(ErrAddr)                  ; Parameterised wrapper for unconditional custom error
                        ld hl, ErrAddr
                        jp ErrorProc
mend

ErrorIfCarry            macro(ErrAddr)                  ; Parameterised wrapper for throwing custom esxDOS-style error
                        jp nc, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfNoCarry          macro(ErrAddr)                  ; Parameterised wrapper for throwing custom NextZXOS-style error
                        jp c, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

ErrorIfNotZero          macro(ErrAddr)                  ; Parameterised wrapper for throwing error after comparison
                        jp z, Continue
                        ld hl, ErrAddr
                        jp ErrorProc
Continue:
mend

PrintMsg                macro(Address)                  ; Parameterised wrapper for null-terminated buffer print routine
                        ld hl, Address
                        call PrintRst16
mend

PrintBufferHex          macro(Addr, Len)                ; Parameterised wrapper for fixed-length hex print routine
                        ld hl, Addr
                        ld de, Len
                        call PrintBufferHexProc
mend

SafePrintStart          macro()                         ; Included at the start of every routine which calls rst 16
                        di                              ; Interrupts off while paging. Subsequent code will enable them.
                        ld (SavedStackPrint), sp        ; Save current stack to be restored in SafePrintEnd()
                        ld sp, (Return.Stack1)          ; Set stack back to what BASIC had at entry, so safe for rst 16
                        push af
                        ld a, (IsNext)
                        or a
                        jr nz, NotNext
                        nextreg $54, 4                  ; Restore what BASIC is expecting to find at $8000 (16K bank 2)
                        nextreg $55, 5                  ; Restore what BASIC is expecting to find at $A000 (16K bank 2)
                        nextreg $56, 0                  ; Restore what BASIC is expecting to find at $C000 (16K bank 0)
                        nextreg $57, 1                  ; Restore what BASIC is expecting to find at $E000 (16K bank 0)
NotNext:                pop af
mend

SafePrintEnd            macro()                         ; Included at the end of every routine which calls rst 16
                        di                              ; Interrupts off while paging. Subsequent code doesn't care.
                        ld (SavedA), a                  ; Preserve A so it's completely free of side-effects
                        ld a, (DeallocateBanks.Bank1)   ; Read bank to restore at $8000
                        cp $FF                          ; If $FF we didn't allocate it yet,
                        jr z, NoBank1                   ; so don't restore,
                        nextreg $54, a                  ; otherwise restore original bank at $8000.
NoBank1:                ld a, (DeallocateBanks.Bank2)   ; Read bank to restore at $A000
                        cp $FF                          ; If $FF we didn't allocate it yet,
                        jr z, NoBank2                   ; so don't restore,
                        nextreg $55, a                  ; otherwise restore original bank at $A000.
NoBank2:                ld a, (DeallocateBanks.Bank3)   ; Read bank to restore at $C000
                        cp $FF                          ; If $FF we didn't allocate it yet,
                        jr z, NoBank3                   ; so don't restore,
                        nextreg $56, a                  ; otherwise restore original bank at $C000.
NoBank3:                ld a, (DeallocateBanks.Bank4)   ; Read bank to restore at $E000
                        cp $FF                          ; If $FF we didn't allocate it yet,
                        jr z, NoBank4                   ; so don't restore,
                        nextreg $57, a                  ; otherwise restore original bank at $E000.
NoBank4:
SavedA equ $+1:         ld a, SMC                       ; Restore A so it's completely free of side-effects
                        ld sp, (SavedStackPrint)        ; Restore stack to what it was before SafePrintStart()
mend

Rst8                    macro(Command)                  ; Parameterised wrapper for esxDOS API routine
                        rst $08
                        noflow
                        db Command
mend

NextRegRead             macro(Register)                 ; Nextregs have to be read through the register I/O port pair,
                        ld bc, $243B                    ; as there is no dedicated ZX80N opcode like there is for
                        ld a, Register                  ; writes.
                        out (c), a
                        inc b
                        in a, (c)
mend

WaitFrames              macro(Frames)                   ; Parameterised wrapper for safe halt routine
                        ld bc, Frames
                        call WaitFramesProc
mend

FillLDIR                macro(SourceAddr, Size, Value)  ; Parameterised wrapper for LDIR fill
                        ld a, Value
                        ld hl, SourceAddr
                        ld (hl), a
                        ld de, SourceAddr+1
                        ld bc, Size-1
                        ldir
mend

SetUARTBaud             macro(BaudTable, BaudMsg)       ; Parameterised wrapper for UART baud setting routine
                        ld hl, BaudTable                ; Not currently used
                        ld de, BaudMsg
                        call SetUARTBaudProc
mend


ESPSendBytes            macro(BufferStart, BufferLength) ; Parameterised wrapper for ESP send routine
                        ld hl, BufferStart
                        ld de, BufferLength
                        call ESPSendBytesProc
mend

ESPReadReg              macro(Addr32)                   ; Parameterised wrapper for ESP low level SLIP read routine
                        ld hl, Addr32 and $FFFF
                        ld (SLIP.ReadRegAddr), hl
                        ld hl, Addr32 >> 16
                        ld (SLIP.ReadRegAddr+2), hl
                        ld hl, SLIP.ReadReg
                        ld de, SLIP.ReadRegLen
                        call ESPSendBytesProc
mend

ESPValidateCmd          macro(Op, ValWordAddr)          ; Parameterised wrapper for ESP low level SLIP validate routine
                        ld a, Op
                        ld hl, ValWordAddr
                        call ESPValidateCmdProc
mend

ESPSendCmdWithData      macro(Op, DataAddr, DataLen, ErrAddr) ; Parameterised wrapper for ESP low level SLIP one-shot
                        ld a, Op                              ; send data routine
                        ld de, DataAddr                 ; This can be in de because it's just as quick to pop hl later
                        ld hl, DataLen                  ; This is faster being in hl because we copy to memory
                        ld bc, ErrAddr                  ; This can be in bc because it's just as quick to pop hl later
                        ld ix, 0
                        ld (SLIP.HeaderCS), ix          ; Clears the header checksum
                        call ESPSendCmdWithDataProc
mend

ESPSendDataBlock        macro(Opcode, DataAddr, DataLen, Seq, ErrAddr) ; Parameterised wrapper for ESP low level SLIP
                        ld hl, DataAddr                                ; repeating loop routine
                        ld bc, DataLen
                        call ESPSetDataBlockProc

                        ld hl, DataLen
                        ld de, Seq
                        call ESPSetDataBlockHeaderProc

                        ld a, Opcode
                        ld de, DataAddr                 ; This can be in de because it's just as quick to pop hl later
                        ld hl, DataLen+16               ; This is faster being in hl because we copy to memory
                        ld bc, ErrAddr                  ; This can be in bc because it's just as quick to pop hl later
                        ld ix, SLIP.DataBlock
                        call ESPSendCmdWithDataProc
mend

ESPSendDataBlockSeq     macro(Opcode, DataAddr, ErrAddr); As ESPSendDataBlock(), except:
                        ld hl, DataAddr
                        push de                         ; de = Seq, and
                        push bc                         ; bc = DataLen
                        call ESPSetDataBlockProc

                        pop hl                          ; hl = DataLen
                        pop de                          ; de = Seq
                        push hl                         ; Save DataLen again for the ESPSendCmdWithDataProc call
                        call ESPSetDataBlockHeaderProc

                        pop hl
                        ld de, 16
                        add hl, de                      ; hl = DataLen+16
                        ld a, Opcode
                        ld de, DataAddr
                        ld bc, ErrAddr
                        ld ix, SLIP.DataBlock
                        call ESPSendCmdWithDataProc
mend

SetReadTimeout          macro(FramesToWait)             ; Parameterised wrapper for the ESP SLIP buffer read timeout
                        ld a, FramesToWait              ; changing routine. Invoke RestoreReadTimeout() afterwards.
                        call SaveReadTimeoutProc
mend

RestoreReadTimeout      macro()                         ; Parameterised wrapper for the ESP SLIP buffer read timeout
                        call RestoreReadTimeoutProc     ; restoring routine. Invoke after SetReadTimeout()
mend

DisableReadValidate     macro()
                        ld hl, ESPNoValidateCmdProc     ; Parameterised wrapper for the ESP SLIP buffer read validate
                        ld (ESPSendCmdWithDataProc.ValidateProcSMC), hl ; disabling routine. Invoke
mend                                                                    ; DisableReadValidate() afterwards.

EnableReadValidate     macro()
                        ld hl, ESPValidateCmdProc       ; Parameterised wrapper for the ESP SLIP buffer read validate
                        ld (ESPSendCmdWithDataProc.ValidateProcSMC), hl ; re-enabling routine. Invoke after
mend                                                                    ; EnableReadValidate().

