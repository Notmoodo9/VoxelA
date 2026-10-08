"""Registry2 blocks, independent meshing/vertices, picking and atomic world saves."""
import ctypes as C,random,struct,sys,math
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;checks=0

def bind(n,args,prefix=True):
 f=getattr(lib,('world2_' if prefix else '')+n);f.argtypes=args;f.restype=I;return f
flags=bind('block_flags',[I]);setblock=bind('section_set',[P,I,I]);mesh=bind('mesh_build',[P,P,P,I]);expand=bind('faces_expand',[P,I,P]);ci=bind('cache_init',[P,P,I]);insert=bind('cache_insert',[P,P,P,I]);ce=bind('cache_edit',[P,P,I,I]);cg=bind('cache_get',[P,P,P]);cast=bind('world_raycast',[P,P,P]);si=bind('stream_init',[P,P]);center=bind('stream_recenter',[P,I,I]);get=bind('stream_get',[P,P]);edit=bind('stream_edit',[P,P,I]);pinit=bind('player_init',[P,P]);collide=bind('player_collides',[P,P]);encode=bind('walk_encode',[P,P,P,I]);decode=bind('walk_decode',[P,I,P,P]);legacy_decode=bind('walk_decode',[P,I,P,P],False);legacy_encode=bind('walk_encode',[P,P,P,I],False);height=bind('terrain_height',[I,I,I],False);legacy_set=bind('section_set',[P,I,I],False)
def check(v,msg):
 global checks
 checks+=1;assert v,msg
coords=lambda x,y,z:(I*3)(x,y,z)
flags_model=[0,7,7,7,7,7,13,3,7,23,23]
for id in range(-1,14):check(flags(id)==(flags_model[id] if 0<=id<11 else -1),'block flags')
s=(C.c_uint16*4096)()
for id in range(11):check(setblock(s,4095,id)==0 and s[4095]==id,'section set')
for id in (8,9,10):check(legacy_set(s,4095,id)==-1,'legacy ID rejection')
before=bytes(s)
for index,id in ((4096,8),(0,11),(-1,10),(0,-1)):check(setblock(s,index,id)==-1 and bytes(s)==before,'invalid set immutable')
rng=random.Random(1738);directions=[(-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1)]
def index(x,y,z):return x+16*(z+16*y)
for _ in range(150):
 values=[0]*4096
 for _ in range(60):values[rng.randrange(4096)]=rng.randrange(1,11)
 adjacent=[[(rng.randrange(11) if rng.randrange(10)==0 else 0) for _ in range(4096)] for _ in range(6)]
 section=(C.c_uint16*4096)(*values);neighbors=[(C.c_uint16*4096)(*v) for v in adjacent];ptrs=(P*6)(*[C.addressof(v) for v in neighbors]);expected=[]
 for i,id in enumerate(values):
  if not id:continue
  x=i%16;z=(i//16)%16;y=i//256
  for d,(dx,dy,dz) in enumerate(directions):
   nx,ny,nz=x+dx,y+dy,z+dz;j=index(nx%16,ny%16,nz%16);neighbor=values[j] if 0<=nx<16 and 0<=ny<16 and 0<=nz<16 else adjacent[d][j]
   if neighbor!=id and not(flags_model[neighbor]&2):expected.append(struct.pack('<4BHH',x,y,z,d,id,0))
 want=b''.join(expected);out=C.create_string_buffer(len(want)+16);C.memset(out,165,len(want)+16)
 check(mesh(section,ptrs,None,0)==len(expected),'independent face count');check(mesh(section,ptrs,out,len(expected))==len(expected),'mesh emit count');check(out.raw==want+b'\xa5'*16,'exact face records/canary')
 if expected:
  C.memset(out,165,len(want)+16);check(mesh(section,ptrs,out,len(expected)-1)==-2 and out.raw==b'\xa5'*(len(want)+16),'mesh capacity atomic')
 section[0]=11;before=out.raw;check(mesh(section,ptrs,out,len(expected))==-1 and out.raw==before,'invalid section rejected')
 section[0]=0;neighbors[4][2048]=11;check(mesh(section,ptrs,out,len(expected))==-1 and out.raw==before,'invalid neighbor rejected')
class Target(C.Structure):_fields_=[('buffer',P),('capacity',U),('x',C.c_int32),('y',C.c_int32),('z',C.c_int32)]
quads=[[(0,0,0),(0,0,1),(0,1,1),(0,1,0)],[(1,0,1),(1,0,0),(1,1,0),(1,1,1)],[(0,0,1),(0,0,0),(1,0,0),(1,0,1)],[(0,1,0),(0,1,1),(1,1,1),(1,1,0)],[(1,0,0),(0,0,0),(0,1,0),(1,1,0)],[(0,0,1),(1,0,1),(1,1,1),(0,1,1)]]
colors=[(0,0,0),(.55,.55,.58),(.48,.29,.16),(.24,.65,.22),(.86,.77,.48),(.48,.32,.17),(.18,.48,.17),(.24,.24,.27),(.66,.46,.25),(.62,.38,.16),(.50,.30,.14)];shades=[.7,.8,.45,1,.6,.85]
def f32(v):return struct.unpack('<f',struct.pack('<f',v))[0]
for id in range(1,11):
 for d in range(6):
  record=C.create_string_buffer(struct.pack('<4BHH',7,9,11,d,id,0));out=C.create_string_buffer(160);C.memset(out,165,160);target=Target(C.addressof(out),6,-40,20,50)
  check(expand(record,1,C.byref(target))==6,'extended face expansion')
  for v,q in enumerate((0,1,2,0,2,3)):
   got=struct.unpack_from('<6f',out.raw,v*24);corner=quads[d][q];xyz=tuple(a+b+c for a,b,c in zip((7,9,11),(-40,20,50),corner));rgb=tuple(f32(f32(c)*f32(shades[d])) for c in colors[id])
   check(got==xyz+rgb,'independent vertex/color model')
  check(out.raw[144:]==b'\xa5'*16,'vertex canary')
  target.capacity=5;before=out.raw;check(expand(record,1,C.byref(target))==-2 and out.raw==before,'vertex capacity immutable')
  target.capacity=6;struct.pack_into('<H',record,4,11);check(expand(record,1,C.byref(target))==-1 and out.raw==before,'vertex invalid ID immutable')
class Cache(C.Structure):_fields_=[('entries',P),('capacity',U),('count',U)]
class Ray(C.Structure):_fields_=[('origin',C.c_double*3),('direction',C.c_double*3),('reach',C.c_double)]
class Hit(C.Structure):_fields_=[('cell',I*3),('face',I),('distance',C.c_double),('previous',I*3),('block',U)]
cache=Cache();entries=C.create_string_buffer(128);section=(C.c_uint16*4096)();ci(C.byref(cache),entries,2);entry=insert(C.byref(cache),coords(0,0,0),section,1);check(entry>0,'cache insert')
for id in (8,9,10):
 check(ce(C.byref(cache),entry,index(8,8,8),id)==0,'extended cache edit');value=C.c_uint16(999);check(cg(C.byref(cache),coords(8,8,8),C.byref(value))==0 and value.value==id,'cache lookup')
 ray=Ray((C.c_double*3)(5.5,8.5,8.5),(C.c_double*3)(1,0,0),10);hit=Hit();check(cast(C.byref(cache),C.byref(ray),C.byref(hit))==1 and tuple(hit.cell)==(8,8,8) and hit.block==id and hit.distance==2.5,'ray picks extended block')
 before=bytes(section);check(ce(C.byref(cache),entry,0,11)==-1 and bytes(section)==before,'invalid cache ID immutable')
# Actual streamed world, with old generator0 unchanged and preserved overrides.
world=(U*12)();world_entries=C.create_string_buffer(25600);blocks=C.create_string_buffer(3276800);edits=C.create_string_buffer(262144);player=C.create_string_buffer(80);config=(U*4)(42,C.addressof(world_entries),C.addressof(blocks),C.addressof(edits));check(si(world,config)==0 and center(world,0,0)==1,'stream init/recenter');feet=(C.c_double*3)(.5,height(42,0,0)+1,.5);check(pinit(player,feet)==0,'player spawn')
expected={}
for _ in range(80):
 p=(rng.randint(-30,30),rng.randint(120,200),rng.randint(-30,30));id=rng.choice((0,8,9,10));previous=expected.get(p,0);check(edit(world,coords(*p),id)==int(id!=previous),'stream edit semantics');expected[p]=id;check(get(world,coords(*p))==id,'stream point query')
for p in ((0,0,0),(0,256,0)):
 before=(bytes(world),bytes(edits));check(edit(world,coords(*p),9)==-1 and before==(bytes(world),bytes(edits)),'bedrock/height immutable')
for id in (7,11,-1):
 before=(bytes(world),bytes(edits));check(edit(world,coords(0,150,0),id)==-1 and before==(bytes(world),bytes(edits)),'invalid stream block immutable')
check(center(world,20,-20)==1 and center(world,0,0)==1,'recenter away/back')
for p,id in expected.items():check(get(world,coords(*p))==id,'eviction preserves extended edits')
for p,id in expected.items():
 if id:check(edit(world,coords(*p),0)==1,'revert to baseline removes override')
check(world[6]==0,'journal empty after baseline reverts')
for id,p in zip((8,9,10),((3,150,3),(4,150,3),(5,150,3))):check(edit(world,coords(*p),id)==1,'three extended save fixtures')
# Collision includes new blocks, without any item/container UI dependency.
for id,x in ((8,3),(9,4),(10,5)):
 position=(C.c_double*3)(x+.5,150,3.5);check(collide(world,position)==1,'player collides with new block');position[1]=151;check(collide(world,position)==0,'air above new block is free')
def checksum(data):
 value=0xcbf29ce484222325
 for i,b in enumerate(data):value=((value^(0 if 40<=i<48 else b))*0x100000001b3)&((1<<64)-1)
 return value
def repair(data):
 b=bytearray(data);struct.pack_into('<Q',b,40,checksum(b));return bytes(b)
out=C.create_string_buffer(262288);C.memset(out,165,262288);length=encode(world,player,out,262272);records=bytes(edits)[:world[6]*32];header=bytearray(128);struct.pack_into('<8sIIIIQQ',header,0,b'VXAWALK\0',1,0,2,world[6],42,len(records));header[64:96]=player.raw[:32];want=repair(header+records);check(length==224 and out.raw[:length]==want,'exact registry2 save wire');check(out.raw[length:]==b'\xa5'*(262288-length),'save output canary')
before=out.raw;check(encode(world,player,out,length-1)==-2 and out.raw==before,'save capacity atomic');check(legacy_encode(world,player,out,262272)==-1 and out.raw==before,'old encoder rejects extended journal')
check(center(world,10,10)==1 and decode(C.create_string_buffer(want),length,world,player)==0,'extended save load/recenter')
for id,p in zip((8,9,10),((3,150,3),(4,150,3),(5,150,3))):check(get(world,coords(*p))==id,'saved extended block restored')
def reject(blob,fn=decode):
 before=(bytes(world),player.raw,edits.raw,world_entries.raw,blocks.raw)
 check(fn(C.create_string_buffer(blob),len(blob),world,player)==-1,'malformed save rejected');check(before==(bytes(world),player.raw,edits.raw,world_entries.raw,blocks.raw),'decode rejection atomic')
reject(want,legacy_decode)
for i in range(len(want)):
 b=bytearray(want);b[i]^=128;reject(bytes(b))
for offset,value,fmt in ((16,0,'I'),(16,3,'I'),(20,8193,'I'),(24,43,'Q'),(48,1,'Q'),(128,30000000,'q'),(136,0,'q'),(152,7,'Q'),(152,11,'Q'),(152,-1,'q')):
 b=bytearray(want);struct.pack_into('<'+fmt,b,offset,value);reject(repair(b))
b=bytearray(want);struct.pack_into('<I',b,16,1);reject(repair(b)) # legacy header cannot carry new IDs
for n in (0,1,127,128,223):reject(want[:n])
reject(want+b'x')
# Old registry1 save migrates through the new world decoder, and re-encodes as2.
b=bytearray(want);struct.pack_into('<I',b,16,1)
for offset in (152,184,216):struct.pack_into('<Q',b,offset,5)
old=repair(b);check(decode(C.create_string_buffer(old),len(old),world,player)==0,'legacy world save migration');check(encode(world,player,out,262272)==224 and struct.unpack_from('<I',out,16)[0]==2,'migration re-encodes registry2')
for p in ((3,150,3),(4,150,3),(5,150,3)):check(get(world,coords(*p))==5,'legacy blocks preserved')
print(f'world2: {checks} block/mesh/vertex/picking/save checks passed')
