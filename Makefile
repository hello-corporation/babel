CC          := gcc
WARNINGS    := -Wall
PY_INCLUDE  := $(shell python -c "import sysconfig; print(sysconfig.get_path('include'))")
PY_VERSION  := $(shell python -c "import sysconfig; print(sysconfig.get_python_version())")
INTERPRETER := $(shell readelf -l /bin/sh | grep "Requesting program interpreter" | grep -Eo '/[^]]*')
C_RUNTIME   := $(shell gcc -print-file-name=crt1.o; gcc -print-file-name=crti.o; gcc -print-file-name=crtn.o)
BUILDDIR    := $(PWD)
LIBS        := -lc2 -lrust -lasm -lcython -lc
SRC         := src
O           := obj
L           := lib
E           := babel

ifeq ($(shell id -u),0)
    PREFIX ?= /usr/local
else
    PREFIX ?= $(HOME)/.local
endif

default: init c rust asm cython main link

init:
	@mkdir -p $(O) $(L) $(C)

c:
	gcc $(WARNINGS) -shared -fPIC -o $(L)/libc2.so $(SRC)/c.c

rust:
	rustc --crate-type=cdylib -o $(L)/librust.so $(SRC)/rust.rs

asm:
	nasm -f elf64 $(SRC)/asm.asm -o $(O)/asm.o
	gcc $(WARNINGS) -shared -fPIC -o $(L)/libasm.so $(O)/asm.o

cython:
	cythonize -3 $(SRC)/cython3.pyx
	mv -v $(SRC)/cython3.{c,h} $(O)/
	gcc $(WARNINGS) -shared -I$(O) -I$(PY_INCLUDE) -L $(shell python -c "import sys; print(sys.prefix)")/lib -fPIC -o $(L)/libcython.so $(O)/cython3.c -lpython$(PY_VERSION)

main:
	gcc $(WARNINGS) -c -o $(O)/main.o $(SRC)/main.c

link:
	ld -o $(E) -L$(PWD)/$(L) -rpath $(PWD)/$(L) -dynamic-linker $(INTERPRETER) $(LIBS) $(C_RUNTIME) $(O)/main.o
	@printf "You can now run %s\n" ./$(E)

install:
	# TODO: install shared libraries into $(PREFIX)/lib.
	# The current setup is a sort of "editable install for binaries",
	# but only halfway there.
	@echo PREFIX is $(PREFIX)
	install -d   $(PREFIX)/bin
	install $(E) $(PREFIX)/bin

develop: default install

clean:
	rm -rf $(O) $(E)
