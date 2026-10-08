"""Independent portable demo snapshot format and transactional decode checks."""
import ctypes as C
import random
import struct
import sys

lib=C.CDLL(sys.argv[1])
encode=lib.snapshot_encode;encode.argtypes=[C.c_void_p,C.c_void_p,C.c_void_p,C.c_uint64];encode.restype=C.c_int64
decode=lib.snapshot_decode;decode.argtypes=[C.c_void_p,C.c_uint64,C.c_void_p,C.c_void_p];decode.restype=C.c_int64
checks=0

def check(value,message='snapshot assertion'):
 global checks
 checks+=1
 assert value,message

def fnv(data):
 value=0xcbf29ce484222325
 for byte in data:value=((value^byte)*0x100000001b3)&0xffffffffffffffff
 return value

def reference(current,base):
 records=b''.join(struct.pack('<HHHH',i//4096,i%4096,value,0)
                  for i,value in enumerate(current) if value!=base[i])
 count=len(records)//8
 return struct.pack('<8sIIIIQQQQQ',b'VXADEMO\0',1,0,1,count,42,len(records),fnv(records),0,0)+records

def buffer(data):return C.create_string_buffer(data,len(data))

def repair(blob):
 result=bytearray(blob)
 struct.pack_into('<Q',result,40,fnv(result[64:]))
 return bytes(result)

rng=random.Random(7719)
base_values=[rng.randrange(7) for _ in range(16384)]
# Some immutable bedrock in the independent fixture.
for i in range(0,16384,199):base_values[i]=7
base=(C.c_uint16*16384)(*base_values)
current=(C.c_uint16*16384)(*base_values)
output=(C.c_ubyte*(131136+32))()
for edits in [0,1,2,4096,100,16384]:
 values=list(base_values)
 for i in rng.sample(range(16384),edits):
  if values[i]!=7:values[i]=(values[i]+1+rng.randrange(6))%7
 current[:]=values
 expected=reference(values,base_values)
 C.memset(output,0xa5,len(output))
 check(encode(current,base,output,len(expected))==len(expected),'encoded length')
 check(bytes(output[:len(expected)])==expected,'independent wire bytes')
 check(bytes(output[len(expected):])==b'\xa5'*(len(output)-len(expected)),'encode canary')
 restored=(C.c_uint16*(16384+8))()
 C.memset(restored,0xa5,C.sizeof(restored))
 check(decode(buffer(expected),len(expected),base,restored)==0,'decode')
 check(list(restored[:16384])==values,'all decoded cells')
 check(bytes(restored)[32768:]==b'\xa5'*16,'decode canary')
 before=bytes(output)
 check(encode(current,base,output,len(expected)-1)==-2,'capacity')
 check(bytes(output)==before,'capacity preserved output')
# Both maximum record count and zero-record saves have independent goldens.
base_zero=(C.c_uint16*16384)()
all_changed=(C.c_uint16*16384)(*([6]*16384))
check(encode(all_changed,base_zero,output,131136)==131136)
check(bytes(output[:131136])==reference([6]*16384,[0]*16384))
max_blob=bytes(output[:131136])
restored=(C.c_uint16*16384)()
check(decode(buffer(max_blob),len(max_blob),base_zero,restored)==0)
check(list(restored)==[6]*16384)
# Known values rather than regenerating the production codec's checksum algorithm.
check(fnv(b'')==0xcbf29ce484222325)
check(fnv(b'hello')==0xa430d84680aabd0b)
small=[0]*16384;small[0]=1;small[15]=2;small[4096]=6
valid=reference(small,[0]*16384)

def reject(blob,baseline=base_zero):
 C.memset(restored,0xcd,C.sizeof(restored))
 before=bytes(restored)
 check(decode(buffer(blob or b'\0'),len(blob),baseline,restored)==-1,'invalid save accepted')
 check(bytes(restored)==before,'invalid decode mutated output')

for length in range(len(valid)):
 reject(valid[:length])
reject(valid+b'\0')
for offset in range(64):
 blob=bytearray(valid);blob[offset]^=0x80;reject(bytes(blob))
for offset,value in [(20,16385),(8,2),(12,1),(16,2)]:
 blob=bytearray(valid);struct.pack_into('<I',blob,offset,value);reject(bytes(blob))
for offset,value in [(24,43),(32,0),(48,1),(56,1)]:
 blob=bytearray(valid);struct.pack_into('<Q',blob,offset,value);reject(bytes(blob))
# Repair checksum to ensure semantic validations are independently exercised.
for offset,value in [(64,4),(66,4096),(68,7),(68,8),(68,65535),(70,1),(68,0)]:
 blob=bytearray(valid);struct.pack_into('<H',blob,offset,value);reject(repair(blob))
blob=bytearray(valid);blob[72:80]=blob[64:72];reject(repair(blob)) # duplicate
blob=bytearray(valid);blob[64:72],blob[80:88]=blob[80:88],blob[64:72];reject(repair(blob))
bad_base=(C.c_uint16*16384)();bad_base[100]=8;reject(valid,bad_base)
bedrock_base=(C.c_uint16*16384)();bedrock_base[0]=7;reject(valid,bedrock_base)
for baseline_changed,current_changed in [(8,0),(0,8),(7,0),(0,7),(65535,0),(0,65535)]:
 bad_base=(C.c_uint16*16384)();bad_current=(C.c_uint16*16384)()
 bad_base[123]=baseline_changed;bad_current[123]=current_changed
 C.memset(output,0xce,len(output));before=bytes(output)
 check(encode(bad_current,bad_base,output,131136)==-1)
 check(bytes(output)==before,'encode invalid output preservation')
# Random single-byte corruption must be caught regardless of where it occurs.
for _ in range(400):
 blob=bytearray(max_blob);offset=rng.randrange(len(blob));blob[offset]^=1<<rng.randrange(8)
 reject(bytes(blob))
print(f'PASS: {checks} snapshot wire-format/corruption/transaction assertions')
