%include "abi.inc"
%include "world.inc"
section .text
extern block_flags
; face_neighbor(index,direction)->index, or 4096|neighbor_index for border.
; Directions -X,+X,-Y,+Y,-Z,+Z. Invalid arguments -> -1.
global face_neighbor
face_neighbor:
 cmp A0,4096
 jae .bad
 cmp A1,6
 jae .bad
 mov rax,A0
 cmp A1,0
 je .xm
 cmp A1,1
 je .xp
 cmp A1,2
 je .ym
 cmp A1,3
 je .yp
 cmp A1,4
 je .zm
 test eax,240
 jz .zp_inside ; z=0 is also interior for +z
 mov r10d,eax
 and r10d,240
 cmp r10d,240
 jne .zp_inside
 sub eax,240
 or eax,4096
 ret
.zp_inside:
 add eax,16
 ret
.xm:
 test eax,15
 jnz .xm_inside
 add eax,15
 or eax,4096
 ret
.xm_inside:
 dec eax
 ret
.xp:
 mov r10d,eax
 and r10d,15
 cmp r10d,15
 jne .xp_inside
 sub eax,15
 or eax,4096
 ret
.xp_inside:
 inc eax
 ret
.ym:
 cmp eax,256
 jae .ym_inside
 add eax,3840
 or eax,4096
 ret
.ym_inside:
 sub eax,256
 ret
.yp:
 cmp eax,3840
 jb .yp_inside
 sub eax,3840
 or eax,4096
 ret
.yp_inside:
 add eax,256
 ret
.zm:
 test eax,240
 jnz .zm_inside
 add eax,240
 or eax,4096
 ret
.zm_inside:
 sub eax,16
 ret
.bad:
 mov rax,-1
 ret
; Internal mesh_walk(section,neighbors[6] or NULL,output or NULL).
; Buffers/IDs prevalidated. 8-byte face records: x,y,z,dir,u16 block,u16 zero.
FRAME mesh_walk,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov qword [rsp+56],0
 mov qword [rsp+64],0
.cell:
 mov r10,[rsp+32]
 mov r11,[rsp+56]
 movzx eax,word [r10+r11*2]
 mov [rsp+80],rax
 test eax,eax
 jz .next_cell
 mov qword [rsp+72],0
.face:
 mov A0,[rsp+56]
 mov A1,[rsp+72]
 call face_neighbor
 mov r10,[rsp+32]
 test eax,4096
 jz .read
 mov r10,[rsp+40]
 test r10,r10
 jz .emit
 mov r11,[rsp+72]
 mov r10,[r10+r11*8]
 test r10,r10
 jz .emit
 and eax,4095
.read:
 movzx eax,word [r10+rax*2]
 cmp rax,[rsp+80]
 je .next_face
 mov A0,rax
 call block_flags
 test eax,2
 jnz .next_face
.emit:
 mov r10,[rsp+48]
 test r10,r10
 jz .count
 mov r11,[rsp+64]
 lea r10,[r10+r11*8]
 mov rax,[rsp+56]
 and eax,15
 mov [r10],al
 mov rax,[rsp+56]
 shr eax,8
 mov [r10+1],al
 mov rax,[rsp+56]
 shr eax,4
 and eax,15
 mov [r10+2],al
 mov rax,[rsp+72]
 mov [r10+3],al
 mov rax,[rsp+80]
 mov [r10+4],ax
 mov word [r10+6],0
.count:
 inc qword [rsp+64]
.next_face:
 inc qword [rsp+72]
 cmp qword [rsp+72],6
 jb .face
.next_cell:
 inc qword [rsp+56]
 cmp qword [rsp+56],4096
 jb .cell
 mov rax,[rsp+64]
END_FRAME mesh_walk,88
; mesh_build(section,neighbors[6] or NULL,output or NULL,face_capacity)
; -> count, -1 invalid block IDs, -2 insufficient output capacity.
; Validates every supplied section; errors leave output untouched.
; NULL output is a count query. Inputs must not overlap output or mutate.
FRAME mesh_build,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 mov r10,A0
 mov r11,-1
.validate_buffer:
 xor eax,eax
.validate_cell:
 cmp word [r10+rax*2],BLOCK_COUNT
 jae .bad
 inc eax
 cmp eax,4096
 jb .validate_cell
.next_buffer:
 inc r11
 cmp r11,6
 jae .count
 mov r10,[rsp+40]
 test r10,r10
 jz .count
 mov r10,[r10+r11*8]
 test r10,r10
 jz .next_buffer
 jmp .validate_buffer
.count:
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 xor A2,A2
 call mesh_walk
 cmp qword [rsp+48],0
 je .done
 cmp rax,[rsp+56]
 ja .small
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 call mesh_walk
 jmp .done
.bad:
 mov rax,-1
 jmp .done
.small:
 mov rax,-2
.done:
END_FRAME mesh_build,88
ELF_STACK
