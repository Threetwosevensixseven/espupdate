; version.asm
;
; Auto-generated by ZXVersion.exe
; On 12 Jan 2020 at 15:28

BuildNo                 macro()
                        db "13"
mend

BuildNoValue            equ "13"
BuildNoWidth            equ 0 + FW1 + FW3



BuildDate               macro()
                        db "12 Jan 2020"
mend

BuildDateValue          equ "12 Jan 2020"
BuildDateWidth          equ 0 + FW1 + FW2 + FWSpace + FWJ + FWa + FWn + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "15:28"
mend

BuildTimeValue          equ "15:28"
BuildTimeWidth          equ 0 + FW1 + FW5 + FWColon + FW2 + FW8



BuildTimeSecs           macro()
                        db "15:28:59"
mend

BuildTimeSecsValue      equ "15:28:59"
BuildTimeSecsWidth      equ 0 + FW1 + FW5 + FWColon + FW2 + FW8 + FWColon + FW5 + FW9
