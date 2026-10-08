%include "abi.inc"
%include "world.inc"
section .text
extern fnv1a
; Bounded demo format, not the future region format. Four contiguous sections.
; encode(current[32768], baseline[32768], output, capacity)->bytes or -1 invalid,
; -2 capacity. Disjoint buffers; no output writes on failure.
FRAME snapshot_encode,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 xor r10d,r10d
 xor r11d,r11d
.validate:
 movzx eax,word [A0+r10*2]
 movzx r8d,word [A1+r10*2]
 cmp eax,8
 jae .bad
 cmp r8d,8
 jae .bad
 cmp eax,r8d
 je .next
 ; Bedrock is immutable, even if a caller bypasses normal editing.
 cmp eax,7
 je .bad
 cmp r8d,7
 je .bad
 inc r11
.next:
 inc r10
 cmp r10,16384
 jb .validate
 lea rax,[r11*8+64]
 cmp rax,[rsp+56]
 ja .capacity
 mov [rsp+64],rax
 mov [rsp+72],r11
 mov r10,[rsp+48]
 mov rax,0x004f4d4544415856 ; VXADEMO\0
 mov [r10],rax
 mov dword [r10+8],1 ; format
 mov dword [r10+12],0 ; generator prototype
 mov dword [r10+16],1 ; registry
 mov [r10+20],r11d
 mov qword [r10+24],42 ; demo seed
 shl r11,3
 mov [r10+32],r11
 mov qword [r10+40],0 ; payload checksum filled below
 mov qword [r10+48],0
 mov qword [r10+56],0
 lea r11,[r10+64]
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 xor r10d,r10d
.emit:
 movzx eax,word [A0+r10*2]
 cmp ax,[A1+r10*2]
 je .advance
 mov r8,r10
 shr r8,12
 mov [r11],r8w
 mov r8,r10
 and r8d,4095
 mov [r11+2],r8w
 mov [r11+4],ax
 mov word [r11+6],0
 add r11,8
.advance:
 inc r10
 cmp r10,16384
 jb .emit
 mov A0,[rsp+48]
 add A0,64
 mov A1,[rsp+72]
 shl A1,3
 call fnv1a
 mov r10,[rsp+48]
 mov [r10+40],rax
 mov rax,[rsp+64]
 jmp .done
.capacity:
 mov rax,-2
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME snapshot_encode,88
; decode(bytes,length,baseline[32768],out[32768])->0 or -1 invalid.
; Validate the ENTIRE record before copying; errors preserve output.
FRAME snapshot_decode,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A1,64
 jb .bad
 cmp A1,131136
 ja .bad
 mov rax,0x004f4d4544415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 cmp dword [A0+12],0
 jne .bad
 cmp dword [A0+16],1
 jne .bad
 cmp qword [A0+24],42
 jne .bad
 cmp qword [A0+48],0
 jne .bad
 cmp qword [A0+56],0
 jne .bad
 mov eax,[A0+20]
 cmp eax,16384
 ja .bad
 mov [rsp+64],rax
 shl rax,3
 cmp [A0+32],rax
 jne .bad
 add rax,64
 cmp rax,A1
 jne .bad
 mov A1,[A0+32]
 add A0,64
 call fnv1a
 mov r10,[rsp+32]
 cmp rax,[r10+40]
 jne .bad
 ; Generated baseline must itself contain only registered blocks.
 mov r10,[rsp+48]
 xor ecx,ecx
.base:
 cmp word [r10+rcx*2],8
 jae .bad
 inc ecx
 cmp ecx,16384
 jb .base
 mov r10,[rsp+32]
 add r10,64
 mov r11,[rsp+64]
 xor ecx,ecx
 mov r9,-1 ; previous key, compare signed because first key >=0
.records:
 test r11,r11
 jz .commit
 movzx eax,word [r10]
 cmp eax,4
 jae .bad
 shl eax,12
 movzx r8d,word [r10+2]
 cmp r8d,4096
 jae .bad
 or rax,r8
 cmp rax,r9
 jle .bad
 mov r9,rax
 movzx r8d,word [r10+4]
 cmp r8d,7
 jae .bad
 cmp word [r10+6],0
 jne .bad
 mov rax,[rsp+48]
 cmp word [rax+r9*2],7
 je .bad
 cmp word [rax+r9*2],r8w
 je .bad ; redundant overrides are not canonical
 add r10,8
 dec r11
 jmp .records
.commit:
 mov r10,[rsp+48]
 mov r11,[rsp+56]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,32768
 jb .copy
 mov r10,[rsp+32]
 add r10,64
 mov rcx,[rsp+64]
.apply:
 test rcx,rcx
 jz .success
 movzx eax,word [r10]
 shl eax,12
 movzx r8d,word [r10+2]
 or eax,r8d
 mov r8w,[r10+4]
 mov [r11+rax*2],r8w
 add r10,8
 dec rcx
 jmp .apply
.success:
 xor eax,eax
 jmp .done
.bad:
 mov rax,-1
.done:
END_FRAME snapshot_decode,88
ELF_STACK
