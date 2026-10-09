%include "abi.inc"
section .text
extern malloc, free, file_save, file_load, file_load_optional, region_encode, region_decode
FRAME region_file_save,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A0,131264
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+48],rax
 mov A0,[rsp+40]
 mov A1,rax
 mov A2,131264
 call region_encode
 test rax,rax
 js .release
 mov A2,rax
 mov A0,[rsp+32]
 mov A1,[rsp+48]
 call file_save
.release:
 mov [rsp+56],rax
 mov A0,[rsp+48]
 CCALL free
 mov rax,[rsp+56]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME region_file_save,72
%macro REGION_LOAD 2
FRAME %1,72
 mov [rsp+32],A0
 mov [rsp+40],A1
 mov A0,131264
 CCALL malloc
 test rax,rax
 jz .bad
 mov [rsp+48],rax
 mov A0,[rsp+32]
 mov A1,rax
 mov A2,131264
%if %2
 call file_load_optional
 cmp rax,-3
 jne .loaded
 mov eax,1
 jmp .release
.loaded:
%else
 call file_load
%endif
 test rax,rax
 js .release
 mov A1,rax
 mov A0,[rsp+48]
 mov A2,[rsp+40]
 call region_decode
.release:
 mov [rsp+56],rax
 mov A0,[rsp+48]
 CCALL free
 mov rax,[rsp+56]
 jmp .done
.bad: mov rax,-1
.done:
END_FRAME %1,72
%endmacro
REGION_LOAD region_file_load,0
REGION_LOAD region_file_load_optional,1
ELF_STACK
