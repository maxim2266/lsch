# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# targets
.PHONY: all clean

# source files
LUA_FILES := error.lua pump.lua database.lua main.lua

# program binary
BIN := lsch

# all
all: $(BIN)

# compilation
$(BIN): $(LUA_FILES)
	luac5.3 -s -o $@ $^
	sed -i '1s|^|#!/usr/bin/env lua5.3\n|' $@ && chmod +x $@

# clean up
clean:
	rm -f $(BIN)
