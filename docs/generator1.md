# Candidate generator1

This is a CPU-only development generator, not a migrated playable world format.
Frozen generator0, existing section hashes, save validators, collision and actual
world-derived distant meshes are unchanged. The playable cache still spans
Y0–255. The new generator must enter the versioned storage/streaming pipeline
before it can drive nearby or distant rendering.

## Sampling contracts

- `lattice3(seed,x,y,z)` hashes signed global integer coordinates modulo 2^64
  using the frozen SplitMix64 mixing function and distinct axis salts.
- `noise3(seed,coords24*,wavelengthLog2)` returns unsigned Q16 noise, or −1
  for wavelengths outside 0–16. Quintic fade and trilinear interpolation floor
  every signed fixed-point multiply; negative coordinates use floor division.
- `terrain1_column(seed,x,z,out32)` returns the existing experimental landscape
  fields: top-cell height, biome, moisture and temperature, followed by seed and
  a reserved zero qword. Mountain/volcanic columns add broad ridged relief.
  Invalid horizontal coordinates preserve output. The prototype's observed
  relief fits the vertical range; final biome/elevation distributions remain open.
- `terrain1_cave(seed,coords24*,surfaceY)` evaluates two intersecting tunnel
  fields plus occasional deep chambers. Eight surface blocks and the bottom
  floor are protected. Global inputs avoid chunk-local random seams. This does
  not yet guarantee a connected cave network or supply surface entrances.
- `generated_block1(seed,coords24*,column32*)` evaluates one block using the
  prepared column. The caller must supply that exact seed/X/Z column and valid
  nonoverlapping allocations. Supported Y is −256 through 767. Existing material
  IDs are used: bedrock at −256, stone underground, dirt/grass surface layers,
  sand for desert/ocean/river profiles and exposed volcanic stone. Biome ecology,
  snow, liquid filling, vegetation, ores and distinct fantasy materials remain
  pending. A biome label alone does not complete a biome delivery milestone.
- `generate_section1(buffer8192,seed,sectionCoords24*)` fills 16³ u16 block IDs
  in X-fastest, then Z, then Y order. Vertical sections are −16 through 47.
  Horizontal sections retain ±30-million-block limits. Invalid coordinates leave
  the complete destination untouched.

The candidate generator does not read edits or mutate shared state. Storage must
combine generated blocks with recorded data/edits and saved generator versions.
Old-world border blending is still required under the existing upgrade plan;
there is no silent rewrite of old chunks. Final connectivity, distributions and
performance must be assessed before declaring generator1 a stable saved version.

## Validation

Independent Python interpolation and cave/block models check both calling
conventions. Tests cover all 11 climate profiles, exact section order, negative
and large coordinates, the lowest/highest vertical sections, cave roof/floor
protection, unsupported inputs and output canaries. Existing generator0 golden
fixtures remain separate. These checks verify algorithms, not playable adoption
or native Windows graphics.
