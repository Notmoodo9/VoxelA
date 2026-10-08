"""Actual versioned region files: persistence, failed saves and staged reloads."""
import ctypes as C
from pathlib import Path
import sys
import tempfile
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;SIZE=131264

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('region_init',[P,P]);generate=bind('region_generate',[P,U,U]);edit=bind('region_edit',[P,P,U]);get=bind('region_get',[P,P]);save=bind('region_file_save',[C.c_char_p,P]);load=bind('region_file_load',[C.c_char_p,P])
region=C.create_string_buffer(SIZE);restored=C.create_string_buffer(b'\xa5'*SIZE,SIZE);cfg=(I*4)(42,-1,0,4)
assert init(region,cfg)==0
for slot in range(16):assert generate(region,slot,slot%2)==1
coords=(I*3)(-64,70,0);assert edit(region,coords,5)==1
with tempfile.TemporaryDirectory(prefix='VoxelA regions ') as folder:
 path=Path(folder)/'世界-region.vxr';encoded=str(path).encode('utf-8')
 assert save(encoded,region)==0 and path.stat().st_size==SIZE
 saved=path.read_bytes();assert load(encoded,restored)==0 and restored.raw==region.raw and get(restored,coords)==5
 # Regenerating recorded terrain cannot rewrite an old version after restart.
 before=restored.raw;assert generate(restored,0,1)==0 and restored.raw==before
 assert edit(region,coords,6)==1
 tmp=Path(str(path)+'.tmp');tmp.write_bytes(b'interrupted or other writer')
 assert save(encoded,region)==-1 and path.read_bytes()==saved and tmp.read_bytes()==b'interrupted or other writer'
 tmp.unlink();assert save(encoded,region)==0 and load(encoded,restored)==0 and get(restored,coords)==6
 before=restored.raw;valid=path.read_bytes()
 for bad in [valid[:-1],valid+b'x',valid[:100]+b'bad'+valid[103:]]:
  path.write_bytes(bad);assert load(encoded,restored)==-1 and restored.raw==before
 assert load(str(Path(folder)/'absent.vxr').encode(),restored)==-1 and restored.raw==before
 path.write_bytes(valid);region[68]=b'\x01'
 assert save(encoded,region)==-1 and path.read_bytes()==valid and not tmp.exists()
print('PASS: mixed version region files, Unicode filename, recorded terrain preservation, locked temporary, corrupt/trailing/missing data and atomic failures')
