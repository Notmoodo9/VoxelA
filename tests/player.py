"""Stream residency, deterministic regeneration, journal and player physics."""
import ctypes as C
import math
import random
import sys
lib=C.CDLL(sys.argv[1])
def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=C.c_int64;return f
P=C.c_void_p;U=C.c_uint64;I=C.c_int64
init=bind('stream_init',[P,P]);recenter=bind('stream_recenter',[P,I,I])
get=bind('stream_get',[P,P]);edit=bind('stream_edit',[P,P,U]);generated=bind('generated_block',[U,P])
pinit=bind('player_init',[P,P]);look=bind('player_look',[P,I,I]);step=bind('player_step',[P,P,U,U])
collides=bind('player_collides',[P,P]);ray=bind('player_ray',[P,P]);overlap=bind('player_overlaps_cell',[P,P]);resize=bind('player_resize',[P,U,U])
world=(U*12)();entries=(C.c_ubyte*(400*64))();blocks=(C.c_uint16*(400*4096))();edits=(I*(8192*4))()
config=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(edits))
checks=0
def check(v,msg='player/stream assertion'):
 global checks
 checks+=1
 assert v,msg
check(init(world,config)==0);check(recenter(world,0,0)==1);check(recenter(world,0,0)==0)
check(world[3]==400 and world[9]==1)
coords=lambda x,y,z:(I*3)(x,y,z)
rng=random.Random(488)
for _ in range(2000):
 p=coords(rng.randrange(-32,48),rng.randrange(256),rng.randrange(-32,48))
 check(get(world,p)==generated(42,p),'streamed block differs from generator')
position=coords(15,79,15);original=get(world,position);replacement=0 if original else 5
check(edit(world,position,replacement)==1);check(world[6]==1)
check(edit(world,position,replacement)==0)
check(recenter(world,20,-10)==1);check(get(world,position)==-1)
check(recenter(world,0,0)==1);check(get(world,position)==replacement,'edit lost on eviction')
check(edit(world,position,original)==1 and world[6]==0,'baseline override not removed')
check(edit(world,coords(0,0,0),0)==-1,'bedrock removable')
check(edit(world,coords(0,80,0),7)==-1)
before=bytes(world)
check(recenter(world,1875000,0)==-1 and bytes(world)==before)
check(recenter(world,-4,-3)==1)
for _ in range(200):
 p=coords(rng.randrange(-96,-16),rng.randrange(256),rng.randrange(-80,0))
 check(get(world,p)==generated(42,p),'negative ring mapping')
check(recenter(world,0,0)==1)
# Make a flat independent fixture in the resident blocks: floor Y=64, otherwise air.
for i in range(400):
 sx,sy,sz,ptr=C.cast(C.addressof(entries)+i*64,C.POINTER(I))[:4]
 view=(C.c_uint16*4096).from_address(ptr)
 C.memset(ptr,0,8192)
 if sy==4:
  for j in range(256):view[j]=1
player=(C.c_ubyte*80)()
feet=(C.c_double*3)(0.5,65.0,0.5)
check(pinit(player,feet)==0)
def doubles():return C.cast(player,C.POINTER(C.c_double))
def ints():return C.cast(player,C.POINTER(U))
check(collides(world,player)==0)
check(step(world,player,0,100)==0 and ints()[7]==1 and abs(doubles()[1]-65)<1e-8,'grounding')
check(step(world,player,16,100)==0 and doubles()[1]>65.5 and ints()[7]==0,'jump')
for _ in range(100):check(step(world,player,16,10)==0)
check(abs(doubles()[1]-65)<1e-7 and ints()[7]==1,'landing or repeated held jump')
check(step(world,player,0,10)==0);check(step(world,player,16,100)==0 and doubles()[1]>65.5,'second jump')
check(pinit(player,feet)==0)
check(step(world,player,1,100)==0)
check(abs(doubles()[2]-.07)<1e-7,'forward speed')
check(pinit(player,feet)==0);check(step(world,player,1|8,100)==0)
check(abs(math.hypot(doubles()[0]-.5,doubles()[2]-.5)-.43)<1e-7,'diagonal speed')
check(pinit(player,feet)==0);check(step(world,player,32|1,1000)==0)
check(abs(doubles()[2]+.14)<1e-7,'sprint or delta clamp')
# Solid wall at Z=-1 and Y65..68, tests sustained wall contact and sliding.
for x in range(-4,5):
 for y in range(65,69):
  check(edit(world,coords(x,y,-1),1)>=0)
check(pinit(player,feet)==0)
for _ in range(100):check(step(world,player,1,10)==0)
check(abs(doubles()[2]-.3)<1e-7 and collides(world,player)==0,'wall penetration')
oldx=doubles()[0]
for _ in range(10):check(step(world,player,1|8,10)==0)
check(doubles()[0]>oldx and doubles()[2]>=.3-1e-7,'wall sliding')
# Ceiling at Y=67 stops a jump, with the 1.8-high body below it.
check(edit(world,coords(0,67,0),1)>=0);check(pinit(player,feet)==0)
check(step(world,player,0,10)==0)
for _ in range(20):check(step(world,player,16,10)==0)
check(doubles()[1]<=65.2+1e-7 and collides(world,player)==0,'ceiling collision')
check(pinit(player,feet)==0);before=bytes(player)
check(step(world,player,64,100)==-1 and bytes(player)==before)
check(look(player,1001,0)==-1 and bytes(player)==before)
check(resize(player,0,600)==-1 and bytes(player)==before)
check(look(player,200,100)==0)
floats=C.cast(player,C.POINTER(C.c_float))
check(abs(floats[6]-.5)<1e-6 and abs(floats[7]+.5)<1e-6)
r=(C.c_double*7)();check(ray(player,r)==0)
check(abs(sum(v*v for v in r[3:6])-1)<1e-6 and r[6]==5)
check(abs(r[1]-66.62)<1e-7)
check(overlap(player,coords(0,65,0))==1 and overlap(player,coords(0,64,0))==0)
# A fully populated journal refuses new edits without losing any existing data.
for i in range(8192):
 edits[i*4:i*4+4]=(i%80-32,100+i//6400,(i//80)%80-32,1)
world[6]=8192;world[10]=0
check(recenter(world,0,0)==1)
before=(bytes(world),bytes(edits),bytes(blocks))
check(edit(world,coords(0,102,0),2)==-2)
check(before==(bytes(world),bytes(edits),bytes(blocks)),'full journal corrupted state')
check(edit(world,coords(-32,100,-32),2)==1 and world[6]==8192,'full journal update')
check(edit(world,coords(-32,100,-32),0)==1 and world[6]==8191,'full journal revert')
check(edit(world,coords(0,102,0),2)==1 and world[6]==8192,'journal slot reuse')
print(f'PASS: {checks} streaming/journal/player collision/movement assertions')
