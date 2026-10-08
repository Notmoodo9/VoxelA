"""World-owned container store identities, ownership and atomic aggregate codec."""
import ctypes as C
import random,struct,sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;I=C.c_int64;U=C.c_uint64;checks=0

def bind(n,args):
 f=getattr(lib,n);f.argtypes=args;f.restype=I;return f
init=bind('container_store_init',[P]);valid=bind('container_store_valid',[P]);find=bind('container_store_find',[P,P]);resolve=bind('container_store_resolve',[P,U]);add=bind('container_store_add',[P,P,I]);remove=bind('container_store_remove',[P,U]);encode=bind('container_store_encode',[P,U,P,U]);decode=bind('container_store_decode',[P,U,P,U])
store=(C.c_ubyte*16416)()
def check(v,m):
 global checks
 checks+=1;assert v,m

def fresh():C.memset(store,0xa5,len(store));check(init(store)==0 and valid(store)==0,'init')
def xyz(x,y,z):return (I*3)(x,y,z)
fresh();check(bytes(store[16400:])==b'\xa5'*16,'init canary');check(find(store,xyz(0,100,0))==0 and resolve(store,1)==0,'empty lookup')
check(add(store,xyz(-1,100,-16),1)==1 and add(store,xyz(0,100,-16),2)==2,'create identities')
first=resolve(store,1);second=resolve(store,2);check(first==C.addressof(store)+24 and second==C.addressof(store)+280,'record addresses');check(find(store,xyz(-1,100,-16))==1,'negative position lookup')
before=bytes(store);check(add(store,xyz(-1,100,-16),2)==-3 and bytes(store)==before,'duplicate location atomic')
for pos,kind in [(xyz(0,-1,0),1),(xyz(0,256,0),1),(xyz(30000000,0,0),1),(xyz(0,100,0),3)]:
 before=bytes(store);check(add(store,pos,kind)==-1 and bytes(store)==before,'invalid create atomic')
struct.pack_into('<HHHH',store,56,11,1,17,0);before=bytes(store);check(remove(store,1)==-2 and bytes(store)==before,'nonempty removal refused')
struct.pack_into('<HHHH',store,312,8,12,0,0)
struct.pack_into('<Q',store,56,0);check(remove(store,1)==1 and resolve(store,1)==0 and find(store,xyz(0,100,-16))==2,'remove/shift identities');check(resolve(store,2)==C.addressof(store)+24,'resolve shifted record');check(C.string_at(resolve(store,2)+32,8)==struct.pack('<HHHH',8,12,0,0),'shift preserves nonempty contents');check(add(store,xyz(-1,100,-16),1)==3 and resolve(store,1)==0,'destroyed identity never reused');check(remove(store,999)==0,'missing remove')
# Independently model allocation/removal and confirm every live identity/location.
fresh();rng=random.Random(729);model={};nextid=1
for _ in range(1000):
 if rng.randrange(3)==0 and model:
  item=rng.choice(list(model));check(remove(store,item)==1,'random remove');del model[item]
 else:
  pos=(rng.randrange(-8,9),100,rng.randrange(-8,9));kind=rng.choice([1,2]);before=bytes(store)
  expected=-3 if pos in [v[0] for v in model.values()] else -2 if len(model)==64 else nextid
  got=add(store,xyz(*pos),kind);check(got==expected,'random add')
  if got>0:model[got]=(pos,kind);nextid+=1
  else:check(bytes(store)==before,'rejected random add mutation')
 check(valid(store)==0 and struct.unpack_from('<QQ',store,0)==(len(model),nextid),'random metadata')
 for item,(pos,kind) in model.items():
  pointer=resolve(store,item);check(pointer>0 and find(store,xyz(*pos))==item,'identity/position resolution');check(C.string_at(pointer,32)==struct.pack('<qqqII',*pos,kind,0),'record contents')
 check(bytes(store[16400:])==b'\xa5'*16,'random canary')
# Aggregate blob independently derived, including contents and a table grid.
fresh();add(store,xyz(-1,100,-16),1);add(store,xyz(0,100,-16),2)
struct.pack_into('<HHHH',store,56,11,1,17,0);struct.pack_into('<HHHH',store,312,8,12,0,0)
out=(C.c_ubyte*16440)();C.memset(out,0xa5,len(out));seed=42
n=encode(store,seed,out,16424);check(n==552,'two-entry length')
def repaired(data):
 data=bytearray(data);h=0xcbf29ce484222325
 for i,b in enumerate(data):h=((h^(0 if 32<=i<40 else b))*0x100000001b3)&0xffffffffffffffff
 struct.pack_into('<Q',data,32,h);return bytes(data)
expected=repaired(struct.pack('<8sIIQQQ',b'VXASTOR\0',1,2,3,seed,0)+bytes(store[16:528]));blob=bytes(out[:n]);check(blob==expected and bytes(out[n:])==b'\xa5'*(len(out)-n),'exact wire/canary');saved=bytes(store);init(store)
inputbuf=C.create_string_buffer(blob);check(decode(inputbuf,n,store,seed)==0 and bytes(store)==saved and inputbuf.raw[:n]==blob,'roundtrip/input immutable')
def reject(data):
 before=bytes(store);check(decode(C.create_string_buffer(bytes(data)),len(data),store,seed)==-1 and bytes(store)==before,'malformed/atomic')
for i in range(n):
 b=bytearray(blob);b[i]^=0x80;reject(b)
for offset,value,fmt in [(8,2,'I'),(12,65,'I'),(16,0,'Q'),(16,0xffffffffffffffff,'Q'),(24,43,'Q'),(40,0,'Q'),(296,1,'Q'),(72,3,'I'),(76,1,'I'),(80,7,'H'),(82,2,'H'),(84,133,'H'),(48,30000000,'q'),(56,-1,'q'),(408,5,'H')]:
 b=bytearray(blob);struct.pack_into('<'+fmt,b,offset,value);reject(repaired(b))
# Duplicate coordinate with valid IDs/outer checksum.
b=bytearray(blob);b[304:328]=b[48:72];reject(repaired(b))
for length in [0,39,40,551,553]:reject(blob[:length] if length<=len(blob) else blob+b'x')
before=bytes(out);check(encode(store,seed,out,n-1)==-2 and bytes(out)==before,'encode capacity atomic')
# All64 records and empty-store canonical payload.
fresh()
for i in range(64):check(add(store,xyz(i,100,0),1)==i+1,'capacity fill')
before=bytes(store);check(add(store,xyz(100,100,0),1)==-2 and bytes(store)==before,'capacity rejection')
check(encode(store,seed,out,16424)==16424 and decode(out,16424,store,seed)==0,'max size roundtrip');check(bytes(out[16424:])==b'\xa5'*16,'max output canary')
fresh();check(encode(store,seed,out,40)==40 and decode(out,40,store,seed)==0 and struct.unpack_from('<QQ',store,0)==(0,1),'empty roundtrip')
struct.pack_into('<Q',store,16,1);before=bytes(out);check(valid(store)==-1 and encode(store,seed,out,16424)==-1 and bytes(out)==before,'unused entry canonical/invalid encode')
print(f'PASS: {checks} container-store identity, allocation and codec assertions')
