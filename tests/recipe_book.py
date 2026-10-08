"""Independent bounded search, append/delete and recipe list scrolling."""
import ctypes as C,random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('book_init',[P]);search=bind('book_search',[P,P]);append=bind('book_append',[P,I]);back=bind('book_backspace',[P]);scroll=bind('book_scroll',[P,I]);recipe=bind('book_recipe',[P,I]);names=['PLANKS','STICKS','WOOD PICK','STONE PICK','CRAFTING TABLE','CHEST']
def check(v,msg):
 global checks
 checks+=1;assert v,msg
b=C.create_string_buffer(80);C.memset(b,165,80);check(init(b)==0,'init');check(b.raw[64:]==b'\xa5'*16,'init canary')
def verify(query,offset=0):
 ids=[i for i,name in enumerate(names) if query.upper() in name];raw=b.raw
 check(raw[:17]==query.upper().encode()+b'\0'*(17-len(query)),'canonical query')
 check(raw[17:24]==b'\0'*7 and raw[56:64]==b'\0'*8,'reserved zero')
 check(struct.unpack_from('<II',raw,24)==(offset,len(ids)),'scroll/count')
 check(list(struct.unpack_from('<6I',raw,32))==ids+[2**32-1]*(6-len(ids)),'filtered IDs')
 for row in range(2):check(recipe(b,row)==(ids[offset+row] if offset+row<len(ids) else -1),'visible recipe')
 check(raw[64:]==b'\xa5'*16,'state canary')
rng=random.Random(9911)
for q in ['', 'p','pick','wood','stone','table','chest','NO MATCH','crafting',' ','sticks']+[''.join(rng.choice('abcdeiklpstow ') for _ in range(rng.randrange(17))) for _ in range(3000)]:
 check(search(b,C.create_string_buffer(q.encode()))==0,'search');verify(q)
 ids=[i for i,n in enumerate(names) if q.upper() in n];offset=0
 for direction in [-1,-1,-1,-1,-1,1,1,1,1,1,0]:
  want=min(max(len(ids)-2,0),offset+1) if direction<0 else max(0,offset-1) if direction>0 else offset
  check(scroll(b,direction)==int(want!=offset),'scroll bounds');offset=want;verify(q,offset)
q='';search(b,C.create_string_buffer(b''))
for _ in range(4000):
 if rng.randrange(3)==0:
  want=int(bool(q));check(back(b)==want,'backspace');q=q[:-1]
 else:
  ch=rng.choice('a bCDEiklPstOW');want=int(len(q)<16);check(append(b,ord(ch))==want,'append bound')
  if want:q+=ch
 verify(q)
for text in (b'x'*17,b'a\n',b'\xff',b'\x1f'):
 before=b.raw;check(search(b,C.create_string_buffer(text))==-1 and b.raw==before,'invalid search immutable')
for ch in (-1,0,31,127,256):
 before=b.raw;check(append(b,ch)==-1 and b.raw==before,'invalid append immutable')
for row in (-1,2,3):check(recipe(b,row)==-1,'invalid row')
print(f'recipe book: {checks} independent search/scroll/ownership checks passed')
