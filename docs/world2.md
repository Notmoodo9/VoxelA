# Registry2 world pipeline

The `world2_` namespace is an opt-in CPU pipeline. The playable game still uses
registry1 world/container saves until combined registry2 inventory/container
migration and menus are ready. Registry2 adds planks8, chest9 and table10 to the
existing blocks0–7. Chests/tables are currently full solid opaque cubes in these
APIs; there is no shaped chest renderer or owner allocation implied by an edit.

`include/world2_aliases.inc` namespaces the shared block/cache/stream/mesh/vertex/
player/raycast/walk-save sources. Thin `*2.asm` wrappers compile those sources
with `WORLD_REGISTRY=2`. This retains one implementation and separate legacy
exports. Make dependencies cover all include files and the included sources.
Frozen generator0 is shared unchanged; new blocks enter through explicit edits.

- `world2_section_set` and `world2_cache_edit` accept block0–10. Section/cache
  primitives can store bedrock; gameplay `world2_stream_edit` rejects bedrock7,
  immutable Y0 and coordinates outside the existing Y0–255/XZ±30million bounds.
- `world2_stream_get/recenter/edit` use the existing Stream96 layout,400-section
  cache and8,192-edit journal. Cache eviction/reload reapplies new block edits;
  returning a cell to generator0's baseline removes its journal override.
- `world2_mesh_build` validates the main and all present neighboring sections
  before writing, culls opaque/identical neighbors and emits the existing Face8
  records. `world2_faces_expand` validates IDs and capacity, then emits colored
  counterclockwise Vertex24 triangles with the existing face shading. This is
  CPU geometry; textured OpenGL integration and original container art remain
  separate tasks.
- `world2_world_raycast` uses the existing normalized DDA/reach/output contract
  and accepts hits on new blocks. Its explicit ID validation now uses the
  selected registry count instead of a fixed8.
- `world2_player_*` uses registry2 point queries for collision/movement. Current
  blocks are all solid except air. Vertical expansion and Spectator are future
  changes, not consequences of selecting registry2.

## Walk-save compatibility

`world2_walk_encode/decode/checksum` retain Header128 + Edit32[] and VXAWALK magic,
format1, generator0 and checksum rules. The registry field at16 is2 for new
encoding. Length remains128+32*editCount, maximum262,272 bytes. Native pointers
are never serialized. This codec saves world edits and player pose only; it
contains no inventory, table grid, chest contents or item entities.

The new decoder accepts registry1 and2 headers. A registry1 header must contain
only legacy-edit IDs0–6; changing the header cannot make extended IDs acceptable.
Registry2 edits accept0–6 and8–10; bedrock overrides remain forbidden. All other
version, seed, checksum, canonical-edit, duplicate, coordinate and collision-safe
pose checks remain enforced before live journal/player/cache mutation. New
encoding always writes registry2 after a supported legacy import. The frozen
legacy encoder/decoder reject new IDs/registry2 saves.

`tests/world2.py` independently models neighbor-aware faces and exact colored
vertices, output capacities/canaries, cache lookup, ray hits, player collision,
stream edits and eviction, exact serialized bytes, every-byte corruption of a
representative save, checksum-repaired invalid fields, legacy-header smuggling,
atomic rejection and registry1 import. It runs in both ABI suites and Windows CI.
