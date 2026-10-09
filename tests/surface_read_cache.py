"""Bounded transaction cache: validated records, negative probes, exact samples."""
import ctypes as C
from pathlib import Path
import tempfile,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);close=bind('world_store_close',[P])
edit=bind('world_store_edit',[P,P,U]);get=bind('world_store_get',[P,P])
rinit=bind('region_init',[P,P]);save=bind('region_file_save',[P,P])
start=bind('surface_read_init',[P,P]);stop=bind('surface_read_close',[P])
read=bind('surface_read_region',[P,P]);sample=bind('world_surface_sample',[P,I,I,P])
oracle=bind('world_store_surface',[P,I,I,P])

def setup(root):
 pool=[C.create_string_buffer(131264) for _ in range(2)];stage=C.create_string_buffer(131264)
 entries=(U*8)()
 for i,p in enumerate(pool):entries[i*4]=C.addressof(p)
 store=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode())
 cfg=(U*6)(42,1,2,C.addressof(entries),C.addressof(path),C.addressof(stage))
 assert init(store,cfg)==0
 return store,pool,stage,entries,path,cfg

def snapshot(owner):return owner[0].raw,tuple(p.raw for p in owner[1]),owner[2].raw,bytes(owner[3])
with tempfile.TemporaryDirectory(prefix='VoxelA surface read cache ') as folder:
 root=Path(folder);owner=setup(root);ctx=C.create_string_buffer(64);out=C.create_string_buffer(8);expected=C.create_string_buffer(8)
 assert start(ctx,owner[0])==0
 before=ctx.raw;assert start(ctx,owner[0])==-1 and ctx.raw==before
 key=(I*3)(0,0,47);before=snapshot(owner)
 assert read(ctx,key)==0
 probes=U.from_buffer(ctx,24).value
 assert read(ctx,key)==0 and U.from_buffer(ctx,24).value==probes and U.from_buffer(ctx,40).value==1
 for x,z in [(8,8),(8,9),(-1,-1),(63,64),(-30000000,29999999)]:
  assert oracle(owner[0],x,z,expected)==0 and sample(ctx,x,z,out)==0 and out.raw==expected.raw
 assert snapshot(owner)==before and not list(root.iterdir())
 # Repeated samples avoid all additional region-file probes.
 assert sample(ctx,8,8,out)==0;probes=U.from_buffer(ctx,24).value
 assert sample(ctx,8,8,out)==0 and U.from_buffer(ctx,24).value==probes
 assert stop(ctx)==0 and ctx.raw==bytes(64) and stop(ctx)==0
 out.raw=b'CANARY!!';assert sample(ctx,8,8,out)==-1 and out.raw==b'CANARY!!'
 # More than64 present files exercise bounded replacement with exact bytes.
 region=C.create_string_buffer(131264)
 for rx in range(65):
  assert rinit(region,(I*4)(42,rx,0,47))==0
  assert save(C.create_string_buffer(str(root/f'r_{rx}_0_47.vxr').encode()),region)==0
 assert start(ctx,owner[0])==0
 for rx in range(65):
  key[:]=(rx,0,47);ptr=read(ctx,key);assert ptr>0 and C.string_at(ptr,131264)==(root/f'r_{rx}_0_47.vxr').read_bytes()[:56]+bytes(8)+(root/f'r_{rx}_0_47.vxr').read_bytes()[64:]
 key[:]=(64,0,47);probes=U.from_buffer(ctx,24).value;assert read(ctx,key)>0 and U.from_buffer(ctx,24).value==probes
 key[:]=(0,0,47);assert read(ctx,key)>0 and U.from_buffer(ctx,24).value==probes+1
 assert snapshot(owner)==before and stop(ctx)==0
 # Fill beyond the negative table capacity. Limited probing must fall back
 # to exact I/O rather than hang, fabricate presence or overrun memory.
 assert start(ctx,owner[0])==0
 for rx in range(8200):
  key[:]=(rx,0,46);assert read(ctx,key)==0
 assert stop(ctx)==0 and snapshot(owner)==before
 # Corrupt/wrong-seed/wrong-key failures do not enter the cache as missing.
 target=root/'r_0_0_47.vxr';wire=target.read_bytes()
 for kind in ('corrupt','seed','key'):
  if kind=='corrupt':target.write_bytes(b'bad')
  else:
   assert rinit(region,(I*4)(43 if kind=='seed' else 42,1 if kind=='key' else 0,0,47))==0
   assert save(C.create_string_buffer(str(target).encode()),region)==0
  assert start(ctx,owner[0])==0;key[:]=(0,0,47)
  assert read(ctx,key)==-1 and read(ctx,key)==-1 and U.from_buffer(ctx,24).value==2
  assert stop(ctx)==0;target.write_bytes(wire)
 # Dirty residents take priority over persisted cache snapshots. Start a new
 # read transaction after world writes, as required by the cache contract.
 assert edit(owner[0],(I*3)(8,767,8),5)==1
 before=snapshot(owner);assert start(ctx,owner[0])==0
 assert sample(ctx,8,8,out)==0 and out.raw==(768).to_bytes(4,'little',signed=True)+(5).to_bytes(4,'little')
 assert snapshot(owner)==before and stop(ctx)==0
 assert close(owner[0])==0
 assert start(ctx,owner[0])==-1 and ctx.raw==bytes(64)
print('PASS: exact cached/oracle samples, repeated/missing hits, 65-file bounded replacement, corruption/identity retries, dirty priority and untouched world ownership')
