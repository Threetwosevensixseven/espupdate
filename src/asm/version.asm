; version.asm
;
; Auto-generated by ZXVersion.exe
; On 09 Feb 2020 at 14:48

BuildNo                 macro()
                        db "58"
mend

BuildNoValue            equ "58"
BuildNoWidth            equ 0 + FW5 + FW8



BuildDate               macro()
                        db "09 Feb 2020"
mend

BuildDateValue          equ "09 Feb 2020"
BuildDateWidth          equ 0 + FW0 + FW9 + FWSpace + FWF + FWe + FWb + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "14:48"
mend

BuildTimeValue          equ "14:48"
BuildTimeWidth          equ 0 + FW1 + FW4 + FWColon + FW4 + FW8



BuildTimeSecs           macro()
                        db "14:48:31"
mend

BuildTimeSecsValue      equ "14:48:31"
BuildTimeSecsWidth      equ 0 + FW1 + FW4 + FWColon + FW4 + FW8 + FWColon + FW3 + FW1
