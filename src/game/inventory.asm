%define INV_SLOTS 9
%define INV_SIZE 80
%define INV_CURSOR 0
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
