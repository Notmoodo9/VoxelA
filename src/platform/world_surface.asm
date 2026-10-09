%include "abi.inc"
section .text
extern malloc, free, region_init, region_valid, world_path
extern region_file_load_optional, world_store_upgrade_profile
extern terrain1_upgrade_column, generated_block1
; world_store_surface(Store1024*,globalX,globalZ,out8*) -> 0/-1.
; out8: SIGNED i32 top boundary Y (-255..768), u32 highest block.
; Read only: resident records (including dirty edits), then checked files,
; then the SAME generator/upgrade profile used by world_store_generate.
; Requires an initialized generator1 store, single owner, disjoint output.
; Bounded scratch 132592 bytes plus the existing profile resolver's scratch.
FRAME world_store_surface,1384
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp qword [A0+1016],1
 jne .bad
 cmp qword [A0+8],1
 jne .bad
 cmp qword [A0+16],1
 jb .bad
 cmp qword [A0+16],64
 ja .bad
 cmp qword [A0+24],0
 je .bad
 cmp A1,-30000000
 jl .bad
 cmp A1,30000000
 jge .bad
 cmp A2,-30000000
 jl .bad
 cmp A2,30000000
 jge .bad
 mov rax,A1
 sar rax,6
 mov [rsp+80],rax ; key RX/RZ/SY
 mov rax,A2
 sar rax,6
 mov [rsp+88],rax
 mov qword [rsp+96],47
 mov rax,A1
 sar rax,4
 and eax,3
 mov r10,A2
 sar r10,4
 and r10d,3
 shl r10,2
 add rax,r10
 mov [rsp+104],rax ; region slot
 mov rax,A1
 and eax,15
 mov r10,A2
 and r10d,15
 shl r10,4
 add rax,r10
 mov [rsp+112],rax ; cell's horizontal offset
 mov qword [rsp+120],0 ; lazy profile ready
 mov A0,132592 ; Region + UpgradeProfile1296 + Column32
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+64],rax
.section:
 ; Resident lookup intentionally bypasses LRU touch APIs.
 mov r10,[rsp+32]
 mov r11,[r10+24]
 xor ecx,ecx
.cache:
 cmp qword [r11+24],1
 jne .next_cache
 mov rax,[r11]
 mov [rsp+128],rax
 call surface_matches
 test eax,eax
 jnz .resident
.next_cache:
 add r11,32
 inc rcx
 mov r10,[rsp+32]
 cmp rcx,[r10+16]
 jb .cache
 mov A0,[rsp+32]
 lea A1,[rsp+80]
 lea A2,[rsp+224]
 call world_path
 test rax,rax
 js .fail
 lea A0,[rsp+224]
 mov A1,[rsp+64]
 call region_file_load_optional
 test rax,rax
 js .fail
 jnz .missing
 mov rax,[rsp+64]
 mov [rsp+128],rax
 call surface_matches
 test eax,eax
 jz .fail
 jmp .record
.resident:
 mov A0,[rsp+128]
 call region_valid
 test rax,rax
 jnz .fail
.record:
 mov r10,[rsp+128]
 mov rcx,[rsp+104]
 bt qword [r10+32],rcx
 jnc .missing
 shl rcx,13
 lea r10,[r10+192+rcx]
 mov [rsp+136],r10
 mov qword [rsp+144],15
.scan_record:
 mov rax,[rsp+144]
 shl rax,8
 add rax,[rsp+112]
 mov r10,[rsp+136]
 movzx eax,word [r10+rax*2]
 test eax,eax
 jnz .found
 dec qword [rsp+144]
 jns .scan_record
 jmp .next_section
.missing:
 cmp qword [rsp+120],1
 je .generated
 ; Force the complete-own-column extension query. Its own ceiling may be
 ; used for all absent sections: a complete old column has NO absent SY0..15.
 mov r10,[rsp+32]
 mov rax,[r10]
 mov [rsp+160],rax
 mov rax,[rsp+80]
 mov [rsp+168],rax
 mov rax,[rsp+88]
 mov [rsp+176],rax
 mov qword [rsp+184],-16
 mov A0,[rsp+64]
 lea A1,[rsp+160]
 call region_init
 test rax,rax
 jnz .fail
 mov rax,[rsp+40]
 sar rax,4
 mov [rsp+160],rax ; section coords
 mov qword [rsp+168],-16
 mov rax,[rsp+48]
 sar rax,4
 mov [rsp+176],rax
 mov A0,[rsp+32]
 lea A1,[rsp+160]
 mov A2,[rsp+64]
 lea A3,[A2+131264]
 call world_store_upgrade_profile
 test rax,rax
 jnz .fail
 mov rax,[rsp+40]
 mov [rsp+192],rax ; global block coords
 mov qword [rsp+200],-256
 mov rax,[rsp+48]
 mov [rsp+208],rax
 mov r10,[rsp+32]
 mov A0,[r10]
 lea A1,[rsp+192]
 mov r10,[rsp+64]
 lea A2,[r10+131264]
 lea A3,[r10+132560]
 call terrain1_upgrade_column
 test rax,rax
 jnz .fail
 mov qword [rsp+120],1
.generated:
 mov rax,[rsp+96]
 shl rax,4
 mov [rsp+200],rax
 mov r10,[rsp+64]
 movsxd r11,dword [r10+132560]
 cmp rax,r11
 jg .next_section ; absent air above the actual blended/old ceiling
 add rax,15
 cmp rax,r11
 cmovg rax,r11
 mov [rsp+200],rax
.scan_generated:
 mov r10,[rsp+32]
 mov A0,[r10]
 lea A1,[rsp+192]
 mov r10,[rsp+64]
 lea A2,[r10+132560]
 call generated_block1
 test rax,rax
 js .fail
 jnz .generated_found
 dec qword [rsp+200]
 mov rax,[rsp+200]
 sar rax,4
 cmp rax,[rsp+96]
 je .scan_generated
.next_section:
 dec qword [rsp+96]
 cmp qword [rsp+96],-16
 jge .section
 jmp .fail ; canonical generated bedrock prevents an empty column
.generated_found:
 mov r10,[rsp+200]
 jmp .publish
.found:
 mov r10,[rsp+96]
 shl r10,4
 add r10,[rsp+144]
.publish:
 inc r10
 mov r11,[rsp+56]
 mov [r11],r10d
 mov [r11+4],eax
 xor eax,eax
 jmp .release
.fail: mov rax,-1
.release:
 mov [rsp+72],rax
 mov A0,[rsp+64]
 CCALL free
 mov rax,[rsp+72]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_surface,1384
; Private leaf, frame accessed past the return address. Preserve loop registers.
surface_matches:
 mov r8,[rsp+8+128]
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
; world_store_surface_batch(Store*, Request16[X,Z]*, count1..64, out8[count]*)
; ->0/-1. Staged publication: a failed sample preserves the WHOLE output batch.
; Caller orders requests (e.g. nearest first); no worker/frame scheduling implied.
FRAME world_store_surface_batch,600
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 cmp A2,1
 jb .bad
 cmp A2,64
 ja .bad
 mov qword [rsp+64],0
.sample:
 mov r10,[rsp+64]
 shl r10,4
 add r10,[rsp+40]
 mov A1,[r10]
 mov A2,[r10+8]
 mov A0,[rsp+32]
 mov r10,[rsp+64]
 lea A3,[rsp+80+r10*8]
 call world_store_surface
 test rax,rax
 jnz .bad
 inc qword [rsp+64]
 mov rax,[rsp+64]
 cmp rax,[rsp+48]
 jb .sample
 mov r10,[rsp+56]
 xor ecx,ecx
.publish:
 mov rax,[rsp+80+rcx*8]
 mov [r10+rcx*8],rax
 inc rcx
 cmp rcx,[rsp+48]
 jb .publish
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME world_store_surface_batch,600
ELF_STACK
