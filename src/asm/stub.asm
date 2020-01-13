; stub.asm

LowerCodeStart equ Start        ; This marks the end of the lower 8K of the dot command which is loaded
LowerCodeLen   equ $-Start      ; automatically by NextZXOS. LowerCodeLen should always be smaller than $2000.

align $2000                     ; This section of the file is padded to start 8KB after the dot command and
org $8000                       ; will org at $8000, but is displaced to assemble straight after the lower 8K
disp -$4000                     ; of the dot command/

UpperCodeStart:                 ; after allocating and paging two new 8K banks from NextZXOS.

Buffer                  proc
                        ds 1024
  Len                   equ $-Buffer
pend

ESP8266StubText:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_text.bin"
ESP8266StubTextLen      equ $-1

ESP8266StubData:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_data.bin"
ESP8266StubDataLen      equ $-1

