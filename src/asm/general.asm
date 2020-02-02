; general.asm

InstallErrorHandler     proc                            ; Our error handler gets called by the OS if SCROLL? N happens
                        ld hl, ErrorHandler             ; during printing, or any other ROM errors get thrown. We trap
                        Rst8(esxDOS.M_ERRH)             ; the error in our ErrorHandler routine to give us a chance to
                        ret                             ; clean up the dot cmd before exiting to BASIC.
pend

ErrorHandler            proc                            ; If we trap any errors thrown by the ROM, we currently just
                        ld hl, Err.Break                ; exit the dot cmd with a  "D BREAK - CONT repeats" custom
                        jp Return.WithCustomError       ; error.
pend

ErrorProc               proc
                        if enabled ErrDebug
                          ld a, (CRbeforeErr)           ; For debugging convenience, if the "Debug" UI checkbox is
                          or a                          ; ticked in Zeus, We will print the custom error message in
                          jr z, NoCR                    ; the top half of the screen, and stop dead with a red border.
                          push hl                       ; This really helps see the error when debugging with the dot
                          ld a, CR                      ; cmd invoked from autoexec.bas, as the main menu obscures any
                          call Rst16                    ; error messages during autoexec.bas execution.
                          pop hl
NoCR:                     call PrintRst16Error
Stop:                     Border(2)
                          jr Stop
                        else                            ; The normal (non-debug) error routine shows the error in both
                          ld a, (CRbeforeErr)           ; parts of the screen, and exits to BASIC.
                          or a                          ; Special CR routine, to handle the case when we print
                          jr z, NoCR                    ; backspaces with no CR during the flash progress loop.
                          push hl
                          ld a, CR
                          call Rst16
                          pop hl
NoCR:                     push hl                       ; If we want to print the error at the top of the screen,
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
Bank1 equ $+1:          ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
Bank2 equ $+1:          ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
Bank3 equ $+1:          ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
Bank4 equ $+1:          ld a, $FF                       ; Default value of $FF means not yet allocated
                        call Deallocate8KBank           ; Ignore any error because we are doing best efforts to exit
                                                        ; In more robust library code we might want to set these
                                                        ; locations back to $FF before exiting, but here we are
                                                        ; definitely exiting the dot command imminently.
                        nextreg $54, 4                  ; Restore what BASIC is expecting to find at $8000 (16K bank 2)
                        nextreg $55, 5                  ; Restore what BASIC is expecting to find at $A000 (16K bank 2)
                        nextreg $56, 0                  ; Restore what BASIC is expecting to find at $C000 (16K bank 0)
                        nextreg $57, 1                  ; Restore what BASIC is expecting to find at $C000 (16K bank 0)
                        ret
pend

RestoreSpeed            proc
Saved equ $+3:          nextreg Reg.CPUSpeed, SMC       ; Restore speed to what it originally was at dot cmd entry
                        ret
pend

Return                  proc                            ; This routine restores everything preserved at the start of
ToBasic:                                                ; the dot cmd, for success and errors, then returns to BASIC.
                        call DeallocateBanks            ; Return allocated 8K banks and restore upper 48K banking
                        call RestoreSpeed               ; Restore original CPU speed
                        call RestoreF8                  ; Restore original F8 enable/disable state
                        xor a
Stack                   ld sp, SMC                      ; Unwind stack to original point
Stack1                  equ Stack+1
IY1 equ $+1:            ld iy, SMC                      ; Restore IY
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

Wait5Frames             proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(5)                   ; Each frame is 1/50th of a second.
                        ret
pend

Wait30Frames            proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(30)                  ; Each frame is 1/50th of a second.
                        ret
pend

Wait80Frames            proc                            ; Convenience routines for different lengths of wait.
                        WaitFrames(80)                  ; Each frame is 1/50th of a second.
                        ret
pend

WaitFramesProc          proc
                        di
                        ld (SavedStack), sp             ; Save stack
                        ld sp, $8000                    ; Put stack in upper 48K so FRAMES gets updated (this is a
                        ei                              ; peculiarity of mode 1 interrupts inside dot commands).
Loop:                   halt                            ; Note that we already have a bank allocated by IDE_BANK
                        dec bc                          ; at $8000, so we're not corrupting BASIC by doing this.
                        ld a, b
                        or c
                        jr nz, Loop                     ; Wait for BC frames
                        di                              ; In this dot cmd interrupts are off unless waiting or printing
SavedStack equ $+1:     ld sp, SMC                      ; Restore stack
                        ret
pend

SaveReadTimeoutProc     proc                            ; a = FramesToWait. Since we only really need to call
                        push af                         ; ESPReadIntoBuffer with longer timeouts once, it's easier
                        ld a, (ESPReadIntoBuffer.WaitNFrames) ; to self-modify the timeout routine when needed,
                        ld (TimeoutBackup), a           ; rather than have it always take a timeout parameter.
                        pop af
Set:                    ld (ESPReadIntoBuffer.WaitNFrames), a
                        ret
pend

RestoreReadTimeoutProc  proc                            ; Counterpart to SaveReadTimeoutProc, restores the
                        ld a, (TimeoutBackup)           ; original timeout.
                        jr SaveReadTimeoutProc.Set
pend

/*WaitKey                 proc                          ; Just a debugging routine that allows me to clear
                        Border(6)                       ; my serial logs at a certain point, before logging
                        ei                              ; the traffic I'm interested in debugging.
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
pend*/

