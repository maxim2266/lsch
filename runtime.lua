-- shortcuts
program_pathname = arg[0]
program_name = program_pathname:match("[^/]+$")

-- console messages -------------------------------------------------------------------------------
do
	-- print message to STDERR
	local function show_msg(kind, msg, ...)
		if select("#", ...) > 0 then
			msg = msg:format(...)
		end

		return io.stderr:write(program_name, ": [", kind, "] ", msg, "\n")
	end

	-- [global] print error message
	function perror(msg, ...)
		return show_msg("error", msg, ...)
	end

	-- [global] print warning
	function pwarning(msg, ...)
		return show_msg("warning", msg, ...)
	end
end


-- Lua version check (at least 5.3 is required)
do
	local major, minor = _VERSION:match("^Lua ([5-9])%.(%d+)$")

	if not major or (major == "5" and tonumber(minor) < 3) then
		perror("cannot run with Lua version %q (at least v5.3 is required)\n", _VERSION)
		os.exit(false)
	end
end

-- [global] shell quoting
function Q(s) --> quoted string
	s = s:gsub("'+", function(m) return "'" .. string.rep("\\'", m:len()) .. "'" end)

	return "'" .. s .. "'"
end

-- error handling ---------------------------------------------------------------------------------
do
	-- error reporting helper
	local function _fail(err, code)
		if math.type(code) == "integer" then
			-- returning from os.execute or similar
			if err == "exit" then
				-- propagate the code, assuming an error message has already been
				-- produced by an external program
				error(code, 0)
			end

			if err == "signal" then
				err = "interrupted with signal " .. code
			end
		end

		error(err, 0)
	end

	-- [global] error checker
	function just(ok, err, code, ...)
		if ok then
			return ok, err, code, ...
		end

		_fail(err, code)
	end

	-- [global] application error reporter (never returns)
	function fail(msg, ...)
		if type(msg) == "string" and select("#", ...) > 0 then
			msg = msg:format(...)
		end

		error(msg, 0)
	end

	-- [global] application runner (never returns)
	function run(fn, ...)
		local ok, err = pcall(fn, ...)

		if ok then
			os.exit(true)
		end

		if math.type(err) == "integer" then
			-- exit with this error code, assuming an error message has already been
			-- printed out
			os.exit(err)
		end

		io.stderr:write(program_name, ": [error] ", tostring(err):gsub("%s+$", ""), "\n")
		os.exit(false)
	end

	-- [global] resource handler
	function with(resource, cleanup, fn, ...) --> whatever fn returns
		local function wrap(ok, ...)
			if ok then
				just(cleanup(resource, true))
				return ...
			end

			pcall(cleanup, resource)
			_fail(...)
		end

		return wrap(pcall(fn, resource, ...))
	end

	-- delete file ignoring "file not found" error
	local function _remove(fname)
		local ok, err, code = os.remove(fname)

		if ok or code == 2 then	-- ENOENT 2 No such file or directory
			return true
		end

		return ok, err, code
	end

	-- [global] execute fn with a temporary file name, removing the file in the end
	function with_tmp_file(fn, ...)
		return with(os.tmpname(), _remove, fn, ...)
	end

	-- remove directory
	local function _rm_dir(dir)
		return os.execute("rm -rf " .. Q(dir))
	end

	-- [global] execute fn with a temporary directory name, removing the directory in the end
	function with_tmp_dir(fn, ...)
		-- create temp. directory
		local cmd = just(io.popen("mktemp -d"))
		local tmp = cmd:read("l")

		just(cmd:close())

		-- invoke fn
		return with(tmp, _rm_dir, fn, ...)
	end
end

-- pumping null-delimited data --------------------------------------------------------------------
do
	-- pump helper
	local function _pump(src, fn)
		local tail = ""
		local N = 8 * 1024
		local s = src:read(N)

		while s do	-- explicit loop to avoid stack trace on signals
			local b, e = 1, s:find("\0", 1, true)

			if e then
				fn(tail .. s:sub(b, e - 1))
				b = e + 1
				e = s:find("\0", b, true)

				while e do
					fn(s:sub(b, e - 1))
					b = e + 1
					e = s:find("\0", b, true)
				end

				tail = s:sub(b)
			else
				tail = tail .. s
			end

			s = src:read(N)
		end

		if #tail ~= 0 then	-- must never happen
			fail("reading command output: missing delimiter on the last line")
		end
	end

	-- [global] feed fn with lines from cmd output, using "\0" symbol as line delimiter
	function pump(cmd, fn)
		with(just(io.popen(cmd)), io.close, _pump, fn)
	end
end
