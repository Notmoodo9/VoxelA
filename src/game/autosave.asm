%include "abi.inc"
section .text
; Clock16: u32 lastSuccess,lastAttempt,initialized,lastResult; unsigned SDL ticks.
global autosave_init
autosave_init:
 mov rax,A1
 shr rax,32
 jnz .bad
 mov rax,A1
 mov [A0],eax
 mov [A0+4],eax
 mov dword [A0+8],1
 mov dword [A0+12],0
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
; autosave_poll(clock,tick,reason0periodic/1pause/2exit)->1 attempt,0 wait,-1 invalid.
global autosave_poll
autosave_poll:
 cmp dword [A0+8],1
 jne .bad
 cmp A2,2
 ja .bad
 mov rax,A1
 shr rax,32
 jnz .bad
 mov rax,A1
 test A2,A2
 jnz .due
 mov r10d,eax
 sub r10d,[A0]
 cmp r10d,300000
 jb .wait
 mov r10d,eax
 sub r10d,[A0+4]
 cmp r10d,10000
 jb .wait
.due:
 mov [A0+4],eax
 mov eax,1
 ret
.wait: xor eax,eax
 ret
.bad: mov rax,-1
 ret
; autosave_finish(clock,tick,result0success/nonzero failure).
global autosave_finish
autosave_finish:
 cmp dword [A0+8],1
 jne .bad
 mov rax,A1
 shr rax,32
 jnz .bad
 mov rax,A1
 mov [A0+4],eax
 test A2,A2
 jnz .failed
 mov [A0],eax
 mov dword [A0+12],0
 xor eax,eax
 ret
.failed:
 mov dword [A0+12],-1
 xor eax,eax
 ret
.bad: mov rax,-1
 ret
ELF_STACK
