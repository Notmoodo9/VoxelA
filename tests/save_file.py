"""Real filesystem tests for the assembly atomic save adapter (Linux/Windows)."""
import ctypes as C
import os
from pathlib import Path
import subprocess
import sys
import tempfile

lib_path=str(Path(sys.argv[1]).resolve())
lib=C.CDLL(lib_path)
save=lib.file_save;save.argtypes=[C.c_char_p,C.c_void_p,C.c_uint64];save.restype=C.c_int64
load=lib.file_load;load.argtypes=[C.c_char_p,C.c_void_p,C.c_uint64];load.restype=C.c_int64

def encoded(path):return os.fsencode(path)
def buffer(data):return C.create_string_buffer(data,len(data))
def store(path,data):return save(encoded(path),buffer(data),len(data))

if len(sys.argv)>2 and sys.argv[2]=='--disk-limit':
 import resource
 import signal
 resource.setrlimit(resource.RLIMIT_FSIZE,(1024,1024))
 signal.signal(signal.SIGXFSZ,signal.SIG_IGN)
 assert store(Path(sys.argv[3]),b'x'*131136)==-1
 sys.exit(0)

checks=0
def check(value,message='file assertion'):
 global checks
 checks+=1
 assert value,message

with tempfile.TemporaryDirectory(prefix='VoxelA save test ') as folder:
 root=Path(folder);path=root/'world edits.vxa'
 for data in [b'',b'first',bytes(range(256))*512+b'end',b'replacement',b'']:
  check(store(path,data)==0,'save commit')
  check(path.read_bytes()==data,'exact file contents')
  check(not Path(str(path)+'.tmp').exists(),'temporary cleaned')
  output=(C.c_ubyte*(131136+16))();C.memset(output,0xa5,len(output))
  check(load(encoded(path),output,131136)==len(data),'read length')
  check(bytes(output[:len(data)])==data,'read contents')
  check(bytes(output[len(data):])==b'\xa5'*(len(output)-len(data)),'read canary')
 check(store(path,b'prior generation')==0)
 temporary=Path(str(path)+'.tmp');temporary.write_bytes(b'other writer or interrupted save')
 check(store(path,b'new generation')==-1,'existing temporary accepted')
 check(path.read_bytes()==b'prior generation','prior save altered')
 check(temporary.read_bytes()==b'other writer or interrupted save','other temporary altered')
 temporary.unlink()
 check(store(root/'missing'/'world',b'new')==-1,'missing directory')
 check(store(root,b'new')==-1,'directory replaced')
 check(not Path(str(root)+'.tmp').exists(),'failed rename temp cleanup')
 check(save(b'',buffer(b'x'),1)==-1,'empty path')
 check(save(b'a'*960,buffer(b'x'),1)==-1,'path limit')
 check(save(encoded(path),buffer(b'x'),131137)==-1,'save capacity')
 check(path.read_bytes()==b'prior generation','invalid save changed prior file')
 output=(C.c_ubyte*(131136+16))();C.memset(output,0xa5,len(output))
 check(load(encoded(root/'absent'),output,131136)==-1,'missing read')
 check(load(encoded(root),output,131136)==-1,'directory read')
 check(load(encoded(path),output,131137)==-1,'read capacity')
 path.write_bytes(b'x'*131137)
 check(load(encoded(path),output,131136)==-1,'oversize accepted')
 check(bytes(output[131136:])==b'\xa5'*16,'oversize canary')
 path.write_bytes(b'12345')
 check(load(encoded(path),output,4)==-1,'caller capacity not enforced')
 check(load(encoded(path),output,5)==5,'exact capacity')
 check(load(encoded(path),output,0)==-1,'zero capacity nonempty')
 path.write_bytes(b'')
 check(load(encoded(path),output,0)==0,'zero capacity empty')
 if os.name!='nt':
  # Short write followed by EFBIG must preserve the committed generation.
  path.write_bytes(b'prior generation')
  result=subprocess.run([sys.executable,__file__,lib_path,'--disk-limit',str(path)],capture_output=True)
  check(result.returncode==0,result.stderr.decode())
  check(path.read_bytes()==b'prior generation','disk-limit replaced prior save')
  check(not temporary.exists(),'disk-limit cleanup')
  # Exclusive/no-follow opening must reject a symlink at the temporary path.
  victim=root/'victim';victim.write_bytes(b'keep')
  temporary.symlink_to(victim)
  check(store(path,b'new')==-1)
  check(victim.read_bytes()==b'keep' and temporary.is_symlink(),'temporary symlink followed/removed')
  temporary.unlink()
  os.mkfifo(root/'fifo')
  check(load(encoded(root/'fifo'),output,131136)==0,'FIFO read hung or failed')
print(f'PASS: {checks} real filesystem save/load/failure assertions ({os.name})')
