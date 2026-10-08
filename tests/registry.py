"""Versioned metadata and independent six-recipe grid model."""
import ctypes as C,itertools,random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;checks=0
def bind(n,a):
 f=getattr(lib,n);f.argtypes=a;f.restype=I;return f
item=bind('item_info',[I,I,P]);block=bind('block_info',[I,I,P]);valid=bind('slot_valid',[P,I]);info=bind('recipe_catalog_info',[I,I,P]);match=bind('recipe_catalog_match',[P,I,I,P])
def check(v,msg):
 global checks
 checks+=1;assert v,msg
items={i:(3,64,0,i) for i in range(1,7)}
items.update({8:(3,64,0,8),9:(1,64,0,0),10:(4,1,60,0),11:(4,1,132,0),12:(11,64,0,10),13:(11,64,0,9)})
blocks=[(0,0,0,0),(7,1,1,1),(7,2,2,2),(7,2,3,8),(7,4,4,4),(7,5,5,9),(13,6,6,6),(3,0,7,7),(7,8,10,10),(23,13,15,15),(23,12,14,14)]
for reg in (0,1,2,3):
 for id in range(-1,16):
  for fn,expected in ((item,items.get(id) if reg==2 else ((1,64,0,0) if id==8 else items.get(id)) if reg==1 and id<=11 else None),(block,blocks[id] if 0<=id<(8 if reg==1 else 11) and reg in (1,2) else None)):
   out=(C.c_ubyte*24)(*([165]*24));result=fn(id,reg,out)
   check(result==(0 if expected is not None else -1),'lookup status')
   check(bytes(out)==(struct.pack('<4I',*expected)+b'\xa5'*8 if expected is not None else b'\xa5'*24),'lookup and bounds')
for reg in (0,1,2,3):
 for id,count,dur,reserved in itertools.product(range(15),(0,1,2,64,65),(0,1,60,61,132,133),(0,1)):
  slot=struct.pack('<4H',id,count,dur,reserved);buf=C.create_string_buffer(slot)
  m=items.get(id);ok=reg in (1,2) and (slot==b'\0'*8 or (m is not None and (reg==2 or id<=11) and reserved==0 and 0<count<=m[1] and (1<=dur<=m[2] if m[2] else dur==0)))
  check(valid(buf,reg)==(0 if ok else -1),'slot validity');check(buf.raw[:8]==slot,'slot immutable')
recipes=[([[5]],8,4,0),([[8],[8]],9,4,0),([[8,8,8],[0,9,0],[0,9,0]],10,1,60),([[1,1,1],[0,9,0],[0,9,0]],11,1,132),([[8,8],[8,8]],12,1,0),([[8,8,8],[8,0,8],[8,8,8]],13,1,0)]
for reg in (1,2):
 for n in range(8):
  out=(C.c_ubyte*48)(*([165]*48));r=info(n,reg,out);available=n<(4 if reg==1 else 6)
  check(r==(0 if available else -1),'catalog info status')
  if available:
   shape,id,count,dur=recipes[n];pattern=[shape[y][x] if y<len(shape) and x<len(shape[0]) else 0 for y in range(3) for x in range(3)]
   expected=struct.pack('<IIHHHH9H6x',len(shape[0]),len(shape),id,count,dur,0,*pattern)
   check(bytes(out)==expected+b'\xa5'*8,'catalog wire layout')
  else:check(bytes(out)==b'\xa5'*48,'invalid info unchanged')
def exercise(ids,w,reg):
 grid=C.create_string_buffer(b''.join(struct.pack('<4H',id,1 if id else 0,60 if id==10 else 132 if id==11 else 0,0) for id in ids));before=grid.raw
 occupied=[(i%w,i//w) for i,id in enumerate(ids) if id];want=0;index=999
 if occupied:
  x0=min(x for x,y in occupied);x1=max(x for x,y in occupied);y0=min(y for x,y in occupied);y1=max(y for x,y in occupied)
  shape=[[ids[y*w+x] for x in range(x0,x1+1)] for y in range(y0,y1+1)]
  for n,(pattern,id,count,dur) in enumerate(recipes[:4 if reg==1 else 6]):
   if pattern==shape:want=id|(count<<16)|(dur<<32);index=n;break
 out=(C.c_uint32*2)(999,888)
 check(match(grid,w,reg,out)==want,'independent shape matching');check(list(out)==[index,888],'recipe output bounds');check(grid.raw==before,'grid immutable')
for reg in (1,2):
 for ids in itertools.product((0,1,5,8,9),repeat=4):exercise(ids,2,reg)
 for shape,*_ in recipes:
  if len(shape)<=3:
   for y in range(4-len(shape)):
    for x in range(4-len(shape[0])):
     ids=[0]*9
     for dy,row in enumerate(shape):
      for dx,id in enumerate(row):ids[(y+dy)*3+x+dx]=id
     exercise(ids,3,reg)
rng=random.Random(712)
for _ in range(3000):exercise([rng.choice((0,0,1,5,8,9,10,11)) for _ in range(9)],3,rng.choice((1,2)))
for reg,w in ((0,2),(3,3),(1,1),(2,4)):
 grid=C.create_string_buffer(72);out=C.c_uint32(999);check(match(grid,w,reg,C.byref(out))==-1 and out.value==999,'invalid dimension/registry')
for id,count,dur,reserved,reg in ((12,64,0,0,2),(13,64,0,0,2),(12,1,0,0,1),(13,1,1,0,2),(8,65,0,0,2),(0,0,0,1,2)):
 grid=C.create_string_buffer(struct.pack('<4H',id,count,dur,reserved)+b'\0'*24);before=grid.raw;out=C.c_uint32(999)
 want=0 if reg==2 and id in (12,13) and dur==0 else -1
 check(match(grid,2,reg,C.byref(out))==want and out.value==999,'catalog slot validation')
 check(grid.raw==before,'invalid catalog immutable')
print(f'versioned registry/catalog: {checks} checks passed')
