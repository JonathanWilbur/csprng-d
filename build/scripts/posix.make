#!/usr/bin/make
#
# Run this from the root directory like so:
# make -f ./build/scripts/posix.make
# sudo make -f ./build/scripts/posix.make install
#
vpath %.o ./build/objects
vpath %.di ./build/interfaces/source
vpath %.di ./build/interfaces/source/csprng
vpath %.d ./source/csprng
vpath %.asm ./source/x86
vpath %.d ./source/tools
vpath %.html ./documentation/html
vpath %.a ./build/libraries
vpath %.so ./build/libraries
vpath % ./build/executables

version = 1.0.2

modules = system
sources = $(addsuffix .d,$(modules))
interfaces = $(addsuffix .di,$(modules))
objects = $(addsuffix .o,$(modules))
htmldocs = $(addsuffix .html,$(modules))

.SILENT : all libs tools csprng-$(version).a csprng-$(version).so get-cryptobytes install purge
all : libs tools
libs : csprng-$(version).a csprng-$(version).so
tools : get-cryptobytes

uname := $(shell uname)
ifeq ($(uname), Linux)
	echoflags = "-e"
endif
ifeq ($(uname), Darwin)
	echoflags = ""
endif

# You will most likely need to run this will root privileges
install : all
	cp ./build/libraries/csprng-$(version).so /usr/local/lib
	-rm -f /usr/local/lib/csprng.so
	ln -s /usr/local/lib/csprng-$(version).so /usr/local/lib/csprng.so
	cp ./build/executables/get-cryptobytes /usr/local/bin
	-cp ./documentation/man/1/* /usr/local/share/man/1
	-cp ./documentation/man/1/* /usr/local/share/man/man1
	mkdir -p /usr/local/share/csprng/{html,md,json}
	cp -r ./documentation/html/* /usr/local/share/csprng/html
	cp -r ./documentation/*.md /usr/local/share/csprng/md
	cp -r ./documentation/csprng-$(version).json /usr/local/share/csprng/json/csprng-$(version).json
	cp ./documentation/mit.license /usr/local/share/csprng

purge :
	-rm -f /usr/local/lib/csprng.so
	-rm -f /usr/local/lib/csprng-$(version).so
	-rm -f /usr/local/bin/get-cryptobytes
	-rm -rf /usr/local/share/csprng
	-rm -f /usr/local/share/man/man1/get-cryptobytes.1
	-rm -f /usr/local/share/man/man1/get-cryptobytes.1
	-rm -f /usr/local/share/man/1/get-cryptobytes.1
	-rm -f /usr/local/share/man/1/get-cryptobytes.1

csprng-$(version).a : $(sources)
	echo $(echoflags) "Building the CSPRNG Library (static)... \c"
	dmd \
	./source/macros.ddoc \
	./source/csprng/*.d \
	-Dd./documentation/html \
	-Hd./build/interfaces \
	-op \
	-of./build/libraries/csprng-$(version).a \
	-Xf./documentation/csprng-$(version).json \
	-lib \
	-inline \
	-release \
	-O \
	-map \
	-d
	echo $(echoflags) "\033[32mDone.\033[0m"

csprng-$(version).so : $(sources)
	echo $(echoflags) "Building the CSPRNG Library (shared / dynamic)... \c"
	dmd \
	./source/macros.ddoc \
	./source/csprng/*.d \
	-Dd./documentation/html \
	-Hd./build/interfaces \
	-op \
	-of./build/libraries/csprng-$(version).so \
	-lib \
	-inline \
	-release \
	-O \
	-map \
	-d
	echo $(echoflags) "\033[32mDone.\033[0m"

get-cryptobytes : csprng-$(version).a $(sources) $(interfaces)
	echo $(echoflags) "Building the CSPRNG Command-Line Tool, get-cryptobytes... \c"
	dmd \
	./source/tools/get_cryptobytes.d \
	-I./build/interfaces/source \
	./build/libraries/csprng-$(version).a \
	-of./build/executables/get-cryptobytes \
	-inline \
	-release \
	-O \
	-d
	echo $(echoflags) "\033[32mDone.\033[0m"

# How Phobos compiles only the JSON file:
# JSON = phobos.json
# json : $(JSON)
# $(JSON) : $(ALL_D_FILES)
# $(DMD) $(DFLAGS) -o- -Xf$@ $^