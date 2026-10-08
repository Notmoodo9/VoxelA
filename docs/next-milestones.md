# Implementation order

The canonical, checked implementation plan now lives in the
[README ordered checklist](../README.md#ordered-implementation-checklist).
This replaces the duplicated milestone list, whose checked design decisions
could be mistaken for implemented gameplay.

Confirmed requirements remain in [game design decisions](game-design-decisions.md).
Subsystem documents describe exact APIs, ownership, save formats and tests;
they do not replace the README's completion status.

Work toward playable milestones in this order: container/crafting integration;
player controls/Creative/save reliability; physical item drops; Survival;
region-backed streaming; tall terrain/biomes/caves/liquids; building/creatures;
presentation/performance/release. Independent improvements may be bundled within
sessions, but dependent gameplay features must satisfy their integration gates.
