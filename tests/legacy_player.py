"""Legacy checkpoint adoption keeps pose, inventory and crafting state atomic."""
import ctypes as C
import struct, sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);pinit=bind('player_init',[P,P]);iinit=bind('inventory36_init',[P]);extract=bind('legacy_player_extract',[P,U,U,P]);enc=bind('game_grid_encode',[P,P,P,P]);old1=bind('walk_encode',[P,P,P,U]);old2=bind('game_encode',[P,P,P,P]);old3=bind('game36_encode',[P,P,P,P]);oldinit=bind('inventory_init',[P])
world=(U*12)();entries=C.create_string_buffer(25600);blocks=C.create_string_buffer(3276800);journal=C.create_string_buffer(262144);player=C.create_string_buffer(80);bag=C.create_string_buffer(336);oldbag=C.create_string_buffer(80)
cfg=(U*4)(42,C.addressof(entries),C.addressof(blocks),C.addressof(journal));assert init(world,cfg)==0 and center(world,-2,-3)==1
assert pinit(player,(C.c_double*3)(-31.5,100,-47.5))==0 and iinit(bag)==0 and oldinit(oldbag)==0
struct.pack_into('<ff',player,24,.5,-.25);struct.pack_into('<HHHH',bag,296,9,3,0,0);struct.pack_into('<HHHH',bag,304,5,3,0,0)
out=C.create_string_buffer(262608);target=(U*2)(C.addressof(out),262608);result=C.create_string_buffer(448);fresh=C.create_string_buffer(336);assert iinit(fresh)==0
for version in range(1,5):
 if version==1:n=old1(world,player,out,262608);expected=fresh.raw
 elif version==2:
  n=old2(world,player,oldbag,target);expected=oldbag.raw[:72]+bytes(216)+oldbag.raw[72:80]+bytes(40)
 elif version==3:n=old3(world,player,bag,target);expected=bag.raw[:304]+bytes(32)
 else:n=enc(world,player,bag,target);expected=bag.raw
 assert n>0
 source=out.raw[:n];C.memset(result,0xa5,448)
 assert extract(out,n,42,result)==0 and result.raw[432:]==b'\xa5'*16
 assert result.raw[:32]==player.raw[:32] and result.raw[80:416]==expected
 assert struct.unpack_from('<qq',result,416)==(-2,-3) and out.raw[:n]==source
 before=result.raw;assert extract(out,n,43,result)==-1 and result.raw==before
 corrupt=bytearray(source);corrupt[-1]^=128
 assert extract(C.create_string_buffer(bytes(corrupt)),n,42,result)==-1 and result.raw==before
 assert extract(out,127,42,result)==-1 and result.raw==before
print('PASS: format1–4 immutable checkpoint adoption, original pose/center, inventory/cursor/grid migration, wrong-seed/corruption/truncation atomicity and canaries')
