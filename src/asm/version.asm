; version.asm
;
; Auto-generated by ZXVersion.exe
; On 04 Feb 2020 at 14:20

BuildNo                 macro()
                        db "51"
mend

BuildNoValue            equ "51"
BuildNoWidth            equ 0 + FW5 + FW1



BuildDate               macro()
                        db "04 Feb 2020"
mend

BuildDateValue          equ "04 Feb 2020"
BuildDateWidth          equ 0 + FW0 + FW4 + FWSpace + FWF + FWe + FWb + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "14:20"
mend

BuildTimeValue          equ "14:20"
BuildTimeWidth          equ 0 + FW1 + FW4 + FWColon + FW2 + FW0



BuildTimeSecs           macro()
                        db "14:20:06"
mend

BuildTimeSecsValue      equ "14:20:06"
BuildTimeSecsWidth      equ 0 + FW1 + FW4 + FWColon + FW2 + FW0 + FWColon + FW0 + FW6
