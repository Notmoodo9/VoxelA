%include "abi.inc"
section .text
extern terrain1_column, generated_block1, region_valid, malloc, free
; legacy_edge_profile(sectionPointers16*,face0..3,outI32[16])->0/-1.
; Ordered SY0..15, canonical generator0 sections; faces west/east/north/south.
; Validate all blocks before output. Highest nonair includes recorded edits.
FRAME legacy_edge_profile,136
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,4
 jae .bad
 xor r8d,r8d
.validate_section:
 mov r10,[rsp+32]
 mov r11,[r10+r8*8]
 test r11,r11
 jz .bad
 xor ecx,ecx
.validate_cell:
 movzx eax,word [r11+rcx*2]
 cmp eax,7
 ja .bad
 test r8,r8
 jnz .not_floor
 cmp ecx,256
 jae .not_floor
 cmp eax,7
 jne .bad
 jmp .valid
.not_floor:
 cmp eax,7
 je .bad
.valid:
 inc ecx
 cmp ecx,4096
 jb .validate_cell
 inc r8
 cmp r8,16
 jb .validate_section
 xor r8d,r8d
.column:
 mov rax,[rsp+40]
 cmp eax,2
 jae .z_face
 mov r9,r8
 shl r9,4
 test eax,eax
 jz .index
 add r9,15
 jmp .index
.z_face:
 mov r9,r8
 cmp eax,2
 je .index
 add r9,240
.index:
 mov r10d,255
.scan:
 mov rax,r10
 shr rax,4
 mov r11,[rsp+32]
 mov r11,[r11+rax*8]
 mov rax,r10
 and eax,15
 shl rax,8
 add rax,r9
 cmp word [r11+rax*2],0
 jne .height
 dec r10
 jns .scan
.height:
 mov [rsp+64+r8*4],r10d
 inc r8
 cmp r8,16
 jb .column
 mov r10,[rsp+48]
 movups xmm0,[rsp+64]
 movups xmm1,[rsp+80]
 movups xmm2,[rsp+96]
 movups xmm3,[rsp+112]
 movups [r10],xmm0
 movups [r10+16],xmm1
 movups [r10+32],xmm2
 movups [r10+48],xmm3
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME legacy_edge_profile,136
; Profile264: maskqword bits W/E/N/S, then fourI32[16] profiles.
; terrain1_blend_column(seed,globalCoords24*,profile264*,out32*)->0/-1.
; Native climate retained; rational squared-distance surface transition.
FRAME terrain1_blend_column,248
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 mov rax,[A2]
 cmp rax,15
 ja .bad
 mov [rsp+64],rax
 xor ecx,ecx
.validate:
 bt qword [rsp+64],rcx
 jnc .next_validate
 mov r10,rcx
 shl r10,6
 add r10,[rsp+48]
 xor edx,edx
.values:
 cmp dword [r10+8+rdx*4],0
 jl .bad
 cmp dword [r10+8+rdx*4],255
 jg .bad
 inc edx
 cmp edx,16
 jb .values
.next_validate:
 inc ecx
 cmp ecx,4
 jb .validate
 mov r10,[rsp+40]
 mov A0,[rsp+32]
 mov A1,[r10]
 mov A2,[r10+16]
 lea A3,[rsp+80]
 call terrain1_column
 test rax,rax
 jnz .done
 mov r10,[rsp+40]
 mov rax,[r10]
 and eax,15
 mov [rsp+112],rax
 mov r11,15
 sub r11,rax
 mov [rsp+120],r11
 mov rax,[r10+16]
 and eax,15
 mov [rsp+128],rax
 mov r11,15
 sub r11,rax
 mov [rsp+136],r11
 ; Boundary cells use only touching faces, with arithmetic mean at corners.
 xor ecx,ecx
 xor r8d,r8d
 xor r9d,r9d
.touch:
 bt qword [rsp+64],rcx
 jnc .next_touch
 cmp qword [rsp+112+rcx*8],0
 jne .next_touch
 mov r10,rcx
 shl r10,6
 add r10,[rsp+48]
 mov rax,[rsp+128] ; west/east profiles indexed by localZ
 cmp ecx,2
 jb .touch_index
 mov rax,[rsp+112] ; north/south by localX
.touch_index:
 movsxd rax,dword [r10+8+rax*4]
 add r8,rax
 inc r9
.next_touch:
 inc ecx
 cmp ecx,4
 jb .touch
 test r9,r9
 jz .interior
 mov rax,r8
 xor edx,edx
 div r9
 mov [rsp+80],eax
 jmp .commit
.interior:
 ; Native weight is product d_i^2. Face i weight=(16-d_i)^2
 ; times all other d_j^2. No division by distance, no floating-point state.
 mov qword [rsp+144],1
 xor ecx,ecx
.native:
 bt qword [rsp+64],rcx
 jnc .next_native
 mov rax,[rsp+112+rcx*8]
 imul rax,rax
 imul rax,[rsp+144]
 mov [rsp+144],rax
.next_native:
 inc ecx
 cmp ecx,4
 jb .native
 mov rax,[rsp+144]
 mov [rsp+152],rax
 movsxd r10,dword [rsp+80]
 imul rax,r10
 mov [rsp+160],rax
 mov qword [rsp+168],0
.face:
 mov rcx,[rsp+168]
 bt qword [rsp+64],rcx
 jnc .next_face
 mov rax,16
 sub rax,[rsp+112+rcx*8]
 imul rax,rax
 mov [rsp+176],rax
 xor edx,edx
.other:
 cmp rdx,[rsp+168]
 je .next_other
 bt qword [rsp+64],rdx
 jnc .next_other
 mov rax,[rsp+112+rdx*8]
 imul rax,rax
 imul rax,[rsp+176]
 mov [rsp+176],rax
.next_other:
 inc edx
 cmp edx,4
 jb .other
 mov rax,[rsp+176]
 add [rsp+152],rax
 mov r10,[rsp+168]
 shl r10,6
 add r10,[rsp+48]
 mov r11,[rsp+128]
 cmp qword [rsp+168],2
 jb .face_index
 mov r11,[rsp+112]
.face_index:
 movsxd r10,dword [r10+8+r11*4]
 imul rax,r10
 add [rsp+160],rax
.next_face:
 inc qword [rsp+168]
 cmp qword [rsp+168],4
 jb .face
 mov rax,[rsp+160]
 cqo
 idiv qword [rsp+152]
 test rdx,rdx
 jns .height
 dec rax ; floor negative weighted heights
.height:
 mov [rsp+80],eax
.commit:
 mov r10,[rsp+56]
 movups xmm0,[rsp+80]
 movups xmm1,[rsp+96]
 movups [r10],xmm0
 movups [r10+16],xmm1
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain1_blend_column,248

; generate_section_blend(out8192,seed,sectionCoords24*,profile264*)
FRAME generate_section_blend,184
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+144],A3
 mov rax,[A2]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+48],rax
 mov rax,[A2+8]
 cmp rax,-16
 jl .bad
 cmp rax,48
 jge .bad
 shl rax,4
 mov [rsp+56],rax
 mov rax,[A2+16]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+64],rax
 ; Validate the entire profile before writing any destination cells.
 mov A0,[rsp+40]
 lea A1,[rsp+48]
 mov A2,[rsp+144]
 lea A3,[rsp+104]
 call terrain1_blend_column
 test rax,rax
 jnz .done
 mov qword [rsp+72],0
.column:
 mov rax,[rsp+72]
 mov r10,rax
 and eax,15
 shr r10,4
 add rax,[rsp+48]
 add r10,[rsp+64]
 mov [rsp+80],rax
 mov [rsp+96],r10
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 mov A2,[rsp+144]
 lea A3,[rsp+104]
 call terrain1_blend_column
 test rax,rax
 jnz .done
 mov qword [rsp+136],0
.vertical:
 mov rax,[rsp+56]
 add rax,[rsp+136]
 mov [rsp+88],rax
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 lea A2,[rsp+104]
 call generated_block1
 mov r10,[rsp+136]
 shl r10,8
 add r10,[rsp+72]
 mov r11,[rsp+32]
 mov [r11+r10*2],ax
 inc qword [rsp+136]
 cmp qword [rsp+136],16
 jb .vertical
 inc qword [rsp+72]
 cmp qword [rsp+72],256
 jb .column
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME generate_section_blend,184




; Staged generator1 publication; occupied regions remain byte-for-byte intact.
FRAME region_generate_blend,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,16
 jae .bad
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
 mov A3,[rsp+48]
 call generate_section_blend
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
 mov dword [r10+64+rcx*8],1
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
END_FRAME region_generate_blend,120



; Highest recorded surface for every cell of a complete old column.
FRAME legacy_column_profile,1096
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A2,A1
 lea A2,[rsp+64]
 xor A1,A1
 call legacy_edge_profile ; validates all sixteen complete sections first
 test rax,rax
 jnz .done
 xor r8d,r8d
.column:
 mov r10d,255
.scan:
 mov rax,r10
 shr rax,4
 mov r11,[rsp+32]
 mov r11,[r11+rax*8]
 mov rax,r10
 and eax,15
 shl rax,8
 add rax,r8
 cmp word [r11+rax*2],0
 jne .height
 dec r10
 jns .scan
.height:
 mov [rsp+64+r8*4],r10d
 inc r8
 cmp r8,256
 jb .column
 mov r10,[rsp+40]
 xor ecx,ecx
.publish:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,1024
 jb .publish
 xor eax,eax
.done:
END_FRAME legacy_column_profile,1096
; UpgradeProfile1296: edge264, own-column flag264, I32 heights256 at272.
; A complete recorded old column supplies the ceiling for its vertical extension.
FRAME terrain1_upgrade_column,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp qword [A2+264],1
 ja .bad
 cmp qword [A2+264],0
 je .validated
 xor ecx,ecx
.values:
 cmp dword [A2+272+rcx*4],0
 jl .bad
 cmp dword [A2+272+rcx*4],255
 jg .bad
 inc ecx
 cmp ecx,256
 jb .values
.validated:
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 mov A2,[rsp+48]
 lea A3,[rsp+64]
 call terrain1_blend_column
 test rax,rax
 jnz .done
 mov r10,[rsp+48]
 cmp qword [r10+264],0
 je .publish
 mov r11,[rsp+40]
 mov rax,[r11+16]
 and eax,15
 shl eax,4
 mov r11,[r11]
 and r11d,15
 add rax,r11
 mov eax,[r10+272+rax*4]
 mov [rsp+64],eax
.publish:
 mov r10,[rsp+56]
 movups xmm0,[rsp+64]
 movups xmm1,[rsp+80]
 movups [r10],xmm0
 movups [r10+16],xmm1
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain1_upgrade_column,120

FRAME generate_section_upgrade,184
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+144],A3
 mov rax,[A2]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+48],rax
 mov rax,[A2+8]
 cmp rax,-16
 jl .bad
 cmp rax,48
 jge .bad
 shl rax,4
 mov [rsp+56],rax
 mov rax,[A2+16]
 cmp rax,-1875000
 jl .bad
 cmp rax,1875000
 jge .bad
 shl rax,4
 mov [rsp+64],rax
 ; Validate the entire profile before writing any destination cells.
 mov A0,[rsp+40]
 lea A1,[rsp+48]
 mov A2,[rsp+144]
 lea A3,[rsp+104]
 call terrain1_upgrade_column
 test rax,rax
 jnz .done
 mov qword [rsp+72],0
.column:
 mov rax,[rsp+72]
 mov r10,rax
 and eax,15
 shr r10,4
 add rax,[rsp+48]
 add r10,[rsp+64]
 mov [rsp+80],rax
 mov [rsp+96],r10
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 mov A2,[rsp+144]
 lea A3,[rsp+104]
 call terrain1_upgrade_column
 test rax,rax
 jnz .done
 mov qword [rsp+136],0
.vertical:
 mov rax,[rsp+56]
 add rax,[rsp+136]
 mov [rsp+88],rax
 mov A0,[rsp+40]
 lea A1,[rsp+80]
 lea A2,[rsp+104]
 call generated_block1
 mov r10,[rsp+136]
 shl r10,8
 add r10,[rsp+72]
 mov r11,[rsp+32]
 mov [r11+r10*2],ax
 inc qword [rsp+136]
 cmp qword [rsp+136],16
 jb .vertical
 inc qword [rsp+72]
 cmp qword [rsp+72],256
 jb .column
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME generate_section_upgrade,184

FRAME region_generate_upgrade,120
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 cmp A1,16
 jae .bad
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
 mov A3,[rsp+48]
 call generate_section_upgrade
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
 mov dword [r10+64+rcx*8],1
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
END_FRAME region_generate_upgrade,120
ELF_STACK
