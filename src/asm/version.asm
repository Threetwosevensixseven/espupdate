; version.asm
;
; Auto-generated by ZXVersion.exe
; On 12 Jan 2020 at 14:30

BuildNo                 macro()
                        db "12"
mend

BuildNoValue            equ "12"
BuildNoWidth            equ 0 + FW1 + FW2



BuildDate               macro()
                        db "12 Jan 2020"
mend

BuildDateValue          equ "12 Jan 2020"
BuildDateWidth          equ 0 + FW1 + FW2 + FWSpace + FWJ + FWa + FWn + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "14:30"
mend

BuildTimeValue          equ "14:30"
BuildTimeWidth          equ 0 + FW1 + FW4 + FWColon + FW3 + FW0



BuildTimeSecs           macro()
                        db "14:30:34"
mend

BuildTimeSecsValue      equ "14:30:34"
BuildTimeSecsWidth      equ 0 + FW1 + FW4 + FWColon + FW3 + FW0 + FWColon + FW3 + FW4
