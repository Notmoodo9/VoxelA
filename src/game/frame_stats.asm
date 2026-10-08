%include "abi.inc"
section .text
; FrameStats24: elapsed milliseconds, sample frames, last whole FPS (u64).
; Samples accumulate without clamping stalls; refresh after at least1 second.
global frame_stats_init
frame_stats_init:
 mov qword [A0],0
 mov qword [A0+8],0
 mov qword [A0+16],0
 xor eax,eax
 ret
global frame_stats_step
frame_stats_step:
 mov r10,A0
 mov r11,A1
 mov eax,0xffffffff
 cmp r11,rax
 ja .bad
 cmp [r10+8],rax
 jae .bad
 add [r10],r11
 inc qword [r10+8]
 cmp qword [r10],1000
 jb .done
 mov rax,[r10+8]
 imul rax,1000
 xor edx,edx
 div qword [r10]
 mov [r10+16],rax
 mov qword [r10],0
 mov qword [r10+8],0
.done: xor eax,eax
 ret
.bad: mov rax,-1
 ret
ELF_STACK
