"""Actual saved old terrain drives new-side blending without changing old files."""
import ctypes as C
from pathlib import Path
import tempfile, sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);acquire=bind('world_store_acquire',[P,P]);get=bind('world_store_get',[P,P]);edit=bind('world_store_edit',[P,P,U]);close=bind('world_store_close',[P]);blend=bind('terrain1_blend_column',[U,P,P,P]);block=bind('generated_block1',[U,P,P]);flush=bind('world_store_flush',[P]);resolve=bind('world_store_blend_profile',[P,P,P,P]);rinit=bind('region_init',[P,P])
def setup(root,version=1,capacity=1):
 pool=[C.create_string_buffer(131264) for _ in range(capacity)];stage=C.create_string_buffer(131264);entries=(U*(capacity*4))()
 for i,p in enumerate(pool):entries[4*i]=C.addressof(p)
 ctx=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode());cfg=(U*6)(42,version,capacity,C.addressof(entries),C.addressof(path),C.addressof(stage))
 assert init(ctx,cfg)==0
 return ctx,pool,stage,entries,path,cfg
profile=C.create_string_buffer(264);heights=(C.c_int32*64).from_buffer(profile,8);column=C.create_string_buffer(32);coords=(I*3)()
with tempfile.TemporaryDirectory(prefix='VoxelA actual terrain blend ') as folder:
 root=Path(folder);old=setup(root,0,16)
 for sy in range(16):coords[:]=(-1,sy*16,0);assert acquire(old[0],coords)>=0
 # Floating edited blocks are the recorded highest surface, not old seed height.
 for z in range(16):coords[:]=(-1,90+z,z);assert edit(old[0],coords,5)==1
 # Resolver must include dirty resident data without flushing or altering it.
 current=C.create_string_buffer(131264);assert rinit(current,(I*4)(42,0,0,5))==0
 before=old[0].raw+bytes(old[3])+b''.join(x.raw for x in old[1])
 assert resolve(old[0],(I*3)(0,5,0),current,profile)==0
 assert U.from_buffer(profile).value==1 and list(heights[:16])==list(range(90,106))
 assert old[0].raw+bytes(old[3])+b''.join(x.raw for x in old[1])==before
 assert close(old[0])==0
 preserved={p.name:p.read_bytes() for p in root.glob('*.vxr')}
 new=setup(root)
 # New blocks use the same profile at all vertical levels and survive restart.
 samples={}
 for y in (-256,-128,0,64,80,90,105,112,767):
  for x,z in [(0,0),(0,15),(1,7),(8,8),(15,15)]:
   coords[:]=(x,y,z);assert blend(42,coords,profile,column)==0
   expected=block(42,coords,column);assert get(new[0],coords)==expected
   samples[(x,y,z)]=expected
 assert close(new[0])==0
 for name,wire in preserved.items():assert (root/name).read_bytes()==wire
 restarted=setup(root)
 for point,expected in samples.items():coords[:]=point;assert get(restarted[0],coords)==expected
 coords[:]=(0,90,0);expected=samples[(0,90,0)]
 # Corrupt neighboring data cannot affect a recorded section lookup, but blocks
 # generation of an absent section; dirty resident ownership must be conserved.
 corrupt=root/'r_-1_0_7.vxr';wire=corrupt.read_bytes();corrupt.write_bytes(b'corrupt')
 assert get(restarted[0],coords)==expected
 coords[:]=(0,200,0);before=restarted[0].raw+bytes(restarted[3])+restarted[1][0].raw
 assert get(restarted[0],coords)==-1
 assert restarted[0].raw+bytes(restarted[3])+restarted[1][0].raw==before
 corrupt.write_bytes(wire);assert get(restarted[0],coords)>=0
 # An incomplete old column supplies no fabricated profile.
 partial=root/'partial';partial.mkdir();owner=setup(partial,0)
 coords[:]=(-1,64,0);assert acquire(owner[0],coords)>=0 and close(owner[0])==0
 fresh=setup(partial);assert resolve(fresh[0],(I*3)(0,4,0),current,profile)==0 and U.from_buffer(profile).value==0
 # Generation order cannot change transitions when recorded old inputs match.
 order_points=[(0,80,0),(15,100,15),(0,-200,15),(8,120,8),(1,65,7)]
 outcomes=[]
 for label,points in [('forward',order_points),('reverse',list(reversed(order_points)))]:
  directory=root/label;directory.mkdir()
  for name,data in preserved.items():(directory/name).write_bytes(data)
  owner=setup(directory)
  for point in points:coords[:]=point;assert get(owner[0],coords)>=0
  assert close(owner[0])==0
  outcomes.append({p.name:p.read_bytes() for p in directory.glob('*.vxr')})
 assert outcomes[0]==outcomes[1]
 # All four faces in one mixed region exercise staged-region lookup and
 # signed coordinates. Old section bytes survive publishing new sibling slots.
 shared=root/'shared';shared.mkdir();owner=setup(shared,0)
 neighbors=[(-3,-3),(-1,-3),(-2,-4),(-2,-2)]
 for sx,sz in neighbors:
  for sy in range(16):coords[:]=(sx*16,sy*16,sz*16);assert acquire(owner[0],coords)>=0
 for face in range(4):
  for i in range(16):
   x,z=((-33,-48+i) if face==0 else (-16,-48+i) if face==1 else (-32+i,-49) if face==2 else (-32+i,-32))
   coords[:]=(x,80+face*20+i,z);assert edit(owner[0],coords,5)==1
 assert close(owner[0])==0
 original={p.name:p.read_bytes() for p in shared.glob('*.vxr')};owner=setup(shared)
 coords[:]=(-32,100,-48);idx=acquire(owner[0],coords);assert idx>=0
 resident=C.c_void_p.from_buffer(owner[3],idx*32).value
 assert resolve(owner[0],(I*3)(-2,6,-3),resident,profile)==0 and U.from_buffer(profile).value==15
 for face in range(4):assert list(heights[face*16:face*16+16])==list(range(80+face*20,96+face*20))
 for x,y,z in [(-32,100,-48),(-17,100,-33),(-24,100,-40),(-31,80,-47),(-32,767,-33)]:
  coords[:]=(x,y,z);assert blend(42,coords,profile,column)==0 and get(owner[0],coords)==block(42,coords,column)
 assert close(owner[0])==0
 for name,data in original.items():
  after=(shared/name).read_bytes();oldmask=int.from_bytes(data[32:40],'little')
  for slot in range(16):
   if oldmask&(1<<slot):
    assert after[64+slot*8:72+slot*8]==data[64+slot*8:72+slot*8]
    start=192+slot*8192;assert after[start:start+8192]==data[start:start+8192]
 # Out-of-world neighbors are skipped, including signed negative borders.
 edge=root/'edge';edge.mkdir();owner=setup(edge)
 coords[:]=(-30000000,-256,29999999);assert get(owner[0],coords)==7 and close(owner[0])==0
print('PASS: actual edited old profiles from dirty cache/files, new-side full-height blocks, unchanged old files, restart stability, corrupt-neighbor rejection and incomplete/border handling')
