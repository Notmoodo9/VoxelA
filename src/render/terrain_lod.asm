%include "abi.inc"
section .text
extern terrain_surface, terrain_surface_index_build, terrain_surface_indexed, mix64
; Config64: Stream96*, Vertex32*, capacity>=65536, center global X/Z,
; radius blocks32..4096, output count, optional scratch360480 pointer. Center has X/Z mod16==8.
; Legacy uses terrain_surface; explicit source builds use actual-world callbacks.
; Canonical journal required. Inputs/destination must not alias. Synchronous.
; All rejected config/capacity requests leave output/count untouched.
FRAME lod_sample,88
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov qword [rsp+64],0
 cmp qword [A0+56],0
 je .query
 mov r10,A1
 mov rax,[r10]
 mov r11,0xd6e8feb86659fd93
 imul rax,r11
 mov A0,rax
 mov rax,[r10+16]
 mov r11,0xa5a3564e27f8862f
 imul rax,r11
 xor A0,rax
 call mix64
 and eax,8191
 mov [rsp+48],rax
 mov [rsp+56],rax
.probe:
 mov r10,[rsp+32]
 mov r11,[r10+56]
 mov rax,[rsp+56]
 shl rax,5
 add r11,rax
 cmp qword [r11+16],-1
 je .insert
 mov r10,[rsp+40]
 mov rax,[r10]
 cmp rax,[r11]
 jne .next
 mov rax,[r10+16]
 cmp rax,[r11+8]
 jne .next
 mov rax,[r11+16]
 mov [r10+8],rax
 mov rax,[r11+24]
 mov [r10+24],rax
 xor eax,eax
 jmp .done
.next:
 inc qword [rsp+56]
 and qword [rsp+56],8191
 mov rax,[rsp+56]
 cmp rax,[rsp+48]
 jne .probe
 jmp .query ; a full cache falls back to the exact sampler
.insert:
 mov [rsp+64],r11
.query:
 mov r10,[rsp+40]
 mov A1,[r10]
 mov A2,[r10+16]
 lea A3,[rsp+72]
 mov r10,[rsp+32]
 mov r11,[r10]
 cmp qword [r11+48],-2
 je .source
 mov r11,[r10+56]
 test r11,r11
 jz .unindexed
 lea A0,[r11+262144]
 call terrain_surface_indexed
 jmp .queried
.unindexed:
 mov A0,[r10]
 call terrain_surface
 jmp .queried
.source:
 mov r11,[r11+56]
 mov A0,[r11]
 call [r11+8]
 test rax,rax
 jnz .source_bad
 cmp dword [rsp+72],-255
 jl .source_bad
 cmp dword [rsp+72],768
 jg .source_bad
 cmp dword [rsp+76],1
 jb .source_bad
 cmp dword [rsp+76],7
 ja .source_bad
 jmp .queried
.source_bad:
 mov rax,-1
 jmp .done
.queried:
 test rax,rax
 jnz .done
 mov r10,[rsp+40]
 movsxd rax,dword [rsp+72]
 shl rax,16
 mov [r10+8],rax
 mov eax,[rsp+76]
 mov [r10+24],rax
 mov r11,[rsp+64]
 test r11,r11
 jz .ok
 mov rax,[r10]
 mov [r11],rax
 mov rax,[r10+16]
 mov [r11+8],rax
 mov rax,[r10+8]
 mov [r11+16],rax
 mov rax,[r10+24]
 mov [r11+24],rax
.ok: xor eax,eax
.done:
END_FRAME lod_sample,88
; emit(ctx,record32*) with integer X/Z and Q16 Y, block material.
lod_emit:
 mov r10,[A0+48]
 shl r10,5
 add r10,[A0+8]
 mov r11,[A1]
 sub r11,[A0+24]
 add r11,8
 cvtsi2ss xmm0,r11
 movss [r10],xmm0
 cvtsi2ss xmm0,qword [A1+8]
 mulss xmm0,[q16_scale]
 movss [r10+4],xmm0
 mov r11,[A1+16]
 sub r11,[A0+32]
 add r11,8
 cvtsi2ss xmm0,r11
 movss [r10+8],xmm0
 mov rax,[A1+24]
 imul eax,12
 lea r11,[material_colors]
 mov r9,[r11+rax]
 mov [r10+12],r9
 mov eax,[r11+rax+8]
 mov [r10+20],eax
 mov dword [r10+24],__float32__(0.03125)
 mov dword [r10+28],__float32__(0.5)
 inc qword [A0+48]
 ret
FRAME lod_quad,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov qword [rsp+48],0
.vertex:
 mov rax,[rsp+48]
 lea r10,[triangles]
 movzx eax,byte [r10+rax]
 shl rax,5
 mov A1,[rsp+40]
 add A1,rax
 mov A0,[rsp+32]
 call lod_emit
 inc qword [rsp+48]
 cmp qword [rsp+48],6
 jb .vertex
 xor eax,eax
END_FRAME lod_quad,56
; A coarse cell touching a finer ring shares every fine edge vertex.
; Emit its unaffected triangle, then split the edge triangle into a fan.
FRAME lod_stitched_quad,184
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2 ; edge segment count (4 at block boundary, otherwise2)
 imul A3,6
 lea r10,[stitch_order]
 add r10,A3
 mov [rsp+64],r10
 movzx eax,byte [r10]
 shl rax,5
 add rax,A1
 mov [rsp+144],rax
 movzx eax,byte [r10+1]
 shl rax,5
 add rax,A1
 mov [rsp+160],rax
 movups xmm0,[rax]
 movups xmm1,[rax+16]
 movups [rsp+80],xmm0
 movups [rsp+96],xmm1
 movzx eax,byte [r10+2]
 shl rax,5
 add rax,A1
 mov [rsp+152],rax
 mov qword [rsp+72],0
.other:
 mov r10,[rsp+64]
 mov rax,[rsp+72]
 movzx eax,byte [r10+rax+3]
 shl rax,5
 mov A1,[rsp+40]
 add A1,rax
 mov A0,[rsp+32]
 call lod_emit
 inc qword [rsp+72]
 cmp qword [rsp+72],3
 jb .other
 mov qword [rsp+72],1
.fan:
 mov r10,[rsp+160]
 mov r11,[rsp+152]
 mov rax,[r11]
 sub rax,[r10]
 imul rax,[rsp+72]
 cqo
 idiv qword [rsp+48]
 add rax,[r10]
 mov [rsp+112],rax
 mov rax,[r11+16]
 sub rax,[r10+16]
 imul rax,[rsp+72]
 cqo
 idiv qword [rsp+48]
 add rax,[r10+16]
 mov [rsp+128],rax
 mov A0,[rsp+32]
 lea A1,[rsp+112]
 call lod_sample
 test rax,rax
 jnz .done
 mov A0,[rsp+32]
 mov A1,[rsp+144]
 call lod_emit
 mov A0,[rsp+32]
 lea A1,[rsp+80]
 call lod_emit
 mov A0,[rsp+32]
 lea A1,[rsp+112]
 call lod_emit
 movups xmm0,[rsp+112]
 movups xmm1,[rsp+128]
 movups [rsp+80],xmm0
 movups [rsp+96],xmm1
 inc qword [rsp+72]
 mov rax,[rsp+72]
 cmp rax,[rsp+48]
 jbe .fan
 xor eax,eax
.done:
END_FRAME lod_stitched_quad,184
; Join sampled surface edge to the neighboring stepped block profile.
; edge: two records; step; kind0 joins block boundary,kind1 joins half-step LOD.
FRAME lod_seam,264
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 mov rax,A2
 shr rax,1
 test A3,A3
 jnz .fine
 mov eax,1
.fine:
 mov [rsp+64],rax
 mov qword [rsp+72],0
.segment:
 ; Quad points0/1 are coarse endpoints;2/3 are the fine profile endpoints.
 mov qword [rsp+80],0
.point:
 mov r10,[rsp+40]
 mov rax,[rsp+72]
 cmp qword [rsp+80],0
 je .fraction
 add rax,[rsp+64]
.fraction:
 mov [rsp+88],rax
 mov qword [rsp+240],0
.axis:
 mov r11,[rsp+240]
 mov rax,[r10+32+r11]
 sub rax,[r10+r11]
 imul rax,[rsp+88]
 cqo
 idiv qword [rsp+48]
 add rax,[r10+r11]
 mov r11,[rsp+80]
 shl r11,5
 add r11,[rsp+240]
 mov [rsp+96+r11],rax
 add qword [rsp+240],8
 cmp qword [rsp+240],24
 jb .axis
 mov rax,[r10+24]
 mov r11,[rsp+80]
 shl r11,5
 mov [rsp+120+r11],rax
 inc qword [rsp+80]
 cmp qword [rsp+80],2
 jb .point
 mov A0,[rsp+32]
 lea A1,[rsp+96]
 call lod_sample
 test rax,rax
 jnz .done
 mov A0,[rsp+32]
 lea A1,[rsp+128]
 call lod_sample
 test rax,rax
 jnz .done
 ; Copy endpoint records to fine side, retaining their plane positions.
 movups xmm0,[rsp+96]
 movups xmm1,[rsp+112]
 movups [rsp+192],xmm0
 movups [rsp+208],xmm1
 movups xmm0,[rsp+128]
 movups xmm1,[rsp+144]
 movups [rsp+160],xmm0
 movups [rsp+176],xmm1
 mov qword [rsp+80],0
.sample:
 mov rax,[rsp+80]
 shl rax,5
 lea r10,[rsp+160]
 add r10,rax
 ; Fine order is reversed (point2=end,point3=start).
 cmp qword [rsp+56],0
 jne .sample_lod
 ; A detailed boundary segment uses one block's constant-height top.
 ; Always sample segment start; move to inside on positive cache boundaries.
 mov rax,[rsp+96]
 mov [r10],rax
 mov rax,[rsp+112]
 mov [r10+16],rax
 mov r11,[rsp+32]
 mov rax,[r10]
 sub rax,[r11+24]
 cmp rax,40
 jne .z_inside
 dec qword [r10]
.z_inside:
 mov rax,[r10+16]
 sub rax,[r11+32]
 cmp rax,40
 jne .sample_lod
 dec qword [r10+16]
.sample_lod:
 mov A1,r10
 mov A0,[rsp+32]
 call lod_sample
 test rax,rax
 jnz .done
 inc qword [rsp+80]
 cmp qword [rsp+80],2
 jb .sample
 ; Restore fine X/Z onto the edge plane after inside-column sampling.
 mov rax,[rsp+128]
 mov [rsp+160],rax
 mov rax,[rsp+144]
 mov [rsp+176],rax
 mov rax,[rsp+96]
 mov [rsp+192],rax
 mov rax,[rsp+112]
 mov [rsp+208],rax
 mov A0,[rsp+32]
 lea A1,[rsp+96]
 call lod_quad
 mov rax,[rsp+64]
 add [rsp+72],rax
 mov rax,[rsp+72]
 cmp rax,[rsp+48]
 jb .segment
 xor eax,eax
.done:
END_FRAME lod_seam,264
FRAME terrain_lod_build,40
 xor A1,A1
 call terrain_lod_build_impl
END_FRAME terrain_lod_build,40
; Source16: context, callback(ctx,x,z,out8*) ->0/-1, signed height/block.
; Destination is caller-staged. Count publishes only on success.
FRAME terrain_lod_build_source,216
 mov [rsp+32],A0
 test A1,A1
 jz .bad
 cmp qword [A1+8],0
 je .bad
 mov [rsp+40],A1
 mov r10,A0
 xor ecx,ecx
.copy:
 mov rax,[r10+rcx]
 mov [rsp+48+rcx],rax
 add ecx,8
 cmp ecx,64
 jb .copy
 xor eax,eax
 mov ecx,12
 lea r10,[rsp+112]
.clear:
 mov [r10],rax
 add r10,8
 loop .clear
 lea rax,[rsp+112]
 mov [rsp+48],rax
 mov qword [rsp+160],-2
 mov rax,[rsp+40]
 mov [rsp+168],rax
 lea A0,[rsp+48]
 mov A1,1
 call terrain_lod_build_impl
 test rax,rax
 jnz .done
 mov r10,[rsp+32]
 mov r11,[rsp+96]
 mov [r10+48],r11
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain_lod_build_source,216
FRAME terrain_lod_build_impl,360
 mov [rsp+336],A1
 mov [rsp+32],A0
 cmp qword [A0+16],65536
 jb .small
 cmp qword [A0+40],32
 jb .bad
 cmp qword [A0+40],4096
 ja .bad
 mov r10,[A0+24]
 cmp r10,-30000000
 jl .bad
 cmp r10,30000000
 jge .bad
 and r10d,15
 cmp r10d,8
 jne .bad
 mov r10,[A0+32]
 cmp r10,-30000000
 jl .bad
 cmp r10,30000000
 jge .bad
 and r10d,15
 cmp r10d,8
 jne .bad
 mov r10,[A0]
 cmp qword [rsp+336],1
 je .validated
 cmp qword [r10+48],8192
 ja .bad
 ; Validate journal records before mutating either destination or count.
 mov r11,[r10+56]
 xor ecx,ecx
.validate_edits:
 cmp rcx,[r10+48]
 jae .validated
 cmp qword [r11],-30000000
 jl .bad
 cmp qword [r11],30000000
 jge .bad
 cmp qword [r11+16],-30000000
 jl .bad
 cmp qword [r11+16],30000000
 jge .bad
 cmp qword [r11+8],1
 jb .bad
 cmp qword [r11+8],255
 ja .bad
 cmp qword [r11+24],6
 ja .bad
 add r11,32
 inc rcx
 jmp .validate_edits
.validated:
 mov A0,[rsp+32]
 mov qword [A0+48],0
 cmp qword [A0+40],40
 jbe .success
 ; Each build gets a fresh caller-owned sample cache. No global mutable state.
 mov r10,[A0+56]
 test r10,r10
 jz .cache_ready
 add r10,16
 mov ecx,8192
.clear_cache:
 mov qword [r10],-1
 add r10,32
 loop .clear_cache
.cache_ready:
 cmp qword [rsp+336],1
 je .index_ready
 mov r10,[rsp+32]
 mov A1,[r10+56]
 test A1,A1
 jz .index_ready
 add A1,262144
 mov A0,[r10]
 call terrain_surface_index_build
.index_ready:
 mov qword [rsp+40],64 ; outer
 mov qword [rsp+48],40 ; inner
 mov qword [rsp+56],4 ; sample spacing
.ring:
 mov rax,[rsp+40]
 neg rax
 mov [rsp+72],rax ; Z
.row:
 mov rax,[rsp+40]
 neg rax
 mov [rsp+64],rax ; X
.cell:
 mov rax,[rsp+48]
 neg rax
 cmp [rsp+64],rax
 jl .build
 cmp [rsp+72],rax
 jl .build
 mov rax,[rsp+48]
 cmp [rsp+64],rax
 jge .build
 cmp [rsp+72],rax
 jge .build
 jmp .next_cell
.build:
 ; Four corners, initialized and validated before any samples.
 mov qword [rsp+80],0
.corner:
 mov rax,[rsp+80]
 lea r10,[corners]
 movzx r11d,byte [r10+rax*2]
 imul r11,[rsp+56]
 add r11,[rsp+64]
 mov r10,[rsp+32]
 add r11,[r10+24]
 cmp r11,-30000000
 jl .next_cell
 cmp r11,30000000
 jge .next_cell
 shl rax,5
 mov [rsp+96+rax],r11
 mov rax,[rsp+80]
 lea r10,[corners]
 movzx r11d,byte [r10+rax*2+1]
 imul r11,[rsp+56]
 add r11,[rsp+72]
 mov r10,[rsp+32]
 add r11,[r10+32]
 cmp r11,-30000000
 jl .next_cell
 cmp r11,30000000
 jge .next_cell
 shl rax,5
 mov [rsp+112+rax],r11
 inc qword [rsp+80]
 cmp qword [rsp+80],4
 jb .corner
 mov qword [rsp+80],0
.samples:
 mov rax,[rsp+80]
 shl rax,5
 lea A1,[rsp+96+rax]
 mov A0,[rsp+32]
 call lod_sample
 test rax,rax
 jnz .done
 inc qword [rsp+80]
 cmp qword [rsp+80],4
 jb .samples
 ; Cells touching the inner square share the finer edge vertices.
 mov rax,[rsp+48]
 neg rax
 cmp [rsp+64],rax
 jl .horizontal
 mov rax,[rsp+48]
 cmp [rsp+64],rax
 jge .horizontal
 mov rax,[rsp+48]
 neg rax
 sub rax,[rsp+56]
 cmp [rsp+72],rax
 je .edge_bottom
 mov rax,[rsp+48]
 cmp [rsp+72],rax
 je .edge_top
.horizontal:
 mov rax,[rsp+48]
 neg rax
 cmp [rsp+72],rax
 jl .plain
 mov rax,[rsp+48]
 cmp [rsp+72],rax
 jge .plain
 mov rax,[rsp+48]
 neg rax
 sub rax,[rsp+56]
 cmp [rsp+64],rax
 je .edge_left
 mov rax,[rsp+48]
 cmp [rsp+64],rax
 je .edge_right
 jmp .plain
.plain:
 mov A0,[rsp+32]
 lea A1,[rsp+96]
 call lod_quad
 test rax,rax
 jnz .done
 jmp .next_cell
.edge_bottom:
 mov qword [rsp+88],0
 lea r10,[rsp+192]
 lea r11,[rsp+160]
 jmp .edge
.edge_top:
 mov qword [rsp+88],1
 lea r10,[rsp+96]
 lea r11,[rsp+128]
 jmp .edge
.edge_left:
 mov qword [rsp+88],2
 lea r10,[rsp+128]
 lea r11,[rsp+160]
 jmp .edge
.edge_right:
 mov qword [rsp+88],3
 lea r10,[rsp+96]
 lea r11,[rsp+192]
.edge:
 movups xmm0,[r10]
 movups xmm1,[r10+16]
 movups [rsp+256],xmm0
 movups [rsp+272],xmm1
 movups xmm0,[r11]
 movups xmm1,[r11+16]
 movups [rsp+288],xmm0
 movups [rsp+304],xmm1
 mov A0,[rsp+32]
 lea A1,[rsp+96]
 mov A2,2
 cmp qword [rsp+48],40
 jne .segments
 mov A2,4
.segments:
 mov A3,[rsp+88]
 call lod_stitched_quad
 test rax,rax
 jnz .done
 cmp qword [rsp+48],40
 jne .next_cell
 mov A0,[rsp+32]
 lea A1,[rsp+256]
 mov A2,[rsp+56]
 xor A3,A3
 call lod_seam
 test rax,rax
 jnz .done
.next_cell:
 mov rax,[rsp+56]
 add [rsp+64],rax
 mov rax,[rsp+64]
 cmp rax,[rsp+40]
 jl .cell
 mov rax,[rsp+56]
 add [rsp+72],rax
 mov rax,[rsp+72]
 cmp rax,[rsp+40]
 jl .row
 mov r10,[rsp+32]
 mov rax,[rsp+40]
 cmp rax,[r10+40]
 jae .success
 mov [rsp+48],rax
 shl qword [rsp+40],1
 shl qword [rsp+56],1
 jmp .ring
.success: xor eax,eax
 jmp .done
.small: mov rax,-2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME terrain_lod_build_impl,360
section .rdata
q16_scale: dd 0.0000152587890625
corners: db 0,0,1,0,1,1,0,1
stitch_order: db 0,3,2,0,2,1, 2,1,0,0,3,2, 0,2,1,0,3,2, 2,0,3,0,2,1
triangles: db 0,3,2,0,2,1
material_colors:
 dd 0.0,0.0,0.0, 0.48,0.51,0.55, 0.45,0.30,0.19, 0.35,0.52,0.22
 dd 0.80,0.70,0.46, 0.47,0.32,0.19, 0.23,0.43,0.20, 0.20,0.21,0.25
ELF_STACK
