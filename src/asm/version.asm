; version.asm
;
; Auto-generated by ZXVersion.exe
; On 10 Jul 2023 at 19:52

BuildNo                 macro()
                        db "82"
mend

BuildNoValue            equ "82"
BuildNoWidth            equ 0 + FW8 + FW2



BuildDate               macro()
                        db "10 Jul 2023"
mend

BuildDateValue          equ "10 Jul 2023"
BuildDateWidth          equ 0 + FW1 + FW0 + FWSpace + FWJ + FWu + FWl + FWSpace + FW2 + FW0 + FW2 + FW3



BuildTime               macro()
                        db "19:52"
mend

BuildTimeValue          equ "19:52"
BuildTimeWidth          equ 0 + FW1 + FW9 + FWColon + FW5 + FW2



BuildTimeSecs           macro()
                        db "19:52:06"
mend

BuildTimeSecsValue      equ "19:52:06"
BuildTimeSecsWidth      equ 0 + FW1 + FW9 + FWColon + FW5 + FW2 + FWColon + FW0 + FW6
