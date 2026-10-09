%include "abi.inc"
section .text
extern craft_valid, player_init, player_look
; Independent region player state: Header64 + Pose32 + Craft336 =432.
; Terrain lives in regions; this codec never serializes a global edit journal.
global region_player_checksum
region_player_checksum:
 mov r10,A0
 xor r8d,r8d
 mov rax,0xcbf29ce484222325
 mov r9,0x100000001b3
.loop:
 cmp r8,432
 jae .done
 cmp r8,32
 jb .byte
 cmp r8,40
 jb .zero
.byte: xor al,[r10+r8]
.zero:
 imul rax,r9
 inc r8
 jmp .loop
.done: ret
region_pose_valid:
 movsd xmm0,[A0]
 comisd xmm0,[min_xz]
 jb .bad
 comisd xmm0,[max_xz]
 ja .bad
 movsd xmm0,[A0+16]
 comisd xmm0,[min_xz]
 jb .bad
 comisd xmm0,[max_xz]
 ja .bad
 movsd xmm0,[A0+8]
 comisd xmm0,[min_y]
 jb .bad
 comisd xmm0,[max_y]
 ja .bad
 movss xmm0,[A0+24]
 comiss xmm0,[min_yaw]
 jb .bad
 comiss xmm0,[max_yaw]
 ja .bad
 movss xmm0,[A0+28]
 comiss xmm0,[min_pitch]
 jb .bad
 comiss xmm0,[max_pitch]
 ja .bad
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; encode(seed,Player80*,Craft336*,out432*)->432/-1; atomic rejection.
FRAME region_player_encode,504
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov [rsp+48],A2
 mov [rsp+56],A3
 mov A0,A1
 call region_pose_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+48]
 call craft_valid
 test rax,rax
 jnz .bad
 xor eax,eax
 xor ecx,ecx
.clear:
 mov [rsp+64+rcx],rax
 add ecx,8
 cmp ecx,64
 jb .clear
 mov rax,0x3152594c50415856 ; VXAPLYR1
 mov [rsp+64],rax
 mov dword [rsp+72],1
 mov dword [rsp+76],64
 mov rax,[rsp+32]
 mov [rsp+80],rax
 mov qword [rsp+88],432
 mov r10,[rsp+40]
 movups xmm0,[r10]
 movups xmm1,[r10+16]
 movups [rsp+128],xmm0
 movups [rsp+144],xmm1
 mov r10,[rsp+48]
 xor ecx,ecx
.inventory:
 mov rax,[r10+rcx]
 mov [rsp+160+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .inventory
 lea A0,[rsp+64]
 call region_player_checksum
 mov [rsp+96],rax
 mov r10,[rsp+56]
 xor ecx,ecx
.publish:
 mov rax,[rsp+64+rcx]
 mov [r10+rcx],rax
 add ecx,8
 cmp ecx,432
 jb .publish
 mov eax,432
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_player_encode,504
; decode(bytes,len,expectedSeed,bundle[Player80*,Craft336*])->0/-1.
; Valid initialized destination player; preserve its aspect. Source immutable.
FRAME region_player_decode,152
 mov [rsp+32],A0
 mov [rsp+40],A3
 cmp A1,432
 jne .bad
 mov rax,0x3152594c50415856
 cmp [A0],rax
 jne .bad
 cmp dword [A0+8],1
 jne .bad
 cmp dword [A0+12],64
 jne .bad
 cmp [A0+16],A2
 jne .bad
 cmp qword [A0+24],432
 jne .bad
 cmp qword [A0+40],0
 jne .bad
 cmp qword [A0+48],0
 jne .bad
 cmp qword [A0+56],0
 jne .bad
 call region_player_checksum
 mov r10,[rsp+32]
 cmp [r10+32],rax
 jne .bad
 lea A0,[r10+64]
 call region_pose_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 lea A0,[r10+96]
 call craft_valid
 test rax,rax
 jnz .bad
 lea A0,[rsp+64]
 mov r10,[rsp+32]
 lea A1,[r10+64]
 call player_init
 mov r10,[rsp+32]
 movups xmm0,[r10+64]
 movups xmm1,[r10+80]
 movups [rsp+64],xmm0
 movups [rsp+80],xmm1
 lea A0,[rsp+64]
 xor A1,A1
 xor A2,A2
 call player_look
 mov r10,[rsp+40]
 mov r11,[r10]
 mov eax,[r11+64]
 mov [rsp+128],eax
 xor ecx,ecx
.player:
 mov rax,[rsp+64+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,80
 jb .player
 mov r11,[r10+8]
 mov r10,[rsp+32]
 xor ecx,ecx
.inventory:
 mov rax,[r10+96+rcx]
 mov [r11+rcx],rax
 add ecx,8
 cmp ecx,336
 jb .inventory
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_player_decode,152
section .rdata
min_xz: dq -29999999.7
max_xz: dq 29999999.7
min_y: dq -255.0
max_y: dq 766.2
min_yaw: dd -3.141592654
max_yaw: dd 3.141592654
min_pitch: dd -1.5
max_pitch: dd 1.5
ELF_STACK
