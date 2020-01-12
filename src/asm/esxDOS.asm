; esxDOS.asm
;
; NOTE: File paths use the slash character ('/') as directory separator (UNIX style)

esxDOS proc

M_GETSETDRV             equ $89
M_P3DOS                 equ $94
F_OPEN                  equ $9a
F_CLOSE                 equ $9b
F_READ                  equ $9d
F_WRITE                 equ $9e
F_SEEK                  equ $9f
F_GET_DIR               equ $a8
F_SET_DIR               equ $a9
F_SYNC                  equ $9c

FA_READ                 equ $01
FA_APPEND               equ $06
FA_OVERWRITE            equ $0C

M_GETHANDLE             equ $8D
M_GETDATE               equ $8E

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
GetHandle:
                        Rst8(esxDOS.M_GETHANDLE)        ; Get handle
                        ld (Handle), a                  ; Save handle
                        ret                             ; Returns a file handler in 'A' register.

; Function:             Read bytes from a file
; In:                   A  = file handle
;                       HL = address to load into (IX for non-dot commands)
;                       BC = number of bytes to read
; Out:                  Carry flag is set if read fails.
fRead:
                        ld a, (Handle)                  ; file handle
                        Rst8(esxDOS.F_READ)             ; read file
                        ret

; Function:             Seek into file
; In:                   A    = file handle
;                       L    = mode:  0 - from start of file
;                                     1 - forward from current position
;                                     2 - back from current position
;                       BCDE = bytes to seek
; Out:                  BCDE = Current file pointer. (*does not return this yet)
;
fSeek:
                        ld a, (Handle)                  ; file handle
                        or a                            ; is it zero?
                        ret z                           ; if so return
                        Rst8(esxDOS.F_SEEK)             ; seek into file
                        ret
pend
