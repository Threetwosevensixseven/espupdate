; stub.asm

LowerCodeStart equ Start        ; This marks the end of the lower 8K of the dot command which is loaded
LowerCodeLen   equ $-Start      ; automatically by NextZXOS. LowerCodeLen should always be smaller than $2000.

align $8000                     ; This section of the file is padded to start 8KB after the dot command and
disp -$4000
UpperCodeStart:                 ; after allocating and paging two new 8K banks from NextZXOS.

zeusprinthex $

ESP8266StubText:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_text.bin"
ESP8266StubTextLen      equ $-1

ESP8266StubData:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_data.bin"
ESP8266StubDataLen      equ $-1

; Anything after here has addresses allocated, but doesn't get appended to the dot command during assembly.
; It does, however, get padded to 24K by AppendFW.exe.

Buffer                  proc
                        ds 1024
  Len                   equ $-Buffer
pend

Header                  proc
  Buffer:               ds 1024
  Len                   equ $-Header
pend

