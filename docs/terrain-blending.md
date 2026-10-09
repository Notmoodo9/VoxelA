# Recorded-terrain border blending

Implemented in the world store and adopted by the experimental region window
mode. Default launch retains its legacy stream. Recorded generator0 sections and edits are never modified by
blending. A shared region file may be rewritten to persist new sibling sections,
while all old section metadata and block bytes remain unchanged.
Only a missing generator1 section can receive a transition. A recorded section,
including a recorded generator1 section, is returned without inspecting neighbors
or regenerating its data.

## Recorded inputs

Each new section checks its west/east/north/south section-column neighbors. A
neighbor qualifies only when all sixteen Y0–255 sections are recorded and marked
generator0. The resolver reads the current staged region first, then live cache
entries (including unsaved edits), then saved files. It does not generate old
sections or change cache timestamps, ownership, revisions or files. Missing,
unrecorded or generator1 sections make that neighbor ineligible. Corrupt or
incompatible existing files fail the request instead of inventing a surface.
World-border neighbors outside the coordinate range are skipped.

The actual recorded blocks supply sixteen heights along the facing edge. Each
height is the highest nonair block in that column, including edited blocks and
player builds. Removed blocks therefore affect the profile. The old bedrock
floor guarantees a valid height in0–255. Complete columns are required because
a partially recorded column cannot establish its actual highest block.

This is a surface-height transition. It does not copy old block materials,
reconstruct unrecorded exploration, interpolate cave connectivity, or move the
old bedrock floor fromY0. Generator1 retains its climate/material rules, cave
field and floor atY−256. Complete old columns now supply an actual256-cell
surface grid for their vertical extension: new upper sections stay air and lower
sections use generator1 underground rules under the preserved Y0 floor. No old
section is modified. See region-gameplay.md for access/connectivity limits.

## Deterministic transition

The transition occupies the adjacent16-block-wide new section column. For each
cell, native generator1 supplies the climate, material profile and surfaceH.
An active old face supplies its matching recorded edge heighth_i; d_i is the
cell's distance0–15 from that face. Interior weights are:

- native: product of d_i squared for all active faces;
- facei: (16−d_i) squared times the product of d_j squared for other active faces.

The new height is the floor of the weighted sum divided by the sum of weights.
All arithmetic uses bounded signed64-bit integers. With one face the native
weight grows from0 at the edge to225 at the opposite end, while the old weight
falls from256 to1. At a touching edge (distance0), only touching old faces apply;
a corner touching two old faces uses the floor of their mean. This defines a
stable corner even when recorded edits make the two old profiles disagree.
Without active faces, the result matches generator1 exactly.

The same profile applies to every vertical section of the new column. Generation
is staged into a private section buffer; validation/allocation failure preserves
the target region. Publication sets version1, occupancy and revision once. Files
retain the resulting blocks, so restart and cache eviction never re-evaluate an
already recorded transition. Changing old terrain later can affect future
unrecorded sections; it cannot reshape previously recorded new terrain.

## Assembly APIs

`legacy_edge_profile(sectionPointers16*, face, outI32[16]*)` reads canonical
ordered generator0 sectionsSY0–15. Face0/1/2/3 means west/east/north/south. It
validates every input block, floor and pointer before publishing the output.
Caller allocations must be valid and distinct from output.

`terrain1_blend_column(seed, globalCoords24*, profile264*, out32*)` retains the
terrain1_column layout. Y in the coordinate tuple is ignored. The profile starts
with a qword mask (bits0–3 forW/E/N/S), followed by four16-elementI32 arrays.
Active heights must be0–255; inactive arrays are ignored. Invalid coordinates,
masks or active heights preserve output.

`generate_section_blend(out8192*, seed, sectionCoords24*, profile264*)` supports
SY−16–47. `region_generate_blend(region*, slot, profile*)` stages publication and
returns1 newly generated,0 already occupied or a negative error. Occupied regions
are never rewritten, even if the supplied profile is invalid. Pure APIs require
nonoverlapping input/output buffers and canonical caller-owned regions.

`world_store_blend_profile` and `world_store_generate` are internal synchronous
helpers, requiring a valid initialized store and canonical current region; they
are not an asynchronous loading interface. Their bounded scratch allocation is
263632 bytes per resolver call. The upgrade resolver can read up to80 neighboring/own regions
per missing section, so scheduling and profile caching remain optimization work
for smoother gameplay. Distant meshes must use saved blended terrain,
not independently resample unblended generator1 heights.

Tests compare4608 columns against independent integer weights under both ABIs,
check actual edited section edges, all face masks/corners, section/block output,
Y bounds, staging failures and canaries. Real-file tests preserve old section bytes (including mixed-region siblings),
include dirty cache inputs, compare forward/reverse generation order, reload
saved transitions and reject corrupt neighboring files without losing residents.
Native Windows file tests are configured in CI; local cross-builds are distinct.

`legacy_column_profile` extracts256 actual highest cells from a complete old
column. UpgradeProfile1296 extends the264-byte edge profile with an own-column
flag at264 and256I32 heights at272. `terrain1_upgrade_column`,
`generate_section_upgrade` and `region_generate_upgrade` apply that ceiling
when active; new upper sections cannot form floating mountains over preserved
old air. The world-store dispatcher uses this extended profile only for newly
recorded sections. The edge-only resolver/API remains compatible with264 bytes.
