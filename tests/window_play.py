"""Script real SDL event dispatch in an isolated directory using a test-only shim."""
from pathlib import Path
import os
import subprocess
import struct
import sys
import tempfile
binary=str(Path(sys.argv[1]).resolve());driver=str(Path(sys.argv[2]).resolve())
with tempfile.TemporaryDirectory(prefix='VoxelA actual player ') as folder:
 env=os.environ.copy();env['LD_PRELOAD']=driver
 result=subprocess.run([binary,'--seed','42'],cwd=folder,env=env,capture_output=True,text=True,timeout=90)
 assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
 assert result.stdout.count('Saved player and streamed edits')==2,result.stdout
 assert 'Loaded player and streamed edits' in result.stdout,result.stdout
 assert 'failed' not in result.stdout.lower(),result.stdout
 data=(Path(folder)/'voxela-world.vxa').read_bytes()
 assert data[:8]==b'VXAWALK\0' and struct.unpack_from('<Q',data,24)[0]==42
 x,y,z=struct.unpack_from('<ddd',data,64)
 assert z<-16,(x,y,z,'did not cross a chunk boundary')
 count=struct.unpack_from('<I',data,20)[0]
 assert count>0,'mouse breaking did not record an edit'
 assert struct.unpack_from('<I',data,8)[0]==2,'old gameplay format'
 inventory=data[128+count*32:]
 assert len(inventory)==80 and struct.unpack_from('<II',inventory,72)==(4,0),'selected tool/mode persistence'
 tool=struct.unpack_from('<HHHH',inventory,32)
 assert tool[0:2]==(10,1) and 1<=tool[2]<60,('crafting/tool wear not dispatched',tool)
 assert struct.unpack_from('<H',inventory,2)[0]>32,'mined dirt not collected'
 value=0xcbf29ce484222325
 for i,b in enumerate(data):value=((value^(0 if 40<=i<48 else b))*0x100000001b3)&0xffffffffffffffff
 assert value==struct.unpack_from('<Q',data,40)[0]
 assert not (Path(folder)/'voxela-world.vxa.tmp').exists()
 print(f'PASS: actual SDL player loop, E inventory menu, recipe mouse clicks, finite pickups/tool wear, held-mouse mining, walking/jumping across chunks (Z={z:.2f}), {count} persisted edits, F5/F9, Escape pause, click resume and F10 exit')
