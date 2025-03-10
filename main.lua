local function print_line(prefix, name)
	just(io.write(prefix, " ", name:gsub("\n", "⏎"), "\n"))
end

local function print_line_0(prefix, name)
	just(io.write(prefix, " ", name, "\0"))
end

-- display usage string and exit
local function usage()
	just(io.stderr:write("Usage: ", program_name, [=[ [CMD] [OPTIONS]...

List all added, deleted, and modified files in the current directory and its subdirectories.

Without CMD argument the tool shows all changes made since the last reset.
  Options:
    -0   use ASCII null as output separator

The CMD argument, if given, must be one of the following:
  init            create empty change tracking database in the current directory
                  Options:
                    -f,--force   discard any previous tracking data
  reset           accept current state as the reference for further change tracking
  help,-h,--help  display this help and exit
]=]))
	os.exit(1)
end

-- check if there is exactly one command line option that matches any of the given names
local function one_option(args, ...)
	if #args == 0 then
		return false
	end

	if #args > 1 then
		perror("too many options\n")
		usage()
	end

	local opt = args[1]

	for i = 1, select("#", ...) do
		if opt == select(i, ...) then
			return true
		end
	end

	perror("unknown option %q\n", opt)
	usage()
end

-- ensure no options supplied
local function no_options(args)
	if #args > 0 then
		perror("this command does not expect options\n")
		usage()
	end
end

-- listing of changes
local function do_diff(fname, db)
	traverse(fname, function(name, kind, size, tag)
		local stat = db[name]

		if not stat then
	        print_line("+", name)
	        return
		end

		if kind ~= stat.kind or size ~= stat.size or ((kind == TYPE_LINK or size == 0) and tag ~= stat.tag) then
	        print_line("*", name)
	        db[name] = nil
	        return
		end

		if kind == TYPE_FILE and size > 0 then
			return true	-- request checksum
		end

		db[name] = nil	-- this was either a link, or a file of zero size
	end)

	-- compare sums
	pump_sums(fname, function(name, sum)
		if sum ~= db[name].tag then
			print_line("*", name)
	    end

		db[name] = nil
	end)

	-- all remaining items must have been deleted
	for name in pairs(db) do
		print_line("-", name)
	end
end

-- commands
local function reset(args)
	no_options(args)
	database_file_must_exist()
	return save_database(build_database())
end

local function ls(args)
	if one_option(args, "-0") then
		print_line = print_line_0
	end

	database_file_must_exist()
	with_temp_file(do_diff, load_database())
end

local function init(args)
	if not one_option(args, "-f", "--force") and database_file_exists() then
		fail("database file already exists")
	end

	create_empty_database()
end

-- main
local function main()
	local cmd_map = {
		["help"] = usage,
		["--help"] = usage,
		["-h"] = usage,
		["reset"] = reset,
		["init"] = init,
		["dump"] = dump_database
	}

	local cmd = cmd_map[arg[1]]

	if cmd then
		cmd(table.move(arg, 2, #arg, 1, {}))
	else
		ls(table.move(arg, 1, #arg, 1, {}))
	end
end

run(main)
