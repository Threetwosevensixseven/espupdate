; general.asm

InstallErrorHandler     proc
                        ld hl, ErrorHandler
                        Rst8(esxDOS.M_ERRH)
                        ret
pend

ErrorHandler            proc
                        ld hl, Err.Break
                        jp Return.WithCustomError
pend

ErrorProc               proc
                        if enabled ErrDebug
                          call PrintRst16Error
Stop:                     Border(2)
                          jr Stop
                        else
                          push hl                       ; If we want to print the error at the top of the screen,
                          call PrintRst16Error          ; as well as letting BASIC print it in the lower screen,
                          pop hl                        ; then uncomment this code.
                          jp Return.WithCustomError     ; Straight to the error handing exit routine
                        endif
pend

RestoreF8               proc
Saved equ $+1:          ld a, SMC                       ; This was saved here when we entered the dot command
                        and %1000 0000                  ; Mask out everything but the F8 enable bit
                        ld d, a
                        NextRegRead(Reg.Peripheral2)    ; Read the current value of Peripheral 2 register
                        and %0111 1111                  ; Clear the F8 enable bit
                        or d                            ; Mask back in the saved bit
                        nextreg Reg.Peripheral2, a      ; Save back to Peripheral 2 register
                        ret
pend

DeallocateBanks         proc
Upper1 equ $+1:         ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
Upper2 equ $+1:         ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
                                                        ; In more robust library code we might want to set these
                                                        ; locations back to $FF before exiting, but here we are
                                                        ; definitely exiting the dot command imminently.
                        nextreg $54, 4                  ; Restore what BASIC is expecting to find at $8000 (16K bank 2)
                        nextreg $55, 5                  ; Restore what BASIC is expecting to find at $A000 (16K bank 2)
                        ret
pend

RestoreSpeed            proc
Saved equ $+3:          nextreg Reg.CPUSpeed, SMC       ; Restore speed
                        ret
/*
                        // This section is just for testing speed restore with Garry
                        PrintMsg(Msg.Speed1)            ; "Restoring speed to "
Saved equ $+1:          ld a, SMC                       ; This is written into by code at the start of the dot cmd
                        push af                         ; Save for later
                        nextreg Reg.CPUSpeed, a         ; Restore speed
                        and %11                         ; Lookup speed (0..3) in messages table
                        add a, a                        ; * 2
                        ld hl, Speeds.Table
                        add hl, a
                        ld e, (hl)
                        inc hl
                        ld d, (hl)
                        ex de, hl                       ; HL now contains one of the four speed msg addresses
                        call PrintRst16                 ; Print speed
                        PrintMsg(Msg.Speed2)            ; " (0x"
                        pop af                          ; Get actual restored speed
                        call PrintAHexNoSpace           ; Print hex digits of register value
                        ld a, ')'                       ; Print ")", CR
                        rst 16
                        ld a, CR
                        rst 16
                        WaitFrames(100)
                        ret
*/
pend

/*Speeds proc Table:
  ;  MsgAddr     Index  Notes
  dw Msg.Speed35 ;   0  Prints "3.5Mhz"
  dw Msg.Speed07 ;   1  Prints "7Mhz"
  dw Msg.Speed14 ;   2  Prints "14Mhz"
  dw Msg.Speed28 ;   3  Prints "28Mhz"
pend*/

Return                  proc
ToBasic:
                        call DeallocateBanks            ; Return allocated 8K banks and restore upper 48K banking
                        call RestoreSpeed               ; Restore original CPU speed
                        call RestoreF8                  ; Restore original F8 enable/disable state
                        xor a
Stack                   ld sp, SMC                      ; Unwind stack to original point
Stack1                  equ Stack+1
                        ei
                        ret                             ; Return to BASIC
WithCustomError:
                        push hl
                        call DeallocateBanks            ; Return allocated 8K banks and restore upper 48K banking
                        call RestoreSpeed               ; Restore original CPU speed
                        call RestoreF8                  ; Restore original F8 enable/disable state
                        xor a
                        scf                             ; Signal error, hl = custom error message
                        pop hl
                        jp Stack                        ; (NextZXOS is not currently displaying standard error messages,
pend                                                    ;  with a>0 and carry cleared, so we use a custom message.)

Allocate8KBank          proc
                        ld hl, $0001                    ; H = $00: rc_banktype_zx, L = $01: rc_bank_alloc
Internal:               exx
                        ld c, 7                         ; 16K Bank 7 required for most NextZXOS API calls
                        ld de, IDE_BANK                 ; M_P3DOS takes care of stack safety stack for us
                        Rst8(esxDOS.M_P3DOS)            ; Make NextZXOS API call through esxDOS API with M_P3DOS
                        ErrorIfNoCarry(Err.NoMem)       ; Fatal error, exits dot command
                        ld a, e                         ; Return in a more conveniently saveable register (A not E)
                        ret
pend

Deallocate8KBank        proc                            ; Takes bank to deallocate in A (not E) for convenience
                        cp $FF                          ; If value is $FF it means we never allocated the bank,
                        ret z                           ; so return with carry clear (error) if that is the case
                        ld e, a                         ; Now move bank to deallocate into E for the API call
                        ld hl, $0003                    ; H = $00: rc_banktype_zx, L = $03: rc_bank_free
                        jr Allocate8KBank.Internal      ; Rest of deallocate is the same as the allocate routine
pend

Wait5Frames             proc
                        ei
                        for n = 1 to 5
                          halt
                        next
                        di
                        ret
pend

Wait80Frames            proc
                        ei
                        for n = 1 to 80
                          halt
                        next
                        di
                        ret
pend

; From http://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Division
DivideACbyDE            proc                            ; Divides AC by DE
                        ld hl, 0
                        ld b, 16
Loop:                   sli c                           ; aka SLL/SL1
                        rla
                        adc hl, hl
                        sbc hl, de
                        jr nc, $+4
                        add hl, de
                        dec c
                        djnz Loop
                        ret                             ; Returns quotient in AC, remainder in HL
pend

WaitKey                 proc
                        Border(6)
                        ei
Loop1:                  xor a
                        in a, ($FE)
                        cpl
                        and 15
                        halt
                        jr nz, Loop1
Loop2:                  xor a
                        in a, ($FE)
                        cpl
                        and 15
                        halt
                        jr z, Loop2
                        Border(7)
                        di
                        ret
pend

