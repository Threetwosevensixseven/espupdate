; vars.asm

Buffer:                 ds 1024
BufferLen               equ $-Buffer
Dummy32:                ds 4
eFuses:
eFuse1:                 ds 4
eFuse2:                 ds 4
eFuse3:                 ds 4
eFuse4:                 ds 4
MAC0:                   ds 4
MAC1:                   ds 4
MAC3:                   ds 4
MAC:
OUI1:                   ds 1
OUI2:                   ds 1
OUI3:                   ds 1
OUI4:                   ds 1
OUI5:                   ds 1
OUI6:                   ds 1

Features                proc
  Is8285:               ds 1
  EmbFlash:             ds 1
pend

