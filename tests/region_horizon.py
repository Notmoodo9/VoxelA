"""Whole-mesh publication from exact saved terrain and bounded read transactions."""
import ctypes as C,struct,sys,tempfile,time
from pathlib import Path
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);close=bind('world_store_close',[P])
edit=bind('world_store_edit',[P,P,U]);surface=bind('world_store_surface',[P,I,I,P])
rinit=bind('region_init',[P,P]);save=bind('region_file_save',[P,P])
build=bind('region_horizon_build',[P,P])
def setup(root):
 pool=[C.create_string_buffer(131264) for _ in range(2)];stage=C.create_string_buffer(131264);entries=(U*8)()
 for i,p in enumerate(pool):entries[4*i]=C.addressof(p)
 store=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode())
 cfg=(U*6)(42,1,2,C.addressof(entries),C.addressof(path),C.addressof(stage))
 assert init(store,cfg)==0
 return store,pool,stage,entries,path,cfg
def snapshot(owner,root):return owner[0].raw,tuple(p.raw for p in owner[1]),owner[2].raw,bytes(owner[3]),{p.name:p.read_bytes() for p in root.iterdir()}
with tempfile.TemporaryDirectory(prefix='VoxelA exact horizon ') as folder:
 root=Path(folder);owner=setup(root)
 assert edit(owner[0],(I*3)(72,767,8),5)==1
 buf=C.create_string_buffer(b'Z'*(65536*32+32),65536*32+32)
 cfg=(U*8)(0,C.addressof(buf),65536,8,8,64,123,0)
 before=snapshot(owner,root);start=time.monotonic();assert build(owner[0],cfg)==0;seconds=time.monotonic()-start
 assert snapshot(owner,root)==before
 mesh=buf.raw[:cfg[6]*32];count=cfg[6];vertices=list(struct.iter_unpack('<8f',mesh))
 assert (72.,768.,8.) in [v[:3] for v in vertices]
 assert buf.raw[count*32:]==b'Z'*(len(buf)-count*32)
 # Actual sampled vertices agree with the storage oracle (seam-only bottoms
 # are allowed their documented inside-block constant height).
 result=C.create_string_buffer(8)
 for x,z in {(int(v[0]),int(v[2])) for v in vertices[:72]}:
  assert surface(owner[0],x,z,result)==0
  y=C.c_int32.from_buffer(result).value
  assert (float(x),float(y),float(z)) in [v[:3] for v in vertices]
 assert close(owner[0])==0;owner=setup(root)
 assert build(owner[0],cfg)==0 and cfg[6]==count and buf.raw[:count*32]==mesh
 # A later region-file failure preserves ALL visible vertices and count.
 bad=root/'r_1_0_47.vxr';wire=bad.read_bytes();bad.write_bytes(b'bad')
 before=snapshot(owner,root);old=buf.raw;cfg[6]=123
 assert build(owner[0],cfg)==-1 and cfg[6]==123 and buf.raw==old
 assert snapshot(owner,root)==before;bad.write_bytes(wire)
 cfg[2]=2;assert build(owner[0],cfg)==-2 and cfg[6]==123 and buf.raw==old;cfg[2]=65536
 assert close(owner[0])==0
 # Full recorded shaft at a sampled far vertex exercises negative Y meshes.
 for p in root.iterdir():p.unlink()
 region=C.create_string_buffer(131264)
 for sy in range(-16,48):
  assert rinit(region,(I*4)(42,1,0,sy))==0
  U.from_buffer(region,32).value=1
  C.c_uint32.from_buffer(region,64).value=1
  cells=(C.c_uint16*4096).from_buffer(region,192)
  if sy==-16:
   for i in range(256):cells[i]=7
  if sy==-13:cells[((-200&15)<<8)|136]=5
  assert save(C.create_string_buffer(str(root/f'r_1_0_{sy}.vxr').encode()),region)==0
 owner=setup(root);before=snapshot(owner,root)
 assert build(owner[0],cfg)==0 and snapshot(owner,root)==before
 assert (72.,-199.,8.) in [v[:3] for v in struct.iter_unpack('<8f',buf.raw[:cfg[6]*32])]
 assert close(owner[0])==0
print(f'PASS: {count} actual-region horizon vertices, dirty tower/restart, signed shaft, exact source samples, whole-mesh failure conservation; first64-block build {seconds:.6f}s (synchronous)')
