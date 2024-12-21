DEMO ?= cube
ADD_DEFINES = -D$(shell echo $(DEMO) | tr '[:lower:]' '[:upper:]')
ifeq ($(DEMO),spot)
ADD_DEFINES += -lSDL2_image
endif

ADD_DEPS = $(DEMO).h
HEADERS = cow.h suzanne.h teapot0.h teapot1.h spot.h
ADD_CLEAN = $(HEADERS)

include ../build.mk

$(HEADERS):
	tar -xvf models.tar.xz

