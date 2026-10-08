"""Independent resource conservation, stack, crafting and durability checks."""
import ctypes as C
import random
import struct
import sys
lib=C.CDLL(sys.argv[1]);checks=0

def bind(name,args):
 f=getattr(lib,name);f.argtypes=args;f.restype=C.c_int64;return f
init=bind('inventory_init',[C.c_void_p]);valid=bind('inventory_valid',[C.c_void_p])
add=bind('inventory_add',[C.c_void_p,C.c_uint64,C.c_uint64,C.c_uint64])
craft=bind('inventory_craft',[C.c_void_p,C.c_uint64]);wear=bind('inventory_wear',[C.c_void_p])
preview=bind('inventory_can_craft',[C.c_void_p,C.c_uint64]);count=bind('inventory_count',[C.c_void_p,C.c_uint64]);transfer=bind('inventory_transfer',[C.c_void_p,C.c_uint64,C.c_uint64])
consume=bind('inventory_consume',[C.c_void_p]);duration=bind('mine_duration',[C.c_void_p,C.c_uint64])
limit=bind('item_limit',[C.c_uint64])
def check(v,msg):
 global checks
 checks+=1;assert v,msg
state=(C.c_ubyte*96)();C.memset(state,0xa5,96)
check(init(state)==0,'init');check(bytes(state)[80:]==b'\xa5'*16,'init bounds')
def slots():return [list(struct.unpack_from('<HHHH',bytes(state),i*8)) for i in range(9)]
def put(s,selected=0,mode=0):
 raw=b''.join(struct.pack('<HHHH',*v) for v in s)+struct.pack('<II',selected,mode)
 C.memmove(state,raw,80)
def model_add(s,item,count,dur):
 t=[v[:] for v in s]
 if item<10:
  for slot in t:
   if slot[0]==item:
    n=min(count,64-slot[1]);slot[1]+=n;count-=n
 for slot in t:
  if slot[0]==0 and count:
   n=min(count,1 if item>=10 else 64);slot[:]=[item,n,dur,0];count-=n
 return None if count else t
def model_remove(s,item,n):
 for slot in s:
  if slot[0]==item:
   used=min(n,slot[1]);n-=used;slot[1]-=used
   if not slot[1]:slot[:]=[0,0,0,0]
 return n==0
recipes=[([(5,1)],8,4,0),([(8,2)],9,4,0),([(8,3),(9,2)],10,1,60),([(1,3),(9,2)],11,1,132)]
def model_craft(s,r):
 t=[v[:] for v in s];ingredients,item,n,d=recipes[r]
 for i,c in ingredients:
  if not model_remove(t,i,c):return None
 return model_add(t,item,n,d)
check(slots()[:2]==[[2,32,0,0],[5,8,0,0]],'starter supply')
for item in range(14):check(limit(item)==(-1 if item in [0,7,12,13] else 1 if item>=10 else 64),'registry')
# Random independent transactions include split stacks, full bags and tools.
rng=random.Random(261108)
for iteration in range(4000):
 s=[]
 for i in range(9):
  item=rng.choice([0,1,2,3,4,5,6,8,9,10,11])
  s.append([item,1 if item>=10 else rng.randint(1,64),rng.randint(1,60 if item==10 else 132) if item>=10 else 0,0] if item else [0,0,0,0])
 selected=rng.randrange(9);mode=rng.randrange(2);put(s,selected,mode)
 before=bytes(state)
 if iteration%2:
  item=rng.choice([1,2,3,4,5,6,8,9,10,11]);n=1 if item>=10 else rng.randint(1,576);d=(60 if item==10 else 132) if item>=10 else 0
  expected=model_add(s,item,n,d);result=add(state,item,n,d)
  check(result==(1 if expected is not None else -2),'add result')
 else:
  recipe=rng.randrange(4);expected=model_craft(s,recipe);result=craft(state,recipe)
  check(result==(1 if expected is not None else 0),'craft result')
 check(slots()==(s if expected is None else expected),'transaction/reference mismatch')
 check(bytes(state)[72:]==before[72:],'metadata/canary changed')
 check(valid(state)==0,'result invalid')
# Bad inputs and malformed records must not mutate anything.
init(state)
for item,n,d in [(0,1,0),(7,1,0),(12,1,0),(1,0,0),(1,577,0),(1,1,1),(10,2,60),(10,1,61),(11,1,133),(10,1,0)]:
 before=bytes(state);check(add(state,item,n,d)==-1 and bytes(state)==before,'invalid add atomic')
for offset,value in [(0,7),(0,12),(2,65),(4,1),(6,1),(16,1),(18,1),(72,9),(76,2)]:
 init(state);state[offset]=value;before=bytes(state)
 check(valid(state)==-1,'bad state accepted');check(craft(state,0)==-1 and add(state,1,1,0)==-1 and bytes(state)==before,'malformed mutation')
# Full slots: crafting may free one ingredient slot to fit output, or refuse.
put([[5,1,0,0]]+[[2,64,0,0] for _ in range(8)])
check(craft(state,0)==1 and slots()[0]==[8,4,0,0],'freed ingredient slot')
put([[5,2,0,0]]+[[2,64,0,0] for _ in range(8)]);before=bytes(state)
check(craft(state,0)==0 and bytes(state)==before,'full craft consumed inputs')
# Playable bootstrap: logs -> planks -> sticks -> wooden pick -> stone pick.
init(state);check(craft(state,0)==1 and craft(state,0)==1 and craft(state,1)==1 and craft(state,2)==1,'bootstrap crafting')
wood=next(i for i,s in enumerate(slots()) if s[0]==10);struct.pack_into('<I',state,72,wood)
check(duration(state,1)==800,'wooden mining speed')
for _ in range(59):check(wear(state)==0,'tool wear')
check(slots()[wood][2]==1,'remaining durability');wear(state)
check(slots()[wood]==[0,0,0,0] and duration(state,1)==-1,'broken tool still usable')
check(add(state,1,3,0)==1 and craft(state,3)==1,'stone progression')
stone=next(i for i,s in enumerate(slots()) if s[0]==11);struct.pack_into('<I',state,72,stone)
check(duration(state,1)==400,'stone speed');struct.pack_into('<I',state,76,1)
check(duration(state,1)==1 and duration(state,7)==-1,'creative/bedrock')
struct.pack_into('<I',state,72,0);check(consume(state)==1 and slots()[0][1]==31,'placement consumption')
# Independent UI previews and resource-conserving slot moves, including tools.
for _ in range(1500):
 s=[]
 for slot in range(9):
  item=rng.choice([0,1,2,5,8,9,10,11])
  s.append([item,1 if item>=10 else rng.randint(1,64),rng.randint(1,60 if item==10 else 132) if item>=10 else 0,0] if item else [0,0,0,0])
 put(s,rng.randrange(9),rng.randrange(2));before=bytes(state)
 recipe=rng.randrange(4)
 check(preview(state,recipe)==(1 if model_craft(s,recipe) is not None else 0) and bytes(state)==before,'preview mutated input or mismatched recipe')
 for item in [1,5,8,9,10,11]:check(count(state,item)==sum(v[1] for v in s if v[0]==item),'owned ingredient count')
 source=rng.randrange(9);dest=rng.randrange(9);expected=[v[:] for v in s]
 if source!=dest and expected[source][0]:
  a=expected[source];b=expected[dest]
  if a[0]==b[0] and a[0]<10:
   n=min(a[1],64-b[1]);a[1]-=n;b[1]+=n
   if not a[1]:a[:]=[0,0,0,0]
  else:expected[source],expected[dest]=b,a
 changed=expected!=s
 check(transfer(state,source,dest)==int(changed) and slots()==expected,'slot transfer reference')
 check(bytes(state)[72:]==before[72:] and valid(state)==0,'transfer metadata or canary')
init(state);before=bytes(state)
for a,b in [(9,0),(0,9),(2**64-1,0)]:check(transfer(state,a,b)==-1 and bytes(state)==before,'invalid transfer atomic')
check(preview(state,4)==-1 and bytes(state)==before,'invalid recipe preview')
for item in [0,7,12,65538,2**64-1]:check(count(state,item)==0,'invalid count aliases registered item')
print(f'PASS: {checks} independent inventory/crafting/conservation/durability assertions')
