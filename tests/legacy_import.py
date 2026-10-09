"""Real-file legacy migration, immutable source and resumable checkpoints."""
import ctypes as C
from pathlib import Path
import tempfile, sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
sinit=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);sedit=bind('stream_edit',[P,P,U]);pinit=bind('player_init',[P,P]);iinit=bind('inventory36_init',[P]);encode=bind('game_grid_encode',[P,P,P,P]);height=bind('terrain_height',[U,I,I])
init=bind('world_store_init',[P,P]);get=bind('world_store_get',[P,P]);edit=bind('world_store_edit',[P,P,U]);flush=bind('world_store_flush',[P]);migrate=bind('world_store_import_legacy',[P,P,U])
world=(U*12)();entries=C.create_string_buffer(25600);blocks=C.create_string_buffer(3276800);journal=C.create_string_buffer(262144);player=C.create_string_buffer(80);inv=C.create_string_buffer(336)
cfg=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(journal))
assert sinit(world,cfg)==0 and center(world,0,0)==1
assert pinit(player,(C.c_double*3)(.5,height(42,0,0)+1,.5))==0 and iinit(inv)==0
point=(I*3)(1024,100,-1024)
record=(I*4).from_buffer(journal);record[:]=(1024,100,-1024,5);world[6]=1
out=C.create_string_buffer(262608);target=(U*2)(C.addressof(out),262608);n=encode(world,player,inv,target);assert n>0
source=out.raw[:n];inputbuf=C.create_string_buffer(source)
def setup(root):
 pool=C.create_string_buffer(131264);stage=C.create_string_buffer(131264);entry=(U*4)(C.addressof(pool),0,0,0);ctx=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode());config=(U*6)(42,1,1,C.addressof(entry),C.addressof(path),C.addressof(stage))
 assert init(ctx,config)==0
 return ctx,pool,stage,entry,path,config
with tempfile.TemporaryDirectory(prefix='VoxelA legacy import ') as folder:
 root=Path(folder);owner=setup(root);ctx=owner[0]
 corrupt=bytearray(source);corrupt[-1]^=128
 assert migrate(ctx,C.create_string_buffer(bytes(corrupt)),n)==-1 and not list(root.iterdir())
 wrong=bytearray(source);wrong[24:32]=(43).to_bytes(8,'little');h=0xcbf29ce484222325
 for i,b in enumerate(wrong):h=((h^(0 if 40<=i<48 else b))*0x100000001b3)&((1<<64)-1)
 wrong[40:48]=h.to_bytes(8,'little')
 assert migrate(ctx,C.create_string_buffer(bytes(wrong)),n)==-1 and not list(root.iterdir())

 # Interrupted first flush cannot publish the completion checkpoint.
 locked=root/'r_-1_-1_0.vxr.tmp';locked.write_bytes(b'other writer')
 assert migrate(ctx,inputbuf,n)<0 and not (root/'legacy-player.vxa').exists()
 assert U.from_buffer(ctx,8).value==1 and locked.read_bytes()==b'other writer'
 locked.unlink();assert migrate(ctx,inputbuf,n)==0
 assert inputbuf.raw[:n]==source and (root/'legacy-player.vxa').read_bytes()==source
 assert U.from_buffer(ctx,8).value==1
 assert get(ctx,point)==5
 for sy in range(16):
  data=(root/f'r_16_-16_{sy}.vxr').read_bytes()
  assert int.from_bytes(data[32:40],'little')&1 and int.from_bytes(data[64:68],'little')==0
 # Completed import must never replay journal over subsequent edits.
 assert edit(ctx,point,6)==1 and flush(ctx)==0
 assert migrate(ctx,inputbuf,n)==0 and get(ctx,point)==6
 restarted=setup(root);assert get(restarted[0],point)==6
 fresh=(I*3)(2048,-128,2048);assert get(ctx,fresh)>=0 and flush(ctx)==0
 data=(root/'r_32_32_-8.vxr').read_bytes();assert int.from_bytes(data[64:68],'little')==1
 (root/'legacy-player.vxa').write_bytes(b'incompatible checkpoint')
 assert migrate(ctx,inputbuf,n)==-1 and get(ctx,point)==6
 finalfail=root/'finalfail';finalfail.mkdir();pending=setup(finalfail)
 marker=finalfail/'legacy-player.vxa.tmp';marker.write_bytes(b'other writer')
 assert migrate(pending[0],inputbuf,n)==-1 and not (finalfail/'legacy-player.vxa').exists()
 assert list(finalfail.glob('*.vxr')) and get(pending[0],point)==5
 marker.unlink();assert migrate(pending[0],inputbuf,n)==0
 assert (finalfail/'legacy-player.vxa').read_bytes()==source
 conflict=root/'conflict';conflict.mkdir();other=setup(conflict)
 assert get(other[0],(I*3)(-32,0,-32))>=0 and flush(other[0])==0
 assert migrate(other[0],inputbuf,n)==-1 and not (conflict/'legacy-player.vxa').exists()
 assert U.from_buffer(other[0],8).value==1
# Exercise each older snapshot encoding through the migration entry point.
old1=bind('walk_encode',[P,P,P,U]);old2=bind('game_encode',[P,P,P,P]);old3=bind('game36_encode',[P,P,P,P]);oldinit=bind('inventory_init',[P]);oldinv=C.create_string_buffer(80);assert oldinit(oldinv)==0
with tempfile.TemporaryDirectory(prefix='VoxelA old formats ') as folder:
 for version in (1,2,3):
  root=Path(folder)/str(version);root.mkdir();owner=setup(root)
  if version==1: count=old1(world,player,out,262608)
  elif version==2: count=old2(world,player,oldinv,target)
  else: count=old3(world,player,inv,target)
  assert count>0
  wire=out.raw[:count];assert migrate(owner[0],C.create_string_buffer(wire),count)==0
  assert (root/'legacy-player.vxa').read_bytes()==wire and get(owner[0],point)==5
print('PASS: legacy migration validates before mutation, preserves old columns/edits, resumes interrupted writes, checkpoints last, retains later edits and rejects generator conflicts')
