-- shell quoting
local function Q(s) --> quoted string
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- initialise random generator
math.randomseed(os.time())

-- generate random string 'n' bytes long
local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

local function rand_string(n)
	local res = {}
	local rand = math.random

	for i = 1, n do
		local j = rand(1, #charset)

		res[i] = charset:sub(j, j)
	end

	return table.concat(res)
end

-- write a string to a file
local function write_file(name, content)
	local out = just(io.open(name, "w"))
	local ok, err = out:write(content)

	if ok then
		just(out:close())
	else
		out:close()
		os.remove(name)
		error(err)
	end
end

-- create a file with random content
local function create_random_file(fname)
	write_file(fname, rand_string(math.random(10, 1000)))
end

-- write a line to STDOUT
local function trace(msg)
	just(io.write(msg, "\n"))
end

-- find executable
local function lsch_full_pathname()
	-- check if executable is present
	if not os.execute("test -x ./lsch -a -f ./lsch") then
		error('executable file "lsch" is not found in this directory')
	end

	-- get full pathname
	local cmd = just(io.popen("realpath ./lsch"))
	local lsch = cmd:read("a")

	just(cmd:close())
	return lsch:sub(1, -2)	-- cut off trailing newline
end

-- make a function that compares lsch output to the given list
local function make_expect(dir)
	local cmd = "cd " .. Q(dir) .. " && " .. Q(lsch) .. " -0"

	return function(...)
		local exp = {}

		for i = 1, select("#", ...) do
			exp[select(i, ...)] = true
		end

		pump(just(io.popen(cmd)), function(s)
			if not exp[s] then
				error(string.format("unexpected line: %q", s))
			end

			exp[s] = nil
		end)

		local s = next(exp)

		if s then
			error(string.format("missing line: %q", s))
		end
	end
end

-- make executor
local function make_exec(dir)
	local prefix = "set -e; alias lsch=" .. Q(lsch) .. "; cd " .. Q(dir) .. "\n"

	return function(cmd)
		just(os.execute(prefix .. cmd))
	end
end

-- invoke all tests one by one
local function all_tests(...)
	lsch = lsch_full_pathname()	-- global variable

	local n = select("#", ...)

	-- print header
	if n == 0 then
		error("no tests to run")
	elseif n == 1 then
		trace("running 1 test...")
	else
		trace("running " .. n .. " tests...")
	end

	-- run the tests
	for i = 1, n do
		trace("[ test " .. i .. " ]")

		-- create temp. directory
		local cmd = just(io.popen("mktemp -d"))
		local tmp = cmd:read("l")

		just(cmd:close())

		-- run the test
		local ok, err = pcall(select(i, ...), tmp)

		os.execute("rm -rf " .. Q(tmp))
		just_check(ok, err)
		trace("+ passed.")
	end

	-- done
	trace("all done.")
end

-- display test step name
local function step(name)
	just(io.write(": ", name, "\n"))
end

-- test runner
local function run_tests(...)
	return run(all_tests, ...)
end

-- test cases
local function test_base_ops(tmp)
	create_random_file(tmp .. "/a")
	create_random_file(tmp .. "/b")
	create_random_file(tmp .. "/c")

	local exec = make_exec(tmp)
	local expect = make_expect(tmp)

	step("init")
	exec("lsch init")
	expect("+ ./a", "+ ./b", "+ ./c")

	step("reset")
	exec("lsch reset")
	expect()

	step("change file")
	write_file(tmp .. "/a", "###")
	expect("* ./a")
	exec("lsch reset")

	step("delete file")
	just(os.remove(tmp .. "/a"))
	expect("- ./a")
	exec("lsch reset")

	step("empty file")
	exec("touch a")
	expect("+ ./a")
	exec("lsch reset")

	step("change empty file to link")
	exec("rm a && ln -s b a")
	expect("* ./a")
	exec("lsch reset")

	step("change link")
	exec("rm a && ln -s c a")
	expect("* ./a")
end

local function test_exotic_names(tmp)
	create_random_file(tmp .. "/with space")
	create_random_file(tmp .. "/with\nnewline")
	create_random_file(tmp .. "/rockin'")
	create_random_file(tmp .. "/rock'n'roll")
	create_random_file(tmp .. "/o'ops'''")
	create_random_file(tmp .. "/'done'''")
	create_random_file(tmp .. "/one more\n")

	local exec = make_exec(tmp)
	local expect = make_expect(tmp)

	step("init")
	exec("lsch init")
	expect("+ ./with space",
		   "+ ./with\nnewline",
		   "+ ./rockin'",
		   "+ ./rock'n'roll",
		   "+ ./o'ops'''",
		   "+ ./'done'''",
		   "+ ./one more\n")

	step("reset")
	exec("lsch reset")
	expect()

	step("change one file")
	write_file(tmp .. "/with\nnewline", "###")
	expect("* ./with\nnewline")
	exec("lsch reset")

	step("remove all")
	exec("rm ./*")
	expect("- ./with space",
		   "- ./with\nnewline",
		   "- ./rockin'",
		   "- ./rock'n'roll",
		   "- ./o'ops'''",
		   "- ./'done'''",
		   "- ./one more\n")
end

-- entry point
run_tests(test_base_ops, test_exotic_names)
