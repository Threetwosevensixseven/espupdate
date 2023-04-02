; esxDOS.asm

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

; NOTE: File paths use the slash character ('/') as directory separator (UNIX style)

esxDOS proc

M_DOSVERSION            equ $88
M_GETSETDRV             equ $89
M_P3DOS                 equ $94
M_GETHANDLE             equ $8D
M_GETDATE               equ $8E
M_ERRH                  equ $95

F_OPEN                  equ $9A
F_CLOSE                 equ $9B
F_SYNC                  equ $9C
F_READ                  equ $9D
F_WRITE                 equ $9E
F_SEEK                  equ $9F
F_GET_DIR               equ $A8
F_SET_DIR               equ $A9

FA_READ                 equ $01
FA_APPEND               equ $06
FA_OVERWRITE            equ $0C

esx_seek_set            equ $00         ; set the fileposition to BCDE
esx_seek_fwd            equ $01         ; add BCDE to the fileposition
esx_seek_bwd            equ $02         ; subtract BCDE from the fileposition

DefaultDrive            db 0
Handle                  db 255

; Function:             Get the file handle of the currently running dot command
; In:                   None
; Out:                  A     = file handle
;                       Carry = clear
; Notes:                This call allows dot commands which are >8K to read further data direct
;                       from their own file (for loading into another memory area, or overlaying
;                       as required into the normal 8K dot command area currently in use).
;                       On entry to a dot command, the file is left open with the file pointer
;                       positioned directly after the first 8K.
;                       This call returns meaningless results if not called from a dot command.
GetHandle:              Rst8(esxDOS.M_GETHANDLE)        ; Get handle
                        ld (Handle), a                  ; Save handle
                        ret                             ; Returns a file handler in 'A' register.

; Function:             Open file
; In:                   HL = pointer to file name (ASCIIZ) (IX for non-dot commands)
;                       B  = open mode
;                       A  = Drive
; Out:                  A  = file handle
;                       On error: Carry set
;                         A = 5   File not found
;                         A = 7   Name error - not 8.3?
;                         A = 11  Drive not found
;
fOpen:                  ld a, '*'                       ; get drive we're on
                        ld b, FA_READ                   ; b = open mode
                        Rst8(esxDOS.F_OPEN)             ; open read mode
                        ld (Handle), a
                        ret                             ; Returns a file handler in 'A' register.

; Function:             Read bytes from a file
; In:                   A  = file handle
;                       HL = address to load into (IX for non-dot commands)
;                       BC = number of bytes to read
; Out:                  Carry flag is set if read fails.
;
fRead:                  ld a, (Handle)                  ; file handle
                        Rst8(esxDOS.F_READ)             ; read file
                        ret

; Function:             Close file
; In:                   A  = file handle
; Out:                  Carry flag active if error when closing
;
fClose:                 ld a, (Handle)
                        Rst8(esxDOS.F_CLOSE)            ; close file
                        ret

; Function:             Seek into file
; In:                   A    = file handle
;                       L    = mode:  0 - from start of file
;                                     1 - forward from current position
;                                     2 - back from current position
;                       BCDE = bytes to seek
; Out:                  BCDE = Current file pointer. (*does not return this yet)
;
/*fSeek:                ld a, (Handle)                  ; file handle
                        or a                            ; is it zero?
                        ret z                           ; if so return
                        Rst8(esxDOS.F_SEEK)             ; seek into file
                        ret
pend*/

