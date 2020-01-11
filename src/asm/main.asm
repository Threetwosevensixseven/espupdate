; main.asm
                                                        ; Assembles with regular version of Zeus (not Next version),
zeusemulate             "48K", "RAW", "NOROM"           ; because that makes it easier to assemble dot commands
zoSupportStringEscapes  = true;                         ; Download Zeus.exe from http://www.desdes.com/products/oldfiles/
optionsize 5
CSpect optionbool 15, -15, "CSpect", false              ; Option in Zeus GUI to launch CSpect
RealESP optionbool 80, -15, "Real ESP", true            ; Launch CSpect with physical ESP in USB adaptor
UploadNext optionbool 160, -15, "Next", false           ; Copy dot command to Next FlashAir card
ErrDebug optionbool 212, -15, "Debug", false            ; Print errors onscreen and halt instead of returning to BASIC

org $2000                                               ; Dot commands always start at $2000.
Start:
                        PrintMsg(Msg.Startup)

                        call esxDOS.GetHandle

                        //ld l, 0                         ; 0 - from start of file
                        //ld bc, 0                        ; BCDE = bytes to seek
                        //ld de, 0
                        //call esxDOS.fSeek

                        //CSBreak()

                        //ld hl, $C000
                        //ld bc, $2000
                        //call esxDOS.fRead

                        //call ESPSendTestBytes
                        //Freeze(1,4)

                        //CSBreak()


EnableProgMode:
                        PrintMsg(Msg.ESPProg1)           ; "Setting ESP programming mode..."

                        //PrintMsg(Msg.ESPProg3)           ; "Setting RST low"
                        nextreg 2, 128                   ; Set RST low
                        WaitFrames(ResetWait)

                        //PrintMsg(Msg.ESPProg2)           ; "Enabling GPIO0 output"
                        NextRegRead(168)
                        or %1                            ; Set bit 0
                        nextreg 168, a                   ; to enable GPIO0
                        push af

                        //PrintMsg(Msg.ESPProg4)           ; "Setting GPIO0 low"
                        NextRegRead(169)
                        and %1111 1110                   ; Clear bit 0
                        push af
                        nextreg 169, a                   ; to set GPIO0 low
                        WaitFrames(ResetWait)

                        //PrintMsg(Msg.ESPProg5)           ; "Setting RST high"
                        nextreg 2, 0                     ; Set RST high
                        WaitFrames(ResetWait)

                        //PrintMsg(Msg.ESPProg6)           ; "Setting GPIO0 high"
                        pop af
                        or %1                            ; Set bit 0
                        nextreg 169, a                   ; to set GPIO0 high
                        WaitFrames(ResetWait)

                        //PrintMsg(Msg.ESPProg7)           ; "Disabling GPIO0 output"
                        pop af
                        and %1111 1110                   ; Clear bit 0
                        nextreg 168, a                   ; to enable GPIO0
                        push af
DoSync:
                        PrintMsg(Msg.SendSync)
                        call ESPFlush                   ; Clear the UART buffer first
                        ld b, 2                         ; Send ESP Sync command up to seven times
SyncLoop:               push bc
                        ESPSendBytes(SLIP.Sync, SLIP.SyncLen) ; Send the command
                        pop bc
                        djnz SyncLoop
                        //PrintMsg(Msg.RcvSync)
                        call ESPReadIntoBuffer
                        ValidateCmd($08, Dummy32)       ; Check whether this we got a sync response
                        ErrorIfCarry(Err.NoSync)
                        PrintMsg(Msg.SyncOK)

ReadEfuses:
                        PrintMsg(Msg.Fuse1)
                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff0005c)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, eFuse1)        ; val = 0x00600194 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00058)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, eFuse2)        ; val = 0x1700B000 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00054)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, eFuse3)        ; val = 0x020021E8 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00050)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, eFuse4)        ; val = 0x5A240000 (on test ESP)

                        PrintBufferHex(eFuses, 16)

                        // Full 128b value of all four eFuses = 0x00600194 1700B000 020021E8 5A240000 (on test ESP)

                        zeusprinthex "Buffer: ",Buffer
                        zeusprinthex "eFuses: ", eFuses
                        Freeze(1,2)

                        include "constants.asm"         ; Global constants
                        include "macros.asm"            ; Zeus macros
                        include "esp.asm"               ; ESP and SLIP routines
                        include "esxDOS.asm"            ; ESXDOS routines
                        include "msg.asm"               ; Messaging and error routines
                        include "vars.asm"              ; Global variables

Length equ $-Start
zeusprinthex "Command size: ", Length

if zeusver >= 74
  zeuserror "Does not run on Zeus v4.00 (TEST ONLY) or above, Get v3.991 available at http://www.desdes.com/products/oldfiles/zeus.exe"
endif

if (Length > $2000)
  zeuserror "DOT command is too large to assemble!"
endif

output_bin "..\\..\\dot\\ESPUPDATE", Start, Length

if enabled UploadNext
  output_bin "R:\\dot\\ESPUPDATE", Start, Length
endif

if enabled CSpect
  if enabled RealESP
    zeusinvoke "..\\..\\build\\cspect.bat"
  else
    zeusinvoke "..\\..\\build\\cspect-emulate-esp.bat"
  endif
else
  zeusinvoke "..\\..\\build\\builddot.bat"
endif

