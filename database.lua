-- constants
local DB_NAME = "./.lsch.db"	-- database file name
TYPE_UNKNOWN, TYPE_FILE, TYPE_LINK = 0, 1, 2	-- file types

-- walk directory tree and invoke callback on each file or link
local function walk(fn) --> nil
	local cmd = "find . \\( -type f -or -type l \\) ! -path " .. Q(DB_NAME) .. " -printf '%y %s %p\\0'"

	return pump(cmd, function(s)
		local t, n, name = s:match("^(%a) (%d+) (.+)$")

		return fn(name,
				  t == "f" and TYPE_FILE or t == "l" and TYPE_LINK or TYPE_UNKNOWN,
				  tonumber(n))
	end)
end

-- traverse current directory and call the function with basic stats on each file or link
function traverse(fname, fn)
	with(just(io.open(fname, "w")), io.close, function(dest)
		walk(function(name, kind, size)
			if kind == TYPE_FILE then
				if fn(name, kind, size) and size > 0 then
					just(dest:write(name, "\0"))
				end
			elseif kind == TYPE_LINK then
				local src = just(io.popen("readlink -n " .. Q(name)))
				local tag = src:read("a")

				just(src:close())
				fn(name, kind, size, tag)
			else
				pwarning("object of unknown type: %q (skipped)", name)
			end
		end)
	end)
end

-- per each file name from 'fname' call 'fn' with (name, sum) pair
function pump_sums(fname, fn)
	local cmd = 'xargs -n 1 -0 -r -P "$(nproc)" -- sha256sum -bz < ' .. Q(fname)

	pump(cmd, function(s)
		local sum, name = s:match("^(%x+) %*(.+)$")

	    return fn(name, sum)
	end)
end

-- build in-memory database of all files and links, with stats and tags
local function do_build_database(fname) --> { name -> { kind, size, tag } }
	-- the database
	local db = {}

	traverse(fname, function(name, kind, size, tag)
		if kind == TYPE_FILE then
	        db[name] = { kind = kind, size = size }
	        return size > 0	-- request sha256 for non-empty files only
		else -- link
	        db[name] = { kind = kind, size = size, tag = tag }
		end
	end)

	-- add checksums
	pump_sums(fname, function(name, sum)
		local stat = db[name]

		if stat then
			stat["tag"] = sum
		else
			fail("stray file name %q (mixed up output of sha256 calculator?)", name)
		end
	end)

	return db
end

-- pcall(do_build_database)
function build_database() --> { name -> { kind, size, tag } }
	return with_temp_file(do_build_database)
end

-- save database
local function do_save_database(fname, db)
	-- write database to the temporary file, gzip'ed
	with(just(io.popen("gzip -q -9 > " .. Q(fname), "w")), io.close, function(dest)
	    just(dest:write("return {\n"))

		for name, stat in pairs(db) do
			just(dest:write(string.format("[%q] = { kind = %u, size = %u, tag = %q },\n",
	                                     name, stat.kind, stat.size, stat.tag)))
		end

		just(dest:write("}\n"))
	end)

	-- replace the actual database file
	just(os.execute("mv -T " .. Q(fname) .. " " .. Q(DB_NAME)))
end

-- save database to the file DB_NAME
function save_database(db)
	return with_temp_file(do_save_database, db)
end

-- load database from file DB_NAME
function load_database() --> { name -> { kind, size, tag } }
	return with(just(io.popen("gzip -cd " .. Q(DB_NAME))), io.close, function(src)
		local function src_iter()
			return src:read(16 * 1024)
		end

		return just(load(src_iter, DB_NAME, "t", {}))()
	end)
end

-- test if database file exists
function database_file_exists()
	local db, err, code = io.open(DB_NAME)

	if not db then
		if code == 2 then	-- ENOENT 2 No such file or directory
			return false
		end

		fail(err)
	end

	return just(db:close())
end

function database_file_must_exist()
	if not database_file_exists() then
		fail("database file is not found in this directory (run `"
			  .. basename()
			  .. " init' to create one)")
	end
end

-- create empty database file
function create_empty_database()
	with_temp_file(function(tmp)
		tmp = Q(tmp)

		local cmd = "echo 'return {}' | gzip -9cn > " .. tmp .. " && mv -T " .. tmp .. " " .. Q(DB_NAME)

		just(os.execute(cmd))
	end)
end

-- dump
local function kind_to_string(k)
	return k == TYPE_FILE and "file"
		or k == TYPE_LINK and "link"
		or string.format("unknown (%q)", k)
end

function dump_database()
	database_file_must_exist()

	for name, stat in pairs(load_database()) do
		just(io.stdout:write(string.format("%q\n  type: %s\n  size: %u\n   tag: %q\n",
		                                   name, kind_to_string(stat.kind),
		                                   stat.size, stat.tag)))
	end
end
