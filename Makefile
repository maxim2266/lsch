# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# targets
.PHONY: all clean test

# source files
SRC_FILES := error.lua pump.lua database.lua main.lua
TEST_FILES := error.lua pump.lua test.lua

# binaries
BIN := lsch
TEST_BIN := run-test

# Lua
LUAC := luac

# Lua version (at least 5.3 is required)
ifneq ($(shell $(LUAC) -v | grep -qvE '^Lua ([0-4]\.)|(5\.[0-2]\.)' && echo $$?),0)
  $(error "Unsupported Lua version")
endif

# binary maker
MAKE_BIN = sed -i '1s|^|\#!/usr/bin/env lua\n|' $@ && chmod +x $@

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
