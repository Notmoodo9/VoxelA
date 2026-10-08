%define INV_SLOTS 36
%define INV_SIZE 304
%define INV_CURSOR 1
%define item_limit inventory36_item_limit
%define inventory_init inventory36_init
%define inventory_valid inventory36_valid
%define inventory_add inventory36_add
%define inventory_craft inventory36_craft
%define inventory_consume inventory36_consume
%define inventory_wear inventory36_wear
%define mine_duration inventory36_mine_duration
%define inventory_can_craft inventory36_can_craft
%define inventory_count inventory36_count
%define inventory_transfer inventory36_transfer
%define inventory_click inventory36_click
%define inventory_quick inventory36_quick
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
