%include "abi.inc"
section .text
%ifdef WINDOWS_ABI
 extern CreateFileA, WriteFile, ReadFile, FlushFileBuffers, CloseHandle
 extern DeleteFileA, MoveFileExA
%else
 extern open, write, read, fsync, close, unlink, rename, __errno_location
%endif
; Single calling thread. file_save(path,bytes,length)->0 committed,
; -1 failure before replacement, -2 replacement done but directory sync failed.
; path 1..959 bytes, same-directory exclusive .tmp, bounded 262352 bytes.
; An existing .tmp is NEVER overwritten/deleted (e.g. interrupted other writer).
; Windows paths use ANSI CreateFileA; Unicode-path adapter is future work.
FRAME file_save,2200
 mov [rsp+64],A1
 mov [rsp+72],A2
 mov [rsp+112],A0
 mov qword [rsp+80],-1
 mov qword [rsp+88],0
 mov qword [rsp+96],0 ; owns temporary
 mov qword [rsp+104],-1 ; outcome
 cmp A2,262352
 ja .done
 xor r10d,r10d
 mov r11,A0
.path:
 cmp r10,960
 jae .done
 mov al,[r11+r10]
 test al,al
 jz .end_path
 mov [rsp+r10+128],al
 mov [rsp+r10+1152],al
 inc r10
 jmp .path
.end_path:
 test r10,r10
 jz .done
 mov byte [rsp+r10+1152],0
 mov dword [rsp+r10+128],0x706d742e ; .tmp
 mov byte [rsp+r10+132],0
%ifdef WINDOWS_ABI
 lea A0,[rsp+128]
 mov A1,0x40000000 ; GENERIC_WRITE
 xor A2,A2 ; exclusive sharing
 xor A3,A3
 mov A4,1 ; CREATE_NEW
 mov A5,0x80 ; FILE_ATTRIBUTE_NORMAL
 mov A6,0
 CCALL CreateFileA
%else
 lea A0,[rsp+128]
 mov A1,0xa00c1 ; WRONLY|CREAT|EXCL|NOFOLLOW|CLOEXEC
 mov A2,384 ; 0600
 xor eax,eax ; variadic open
 CCALL open
 movsxd rax,eax
%endif
 cmp rax,-1
 je .done
 mov [rsp+80],rax
 mov qword [rsp+96],1
.write:
 mov r10,[rsp+88]
 cmp r10,[rsp+72]
 jae .flush
 mov A0,[rsp+80]
 mov A1,[rsp+64]
 add A1,r10
 mov A2,[rsp+72]
 sub A2,r10
%ifdef WINDOWS_ABI
 lea A3,[rsp+120]
 mov A4,0
 CCALL WriteFile
 test eax,eax
 jz .cleanup
 mov eax,[rsp+120]
%else
 CCALL write
 test rax,rax
 jns .wrote
 CCALL __errno_location
 cmp dword [rax],4 ; EINTR
 je .write
 jmp .cleanup
%endif
.wrote:
 test rax,rax
 jle .cleanup
 add [rsp+88],rax
 jmp .write
.flush:
 mov A0,[rsp+80]
%ifdef WINDOWS_ABI
 CCALL FlushFileBuffers
 test eax,eax
 jz .cleanup
%else
 CCALL fsync
 test eax,eax
 jnz .cleanup
%endif
 mov A0,[rsp+80]
 mov qword [rsp+80],-1
%ifdef WINDOWS_ABI
 CCALL CloseHandle
 test eax,eax
 jz .cleanup
 lea A0,[rsp+128]
 mov A1,[rsp+112]
 mov A2,9 ; REPLACE_EXISTING|WRITE_THROUGH
 CCALL MoveFileExA
 test eax,eax
 jz .cleanup
%else
 CCALL close
 test eax,eax
 jnz .cleanup
 lea A0,[rsp+128]
 mov A1,[rsp+112]
 CCALL rename
 test eax,eax
 jnz .cleanup
%endif
 mov qword [rsp+96],0
 mov qword [rsp+104],0
%ifndef WINDOWS_ABI
 ; Sync the containing directory AFTER successful replacement.
 ; Last slash wins, relative paths without slashes use '.'.
 xor r10d,r10d
 mov r11,-1
.parent:
 mov al,[rsp+r10+1152]
 test al,al
 jz .parent_end
 cmp al,'/'
 jne .parent_next
 mov r11,r10
.parent_next:
 inc r10
 jmp .parent
.parent_end:
 cmp r11,-1
 jne .slash
 mov word [rsp+1152],0x002e
 jmp .directory
.slash:
 test r11,r11
 jnz .terminate
 inc r11 ; retain root slash
.terminate:
 mov byte [rsp+r11+1152],0
.directory:
 lea A0,[rsp+1152]
 mov A1,0x90000 ; DIRECTORY|CLOEXEC
 xor eax,eax
 CCALL open
 test eax,eax
 js .uncertain
 movsxd rax,eax
 mov [rsp+80],rax
 mov A0,rax
 CCALL fsync
 test eax,eax
 jz .cleanup
.uncertain:
 mov qword [rsp+104],-2
%endif
.cleanup:
 cmp qword [rsp+80],-1
 je .temporary
 mov A0,[rsp+80]
%ifdef WINDOWS_ABI
 CCALL CloseHandle
%else
 CCALL close
%endif
.temporary:
 cmp qword [rsp+96],0
 je .done
 lea A0,[rsp+128]
%ifdef WINDOWS_ABI
 CCALL DeleteFileA
%else
 CCALL unlink
%endif
.done:
 mov rax,[rsp+104]
END_FRAME file_save,2200
; file_load(path,out,capacity)->byte count or -1, detects trailing bytes.
; Output is staging storage and MAY be partially written on error.
FRAME file_load,136
 mov [rsp+64],A1
 mov [rsp+72],A2
 mov qword [rsp+80],-1
 mov qword [rsp+88],0
 mov qword [rsp+104],-1
 cmp A2,262352
 ja .done
%ifdef WINDOWS_ABI
 mov A1,0x80000000 ; GENERIC_READ
 mov A2,1 ; share read only
 xor A3,A3
 mov A4,3 ; OPEN_EXISTING
 mov A5,0x80
 mov A6,0
 CCALL CreateFileA
%else
 mov A1,0xa0800 ; CLOEXEC|NOFOLLOW|NONBLOCK (avoid hanging on a FIFO)
 xor eax,eax
 CCALL open
 movsxd rax,eax
%endif
 cmp rax,-1
 je .done
 mov [rsp+80],rax
.read:
 mov r10,[rsp+88]
 mov A0,[rsp+80]
 mov A1,[rsp+64]
 add A1,r10
 mov A2,[rsp+72]
 sub A2,r10
 test A2,A2
 jnz .read_call
 ; Buffer is full: read one extra byte to reject oversized files.
 lea A1,[rsp+120]
 mov A2,1
.read_call:
%ifdef WINDOWS_ABI
 lea A3,[rsp+124]
 mov A4,0
 CCALL ReadFile
 test eax,eax
 jz .cleanup
 mov eax,[rsp+124]
%else
 CCALL read
 test rax,rax
 jns .read_result
 CCALL __errno_location
 cmp dword [rax],4
 je .read
 jmp .cleanup
%endif
.read_result:
 test rax,rax
 jz .eof
 cmp qword [rsp+88],262352
 jae .cleanup
 mov r10,[rsp+88]
 cmp r10,[rsp+72]
 jae .cleanup
 add [rsp+88],rax
 jmp .read
.eof:
 mov rax,[rsp+88]
 mov [rsp+104],rax
.cleanup:
 mov A0,[rsp+80]
%ifdef WINDOWS_ABI
 CCALL CloseHandle
 test eax,eax
 jnz .done
%else
 CCALL close
 test eax,eax
 jz .done
%endif
 mov qword [rsp+104],-1
.done:
 mov rax,[rsp+104]
END_FRAME file_load,136
ELF_STACK
