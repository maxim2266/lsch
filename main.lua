assert(app, 'missing "app.lua"')

-- database file name
local DB_NAME <const> = ".lsch.db"

-- recursive directory iterator
local function scan_dir(ctx) --> iterator
	local just <const> = context("directory scanner", ctx)
	local src = just(io.popen("exec find . -type 'f,l' -printf '%y %s %p\\0' -type l -printf '%l\\0'"))

	src:setvbuf("full")

	local next_line <const> = io.lines_from(src, "\0")

	local function iter()
		-- next line
		local s <const> = next_line()

		if not s then
			-- close the file handle, but only once
			if io.type(src) == "file" then
				just(src:close())
			end

			return
		end

		-- make item
		local item <const> = {}

		item.type, item.size, item.name = s:match("^([fl]) (%d+) (.+)$")

		if not item.type then
			just(src:close())	-- the command may have failed
			just:fail("unexpected input: %q", s)
		end

		-- update item values
		item.size = math.tointeger(item.size)
		item.name = item.name:sub(3)	-- remove './' prefix

		-- skip own database
		if item.name == DB_NAME then
			return iter()
		end

		-- symlink
		if item.type == "l" then
			-- link has its target name on the next line
			item.tag = next_line()

			if not item.tag or #item.tag == 0 then
				just(src:close())	-- the command may have failed
				just:fail("invalid link name: %q", item.tag or "<nil>")
			end
		end

		return item
	end

	return iter
end

-- sha256 calculator
local function calc_sums(fname, ctx) --> iterator over (name, sum) pairs
	local just <const> = context("sha256 calculator", ctx)
	local cmd <const> = 'exec xargs -n 1 -0 -r -P "$(nproc)" -- sha256sum -bz < ' .. shell.quote(fname)
	local src <const> = just(io.popen(cmd))

	src:setvbuf("full")

	local next_line <const> = io.lines_from(src, "\0")

	return function()
		-- next line
		local s <const> = next_line()

		if not s then
			-- close the file handle, but only once
			if io.type(src) == "file" then
				just(src:close())
			end

			return
		end

		-- get the sum
		local sum, name = s:match("^(%x+) %*(.+)$")

		if not sum then
			just(src:close())	-- the command may have failed
			just:fail("invalid sha256 calculator input: %q", s)
		end

		return name, sum
	end
end

-- scanner
local function scan(consume, preview)
	-- default preview function
	if not preview then
		preview = function() end
	end

	-- error context
	local just <const> = context("scanner")

	-- temporary file for file names
	local tmp_name <const> = os.tmpfile()
	local tmp <const> = just(io.open(tmp_name, "w"))

	tmp:setvbuf("full")

	-- file data
	local files <const> = {}
	local file_count = 0

	-- directory scan
	for item in scan_dir() do
		if not preview(item) then
			if item.type == "l" or item.size == 0 then
				consume(item)	-- links and empty files do not need checksums
			else
				-- schedule checksum calculation
				just(tmp:write(item.name, "\0"))

				files[item.name] = item
				file_count = file_count + 1
			end
		end
	end

	just(tmp:close())

	-- see if there are checksums to calculate
	if file_count == 0 then
		return
	end

	-- checksumming
	for name, sum in calc_sums(tmp_name, just) do
		local item <const> = files[name]

		if not item then
			just:fail("unmatched file %q", name)
		end

		item.tag = sum
		files[name] = nil
		file_count = file_count - 1

		consume(item)
	end

	-- one last check
	if file_count ~= 0 then
		just:fail("%d unprocessed file(s) still remain", file_count)
	end
end

-- template of the command to write database (because gzip errors may be confusing)
local WRITE_DB_CMD <const> = [=[
die() {
	echo >&2 "${prog}: [error]" "$@"
	exit 1
}

if [ -e '${db}' ]
then
	[ ! -f '${db}' ] && die 'database file "${db}" is not a regular file'
	[ ! -w '${db}' ] && die 'database file "${db}" is not writable'
fi

exec gzip -n9c '${tmp}' > '${db}'
]=]

-- create and store a new database ("lsch --reset")
local function reset()
	local just <const> = context("writing new database")
	local patt <const> = "\t[%q] = { type = %q, size = %u, tag = %q },\n"
	local tmp_name <const> = os.tmpfile()
	local tmp <const> = just(io.open(tmp_name, "w"))

	tmp:setvbuf("full")

	just(tmp:write("return {\n"))

	scan(function(item)
		just(tmp:write(patt:format(item.name, item.type, item.size, item.tag)))
	end)

	just(tmp:write("}\n"))
	just(tmp:close())
	just(os.execute(WRITE_DB_CMD:expand{ tmp = tmp_name, db = DB_NAME, prog = app.NAME }))
end

-- template of the command to read database (because gzip errors may be confusing)
local LOAD_DB_CMD <const> = [=[
die() {
	echo >&2 "${prog}: [error]" "$@"
	exit 1
}

[ ! -e '${db}' ] && die 'database file "${db}" does not exist (run "${prog} -r" to create one)'
[ ! -f '${db}' ] && die 'database file "${db}" is not a regular file'
[ ! -r '${db}' ] && die 'database file "${db}" is not readable'

exec gzip -cd '${db}'
]=]

-- load database from file
local function load_db()
	local just <const> = context("loading database")
	local cmd <const> = LOAD_DB_CMD:expand{ prog = app.NAME, db = DB_NAME }
	local db <const> = shell.read(cmd, just)

	return just(load(db, DB_NAME, "t", {}))()
end

-- compare existing files to the saved database
local function diff(delim)
	local db <const> = load_db()
	local just <const> = context("listing changes")

	io.stdout:setvbuf("full")

	scan(function(a)
		-- compare tags of a and b
		local b <const> = db[a.name]

		if a.tag ~= b.tag then
			just(io.stdout:write("* ", a.name, delim))
		end

		db[a.name] = nil
	end,
	function(a)	-- preview
		-- compare a and b
		local b <const> = db[a.name]

		-- new files
		if not b then
			just(io.stdout:write("+ ", a.name, delim))
			return true
		end

		-- existing files
		if a.type ~= b.type or a.size ~= b.size or (a.type == "l" and a.tag ~= b.tag) then
			just(io.stdout:write("* ", a.name, delim))
		elseif a.type == "f" and a.size > 0 then
			return false	-- need checksum
		end

		db[a.name] = nil
		return true
	end)

	-- remaining items are all deleted
	for name in pairs(db) do
		just(io.stdout:write("- ", name, delim))
	end
end

-- help string
local HELP <const> = "Usage: " .. app.NAME .. [=[ [OPTIONS]

List all added, deleted, or modified files in the current directory and its subdirectories.

Options:
  -0          use ASCII null as output separator
  -r,--reset  record the current state of the directory tree for further comparisons
  -h,--help   display this help and exit
]=]

-- main
app:run(function()
	if #arg > 1 then
		app:fail("too many arguments")
	end

	local opt <const> = arg[1]

	if not opt then
		diff("\n")
	elseif opt == "-0" then
		diff("\0")
	elseif opt == "-r" or opt == "--reset" then
		reset()
	elseif opt == "-h" or opt == "--help" then
		io.stderr:write(HELP)
		os.exit(false)
	else
		app:fail("unknown option: %q", opt)
	end
end)
