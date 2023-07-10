; stub.asm

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

LowerCodeStart equ Start        ; This marks the end of the lower 8K of the dot command which is loaded
LowerCodeLen   equ $-Start      ; automatically by NextZXOS. LowerCodeLen should always be smaller than $2000.

align $8000                     ; This section of the file is padded to start 8KB after the dot command and
disp -$4000
UpperCodeStart:                 ; after allocating and paging two new 8K banks from NextZXOS.

ESP8266StubText:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_text.bin"
ESP8266StubTextLen      equ $-1

ESP8266StubData:
import_bin              "..\\..\\fw\\ESP8266_FULL_V3.3_SPUGS\\ESP8266_stub_data.bin"
ESP8266StubDataLen      equ $-1

//EndOfUpperCode = $

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

//org EndOfUpperCode

