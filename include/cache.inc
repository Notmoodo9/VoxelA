; Header: entries pointer, capacity, count. Caller allocates count*ENTRY_BYTES.
%define CACHE_BYTES 24
%define ENTRY_BYTES 64
%define ENTRY_BLOCKS 24
%define ENTRY_TOKEN 32
%define ENTRY_REVISION 40
%define ENTRY_SAVED 48
%define ENTRY_MESH_DIRTY 56
