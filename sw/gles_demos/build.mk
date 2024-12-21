DEMO ?= $(shell basename $(PWD))
BASE_DIR = $(shell dirname $(lastword $(MAKEFILE_LIST)))
SW_DIR = $(BASE_DIR)/..
PSEUDOGL_DIR = $(SW_DIR)/pseudogl
PSEUDOGL_LIB = $(PSEUDOGL_DIR)/libpseudogl.a
SOURCES ?= $(shell ls *.c)
BUILD_DIR = $(BASE_DIR)/build

ifeq ($(RISCV),1)
export RISCV = 1
#export CC = riscv32-buildroot-linux-gnu-gcc
#export CXX = riscv32-buildroot-linux-gnu-g++
export CC = riscv64-linux-gnu-gcc
export CXX = riscv64-linux-gnu-g++
endif

PROG_SDL = $(BUILD_DIR)/$(DEMO).sdl
PROG_OGLORY = $(BUILD_DIR)/$(DEMO).oglory

CFLAGS_SDL = -DUSE_SDL=1 -lm -lSDL2 -lEGL -lGLU -lGLESv1_CM $(ADD_DEFINES)
CFLAGS_OGLORY = -DUSE_PGL=1 -g -I$(PSEUDOGL_DIR)/include -L$(PSEUDOGL_DIR) -lm -lpseudogl -lstdc++ -lpthread  $(ADD_DEFINES)

.PHONY: clean default sdl oglory pseudogl

sdl: $(PROG_SDL)
oglory: $(PROG_OGLORY)
pseudogl: $(PSEUDOGL_LIB)

$(PROG_SDL): $(SOURCES) $(ADD_DEPS)
	mkdir -p $(BUILD_DIR)
	$(CC) $(SOURCES) $(CFLAGS_SDL) -o $@

$(PROG_OGLORY): $(SOURCES) $(ADD_DEPS) $(PSEUDOGL_LIB)
	mkdir -p $(BUILD_DIR)
	$(CC) $(SOURCES) $(CFLAGS_OGLORY) -o $@
	
$(PSEUDOGL_LIB):
	make -j$(nproc) -C $(PSEUDOGL_DIR)

clean:
	rm -rf $(BUILD_DIR) $(ADD_CLEAN)
