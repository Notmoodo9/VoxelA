"""Independent integer reference tests. No generated expectations are saved."""
import ctypes as C
import random
import sys

lib = C.CDLL(sys.argv[1])
U, S, P = C.c_uint64, C.c_int64, C.c_void_p

def bind(name, args, result=U):
    f = getattr(lib, name)
    f.argtypes, f.restype = args, result
    return f

mix = bind('mix64', [U])
fnv = bind('fnv1a', [P, U])
parse = bind('seed_numeric', [C.c_char_p, C.POINTER(U)], S)
section = bind('floor_section', [S], S)
local = bind('local_axis', [S])
index = bind('block_index', [U, U, U], S)
bounds = bind('world_in_bounds', [S, S, S])
get = bind('section_get', [P, U], S)
put = bind('section_set', [P, U, U], S)
flags = bind('block_flags', [U], S)
fade = bind('fade_q16', [U])
lattice = bind('lattice', [U, S, S])
noise = bind('noise2', [U, S, S, U], S)
biome = bind('biome_at', [U, S, S])
height = bind('terrain_height', [U, S, S])
generate = bind('generate_section', [P, U, C.POINTER(S)], S)
MASK = (1 << 64) - 1
checks = 0

def equal(actual, expected, context):
    global checks
    checks += 1
    if actual != expected:
        raise AssertionError(f'{context}: {actual!r} != {expected!r}')

def mix_ref(n):
    n = (n + 0x9e3779b97f4a7c15) & MASK
    n = ((n ^ (n >> 30)) * 0xbf58476d1ce4e5b9) & MASK
    n = ((n ^ (n >> 27)) * 0x94d049bb133111eb) & MASK
    return n ^ (n >> 31)

def lattice_ref(seed, x, z):
    return mix_ref(seed ^ ((x * 0xd6e8feb86659fd93) & MASK)
                    ^ ((z * 0xa5a3564e27f8862f) & MASK)) >> 48

def fade_ref(t):
    cube = (((t * t) >> 16) * t) >> 16
    polynomial = (((6*t - 15*65536)*t) >> 16) + 10*65536
    return (cube * polynomial) >> 16

def noise_ref(seed, x, z, shift):
    step = 1 << shift
    lx, lz = x // step, z // step
    fx = fade_ref((x % step) * 65536 // step)
    fz = fade_ref((z % step) * 65536 // step)
    a, b = lattice_ref(seed, lx, lz), lattice_ref(seed, lx+1, lz)
    c, d = lattice_ref(seed, lx, lz+1), lattice_ref(seed, lx+1, lz+1)
    low, high = a + ((b-a)*fx >> 16), c + ((d-c)*fx >> 16)
    return low + ((high-low)*fz >> 16)

def biome_ref(seed, x, z):
    if noise_ref(seed ^ 0x454c45564154494f, x, z, 10) >= 49152:
        return 3
    moisture = noise_ref(seed ^ 0x4d4f495354555245, x, z, 11)
    if moisture >= 36045:
        return 1
    if moisture < 22937 and noise_ref(seed ^ 0x54454d5045524154, x, z, 11) >= 42598:
        return 2
    return 0

class Arena(C.Structure):
    _fields_ = [('base', P), ('capacity', U), ('used', U), ('high', U)]
init_arena = bind('arena_init', [C.POINTER(Arena), P, U])
alloc_arena = bind('arena_alloc', [C.POINTER(Arena), U, U], P)
reset_arena = bind('arena_reset', [C.POINTER(Arena)])
backing = (C.c_ubyte * 10000)()
base = C.addressof(backing) + 1  # deliberately unaligned
arena = Arena()
equal(init_arena(C.byref(arena), base, 9999), 0, 'arena init')
for size, alignment in [(1,1), (3,16), (50,64), (100,4096)]:
    start = (base + arena.used + alignment - 1) & -alignment
    equal(alloc_arena(C.byref(arena), size, alignment), start, 'aligned arena allocation')
    equal(arena.used, start-base+size, 'arena used')
    equal(arena.high, arena.used, 'arena high-water')
for size, alignment in [(0,1), (1,0), (1,3), (1,8192), (MASK,1), (10000,1)]:
    old = bytes(arena)
    equal(alloc_arena(C.byref(arena), size, alignment), None, 'arena invalid allocation')
    equal(bytes(arena),old,'arena failure atomicity')
old_high = arena.high
equal(reset_arena(C.byref(arena)),0,'arena reset')
equal(arena.used,0,'arena reset used')
equal(arena.high,old_high,'arena retained high-water')
arena.base, arena.capacity, arena.used = MASK-8, 9999, 16
old = bytes(arena)
equal(alloc_arena(C.byref(arena),1,16),None,'pointer overflow')
equal(bytes(arena),old,'overflow preserves arena')

rng = random.Random(2026)
for n in [0, 1, MASK, 1 << 63] + [rng.getrandbits(64) for _ in range(1000)]:
    equal(mix(n), mix_ref(n), ('mix', n))
for text, expected in [(b'', 0xcbf29ce484222325), (b'a', 0xaf63dc4c8601ec8c),
                       (b'hello', 0xa430d84680aabd0b)]:
    equal(fnv(text, len(text)), expected, ('fnv', text))
for n in [0, 1, MASK, 1 << 63] + [rng.getrandbits(64) for _ in range(1000)]:
    for text in [str(n).encode(), hex(n).encode(), ('0X%X' % n).encode()]:
        out = U(123)
        equal(parse(text, C.byref(out)), 0, ('parse', text))
        equal(out.value, n, ('parsed value', text))
for text in [b'', b'0x', b'-1', b'+1', b' 1', b'1 ', b'0xg', b'12z',
             b'18446744073709551616', b'0x10000000000000000', b'9999999999999999999999']:
    out = U(123)
    equal(parse(text, C.byref(out)), -1, ('invalid seed', text))
    equal(out.value, 123, ('preserve output', text))
for n in [-(1 << 63), (1 << 63)-1, -17, -16, -1, 0, 15, 16] + [rng.randint(-30000000, 30000000) for _ in range(1000)]:
    equal(section(n), n // 16, ('section', n))
    equal(local(n), n % 16, ('local', n))
for y in range(16):
    for z in range(16):
        for x in range(16):
            equal(index(x, y, z), x + 16*(z+16*y), ('index', x,y,z))
for args in [(16,0,0), (0,16,0), (0,0,16), (MASK,0,0)]:
    equal(index(*args), -1, ('invalid index', args))
for x in [-30000001,-30000000,-1,0,29999999,30000000]:
    for y in [-1,0,255,256]:
        for z in [-30000001,-30000000,0,29999999,30000000]:
            equal(bounds(x,y,z), int(-30000000 <= x < 30000000 and
                  0 <= y < 256 and -30000000 <= z < 30000000), ('bounds', x,y,z))
raw = (C.c_ubyte * (8192+32))(*([0xA5]*(8192+32)))
buf = C.cast(C.byref(raw,16),P)
for i in range(4096):
    equal(put(buf,i,i % 8), 0, ('put',i))
    equal(get(buf,i), i % 8, ('get',i))
old = bytes(raw)
for i, v in [(4096,1), (MASK,1), (0,8), (0,MASK)]:
    equal(put(buf,i,v), -1, ('invalid put',i,v))
    equal(bytes(raw),old,'invalid writes preserve all bytes')
equal(get(buf,4096),-1,'invalid get')
equal(bytes(raw[:16])+bytes(raw[-16:]), bytes([0xA5]*32),'buffer canaries')
for i, expected in enumerate([0,7,7,7,7,7,13,3]):
    equal(flags(i), expected, ('block flags',i))
equal(flags(8),-1,'invalid block')
for t in range(65537):
    actual = fade(t)
    equal(actual,fade_ref(t),('fade',t))
    # Quantized polynomial can have tiny local rounding reversals; exact
    # integer reference, endpoint and range are the compatibility contract.
    if not 0 <= actual <= 65536:
        raise AssertionError(('fade range',t,actual))
for _ in range(3000):
    seed, x, z, shift = rng.getrandbits(64), rng.randint(-30000000,29999999), rng.randint(-30000000,29999999), rng.randrange(17)
    equal(lattice(seed,x,z),lattice_ref(seed,x,z),('lattice',seed,x,z))
    equal(noise(seed,x,z,shift),noise_ref(seed,x,z,shift),('noise',seed,x,z,shift))
    equal(biome(seed,x,z),biome_ref(seed,x,z),('biome',seed,x,z))
equal(noise(0,0,0,17),-1,'invalid wavelength')
# Known generator v0 fixture, canonical little-endian FNV over 8192 bytes.
fixtures = [(0,(-1,4,0)), (42,(0,0,0)), (MASK,(1874999,15,-1875000))]
hashes = []
for seed, xyz in fixtures:
    coords = (S*3)(*xyz)
    equal(generate(buf,seed,coords),0,('generation status',xyz))
    hashes.append(fnv(buf,8192))
    for y in range(16):
        for z in range(16):
            for x in range(16):
                wx,wy,wz = xyz[0]*16+x, xyz[1]*16+y, xyz[2]*16+z
                h = 64 + (noise_ref(seed,wx,wz,7) >> 12)
                b = biome_ref(seed,wx,wz)
                expected = 7 if wy == 0 else 0 if wy > h else 1 if wy < h-3 else 4 if b==2 else 3 if wy==h else 2
                equal(get(buf,x+16*(z+16*y)),expected,('generated cell',seed,wx,wy,wz))
    snapshot = bytes(raw)
    equal(generate(buf,seed,coords),0,'regeneration')
    equal(bytes(raw),snapshot,'repeated generation')
    equal(bytes(raw[:16])+bytes(raw[-16:]),bytes([0xA5]*32),'generation canaries')
for xyz in [(1875000,0,0),(-1875001,0,0),(0,-1,0),(0,16,0),(0,0,1875000)]:
    old = bytes(raw)
    equal(generate(buf,1,(S*3)(*xyz)),-1,('invalid section',xyz))
    equal(bytes(raw),old,'invalid generation preserves buffer')
equal(hashes, [0x631e9b07007c5325, 0xd04cac448b373b25, 0xb9d103fd6854a325], 'frozen v0 section hashes')
print(f'PASS: {checks} independent reference assertions; section hashes: ' + ', '.join(f'{h:016x}' for h in hashes))
