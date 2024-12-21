TOP=../../../../..
DIRNAME=$(shell basename $(CURDIR))
TARGET_DIR=$(TOP)/run/emu
BIN_DIR=$(TARGET_DIR)/bin
LIB_DIR=$(TARGET_DIR)/lib
PROGNAME=$(BIN_DIR)/$(DIRNAME)
LIBNAME=$(LIB_DIR)/$(DIRNAME).so
HEADERS=$(wildcard *.hh *.h)
CXXFLAGS += -g -I../include
#CXXFLAGS += -O3 -I../include

.PHONY: all

all: $(PROGNAME) $(LIBNAME)

$(PROGNAME): *.cc $(HEADERS)
	mkdir -p $(BIN_DIR)
	c++ $(CXXFLAGS) -DBUILD_BINARY=1 *.cc -o $(PROGNAME)

$(LIBNAME): *.cc $(HEADERS)
	mkdir -p $(LIB_DIR)
	c++ $(CXXFLAGS) -shared -fPIC -DVERBOSE=1 -DBUILD_LIB=1 *.cc -o $(LIBNAME)
