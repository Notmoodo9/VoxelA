TARGET ?= linux
CONFIG ?= debug
NASM ?= nasm
TOOLCHAIN_PREFIX ?=
LINKER = $(TOOLCHAIN_PREFIX)gcc
ifeq ($(filter $(CONFIG),debug release),)
$(error CONFIG must be debug or release)
endif
ifeq ($(TARGET),linux)
FORMAT = elf64
EXT =
MATH_LIBS = -lm
LDFLAGS = -no-pie -Wl,-z,noexecstack
else ifeq ($(TARGET),windows)
FORMAT = win64
EXT = .exe
LDFLAGS =
else
$(error TARGET must be linux or windows)
endif
BUILD = build/$(TARGET)/$(CONFIG)
FLAGS = -Iinclude/ -Wall -w-reloc-rel-dword -w-reloc-abs-dword -Werror
ifeq ($(CONFIG),debug)
ifeq ($(TARGET),linux)
FLAGS += -g -F dwarf
endif
else
FLAGS += -Ox
endif
CORE = src/core/hash.asm src/core/arena.asm src/core/seed.asm src/world/blocks.asm src/world/noise.asm src/world/generate.asm src/world/cache.asm src/render/mesh.asm src/render/vertices.asm src/game/camera.asm src/world/raycast.asm src/game/picking.asm src/world/snapshot.asm src/world/stream.asm src/game/player.asm src/world/walk_save.asm src/game/inventory.asm src/world/game_save.asm src/game/frame_stats.asm src/game/inventory36.asm src/world/game36_save.asm src/game/crafting.asm src/game/ui_layout.asm src/world/game_grid_save.asm src/game/container.asm src/world/container_save.asm src/game/recipes.asm src/world/container_store.asm src/game/registry.asm src/game/recipe_catalog.asm src/game/inventory2.asm src/game/grid_craft.asm src/world/blocks2.asm src/world/cache2.asm src/world/stream2.asm src/render/mesh2.asm src/render/vertices2.asm src/game/player2.asm src/world/walk_save2.asm src/world/raycast2.asm src/game/settings.asm src/game/flight.asm src/game/autosave.asm src/core/format.asm src/game/recipe_book.asm src/world/landscape.asm
OBJECTS = $(patsubst %.asm,$(BUILD)/%.o,$(CORE))
.PHONY: all test objects clean reference
all: $(BUILD)/voxela$(EXT)
objects: $(OBJECTS) $(BUILD)/src/platform/main.o $(BUILD)/tests/runner.o
$(BUILD)/%.o: %.asm $(wildcard include/*.inc)
	@mkdir -p $(@D)
	$(NASM) $(FLAGS) -f $(FORMAT) $< -o $@
$(BUILD)/voxela$(EXT): $(OBJECTS) $(BUILD)/src/platform/main.o
	$(LINKER) $(LDFLAGS) $^ $(MATH_LIBS) -o $@
$(BUILD)/engine_tests$(EXT): $(OBJECTS) $(BUILD)/tests/runner.o
	$(LINKER) $(LDFLAGS) $^ $(MATH_LIBS) -o $@
test: $(BUILD)/engine_tests$(EXT)
	./$(BUILD)/engine_tests$(EXT)
ifeq ($(TARGET),linux)
$(BUILD)/libvoxela.so: $(OBJECTS)
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ $(MATH_LIBS) -o $@
reference: $(BUILD)/libvoxela.so
	python3 tests/reference.py $(BUILD)/libvoxela.so
	python3 tests/chunks.py $(BUILD)/libvoxela.so
	python3 tests/vertices.py $(BUILD)/libvoxela.so
	python3 tests/camera.py $(BUILD)/libvoxela.so
	python3 tests/raycast.py $(BUILD)/libvoxela.so
	python3 tests/snapshot.py $(BUILD)/libvoxela.so
	python3 tests/player.py $(BUILD)/libvoxela.so
	python3 tests/walk_save.py $(BUILD)/libvoxela.so
	python3 tests/inventory36.py $(BUILD)/libvoxela.so
	python3 tests/game36_save.py $(BUILD)/libvoxela.so
	python3 tests/container_store.py $(BUILD)/libvoxela.so
	python3 tests/containers.py $(BUILD)/libvoxela.so
	python3 tests/registry.py $(BUILD)/libvoxela.so
	python3 tests/inventory2.py $(BUILD)/libvoxela.so
	python3 tests/world2.py $(BUILD)/libvoxela.so
	python3 tests/player_options.py $(BUILD)/libvoxela.so
	python3 tests/recipe_book.py $(BUILD)/libvoxela.so
	python3 tests/landscape.py $(BUILD)/libvoxela.so
	python3 tests/recipes.py $(BUILD)/libvoxela.so
	python3 tests/crafting.py $(BUILD)/libvoxela.so
	python3 tests/ui_layout.py $(BUILD)/libvoxela.so
	python3 tests/game_grid_save.py $(BUILD)/libvoxela.so
	python3 tests/frame_stats.py $(BUILD)/libvoxela.so
	python3 tests/inventory.py $(BUILD)/libvoxela.so
	python3 tests/game_save.py $(BUILD)/libvoxela.so
endif
clean:
	rm -rf build

# Exercise Windows calling convention on Linux without claiming native Windows
# runtime validation. Prefix symbols so the shim can expose the same API.
ifeq ($(TARGET),linux)
WIN_ABI_OBJECTS = $(patsubst %.asm,$(BUILD)/win-abi/%.o,$(CORE))
$(BUILD)/win-abi/%.o: %.asm $(wildcard include/*.inc)
	@mkdir -p $(@D)
	$(NASM) $(FLAGS) -DWINDOWS_ABI=1 -f elf64 $< -o $@.raw
	objcopy --prefix-symbols=win_ $@.raw $@
$(BUILD)/libwindows_abi.so: $(WIN_ABI_OBJECTS) $(BUILD)/tests/windows_abi_shim.o
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ $(MATH_LIBS) -o $@
.PHONY: abi-reference
abi-reference: $(BUILD)/libwindows_abi.so
	python3 tests/reference.py $<
	python3 tests/chunks.py $<
	python3 tests/vertices.py $<
	python3 tests/camera.py $<
	python3 tests/raycast.py $<
	python3 tests/snapshot.py $<
	python3 tests/player.py $<
	python3 tests/walk_save.py $<
	python3 tests/inventory36.py $<
	python3 tests/game36_save.py $<
	python3 tests/container_store.py $<
	python3 tests/containers.py $<
	python3 tests/registry.py $<
	python3 tests/inventory2.py $<
	python3 tests/world2.py $<
	python3 tests/player_options.py $<
	python3 tests/recipe_book.py $<
	python3 tests/landscape.py $<
	python3 tests/recipes.py $<
	python3 tests/crafting.py $<
	python3 tests/ui_layout.py $<
	python3 tests/game_grid_save.py $<
	python3 tests/frame_stats.py $<
	python3 tests/inventory.py $<
	python3 tests/game_save.py $<
endif

# Optional SDL/OpenGL bootstrap; headless targets do not require SDL.
SDL_LIBS ?= -lSDL2
.PHONY: window
IO_OBJECT = $(BUILD)/src/platform/save_file.o
window: $(BUILD)/voxela-window$(EXT)
$(BUILD)/src/render/terrain.o: assets/shaders/terrain.vert assets/shaders/terrain.frag include/gl.inc include/gl_names.inc
$(BUILD)/voxela-window$(EXT): $(OBJECTS) $(BUILD)/src/platform/play_window.o $(BUILD)/src/render/play.o $(IO_OBJECT)
	$(LINKER) $(LDFLAGS) $^ $(SDL_LIBS) $(MATH_LIBS) -o $@

ifeq ($(TARGET),linux)
$(BUILD)/libterrain.so: $(OBJECTS) $(BUILD)/src/render/terrain.o $(IO_OBJECT)
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ $(SDL_LIBS) $(MATH_LIBS) -o $@
.PHONY: graphics-reference
graphics-reference: $(BUILD)/libterrain.so
	python3 tests/graphics.py $<
endif

.PHONY: material-assets-test
material-assets-test:
	python3 tests/material_assets.py

.PHONY: packaging-test
packaging-test:
	python3 tests/packaging.py

# Portable codec and real filesystem adapter; also run natively in Windows CI.
ifeq ($(TARGET),windows)
SAVE_LIBRARY = $(BUILD)/save_tests.dll
SAVE_LINK_FLAGS = -shared
else
SAVE_LIBRARY = $(BUILD)/libsave_tests.so
SAVE_LINK_FLAGS = -shared -Wl,-Bsymbolic -Wl,-z,noexecstack
endif
$(SAVE_LIBRARY): $(OBJECTS) $(IO_OBJECT)
	$(LINKER) $(SAVE_LINK_FLAGS) $^ $(MATH_LIBS) -o $@
.PHONY: save-reference
save-reference: $(SAVE_LIBRARY)
	python3 tests/snapshot.py $<
	python3 tests/save_file.py $<

$(BUILD)/src/render/play.o: assets/shaders/play.vert assets/shaders/play.frag assets/textures/blocks.rgba assets/textures/font5x7.bin include/gl.inc include/gl_names.inc
ifeq ($(TARGET),linux)
$(BUILD)/libplay.so: $(OBJECTS) $(BUILD)/src/render/play.o $(IO_OBJECT)
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ $(SDL_LIBS) $(MATH_LIBS) -o $@
.PHONY: play-reference
play-reference: $(BUILD)/libplay.so
	python3 tests/play.py $<
endif

# Keep the bounded orthographic demo for regression and old demo saves.
.PHONY: demo
demo: $(BUILD)/voxela-demo$(EXT)
$(BUILD)/voxela-demo$(EXT): $(OBJECTS) $(BUILD)/src/platform/window.o $(BUILD)/src/render/terrain.o $(IO_OBJECT)
	$(LINKER) $(LDFLAGS) $^ $(SDL_LIBS) $(MATH_LIBS) -o $@
ifeq ($(TARGET),linux)
$(BUILD)/input_driver.so: $(BUILD)/tests/input_driver.o
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ -o $@
.PHONY: window-reference
window-reference: $(BUILD)/voxela-window $(BUILD)/input_driver.so
	python3 tests/window_play.py $^
endif

# Registry2 wrappers include the shared source; rebuild whenever it changes.
WORLD2_SHARED = src/world/blocks.asm src/world/cache.asm src/world/stream.asm src/render/mesh.asm src/render/vertices.asm src/game/player.asm src/world/walk_save.asm src/world/raycast.asm
$(patsubst %.asm,$(BUILD)/%.o,src/world/blocks2.asm src/world/cache2.asm src/world/stream2.asm src/render/mesh2.asm src/render/vertices2.asm src/game/player2.asm src/world/walk_save2.asm src/world/raycast2.asm): $(WORLD2_SHARED)
$(patsubst %.asm,$(BUILD)/win-abi/%.o,src/world/blocks2.asm src/world/cache2.asm src/world/stream2.asm src/render/mesh2.asm src/render/vertices2.asm src/game/player2.asm src/world/walk_save2.asm src/world/raycast2.asm): $(WORLD2_SHARED)
