; version.asm
;
; Auto-generated by ZXVersion.exe
; On 09 Jan 2020 at 22:29

BuildNo                 macro()
                        db "3"
mend

BuildNoValue            equ "3"
BuildNoWidth            equ 0 + FW3



BuildDate               macro()
                        db "09 Jan 2020"
mend

BuildDateValue          equ "09 Jan 2020"
BuildDateWidth          equ 0 + FW0 + FW9 + FWSpace + FWJ + FWa + FWn + FWSpace + FW2 + FW0 + FW2 + FW0



BuildTime               macro()
                        db "22:29"
mend

BuildTimeValue          equ "22:29"
BuildTimeWidth          equ 0 + FW2 + FW2 + FWColon + FW2 + FW9



BuildTimeSecs           macro()
                        db "22:29:58"
mend

BuildTimeSecsValue      equ "22:29:58"
BuildTimeSecsWidth      equ 0 + FW2 + FW2 + FWColon + FW2 + FW9 + FWColon + FW5 + FW8
