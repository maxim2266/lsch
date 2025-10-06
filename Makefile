# disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# targets
.PHONY: clean test

# binaries
BIN  := lsch
TEST := lsch-test

# Lua version
LUA_VER := 5.4

# clear targets on error
.DELETE_ON_ERROR:

# compilation instructions
define COMPILE
	luac$(LUA_VER) -o $@ $^
	sed -i '1s|^|\#!/usr/bin/env lua$(LUA_VER)\n|' $@
	chmod 0711 $@
endef

# compilation
$(BIN): app.lua main.lua
	$(COMPILE)

# cleanup
clean:
	rm -f $(BIN) $(TEST)

# testing
test: $(TEST)

$(TEST): app.lua test_app.lua
	$(COMPILE)
	./$@
