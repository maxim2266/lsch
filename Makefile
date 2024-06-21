# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# targets
.PHONY: all clean test

# source files
SRC_FILES := runtime.lua database.lua main.lua
TEST_FILES := runtime.lua test.lua

# binaries
BIN := lsch
TEST_BIN := lsch-test

# Lua
LUA_VER	:= 5.3
LUAC	:= luac$(LUA_VER)

# binary maker
MAKE_BIN = sed -i '1s|^|\#!/usr/bin/env lua$(LUA_VER)\n|' $@ && chmod 0711 $@

# all
all: $(BIN)

# compilation
$(BIN): $(SRC_FILES)
	$(LUAC) -s -o $@ $^
	$(MAKE_BIN)

# clean up
clean:
	rm -f $(BIN) $(TEST_BIN)

# test
test: $(BIN) $(TEST_BIN)
	./$(TEST_BIN)

$(TEST_BIN): $(TEST_FILES)
	$(LUAC) -o $@ $^
	$(MAKE_BIN)
