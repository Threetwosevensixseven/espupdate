; general.asm

Allocate8KBank          proc
                        ld (Stack), sp                  ; Save stack just for this routine
                        ld sp, $4000                    ; Temporarily put stack right at the end of the 8K dot cmd
                        ld hl, $0001                    ; H = $00: rc_banktype_zx, L = $01: rc_bank_alloc
                        exx
                        ld c, 7                         ; 16K Bank 7 required for most NextZXOS API calls
                        ld de, IDE_BANK
                        Rst8(esxDOS.M_P3DOS)            ; Make NextZXOS API call through esxDOS API with M_P3DOS
Stack equ $+1:          ld sp, SMC                      ; Restore stack before dealing with error
                        ErrorIfNoCarry(Err.NoMem)       ; Fatal error, exits dot command
                        ld a, e                         ; Return in a more conveniently saveable register
                        ret
pend

