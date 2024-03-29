; main.asm

;  Copyright 2020-2023 Robin Verhagen-Guest
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
                                                        ; Assembles with regular version of Zeus (not Next version),
zeusemulate             "Next", "RAW", "NOROM"          ; because that makes it easier to assemble dot commandszxnextmap -1,DotCommand8KBank,-1,-1,-1,-1,-1,-1         ; Assemble into Next RAM bank but displace back down to $2000
zxnextmap -1,DotBank1,-1,-1,DotBank2,DotBank3,-1,-1     ; Assemble into Next RAM bank but displace back down to $2000
zoSupportStringEscapes  = true;                         ; Download zeustest.exe from http://www.desdes.com/products/oldfiles/
optionsize 10
CSpect optionbool 15, -10, "CSpect", false              ; Option in Zeus GUI to launch CSpect
RealESP optionbool 80, -10, "Real ESP", false           ; Launch CSpect with physical ESP in USB adaptor
UploadNext optionbool 160, -10, "Next", false           ; Copy dot command to Next FlashAir card
ErrDebug optionbool 212, -10, "Debug", false            ; Print errors onscreen and halt instead of returning to BASIC
Dump16KOnly optionbool 270, -10, "16K Dump", false      ; Ignore detected sizes and only dump 16K of the FLASH
//AppendFW optionbool 270, -10, "AppendFW", false       ; Pad dot command and append the NXESP-formatted firmware

org $2000                                               ; Dot commands always start at $2000
Start:
                        jr Begin
                        db "ESPUPDATEv1."               ; Put a signature and version in the file in case we ever
                        BuildNo()                       ; need to detect it programmatically
                        db 0
Begin:                  di                              ; We run with interrupts off apart from printing and halts
                        ld (Return.Stack1), sp          ; Save so we can always return without needing to balance stack
                        ld (Return.IY1), iy             ; Put IY safe, just in case
                        ld sp, $4000                    ; Put stack safe inside dot command

                        ld (SavedArgs), hl              ; Save args for later

                        call InstallErrorHandler        ; Handle scroll errors during printing and API calls
                        PrintMsg(Msg.Startup)           ; "ESP Update Tool v1.x"

                        ld a, %0000 0001                ; Test for Next courtesy of Simon N Goodwin, thanks :)
                        MirrorA()                       ; Z80N-only opcode. If standard Z80 or successors, this will
                        nop                             ; be executed as benign opcodes that don't affect the A register.
                        nop
                        cp %1000 0000                   ; Test that the bits of A were mirrored as expected
                        ld hl, Err.NotNext              ; If not a Spectrum Next,
                        jp nz, Return.WithCustomError   ; exit with an error.
                        ld a, 1
                        ld (IsNext), a

                        NextRegRead(Reg.MachineID)      ; If we passed that test we are safe to read machine ID.
                        and %0000 1111                  ; Only look at bottom four bits, to allow for Next clones
                        cp 10                           ; 10 = ZX Spectrum Next
                        jp z, IsANext                   ;  8 = Emulator
                        cp 8                            ; Exit with error if not a Next. HL still points to err message,
                        jp nz, Return.WithCustomError   ; be careful if adding code between the Next check and here!
IsANext:
                        NextRegRead($54)                ; Backup existing banks in all four slots,
                        ld (DeallocateBanks.R54), a     ; and do it right now in case we take an early exit.
                        NextRegRead($55)                ; We can't do this backup before the IsANext check,
                        ld (DeallocateBanks.R55), a     ; because reading these I/O ports will have a bad effect
                        NextRegRead($56)                ; on a non-Next.
                        ld (DeallocateBanks.R56), a     ; We might still have exited before this point,
                        NextRegRead($57)                ; but only on a classic Spectrum, where the default values
                        ld (DeallocateBanks.R57), a     ; of these four banks will be guaranteed to be 4/5/0/1.

                        Rst8(esxDOS.M_DOSVERSION)       ; Check if we are running in NextZXOS
                        ld hl, Err.NotOS                ; If esxDOS (carry set),
                        jp c, Return.WithCustomError    ; exit with an error.
                        or a                            ; If not full NextZXOS (a != 0),
                        ld hl, Err.NotNB                ; exit with an error.
                        jp nz, Return.WithCustomError   ; We could also do NextZXOS version check if we cared.

                        NextRegRead(Reg.Peripheral2)    ; Read Peripheral 2 register.
                        ld (RestoreF8.Saved), a         ; Save current value so it can be restored on exit.
                        and %0111 1111                  ; Clear the F8 enable bit,
                        nextreg Reg.Peripheral2, a      ; And write the entire value back to the register.

                        NextRegRead(Reg.CPUSpeed)       ; Read CPU speed.
                        and %11                         ; Mask out everything but the current desired speed.
                        ld (RestoreSpeed.Saved), a      ; Save current speed so it can be restored on exit.
                        nextreg Reg.CPUSpeed, %11       ; Set current desired speed to 28MHz.

                        NextRegRead(Reg.CoreMSB)        ; Core Major/Minor version
                        ld h, a
                        NextRegRead(Reg.CoreLSB)        ; Core Sub version
                        ld l, a                         ; HL = version, should be >= $3007
                        ld de, CoreMinVersion
                        CpHL(de)
                        ErrorIfCarry(Err.CoreMin)       ; Raise minimum core error if < 3.00.07

                        GetSizedArg(SavedArgs, FWFileName) ; Parse filename from first arg
                        jr nc, ArgNotFile                ; No arg, not a file
                        ld hl, 5
                        CpHL(bc)                        ; Filenames >=5 chars are legit
                        jr c, ArgIsFile
                        ld a, (FWFileName)
                        cp '-'                          ; Filenames <5 chars starting with "-" are switches
                        jr nz, ArgIsFile
ArgNotFile:             xor a
                        jr nc, SaveFileArg
ArgIsFile:              ld a, 1
SaveFileArg:            ld (HasFWFileName), a           ; Save whether we have a filename or not

                        ld hl, (SavedArgs)              ; Start again at the first arg in case it was help
ArgLoop:                ld de, ArgBuffer                ; Parse remaining args in a loop
                        call GetSizedArgProc
                        jr nc, NoMoreArgs
                        call ParseHelp
                        call ParseForce
                        call ParseWaitKeyRet
                        call ParseFlashSize
                        call ParseDump
                        jr ArgLoop
NoMoreArgs:
                        ld a, (WantsHelp)
                        or a
                        jr z, NoHelp
DoHelp:                 call DisablePrintScroll         ; When printing help, honour original scroll
                        PrintMsg(Msg.Help)              ; Print help
                        if (ErrDebug)
                          Freeze(1,2)
                        else
                          jp Return.ToBasic
                        endif
NoHelp:
                        xor a                           ; A=0, query current mode information
                        ld c, 7                         ; 16K Bank 7 required for most NextZXOS API calls
                        ld de, IDE_MODE                 ; M_P3DOS takes care of stack safety stack for us
                        Rst8(esxDOS.M_P3DOS)            ; Make NextZXOS API call through esxDOS API with M_P3DOS
                        ErrorIfNoCarry(Err.NotOS)       ; Fatal error, exits dot command
                        and %000000 11                  ; A bits 1..0 are LAYER
                        jr z, EndLayerDetection         ; If LAYER 0, buffer will already contain 32 backspaces
                        ld hl, UpBuffer
                        ld (hl), 11                     ; Otherwise CHR$ 11 is up, in all other layers
                        inc hl
                        ld (hl), 0                      ; Null-terminate buffer
                        PrintMsgAlt(Msg.NoScroll)       ; Print CHR$ 26;CHR$ 0; to disable scroll when not LAYER 0
EndLayerDetection:

                        ; This dot command is way larger than 8KB, so we have a strategy for dealing with that.
                        ; NextZXOS will automatically load the first 8KB, which contains all the core code,
                        ; and will leave the file handle open. If the core code is less than 8KB, Zeus will
                        ; pad it to 8KB automatically.
                        ; Use of the NextZXOS API means this dot cmd cannot run under esxDOS, so we must do
                        ; an initial check for NextZXOS, and exit gracefully if not present.
                        ; We call M_GETHANDLE to get and save the handle.
                        call esxDOS.GetHandle

                        ; The next <=16KB in the file contains the ESP uploader stubs, additional code and buffers.
                        ; This is assembled so that it runs at $8000-BFFF. We will use IDE_BANK to allocate four 8KB
                        ; banks, which must be freed before exiting the dot command.
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Bank1), a   ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Bank2), a   ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Bank3), a   ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Bank4), a   ; Save bank number

                        ; Now we can page in the four 8K banks at $8000, $A000, $C000 and $E000, and try to load the
                        ; remainder of the dot command code. This paging will need to be undone during cmd exit.

                        ld a, (DeallocateBanks.Bank1)
                        nextreg $54, a                  ; Page in allocated bank for $8000
                        ld a, (DeallocateBanks.Bank2)
                        nextreg $55, a                  ; Page in allocated bank for $A000
                        ld a, (DeallocateBanks.Bank3)
                        nextreg $56, a                  ; Page in allocated bank for $C000
                        ld a, (DeallocateBanks.Bank4)
                        nextreg $57, a                  ; Page in allocated bank for $E000

                        ld hl, $8000                    ; Start loading at $8000
                        ld bc, $4000                    ; Load up to 16KB of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.BadDot)
FlashOrDump:
                        ld a, (DumpFW)
                        cp 1                            ; If we are dumping FW, skip section
                        jp z, SetUARTStdSpeed           ; where we validate filename and read FW
CheckFW:
                        PrintMsg(Msg.ReadFW)
                        ld a, (HasFWFileName)           ; Do we have a filename from the first arg?
                        or a
                        jr z, ReadFW                    ; We don't have a filename, so try to read the appended FW
                        call esxDOS.fClose              ; Close the dot command, but don't bother handling any errors
                        ld hl, FWFileName
                        call esxDOS.fOpen               ; Open the external firmware file from its filename
                        ErrorIfCarry(Err.ReadFW)        ; Throw an error if esxDOS returned one
ReadFW:                 ld hl, $C000                    ; Start loading at $C000
                        ld bc, $0007                    ; Load 7 bytes of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.ReadFW)
                        ld a, b                         ; If we read zero bytes, either FW wasn't appended to
                        or c                            ; the dot cmd, or the external FW file was zero length.
                        jp nz, FWFound

                        //if enabled AppendFW
                        //  ErrorAlways(Err.FWMissing)
                        // else
                          PrintMsg(Msg.ExternalFW)
                          ErrorAlways(Err.FWMissing)
                        //endif

FWFound:                cp 7                            ; Check we read 7 bytes
                        jp nz, BadFormat
                        ld hl, $C000                    ; Check magic bytes NXESP
                        ld a, (hl)
                        cp 'N'
                        jp nz, BadFormat
                        inc hl
                        ld a, (hl)
                        cp 'X'
                        jr nz, BadFormat
                        inc hl
                        ld a, (hl)
                        cp 'E'
                        jr nz, BadFormat
                        inc hl
                        ld a, (hl)
                        cp 'S'
                        jr nz, BadFormat
                        inc hl
                        ld a, (hl)
                        cp 'P'
                        jr z, ReadMoreHeader
BadFormat:              ErrorAlways(Err.BadFW)
ReadMoreHeader:         inc hl
                        ld c, (hl)                      ; Read remaining header size
                        inc hl
                        ld b, (hl)
                        ld hl, Header.Len
                        CpHL(bc)                        ; Check it isn't bigger than Header buffer
                        jr c, BadFormat
                        ld hl, Header.Buffer            ; Read remaining header into Header buffer
                        push hl
                        call esxDOS.fRead
                        ErrorIfCarry(Err.BadDot)
                        pop hl
                        ld a, (hl)                      ; Read Version Length
                        cp 11                           ; Can't be more than 10 chars
                        jr nc, BadFormat
                        ld c, a                         ; Save version
                        ld b, 0
                        ld de, FWVersion
                        inc hl
                        ldir
                        xor a
                        ld (de), a                      ; Add null terminator
                        ld a, (hl)                      ; Save flash params
                        ld (FlashParams), a
                        inc hl
                        ld a, (hl)
                        ld (FlashParams+1), a
                        inc hl
                        ld a, (hl)                      ; Read MD5 length
                        cp 16                           ; Must be 16 (binary, not hex string)
                        jr nz, BadFormat
                        inc hl
                        ld de, FWMD5
                        ld bc, 16
                        ldir                            ; Write MD5
                        ld e, (hl)                      ; Read DataBlockSize
                        inc hl
                        ld d, (hl)
                        ld (DataBlockSize), de          ; Write DataBlockSize
                        ld (SLIP.FlashBlock+8), de      ; (also write into lower word of SLIP flash header)
                        ld (SLIP.FinalizeBlock+8), de   ; (also write into lower word of SLIP finalize header)
                        inc hl
                        ld e, (hl)                      ; Read FWCompLen
                        inc hl
                        ld d, (hl)
                        inc hl
                        ld c, (hl)
                        inc hl
                        ld b, (hl)
                        ld (FWCompLen), de
                        ld (FWCompLen+2), bc            ; Write FWCompLen
                        inc hl
                        ld a, (hl)                      ; Read HeaderBlockSize
                        ld (HeaderBlockSize), a         ; Write HeaderBlockSize
                        inc hl
                        ld e, (hl)                      ; Read BlockCount
                        inc hl
                        ld d, (hl)
                        ld (BlockCount), de             ; Write BlockCount
                        ld (SLIP.FlashBlock+4), de      ; (also write into lower word of SLIP header)
                        inc hl
                        ld c, (hl)                      ; Read FWCompLenStr size
                        ld b, 0
                        inc hl
                        ld de, FWCompLenStr
                        ldir                            ; Write FWCompLenStr
                        xor a                           ; with terminating null
                        ld (de), a
                        ld (BlockHeaderStart), hl       ; Write BlockHeaderStart
FWReadFinished:         PrintMsg(Msg.FWVer)
                        PrintMsg(FWVersion)
                        PrintMsg(Msg.EOL)

                        ld a, (Force)
                        or a
                        jr nz, SetUARTStdSpeed
                        PrintMsg(Msg.Confirm)
                        call WaitKeyYN
                        jr nc, SetUARTStdSpeed
                        PrintMsg(Msg.Abort)
                        jp EndOfCommand
SetUARTStdSpeed:
                        SetUARTBaud(Baud.b115200, Msg.b115200)
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
                        nextreg 168, a                  ; to disable GPIO0
                        ld a, 1
                        ld (InProgMode), a              ; Signal that ESP should be reset on exit
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
                        ESPValidateCmd($08, Dummy32)    ; Check whether this we got a sync response

SyncPass equ $+1:       jp c, NotSynced1                ; If we didn't sync the first time,
                        jr Synced
NotSynced1:             ld hl,NotSynced2
                        ld (SyncPass), hl
                        PrintMsg(Msg.RetryESP)          ; Reset and try a second time.
                        nextreg 2, 128                  ; Set RST low
                        call Wait80Frames               ; Hold in reset a really long time
                        nextreg 2, 0                    ; Set RST high
                        call Wait80Frames               ; Wait a really, really long time
                        call Wait80Frames
                        jp EnableProgMode
NotSynced2:             ErrorAlways(Err.NoSync)         ; Error on second failure
Synced:

ReadEfuses:
                        //PrintMsg(Msg.Fuse1)           ; "Reading eFuses..."
                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        //SetReadTimeout(500)
                        //call WaitKey
                        ESPReadReg(0x3ff0005c)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        //call WaitKey
                        ESPValidateCmd($0A, eFuse1)     ; val = 0x00600194 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00058)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ESPValidateCmd($0A, eFuse2)     ; val = 0x1700B000 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00054)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ESPValidateCmd($0A, eFuse3)     ; val = 0x020021E8 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff00050)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ESPValidateCmd($0A, eFuse4)     ; val = 0x5A240000 (on test ESP)
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
                        ESPValidateCmd($0A, MAC0)       ; val = 0x5A240000 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(ESP_OTP_MAC1)        ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ESPValidateCmd($0A, MAC1)       ; val = 0x020021E8 (on test ESP)

                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(ESP_OTP_MAC3)        ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
                        ESPValidateCmd($0A, MAC3)       ; val = 0x00600194 (on test ESP)
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
                        call Rst16
                        ld a, (OUI2)
                        call PrintAHexNoSpace
                        ld a, ':'
                        call Rst16
                        ld a, (OUI3)
                        call PrintAHexNoSpace
                        ld a, ':'
                        call Rst16
                        ld a, (OUI4)
                        call PrintAHexNoSpace
                        ld a, ':'
                        call Rst16
                        ld a, (OUI5)
                        call PrintAHexNoSpace
                        ld a, ':'
                        call Rst16
                        ld a, (OUI6)
                        call PrintAHexNoSpace
                        ld a, CR
                        call Rst16
DetectIssue:
                        PrintMsg(Msg.Issue)             ; "Using flash size: "
                        NextRegRead(Reg.BoardID)        ; Read BoardID
                        and 15                          ; 0 = Issue 2, 1 = Issue 3, 2 = Issue 4, 3..15 = Unknown
                        //ld a, 3                       ; TESTING ONLY!
                        cp 3
                        jr c, GetIssue
                        ld a, 3
GetIssue:               swapnib
                        rlca                            ; a = record# in Issue table (BoardID * 32)
                        ld hl, Issue.Table
                        ld c, a
                        ld b, 0
                        add hl, bc                      ; hl = Issue record address
                        push hl
                        call PrintRst16
                        PrintMsg(Msg.FlashSize1)        ; "MB\r"
                        pop hl                          ; Read passed-in flash size arg
                        ld a, (FlashSizeChar)
                        or a                            ; If nothing was passed in arg,
                        jp z, DefaultSize               ; use 1 for issue 2, and 4 for everything else.
                        ld hl, FlashSizeChar            ; Otherwise use passed in arg,
                        jr  PrintSize                   ; and print the corresponding size.
DefaultSize:            add hl, 9                       ; (hl) = flash size (Num) in MB
                        ld a, (hl)
                        ld (FlashSizeNum), a
                        inc hl                          ; (hl) = flash size (ASCII) in MB
                        ld a, (hl)
                        ld (FlashSizeChar), a
                        if (not enabled Dump16KOnly)
                          push hl
                          CSBreak()
                          inc hl
                          inc hl
                          ld e, (hl)
                          inc hl
                          ld d, (hl)                    ; DE = block count
                          ld (DumpPacketCount), de      ; Patch block count into the dump loop
                          inc hl
                          ld e, (hl)
                          inc hl
                          ld d, (hl)                    ; DE = dump size (middle 2 bytes of 32bit word!)
                          ld (SLIP.DumpSize), de        ; Patch dump size into the SLIP packet definition
                          inc hl
                          ld e, (hl)
                          inc hl
                          ld d, (hl)                    ; (DE) = block count in ASCII, null-terminated
                          ld (PrintDumpProgress.BlockTot), de ; Patch block count into the progress print
                          inc hl
                          ld e, (hl)
                          inc hl
                          ld d, (hl)                    ; DE = percentage increment in 8.8 fixed point format
                          ld (PrintDumpProgress.PercentInc), de ; Patch percentage increment into the progress print
                          pop hl
                        endif
PrintSize:              call PrintRst16                 ; Assume any unknown Board IDs have 4MB flash size
                        PrintMsg(Msg.FlashSize2)

UploadStub:
                        PrintMsg(Msg.Stub1)
                        //SetReadTimeout(50)
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

                        ; A1: mem_begin(0x1F60, 2, 0x1800, 0x4010E000)
                        ; self.command(op, data, chk, timeout=timeout)
                        ;   op      = 5
                        ;   data    = 16 bytes (see below)
                        ;   chk     = 0
                        ;   timeout = 3
                        ; data consists of:
                        ;   size      = 0x00001F60 (UInt32)
                        ;   blocks    = 0x00000002 (UInt32)
                        ;   blocksize = 0x00001800 (UInt32)
                        ;   offset    = 0x4010E000 (UInt32)
                        ;   Ignore what the PyCharm debugger says - it is showing 14 bytes instead of 16 :(

                        ESPSendCmdWithData(ESP_MEM_BEGIN, SLIP.Stub1, SLIP.Stub1Len, Err.StubUpload)
                        ESPSendDataBlock(ESP_MEM_DATA, ESP8266StubText+0x0000, 0x1800, 0, Err.StubUpload)
                        ESPSendDataBlock(ESP_MEM_DATA, ESP8266StubText+0x1800, 0x0760, 1, Err.StubUpload)
                        ESPSendCmdWithData(ESP_MEM_BEGIN, SLIP.Stub2, SLIP.Stub2Len, Err.StubUpload)
                        ESPSendDataBlock(ESP_MEM_DATA, ESP8266StubData+0x0000, 0x0300, 0, Err.StubUpload)

                        ; Run stub
                        ; mem_finish(stub['entry']) ; 0x4010E004
                        ESPSendCmdWithData(ESP_MEM_END, SLIP.EntryBlock, SLIP.EntryBlockLen, Err.StubUpload)

                        ; Check stub is running
                        ; If so, it returns a string "OHAI" straight after the SLIP response
                        ld hl, Buffer+$0D
                        ld a, (hl)
                        cp 'O'
                        jr nz, FailStub
                        inc hl
                        ld a, (hl)
                        cp 'H'
                        jr nz, FailStub
                        inc hl
                        ld a, (hl)
                        cp 'A'
                        jr nz, FailStub
                        inc hl
                        ld a, (hl)
                        cp 'I'
                        jr nz, FailStub
                        jr OkStub
FailStub:               ErrorAlways(Err.StubRun)
OkStub:                 PrintMsg(Msg.Stub2)

                        if enabled FastUART
                          SetUARTBaud(Baud.b1152000, Msg.b1152000)
                          ; esp.change_baud(1152000)
                          ESPSendCmdWithData(ESP_CHANGE_BAUDRATE, SLIP.ChgBaud, SLIP.ChgBaudLen, Err.BaudChg)
                          ; print("Changed.")
                          ; self._set_port_baudrate(baud)
                          ; time.sleep(0.05)  # get rid of crap sent during baud rate change
                          ; self.flush_input()
                        endif

                        ld a, (DumpFW)                  ; If dumping firmware,
                        or a                            ; then go to the firmware dump routine,
                        jp nz, BeginDump                ; otherwise continue with the firmware flash routine.

                        ; flash_set_parameters(self, 0x00100000) [1MB]
                        ; fl_id = 0
                        ; total_size = 0x00100000
                        ; block_size = 64 * 1024
                        ; sector_size = 4 * 1024
                        ; page_size = 256
                        ; status_mask = 0xffff
                        ; self.command(op, data, chk, timeout=timeout)
                        ; op      = 11 ESP_SPI_SET_PARAMS
                        ; data    = 24 bytes, of which:
                        ;   fl_id       = 0x00000000
                        ;   total_size  = 0x00100000
                        ;   block_size  = 0x00010000
                        ;   sector_size = 0x00001000
                        ;   page_size   = 0x00000100
                        ;   status_mask = 0x0000ffff
                        ; chk     = 0
                        ; timeout = 3
                        ESPSendCmdWithData(ESP_SPI_SET_PARAMS, SLIP.CfgFlash, SLIP.CfgFlashLen, Err.FlashSet)

                        ; operation_func(esp, args)
                        ; write_flash(esp, args)
                        ; image = _update_image_flash_params(esp, address, args, image), where
                        ;   address = 0
                        ;   image   = 1,048,576 bytes
                        ; # unpack the (potential) image header: some stuff to check this is really a fw image
                        ; Look at first four bytes:
                        ; magic           = ESP_IMAGE_MAGIC 0xE9
                        ; dummy           = ??
                        ; flash_mode      = 2
                        ; flash_size_freq = 1
                        ; if magic <> ESP_IMAGE_MAGIC jp AfterModFlashParams

                        ; flash_freq = 1 (26m)
                        ; flash_mode = 2 (dio)
                        ; flash_size = 32 (MB)
                        ; flash_params = struct.pack(b'BB', flash_mode, flash_size + flash_freq) = 0x2102
                        ; flash_mode appears first, flash_size + flash_freq appears second
                        ; replace bytes 2 and 3 (zero-based) of image with these two bytes
                        PrintMsg(Msg.FlashParams)       ; "Flash params set to 0x"
                        ld a, (FlashParams)
                        call PrintAHexNoSpace           ; Print param word in hex
                        ld a, (FlashParams+1)
                        call PrintAHexNoSpace
                        PrintMsg(Msg.EOL)
                        PrintMsg(Msg.Upload1)           ; "Uploading "
                        ld hl, FWCompLenStr
                        call PrintRst16                 ; Print compresed size in decimal
                        PrintMsg(Msg.Upload2)           ; " bytes..."
                        ld a, 1
                        ld (CRbeforeErr), a
                        ld hl, 0
                        ld (BlockSeqNo), hl

                        ; blocks = esp.flash_defl_begin(uncsize, len(image), address)
                        ; blocks = esp.flash_defl_begin(1048576, 457535, 0)
                        ; blocks = esp.flash_defl_begin(0x00100000, 0x0006FB3F, 0)
                        ; num_blocks = (compsize + self.FLASH_WRITE_SIZE - 1) // self.FLASH_WRITE_SIZE = 28
                        ; erase_blocks = (size + self.FLASH_WRITE_SIZE - 1) // self.FLASH_WRITE_SIZE = 64
                        ; write_size = size = 1048576
                        ; struct.pack('<IIII', write_size, num_blocks, self.FLASH_WRITE_SIZE, offset)
                        ; FLASH_WRITE_SIZE = 0x4000 (16K)
                        ; offset = 0
                        ; SLIP.FlashBlock was already prepopulated when we read the firmware header
                        ESPSendCmdWithData(ESP_FLASH_DEFL_BEGIN, SLIP.FlashBlock, SLIP.FlashBlockLen, Err.FlashStart)
FlashLoop:
                        PrintMsg(Msg.Upload3)           ; "Writing at 0x"
                        ld hl, (BlockHeaderStart)
                        ld e, (hl)
                        inc hl
                        ld d, (hl)
                        ld (BlockDataLen), de           ; Compressed block size (DataLen)
                        inc hl
                        ld de, Progress                 ; "00000000 (3%)  " etc
                        push de
                        ld bc, 15
                        ldir
                        pop hl
                        call PrintRst16                 ; Print address and percentage
                        PrintMsg(Msg.UploadLeft)        ; Print left 15 chars

                        ; print('\rWriting at 0x%08x... (%d %%)' % (address + seq * esp.FLASH_WRITE_SIZE,
                        ; 100 * (seq + 1) // blocks), end='')
                        ; block = image[0:esp.FLASH_WRITE_SIZE]
                        ; esp.flash_defl_block(block, seq, timeout=DEFAULT_TIMEOUT * ratio)
                        ; ratio = 2.3 (maybe 7 frames?)
                        ; image = image[esp.FLASH_WRITE_SIZE:]
                        ; seq += 1
                        ; written += len(block)

                        ; esp.flash_defl_block(block, seq, timeout=DEFAULT_TIMEOUT * ratio)
                        ; self.ESP_FLASH_DEFL_DATA, struct.pack('<IIII', len(data), seq, 0, 0) + data,
                        ;   self.checksum(data), timeout=timeout) - line 632

                        ld hl, $C000                    ; Load 16K of compressed firmware data
                        ld bc, $4000                    ; into the buffer at $C000
                        call esxDOS.fRead
                        ErrorIfCarry(Err.ReadFW)
BlockDataLen equ $+1:   ld bc, SMC                      ; bc = compressed block size (DataLen)
BlockSeqNo equ $+1:     ld de, SMC                      ; de = Seq number (Seq)
                        SetReadTimeout(500)
                        ESPSendDataBlockSeq(ESP_FLASH_DEFL_DATA, $C000, Err.FlashUp)
                        RestoreReadTimeout()

                        //call Wait100Frames              ; Pause to allow decompression

                        ld hl, (BlockHeaderStart)
                        ld de, (HeaderBlockSize)
                        add hl, de                      ; Move block header pointer to next block
                        ld (BlockHeaderStart), hl
                        ld hl, (BlockSeqNo)             ; Increase and save block sequence no
                        inc hl
                        ld (BlockSeqNo), hl
                        ld hl, (BlockCount)
                        dec hl                          ; Decrease and save block count
                        ld (BlockCount), hl
                        ld a, h
                        or l
                        jp nz, FlashLoop                ; If more blocks remain, upload again
                        xor a
                        ld (CRbeforeErr), a
                        PrintMsg(Msg.Written1)          ; "Wrote "
                        ld hl, FWCompLenStr
                        call PrintRst16                 ; Print compressed size in decimal
                        PrintMsg(Msg.Written2)          ; " bytes to flash "

                        ; Ask ESP uploader stub to calculate the MD5 hash of the 1MB of data we just uploaded,
                        ; after the stub has decompressed it. It will return it in a SLIP response, after a
                        ; delay. Because we know the size and location, we can increase the timeout and
                        ; skip the validation, then verify the MD5 hash directly from the read buffer.
                        ;
                        ; res = esp.flash_md5sum(address, uncsize)
                        ; res = esp.flash_md5sum(0, 0x00100000)
                        ; self.ESP_SPI_FLASH_MD5, struct.pack('<IIII', addr, size, 0, 0)
                        SetReadTimeout(255)
                        DisableReadValidate()
                        ESPSendCmdWithData(ESP_SPI_FLASH_MD5, SLIP.Md5Block, SLIP.Md5BlockLen, Err.BadMd5)
                        EnableReadValidate()
                        RestoreReadTimeout()

                        ; Compare the 32 returned bytes in the buffer against the precalculated MD5 hash
                        ; we read from the firmware extended header.
                        ld hl, Buffer+9                 ; Received hash start address, in buffer.
                        ld de, GotMD5                   ; A safe place, so we can print later.
                        ld b, 16
MD5Loop:                ld a, (hl)
                        call SlipUnescape               ; Unescape $DB $DC to $C0, unescape $DB $DD to $DB
                        ld (de), a                      ; Copy the unescaped byte to safe place
                        inc hl                          ; Increase source buffer pointer
                        inc de                          ; and destination pointer.
                        djnz MD5Loop                    ; After loop, exactly 16 unescaped bytes were copied
                        ld hl, GotMD5                   ; Received hash start address, in safe place.
                        ld de, FWMD5                    ; Precalculated hash start address, in vars.
                        ld b, 16                        ; Size of hash, MD5 is always 16 bytes (not hex string)
HashVerifyLoop:         ld a, (de)
                        cp (hl)
                        inc hl                          ; 16bit inc doesn't affect flags
                        inc de
                        jr nz, HashNotVerified
                        djnz HashVerifyLoop             ; Repeat for all 16 bytes of MDS hash
                        jr HashVerified
HashNotVerified:        PrintMsg(Msg.HashExp)           ; "Expecting hash:"
                        PrintBufferHex(FWMD5, 16)
                        PrintMsg(Msg.HashGot)           ; "Actual hash:"
                        PrintBufferHex(GotMD5, 16)
                        PrintMsg(Msg.EOL)
                        ErrorAlways(Err.BadMd5)      ; If any byte differs, raise "MD5 hash failure" error.
HashVerified:           PrintMsg(Msg.GoodMd5)           ; "Hash of data verified"

                        ; Send an ESP_FLASH_BEGIN command to begin the final sequence. esptool.py says:
                        ; # skip sending flash_finish to ROM loader here,
                        ; # as it causes the loader to exit and run user code
                        ; esp.flash_begin(0, 0)
                        ; struct.pack('<IIII', erase_size, num_blocks, self.FLASH_WRITE_SIZE, offset)
                        ; erase_size = 0
                        ; num_blocks = 0
                        ; FLASH_WRITE_SIZE = 0x4000 (already set when we read the extended firmware header)
                        ; offset = 0
                        PrintMsg(Msg.Finalize)                  ; "Finalising...", esptool.py prints "Leaving..." here
                        ESPSendCmdWithData(ESP_FLASH_BEGIN, SLIP.FinalizeBlock, SLIP.FinalizeBlockLen, Err.Finalize)

                        ; Send an ESP_FLASH_DEFL_END command to exit the flash write
                        ; esp.flash_defl_finish(False)
                        ; pkt = struct.pack('<I', int(not reboot)) = 0x00000001
                        ; self.check_command("leave compressed flash mode", self.ESP_FLASH_DEFL_END, pkt)
                        ESPSendCmdWithData(ESP_FLASH_DEFL_END, SLIP.ExitBlock, SLIP.ExitBlockLen, Err.ExitWrite)
FinalResetESP:
                        PrintMsg(Msg.ResetESP)          ; "Resetting ESP..."
                        call ResetESP
                        call Wait80Frames
                        SetReadTimeout(255)
                        call ESPReadIntoBuffer
                        call ESPReadIntoBuffer
                        RestoreReadTimeout()
                        ld hl, [FinalMsg]Msg.Success    ; "ESP updated successfully!"
                        call PrintRst16
                        jp EndOfCommand
BeginDump:
                        PrintMsg(Msg.DumpingFW)         ; "Dumping firmware..."
                        ld a, 255
                        ld (esxDOS.Handle), a
                        ld a, '*'                       ; Default (current) drive
                        ld hl, DumpFacFileName          ; ESPDump.fac, in hl because we're in a dot command
                        ld b, $0E                       ; $02 = esx_mode_write
                        Rst8(esxDOS.F_OPEN)             ; $0C = create new file, delete existing
                        ErrorIfCarry(Err.DumpCreate)
                        ld (esxDOS.Handle), a

                        call PrintDumpProgress.NoUp

                        ; Cmd xd2: READ_FLASH
                        ; Four 32-bit words: flash offset,
                        ;                    read length,
                        ;                    flash sector size,
                        ;                    read packet size,
                        ;                    maximum number of un-acked packets
                        ; data = esp.read_flash(args.address, args.size, flash_progress)
                        ; args.address   = 0x00000000
                        ; args.size      = 0x00010000
                        ; flash_progress = function
                        ; def read_flash(self, offset, length, progress_fn=None)
                        ; self.check_command("read flash", self.ESP_READ_FLASH,
                        ;   struct.pack('<IIII', offset, length, self.FLASH_SECTOR_SIZE, 64))
                        ; offset                 = 0x00000000
                        ; length                 = 0x00010000
                        ; self.FLASH_SECTOR_SIZE = 0x00001000
                        ; self.command(op, data, chk, timeout=timeout)
                        ;   op      = 210
                        ;   data    = 16 bytes (see below)
                        ;   chk     = 0
                        ;   timeout = 3
                        ; data consists of:
                        ;   offset            = 0x00000000 (UInt32)
                        ;   length            = 0x00010000 (UInt32)
                        ;   FLASH_SECTOR_SIZE = 0x00001000 (UInt32)
                        ;   packets           = 0x00000040 (UInt32)
                        ;   Ignore what the PyCharm debugger says - it is showing 14 bytes instead of 16 :(
                        ld hl, 12                            ; Just for this command, only read the 12 bytes
                        ld (ESPReadIntoBuffer.BufferLen), hl ; corresponding to the command response
                        ESPSendCmdWithData(ESP_READ_FLASH, SLIP.Dump, SLIP.DumpLen, Err.DumpInit)
NextDumpPacket:
                        call ESPReadandDecodePacket     ; Read an entire SLIP packet (max 8KB raw, 4KB decoded)
                        jp c, CloseFileParseError
                        ld de, BigBuffer                ; Returned with hl = byte after packet end
                        sbc hl, de                      ; Carry was clear because no error, so sbc is ok
                        ld (DumpByteCount), hl          ; SMC> Save length for reply packet
                        ld bc, hl                       ; bc = length to write
                        ld hl, BigBuffer                ; hl = address to write from
                        ld a, (esxDOS.Handle)           ; a  = file handle
                        Rst8(esxDOS.F_WRITE)            ; Append to the file
                        ErrorIfCarry(Err.DumpSave)

                        ; Send dump packet acknowledgement in a SLIP packet.
                        ; Usually c0 00 10 00 00 c0 because packets are 4KB in size
                        ; and total dump size (1MB or 4MB) is an exact multiple of 4KB.
                        ld hl, [DumpByteCount]SMC       ; Write current dump received count (16bit)
                        ld (ReceivedNow), hl            ; into buffer (32bit).
                        Add32(ReceivedTotal, ReceivedNow, ReceivedTotal) ; Add to existing count (32bit)
                        ESPSendSlip(ReceivedTotal, ReceivedTotalLen) ; Send dump packet acknowledgement SLIP packet

                        ld hl, [DumpPacketCount]16      ; Will eventually be calculated
                        dec hl
                        ld (DumpPacketCount), hl
                        ld a, h
                        or l
                        jp z, DumpCompleted             ; If more packets remaining, download them
                        call PrintDumpProgress
                        jp NextDumpPacket
DumpCompleted:
                        PrintMsg(Msg.DumpingCS)         ; Print "Getting MD5 hash...". MD5 hash is sent by the
                        call esxDOS.CloseFile           ; ESP_READ_FLASH command after all packets are acknowledged.
                        ld hl, 16                       ; Just for this time, only read the 16 bytes
                        ld (ESPReadIntoBuffer.BufferLen), hl ; corresponding to the MD5 hash response
                        call ESPReadandDecodePacket     ; Read a single SLIP packet
                        PrintBufferHex($C000, 16)       ; Print MD5 in ASCII hex

                        ld a, 255
                        ld (esxDOS.Handle), a
                        ld a, '*'                       ; Default (current) drive
                        ld hl, DumpMD5FileName          ; ESPDump.md5, in hl because we're in a dot command
                        ld b, $0E                       ; $02 = esx_mode_write
                        Rst8(esxDOS.F_OPEN)             ; $0C = create new file, delete existing
                        ErrorIfCarry(Err.HashCreate)
                        ld (esxDOS.Handle), a

                        ; Create an .md5 file using *nix style md5sum output as file format:
                        ; https://man.freebsd.org/cgi/man.cgi?query=md5
                        ld hl, $C000                    ; Start of binary MD5
                        ld de, $C010                    ; Start of hash file buffer
                        ld bc, 16                       ; Convert 16 bytes
                        call Bin2Hex                    ; from binary to hex
                        ld a, ' '
                        ld (de), a                      ; Add space to buffer
                        inc de
                        ld a, '*'
                        ld (de), a                      ; Add asterisk to buffer (signifying binary mode)
                        inc de
                        ld hl, DumpFacFileName
                        ld bc, DumpFacFileNameLen
                        ldir                            ; Add dump filename to buffer
                        ld a, LF
                        ld (de), a                      ; Add LF to buffer (*nix style)

                        ld hl, $C010                    ; hl = address to write from
                        ld bc, 46                       ; bc = length to write
                        ld a, (esxDOS.Handle)           ; a  = file handle
                        Rst8(esxDOS.F_WRITE)            ; Append buffer to the file
                        ErrorIfCarry(Err.HashSave)
                        call esxDOS.CloseFile

                        PrintMsg(Msg.DumpFile)          ; Print :"Dump file: ESPDump.fac"
                        PrintMsg(DumpFacFileName)
                        PrintMsg(Msg.HashFile)          ; Print :"Hash file: ESPDump.hash"
                        PrintMsg(DumpMD5FileName)
                        PrintMsg(Msg.EOL)

                        ld hl, Msg.DumpSuccess          ; Change final message to "ESP dumped successfully!"
                        ld (FinalMsg), hl
                        jp FinalResetESP                ; Rejoin main program flow that happens after flashing

CloseFileParseError:
                        call esxDOS.CloseFile
                        ErrorAlways(Err.DumpParse)
EndOfCommand:
                        if (ErrDebug)
                          ; This is a temporary testing point that indicates we have have reached
                          ; The "success" point, and does a red/blue border effect instead of
                          ; actually exiting cleanly to BASIC.
                          Freeze(1,2)
                        else
                          ; This is the official "success" exit point of the program which restores
                          ; all the settings and exits to BASIC cleanly.
                          jp Return.ToBasic
                        endif

                        include "constants.asm"         ; Global constants
                        include "macros.asm"            ; Zeus macros
                        include "general.asm"           ; General routines
                        include "esp.asm"               ; ESP and SLIP routines
                        include "esxDOS.asm"            ; ESXDOS routines
                        include "print.asm"             ; Messaging and error routines
                        include "vars.asm"              ; Global variables
                                                        ; Everything after this is padded to the next 8K
                                                        ; but assembles at $8000
                        include "stub.asm"              ; ESP upload stub and input buffer

                        db $55, $AA, $55                ; Magic bytes to check we included the correct amount of data

UpperCodeLen equ $-UpperCodeStart
Length       equ $-Start-$4000                          ; This adjust for the displacement of the upper code bank
zeusprinthex "Lower code: ", LowerCodeStart, LowerCodeLen
zeusprinthex "Upper code: ", UpperCodeStart, UpperCodeLen
zeusprinthex "Cmd size:   ", Length

zeusassert zeusver>=75, "Upgrade to Zeus v4.00 (TEST ONLY) or above, available at http://www.desdes.com/products/oldfiles/zeustest.exe"

if (LowerCodeLen > $2000)
  zeuserror "DOT command (lower code) is too large to assemble!"
endif
if (UpperCodeLen > $4000)
  zeuserror "DOT command (upper code) is too large to assemble!"
endif

output_bin "..\\..\\dot\\ESPUPDATE", Start, Length ; Binary for project, and for CSpect image.

BuildArgs = "";
if enabled CSpect
  BuildArgs = BuildArgs + "-c "
endif
if enabled RealESP
  BuildArgs = BuildArgs + "-e "
endif
if enabled AppendFW
  BuildArgs = BuildArgs + "-a "
endif

zeusinvoke "..\\..\\build\\builddot.bat " + BuildArgs, "", false ; Run batch file with args

