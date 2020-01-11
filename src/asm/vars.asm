; vars.asm

Buffer:                 ds 1024
BufferLen               equ $-Buffer
Dummy32:                ds 4
eFuses:
eFuse1:                 ds 4
eFuse2:                 ds 4
eFuse3:                 ds 4
eFuse4:                 ds 4

Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

