# disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# targets
.PHONY: all clean install uninstall

# binary
BIN := lsch

# Lua version
LUA_VER := 5.4

# compilation
all: $(BIN)

$(BIN): lua-app/app.lua main.lua
	./version > ver.lua
	luac$(LUA_VER) -o $@ $< ver.lua $(wordlist 2, $(words $^), $^)
	rm -f ver.lua
	sed -i '1s|^|\#!/usr/bin/env lua$(LUA_VER)\n|' $@
	chmod 0755 $@

# cleanup
clean:
	rm -f $(BIN)

# installation
PREFIX := /usr/local
BINDIR := $(PREFIX)/bin

install: $(BIN)
	install -m555 -Dt $(DESTDIR)$(BINDIR) $^

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(BIN)
