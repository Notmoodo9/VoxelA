%include "abi.inc"
section .text
extern inventory36_valid, inventory36_mine_duration
; Playable Survival policy, separate from frozen legacy inventory rules.
; Breakable blocks1..6 may be broken with anything. Unsuitable stone tools
; take six seconds and yield nothing; suitable picks retain800/400ms timing.
FRAME survival_mine_duration,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov A0,[rsp+32]
 mov A1,[rsp+40]
 call inventory36_mine_duration
 test rax,rax
 jns .done
 cmp qword [rsp+40],1
 jne .bad
 mov eax,6000
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME survival_mine_duration,56
; survival_mine_drop(Inventory304*,block)->item0..6 or-1.
; Query BEFORE tool wear, so a final-use suitable pick retains its drop.
FRAME survival_mine_drop,56
 mov [rsp+32],A0
 mov [rsp+40],A1
 cmp A1,1
 jb .bad
 cmp A1,6
 ja .bad
 call inventory36_valid
 test rax,rax
 jnz .bad
 mov r10,[rsp+32]
 cmp dword [r10+292],1
 je .none
 mov rax,[rsp+40]
 cmp rax,1
 jne .grass
 mov ecx,[r10+288]
 movzx ecx,word [r10+rcx*8]
 cmp ecx,10
 je .done
 cmp ecx,11
 je .done
.none: xor eax,eax
 jmp .done
.grass:
 cmp eax,3
 jne .done
 mov eax,2
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME survival_mine_drop,56
ELF_STACK
