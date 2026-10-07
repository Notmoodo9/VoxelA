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
CORE = src/core/hash.asm src/core/arena.asm src/core/seed.asm src/world/blocks.asm src/world/noise.asm src/world/generate.asm src/world/cache.asm src/render/mesh.asm
OBJECTS = $(patsubst %.asm,$(BUILD)/%.o,$(CORE))
.PHONY: all test objects clean reference
all: $(BUILD)/voxela$(EXT)
objects: $(OBJECTS) $(BUILD)/src/platform/main.o $(BUILD)/tests/runner.o
$(BUILD)/%.o: %.asm include/abi.inc include/world.inc include/cache.inc
	@mkdir -p $(@D)
	$(NASM) $(FLAGS) -f $(FORMAT) $< -o $@
$(BUILD)/voxela$(EXT): $(OBJECTS) $(BUILD)/src/platform/main.o
	$(LINKER) $(LDFLAGS) $^ -o $@
$(BUILD)/engine_tests$(EXT): $(OBJECTS) $(BUILD)/tests/runner.o
	$(LINKER) $(LDFLAGS) $^ -o $@
test: $(BUILD)/engine_tests$(EXT)
	./$(BUILD)/engine_tests$(EXT)
ifeq ($(TARGET),linux)
$(BUILD)/libvoxela.so: $(OBJECTS)
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ -o $@
reference: $(BUILD)/libvoxela.so
	python3 tests/reference.py $(BUILD)/libvoxela.so
	python3 tests/chunks.py $(BUILD)/libvoxela.so
endif
clean:
	rm -rf build

# Exercise Windows calling convention on Linux without claiming native Windows
# runtime validation. Prefix symbols so the shim can expose the same API.
ifeq ($(TARGET),linux)
WIN_ABI_OBJECTS = $(patsubst %.asm,$(BUILD)/win-abi/%.o,$(CORE))
$(BUILD)/win-abi/%.o: %.asm include/abi.inc include/world.inc include/cache.inc
	@mkdir -p $(@D)
	$(NASM) $(FLAGS) -DWINDOWS_ABI=1 -f elf64 $< -o $@.raw
	objcopy --prefix-symbols=win_ $@.raw $@
$(BUILD)/libwindows_abi.so: $(WIN_ABI_OBJECTS) $(BUILD)/tests/windows_abi_shim.o
	$(LINKER) -shared -Wl,-Bsymbolic -Wl,-z,noexecstack $^ -o $@
.PHONY: abi-reference
abi-reference: $(BUILD)/libwindows_abi.so
	python3 tests/reference.py $<
	python3 tests/chunks.py $<
endif

# Optional SDL/OpenGL bootstrap; headless targets do not require SDL.
SDL_LIBS ?= -lSDL2
.PHONY: window
window: $(BUILD)/voxela-window$(EXT)
$(BUILD)/voxela-window$(EXT): $(BUILD)/src/platform/window.o
	$(LINKER) $(LDFLAGS) $^ $(SDL_LIBS) -o $@
