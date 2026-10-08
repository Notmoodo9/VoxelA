%ifndef VOXELA_INVENTORY
%define VOXELA_INVENTORY
; Inventory80: nine Slot8 records, selected slot u32 at72, mode u32 at76.
; Slot8: item u16, count u16, durability u16, reserved u16. Empty = all zero.
; Mode0 Survival,1 Creative. Slots remain unchanged when switching mode.
%define INVENTORY_SIZE 80
%define INVENTORY_SLOTS 9
%define ITEM_PLANKS 8
%define ITEM_STICKS 9
%define ITEM_WOOD_PICK 10
%define ITEM_STONE_PICK 11
%endif
