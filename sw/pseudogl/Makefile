LIB=libpseudogl.a
# CFLAGS += -Iinclude -I. -O2 -DNDEBUG -g 
CFLAGS += -Iinclude -I. -g
CCFLAGS += -std=c++17
OBJECTS = pseudogl.o gles_api.o oglory_comm.o

ifeq ($(RISCV),1)
CFLAGS = -Iinclude -I. -O2 -DNDEBUG -g
IFACE = DEVMEM
endif

ifeq ($(IFACE),DEVMEM)
CFLAGS += -DOGLORY_COMM_DEVMEM=1
OBJECTS += devmem.o
else
CFLAGS += -DOGLORY_COMM_ETHERBONE=1
OBJECTS += libeb-c/etherbone.o
endif

ifdef LITEX_GEN_PATH
CFLAGS += -DLITEX_PATH=1 -I$(shell realpath $(LITEX_GEN_PATH))
endif

.PHONY: clean demo lib

lib: $(LIB)

demo:
	$(MAKE) -C ../gles_demos

%.o : %.cc 
	$(CXX) $(CFLAGS) $(CCFLAGS) $(basename $@).cc -c -o $@

%.o : %.c 
	$(CC) $(CFLAGS) $(basename $@).c  -c -o $@

$(LIB): $(OBJECTS)
	rm -f $(LIB)
	ar -crs $(LIB) $(OBJECTS)

clean:
	rm -f *.o *.a *.so
