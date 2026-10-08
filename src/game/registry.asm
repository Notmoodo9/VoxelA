%include "abi.inc"
section .text
; ItemInfo16: u32 flags,maxStack,maxDurability,placementBlock.
; Flags:1 stackable,2 placeable,4 durable tool,8 container item.
; Registry1 remains frozen; registry2 adds table12,chest13 and placeable planks8.
; Invalid lookup writes nothing. Item0 and bedrock7 are not inventory items.
global item_info
item_info:
 mov r11,A2
 mov r10,A1
 mov r9,A1
 cmp r10,1
 jb .bad
 cmp r10,2
 ja .bad
 cmp A0,1
 jb .bad
 cmp A0,7
 je .bad
 mov eax,11
 cmp r10,1
 je .bound
 mov eax,13
.bound:
 cmp A0,rax
 ja .bad
 mov rax,A0
 shl rax,4
 lea r10,[items]
 add r10,rax
 mov rax,[r10]
 mov rdx,[r10+8]
 mov [r11],rax
 mov [r11+8],rdx
 ; Legacy planks are an ingredient, not a placement block.
 cmp r9,1
 jne .done
 cmp A0,8
 jne .done
 mov dword [r11],1
 mov dword [r11+12],0
.done: xor eax,eax
 ret
.bad: mov rax,-1
 ret
; BlockInfo16: u32 flags,droppedItem,sideTile,topTile.
; Flags:1 solid,2 opaque,4 breakable,8 cutout,16 container.
; Registry2 block8 planks,9 chest,10 crafting table. Mapping is explicit.
global block_info
block_info:
 mov r11,A2
 mov r10,A1
 cmp r10,1
 jb .bad
 cmp r10,2
 ja .bad
 mov eax,8
 cmp r10,1
 je .bound
 mov eax,11
.bound:
 cmp A0,rax
 jae .bad
 mov rax,A0
 shl rax,4
 lea r10,[blocks]
 add r10,rax
 mov rax,[r10]
 mov rdx,[r10+8]
 mov [r11],rax
 mov [r11+8],rdx
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; Slot8 validation via item metadata, including canonical empty records.
FRAME slot_valid,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,1
 jb .bad
 cmp A1,2
 ja .bad
 movzx eax,word [A0]
 test eax,eax
 jnz .occupied
 cmp qword [A0],0
 jne .bad
 xor eax,eax
 jmp .done
.occupied:
 mov A0,rax
 lea A2,[rsp+40] ; metadata overwrites saved registry only after lookup begins
 call item_info
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 cmp word [r10+6],0
 jne .bad
 movzx eax,word [r10+2]
 test eax,eax
 jz .bad
 cmp eax,[rsp+44]
 ja .bad
 movzx eax,word [r10+4]
 cmp dword [rsp+48],0
 jne .tool
 test eax,eax
 jnz .bad
 xor eax,eax
 jmp .done
.tool:
 test eax,eax
 jz .bad
 cmp eax,[rsp+48]
 ja .bad
 xor eax,eax
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME slot_valid,56
section .rdata align=8
items:
 dd 0,0,0,0 ; air not held
 dd 3,64,0,1
 dd 3,64,0,2
 dd 3,64,0,3
 dd 3,64,0,4
 dd 3,64,0,5
 dd 3,64,0,6
 dd 0,0,0,0 ; bedrock not held
 dd 3,64,0,8 ; planks
 dd 1,64,0,0 ; sticks
 dd 4,1,60,0
 dd 4,1,132,0
 dd 11,64,0,10 ; table item -> block10
 dd 11,64,0,9 ; chest item -> block9
blocks:
 dd 0,0,0,0
 dd 7,1,1,1
 dd 7,2,2,2
 dd 7,2,3,8 ; grass yields dirt
 dd 7,4,4,4
 dd 7,5,5,9
 dd 13,6,6,6
 dd 3,0,7,7
 dd 7,8,10,10
 dd 23,13,15,15
 dd 23,12,14,14
ELF_STACK
