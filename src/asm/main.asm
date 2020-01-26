    ; main.asm
                                                        ; Assembles with regular version of Zeus (not Next version),
zeusemulate             "48K", "RAW", "NOROM"           ; because that makes it easier to assemble dot commands
zoSupportStringEscapes  = true;                         ; Download Zeus.exe from http://www.desdes.com/products/oldfiles/
optionsize 5
CSpect optionbool 15, -15, "CSpect", false              ; Option in Zeus GUI to launch CSpect
RealESP optionbool 80, -15, "Real ESP", false           ; Launch CSpect with physical ESP in USB adaptor
UploadNext optionbool 160, -15, "Next", false           ; Copy dot command to Next FlashAir card
ErrDebug optionbool 212, -15, "Debug", false            ; Print errors onscreen and halt instead of returning to BASIC

org $2000                                               ; Dot commands always start at $2000
Start:
                        jr Begin
                        db "ESPUPDATEv1."               ; Put a signature and version in the file in case we ever
                        BuildNo()                       ; need to detect it programmatically
                        db 0
Begin:                  di                              ; We run with interrupts off apart from printing and halts
                        ld (Return.Stack1), sp          ; Save so we can always return without needing to balance stack
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

                        NextRegRead(Reg.MachineID)      ; If we passed that test we are safe to read machine ID.
                        cp 10                           ; 10 = ZX Spectrum Next
                        jp z, IsANext                   ;  8 = Emulator
                        cp 8                            ; Exit with error if not a Next. HL still points to err message,
                        jp nz, Return.WithCustomError   ; be careful if adding code between the Next check and here!
IsANext:
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

                        ; This dot command is way larger than 8KB, so we have a strategy for dealing with that.
                        ; NextZXOS will automatically load the first 8KB, which contains all the core code,
                        ; and will leave the file handle open. If the core code is less than 8KB, Zeus will
                        ; pad it to 8KB automatically.
                        ; Use of the NextZXOS API means this dot cmd cannot run under esxDOS, so we must do
                        ; an initial check for NextZXOS, and exit gracefully if not present.
                        ; We call M_GETHANDLE to get and save the handle.
                        call esxDOS.GetHandle

                        ; The next <=16KB in the file contains the ESP uploader stubs, additional code and buffers.
                        ; This is assembled so that it runs at $8000-BFFF. We will use IDE_BANK to allocate three 8KB
                        ; banks, which must be freed before exiting the dot command.
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Upper1), a  ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Upper2), a  ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Upper3), a  ; Save bank number

                        ; Now we can page in the the three 8K banks at $8000, $A000 and $C000, and try to load the
                        ; remainder of the dot command code. This paging will need to be undone during cmd exit.
                        nextreg $56, a                  ; Allocated bank for $C000 was already in A, page it in.
                        ld a, (DeallocateBanks.Upper1)
                        nextreg $54, a                  ; Page in allocated bank for $8000
                        ld a, (DeallocateBanks.Upper2)
                        nextreg $54, a                  ; Page in allocated bank for $A000
                        ld hl, $8000                    ; Start loading at $8000
                        ld bc, $4000                    ; Load up to 16KB of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.BadDot)
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
                        ESPValidateCmd($08, Dummy32)    ; Check whether this we got a sync response
//TestError:            scf                             ; You can use this forced error to test how errors are handled



                        //CSBreak()
SyncPass equ $+1:       jp c, NotSynced1                ; If we didn't sync the first time,
                        jr ReadEfuses
NotSynced1:             ld hl,NotSynced2
                        ld (SyncPass), hl
                        PrintMsg(Msg.ResetESP)          ; Reset and try a second time.
                        nextreg 2, 128                  ; Set RST low
                        call Wait80Frames               ; Hold in reset a really long time
                        nextreg 2, 0                    ; Set RST high
                        call Wait80Frames               ; Wait a really, really long time
                        call Wait80Frames
                        jp EnableProgMode
NotSynced2:             ErrorAlways(Err.NoSync)         ; Error on second failure





ReadEfuses:
                        //PrintMsg(Msg.Fuse1)           ; "Reading eFuses..."
                        call Wait5Frames
                        call ESPFlush                   ; Clear UART buffer
                        call Wait5Frames
                        ESPReadReg(0x3ff0005c)          ; Read this address
                        call Wait5Frames
                        call ESPReadIntoBuffer
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
                        ESPSendDataBlock(ESP8266StubText+0x0000, 0x1800, 0, Err.StubUpload)
                        ESPSendDataBlock(ESP8266StubText+0x1800, 0x0760, 1, Err.StubUpload)
                        ESPSendCmdWithData(ESP_MEM_BEGIN, SLIP.Stub2, SLIP.Stub2Len, Err.StubUpload)
                        ESPSendDataBlock(ESP8266StubData+0x0000, 0x0300, 0, Err.StubUpload)

                        ; Run stub
                        PrintMsg(Msg.Stub2)
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
OkStub:                 PrintMsg(Msg.Stub3)


                        if enabled FastUART
                          SetUARTBaud(Baud.b1152000, Msg.b1152000)
                          ; esp.change_baud(1152000)
                          ESPSendCmdWithData(ESP_CHANGE_BAUDRATE, SLIP.ChgBaud, SLIP.ChgBaudLen, Err.BaudChg)
                          ; print("Changed.")
                          ; self._set_port_baudrate(baud)
                          ; time.sleep(0.05)  # get rid of crap sent during baud rate change
                          ; self.flush_input()
                        endif

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
                        //ESPSendCmdWithData(ESP_SPI_SET_PARAMS, SLIP.CfgFlash, SLIP.CfgFlashLen, Err.FlashSet)

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

                        ; Read first four bytes of firmware file
                        /*
                        ld hl, $C000                    ; Start loading at $C000
                        ld bc, $0004                    ; Load 4 bytes of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.ReadFW)
                        ld hl, $C000
                        ld a, (hl)
                        cp ESP_IMAGE_MAGIC
                        ErrorIfNotZero(Err.NotFW)
                        inc hl:inc hl:inc hl
                        ld a, (hl)
                        //CSBreak()
                        and $0F
                        ld (FlashFreq), a               ; flash_freq
                        */

                        ; flash_freq = 1 (26m)
                        ; flash_mode = 2 (dio)
                        ; flash_size = 32 (MB)
                        ; flash_params = struct.pack(b'BB', flash_mode, flash_size + flash_freq) = 0x2102
                        ; flash_mode appears first, flash_size + flash_freq appears second
                        ; replace bytes 2 and 3 (zero-based) of image with these two bytes
                        PrintMsg(Msg.Stub5)
                        ld a, (FlashParams)
                        call PrintAHexNoSpace
                        ld a, (FlashParams+1)
                        call PrintAHexNoSpace
                        PrintMsg(Msg.EOL)

AfterModFlashParams:

                        ; calcmd5 = hashlib.md5(image).hexdigest() = '03192f512d08b14be06b74f98e109ee0'
                        ; uncsize = len(image) = 1048576              03192f512d08b14be06b74f98e109ee0





                        //zeusprinthex "Buffer:     ", Buffer
                        //zeusprinthex "eFuses:     ", eFuses
                        //zeusprinthex "MAC:         ", MAC

                        if (enabled TestWorkflow)
                          WaitFrames(100)
                          PrintMsg(Msg.Stub2)
                          WaitFrames(20)
                          PrintMsg(Msg.Stub3)
                          WaitFrames(10)
                          PrintMsg(Msg.Stub4)
                          WaitFrames(5)
                          PrintMsg(Msg.Stub5)
                          PrintMsg(Msg.Stub6)

                          PrintMsg(Msg.Write1)
                          call Wait80Frames
                          PrintMsg(Msg.Write2)
                          call Wait80Frames
                          PrintMsg(Msg.Write3)
                          call Wait80Frames
                          PrintMsg(Msg.Write4)
                          call Wait80Frames
                          PrintMsg(Msg.Write5)
                          call Wait80Frames
                          PrintMsg(Msg.Write6)
                          call Wait80Frames
                          PrintMsg(Msg.Write7)
                          call Wait80Frames
                          PrintMsg(Msg.Write8)
                          call Wait80Frames
                          PrintMsg(Msg.Write9)
                          call Wait80Frames

                          PrintMsg(Msg.Write10)
                          call Wait80Frames
                          PrintMsg(Msg.Write11)
                          call Wait80Frames
                          PrintMsg(Msg.Write12)
                          call Wait80Frames
                          PrintMsg(Msg.Write13)
                          call Wait80Frames
                          PrintMsg(Msg.Write14)
                          call Wait80Frames
                          PrintMsg(Msg.Write15)
                          call Wait80Frames
                          PrintMsg(Msg.Write16)
                          call Wait80Frames
                          PrintMsg(Msg.Write17)
                          call Wait80Frames
                          PrintMsg(Msg.Write18)
                          call Wait80Frames
                          PrintMsg(Msg.Write19)
                          call Wait80Frames
                          PrintMsg(Msg.Write20)
                          call Wait80Frames
                          PrintMsg(Msg.Write21)
                          call Wait80Frames
                          PrintMsg(Msg.Write22)
                          call Wait80Frames
                          PrintMsg(Msg.Write23)
                          call Wait80Frames
                          PrintMsg(Msg.Write24)
                          call Wait80Frames
                          PrintMsg(Msg.Write25)
                          call Wait80Frames
                          PrintMsg(Msg.Write26)
                          call Wait80Frames
                          PrintMsg(Msg.Write27)
                          call Wait80Frames
                          PrintMsg(Msg.Write28)
                          call Wait5Frames

                          PrintMsg(Msg.Finish1)
                          PrintMsg(Msg.Finish2)
                          PrintMsg(Msg.Finish3)
                          nextreg 2, 128                  ; Set RST Low
                          call Wait5Frames
                          nextreg 2, 0                    ; Set RST high
                          call Wait5Frames
                        endif

                        if (ErrDebug)
                          ; This is a temporary testing point that indicates we have have reached
                          ; The "success" point, and does a red/blue border effect instead of
                          ; actually exiting cleanly to BASIC.
                          Freeze(1,2)
                        else
                          ; This is the official "success" exit point of the program which restores
                          ; all the settings and exits to BASIC cleanly.
                          PrintMsg(Msg.Success)
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

if zeusver >= 74
  zeuserror "Does not run on Zeus v4.00 (TEST ONLY) or above, Get v3.991 available at http://www.desdes.com/products/oldfiles/zeus.exe"
endif

if (LowerCodeLen > $2000)
  zeuserror "DOT command (lower code) is too large to assemble!"
endif
if (UpperCodeLen > $4000)
  zeuserror "DOT command (upper code) is too large to assemble!"
endif

output_bin "..\\..\\dot\\ESPUPDATE", Start, Length              ; Binary for project, and for CSpect image.

if enabled UploadNext
  output_bin "R:\\dot\\ESPUPDATE", Start, Length                ; NextZXOS  dot command (LFN)
  //output_bin "R:\\dot\\extra\\ESPUPDATE", Start, Length       ; 48K BASIC dot command (LFN)
  //output_bin "R:\\bin\\ESPUPD", Start, Length                 ; esxDOS    dot command (8+3)
endif

if enabled CSpect
  if enabled RealESP
    zeusinvoke "..\\..\\build\\cspect.bat"                      ; Build, copy to SD image, launch CSpect w/ USB ESP
  else
    zeusinvoke "..\\..\\build\\cspect-emulate-esp.bat"          ; Build, copy to SD image, launch CSpect w/ emulated ESP
  endif
else
  zeusinvoke "..\\..\\build\\builddot.bat"                      ; Just build
endif

