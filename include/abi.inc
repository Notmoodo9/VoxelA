%ifndef VOXELA_ABI
%define VOXELA_ABI
bits 64
default rel
%ifidn __OUTPUT_FORMAT__,win64
 %define WINDOWS_ABI 1
%endif
%ifdef WINDOWS_ABI
 %define A0 rcx
 %define A1 rdx
 %define A2 r8
 %define A3 r9
 %define A4 qword [rsp+32]
 %define A5 qword [rsp+40]
 %define A6 qword [rsp+48]
%else
 %define A0 rdi
 %define A1 rsi
 %define A2 rdx
 %define A3 rcx
 %define A4 r8
 %define A5 r9
 %define A6 qword [rsp]
%endif
; Only volatile integer registers and XMM0-5 may be clobbered.
; FRAME supplies aligned storage including Windows shadow space.
%macro FRAME 2
 %if %2 < 40 || %2 > 120 || (%2 % 16) != 8
  %error FRAME requires 40..120 bytes, congruent to 8 modulo 16
 %endif
 global %1
 %1:
 sub rsp,%2
 %1 %+ _prolog_end:
%endmacro
%macro END_FRAME 2
 add rsp,%2
 ret
 %1 %+ _end:
%ifidn __OUTPUT_FORMAT__,win64
 section .xdata rdata align=4
 %1 %+ _unwind:
 db 1, %1 %+ _prolog_end - %1, 1, 0
 db %1 %+ _prolog_end - %1, (((%2 / 8) - 1) << 4) | 2
 dw 0
 section .pdata rdata align=4
 dd %1 wrt ..imagebase
 dd %1 %+ _end wrt ..imagebase
 dd %1 %+ _unwind wrt ..imagebase
 section .text
%endif
%endmacro
; Position-independent calls to external shared-library functions.
%macro CCALL 1
%ifidn __OUTPUT_FORMAT__,elf64
 call %1 wrt ..plt
%else
 call %1
%endif
%endmacro
%macro ELF_STACK 0
%ifidn __OUTPUT_FORMAT__,elf64
 section .note.GNU-stack noalloc noexec nowrite progbits
%endif
%endmacro
%endif
