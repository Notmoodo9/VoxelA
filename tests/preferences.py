"""Persistent settings codec: exact layout, validated atomic decode, transient reset."""
import ctypes as C
import random
import struct
import sys
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64
encode=lib.preferences_encode;encode.argtypes=[P,U,U,P];encode.restype=I
decode=lib.preferences_decode;decode.argtypes=[P,U,P,P];decode.restype=I
rng=random.Random(17);settings=(C.c_uint32*8)();out=C.create_string_buffer(96);restored=(C.c_uint32*8)();visual=(C.c_uint32*2)()
def checksum(data):
 h=0xcbf29ce484222325
 for b in data:h=((h^b)*0x100000001b3)&((1<<64)-1)
 return h
for _ in range(300):
 values=[rng.randrange(60,111),rng.randrange(10,301),rng.randrange(2),rng.randrange(2),rng.randrange(2),rng.randrange(25,401),1,1]
 settings[:]=values;quality=rng.randrange(3);far=rng.randrange(2,257)
 out.raw=b'\xa5'*96
 assert encode(settings,quality,far,out)==64 and out.raw[64:]==b'\xa5'*32
 expected=b'VXAPREFS'+struct.pack('<IIQQ',1,64,0,0)+struct.pack('<8I',*values[:6],quality,far)
 expected=expected[:16]+struct.pack('<Q',checksum(expected[32:]))+expected[24:]
 assert out.raw[:64]==expected
 assert decode(out,64,restored,visual)==0 and list(restored)==values[:6]+[0,0] and list(visual)==[quality,far]
# Every altered byte must reject unchanged outputs, including headers/checksum.
reference=out.raw[:64]
for i in range(64):
 corrupt=bytearray(reference);corrupt[i]^=1
 src=C.create_string_buffer(bytes(corrupt));restored[:]=[123]*8;visual[:]=[456]*2
 assert decode(src,64,restored,visual)==-1 and list(restored)==[123]*8 and list(visual)==[456]*2
for length in [0,1,63,65,2**64-1]:
 assert decode(out,length,restored,visual)==-1 and list(restored)==[123]*8
# Invalid fields with recomputed checksum still reject; no validator bypass.
for offset,value in [(32,59),(32,111),(36,9),(40,2),(44,2),(48,2),(52,24),(56,3),(60,1),(60,257)]:
 corrupt=bytearray(reference);struct.pack_into('<I',corrupt,offset,value);struct.pack_into('<Q',corrupt,16,checksum(corrupt[32:]))
 src=C.create_string_buffer(bytes(corrupt));assert decode(src,64,restored,visual)==-1 and list(restored)==[123]*8
settings[:]=[95,100,0,0,0,100,0,0]
for quality,far in [(3,64),(0,1),(2,257)]:
 out.raw=b'\xa5'*96;assert encode(settings,quality,far,out)==-1 and out.raw==b'\xa5'*96
settings[0]=111;assert encode(settings,2,64,out)==-1 and out.raw==b'\xa5'*96
print('PASS: 300 preferences layouts/roundtrips, byte corruption, invalid recomputed fields, canaries and transient reset')
