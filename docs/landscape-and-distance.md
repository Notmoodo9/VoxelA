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
8,192×32-byte sample-cache pointer. Capacity must be at least 65,536 vertices;
rejected configuration, capacity or journal records preserve output/count.
Canonical journal ownership and valid nonoverlapping allocations are caller
preconditions. The world must remain unchanged throughout a build.

The largest ring set emits 35,184 vertices, about 1.07 MiB of GPU geometry. The
renderer reserves 2 MiB vertex storage plus 0.25 MiB sample scratch. Memoization
reuses shared surface samples, resets on every build and falls back safely if
full. No mutable global mesher cache is shared between callers.

Rebuilds remain synchronous and recenter with the resident cache. Worker jobs,
frustum-selected patches, globally anchored clipmaps/geomorphing and local edits
that rebuild only affected patches remain future performance work. Dense edit
journals increase surface-query cost. The existing shadow volume still covers
the detailed area; distant terrain outside it receives directional/ambient light.

## Validation

Independent surface tests compare with generated blocks plus shuffled edits,
including removed layers and raised blocks. Both ABI variants also audit mesh
samples, every transition profile, increasing spacing, boundary/capacity canaries,
rejected input conservation and cached/uncached byte-identical output. Graphics
checks retain radius controls, terrain edits, saves, large-coordinate restart and
real SDL input. Native Windows graphics is separate from local cross-builds.

![Actual terrain from an elevated view](landscape-preview.png)
