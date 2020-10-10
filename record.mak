record.exe: record.def record.obj
  link386 /a:16 /map /nod /nos record,record.exe,,mmpm2+os2,record

record.obj: record.asm record.mak
  tasm /la /m /oi record.asm,record.obj
