%include "abi.inc"
section .text
extern malloc, free, world_path, region_file_load_optional, legacy_edge_profile
extern region_generate, region_generate_blend, region_generate_upgrade
extern legacy_column_profile, surface_read_region
; Internal synchronous read-only resolver. Requires canonical store/current region.
; Four complete recorded generator0 neighbor columns qualify. No generation on read.
FRAME world_store_upgrade_profile,40
 mov A4,0
 call world_store_upgrade_profile_impl
END_FRAME world_store_upgrade_profile,40
; Cached variant takes Read64* instead of Store*; other args unchanged.
FRAME world_store_upgrade_profile_cached,40
 mov A4,A0
 mov A0,[A0]
 call world_store_upgrade_profile_impl
END_FRAME world_store_upgrade_profile_cached,40
FRAME world_store_upgrade_profile_impl,1256
%ifdef WINDOWS_ABI
 mov rax,[rsp+1296]
%else
 mov rax,A4
%endif
 mov [rsp+280],rax
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 mov A0,263632 ; scratch region, sixteen sections, staged upgrade profile
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+64],rax
 lea r10,[rax+262336]
 xor eax,eax
 mov ecx,162
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
 mov qword [rsp+72],0
 .face:
 cmp qword [rsp+72],4
 jne .face_ready
 mov r10,[rsp+40]
 cmp qword [r10+8],0
 jl .face_ready
 cmp qword [r10+8],16
 jb .next_face
.face_ready:
 mov r10,[rsp+40]
 mov rax,[r10]
 mov r11,[r10+16]
 cmp qword [rsp+72],0
 jne .east
 dec rax
 jmp .neighbor
.east:
 cmp qword [rsp+72],1
 jne .north
 inc rax
 jmp .neighbor
.north:
 cmp qword [rsp+72],2
 jne .south
 dec r11
 jmp .neighbor
.south:
 cmp qword [rsp+72],3
 jne .neighbor
 inc r11
.neighbor:
 cmp rax,-1875000
 jl .next_face
 cmp rax,1875000
 jge .next_face
 cmp r11,-1875000
 jl .next_face
 cmp r11,1875000
 jge .next_face
 mov [rsp+104],rax
 mov [rsp+112],r11
 sar rax,2
 sar r11,2
 mov [rsp+80],rax
 mov [rsp+88],r11
 mov qword [rsp+120],0
 mov rax,[rsp+104]
 and eax,3
 mov r11,[rsp+112]
 and r11d,3
 shl r11,2
 add rax,r11
 mov [rsp+264],rax
.section:
 mov rax,[rsp+120]
 mov [rsp+96],rax
 mov r11,[rsp+48]
 mov [rsp+256],r11
 call world_blend_matches
 test eax,eax
 jnz .found
 mov r10,[rsp+32]
 mov r11,[r10+24]
 xor ecx,ecx
.cache:
 cmp qword [r11+24],1
 jne .next_cache
 mov rax,[r11]
 mov [rsp+256],rax
 call world_blend_matches
 test eax,eax
 jnz .found
.next_cache:
 inc rcx
 add r11,32
 mov r10,[rsp+32]
 cmp rcx,[r10+16]
 jb .cache
 cmp qword [rsp+280],0
 jne .cached_read
 mov A0,[rsp+32]
 lea A1,[rsp+80]
 lea A2,[rsp+288]
 call world_path
 test rax,rax
 js .release
 lea A0,[rsp+288]
 mov A1,[rsp+64]
 call region_file_load_optional
 test rax,rax
 js .release
 jnz .next_face ; missing cannot imply preserved legacy data
 mov rax,[rsp+64]
 jmp .read_ready
.cached_read:
 mov A0,[rsp+280]
 lea A1,[rsp+80]
 call surface_read_region
 test rax,rax
 js .release
 jz .next_face
.read_ready:
 mov [rsp+256],rax
 call world_blend_matches
 test eax,eax
 jz .conflict
.found:
 mov r10,[rsp+256]
 mov rcx,[rsp+264]
 bt qword [r10+32],rcx
 jnc .next_face
 cmp dword [r10+64+rcx*8],0
 jne .next_face
 shl rcx,13
 lea r10,[r10+192+rcx]
 mov rax,[rsp+120]
 shl rax,13
 add rax,[rsp+64]
 add rax,131264
 mov r11,[rsp+120]
 mov [rsp+128+r11*8],rax
 xor ecx,ecx
.copy:
 mov r11,[r10+rcx]
 mov [rax+rcx],r11
 add ecx,8
 cmp ecx,8192
 jb .copy
 inc qword [rsp+120]
 cmp qword [rsp+120],16
 jb .section
 cmp qword [rsp+72],4
 je .own_column
 lea A0,[rsp+128]
 mov A1,[rsp+72]
 xor A1,1 ; read the neighbor face facing this new section
 mov rax,[rsp+72]
 shl rax,6
 add rax,[rsp+64]
 lea A2,[rax+262344]
 call legacy_edge_profile
 test rax,rax
 jnz .release
 mov r10,[rsp+64]
 mov rcx,[rsp+72]
 bts qword [r10+262336],rcx
 jmp .next_face
.own_column:
 lea A0,[rsp+128]
 mov r10,[rsp+64]
 lea A1,[r10+262608]
 call legacy_column_profile
 test rax,rax
 jnz .release
 mov r10,[rsp+64]
 mov qword [r10+262600],1
.next_face:
 inc qword [rsp+72]
 cmp qword [rsp+72],5
 jb .face
 mov r10,[rsp+64]
 add r10,262336
 mov r11,[rsp+56]
 xor ecx,ecx
.publish:
 mov rax,[r10+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,1296
 jb .publish
 xor eax,eax
 jmp .release
.conflict: mov rax,-1
.release:
 mov [rsp+272],rax
 mov A0,[rsp+64]
 CCALL free
 mov rax,[rsp+272]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_upgrade_profile_impl,1256
; Private leaf: stack has one return address beyond frame. No register clobbers
; other than RAX/R8/R9. The cache loop keeps RCX/R11 untouched.
world_blend_matches:
 mov r8,[rsp+8+256]
 mov r9,[rsp+8+32]
 mov rax,[r9]
 cmp [r8],rax
 jne .no
 mov rax,[rsp+8+80]
 cmp [r8+8],rax
 jne .no
 mov rax,[rsp+8+88]
 cmp [r8+16],rax
 jne .no
 mov rax,[rsp+8+96]
 cmp [r8+24],rax
 jne .no
 mov eax,1
 ret
.no: xor eax,eax
 ret
; Internal generator dispatcher. No resident/staged mutation on resolver failure.
FRAME world_store_generate,1400
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov r10,A1
 mov rcx,A2
 bt qword [r10+32],rcx
 jc .exists
 mov r10,[rsp+32]
 cmp qword [r10+8],0
 jne .new
 mov A0,A1
 mov A1,A2
 xor A2,A2
 call region_generate
 jmp .done
.new:
 mov r10,[rsp+40]
 mov rcx,[rsp+48]
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
 mov A0,[rsp+32]
 lea A1,[rsp+64]
 mov A2,[rsp+40]
 lea A3,[rsp+88]
 call world_store_upgrade_profile
 test rax,rax
 jnz .done
 mov A0,[rsp+40]
 mov A1,[rsp+48]
 lea A2,[rsp+88]
 call region_generate_upgrade
 jmp .done
.exists: xor eax,eax
.done:
END_FRAME world_store_generate,1400


; Edge-only compatibility view for callers using the original264-byte profile.
FRAME world_store_blend_profile,1352
 mov [rsp+32],A3
 lea A3,[rsp+48]
 call world_store_upgrade_profile
 test rax,rax
 jnz .done
 mov r10,[rsp+32]
 xor ecx,ecx
.copy:
 mov rax,[rsp+48+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,264
 jb .copy
 xor eax,eax
.done:
END_FRAME world_store_blend_profile,1352
ELF_STACK
