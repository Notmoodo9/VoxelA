"""Exercise the opt-in region CLI through actual SDL input and autosave dispatch."""
import ctypes as C
import os, struct, subprocess, sys, tempfile
from pathlib import Path
binary=str(Path(sys.argv[1]).resolve());driver=str(Path(sys.argv[2]).resolve());lib=C.CDLL(sys.argv[3]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);height=bind('terrain_height',[U,I,I]);pinit=bind('player_init',[P,P]);iinit=bind('inventory36_init',[P]);encode=bind('game_grid_encode',[P,P,P,P])
world=(U*12)();entries=C.create_string_buffer(25600);blocks=C.create_string_buffer(3276800);journal=C.create_string_buffer(262144);player=C.create_string_buffer(80);inv=C.create_string_buffer(336)
cfg=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(journal));assert init(world,cfg)==0 and center(world,0,0)==1
assert pinit(player,(C.c_double*3)(.5,height(42,0,0)+1,.5))==0 and iinit(inv)==0
out=C.create_string_buffer(262608);target=(U*2)(C.addressof(out),262608);n=encode(world,player,inv,target);assert n==464
original=out.raw[:n]
with tempfile.TemporaryDirectory(prefix='VoxelA actual region window ') as folder:
 root=Path(folder);modern=root/'regions';modern.mkdir();(root/'voxela-world.vxa').write_bytes(original)
 env=os.environ.copy();env['LD_PRELOAD']=driver;env['XDG_DATA_HOME']=folder;env['VOXELA_REGION_EXIT_LOCK']=str(modern/'player.vxp.tmp')
 result=subprocess.run([binary,'--region-world',str(modern)],cwd=folder,env=env,capture_output=True,text=True,timeout=120)
 assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
 assert result.stdout.count('Saved terrain, player and inventory.')==1,result.stdout
 assert 'Loaded player and inventory.' in result.stdout and result.stdout.count('Autosave failed; previous save and live state retained.')==1,result.stdout
 assert result.stdout.count('Autosaved player and world.')>=3,result.stdout
 assert (root/'voxela-world.vxa').read_bytes()==original
 assert (modern/'upgrade-source.vxa').read_bytes()==original and (modern/'legacy-player.vxa').read_bytes()==original
 data=(modern/'player.vxp').read_bytes();assert len(data)==432 and data[:8]==b'VXAPLYR1'
 assert struct.unpack_from('<Q',data,16)[0]==42
 x,y,z=struct.unpack_from('<ddd',data,64);assert z<-16 and y>90,(x,y,z)
 inventory=data[96:];assert struct.unpack_from('<II',inventory,288)==(0,1) and inventory[304:]==bytes(32)
 assert struct.unpack_from('<H',inventory,2)[0]>32,'region mining did not collect items'
 h=0xcbf29ce484222325
 for i,b in enumerate(data):h=((h^(0 if 32<=i<40 else b))*0x100000001b3)&((1<<64)-1)
 assert struct.unpack_from('<Q',data,32)[0]==h
 versions=set();files=list(modern.glob('*.vxr'));assert len(files)>64
 for p in files:
  r=p.read_bytes();assert len(r)==131264
  mask=int.from_bytes(r[32:40],'little')
  for slot in range(16):
   if mask&(1<<slot):versions.add(int.from_bytes(r[64+slot*8:68+slot*8],'little'))
 assert versions=={0,1} and not list(modern.glob('*.tmp'))
 print(f'PASS: real --region-world CLI upgrade, SDL inventory/mining/flight/traversal (Z={z:.2f}), pause/periodic/exit saves, failed-quit retry, mixed regions and unchanged original snapshot')
