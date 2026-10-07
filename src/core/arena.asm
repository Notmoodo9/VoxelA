%include "abi.inc"
; Arena layout: base pointer at 0, capacity at 8, used at 16,
; high-water mark at 24; total 32 bytes. Caller owns arena and backing memory.
; Single-threaded: no synchronization; reset invalidates all allocations.
section .text
; arena_init(arena*,backing*,capacity)->0. Nonnull valid writable buffers.
global arena_init
arena_init:
 mov [A0],A1
 mov [A0+8],A2
 mov qword [A0+16],0
 mov qword [A0+24],0
 xor eax,eax
 ret
; arena_reset(arena*)->0. Keeps capacity/base/high-water mark.
global arena_reset
arena_reset:
 mov qword [A0+16],0
 xor eax,eax
 ret
; arena_alloc(arena*,size,alignment)->pointer or NULL.
; Size must be nonzero; alignment power-of-two in 1..4096.
; Validates arithmetic and capacity before committing used/high-water.
; Failure does not mutate the arena. Clobbers volatile integer regs, flags.
global arena_alloc
arena_alloc:
 mov r10,A0
 mov r11,A1
 mov r9,A2
 test r11,r11
 jz .bad
 test r9,r9
 jz .bad
 cmp r9,4096
 ja .bad
 lea rax,[r9-1]
 test r9,rax
 jnz .bad
 mov r8,[r10]
 add r8,[r10+16]
 jc .bad
 add r8,rax
 jc .bad
 not rax
 and r8,rax
 mov rax,r8
 sub rax,[r10]
 jc .bad
 add rax,r11
 jc .bad
 cmp rax,[r10+8]
 ja .bad
 mov [r10+16],rax
 cmp rax,[r10+24]
 jbe .return
 mov [r10+24],rax
.return:
 mov rax,r8
 ret
.bad:
 xor eax,eax
 ret
ELF_STACK
