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

                        ; This dot command is way larger than 8KB, so we have a strategy for dealing with that.
                        ; NextZXOS will automatically load the first 8KB, which contains all the core code,
                        ; and will leave the file handle open. If the core code is less than 8KB, Zeus will
                        ; pad it to 8KB automatically.
                        ; Use of the NextZXOS API means this dot cmd cannot run under esxDOS, so we must do
                        ; an initial check for NextZXOS, and exit gracefully if not present.
                        ; We call M_GETHANDLE to get and save the handle.
                        call esxDOS.GetHandle

                        ; The next <=16KB in the file contains the ESP uploader stubs, additional code and buffers.
                        ; This is assembled so that it runs at $8000-BFFF. We will use IDE_BANK to allocate two 8KB
                        ; banks, which must be freed before exiting the dot command.
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (BankUpper1), a              ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (BankUpper2), a              ; Save bank number

                        ; Now we can page in the the two 8K banks at $8000 and $A000, and try to load the
                        ; remainder of the dot command code. This paging will need to be undone during cmd exit.
                        nextreg $55, a                  ; Allocated bank for $A000 was already in A, page it in.
                        ld a, (BankUpper1)
                        nextreg $54, a                  ; Page in allocated bank for $8000
                        ld hl, $8000                    ; Start loading at $8000
                        ld bc, $4000                    ; Load up to 16KB of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.BadDot)

                        //ld l, 0                       ; 0 - from start of file
                        //ld bc, 0                      ; BCDE = bytes to seek
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
                        PrintMsg(Msg.ESPProg1)          ; "Setting ESP programming mode..."

                        //PrintMsg(Msg.ESPProg3)        ; "Setting RST low"
                        nextreg 2, 128                  ; Set RST low
                        call Wait5Frames

                        //PrintMsg(Msg.ESPProg2)        ; "Enabling GPIO0 output"
                        NextRegRead(168)
                        or %1                           ; Set bit 0
                        nextreg 168, a                  ; to enable GPIO0
                        push af

                        //PrintMsg(Msg.ESPProg4)        ; "Setting GPIO0 low"
                        NextRegRead(169)
                        and %1111 1110                  ; Clear bit 0
                        push af
                        nextreg 169, a                  ; to set GPIO0 low
                        call Wait5Frames

                        //PrintMsg(Msg.ESPProg5)        ; "Setting RST high"
                        nextreg 2, 0                    ; Set RST high
                        call Wait5Frames

                        //PrintMsg(Msg.ESPProg6)        ; "Setting GPIO0 high"
                        pop af
                        or %1                           ; Set bit 0
                        nextreg 169, a                  ; to set GPIO0 high
                        call Wait5Frames

                        //PrintMsg(Msg.ESPProg7)        ; "Disabling GPIO0 output"
                        pop af
                        and %1111 1110                  ; Clear bit 0
                        nextreg 168, a                  ; to enable GPIO0
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
                        //PrintMsg(Msg.Fuse1)           ; "Reading eFuses..."
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
                        ; Full 128b value of all four eFuses = 0x00600194 1700B000 020021E8 5A240000 (on test ESP)
CheckChip:
                        //PrintBufferHex(eFuses, 16)
                        ; is_8285 = (efuses & ((1 << 4) | 1 << 80)) != 0
                        ; Bit 5   = eFuse4 byte 4 (%0001 0000)
                        ; Bit 81  = eFuse2 byte 2 (%0000 0001)
                        ; Note the words are stored most significant,
                        ; and the bytes are also stored most significant.
                        ; If either of these bits are set, chip is ESP8285, otherwise ESP8266EX.
                        ld a, (eFuse4+3)
                        and %0001 0000
                        jr nz, Is8285_
                        ld a, (eFuse2+1)
                        and %0000 0001
                        jr nz, Is8285_
                        PrintMsg(Msg.ESP8266EX)
                        xor a
                        jr EndCheckChip
Is8285_:                PrintMsg(Msg.ESP8285)
                        ld a, 1
EndCheckChip:           ld (Features.Is8285), a

CheckFeatures:
                        PrintMsg(Msg.FWiFi)             ; Every ESP has WiFi
                        ld a, (Features.Is8285)
                        or a
                        jr z, NoEmbFlash
                        PrintMsg(Msg.FFLash)            ; 8285s have embedded flash
                        ld a, 1
                        jr EndFeatures
NoEmbFlash:             xor a
EndFeatures:            ld (Features.EmbFlash), a

ReadMAC:
                        //PrintMsg(Msg.MAC1)            ; "Reading MAC..."
                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(ESP_OTP_MAC0)        ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, MAC0)          ; val = 0x5A240000 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(ESP_OTP_MAC1)        ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, MAC1)          ; val = 0x020021E8 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(ESP_OTP_MAC3)        ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ValidateCmd($0A, MAC3)          ; val = 0x00600194 (on test ESP)
                        //PrintBufferHex(MAC0, 12)

CalculateMAC:
                        ; There are three alternative MAC scenarios. If not of them match, it is a fatal error.
                        ; Scenario 1: mac3 != 0
                        ; Scenario 2: ((mac1 >> 16) & 0xff) == 0
                        ; Scenario 3: ((mac1 >> 16) & 0xff) == 1
                        ; For each scenario, there is an interim calculation
                        ; The interim calculation is then used in the final calculation
                        ; Scenario 1: mac3 != 0
                        ld hl, (MAC3)
                        xor a
                        or h
                        or l
                        ld hl, (MAC3+2)
                        or h
                        or l
                        jp z, MACScenario2
                        ; Scenario 1 matches. The interim calculation is:
                        ; oui = ((mac3 >> 16) & 0xff, (mac3 >> 8) & 0xff, mac3 & 0xff)
                        ; val = tuple (0x60, 0x01, 0x94) on test ESP
                        ld hl, (MAC3+1)
                        ld (OUI1), hl
                        ld a, (MAC3+3)
                        ld (OUI3), a
                        jr MacFinalCalc
MACScenario2:           ld a, (MAC1+1)
                        or a
                        jr z, MACIsScenario2
                        cp 1
                        jr z, MACScenario3
                        ErrorAlways(Err.UnknownOUI)
MACIsScenario2:
                        ; Scenario 2 matches. The interim calculation is:
                        ; oui = tuple (0x18, 0xF3, 0x34) hardcoded
                        ld hl, $F318
                        ld (OUI1), hl
                        ld a, $34
                        ld (OUI3), a
                        jr MacFinalCalc
MACScenario3:
                        ; Scenario 3 matches. The interim calculation is:
                        ; oui = tuple (0xAC, 0xD0, 0x74) hardcoded
                        ld hl, $D0AC
                        ld (OUI1), hl
                        ld a, $74
                        ld (OUI3), a
                        ; Fall into final calculation
MacFinalCalc:
                        ; MAC final calculation is:
                        ; MAC = oui + ((mac1 >> 8) & 0xff, mac1 & 0xff, (mac0 >> 24) & 0xff)
                        ; The first three bytes are the precalculated OUI
                        ; The second three bytes are defived from mac1 and mac0
                        ; MAC = tuple (0x18, 0xF3, 0x34, 0x21, 0xE8, 0x5A) on test ESP
                        ; formatted MAC is 60:01:94:21:E8:5A on test ESP
                        ld hl, (MAC1+2)
                        ld (OUI4), hl
                        ld a, (MAC0)
                        ld (OUI6), a
PrintMAC:
                        PrintMsg(Msg.MAC2)
                        ld a, (OUI1)
                        call PrintAHexNoSpace
                        ld a, ':'
                        rst 16
                        ld a, (OUI2)
                        call PrintAHexNoSpace
                        ld a, ':'
                        rst 16
                        ld a, (OUI3)
                        call PrintAHexNoSpace
                        ld a, ':'
                        rst 16
                        ld a, (OUI4)
                        call PrintAHexNoSpace
                        ld a, ':'
                        rst 16
                        ld a, (OUI5)
                        call PrintAHexNoSpace
                        ld a, ':'
                        rst 16
                        ld a, (OUI6)
                        call PrintAHexNoSpace
                        ld a, 13
                        rst 16
UploadStub:
                        PrintMsg(Msg.Stub1)
                        ; These are the value for uploading the stub:
                        ;
                        ; text_start  = 0x4010E000
                        ; text_length = 0x1F60
                        ; text_blocks = 2
                        ; text_block_0_from_offs = 0x0000
                        ; text_block_0_to_offs   = 0x1800
                        ; text_block_1_from_offs = 0x1800
                        ; text_block_1_to_offs   = 0x3000
                        ;
                        ; data_start  = 0x3FFFABA4
                        ; data_length = 0x0300
                        ; data_blocks = 1
                        ; data_block_0_from_offs = 0x0000
                        ; data_block_0_to_offs   = 0x1800

                        zeusprinthex "Buffer: ", Buffer
                        zeusprinthex "eFuses: ", eFuses
                        zeusprinthex "MAC: ", MAC
                        Freeze(1,2)

                        include "constants.asm"         ; Global constants
                        include "macros.asm"            ; Zeus macros
                        include "general.asm"           ; General routines
                        include "esp.asm"               ; ESP and SLIP routines
                        include "esxDOS.asm"            ; ESXDOS routines
                        include "msg.asm"               ; Messaging and error routines
                        include "vars.asm"              ; Global variables
                                                        ; Everything after this is padded to the next 8K
                                                        ; but assembles at $8000
                        include "stub.asm"              ; ESP upload stub

UpperCodeLen equ $-UpperCodeStart
Length       equ $-Start
zeusprinthex "Lower code: ", LowerCodeStart, LowerCodeLen
zeusprinthex "Upper code: ", UpperCodeStart, UpperCodeLen
zeusprinthex "Cmd size:   ", Length

if zeusver >= 74
  zeuserror "Does not run on Zeus v4.00 (TEST ONLY) or above, Get v3.991 available at http://www.desdes.com/products/oldfiles/zeus.exe"
endif

if (LowerCodeLen > $2000)
  zeuserror "DOT command (lower code) is too large to assemble!"
endif
if (UpperCodeLen > $4000)
  zeuserror "DOT command (upper code) is too large to assemble!"
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

