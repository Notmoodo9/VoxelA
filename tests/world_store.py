"""Real region-backed bounded world access, traversal, reload and safe failures."""
import ctypes as C
from pathlib import Path
import tempfile
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;SIZE=131264

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);get=bind('world_store_get',[P,P]);edit=bind('world_store_edit',[P,P,U]);flush=bind('world_store_flush',[P]);load_optional=bind('file_load_optional',[C.c_char_p,P,U])

def setup(root,capacity=1,seed=42,version=1):
 pool=[C.create_string_buffer(SIZE+32) for _ in range(capacity)];staged=C.create_string_buffer(SIZE+32);entries=(U*(capacity*4))()
 for i,buf in enumerate(pool):entries[i*4]=C.addressof(buf);C.memset(C.addressof(buf)+SIZE,0xa5,32)
 C.memset(C.addressof(staged)+SIZE,0xa5,32)
 ctx=C.create_string_buffer(b'\xa5'*1024,1024);rootbuf=C.create_string_buffer(str(root).encode())
 config=(U*6)(seed,version,capacity,C.addressof(entries),C.addressof(rootbuf),C.addressof(staged))
 assert init(ctx,config)==0
 return ctx,pool,staged,entries,rootbuf,config
coords=(I*3)();scratch=C.create_string_buffer(32)
with tempfile.TemporaryDirectory(prefix='VoxelA world store ') as folder:
 root=Path(folder);world=setup(root);ctx,pool,stage,entries,rootbuf,config=world
 assert load_optional(str(root/'absent').encode(),scratch,32)==-3
 bad=root/'bad';bad.write_bytes(b'x'*33);assert load_optional(str(bad).encode(),scratch,32)==-1
 # Traversal beyond capacity persists dirty regions before replacement.
 points=[(-1,70,-1),(64,120,64),(128,-128,-64),(-128,767,128),(29999999,-255,-30000000)]
 for point in points:
  coords[:]=point;assert get(ctx,coords)>=0
  assert edit(ctx,coords,5)>=0
 assert flush(ctx)==0
 world2=setup(root);ctx2=world2[0]
 for point in reversed(points):coords[:]=point;assert get(ctx2,coords)==5
 # Locked victim temporary prevents eviction and retains the current resident.
 coords[:]=points[-1];assert get(ctx,coords)==5 and edit(ctx,coords,6)==1
 rx,rz,sy=points[-1][0]//64,points[-1][2]//64,points[-1][1]//16
 temporary=root/f'r_{rx}_{rz}_{sy}.vxr.tmp';temporary.write_bytes(b'other writer')
 before=bytes(entries)+pool[0].raw;coords[:]=(512,70,512)
 assert get(ctx,coords)==-1 and bytes(entries)+pool[0].raw==before
 assert temporary.read_bytes()==b'other writer';temporary.unlink();assert flush(ctx)==0
 # Corrupt or incompatible existing files are never treated as absent.
 target=root/'r_8_8_4.vxr';target.write_bytes(b'broken')
 before=bytes(entries)+pool[0].raw;assert get(ctx,coords)==-1 and bytes(entries)+pool[0].raw==before and target.read_bytes()==b'broken'
 target.unlink();assert get(ctx,coords)>=0 and flush(ctx)==0
 mismatch=setup(root,seed=43);assert get(mismatch[0],coords)==-1
 raw=bytearray(target.read_bytes());raw[8:16]=(9).to_bytes(8,'little',signed=True)
 h=0xcbf29ce484222325
 for i,b in enumerate(raw):h=((h^(0 if 56<=i<64 else b))*0x100000001b3)&((1<<64)-1)
 raw[56:64]=h.to_bytes(8,'little');target.write_bytes(raw)
 other=setup(root);assert get(other[0],coords)==-1 and target.read_bytes()==raw
 for buf in pool:assert buf.raw[SIZE:]==b'\xa5'*32
 assert stage.raw[SIZE:]==b'\xa5'*32
 # Existing saved versions survive changing the default generator.
 mixed_dir=root/'mixed';mixed_dir.mkdir();old=setup(mixed_dir,version=0);coords[:]=(0,70,0)
 assert edit(old[0],coords,5)==1 and flush(old[0])==0
 new=setup(mixed_dir,version=1);assert get(new[0],coords)==5
 region_ptr=C.c_void_p.from_buffer(new[3],0).value
 assert C.c_uint32.from_address(region_ptr+64).value==0
 # Invalid config must preserve caller cache and ownership.
 before=new[0].raw+bytes(new[3]);missing=C.create_string_buffer(str(root/'missing-dir').encode());new[5][4]=C.addressof(missing)
 untouched=C.create_string_buffer(b'\xa5'*1024,1024);assert init(untouched,new[5])==-1 and untouched.raw==b'\xa5'*1024
 assert new[0].raw+bytes(new[3])==before
 # More than8192 distinct edits, using regions rather than a global journal.
 many_dir=root/'many';many_dir.mkdir();many=setup(many_dir,capacity=2,version=0)
 for i in range(8200):coords[:]=(i%64,70,i//64);assert edit(many[0],coords,5)>=0
 assert flush(many[0])==0
 reopened=setup(many_dir,version=1)
 for i in [0,4095,4096,8191,8192,8199]:coords[:]=(i%64,70,i//64);assert get(reopened[0],coords)==5
 # Close must not destroy dirty ownership after a failed flush.
 close=bind('world_store_close',[P]);coords[:]=(7,70,128)
 assert edit(reopened[0],coords,6)==1
 locked=many_dir/'r_0_2_4.vxr.tmp';locked.write_bytes(b'other writer')
 before=reopened[0].raw+bytes(reopened[3])+reopened[1][0].raw
 assert close(reopened[0])==-1 and reopened[0].raw+bytes(reopened[3])+reopened[1][0].raw==before
 locked.unlink();assert close(reopened[0])==0 and close(reopened[0])==0 and get(reopened[0],coords)==-1 and flush(reopened[0])==-1
 assert init(reopened[0],reopened[5])==0 and get(reopened[0],coords)==6 and close(reopened[0])==0
print('PASS: bounded region world get/edit/flush, eviction/restart,8200 edits, negative/vertical borders, mixed versions, missing vs corrupt data, failed flush and seed/identity rejection')
