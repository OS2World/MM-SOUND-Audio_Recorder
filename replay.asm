.486p
model flat
ideal

Adapter = 3 ; 1,2,3

BitsPerSample = 32; 8,16,24,32
Channels = 2 ; 1=mono,2=stereo
FormatTag = 1 ; 1=PCM,301h=DSD
SamplesPerSec = 192000; 44100,48000,88200,96000,176400,192000,352800,384000 Hz

extrn DosClose:near
extrn DosCloseEventSem:near
extrn DosCreateEventSem:near
extrn DosExit:near
extrn DosExitList:near
extrn DosOpen:near
extrn DosPostEventSem:near
extrn DosRead:near
extrn DosResetEventSem:near
extrn DosSleep:near
extrn DosWaitEventSem:near
extrn DosWrite:near

extrn MciGetErrorString:near
extrn MciSendCommand:near

stack 8192

dataseg
szInput db 'test.wav',0

BufferSize = 0
NumBuffers = 8

dataseg
AmpMixer db 'Ampmix0','0'+Adapter,0
AmpOpenParms dd 0,0,offset(AmpMixer),0,0,0
MixerAllocParms dd 0,32,NumBuffers,BufferSize,0,0,0,offset(MixerBuffer1)
MixerSetupParms dd 0,BitsPerSample,FormatTag,SamplesPerSec,Channels,4,7,0,0,0,offset(SoundMixerEvent),0,BufferSize,NumBuffers

dataseg
FreeBuffers dd NumBuffers
MixerBuffer1 dd 0,0,0,0,offset(MixerBuffer2),0,0,0
MixerBuffer2 dd 0,0,0,0,offset(MixerBuffer3),0,0,0
MixerBuffer3 dd 0,0,0,0,offset(MixerBuffer4),0,0,0
MixerBuffer4 dd 0,0,0,0,offset(MixerBuffer5),0,0,0
MixerBuffer5 dd 0,0,0,0,offset(MixerBuffer6),0,0,0
MixerBuffer6 dd 0,0,0,0,offset(MixerBuffer7),0,0,0
MixerBuffer7 dd 0,0,0,0,offset(MixerBuffer8),0,0,0
MixerBuffer8 dd 0,0,0,0,offset(MixerBuffer1),0,0,0
MixerBuffer dd offset(MixerBuffer1)

udataseg
DartSem dd ?
FreeCnt dd ?
MciMessage db 128 dup(?)
Written dd ?

dataseg
sGood0 db 'started.',13,10
sGood1 db 'stopped.',13,10
sGood2 db 'waiting...',13,10
label sGood3 byte

dataseg
sInfo0 db ' opening ampmixer device',13,10
sInfo1 db ' informing dart being used',13,10
sInfo2 db ' allocating dart buffers',13,10
sInfo3 db ' creating event semaphore',13,10
sInfo4 db ' closing event semaphore',13,10
sInfo5 db ' deallocating dart buffers',13,10
sInfo6 db ' informing dart use ended',13,10
sInfo7 db ' closing ampmixer device',13,10
label sInfo8 byte

dataseg
sTest0 db ' opening audio input file',13,10
sTest1 db ' reading audio input file',13,10
sTest2 db ' closing audio input file',13,10
label sTest3 byte

udataseg
AudioHeader db 44 dup(?)

udataseg
ActionTaken dd ?
BytesDone dd ?
BytesRead dd ?
fhDevice dd ?
fhInput dd ?

codeseg
proc MainRoutine c near
arg @@Mod,@@Nul,@@Env,@@Arg
; determine begin of arguments
  cld ; operate foreward scan
  mov ecx,512 ; max scan length
  mov edi,[@@Arg] ; start address
  repne scasb ; find terminator
; process passed arguments
  call ProcessArguments
; show application started message
  call DosWrite c,1,offset(sGood0),sGood1-sGood0,offset(BytesDone)
; initialize sound device
  call SoundDeviceInit
; open pcm audio data input file
  call DosWrite c,1,offset(sTest0),sTest1-sTest0,offset(BytesDone)
  call DosOpen c,offset(szInput),offset(fhInput),offset(ActionTaken),0,0,1,01A0h,0
  call ShowReturnCode
  jnz NotReplaySound
; register termination processing;
  call DosExitList c,1,offset(ProcessComplete)
; invoke sound processing
  call SoundProcessing
; force process complete
  sub eax,eax ; success
  ret ; uses exit list
label NotReplaySound near
; finalize sound device
  call SoundDeviceExit
; show application stopped message
  call DosWrite c,1,offset(sGood1),10,offset(BytesDone)
; exit the program
  call DosExit c,1,0
endp MainRoutine

codeseg
proc dec2bin near
; decimal to binary
  sub eax,eax ; input
  sub edx,edx ; output
label ConvertInput near
  inc edi ; next position
  mov al,[edi] ; digit
; convert decimal digit
  cmp al,'0' ; minimum
  jb Enddec2bin ; done
  cmp al,'9' ; maximum
  ja Enddec2bin ; done
  sub al,'0' ; digit
  lea edx,[edx*4+edx]
  lea edx,[edx*2+eax]
  jmp ConvertInput
label Enddec2bin Near
  ret ; return
endp dec2bin

codeseg
proc ProcessArguments near
; scan for forward slash
  mov al,[edi] ; character
  inc edi ; next position
  cmp al,00h ; terminator
  je EndScanString ; done
  cmp al,'/' ; parameter
  jne ProcessArguments
; adapter number
  cmp [byte(edi)],'a'
  jne NotAdapter
  call dec2bin ; convert
; verify adapter number
  cmp edx,8 ; maximum
  ja ProcessArguments
; update adapter number
  add dl,"0" ; ascii
  mov [AmpMixer+7],dl
  jmp ProcessArguments
label NotAdapter near
; bits per sample
  cmp [byte(edi)],'b'
  jne NotBits
  call dec2bin ; convert
; store BitsPerSample value
  mov [MixerSetupParms+04],edx
  jmp ProcessArguments
label NotBits near
; channels argument
  cmp [byte(edi)],'c'
  jne NotChannels
  call dec2bin ; convert
; store Channels value
  mov [MixerSetupParms+16],edx
  jmp ProcessArguments
label NotChannels near
; frequency argument
  cmp [byte(edi)],'f'
  jne NotFrequency
  call dec2bin ; convert
; store SamplesPerSec value
  mov [MixerSetupParms+12],edx
  jmp ProcessArguments
label NotFrequency near
  jmp ProcessArguments
label EndScanString near
; skip sanity checks
  ret ; return
endp ProcessArguments

codeseg
proc ProcessComplete c near
arg @@ReasonCode
; report reason code
; mov eax,[@@ReasonCode]
; call ShowReturnCode
label CloseAudioRecordFile near
; close pcm audio data input file
  call DosWrite c,1,offset(sTest2),sTest3-sTest2,offset(BytesDone)
  call DosClose c,[fhInput]
  call ShowReturnCode
; finalize sound device
  call SoundDeviceExit
; show application stopped message
  call DosWrite c,1,offset(sGood1),10,offset(BytesDone)
; exit termination process
  call DosExitList c,3,0)
  endp ProcessComplete

codeseg
proc ShowMultimediaMessage near
  test eax,eax ; skip success
  jz EndShowMultimediaMessage
  call MciGetErrorString c,eax,offset(MciMessage),80
  call DosWrite c,1,offset(MciMessage),80,offset(Written)
label EndShowMultimediaMessage near
  ret ; return
endp ShowMultimediaMessage

dataseg
hex2ascii db '0123456789ABCDEF'
szStatus db '[????????]',13,10

codeseg
proc ShowReturnCode near
; skip zero return code
  test eax,eax ; zero
  jz EndShowCode ; done
  push eax ; save register
; convert return code
  mov ecx,8 ; code length
label ConvertDigit near
  mov edx,eax ; error code
  and edx,0000000Fh ; digit
  mov dl,[hex2ascii+edx]
  mov [szStatus+ecx],dl
  shr eax,4 ; next one
  loop ConvertDigit
; show appropriate info message
  call DosWrite c,1,offset(szStatus),12,offset(BytesDone)
  pop eax ; restore register
  test eax,eax ; check
label EndShowCode near
  ret ; return
endp ShowReturnCode

codeseg
public SoundDeviceExit
proc SoundDeviceExit near
; close dart event semaphore
  call DosWrite c,1,offset(sInfo4),sInfo5-sInfo4,offset(BytesDone)
  call DosCloseEventSem c,[DartSem]
; deallocate dart communication buffers and wait
; 62=MCI_BUFFER,80002h=MCI_DEALLOCATE_MEMORY+MCI_WAIT
  call DosWrite c,1,offset(sInfo5),sInfo6-sInfo5,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],62,80002h,offset(MixerAllocParms),0
  call ShowMultimediaMessage
; inform ampmixer that dart is no longer used and wait
; 63=MCI_MIXSETUP,20002h=MCI_MIXSETUP_DEINIT+MCI_WAIT
  call DosWrite c,1,offset(sInfo6),sInfo7-sInfo6,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],63,20002h,offset(MixerSetupParms),0
  call ShowMultimediaMessage
; close the waveaudio device and wait
; 02=MCI_CLOSE,00002h=MCI_WAIT
  call DosWrite c,1,offset(sInfo7),sInfo8-sInfo7,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],02,00002h,offset(AmpOpenParms),0
  call ShowMultimediaMessage
  ret ; return
endp SoundDeviceExit

codeseg
public SoundDeviceInit
proc SoundDeviceInit near
; open the ampmixer device shared and wait
; 01=MCI_OPEN,02002h=MCI_OPEN_TYPE_ID+MCI_WAIT
  call DosWrite c,1,offset(sInfo0),sInfo1-sInfo0,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],01,02002h,offset(AmpOpenParms),0
  test eax,eax ; any error
  jnz MultimediaMessage
; inform ampmixer that dart is used and wait
; 63=MCI_MIXSETUP,10002h=MCI_MIXSETUP_INIT+MCI_WAIT
  call DosWrite c,1,offset(sInfo1),sInfo2-sInfo1,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],63,10002h,offset(MixerSetupParms),0
  test eax,eax ; any error
  jnz MultimediaMessage
; use recommended BufferSize
  mov eax,[MixerSetupParms+12*4]
  mov [MixerAllocParms+3*4],eax
; use recommended NumBuffers
; mov eax,[MixerSetupParms+13*4]
; mov [MixerAllocParms+2*4],eax
; allocate dart communication buffers and wait
; 62=MCI_BUFFER,40002h=MCI_ALLOCATE_MEMORY+MCI_WAIT
  call DosWrite c,1,offset(sInfo2),sInfo3-sInfo2,offset(BytesDone)
  call MciSendCommand c,[AmpOpenParms+04h],62,40002h,offset(MixerAllocParms),0
  test eax,eax ; any error
  jnz MultimediaMessage
; create dart event semaphore
  call DosWrite c,1,offset(sInfo3),sInfo4-sInfo3,offset(BytesDone)
  call DosCreateEventSem c,0,offset(DartSem),1,0
  ret ; return
label MultimediaMessage near
; write multimedia error message
  call ShowMultimediaMessage
; exit the program
  call DosExit c,1,0
endp SoundDeviceInit

codeseg
proc SoundMixerEvent c near
arg @@Status,@@Buffer,@@Flags
; handle write complete condition
; cmp [@@Flags],02h ; write complete
; jne EndSoundMixerEvent ; other
; report mixer write completion
  call DosPostEventSem c,[DartSem]
label EndSoundMixerEvent near
  ret ; return
endp SoundMixerEvent

codeseg
proc SoundProcessing near
; read riff/wave audio file header
  call DosWrite c,1,offset(sTest1),sTest2-sTest1,offset(BytesDone)
  call DosRead c,[fhInput],offset(AudioHeader),44,offset(BytesDone)
  call ShowReturnCode
  jnz EndReplaySound
label MixerBufferProcess near
; call DosWrite c,1,offset(sTest1),sTest2-sTest1,offset(BytesDone)
; address first sample position
  mov eax,[MixerBuffer] ; current
  mov eax,[eax+4] ; buffer pointer
; read pcm audio input data into buffer
  call DosRead c,[fhInput],eax,[MixerAllocParms+12],offset(BytesRead)
  call ShowReturnCode
  jnz EndReplaySound
  cmp [BytesRead],eax
  jna EndReplaySound ; stop
; write this filled mixer buffer
; 32=pmixWrite(PMIXERPROC) entry point
  call [MixerSetupParms+32] c,[MixerSetupParms+28],[MixerBuffer],1
  dec [FreeBuffers] ; buffer used
label UpdateCurrentFreeBuffers near
; update currently available mixer buffers
  call DosResetEventSem c,[DartSem],offset(FreeCnt)
  mov eax,[FreeCnt] ; buffers freed
  add [FreeBuffers],eax ; current
  jnz FillMixerBuffer ; available
; show application waiting message
; call DosWrite c,1,offset(sGood2),sGood3-sGood2,offset(BytesDone)
; await 2 seconds mixer buffer available
  call DosWaitEventSem c,[DartSem],2000
  call ShowReturnCode
  jnz EndReplaySound
  jmp UpdateCurrentFreeBuffers
label FillMixerBuffer near
; address next mixer buffer
  mov eax,[MixerBuffer] ; last
  mov eax,[eax+16] ; user parms
  mov [MixerBuffer],eax ; next
  jmp MixerBufferProcess
label EndReplaySound near
; hang in here for 3 seconds
  call DosSleep c,3000
  ret ; return
endp SoundProcessing

end MainRoutine
