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
                        ; This is assembled so that it runs at $8000-BFFF. We will use IDE_BANK to allocate two 8KB
                        ; banks, which must be freed before exiting the dot command.
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Upper1), a  ; Save bank number
                        call Allocate8KBank             ; Bank number in A (not E), errors have already been handled
                        ld (DeallocateBanks.Upper2), a  ; Save bank number

                        ; Now we can page in the the two 8K banks at $8000 and $A000, and try to load the
                        ; remainder of the dot command code. This paging will need to be undone during cmd exit.
                        nextreg $55, a                  ; Allocated bank for $A000 was already in A, page it in.
                        ld a, (DeallocateBanks.Upper1)
                        nextreg $54, a                  ; Page in allocated bank for $8000
                        ld hl, $8000                    ; Start loading at $8000
                        ld bc, $4000                    ; Load up to 16KB of data
                        call esxDOS.fRead
                        ErrorIfCarry(Err.BadDot)
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
                        ErrorIfCarry(Err.NoSync)
                        //PrintMsg(Msg.SyncOK)

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

                        ; This should send:
                        ; c0 00 05 10 00 00 00 00 00 60 1f 00 00 02 00 00
                        ; 00 00 18 00 00 00 e0 10 40 c0
                        ; We should receive:
                        ; c0 01 05 02 00 94 01 60 00 00 00 c0
                        ; We know that the data received should be at least two bytes here
                        ; If success, the first byte will be be 00
                        ; If failure, the first byte will be non-zero and the second byte will be the reason code
                        ; (The data could be more than two..four bytes if the command was md5sum)

                        ; A2: mem_block(stub[field][from_offs:to_offs], seq)
                        ; which equates to:
                        ; mem_block(text[0:0x1800], 0)
                        ; which equates to:
                        ; command(ESP_MEM_DATA, data1, chk, timeout)
                        ; where:
                        ;   ESP_MEM_DATA = 0x07
                        ;   data1        = 0x1810 bytes, comprising:
                        ;     len(data)  = 0x00001800
                        ;     seq        = 0x00000000 (block number)
                        ;     unk1       = 0x00000000
                        ;     unk2       = 0x00000000
                        ;     data       = text[0:0x1800] (0x1800 bytes)
                        ;   chk          = 0xED (ESP_CHECKSUM_MAGIC XOR'd with every byte in data), where:
                        ;                  ESP_CHECKSUM_MAGIC = 0xEF
                        ;   timeout      = 0x03
                        ; which should send:
                        /*
    c0 00 07 10 18 ed 00 00 00 00 18 00 00 00 00 00   �....�..........
    00 00 00 00 00 00 00 00 00 a8 10 00 40 01 ff ff   .........�..@.��
    46 45 00 00 00 00 80 fe 3f 4f 48 41 49 a4 ab ff   FE....��?OHAI���
    3f 0c ab fe 3f 80 80 00 00 e8 f9 10 40 0c 00 00   ?.��?��..��.@...
    60 00 00 00 01 00 00 01 00 00 10 00 00 ff ff 00   `............��.
    00 8c 80 00 00 10 40 00 00 00 00 ff ff 00 40 00   .��...@....��.@.
    00 00 80 fe 3f 9c 2b ff 3f a0 2b ff 3f 10 27 00   ..��?�+�?�+�?.'.
    00 14 00 00 60 ff ff 0f 00 a4 ab ff 3f a4 ab ff   ....`��..���?���
    3f a4 2b ff 3f b4 ab ff 3f 00 80 00 00 20 29 00   ?�+�?���?.�.. ).
    00 f8 8d fe 3f 58 80 fe 3f a8 ab ff 3f 98 ae ff   .���?X��?���?���
    3f 98 9b fe 3f 84 ae ff 3f 80 1b 00 00 a0 0d 00   ?���?���?�...�..
    00 00 08 00 00 20 09 00 00 50 0e 00 00 50 12 00   ..... ...P...P..
    00 ac ab ff 3f b0 ab ff 3f 1f 29 00 00 3c a9 fe   .���?���?.)..<��
    3f 08 ae ff 3f 8c ad ff 3f 80 0b 00 00 0c ad ff   ?.��?���?�....��
    3f 8c ac ff 3f b0 15 00 00 f1 ff 00 00 00 ab fe   ?���?�...��...��
    3f 00 a9 fe 3f bc 0f 00 40 88 0f 00 40 a8 0f 00   ?.��?�..@�..@�..
    40 58 3f 00 40 2c 4c 00 40 30 3b 00 40 78 48 00   @X?.@,L.@0;.@xH.
    40 00 4a 00 40 b4 49 00 40 cc 2e 00 40 1c e2 00   @.J.@�I.@�..@.�.
    40 d8 39 00 40 68 e2 00 40 48 df 00 40 90 e1 00   @�9.@h�.@H�.@��.
    40 4c 26 00 40 84 49 00 40 21 bc ff 92 a1 10 90   @L&.@�I.@!����.�
    11 db dc 22 61 23 22 a0 00 02 61 43 c2 61 42 d2   .��"a#"�..aC�aB�
    61 41 e2 61 40 f2 61 3f 01 e7 ff db dc 00 00 21   aA�a@�a?.����..!
    b2 ff 31 b3 ff 0c 04 06 01 00 00 49 02 4b 22 37   ��1��......I.K"7
    32 f8 22 a0 8c 2a 21 0c 43 45 b3 01 21 ae ff c1   2�"��*!.CE�.!���
    ad ff 31 ae ff 2a 2c db dc 20 00 c9 02 42 a0 00   ��1��*,�� .�.B�.
    22 a0 05 01 da ff db dc 00 00 21 a9 ff 32 a1 01   "�..����..!��2�.
    db dc 20 00 48 02 30 34 20 db dc 20 00 39 02 2c   �� .H.04 �� .9.,
    02 01 d4 ff db dc 00 00 01 d4 ff db dc 00 00 31   ..����...����..1
    a2 ff 41 a2 ff 51 a3 ff 71 a3 ff 0c 02 62 a1 00   ��A��Q��q��..b�.
    01 cf ff db dc 00 00 21 a0 ff 31 98 ff 2a 23 db   .����..!��1��*#�
    dc 20 00 38 02 16 73 ff db dc 20 00 c8 02 0c 03   � .8..s��� .�...
    db dc 20 00 39 02 0c 12 22 41 84 22 0c 01 0c 24   �� .9..."A�"...$
    22 41 85 42 51 43 32 61 22 26 92 08 1c 33 37 12   "A�BQC2a"&�..37.
    1f 86 08 00 00 22 0c 03 32 0c 02 80 22 11 30 22   .�..."..2..�".0"
    20 66 42 12 28 2c db dc 20 00 28 02 22 61 22 46    fB.(,�� .(."a"F
    01 00 22 a0 12 22 51 43 22 a0 db dc 01 b6 ff db   .."�."QC"���.���
    dc 00 00 22 a0 84 10 22 80 32 a0 08 45 a4 01 f2   �.."��."�2�.E�.�
    0c 03 22 0c 02 80 ff 11 20 ff 20 21 82 ff f7 b2   .."..��. � !����
    17 05 9e 01 22 a0 ee 01 ac ff db dc 00 00 22 a0   ..�."��.����.."�
    db dc 01 aa ff db dc 00 00 c6 d8 ff 32 0c 01 0c   ��.����..���2...
    d2 27 93 02 c6 85 00 37 32 51 66 63 02 86 9e 00   �'�.ƅ.72Qfc.��.
    f6 73 23 66 33 02 46 5d 00 f6 43 0a 66 23 02 86   �s#f3.F].�C.f#.�
    4c 00 06 9d 00 00 00 66 43 02 46 71 00 66 53 02   L..�...fC.Fq.fS.
    c6 83 00 c6 98 00 00 0c 92 27 93 02 06 7a 00 37   ƃ.Ƙ...�'�..z.7
    32 08 66 73 02 c6 80 00 86 93 00 66 93 02 46 78   2.fs.ƀ.��.f�.Fx
    00 0c b2 27 93 02 46 6d 00 46 8f 00 1c 32 27 93   ..�'�.Fm.F�..2'�
    02 c6 39 00 37 32 28 66 b3 02 86 40 00 1c 02 37   .�9.72(f�.�@...7
    32 0a 0c f2 27 93 02 06 2e 00 06 87 00 1c 12 27   2..�'�.....�...'
    93 02 46 42 00 1c 22 27 93 02 46 59 00 46 82 00   �.FB.."'�.FY.F�.
    22 a0 d1 27 13 2c 37 32 09 22 a0 d0 27 13 18 c6   "��'.,72."��'..�
    7d 00 00 22 a0 d2 27 93 02 86 25 00 22 a0 d3 27   }.."��'�.�%."��'
    93 02 86 96 05 46 78 00 0c 1d cc 1f 86 60 05 06   �.��.Fx...�.�`..
    74 00 00 66 8f 02 46 61 05 06 71 00 00 01 74 ff   t..f�.Fa..q...t�
    db dc 00 00 ea ed 9c 12 86 6d 00 00 20 2c 41 01   ��..��.�m.. ,A.
    71 ff db dc 00 00 56 92 1a d2 dd f0 d0 2e db dc   q���..V�.����.��
    8c 4d 20 30 f4 56 53 fe da f2 e1 38 ff 06 04 00   �M 0�VS����8�...
    00 00 20 20 f5 01 69 ff db dc 00 00 56 52 18 e0   ..  �.i���..VR.�
    dd db dc d0 2f db dc d7 3e ea da e2 06 04 00 00   ����/���>���....
    00 20 2c 41 01 61 ff db dc 00 00 56 92 16 d2 dd   . ,A.a���..V�.��
    f0 d0 2e db dc 56 ad fe c6 57 00 0c 0e d2 a0 db   ��.��V���W...Ҡ�
    dc 26 8f 02 46 58 00 86 66 05 00 00 66 bf 02 86   �&�.FX.�f...f�.�
    64 05 06 3b 00 66 bf 02 86 43 05 c6 4e 00 0c 1d   d..;.f�.�C.�N...
    26 bf 02 46 4d 00 38 4c 21 24 ff 0c 0e d2 a0 c2   &�.FM.8L!$�..Ҡ�
    27 13 02 86 4c 00 46 3f 05 0c 14 66 bf 12 38 4c   '..�L.F?...f�.8L
    21 1e ff 0c 0e d2 a0 c2 27 13 02 86 46 00 c6 3e   !.�..Ҡ�'..�F.�>
    05 dd 04 46 41 00 00 00 21 19 ff 0c 0e 32 02 00   .�.FA...!.�..2..
    d2 a0 c6 e7 93 02 c6 3f 00 38 2c d8 52 f2 cf f0   Ҡ��.�?.8,�R���
    f0 33 db dc 22 a0 db dc 30 d2 93 32 cc 18 22 a0   �3��"���0ғ2�."�
    ef 46 02 00 ea 43 42 04 00 1b ee 40 22 30 f7 2e   �F..�CB...�@"0�.
    f2 52 0c 05 62 0c 04 42 0c 06 80 55 11 32 0c 07   �R..b..B..�U.2..
    60 55 20 00 44 11 50 44 20 80 33 01 40 33 20 30   `U .D.PD �3.@3 0
    22 db dc 32 a0 c1 0c 0e 20 d3 93 46 2b 00 00 21   "��2��.. ӓF+..!
    00 ff d2 a0 c6 32 02 00 16 33 09 38 32 d2 a0 c8   .�Ҡ�2...3.82Ҡ�
    56 b3 08 32 42 00 d8 52 c6 20 00 1c 82 27 9f 02   V�.2B.�R� ..�'�.
    46 24 05 0c 0e 0c 1d 46 20 00 00 66 4f 02 46 28   F$.....F ..fO.F(
    05 06 1a 00 66 bf 02 06 29 05 c6 01 00 00 00 66   ....f�..).�....f
    4f 02 86 28 05 0c 0e d2 a0 db dc 86 17 00 00 00   O.�(...Ҡ�܆....
    66 bf 02 46 26 05 06 11 00 41 ea fe f2 cf f0 78   f�.F&....A�����x
    04 cc 37 d2 a0 c6 fc 6f 31 e8 fe d2 a0 c9 68 03   .�7Ҡ��o1��Ҡ�h.
    f7 36 2c f0 20 14 d2 a0 db dc 92 cc 18 8c 92 86   �6,� .Ҡ�ܒ�.���
    07 00 2a 89 88 08 4b 22 89 05 2a 57 20 86 db dc   ..*��.K"�.*W ���
    f7 32 ef 59 04 89 03 46 10 05 66 8f 02 86 18 05   �2�Y.�.F..f�.�..
    0c 1d 0c 0e c6 01 00 00 00 e2 a0 00 d2 a0 ff d0   ....�....�.Ҡ��
    20 74 05 74 01 e0 20 74 c5 73 01 22 a0 db dc 01    t.t.� t�s."���.
    fb fe db dc 00 00 56 7d ca 22 0c 01 32 a0 0f 37   ����..V}�"..2�.7
    12 31 27 33 14 66 42 02 06 d2 04 66 62 02 c6 d6   .1'3.fB..�.fb.��
    04 26 32 02 46 22 ff 46 1a 00 1c 23 37 92 02 46   .&2.F"�F...#7�.F
    cc 04 32 a0 d2 37 12 49 1c 13 37 12 02 06 1c ff   �.2��7.I..7....�
    c6 1a 00 00 21 c3 fe 01 ed fe db dc 00 00 21 c1   �...!��.����..!�
    fe db dc 20 00 38 02 21 db dc fe 20 33 10 22 2c   ��� .8.!��� 3.",
    03 20 23 82 32 2c 02 01 e7 fe db dc 00 00 3d 02   . #�2,..����..=.
    2d 0d 01 e5 fe db dc 00 00 22 a3 e8 01 e1 fe db   -..����.."��.���
    dc 00 00 06 0c ff 00 00 22 2c 02 32 2c 03 42 2c   �....�..",.2,.B,
    04 58 5c 85 76 01 46 07 ff 00 32 0c 03 22 0c 02   .X\�v.F.�.2.."..
    80 33 11 20 33 20 32 c3 f0 22 cc 18 45 5b 01 06   �3. 3 2��"�.E[..
    01 ff 00 00 00 22 0c 03 32 0c 02 80 22 11 30 22   .�..."..2..�".0"
    20 22 c2 f0 f2 cc 18 22 61 2b 0c 1e 86 95 04 21    "����."a+..��.!
    a4 fe 41 c1 fe b2 22 00 d1 a3 fe 62 a0 03 22 24   ��A���".ѣ�b�."$
    02 72 21 2b 62 61 25 b0 dd db dc 27 37 04 0c 18   .r!+ba%����'7...
    82 61 25 b2 61 35 05 4d 01 b2 21 35 71 9b fe 92   �a%�a5.M.�!5q���
    21 2b 70 4b db dc da 44 0b 84 da 6b 62 61 29 82   !+pK���D.��kba)�
    61 2c 40 58 10 9a af 8c 15 46 6e 04 77 bb 02 c6   a,@X.���.Fn.w�.�
    6e 04 98 ec 72 2c 10 82 2c 15 28 6c 92 61 26 72   n.��r,.�,.(l�a&r
    61 24 82 61 2a 3c 53 d8 7c e2 2c 14 68 fc 27 b3   a$�a*<S�|�,.h�'�
    02 06 1b 04 31 8b fe 30 22 a0 28 02 a0 02 00 21   ....1��0"�(.�..!
    7f fe 0c 0e 0c 13 e9 92 e9 82 39 d2 39 a2 a7 3f   �....��9�9��?
    3a e2 61 24 6d 0e e2 61 26 e0 de 20 92 21 25 0c   :�a$m.�a&�� �!%.
    23 30 39 10 21 76 fe 9c 93 0c 14 49 62 5d 0b cd   #09.!v���..Ib].�
    0f 86 0c 04 a7 bf e4 32 0f 00 21 70 fe 1b cf 39   .�..���2..!p�.�9
    82 06 06 00 39 82 cd 0f 46 04 00 00 32 0f 00 1b   �...9��.F...2...
    cf 39 82 e2 61 24 6d 0e e2 61 26 dd 0e a7 3c 2c   �9��a$m.�a&�.�<,
    86 00 00 00 cd 0f 72 21 25 0c 25 50 37 10 21 63   �...�.r!%.%P7.!c
    fe 9c 03 59 62 5d 0b c6 2e 00 a7 bf e6 32 0f 00   ��.Yb].�..���2..
    21 5f fe 1b cf 39 92 06 03 00 00 00 00 32 0c 00   !_�.�9�......2..
    21 5b fe 1b cc 39 92 21 59 fe 1c f3 58 82 68 92   ![�.�9�!Y�.�X�h�
    80 25 11 6a 22 42 61 30 52 61 34 62 61 2f a2 61   �%.j"Ba0Ra4ba/�a
    33 b2 61 35 01 83 fe db dc 00 00 0c 13 42 21 30   3�a5.����....B!0
    52 21 34 62 21 2f a2 21 33 b2 21 35 cc e2 2c 02   R!4b!/�!3�!5��,.
    20 66 10 cc 76 50 20 34 22 c2 f8 20 36 83 50 54    f.�vP 4"�� 6�PT
    41 8b 55 0c 12 71 50 fe 00 15 40 00 62 a1 67 37   A�U..qP�..@.b�g7
    0f 00 05 40 40 40 91 0c 06 40 62 83 30 66 20 9c   ...@@@�..@b�0f �
    46 0c 16 46 00 00 cd 0f 21 3d fe 2c 43 39 62 5d   F..F..�.!=�,C9b]
    0b 46 d4 03 00 00 00 5d 0b f6 3d 3f a7 3c 29 c6   .F�....].�=?�<)�
    00 00 5d 0b cd 0f 82 21 25 0c 22 20 28 10 9c c2   ..].�.�!%." (.��
    0c 33 21 32 fe 39 62 0c 14 c6 ca 03 a7 bf e2 1b   .3!2�9b..��.���.
    cf 22 0f 00 5d 0b 06 01 00 22 0c 00 1b cc 00 1d   �"..]...."...�..
    40 00 22 a1 20 ee 20 8b dd 06 ef ff 71 28 fe e0   @."� � ��.��q(��
    20 24 29 b7 20 21 41 29 c7 e0 e3 41 d2 cd fd 56    $)� !A)���A���V
    22 23 d0 20 24 27 bd 3c a7 3c 25 c6 00 00 5d 0b   "#� $'�<�<%�..].
    cd 0f 92 21 25 0c 22 20 29 10 0c 53 56 22 fa c6   �.�!%." )..SV"��
    04 00 00 00 a7 bf e6 1b cf 22 0f 00 5d 0b 06 01   ....���.�"..]...
    00 22 0c 00 1b cc 00 1d 40 00 22 a1 20 ee 20 8b   ."...�..@."� � �
    dd 46 ef ff 00 d0 20 24 00 02 40 e0 e0 91 7c 82   �F��.� $..@���|�
    20 dd 10 0c 06 16 4d 05 f6 8d 39 a7 3c 23 c6 00    �....M.��9�<#�.
    00 5d 0b cd 0f 72 21 25 0c 22 20 27 10 0c 63 56   .].�.r!%." '..cV
    f2 f4 46 04 00 a7 bf e8 1b cf 22 0f 00 5d 0b 06   ��F..���.�"..]..
    01 00 22 0c 00 1b cc 00 1d 40 00 22 a1 20 ee 20   .."...�..@."� �
    8b dd 86 f0 ff 21 fe fd 31 08 fe 6a 22 3a 22 e2   �݆��!��1.�j":"�
    42 18 d2 cd f8 e0 e8 41 06 16 00 00 00 a7 3c 41   B.�����A.....�<A
    c6 00 00 5d 0b cd 0f 82 21 25 0c 22 20 28 10 31   �..].�.�!%." (.1
    f3 fd 9c f2 0c 72 29 63 c6 be ff a7 bf e4 21 ef   ����.r)cƾ����!�
    fd 41 fa fd 32 0f 00 6a 22 4a 22 1b cf 32 42 18   �A��2..j"J".�2B.
    5d 0b 86 07 00 41 f5 fd 6a 33 4a 33 22 43 18 46   ].�..A��j3J3"C.F
    04 00 21 e6 fd 41 f1 fd 32 0c 00 6a 22 4a 22 32   ..!��A��2..j"J"2
    42 18 1b cc 1b 66 f6 46 02 06 d2 ff 91 04 fe 62   B..�.f�F..���.�b
    09 39 22 09 38 80 66 11 20 66 20 22 09 3b 32 09   .9".8�f. f ".;2.
    3a 80 22 11 30 22 20 31 d4 fd 30 22 30 27 96 06   :�".0" 1��0"0'�.
    86 1c 00 5d 0b cd 0f 2c 73 46 e2 00 00 f6 8d 3c   �..].�.,sF�..��<
    a7 3c 25 c6 00 00 5d 0b cd 0f 72 21 25 0c 22 20   �<%�..].�.r!%."
    27 10 3c 33 56 a2 e6 c6 04 00 00 00 a7 bf e6 1b   '.<3V���....���.
    cf 22 0f 00 5d 0b 06 01 00 22 0c 00 1b cc 00 1d   �"..]...."...�..
    40 00 22 a1 20 ee 20 8b dd 06 f0 ff 00 e0 80 74   @."� � ��.��.��t
    82 61 26 e0 e8 41 d2 cd f8 46 02 00 00 3c 43 46   �a&��A���F...<CF
    f7 02 5d 0b cd 0f 92 21 29 97 b5 f0 72 21 26 0b   �.].�.�!)���r!&.
    66 72 45 00 1b 55 0c 02 0c 13 4d 02 d0 43 93 60   frE..U....M.�C�`
    23 93 27 84 87 86 1d 00 0c 93 86 ec 02 5d 0b cd   #�'���...���.].�
    0f 82 21 29 87 b5 f0 46 07 00 92 21 25 0c 22 2c   .�!)���F..�!%.",
    63 27 09 02 86 7a ff c6 00 00 5d 0b cd 0f 2c 83   c'..�z��..].�.,�
    86 b8 00 00 5d 0b cd 0f a7 bc de 72 21 29 50 27   ��..].�.���r!)P'
    db dc db dc 7a db dc 77 b2 01 7d 02 77 b6 01 7d   ����z��w�.}.w�.}
    06 2d 05 3d 0c 4d 07 52 61 34 62 61 2f 72 61 32   .-.=.M.Ra4ba/ra2
    a2 61 33 b2 61 35 01 d0 fd db dc 00 00 72 21 32   �a3�a5.����..r!2
    52 21 34 62 21 2f b2 21 35 a2 21 33 7a cc 7a 55   R!4b!/�!5�!3z�zU
    70 66 db dc 56 e6 f8 c6 ed 02 66 32 0d 46 01 00   pf��V����.f2.F..
    00 00 5d 0b cd 0f 0c a3 c6 9f 00 26 12 02 86 21   ..].�..�Ɵ.&..�!
    00 22 a1 20 22 67 11 2c 04 21 9a fd 42 67 12 32   ."� "g.,.!��Bg.2
    a0 05 52 61 34 62 61 2f 72 61 32 a2 61 33 b2 61   �.Ra4ba/ra2�a3�a
    35 01 bb fd db dc 00 00 72 21 32 22 a0 e8 2a 77   5.����..r!2"��*w
    31 91 fd b2 21 35 a2 21 33 62 21 2f 52 21 34 2d   1���!5�!3b!/R!4-
    07 42 a0 08 42 43 00 1b 33 77 93 f7 32 c2 70 8d   .B�.BC..3w��2�p�
    03 0c 94 42 42 00 1b 22 37 92 f7 22 a1 00 32 a1   ..�BB.."7��"�.2�
    18 0c 74 c6 01 00 00 42 48 00 1b 22 1b 88 37 92   ..t�...BH..".�7�
    f5 32 ae e8 3a 88 0c 87 32 a1 1f 2a 48 72 44 00   �2��:�.�2�.*HrD.
    1b 22 27 b3 f5 06 6e 01 00 0c 06 21 7c fd 6a 22   ."'��.n....!|�j"
    22 02 00 27 bd 3c a7 3c 25 c6 00 00 5d 0b cd 0f   "..'�<�<%�..].�.
    82 21 25 0c 22 20 28 10 0c b3 56 a2 cc c6 04 00   �!%." (..�V���..
    a7 bf e8 1b cf 22 0f 00 5d 0b 86 01 00 00 00 22   ���.�"..].�...."
    0c 00 1b cc 00 1d 40 00 22 a1 20 ee 20 8b dd 06   ...�..@."� � ��.
    ee ff 00 21 6a fd 0c 13 6a 22 22 02 00 41 68 fd   ��.!j�..j""..Ah�
    00 12 40 00 33 a1 40 46 a0 0b 33 e0 33 10 20 dd   ..@.3�@F�.3�3. �
    db dc 00 02 40 e0 e0 91 48 04 21 52 fd 4a 33 20   ��..@���H.!R�J3
    26 a0 32 62 11 1b 66 b6 36 81 21 5e fd 0c 03 42   &�2b..f�6�!^�..B
    a1 20 52 61 34 a2 61 33 b2 61 35 01 7d fd db dc   � Ra4�a3�a5.}���
    00 00 0c 06 52 21 34 a2 21 33 b2 21 35 06 18 00   ....R!4�!3�!5...
    00 f6 3d 3c a7 3c 25 c6 00 00 5d 0b cd 0f 92 21   .�=<�<%�..].�.�!
    25 0c 22 20 29 10 0c e3 56 e2 c2 c6 04 00 00 00   %." )..�V���....
    a7 bf e6 1b cf 22 0f 00 5d 0b 06 01 00 22 0c 00   ���.�"..]...."..
    1b cc 00 1d 40 00 22 a1 20 ee 20 8b dd 06 f0 ff   .�..@."� � ��.��
    00 21 46 fd 41 34 fd 6a 22 22 02 00 e0 30 24 2a   .!F�A4�j""..�0$*
    24 41 43 fd d2 cd fd 4a 22 32 42 18 e0 e3 41 1b   $AC����J"2B.��A.
    66 21 2d fd 32 22 13 37 36 96 1c 33 32 62 13 06   f!-�2".76�.32b..
    28 01 71 3b fd 0c 03 70 72 82 42 a0 40 70 78 80   (.q;�..pr�B�@px�
    72 c7 58 22 c1 44 52 61 34 62 61 2f 82 61 31 a2   r�X"�DRa4ba/�a1�
    61 33 b2 61 35 72 61 27 01 52 fd db dc 00 00 72   a3�a5ra'.R���..r
    21 27 41 31 fd 22 a1 20 2a 27 32 a0 00 01 4d fd   !'A1�"� *'2�..M�
    db dc 00 00 21 2d fd 92 21 27 0c 03 2a 29 42 a4   ��..!-��!'..*)B�
    80 01 48 fd db dc 00 00 82 21 31 52 21 34 28 c8   �.H���..�!1R!4(�
    62 21 2f 80 82 a0 82 28 11 22 61 2d 82 61 2e 0c   b!/����(."a-�a..
    02 a2 21 33 b2 21 35 86 05 00 00 00 72 21 27 2a   .�!3�!5�....r!'*
    37 32 03 00 1b 22 10 33 a0 42 23 11 1b 44 42 63   72...".3�B#..DBc
    11 82 21 2e 87 92 e4 0c 02 29 11 29 01 4d 02 0c   .�!.���..).).M..
    13 e0 83 11 72 c1 44 8a 97 98 09 8a 81 9a 22 f0   .��.r�D���.���"�
    22 11 1b 33 29 18 9a 44 66 b3 e5 82 a0 01 f6 24   "..3).�Df�傠.�$
    02 82 a0 00 31 f7 fc 0c 09 3a 22 0c 13 20 93 93   .��.1��..:".. ��
    80 99 10 7c f2 16 39 11 c6 00 00 5d 0b cd 0f 2c   ��.|�.9.�..].�.,
    33 21 f1 fc 39 62 c6 89 02 82 21 27 9a 38 82 03   3!��9bƉ.�!'�8�.
    00 16 58 0f 10 38 a0 48 03 0c 07 42 61 36 1b 44   ..X..8�H...Ba6.D
    49 03 72 61 38 70 37 20 f0 33 11 32 61 37 32 21   I.ra8p7 �3.2a72!
    36 42 21 37 30 30 04 72 21 36 32 61 28 40 33 20   6B!700.r!62a(@3
    42 21 38 70 71 41 1b 44 72 61 36 42 61 38 47 98   B!8pqA.Dra6Ba8G�
    d6 0c a7 87 37 31 70 48 11 90 44 20 00 44 11 40   �.��71pH.�D .D.@
    40 31 42 61 28 0c 14 00 18 40 00 84 a1 46 03 00   @1Ba(....@.��F..
    42 21 27 40 73 90 42 21 28 8a 33 42 57 90 72 a3   B!'@s�B!(�3BW�r�
    ff 37 b7 eb 86 20 00 00 42 21 27 30 70 94 40 77   �7�� ..B!'0p�@w
    90 42 97 90 56 84 00 22 57 90 20 42 20 22 c2 fe   �B��V�."W� B "��
    30 39 41 0c 07 06 0c 00 32 21 37 30 70 04 70 44   09A.....2!70p.pD
    db dc 72 af ff 40 47 30 72 21 27 70 44 90 42 d4   ��r��@G0r!'pD�B�
    09 42 61 28 42 94 10 cc a4 42 21 28 22 54 10 20   .Ba(B�.̤B!("T.
    42 20 22 c2 fe 72 21 36 1b 77 72 61 36 72 21 36   B "��r!6.wra6r!6
    30 31 41 32 61 37 70 78 db dc 0c b3 37 97 ba 72   01A2a7px��.�7��r
    21 37 7c f8 70 30 04 30 34 db dc 30 38 30 42 a4   !7|�p0.04��080B�
    90 72 21 27 40 33 80 70 33 90 92 53 00 1b 99 82   �r!'@3�p3��S..��
    21 2e 87 19 02 c6 bc ff 92 21 2d 26 29 02 86 a7   !.�..Ƽ��!-&).��
    00 86 8d 00 0c e2 d7 b2 02 86 33 00 db dc 2a db   .��..�ײ.�3.��*�
    dc a6 22 02 86 29 00 21 bb fc e0 30 94 71 a4 fc   ܦ".�).!���0�q��
    2a 23 70 22 90 42 12 0c 00 44 11 40 30 31 96 93   *#p"�B...D.@01��
    01 40 49 31 0c 13 47 bd 01 0c 03 0c 02 0c 17 40   .@I1..G�.......@
    27 93 37 02 02 06 25 00 86 0b 00 0c a2 d7 b2 29   '�7...%.�...�ײ)
    91 ae fc 7c f8 00 02 40 e0 40 91 30 38 db dc 40   ���|�..@�@�08��@
    40 04 4a 33 9a 33 70 33 90 32 93 0c d6 e3 06 1b   @.J3�3p3�2�.��..
    42 2b 22 27 3d 04 2d 04 86 f6 ff a7 3c 24 06 01   B+"'=.-.����<$..
    00 00 5d 0b cd 0f 72 21 25 0c 22 20 27 10 1c 03   ..].�.r!%." '...
    56 f2 94 46 04 00 a7 bf e8 1b cf 22 0f 00 5d 0b   V�F..���.�"..].
    06 01 00 22 0c 00 1b cc 00 1d 40 00 22 a1 20 ee   ..."...�..@."� �
    20 8b dd 0c e2 d7 32 02 06 d7 ff c6 07 00 00 32    ��.��2..���...2
    0c 00 42 0c 01 8b 2d 00 1d 40 00 33 a1 00 12 40   ..B..�-..@.3�..@
    00 24 a1 20 23 20 20 ee 20 2b cc d2 cd 10 21 8a   .$� #  � +���.!�
    fc e0 30 94 71 72 fc 2a 23 70 22 90 32 12 0c 00   ��0�qr�*#p"�2...
    33 11 30 20 31 96 82 00 30 39 31 20 20 84 06 0a   3.0 1��.091  �..
    00 91 82 fc 0c a4 7c f8 1b 34 00 04 40 e0 40 91   .���.�|�.4..@�@�
    20 28 db dc 40 40 04 4a 22 9a 22 70 22 90 22 92    (��@@.J"�"p"�"�
    0c d6 62 00 4d 03 c6 f7 ff 00 00 22 61 26 82 21   .�b.M.���.."a&�!
    26 0c f2 00 03 40 e0 e0 91 30 dd db dc 87 32 13   &.�..@���0��܇2.
    21 5c fc 31 66 fc 6a 22 3a 22 82 42 1c 1b 66 c6   !\�1f�j":"�B..f�
    3b 00 00 00 92 21 26 0c 02 0c 13 42 c9 f0 7d 02   ;...�!&....B��}.
    40 73 83 60 32 93 37 07 12 1c 08 6d 02 82 61 26   @s�`2�7....m.�a&
    c6 00 00 5d 0b cd 0f 1c 13 06 5b ff 21 65 fc 92   �..].�....[�!e��
    21 26 9a 22 22 c2 f0 22 02 00 22 61 24 27 bd 3f   !&�""��".."a$'�?
    a7 3c 24 c6 00 00 5d 0b cd 0f 72 21 25 0c 22 20   �<$�..].�.r!%."
    27 10 1c 23 56 d2 83 c6 04 00 00 a7 bf e7 1b cf   '..#V҃�...���.�
    22 0f 00 5d 0b 46 01 00 22 0c 00 c2 cc 01 82 21   "..].F.."..��.�!
    24 00 1d 40 00 22 a1 d2 cd 08 20 ee 20 87 3d bf   $..@."���. � �=�
    21 51 fc 82 21 26 92 21 24 0c 17 8a 22 00 19 40   !Q��!&�!$..�"..@
    00 77 a1 22 c2 f0 22 02 00 0b 77 e0 77 10 2a 77   .w�"��"...w�w.*w
    21 3b fc 41 2f fc 2a 26 4a 22 00 09 40 e0 e0 91   !;�A/�*&J"..@���
    90 dd db dc 22 c2 1c 0c 03 66 b8 09 31 43 fc 6a   ����"�...f�.1C�j
    44 3a 44 32 04 1c 4d 07 52 61 34 62 61 2f 72 61   D:D2..M.Ra4ba/ra
    32 a2 61 33 b2 61 35 01 55 fc db dc 00 00 62 21   2�a3�a5.U���..b!
    2f 72 21 32 52 21 34 7a 66 a2 21 33 b2 21 35 46   /r!2R!4zf�!3�!5F
    00 00 0c 06 71 1b fc 42 27 11 22 27 12 2a 24 27   ....q.�B'."'.*$'
    b6 02 46 6d ff 67 92 06 06 02 00 5d 0b cd 0f 1c   �.Fm�g�....].�..
    53 86 21 ff 31 2e fc 21 1f fc 52 61 34 62 61 2f   S�!�1.�!.�Ra4ba/
    a2 61 33 b2 61 35 72 61 32 01 40 fc db dc 00 00   �a3�a5ra2.@���..
    72 21 32 21 17 fc 32 27 11 42 27 12 2a 33 7a 33   r!2!.�2'.B'.*3z3
    21 14 fc 32 c3 1c 01 39 fc db dc 00 00 b2 21 35   !.�2�..9���..�!5
    a2 21 33 62 21 2f 52 21 34 21 02 fc 38 c2 0b 33   �!3b!/R!4!.�8�.3
    39 c2 81 00 fc 28 c8 d6 62 b5 86 53 01 db dc 2a   9.�(��b��S.��*
    db dc e6 42 08 0c e3 d7 b3 13 06 36 00 00 92 21   ���B..�׳..6..�!
    29 50 39 db dc a6 23 02 06 4f 00 c6 f9 ff 00 a6   )P9�ܦ#..O.���.�
    22 02 86 28 00 71 f4 fb e0 20 94 70 22 90 42 12   ".�(.q��� �p"�B.
    bc 00 44 11 40 30 31 96 93 01 40 49 31 0c 13 47   �.D.@01��.@I1..G
    bd 01 0c 03 0c 02 0c 17 40 27 93 37 02 02 46 25   �.......@'�7..F%
    00 86 0b 00 0c a2 d7 b2 29 7c f8 92 a4 b0 00 02   .�...�ײ)|����..
    40 e0 40 91 30 38 db dc 40 40 04 4a 33 9a 33 70   @�@�08��@@.J3�3p
    33 90 32 93 0c d6 f3 06 1b 42 2b 22 27 3d 04 2d   3�2�.��..B+"'=.-
    04 86 f6 ff a7 3c 25 c6 00 00 5d 0b cd 0f 72 21   .����<%�..].�.r!
    25 0c 22 20 27 10 1c 73 8c 12 c6 a3 fd 46 04 00   %." '..s�.ƣ�F..
    a7 bf e6 1b cf 22 0f 00 5d 0b 06 01 00 22 0c 00   ���.�"..]...."..
    1b cc 00 1d 40 00 22 a1 20 ee 20 8b dd 0c e2 d7   .�..@."� � ��.��
    32 02 06 d8 ff c6 07 00 00 32 0c 00 42 0c 01 8b   2..���...2..B..�
    2d 00 1d 40 00 33 a1 00 12 40 00 24 a1 20 23 20   -..@.3�..@.$� #
    e0 e2 20 2b cc d2 cd 10 41 c4 fb e0 20 94 40 22   �� +���.A��� �@"
    90 22 12 bc 00 22 11 20 60 31 96 86 00 20 29 31   �".�.". `1��. )1
    60 60 84 86 09 00 0c a3 7c f7 82 a4 b0 1b 23 00   ``��...�|����.#.
    03 40 e0 30 91 60 67 db dc 30 30 04 3a 66 8a 66   .@�0�`g��00.:f�f
    40 66 90 62 96 0c d6 46 00 3d 02 c6 f7 ff 00 02   @f�b�.�F.=.���..
    40 e0 e0 91 20 dd db dc 22 a0 ff 67 b2 02 46 49   @��� ���"��g�.FI
    00 06 02 00 1c 83 c6 e4 00 5d 0b cd 0f 82 21 29   .....���.].�.�!)
    87 b5 f0 62 45 00 1b 55 86 fd 00 0c e9 d7 39 19   ���bE..U��..��9.
    32 0c 01 22 0c 00 80 33 11 20 23 20 00 1d 40 00   2.."..�3. # ..@.
    22 a1 20 ee 20 2b cc d2 cd 10 32 a0 b0 e0 20 94   "� � +���.2��� �
    41 9e fb 3a 22 40 22 90 22 12 0c 00 22 11 20 30   A��:"@"�"...". 0
    31 20 29 31 d6 a3 02 0c a4 1b 24 7c f6 00 04 40   1 )1֣..�.$|�..@
    e0 40 91 30 36 db dc 40 40 04 4a 33 72 a4 b0 91   �@�06��@@.J3r���
    93 fb 7a 33 90 33 90 32 93 0c d6 53 00 4d 02 c6   ��z3�3�2�.�S.M.�
    f5 ff 00 6d 03 00 02 40 e0 e0 91 20 dd db dc 87   ��.m...@��� ��܇
    03 02 c6 24 00 0c e2 d7 32 19 42 0c 01 22 0c 00   ..�$..��2.B.."..
    80 44 11 20 24 20 00 1d 40 00 22 a1 20 ee 20 2b   �D. $ ..@."� � +
    cc d2 cd 10 42 a0 b0 e0 20 94 71 80 fb 4a 22 70   ���.B��� �q��J"p
    22 90 42 12 0c 00 44 11 40 90 31 92 61 27 40 49   "�B...D.@�1�a'@I
    31 d6 f9 02 0c a7 92 21 27 1b 47 7c f2 00 07 40   1��..��!'.G|�..@
    e0 70 91 90 22 db dc 70 70 04 7a 22 91 74 fb 72   �p��"��pp.z"�t�r
    a4 b0 7a 22 90 22 90 22 92 0c 22 61 27 d6 42 00   ��z"�"�"�."a'�B.
    7d 04 46 f4 ff 22 21 27 32 45 00 00 04 40 e0 e0   }.F��"!'2E...@��
    91 40 dd db dc 87 02 06 1b 55 6d 02 c6 02 00 32   �@��܇...Um.�..2
    21 27 32 45 01 2b 55 06 67 ff 00 60 60 84 66 f6   !'2E.+U.g�.``�f�
    02 46 ba 00 22 ae ff 2a 66 21 7d fb e0 66 11 6a   .F�."��*f!}��f.j
    22 28 02 22 61 24 21 7b fb 6a 62 28 06 62 21 24   "(."a$!{�jb(.b!$
    16 26 06 67 bd 44 6d 02 a7 bc 06 46 08 00 5d 0b   .&.g�Dm.��.F..].
    cd 0f 72 21 25 0c 23 30 37 10 9c a3 1c 93 46 20   �.r!%.#07.��.�F
    fd 00 00 a7 bf e7 1b cf 32 0f 00 5d 0b c6 01 00   �..���.�2..].�..
    32 0c 00 1b cc 46 00 00 2d 06 82 21 24 00 1d 40   2...�F..-.�!$..@
    00 33 a1 8b dd 30 ee 20 87 3d ba 92 21 24 0c 13   .3���0� �=��!$..
    00 19 40 00 33 a1 0b 33 e0 33 10 90 dd db dc 00   ..@.3�.3�3.����.
    09 40 e0 e0 91 3a 22 0c e3 d7 b3 02 c6 34 00 db   .@���:".�׳.�4.�
    dc 3a db dc a6 23 02 c6 2a 00 71 3d fb e0 30 94   �:�ܦ#.�*.q=��0�
    70 33 90 32 d3 0f 62 13 0c 00 66 11 60 40 31 96   p3�2�.b...f.`@1�
    a4 01 60 69 31 0c 14 67 bd 02 42 a0 00 0c 03 0c   �.`i1..g�.B�....
    17 60 37 93 47 03 02 86 26 00 c6 0b 00 0c a3 d7   .`7�G..�&.�...��
    b3 2a 91 4d fb 7c f8 00 03 40 e0 60 91 40 48 db   �*�M�|�..@�`�@H�
    dc 60 60 04 6a 44 9a 44 70 44 90 42 94 0c d6 44   �``.jD�DpD�B�.�D
    07 1b 63 2b 33 37 3d 05 3d 06 86 f6 ff 00 6d 02   ..c+37=.=.���.m.
    a7 bc 06 c6 07 00 5d 0b cd 0f 72 21 25 0c 23 30   ��.�..].�.r!%.#0
    37 10 9c 83 1c a3 46 eb fc a7 bf e9 1b cf 32 0f   7.��.�F�����.�2.
    00 5d 0b c6 01 00 32 0c 00 1b cc 46 00 00 2d 06   .].�..2...�F..-.
    00 1d 40 00 33 a1 30 ee 20 8b dd 0c e3 d7 33 02   ..@.3�0� ��.��3.
    c6 d5 ff c6 07 00 00 32 0c 00 62 0c 01 8b 4d 00   ����...2..b..�M.
    1d 40 00 33 a1 00 14 40 00 46 a1 40 33 20 30 ee   .@.3�..@.F�@3 0�
    20 2b cc d2 cd 10 71 0b fb e0 30 94 70 33 90 32    +���.q.��0�p3�2
    d3 0f 42 13 0c 00 44 11 40 30 31 96 83 00 40 49   �.B...D.@01��.@I
    31 30 30 84 86 09 00 91 20 fb 0c a6 7c f8 1b 46   100��..� �.�|�.F
    00 06 40 e0 60 91 30 38 db dc 60 60 04 6a 33 9a   ..@�`�08��``.j3�
    33 70 33 90 32 93 0c d6 43 00 6d 04 c6 f7 ff 00   3p3�2�.�C.m.���.
    04 40 e0 e0 91 40 dd db dc 41 15 fb e0 33 11 3a   .@���@���A.��3.:
    44 48 04 42 61 24 41 13 fb 82 21 24 3a 34 38 03   DH.Ba$A.��!$:48.
    32 61 26 16 68 06 87 bd 42 6d 02 a7 bc 06 c6 07   2a&.h.��Bm.��.�.
    00 5d 0b cd 0f 92 21 25 0c 23 30 39 10 9c 83 1c   .].�.�!%.#09.��.
    b3 06 b5 fc a7 bf e9 1b cf 32 0f 00 5d 0b c6 01   �.�����.�2..].�.
    00 32 0c 00 1b cc 46 00 00 2d 06 62 21 24 00 1d   .2...�F..-.b!$..
    40 00 33 a1 8b dd 30 ee 20 67 3d bc 72 21 24 0c   @.3���0� g=�r!$.
    13 00 17 40 00 33 a1 82 21 26 0b 33 e0 33 10 3a   ...@.3��!&.3�3.:
    88 00 07 40 e0 e0 91 70 dd db dc 82 61 26 91 dd   �..@���p��܂a&��
    fa 62 21 26 90 95 db dc 72 21 2c 41 da fa 60 39   �b!&����r!,A��`9
    db dc 70 33 10 4a 33 92 61 2a 30 43 20 57 b3 02   ��p3.J3�a*0C W�.
    50 45 20 82 21 29 2a 44 47 38 45 c6 12 00 21 ca   PE �!)*DG8E�..!�
    fa 2c 53 39 62 c6 60 00 3c 53 21 c7 fa 0c 24 39   �,S9b�`.<S!��.$9
    62 46 5f 00 5d 0b cd 0f 92 21 29 97 b5 e9 72 21   bF_.].�.�!)���r!
    2a 82 21 26 92 21 2c 80 27 db dc 31 c7 fa 90 22   *�!&�!,�'��1���"
    10 2a 23 22 02 00 1b 77 22 45 00 72 61 2a 1b 55   .*#"...w"E.ra*.U
    2d 06 0b 62 56 12 fd 46 0d 00 00 42 03 00 62 c2   -..bV.�F...B..b�
    fd 42 45 00 42 03 01 42 45 01 42 03 02 3b 33 42   �BE.B..BE.B..;3B
    45 02 3b 55 a6 36 04 2d 06 86 f7 ff a6 16 10 22   E.;U�6.-.����.."
    03 00 22 45 00 66 26 05 22 03 01 22 45 01 6a 55   .."E.f&.".."E.jU
    82 a1 00 86 aa fe 00 00 21 a8 fa 28 b2 07 e2 02   ��.���..!��(�.�.
    06 6c fc d0 20 24 27 bd 3d a7 3c 27 06 01 00 00   .l�� $'�=�<'....
    5d 0b cd 0f 72 21 25 0c 22 20 27 10 2c 03 8c 12   ].�.r!%." '.,.�.
    46 6a fc 86 04 00 00 a7 bf e5 1b cf 22 0f 00 5d   Fj��...���.�"..]
    0b 06 01 00 22 0c 00 1b cc 00 1d 40 00 22 a1 20   ...."...�..@."�
    ee 20 8b dd c6 ee ff d0 20 24 00 02 40 e0 e0 91   � ������ $..@���
    7c 82 20 dd 10 0c 06 16 dd 04 f6 8d 3e a7 3c 27   |� �....�.��>�<'
    06 01 00 00 5d 0b cd 0f 82 21 25 0c 22 20 28 10   ....].�.�!%." (.
    2c 93 8c 12 46 55 fc 86 04 00 00 a7 bf e5 1b cf   ,��.FU��...���.�
    22 0f 00 5d 0b 06 01 00 22 0c 00 1b cc 00 1d 40   "..]...."...�..@
    00 22 a1 20 ee 20 8b dd 86 ef ff 00 e0 20 74 d2   ."� � �݆��.� t�
    cd f8 e0 e8 41 46 0b 00 a7 3c 25 c6 00 00 5d 0b   ����AF..�<%�..].
    cd 0f 92 21 25 0c 22 20 29 10 2c a3 8c 12 c6 42   �.�!%." ).,��.�B
    fc 46 04 00 a7 bf e6 1b cf 22 0f 00 5d 0b 06 01   �F..���.�"..]...
    00 22 0c 00 1b cc 31 70 fa 1b 66 48 a3 80 44 11   ."...�1p�.fH��D.
    40 22 20 29 a3 f6 46 07 c6 da ff 00 5d 0b cd 0f   @" )��F.���.].�.
    21 6a fa 2c 23 39 62 0c 04 86 01 00 00 5d 0b cd   !j�,#9b..�...].�
    0f 7c f4 21 65 fa 72 21 26 82 21 24 92 21 2a d9   .|�!e�r!&�!$�!*�
    72 e2 62 14 79 e2 69 f2 82 62 10 92 62 15 7c fe   r�b.y�i�b.�b.|�
    f0 dc db dc b0 c5 db dc e7 94 02 c6 40 00 58 d2   ���ܰ����.�@.X�
    31 7b fa 50 e0 f4 2d 0c 50 50 f5 42 61 30 52 61   1{�P��-.PP�Ba0Ra
    34 b2 61 35 01 86 fa db dc 00 00 7d 02 8d 0c 0c   4�a5.����..}.�..
    79 42 21 30 52 21 34 b2 21 35 06 28 00 a2 03 00   yB!0R!4�!5.(.�..
    ea ea a2 03 01 5a 5e aa ee a2 03 02 ea 55 aa ee   ��..Z^��..�U��
    a2 03 03 ea 55 aa ee a2 03 04 ea 55 aa ee a2 03   �..�U��..�U��.
    05 ea 55 aa ee a2 03 06 ea 55 aa ee a2 03 07 ea   .�U��..�U��..�
    55 aa ee ea 55 8b 33 2a a3 77 3a db dc 70 23 41   U���U�3*�w:��p#A
    b0 22 b0 b0 a0 60 06 02 00 32 02 00 1b 22 3a ee   �"���`...2...":�
    ea 55 2a 3a 20 b2 20 77 33 ee 31 5a fa e0 2e 20   �U*: � w3�1Z��.
    42 61 30 72 61 32 82 61 31 92 61 2f b2 61 35 52   Ba0ra2�a1�a/�a5R
    61 34 01 63 fa db dc 00 00 52 21 34 31 52 fa ed   a4.c���..R!41R��
    02 2d 05 01 5f fa db dc 00 00 72 21 32 82 21 31   .-.._���..r!2�!1
    b2 21 35 70 88 db dc 92 21 2f 71 4a fa 42 21 30   �!5p��ܒ!/qJ�B!0
    5d 02 8c 68 3d 0b b0 29 db dc 86 e3 ff 00 55 11   ].�h=.�)�܆��.U.
    21 24 fa ea 55 59 d2 ed 04 dc b4 e8 a2 7c e2 e0   !$��UY��.ܴ�|��
    e5 db dc e0 82 93 ed 08 46 03 00 0c 0c 06 01 00   �������.F.......
    00 00 00 cd 05 dd 0c 7c de 31 3d fa 62 21 2b 28   ...�.�.|�1=�b!+(
    23 d0 66 db dc d0 22 db dc da ff d1 1c fa 29 23   #�f���"�����.�)#
    38 0d 71 1c fa ca c3 70 3c db dc 0c c0            8.q.���p<��.�
                        */
                        ;   38 0d 71 1c fa ca c3 70 3c db dc 0c c0
                        ; and receives:
                        ;   c0 01 07 02 00 bc fa ec 00 00 00 c0               �....���...�

                        ESPSendDataBlock(ESP8266StubText, 0x1800, 0, Err.StubUpload)



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

