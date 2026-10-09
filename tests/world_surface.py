"""Read-only actual-region surfaces: dirty edits, disk records and generation parity."""
import ctypes as C
from pathlib import Path
import tempfile, sys, time
lib=C.CDLL(sys.argv[1]);P=C.c_void_p;U=C.c_uint64;I=C.c_int64

def bind(name,args):
    f=getattr(lib,name);f.argtypes=args;f.restype=I;return f
init=bind('world_store_init',[P,P]);get=bind('world_store_get',[P,P])
edit=bind('world_store_edit',[P,P,U]);close=bind('world_store_close',[P])
acquire=bind('world_store_acquire',[P,P]);surface=bind('world_store_surface',[P,I,I,P])
rinit=bind('region_init',[P,P]);save=bind('region_file_save',[P,P])
native=bind('terrain1_column',[U,I,I,P])
batch=bind('world_store_surface_batch',[P,P,U,P])

def setup(root,version=1,capacity=2,seed=42):
    pool=[C.create_string_buffer(131264) for _ in range(capacity)]
    staging=C.create_string_buffer(131264);entries=(U*(capacity*4))()
    for i,p in enumerate(pool):entries[4*i]=C.addressof(p)
    store=C.create_string_buffer(1024);path=C.create_string_buffer(str(root).encode())
    cfg=(U*6)(seed,version,capacity,C.addressof(entries),C.addressof(path),C.addressof(staging))
    assert init(store,cfg)==0
    return store,pool,staging,entries,path,cfg

def snapshot(owner,root):
    return (owner[0].raw,bytes(owner[3]),tuple(p.raw for p in owner[1]),owner[2].raw,
            {p.name:p.read_bytes() for p in root.iterdir() if p.is_file()})

def query(owner,root,x,z,expected=None):
    out=C.create_string_buffer(b'CANARY!!',8);before=snapshot(owner,root)
    assert surface(owner[0],x,z,out)==0
    actual=(C.c_int32.from_buffer(out).value,C.c_uint32.from_buffer(out,4).value)
    assert snapshot(owner,root)==before, 'surface lookup changed terrain/cache/clock/staging/files'
    assert -255<=actual[0]<=768 and 1<=actual[1]<=7
    if expected is not None:assert actual==expected,(x,z,actual,expected)
    return actual

def rejected(owner,root,x,z):
    out=C.create_string_buffer(b'CANARY!!',8);before=snapshot(owner,root)
    assert surface(owner[0],x,z,out)==-1 and out.raw==b'CANARY!!'
    assert snapshot(owner,root)==before

start=time.monotonic();queries=0
with tempfile.TemporaryDirectory(prefix='VoxelA actual surface ') as folder:
    root=Path(folder);owner=setup(root)
    # Empty-world queries must not create terrain or touch store staging/LRU.
    for x,z in [(0,0),(-1,-1),(63,64),(-30000000,29999999),(29999999,-30000000)]:
        y,b=query(owner,root,x,z);queries+=1
        assert get(owner[0],(I*3)(x,y-1,z))==b
        assert get(owner[0],(I*3)(x,y,z))==0
    # Authoritative dirty resident data beats its prior persisted contents.
    assert edit(owner[0],(I*3)(0,767,0),5)==1
    query(owner,root,0,0,(768,5));queries+=1
    assert close(owner[0])==0
    owner=setup(root);query(owner,root,0,0,(768,5));queries+=1
    assert edit(owner[0],(I*3)(0,767,0),0)==1
    y,b=query(owner,root,0,0);queries+=1
    # Remove a full top section and compare the fallback with actual block API,
    # including generator caves rather than assuming every lower cell is solid.
    lower=((y-1)//16)*16
    for yy in range(lower,y):assert edit(owner[0],(I*3)(0,yy,0),0)>=0
    exposed=query(owner,root,0,0);queries+=1
    yy=lower-1
    while get(owner[0],(I*3)(0,yy,0))==0:yy-=1
    b=get(owner[0],(I*3)(0,yy,0))
    assert exposed==(yy+1,b), (exposed,yy+1,b)
    assert close(owner[0])==0
    owner=setup(root);query(owner,root,0,0,(yy+1,b));queries+=1
    # Existing unreadable/corrupt/wrong-key files must never become generated air.
    wrong=root/'r_0_0_47.vxr';wire=wrong.read_bytes();wrong.write_bytes(b'broken')
    rejected(owner,root,0,0);wrong.write_bytes(wire)
    region=C.create_string_buffer(131264);assert rinit(region,(I*4)(43,0,0,47))==0
    assert save(C.create_string_buffer(str(wrong).encode()),region)==0
    rejected(owner,root,0,0);wrong.write_bytes(wire)
    assert rinit(region,(I*4)(42,1,0,47))==0
    assert save(C.create_string_buffer(str(wrong).encode()),region)==0
    rejected(owner,root,0,0);wrong.write_bytes(wire)
    for x,z in [(-30000001,0),(30000000,0),(0,-30000001),(0,30000000)]:rejected(owner,root,x,z)
    assert close(owner[0])==0
    rejected(owner,root,0,0)
    # Closed and generator0 stores are rejected without touching output.
    legacy=root/'legacy';legacy.mkdir();old=setup(legacy,0)
    rejected(old,legacy,0,0);assert close(old[0])==0
    # Complete old columns keep their actual edited ceiling through extensions.
    oldroot=root/'old';oldroot.mkdir();old=setup(oldroot,0,16)
    for sy in range(16):assert acquire(old[0],(I*3)(-1,sy*16,0))>=0
    assert edit(old[0],(I*3)(-1,123,0),5)==1 and close(old[0])==0
    upgraded=setup(oldroot);query(upgraded,oldroot,-1,0,(124,5));queries+=1
    # Native blended new side agrees with the actual region generation path.
    y,b=query(upgraded,oldroot,0,0);queries+=1
    assert get(upgraded[0],(I*3)(0,y-1,0))==b and get(upgraded[0],(I*3)(0,y,0))==0
    assert close(upgraded[0])==0
    # Old ceilings also suppress native mountains above the old vertical range.
    column=C.create_string_buffer(32);mountain=None
    for x in range(-20000,20000,127):
        assert native(42,x,x//3,column)==0
        if C.c_int32.from_buffer(column).value>300:mountain=(x,x//3);break
    assert mountain is not None
    mountainroot=root/'mountain';mountainroot.mkdir();old=setup(mountainroot,0)
    for sy in range(16):assert acquire(old[0],(I*3)(mountain[0],sy*16,mountain[1]))>=0
    assert edit(old[0],(I*3)(mountain[0],180,mountain[1]),5)==1 and close(old[0])==0
    owner=setup(mountainroot);query(owner,mountainroot,*mountain,(181,5));queries+=1
    assert close(owner[0])==0
    # A corrupt old neighbor rejects missing-section generation and retains data.
    neighbor=oldroot/'r_-1_0_7.vxr';wire=neighbor.read_bytes();neighbor.write_bytes(b'bad')
    owner=setup(oldroot);rejected(owner,oldroot,1,1);assert close(owner[0])==0
    neighbor.write_bytes(wire)
    # A completely recorded shaft has a genuinely negative visible surface.
    shaft=root/'shaft';shaft.mkdir()
    for sy in range(-16,48):
        assert rinit(region,(I*4)(42,-1,-1,sy))==0
        U.from_buffer(region,32).value=1<<15
        C.c_uint32.from_buffer(region,64+15*8).value=1
        cells=(C.c_uint16*4096).from_buffer(region,192+15*8192)
        if sy==-16:
            for i in range(256):cells[i]=7
        if sy==-13:cells[((-200&15)<<8)|255]=5
        path=C.create_string_buffer(str(shaft/f'r_-1_-1_{sy}.vxr').encode())
        assert save(path,region)==0
    owner=setup(shaft);query(owner,shaft,-1,-1,(-199,5));queries+=1
    query(owner,shaft,-2,-1,(-255,7));queries+=1
    # Batches are bounded and publish only after all samples succeed.
    requests=(I*6)(-1,-1,-2,-1,-1,-2);out=C.create_string_buffer(b'Z'*32,32)
    before=snapshot(owner,shaft)
    assert batch(owner[0],requests,3,out)==0
    assert [(C.c_int32.from_buffer(out,i*8).value,C.c_uint32.from_buffer(out,i*8+4).value) for i in range(3)]==[(-199,5),(-255,7),(-255,7)]
    assert out.raw[24:]==b'Z'*8 and snapshot(owner,shaft)==before
    for n in (0,65,2**64-1):
        out.raw=b'Z'*32;assert batch(owner[0],requests,n,out)==-1 and out.raw==b'Z'*32
    # First sample succeeds; second fails after encountering a corrupt region.
    failure=shaft/'r_-1_-1_47.vxr';wire=failure.read_bytes();failure.write_bytes(b'bad')
    requests[:]=(64,64,-1,-1,0,0);out.raw=b'Z'*32;before=snapshot(owner,shaft)
    assert batch(owner[0],requests,3,out)==-1 and out.raw==b'Z'*32
    assert snapshot(owner,shaft)==before;failure.write_bytes(wire)
    assert close(owner[0])==0
    # Timed cold-directory batch is evidence for upcoming loading-budget work;
    # no hardware-specific timing threshold is asserted.
    cold=root/'cold';cold.mkdir();owner=setup(cold)
    requests=(I*128)(*[v for i in range(64) for v in (i*64+8,-i*64+8)])
    out=C.create_string_buffer(64*8+8);out.raw=b'Z'*(64*8+8)
    before=snapshot(owner,cold);t=time.monotonic()
    assert batch(owner[0],requests,64,out)==0
    batch_seconds=time.monotonic()-t
    assert snapshot(owner,cold)==before and out.raw[64*8:]==b'Z'*8
    assert close(owner[0])==0
print(f'PASS: {queries} exact region surfaces; untouched ownership/files, dirty and restarted edits, removed roofs/caves, old blends, signed heights, corrupt/identity/boundary rejection ({time.monotonic()-start:.3f}s)')

print(f'INFO: 64 cold-directory actual-generator samples: {batch_seconds:.6f}s; synchronous, no loading-budget claim')
