%define INV_REGISTRY 2
%define INV_SLOTS 36
%define INV_SIZE 304
%define INV_CURSOR 1
%define item_limit inventory2_item_limit
%define inventory_init inventory2_init
%define inventory_valid inventory2_valid
%define inventory_add inventory2_add
%define inventory_craft inventory2_craft
%define inventory_consume inventory2_consume
%define inventory_wear inventory2_wear
%define mine_duration inventory2_mine_duration
%define inventory_can_craft inventory2_can_craft
%define inventory_count inventory2_count
%define inventory_transfer inventory2_transfer
%define inventory_click inventory2_click
%define inventory_quick inventory2_quick
%include "abi.inc"
%include "inventory.inc"
%define INV_SLOT_BYTES (INV_SLOTS*8)
%define INV_SELECTED INV_SLOT_BYTES
%define INV_MODE (INV_SLOT_BYTES+4)
%define INV_MAX_ADD (INV_SLOTS*64)
%define INV_ADD_FRAME ((((INV_SLOT_BYTES+71)/16)*16)+8)
%define INV_CRAFT_FRAME ((((INV_SLOT_BYTES+87)/16)*16)+8)
%define INV_PREVIEW_FRAME ((((INV_SIZE+55)/16)*16)+8)
%include "inventory_impl.inc"
%include "inventory_mouse_impl.inc"
