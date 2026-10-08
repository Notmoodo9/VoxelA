"""Shaped crafting: independent recipes, ownership, transactions and conservation."""
import ctypes as C
import itertools,random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;checks=0

def bind(name,args):
 f=getattr(lib,name);f.argtypes=args;f.restype=I;return f
init=bind('inventory36_init',[P]);valid=bind('craft_valid',[P]);preview=bind('craft_preview',[P]);click=bind('craft_click',[P,I,I]);clear=bind('craft_clear',[P]);take=bind('craft_take',[P,I]);repeat=bind('craft_repeat',[P]);fill=bind('craft_fill',[P,I]);swap=bind('inventory36_swap',[P,I,I]);collect=bind('craft_collect',[P]);canfill=bind('craft_can_fill',[P,I])
state=(C.c_ubyte*352)()
def check(value,message):
 global checks
 checks+=1;assert value,message

def fresh():
 C.memset(state,0,336);init(state);C.memset(C.byref(state,336),0xa5,16)
def put(index,item,count=1,dur=0):struct.pack_into('<HHHH',state,index*8,item,count,dur,0)
def grid(items):
 for i,item in enumerate(items):put(38+i,item,(1 if item==10 else 3) if item else 0,60 if item==10 else 0)
def expected(items):
 occupied=[(i,x) for i,x in enumerate(items) if x]
 if len(occupied)==1 and occupied[0][1]==5:return (4<<16)|8
 if items in [(8,0,8,0),(0,8,0,8)]:return (4<<16)|9
 return 0
fresh()
for items in itertools.product([0,5,8,9,10],repeat=4):
 grid(items);before=bytes(state);check(preview(state)==expected(items),'shaped recipe translation/extras');check(bytes(state)==before,'preview mutated');check(valid(state)==0,'grid validation')
for i in range(4):
 fresh();put(38+i,5,64);check(repeat(state)==64,'repeat logs');check(preview(state)==0,'consumed grid');check(sum(struct.unpack_from('<H',state,j*8+2)[0] for j in range(36) if struct.unpack_from('<H',state,j*8)[0]==8)==256,'repeat output')
fresh();grid((8,0,8,0));put(37,9,61);before=bytes(state);check(take(state,0)==0 and bytes(state)==before,'cursor overflow atomic')
put(37,9,60);check(take(state,0)==1 and struct.unpack_from('<HH',state,296)==(9,64),'cursor merge')
fresh();grid((8,8,0,0));before=bytes(state);check(take(state,0)==0 and bytes(state)==before,'horizontal sticks rejected')
fresh();grid((8,0,8,0));put(37,5,1);before=bytes(state);check(take(state,0)==0 and bytes(state)==before,'different cursor item atomic')
fresh();grid((5,0,0,0));struct.pack_into('<I',state,292,1);before=bytes(state);check(take(state,0)==0 and repeat(state)==0 and bytes(state)==before,'creative craft refused')
fresh();check(fill(state,0)==1 and struct.unpack_from('<HH',state,304)==(5,1),'log autofill');check(take(state,1)==1 and fill(state,1)==1 and preview(state)==(4<<16)|9,'sticks autofill');check(clear(state)==1 and bytes(state[304:336])==bytes(32),'clear grid')
fresh();before=bytes(state);check(fill(state,1)==0 and bytes(state)==before,'missing autofill atomic')
fresh()
for i in range(36):put(i,8,64)
grid((5,0,0,0));before=bytes(state);check(clear(state)==0 and click(state,0,2)==0 and take(state,1)==0 and bytes(state)==before,'full bag transactions')
# Availability uses execution but never mutates ownership or output canaries.
for recipe in (0,1,2,-1):
 fresh();before=bytes(state);want=1 if recipe==0 else 0 if recipe==1 else -1
 check(canfill(state,recipe)==want and bytes(state)==before,'autofill availability immutable')
# Empty tools retain exact wear in grid, cursor and hotbar swaps.
fresh();put(37,11,1,17);check(click(state,3,0)==1 and struct.unpack_from('<HHHH',state,328)==(11,1,17,0),'tool placement');check(click(state,3,1)==1 and struct.unpack_from('<HHHH',state,296)==(11,1,17,0),'tool pickup');check(click(state,0,1)==1 and click(state,0,2)==1,'tool return');check(swap(state,2,8)==1 and struct.unpack_from('<HHHH',state,64)==(11,1,17,0),'number swap')
# Double-click includes grid cells and never merges tools or exceeds64.
fresh();put(37,8,1);put(2,8,60);put(38,8,10);put(39,5,3)
check(collect(state)==1 and struct.unpack_from('<HH',state,296)==(8,64) and struct.unpack_from('<HH',state,304)==(8,7),'collect capacity/grid')
before=bytes(state);check(collect(state)==0 and bytes(state)==before,'full collect no-op')
put(37,10,1,60);before=bytes(state);check(collect(state)==0 and bytes(state)==before,'tools never collected into stack')
# Invalid parameters and malformed grid bytes reject without mutation.
for fn,args in [(click,(4,0)),(click,(0,3)),(take,(2,)),(fill,(2,)),(swap,(36,0)),(swap,(0,9))]:
 before=bytes(state);check(fn(state,*args)==-1 and bytes(state)==before,'invalid parameter')
for offset,value in [(304,7),(306,65),(308,1),(310,1),(304,0)]:
 fresh();grid((5,0,0,0));struct.pack_into('<H',state,offset,value);before=bytes(state)
 check(valid(state)==-1,'malformed grid');check(preview(state)==-1 and take(state,0)==-1 and clear(state)==-1 and fill(state,0)==-1 and click(state,0,0)==-1 and bytes(state)==before,'malformed transaction atomic')
# Material-equivalent conservation includes both bag/cursor and every grid cell.
fresh();put(2,8,30);put(3,9,20);rng=random.Random(81234)
def mass():
 result=0
 for offset in list(range(0,288,8))+[296,304,312,320,328]:
  item,count=struct.unpack_from('<HH',state,offset);result+=count*{0:0,2:1,5:8,8:2,9:1}.get(item,0)
 return result
initial=mass()
for _ in range(3000):
 action=rng.randrange(6)
 if action==0:click(state,rng.randrange(4),rng.randrange(3))
 elif action==1:take(state,rng.randrange(2))
 elif action==2:fill(state,rng.randrange(2))
 elif action==3:clear(state)
 elif action==4:repeat(state)
 else:
  invclick=bind('inventory36_click',[P,I,I]);invclick(state,rng.randrange(36),rng.randrange(2))
 check(valid(state)==0 and mass()==initial,'random conservation/validation')
 check(bytes(state[336:])==b'\xa5'*16,'state canary')
print(f'PASS: {checks} shaped crafting and inventory transaction assertions')
