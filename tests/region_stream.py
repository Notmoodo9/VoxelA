"""Region residency drives the existing first-person collision/ray/mesh systems."""
import ctypes as C
from pathlib import Path
import tempfile, sys, time
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);flush=bind('world_store_flush',[P]);close=bind('world_store_close',[P]);get=bind('world_store_get',[P,P]);attach=bind('region_stream_attach',[P,P,P,P]);detach=bind('region_stream_detach',[P,P]);sinit=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);sg=bind('stream_get',[P,P]);se=bind('stream_edit',[P,P,U]);find=bind('cache_find',[P,P]);ray=bind('world_raycast',[P,P,P]);pinit=bind('player_init',[P,P]);collides=bind('player_collides',[P,P]);mesh=bind('mesh_build',[P,P,P,U]);encode=bind('game_grid_encode',[P,P,P,P]);decode=bind('game_grid_decode',[P,U,P,P]);iinit=bind('inventory36_init',[P])
def setup(root):
 pool=[C.create_string_buffer(131264) for _ in range(64)];stage=C.create_string_buffer(131264);entries=(U*256)()
 for i,p in enumerate(pool):entries[i*4]=C.addressof(p)
 store=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode());cfg=(U*6)(42,1,64,C.addressof(entries),C.addressof(path),C.addressof(stage))
 assert init(store,cfg)==0
 return store,pool,stage,entries,path,cfg
world=(U*12)();oldentries=C.create_string_buffer(25600);oldblocks=C.create_string_buffer(3276800);journal=C.create_string_buffer(262144);config=(U*4)(42,C.addressof(oldentries),C.addressof(oldblocks),C.addressof(journal))
assert sinit(world,config)==0 and center(world,0,0)==1
player=C.create_string_buffer(80);inventory=C.create_string_buffer(336);assert pinit(player,(C.c_double*3)(.5,80,.5))==0 and iinit(inventory)==0
wire=C.create_string_buffer(262608);target=(U*2)(C.addressof(wire),262608);n=encode(world,player,inventory,target);assert n>0
legacy=bytes(world);legacybuffers=oldentries.raw+oldblocks.raw+journal.raw
bridge=C.create_string_buffer(176);coords=(I*3)();start=time.monotonic()
with tempfile.TemporaryDirectory(prefix='VoxelA region stream ') as folder:
 root=Path(folder);owner=setup(root);store=owner[0]
 # A failed first dirty flush must leave the live legacy world intact.
 locked=root/'r_-1_-1_-16.vxr.tmp';locked.write_bytes(b'other writer')
 assert attach(world,store,bridge,(I*2)(0,0))==-1
 assert bytes(world)==legacy and oldentries.raw+oldblocks.raw+journal.raw==legacybuffers
 assert U.from_buffer(bridge,160).value==0;locked.unlink()
 assert attach(world,store,bridge,(I*2)(0,0))==0
 assert world[2]==((1<<63)|1600) and world[3]==1600 and world[6]==(1<<64)-1
 before=bytes(world);assert attach(world,store,bridge,(I*2)(0,0))==-1 and bytes(world)==before
 for point in [(0,-256,0),(0,-200,0),(0,70,0),(0,767,0),(-32,100,-32),(47,70,47)]:
  coords[:]=point;assert sg(world,coords)==get(store,coords)
 coords[:]=(0,768,0);assert sg(world,coords)==-1
 coords[:]=(0,-257,0);assert sg(world,coords)==-1
 # Actual edited blocks participate in deep/high collision and first-person rays.
 for y in (-128,400):
  coords[:]=(0,y,0);assert se(world,coords,5)>=0 and sg(world,coords)==5
  assert pinit(player,(C.c_double*3)(.5,y,.5))==0 and collides(world,player)==1
  for z in (-2,-1):coords[:]=(0,y,z);assert se(world,coords,0)>=0
  r=(C.c_double*7)(.5,y+.5,-1.5,0,0,1,5);hit=C.create_string_buffer(72)
  assert ray(C.byref(world,8),r,hit)==1
  assert list((I*3).from_buffer(hit))==[0,y,0]
 # Bedrock and cached revision exhaustion reject without store mutation.
 coords[:]=(0,-256,0);assert se(world,coords,0)==-1 and sg(world,coords)==7
 entry=find(C.byref(world,8),(I*3)(0,25,0));assert entry
 revision=U.from_address(entry+40);saved=revision.value;revision.value=(1<<64)-1
 coords[:]=(0,401,0);old=get(store,coords);assert se(world,coords,6)==-1 and get(store,coords)==old
 revision.value=saved
 # Meshing consumes the copied actual region section, not a generator sample.
 neighbors=(U*6)();faces=C.create_string_buffer(24576*8)
 blockptr=U.from_address(entry+24).value;assert mesh(blockptr,neighbors,faces,24576)>0
 # Legacy snapshots cannot overwrite a callback-backed stream or its bridge.
 before=bytes(world)+player.raw+inventory.raw+bridge.raw
 bundle=(U*2)(C.addressof(player),C.addressof(inventory))
 assert decode(wire,n,world,bundle)==-1 and bytes(world)+player.raw+inventory.raw+bridge.raw==before
 before=wire.raw;assert encode(world,player,inventory,target)==-1 and wire.raw==before
 # Failed recenter retains complete residency, even while staging generated data.
 locked=root/'r_1_-1_-16.vxr.tmp';locked.write_bytes(b'other writer')
 before=bytes(world)+C.string_at(world[1],102400)+C.string_at(world[8],13107200)
 result=center(world,5,0);assert result==-1
 assert bytes(world)+C.string_at(world[1],102400)+C.string_at(world[8],13107200)==before
 locked.unlink();assert center(world,5,0)==1 and center(world,5,0)==0
 coords[:]=(0,400,0);assert sg(world,coords)==-1 # no longer resident
 assert center(world,0,0)==1 and sg(world,coords)==5
 assert oldentries.raw+oldblocks.raw+journal.raw==legacybuffers
 assert flush(store)==0 and detach(world,bridge)==0 and detach(world,bridge)==0
 assert bytes(world)==legacy and close(store)==0
 # Reattachment reloads durable deep/high edits into the same gameplay systems.
 owner=setup(root);assert attach(world,owner[0],bridge,(I*2)(0,0))==0
 for y in (-128,400):coords[:]=(0,y,0);assert sg(world,coords)==5
 assert detach(world,bridge)==0 and close(owner[0])==0
print(f'PASS: full-height region residency, actual physics/rays/mesh, edit durability, failed attach/recenter conservation, legacy snapshot guards and clean detach ({time.monotonic()-start:.2f}s)')
