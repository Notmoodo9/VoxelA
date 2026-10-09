# Actual terrain and progressive distant meshes

Distant terrain now comes from the same frozen generator 0 and saved edit journal
as playable chunks. The independent experimental biome landscape no longer drives
the renderer. There is no alternate terrain blend or downward height offset.
The 11-biome sampler remains CPU-only until a versioned block generator adopts it.

F7/F8 adjust the far radius within 2–256 chunks, default 64. The HUD shows FAR
and the current chunk radius. Fog/projection follow that setting. These settings
remain session-local; world/save generation contracts are unchanged.

## Surface source

`terrain_surface(Stream 96*,globalX,globalZ,out 8)` returns the top boundary Y and
material of the actual highest non-air block. It starts from generator 0, applies
all matching column edits and searches downward after removals. Saved raised
columns, exposed dirt/stone and changes outside current cache residency are
included when their columns are sampled. Bedrock remains the bottom boundary.
Global integer coordinates are used even millions of blocks from origin.

Invalid coordinates or unsupported matching records leave output unchanged.
The canonical journal has at most 8,192 records and must remain unchanged during
sampling/builds. This is a surface representation: caves/overhang interiors and
thin features between coarse samples are not retained. Full volumetric far LOD
and finer treatment of edited regions remain planned.

## Progressive mesh and joins

`terrain_lod_build(Config 64*)` constructs square rings around the detailed cache.
The full-detail footprint stays 80 blocks wide, centered eight blocks beyond the
stream's chunk origin. No distant top triangles cover this footprint.

| Ring from cache center | Sample spacing |
| --- | --- |
| 40–64 blocks | 4 blocks |
| 64–128 | 8 |
| 128–256 | 16 |
| 256–512 | 32 |
| 512–1,024 | 64 |
| 1,024–2,048 | 128 |
| 2,048–4,096 | 256 |

The outer ring reaches the next power-of-two bound; fragment clipping applies
the requested radius. A radius of 32 blocks needs no distant mesh because the
existing cache already covers it. Invalid cells at the finite world border are
omitted. The full-detail cache is still five chunk columns across; the requested
16-chunk full-detail streaming radius is not implemented by this change.

At a ring join, boundary triangles split into fans containing every neighboring
fine edge vertex. Both levels share the same sampled positions and heights,
avoiding T-junction cracks. At the detailed cache, one-block connecting strips
join the sampled edge to each actual boundary block's constant-height top.
The old hard fragment cutout was removed so it cannot erase these faces.
Colors use representative values for the sampled block material; they do not
invent biome colors or heights.

Config 64 contains world pointer, Vertex 32 output pointer/capacity, aligned global
center X/Z, radius in blocks, output vertex count, and optional caller-owned
360,480-byte scratch pointer. Capacity must be at least 65,536 vertices;
rejected configuration, capacity or journal records preserve output/count.
Canonical journal ownership and valid nonoverlapping allocations are caller
preconditions. The world must remain unchanged throughout a build.

The largest ring set emits 35,184 vertices, about 1.07 MiB of GPU geometry. The
renderer reserves 2 MiB vertex storage plus about 0.344 MiB sample/index scratch.
Memoization
reuses shared surface samples, resets on every build and falls back safely if
full. The first 262,144 scratch bytes contain the sample memo; the remaining
98,336 bytes hold an edit-column index. That index is built once per rebuild,
with 16,384 bucket heads and 8,192 next-record links. Surface queries scan only
the matching hash bucket, then check exact X/Z coordinates. Hash collisions
cannot change results. No mutable global mesher cache is shared between callers.

`terrain_surface_index_build(Stream96*,Index98336*)` validates every journal
record before touching the index. `terrain_surface_indexed(Index98336*,X,Z,out8)`
uses the same surface algorithm as the scan implementation. The caller must
rebuild the index after any seed, journal pointer/count or record change; it is
valid only while that world remains unchanged. The renderer rebuilds it every
time the far mesh becomes dirty. Null mesh scratch retains the original exact
scan path for compatibility and reference comparisons.

Rebuilds remain synchronous and recenter with the resident cache. Worker jobs,
frustum-selected patches, globally anchored clipmaps/geomorphing and local edits
that rebuild only affected patches remain future performance work. Pathological
hash collisions still increase surface-query cost. The existing shadow volume covers
the detailed area; distant terrain outside it receives directional/ambient light.

## Validation

Independent surface tests compare with generated blocks plus shuffled edits,
including removed layers and raised blocks. Both ABI variants also audit mesh
samples, every transition profile, increasing spacing, boundary/capacity canaries,
rejected input conservation and cached/uncached byte-identical output, including
a maximum-size 8,192-edit journal. Index checks exercise rebuilds, unrelated
columns, hash collisions and large coordinates; query timings are diagnostic,
without hardware-dependent pass thresholds. Graphics
checks retain radius controls, terrain edits, saves, large-coordinate restart and
real SDL input. Native Windows graphics is separate from local cross-builds.

![Actual terrain from an elevated view](landscape-preview.png)

## Region-mode horizon

Opt-in region gameplay now uses the same progressive mesh topology with signed
full-height samples from actual saved blocks, dirty residents and the exact
blended generator for missing sections. Its separate bounded file/negative read
cache never acquires or evicts gameplay regions. Whole-mesh staging preserves
the previous visible horizon on corrupt/unreadable data; a separate far eye
keeps retained vertices correctly positioned after recenter. See
[region surface and cache contracts](region-surface.md). F7/F8 select2–256 chunk
columns; near residency remains radius2 and all rebuilds remain synchronous.
