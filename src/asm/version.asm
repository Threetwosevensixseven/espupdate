; version.asm
;
; Auto-generated by ZXVersion.exe
; On 10 Jan 2020 at 22:35

BuildNo                 macro()
                        db "6"
mend

BuildNoValue            equ "6"
BuildNoWidth            equ 0 + FW6



BuildDate               macro()
                        db "10 Jan 2020"
mend

BuildDateValue          equ "10 Jan 2020"
BuildDateWidth          equ 0 + FW1 + FW0 + FWSpace + FWJ + FWa + FWn + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "22:35"
mend

BuildTimeValue          equ "22:35"
BuildTimeWidth          equ 0 + FW2 + FW2 + FWColon + FW3 + FW5



BuildTimeSecs           macro()
                        db "22:35:54"
mend

BuildTimeSecsValue      equ "22:35:54"
BuildTimeSecsWidth      equ 0 + FW2 + FW2 + FWColon + FW3 + FW5 + FWColon + FW5 + FW4
