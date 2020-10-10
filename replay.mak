replay.exe: replay.def replay.obj
  link386 /a:16 /map /nod /nos replay,replay.exe,,mmpm2+os2,replay

replay.obj: replay.asm replay.mak
  tasm /la /m /oi replay.asm,replay.obj
