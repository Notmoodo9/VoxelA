"""Rebuild offline art in isolation and verify the embedded atlas/PNG contract."""
from pathlib import Path
import shutil,struct,subprocess,sys,tempfile,zlib
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='VoxelA materials ') as d:
 stage=Path(d);(stage/'tools').mkdir();(stage/'assets/textures').mkdir(parents=True)
 shutil.copyfile(root/'tools/generate_play_assets.py',stage/'tools/generate_play_assets.py')
 subprocess.run([sys.executable,str(stage/'tools/generate_play_assets.py')],check=True)
 for name in ['blocks.rgba','blocks.png','font5x7.bin']:
  assert (stage/'assets/textures'/name).read_bytes()==(root/'assets/textures'/name).read_bytes(),f'stale or nondeterministic {name}'
raw=(root/'assets/textures/blocks.rgba').read_bytes();assert len(raw)==1024*64*4
png=(root/'assets/textures/blocks.png').read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
offset=8;compressed=b''
while offset<len(png):
 size=struct.unpack_from('>I',png,offset)[0];kind=png[offset+4:offset+8];body=png[offset+8:offset+8+size]
 assert zlib.crc32(kind+body)&0xffffffff==struct.unpack_from('>I',png,offset+8+size)[0]
 if kind==b'IHDR':assert struct.unpack('>IIBBBBB',body)==(1024,64,8,6,0,0,0)
 if kind==b'IDAT':compressed+=body
 offset+=size+12
rows=zlib.decompress(compressed);assert len(rows)==64*(4096+1)
for y in range(64):assert rows[y*4097:y*4097+4097]==b'\0'+raw[(63-y)*4096:(64-y)*4096]
for tile in range(16):
 pixels=[raw[y*4096+tile*256+x*4:y*4096+tile*256+x*4+4] for y in range(64) for x in range(64)]
 if tile==0:assert set(pixels)=={b'\xff'*4},'UI white tile corrupted'
 elif tile in (6,11,12,13):assert {p[3] for p in pixels}=={0,255},'cutout silhouette missing'
 else:assert all(p[3]==255 for p in pixels) and len(set(pixels))>20,'opaque material missing variation'
assert len((root/'assets/textures/font5x7.bin').read_bytes())==448
print('PASS: deterministic 64px atlas, PNG CRC/orientation, all material/cutout tiles and font bounds')
