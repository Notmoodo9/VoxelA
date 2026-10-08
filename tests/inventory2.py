"""Independent inventory-v2 and staged 2x2/3x3 crafting checks, both ABIs."""
import ctypes as C,random,struct,sys,collections
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('inventory2_init',[P]);valid=bind('inventory2_valid',[P]);add=bind('inventory2_add',[P,I,I,I]);click=bind('inventory2_click',[P,I,I]);quick=bind('inventory2_quick',[P,I]);transfer=bind('inventory2_transfer',[P,I,I]);consume=bind('inventory2_consume',[P]);wear=bind('inventory2_wear',[P]);count=bind('inventory2_count',[P,I]);limit=bind('inventory2_item_limit',[I]);take=bind('grid_craft_take',[P,P,I,I]);repeat=bind('grid_craft_repeat',[P,P,I]);fill=bind('grid_craft_fill',[P,P,I,I]);clear=bind('grid_craft_clear',[P,P,I]);legacy=bind('inventory36_valid',[P])
def check(v,msg):
 global checks
 checks+=1;assert v,msg

def slot(id=0,n=0,d=0):return (id,n,d,0)
def tool(id):return id in (10,11)
def capacity(id):return 1 if tool(id) else 64
def pack(slots):return b''.join(struct.pack('<4H',*s) for s in slots)
def make(slots=None,cursor=slot(),mode=0):
 b=C.create_string_buffer(320);data=pack(slots or [slot()]*36)+struct.pack('<II',0,mode)+pack([cursor]);C.memmove(b,data,304);C.memset(C.byref(b,304),165,16);return b
def decode(b):return [struct.unpack_from('<4H',b.raw,i*8) for i in range(36)],struct.unpack_from('<4H',b.raw,296)
def model_click(slots,cursor,index,action):
 slots=slots.copy();old=slots[index];before=(slots.copy(),cursor)
 if action==0:
  if not cursor[0]:slots[index],cursor=cursor,old
  elif not old[0] or old[0]!=cursor[0] or tool(cursor[0]):slots[index],cursor=cursor,old
  else:
   moved=min(64-old[1],cursor[1]);slots[index]=slot(old[0],old[1]+moved);cursor=slot(cursor[0],cursor[1]-moved) if cursor[1]>moved else slot()
 elif not cursor[0]:
  n=(old[1]+1)//2
  cursor=slot(old[0],n,old[2]) if n else slot();slots[index]=slot(old[0],old[1]-n,old[2]) if old[1]>n else slot()
 elif not old[0]:
  slots[index]=slot(cursor[0],1,cursor[2]);cursor=slot(cursor[0],cursor[1]-1,cursor[2]) if cursor[1]>1 else slot()
 elif cursor[0]==old[0] and not tool(cursor[0]) and old[1]<64:
  slots[index]=slot(old[0],old[1]+1);cursor=slot(cursor[0],cursor[1]-1) if cursor[1]>1 else slot()
 return slots,cursor,int(before!=(slots,cursor))
def model_quick(slots,index):
 slots=slots.copy();before=slots.copy();source=slots[index];n=source[1];targets=range(9,36) if index<9 else range(9)
 for phase in range(2):
  for i in targets:
   target=slots[i]
   room=64-target[1] if phase==0 and not tool(source[0]) and target[0]==source[0] and source[0] else capacity(source[0]) if phase==1 and not target[0] and source[0] else 0
   moved=min(room,n)
   if moved:slots[i]=slot(source[0],target[1]+moved,source[2]);n-=moved
 slots[index]=slot(source[0],n,source[2]) if n else slot()
 return slots,int(before!=slots)
def model_add(slots,id,n,d=0):
 slots=slots.copy()
 if not tool(id):
  for i,s in enumerate(slots):
   if s[0]==id:
    moved=min(64-s[1],n);slots[i]=slot(id,s[1]+moved);n-=moved
 for i,s in enumerate(slots):
  if not s[0] and n:
   moved=min(capacity(id),n);slots[i]=slot(id,moved,d);n-=moved
 return None if n else slots
rng=random.Random(8841);ids=[1,2,3,4,5,6,8,9,10,11,12,13]
def random_slot():
 id=rng.choice([0,0]+ids)
 return slot() if not id else slot(id,rng.randint(1,capacity(id)),rng.randint(1,60 if id==10 else 132) if tool(id) else 0)
for id in range(16):check(limit(id)==(capacity(id) if id in ids else -1),'item stack limit')
for _ in range(5000):
 slots=[random_slot() for _ in range(36)];cursor=random_slot();b=make(slots,cursor);index=rng.randrange(36)
 check(valid(b)==0,'all v2 slots valid')
 if rng.randrange(2):
  action=rng.randrange(2);expected,cur,status=model_click(slots,cursor,index,action);result=click(b,index,action)
 else:expected,status=model_quick(slots,index);cur=cursor;result=quick(b,index)
 check(result==status and decode(b)==(expected,cur),'independent mouse/shift model');check(valid(b)==0,'post-operation validity');check(b.raw[304:]==b'\xa5'*16,'inventory canary')
for _ in range(2000):
 slots=[random_slot() for _ in range(36)];cursor=random_slot();id=rng.choice(ids);n=1 if tool(id) else rng.randint(1,2304);d=rng.randint(1,60 if id==10 else 132) if tool(id) else 0;b=make(slots,cursor);before=b.raw;expected=model_add(slots,id,n,d)
 check(add(b,id,n,d)==(1 if expected is not None else -2),'atomic add status');check(b.raw==before if expected is None else decode(b)==(expected,cursor),'atomic add state');check(b.raw[304:]==b'\xa5'*16,'add canary')
for id in (8,12,13):
 b=make([slot(id,64)]+[slot()]*35);check(consume(b)==1 and decode(b)[0][0]==slot(id,63),'new placement consumption');before=b.raw;check(wear(b)==0 and b.raw==before,'containers do not wear');check(count(b,id)==63,'new item count')
 check(legacy(b)==(-1 if id>=12 else 0),'legacy registry remains frozen')
for id in (9,10,11):
 b=make([slot(id,1,60 if id==10 else 132 if id==11 else 0)]+[slot()]*35);before=b.raw;check(consume(b)==-1 and b.raw==before,'non-placeable consumption rejected')
for id,n,d in ((12,2305,0),(13,1,1),(10,2,60),(11,1,133),(7,1,0)):
 b=make();before=b.raw;check(add(b,id,n,d)==-1 and b.raw==before,'invalid add immutable')
for index,action in ((36,0),(0,2),(-1,1)):
 b=make();before=b.raw;check(click(b,index,action)==-1 and b.raw==before,'invalid click immutable')
recipes=[([[5]],8,4,0),([[8],[8]],9,4,0),([[8,8,8],[0,9,0],[0,9,0]],10,1,60),([[1,1,1],[0,9,0],[0,9,0]],11,1,132),([[8,8],[8,8]],12,1,0),([[8,8,8],[8,0,8],[8,8,8]],13,1,0)]
def grid_buffer(slots):
 data=pack(slots);b=C.create_string_buffer(len(data)+16);C.memmove(b,data,len(data));C.memset(C.byref(b,len(data)),165,16);return b
def grid_decode(b,w):return [struct.unpack_from('<4H',b.raw,i*8) for i in range(w*w)]
for w in (2,3):
 for index,(shape,id,n,d) in enumerate(recipes):
  if len(shape)>w or len(shape[0])>w:continue
  for y in range(w-len(shape)+1):
   for x in range(w-len(shape[0])+1):
    gs=[slot()]* (w*w)
    for dy,row in enumerate(shape):
     for dx,ingredient in enumerate(row):
      if ingredient:gs[(y+dy)*w+x+dx]=slot(ingredient,3)
    for destination in (0,1):
     b=make();g=grid_buffer(gs);check(take(b,g,w,destination)==1,'craft every translated recipe')
     expected=[slot(s[0],2) if s[0] else slot() for s in gs];check(grid_decode(g,w)==expected,'one ingredient per occupied cell')
     bag,cursor=decode(b);check((cursor==slot(id,n,d) and all(not s[0] for s in bag)) if destination==0 else (bag[0]==slot(id,n,d) and cursor==slot()),'correct crafted output and tool wear')
     check(g.raw[w*w*8:]==b'\xa5'*16 and b.raw[304:]==b'\xa5'*16,'craft canaries')
    b=make();g=grid_buffer(gs);check(repeat(b,g,w)==3,'repeat uses all batches');check(all(s==slot() for s in grid_decode(g,w)),'repeat consumes grid');check(count(b,id)==3*n,'repeat output quantity')
for _ in range(2000):
 w=rng.choice((2,3));index=rng.choice([i for i,(s,*_) in enumerate(recipes) if len(s)<=w]);shape,id,n,d=recipes[index];batches=rng.randint(1,64);gs=[slot()]* (w*w)
 for y,row in enumerate(shape):
  for x,v in enumerate(row):
   if v:gs[y*w+x]=slot(v,batches)
 slots=[random_slot() for _ in range(36)];cursor=random_slot();destination=rng.randrange(2);b=make(slots,cursor);g=grid_buffer(gs);before=(b.raw,g.raw)
 expected=model_add(slots,id,n,d) if destination else None
 if destination:fits=expected is not None;expected_cursor=cursor
 else:
  fits=not cursor[0] or (cursor[0]==id and not tool(id) and cursor[1]+n<=64);expected_cursor=slot(id,n+(cursor[1] if cursor[0] else 0),d);expected=slots
 check(take(b,g,w,destination)==int(fits),'craft capacity model')
 if not fits:check((b.raw,g.raw)==before,'rejected craft immutable')
 else:
  check(decode(b)==(expected,expected_cursor),'craft output model');check(grid_decode(g,w)==[slot(s[0],s[1]-1) if s[1]>1 else slot() for s in gs],'craft ingredient model')
for w in (2,3):
 for index,(shape,id,n,d) in enumerate(recipes):
  ingredients=collections.Counter(v for row in shape for v in row if v);slots=[slot(v,n) for v,n in ingredients.items()]+[slot()]*(36-len(ingredients));b=make(slots);g=grid_buffer([slot()]*(w*w));before=(b.raw,g.raw);fits=len(shape)<=w and len(shape[0])<=w
  check(fill(b,g,w,index)==int(fits),'fill dimensional gate')
  if fits:
   expected=[slot()]* (w*w)
   for y,row in enumerate(shape):
    for x,v in enumerate(row):expected[y*w+x]=slot(v,1) if v else slot()
   check(grid_decode(g,w)==expected and all(s==slot() for s in decode(b)[0]),'fill removes exact bag ingredients')
   check(clear(b,g,w)==1,'clear succeeds');check(all(s==slot() for s in grid_decode(g,w)),'clear empties grid')
   check({v:count(b,v) for v in ingredients}==dict(ingredients),'clear conserves ingredients')
  else:check((b.raw,g.raw)==before,'oversized fill immutable')
# Staged failures: no output space, incomplete recipe, occupied cursor, old-grid return.
for operation in ('take','fill','clear'):
 b=make([slot(2,64)]*36);g=grid_buffer([slot(5,1),slot(),slot(),slot()]);before=(b.raw,g.raw)
 result=take(b,g,2,1) if operation=='take' else fill(b,g,2,4) if operation=='fill' else clear(b,g,2)
 check(result==0 and (b.raw,g.raw)==before,'full bag transaction immutable')
b=make([slot(8,3)]+[slot()]*35);g=grid_buffer([slot(5,1),slot(),slot(),slot()]);before=(b.raw,g.raw);check(fill(b,g,2,4)==0 and (b.raw,g.raw)==before,'missing ingredients retains previous grid')
b=make(cursor=slot(8,64));g=grid_buffer([slot(5,1),slot(),slot(),slot()]);before=(b.raw,g.raw);check(take(b,g,2,0)==0 and (b.raw,g.raw)==before,'full cursor immutable')
for fn in (take,fill,clear):
 b=make();g=grid_buffer([slot(13,1,1)]+[slot()]*8);before=(b.raw,g.raw)
 result=fn(b,g,3,1) if fn==take else fn(b,g,3,5) if fn==fill else fn(b,g,3)
 check(result==-1 and (b.raw,g.raw)==before,'invalid grid immutable')
for mode in (0,1):
 b=make(mode=mode);g=grid_buffer([slot(5,1),slot(),slot(),slot()]);before=(b.raw,g.raw)
 check(take(b,g,2,1)==(0 if mode else 1),'survival-only executor');check((b.raw,g.raw)==before if mode else count(b,8)==4,'creative preserves all ingredients')
for _ in range(1500):
 slots=[random_slot() for _ in range(36)];cursor=random_slot();a=rng.randrange(36);dest=rng.randrange(36);expected=slots.copy();source=slots[a];target=slots[dest]
 if a!=dest and source[0]:
  if source[0]==target[0] and not tool(source[0]):
   moved=min(64-target[1],source[1]);expected[dest]=slot(target[0],target[1]+moved);expected[a]=slot(source[0],source[1]-moved) if source[1]>moved else slot()
  else:expected[a],expected[dest]=target,source
 b=make(slots,cursor);check(transfer(b,a,dest)==int(expected!=slots) and decode(b)==(expected,cursor),'transfer model')
for _ in range(1000):
 w=rng.choice((2,3));recipe=rng.choice([i for i,(shape,*_) in enumerate(recipes) if len(shape)<=w]);shape,*_=recipes[recipe];slots=[random_slot() for _ in range(36)];cursor=random_slot();gs=[random_slot() for _ in range(w*w)];b=make(slots,cursor);g=grid_buffer(gs);before=(b.raw,g.raw);expected=slots.copy()
 for id,n,d,_reserved in gs:
  if id and expected is not None:expected=model_add(expected,id,n,d)
 if expected is not None:
  for row in shape:
   for id in row:
    if not id:continue
    found=next((i for i,s in enumerate(expected) if s[0]==id),None)
    if found is None:expected=None;break
    old=expected[found];expected[found]=slot(id,old[1]-1) if old[1]>1 else slot()
   if expected is None:break
 check(fill(b,g,w,recipe)==int(expected is not None),'staged fill capacity/missing model')
 if expected is None:check((b.raw,g.raw)==before,'staged fill rejection immutable')
 else:
  arranged=[slot()]* (w*w)
  for y,row in enumerate(shape):
   for x,id in enumerate(row):arranged[y*w+x]=slot(id,1) if id else slot()
  check(decode(b)==(expected,cursor) and grid_decode(g,w)==arranged,'staged fill exact model')
for offset,data in ((288,struct.pack('<I',9)),(292,struct.pack('<I',2)),(296,pack([slot(13,1,1)])),(0,pack([slot(12,65)]))):
 b=make();C.memmove(C.byref(b,offset),data,len(data));before=b.raw;g=grid_buffer([slot(5,1)]+[slot()]*3);gbefore=g.raw
 check(valid(b)==-1,'invalid v2 state')
 for fn,args in ((add,(b,13,1,0)),(click,(b,0,0)),(quick,(b,0)),(transfer,(b,0,1)),(consume,(b,)),(take,(b,g,2,1)),(fill,(b,g,2,0)),(clear,(b,g,2))):
  check(fn(*args)==-1 and b.raw==before and g.raw==gbefore,'invalid state mutation rejected')
print(f'inventory2/grid crafting: {checks} independent checks passed')
