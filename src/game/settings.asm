%include "abi.inc"
section .text
extern tanf
; Settings32: u32 vertical FOV,sensitivity%,invert,toggleSprint,coords,
; flightSpeed%,flightActive,sprintLatched. Last two are transient gameplay state.
global settings_init
settings_init:
 mov dword [A0],95
 mov dword [A0+4],100
 mov qword [A0+8],0
 mov dword [A0+16],0
 mov dword [A0+20],100
 mov qword [A0+24],0
 xor eax,eax
 ret
global settings_valid
settings_valid:
 cmp dword [A0],60
 jb .bad
 cmp dword [A0],110
 ja .bad
 cmp dword [A0+4],10
 jb .bad
 cmp dword [A0+4],300
 ja .bad
 cmp dword [A0+20],25
 jb .bad
 cmp dword [A0+20],400
 ja .bad
 cmp dword [A0+8],1
 ja .bad
 cmp dword [A0+12],1
 ja .bad
 cmp dword [A0+16],1
 ja .bad
 cmp dword [A0+24],1
 ja .bad
 cmp dword [A0+28],1
 ja .bad
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
FRAME settings_set,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,6
 jae .bad
 call settings_valid
 test rax,rax
 jnz .bad
 mov rcx,[rsp+40]
 mov rdx,[rsp+48]
 lea r10,[minimum]
 cmp rdx,[r10+rcx*8]
 jb .bad
 lea r10,[maximum]
 cmp rdx,[r10+rcx*8]
 ja .bad
 mov r10,[rsp+32]
 mov [r10+rcx*4],edx
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME settings_set,56
FRAME settings_lens,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call settings_valid
 test rax,rax
 jnz .done
 mov r10,[rsp+32]
 cvtsi2ss xmm0,dword [r10]
 mulss xmm0,[half_radians]
 CCALL tanf
 movss xmm1,[one]
 divss xmm1,xmm0
 mov r10,[rsp+40]
 movss [r10],xmm1
 xor eax,eax
.done:
END_FRAME settings_lens,56
; settings_mouse(state,dx,dy,outI64[2]); bounds±1000, scale/truncate/clamp±1000.
FRAME settings_mouse,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 call settings_valid
 test rax,rax
 jnz .bad
 mov qword [rsp+64],0
.loop:
 mov rcx,[rsp+64]
 mov rax,[rsp+40+rcx*8]
 cmp rax,-1000
 jl .bad
 cmp rax,1000
 jg .bad
 mov r10,[rsp+32]
 mov ecx,[r10+4]
 imul rax,rcx
 cqo
 mov ecx,100
 idiv rcx
 mov r10,-1000
 cmp rax,r10
 cmovl rax,r10
 mov r10,1000
 cmp rax,r10
 cmovg rax,r10
 mov rcx,[rsp+64]
 mov [rsp+72+rcx*8],rax
 inc qword [rsp+64]
 cmp qword [rsp+64],2
 jb .loop
 mov r10,[rsp+32]
 cmp dword [r10+8],0
 je .commit
 neg qword [rsp+80]
.commit:
 mov r10,[rsp+56]
 mov rax,[rsp+72]
 mov [r10],rax
 mov rax,[rsp+80]
 mov [r10+8],rax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME settings_mouse,88
section .rdata align=8
minimum: dq 60,10,0,0,0,25
maximum: dq 110,300,1,1,1,400
half_radians: dd 0.00872664626
one: dd 1.0
ELF_STACK
