"""Dirty-region cache ownership tested against real atomic filesystem saves."""
import ctypes as C
from pathlib import Path
import sys
import tempfile
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;SIZE=131264

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
ci=bind('region_cache_init',[P,P]);pub=bind('region_cache_publish',[P,U,P,U]);dirty=bind('region_cache_dirty',[P,U]);clean=bind('region_cache_clean',[P,U,U]);evict=bind('region_cache_evict',[P,U]);reserve=bind('region_cache_reserve',[P]);ri=bind('region_init',[P,P]);gen=bind('region_generate',[P,U,U]);edit=bind('region_edit',[P,P,U]);get=bind('region_get',[P,P]);save=bind('region_file_save',[C.c_char_p,P]);load=bind('region_file_load',[C.c_char_p,P])
resident=C.create_string_buffer(SIZE);staged=C.create_string_buffer(SIZE);entries=(U*4)(C.addressof(resident),0,0,0);ctx=(U*5)();cfg=(U*4)(42,1,1,C.addressof(entries));rcfg=(I*4)(42,0,0,4);xyz=(I*3)(0,70,0)
assert ci(ctx,cfg)==0 and ri(staged,rcfg)==0 and gen(staged,0,0)==1 and pub(ctx,0,staged,0)==1
with tempfile.TemporaryDirectory(prefix='VoxelA cache eviction ') as folder:
 path=Path(folder)/'region.vxr';encoded=str(path).encode();tmp=Path(str(path)+'.tmp')
 tmp.write_bytes(b'other writer');before=resident.raw+bytes(entries)+bytes(ctx)
 assert save(encoded,resident)==-1 and reserve(ctx)==-2 and evict(ctx,0)==-2
 assert resident.raw+bytes(entries)+bytes(ctx)==before and tmp.read_bytes()==b'other writer'
 tmp.unlink();revision=C.c_uint64.from_buffer(resident,40).value
 assert save(encoded,resident)==0
 # A write completed at an old revision may not mark a newer edit clean.
 assert edit(resident,xyz,5)==1 and clean(ctx,0,revision)==-1 and dirty(ctx,0)==1 and evict(ctx,0)==-2
 assert save(encoded,resident)==0
 revision=C.c_uint64.from_buffer(resident,40).value
 assert clean(ctx,0,revision)==0 and reserve(ctx)==0 and evict(ctx,0)==1
 rcfg[:]=(42,1,0,4);assert ri(staged,rcfg)==0 and gen(staged,0,1)==1
 farpath=str(Path(folder)/'far-region.vxr').encode()
 assert save(farpath,staged)==0 and load(farpath,staged)==0 and pub(ctx,0,staged,1)==1
 # Load and validate before reusing the live destination for the original region.
 assert load(encoded,staged)==0 and get(staged,xyz)==5
 assert pub(ctx,0,staged,1)==1 and dirty(ctx,0)==0 and get(resident,xyz)==5
 before=resident.raw+bytes(entries)+bytes(ctx);data=bytearray(path.read_bytes());data[192]^=1;path.write_bytes(data)
 assert load(encoded,staged)==-1 and resident.raw+bytes(entries)+bytes(ctx)==before
print('PASS: failed flush preserves dirty resident, stale-save revision rejected, clean eviction/reload retains edits and invalid loads preserve cache')
