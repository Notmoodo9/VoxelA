%include "abi.inc"
%include "world.inc"
section .text
; floor_section(axis)-> signed floor(axis/16), including INT64_MIN.
global floor_section
floor_section:
 mov rax,A0
 sar rax,4
 ret
; local_axis(axis)->0..15.
global local_axis
local_axis:
 mov rax,A0
 and eax,15
 ret
; block_index(x,y,z)->0..4095 or -1. All inputs unsigned 64-bit.
global block_index
block_index:
 cmp A0,16
 jae .bad
 cmp A1,16
 jae .bad
 cmp A2,16
 jae .bad
 mov rax,A1
 shl eax,4
 add rax,A2
 shl eax,4
 add rax,A0
 ret
.bad:
 mov rax,-1
 ret
; world_in_bounds(x,y,z)->1 inside world, 0 otherwise.
global world_in_bounds
world_in_bounds:
 xor eax,eax
 cmp A0,WORLD_MIN
 jl .done
 cmp A0,WORLD_MAX
 jge .done
 cmp A2,WORLD_MIN
 jl .done
 cmp A2,WORLD_MAX
 jge .done
 cmp A1,256
 jae .done
 inc eax
.done:
 ret
; section_get(buffer,index)->block ID, or -1 for invalid index.
; Caller owns a readable SECTION_BYTES buffer, pointer must be nonnull.
global section_get
section_get:
 cmp A1,SECTION_CELLS
 jae .bad
 movzx eax,word [A0+A1*2]
 ret
.bad:
 mov rax,-1
 ret
; section_set(buffer,index,id)->0 success, -1 invalid. No dirty tracking yet.
global section_set
section_set:
 cmp A1,SECTION_CELLS
 jae .bad
 cmp A2,BLOCK_COUNT
 jae .bad
 mov r10,A2
 mov word [A0+A1*2],r10w
 xor eax,eax
 ret
.bad:
 mov rax,-1
 ret
; block_flags(id)->bit0 solid, bit1 opaque, bit2 breakable, bit3 cutout;
; invalid -> -1. Bedrock solid/opaque but not breakable.
global block_flags
block_flags:
 cmp A0,BLOCK_COUNT
 jae .bad
 lea r10,[flags]
 movzx eax,byte [r10+A0]
 ret
.bad:
 mov rax,-1
 ret
section .rdata align=8
flags: db 0,7,7,7,7,7,13,3
ELF_STACK
