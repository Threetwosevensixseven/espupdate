; version.asm
;
; Auto-generated by ZXVersion.exe
; On 11 Feb 2020 at 12:09

BuildNo                 macro()
                        db "61"
mend

BuildNoValue            equ "61"
BuildNoWidth            equ 0 + FW6 + FW1



BuildDate               macro()
                        db "11 Feb 2020"
mend

BuildDateValue          equ "11 Feb 2020"
BuildDateWidth          equ 0 + FW1 + FW1 + FWSpace + FWF + FWe + FWb + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "12:09"
mend

BuildTimeValue          equ "12:09"
BuildTimeWidth          equ 0 + FW1 + FW2 + FWColon + FW0 + FW9



BuildTimeSecs           macro()
                        db "12:09:39"
mend

BuildTimeSecsValue      equ "12:09:39"
BuildTimeSecsWidth      equ 0 + FW1 + FW2 + FWColon + FW0 + FW9 + FWColon + FW3 + FW9
