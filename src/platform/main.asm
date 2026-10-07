%include "abi.inc"
section .text
extern puts, generate_section, fnv1a
FRAME main,40
 lea A0,[blocks]
 mov A1,42
 lea A2,[coords]
 call generate_section
 test rax,rax
 jnz .fail
 lea A0,[blocks]
 mov A1,8192
 call fnv1a
 ; Format the uint64 ourselves: no CRT-specific printf length modifiers.
 lea r10,[hex_digits]
 lea r11,[hash_slot+15]
 mov r9d,16
.hex:
 mov r8,rax
 and r8d,15
 mov r8b,[r10+r8]
 mov [r11],r8b
 shr rax,4
 dec r11
 dec r9d
 jnz .hex
 lea A0,[message]
 call puts
 xor eax,eax
 jmp .done
.fail:
 lea A0,[failure]
 call puts
 mov eax,1
.done:
END_FRAME main,40
section .rdata
hex_digits: db '0123456789abcdef'
failure: db 'Section generation failed.',0
align 8
coords: dq -1,4,0
section .data
message: db 'VoxelA headless prototype: seed=42 section=(-1,4,0) hash='
hash_slot: times 16 db '0'
db 0
section .bss align=16
blocks: resb 8192
ELF_STACK
