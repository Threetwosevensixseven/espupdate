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
DoSync:
                        PrintMsg(Msg.SendSync)
                        call ESPFlush                   ; Clear the UART buffer first
                        ld b, 1                         ; Send ESP Sync command up to seven times
SyncLoop:               push bc
                        ESPSendBytes(SLIP.Sync, SLIP.SyncLen) ; Send the command
                        //call ESPFlush                   ; Clear any response from the UART buffer
                        pop bc
                        djnz SyncLoop
                        PrintMsg(Msg.RcvSync)
                        call ESPRead

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

