%include "abi.inc"
section .text
extern settings_valid, fnv1a
; Preferences64: magic8,version u32,size u32,payload checksum u64,reserved u64,
; six persisted settings u32,quality u32,far radius u32. Flight/latch excluded.
FRAME preferences_encode,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,2
 ja .bad
 cmp A2,2
 jb .bad
 cmp A2,256
 ja .bad
 call settings_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+56]
 mov rax,0x5346455250415856 ; VXAPREFS
 mov [r10],rax
 mov dword [r10+8],1
 mov dword [r10+12],64
 mov qword [r10+24],0
 mov r11,[rsp+32]
 movups xmm0,[r11]
 movups [r10+32],xmm0
 mov rax,[r11+16]
 mov [r10+48],rax
 mov eax,[rsp+40]
 mov [r10+56],eax
 mov eax,[rsp+48]
 mov [r10+60],eax
 lea A0,[r10+32]
 mov A1,32
 call fnv1a
 mov r10,[rsp+56]
 mov [r10+16],rax
 mov eax,64
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME preferences_encode,88
; decode(bytes,length,Settings32*,visual8*)->0/-1; staged atomic outputs.
FRAME preferences_decode,120
 mov [rsp+32],A0
 mov [rsp+40],A2
 mov [rsp+48],A3
 cmp A1,64
 jne .bad
 mov rax,0x5346455250415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 cmp dword [A0+12],64
 jne .bad
 cmp qword [A0+24],0
 jne .bad
 cmp dword [A0+56],2
 ja .bad
 cmp dword [A0+60],2
 jb .bad
 cmp dword [A0+60],256
 ja .bad
 add A0,32
 mov A1,32
 call fnv1a
 mov r10,[rsp+32]
 cmp rax,[r10+16]
 jne .bad
 movups xmm0,[r10+32]
 movups [rsp+64],xmm0
 mov rax,[r10+48]
 mov [rsp+80],rax
 mov qword [rsp+88],0
 lea A0,[rsp+64]
 call settings_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+40]
 movups xmm0,[rsp+64]
 movups xmm1,[rsp+80]
 movups [r10],xmm0
 movups [r10+16],xmm1
 mov r10,[rsp+32]
 mov rax,[r10+56]
 mov r10,[rsp+48]
 mov [r10],rax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME preferences_decode,120
ELF_STACK
