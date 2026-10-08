%include "abi.inc"
section .text
extern generate_section, generate_section1, malloc, free
%define SIZE 131264
; Region131264: seed0, RX8,RZ16,SY24,mask32,revision40,magic48,
; runtime checksum0 at56; Meta8[16] at64; Section8192[16] at192.
; Regions span4x4 section columns and one vertical section. Single owner.
FRAME region_init,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov r10,[A1+8]
 cmp r10,-468750
 jl .bad
 cmp r10,468750
 jge .bad
 mov r10,[A1+16]
 cmp r10,-468750
 jl .bad
 cmp r10,468750
 jge .bad
 mov r10,[A1+24]
 cmp r10,-16
 jl .bad
 cmp r10,48
 jge .bad
 mov r10,A0
 xor ecx,ecx
.clear:
 mov qword [r10+rcx],0
 add ecx,8
 cmp ecx,SIZE
 jb .clear
 mov r11,[rsp+40]
 movups xmm0,[r11]
 movups xmm1,[r11+16]
 movups [r10],xmm0
 movups [r10+16],xmm1
 mov rax,0x3130474552415856 ; VXAREG01
 mov [r10+48],rax
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_init,72
global region_valid
region_valid:
 mov r10,A0
 mov rax,0x3130474552415856
 cmp [r10+48],rax
 jne .bad
 cmp qword [r10+56],0
 jne .bad
 cmp qword [r10+8],-468750
 jl .bad
 cmp qword [r10+8],468750
 jge .bad
 cmp qword [r10+16],-468750
 jl .bad
 cmp qword [r10+16],468750
 jge .bad
 cmp qword [r10+24],-16
 jl .bad
 cmp qword [r10+24],48
 jge .bad
 cmp qword [r10+32],65535
 ja .bad
 cmp qword [r10+40],0
 jl .bad
 xor ecx,ecx
.slot:
 mov r11,rcx
 shl r11,13
 lea r11,[r10+192+r11]
 bt qword [r10+32],rcx
 jc .occupied
 cmp qword [r10+64+rcx*8],0
 jne .bad
 xor edx,edx
.empty:
 cmp qword [r11+rdx],0
 jne .bad
 add edx,8
 cmp edx,8192
 jb .empty
 jmp .next
.occupied:
 cmp dword [r10+64+rcx*8],1
 ja .bad
 cmp dword [r10+68+rcx*8],0
 jne .bad
 cmp dword [r10+64+rcx*8],0
 jne .cells
 cmp qword [r10+24],0
 jl .bad
 cmp qword [r10+24],16
 jge .bad
.cells:
 xor edx,edx
.cell:
 movzx eax,word [r11+rdx*2]
 cmp eax,7
 ja .bad
 mov r8,[r10+24]
 mov r9,-16
 cmp dword [r10+64+rcx*8],1
 je .floor
 xor r9d,r9d
.floor:
 cmp r8,r9
 jne .nonfloor
 cmp edx,256
 jae .nonfloor
 cmp eax,7
 jne .bad
 jmp .cell_next
.nonfloor:
 cmp eax,7
 je .bad
.cell_next:
 inc edx
 cmp edx,4096
 jb .cell
.next:
 inc ecx
 cmp ecx,16
 jb .slot
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
FRAME region_generate,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,16
 jae .bad
 cmp A2,1
 ja .bad
 call region_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 bt qword [r10+32],rcx
 jc .exists
 mov rax,0x7fffffffffffffff
 cmp [r10+40],rax
 je .bad
 cmp qword [rsp+48],0
 jne .allocate
 cmp qword [r10+24],0
 jl .bad
 cmp qword [r10+24],16
 jge .bad
.allocate:
 mov A0,8192
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+56],rax
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 mov rax,[r10+8]
 shl rax,2
 mov r11,rcx
 and r11d,3
 add rax,r11
 mov [rsp+64],rax
 mov rax,[r10+24]
 mov [rsp+72],rax
 mov rax,[r10+16]
 shl rax,2
 shr rcx,2
 add rax,rcx
 mov [rsp+80],rax
 mov A0,[rsp+56]
 mov A1,[r10]
 lea A2,[rsp+64]
 cmp qword [rsp+48],0
 jne .new
 call generate_section
 jmp .generated
.new: call generate_section1
.generated:
 mov [rsp+88],rax
 test rax,rax
 jnz .release
 mov r10,[rsp+32]
 mov rcx,[rsp+40]
 mov r11,rcx
 shl r11,13
 lea r11,[r10+192+r11]
 mov r8,[rsp+56]
 xor edx,edx
.copy:
 mov rax,[r8+rdx]
 mov [r11+rdx],rax
 add edx,8
 cmp edx,8192
 jb .copy
 mov eax,[rsp+48]
 mov [r10+64+rcx*8],eax
 bts qword [r10+32],rcx
 inc qword [r10+40]
 mov qword [rsp+88],1
.release:
 mov A0,[rsp+56]
 CCALL free
 mov rax,[rsp+88]
 jmp .done
.exists: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_generate,120
; Resolve global coordinates to a cell pointer; caller owns canonical region.
; Internal result pointer, -1 invalid/outside,-2 unrecorded.
region_cell:
 mov r10,[A1]
 cmp r10,-30000000
 jl .bad
 cmp r10,30000000
 jge .bad
 sar r10,6
 cmp r10,[A0+8]
 jne .bad
 mov r10,[A1+16]
 cmp r10,-30000000
 jl .bad
 cmp r10,30000000
 jge .bad
 sar r10,6
 cmp r10,[A0+16]
 jne .bad
 mov r10,[A1+8]
 cmp r10,-256
 jl .bad
 cmp r10,768
 jge .bad
 sar r10,4
 cmp r10,[A0+24]
 jne .bad
 mov r10,[A1]
 sar r10,4
 and r10d,3
 mov r11,[A1+16]
 sar r11,4
 and r11d,3
 shl r11,2
 add r10,r11
 bt qword [A0+32],r10
 jnc .absent
 shl r10,13
 lea rax,[A0+192+r10]
 mov r10,[A1+8]
 and r10d,15
 shl r10,8
 mov r11,[A1+16]
 and r11d,15
 shl r11,4
 add r10,r11
 mov r11,[A1]
 and r11d,15
 add r10,r11
 lea rax,[rax+r10*2]
 ret
.absent: mov rax,-2
 ret
.bad: mov rax,-1
 ret
FRAME region_get,40
 call region_cell
 test rax,rax
 js .done
 movzx eax,word [rax]
.done:
END_FRAME region_get,40
FRAME region_edit,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A2,6
 ja .bad
 call region_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call region_cell
 test rax,rax
 js .done
 cmp word [rax],7
 je .bad
 mov r10,[rsp+48]
 cmp word [rax],r10w
 je .same
 mov r11,[rsp+32]
 mov rdx,0x7fffffffffffffff
 cmp [r11+40],rdx
 je .bad
 mov [rax],r10w
 inc qword [r11+40]
 mov eax,1
 jmp .done
.same: xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_edit,72
; Wire checksum treats bytes56..63 as zero; source immutable.
global region_checksum
region_checksum:
 mov r10,A0
 mov rax,0xcbf29ce484222325
 mov r11,0x100000001b3
 xor ecx,ecx
.byte:
 xor edx,edx
 cmp ecx,56
 jb .read
 cmp ecx,64
 jb .hash
.read: mov dl,[r10+rcx]
.hash:
 xor rax,rdx
 imul rax,r11
 inc ecx
 cmp ecx,SIZE
 jb .byte
 ret
FRAME region_encode,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 call region_valid
 test rax,rax
 jnz .bad
 cmp qword [rsp+48],SIZE
 jb .small
 mov r10,[rsp+32]
 mov r11,[rsp+40]
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,SIZE
 jb .copy
 mov A0,r11
 call region_checksum
 mov r10,[rsp+40]
 mov [r10+56],rax
 mov eax,SIZE
 jmp .done
.small: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_encode,72
FRAME region_decode,88
 mov [rsp+32],A0
 mov [rsp+40],A2
 cmp A1,SIZE
 jne .bad
 call region_checksum
 mov r10,[rsp+32]
 cmp rax,[r10+56]
 jne .bad
 mov A0,SIZE
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+48],rax
 mov r11,rax
 mov r10,[rsp+32]
 xor ecx,ecx
.stage:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,SIZE
 jb .stage
 mov qword [r11+56],0
 mov A0,r11
 call region_valid
 mov [rsp+56],rax
 test rax,rax
 jnz .release
 mov r10,[rsp+48]
 mov r11,[rsp+40]
 xor ecx,ecx
.commit:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,SIZE
 jb .commit
.release:
 mov A0,[rsp+48]
 CCALL free
 mov rax,[rsp+56]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_decode,88
ELF_STACK
