assert(app, 'missing "app.lua"')

local function ensure(cond, msg, ...)
	if not cond then
		app:fail(msg, ...)
	end
end

local function test_trim()
	local tests <const> = {
		"xxx",
		"  xxx ",
		"\txxx",
		"xxx\t\n",
	}

	for i, s in ipairs(tests) do
		local r <const> = s:trim()

		ensure(r == "xxx", "(%d) unexpected result: %q", i, r)
	end
end

local function test_expand()
	local m <const> = {
		a = 42,
		abc = "xxx",
	}

	local tests <const> = {
		{ "__${a}__", "__42__" },
		{ "${a}__", "42__" },
		{ "${a}", "42" },
		{ "__$${a}__", "__${a}__" },
		{ "$${a}__", "${a}__" },
		{ "$${abc}", "${abc}" },
		{ "${a}_${abc}", "42_xxx" },
		{ "${a}_${x}", "42_${x}" },
		{ "$(a}", "$(a}" },
		{ "{a}", "{a}" },
		{ "${5}", "${5}" },
	}

	for i, t in ipairs(tests) do
		local r <const> = t[1]:expand(m)

		ensure(r == t[2], "(%d) unexpected result: %q", i, r)
	end

	local user <const> = os.getenv("USER")

	if user then	-- $USER might be undefined
		local user2 <const> = ("${USER}"):expand(os.getenv)

		ensure(user == user2, "unexpected result: %q instead of %q", user2, user)
	else
		app:warn("environment variable $USER is not defined")
	end
end

local function test_shell_quote()
	local tests <const> = {
		"'",
		"rock'n'roll",
		"one\ntwo\n",
		"'xxx'",
		"'''x'x'x'''\n'''",
		"$PATH",
	}

	for i, t in ipairs(tests) do
		local s <const> = shell.read("echo -n " .. shell.quote(t))

		ensure(s == t, "(%d) unexpected result: %q", i, s)
	end
end

local function test_lines_from()
	local tests <const> = {
		{ "", "" },
		{ "x", "x" },
		{ "_", "" },
		{ "___", "__" },
		{ "xx_xxx", "xx_xxx" },
		{ "xx____xxx", "xx____xxx" },
		{ "_xx_xxx", "_xx_xxx" },
		{ "___xx_xxx", "___xx_xxx" },
		{ "xx_xxx_", "xx_xxx" },
		{ "xx_xxx___", "xx_xxx__" },
		{ string.rep("x", 8 * 1024), string.rep("x", 8 * 1024) },
		{ string.rep("x", 8 * 1024 + 1), string.rep("x", 8 * 1024 + 1) },
		{ string.rep("x", 8 * 1024) .. "_", string.rep("x", 8 * 1024) },
		{ string.rep("x", 8 * 1024 - 1) .. "_", string.rep("x", 8 * 1024 - 1) },
		{ string.rep("x", 8 * 1024 - 1) .. "___", string.rep("x", 8 * 1024 - 1) .. "__" },
		{ string.rep("x", 32 * 1024 - 1) .. "___x", string.rep("x", 32 * 1024 - 1) .. "___x" },
	}

	local just = context("io.lines_from")
	local tmp <const> = os.tmpfile()

	for i, t in ipairs(tests) do
		local f <const> = just(io.open(tmp, "w+"))

		just(f:write(t[1]))
		just(f:seek("set", 0))

		local res = {}

		for s in io.lines_from(f, "_") do
			res[#res + 1] = s
		end

		just(f:close())

		res = table.concat(res, "_")

		ensure(res == t[2], "(%d) unexpected result: %q", i, res)
	end
end

local function test_lines_from_2()
	local just <const> = context("io.lines_from (default)")
	local temp_name <const> = os.tmpfile()
	local tmp <const> = just(io.open(temp_name, "w+"))

	just(tmp:write("xxx\nyyy\nzzz\n"))
	just(tmp:seek("set"))

	local res = {}

	for s in io.lines_from(tmp) do
		res[#res + 1] = s
	end

	just(tmp:close())

	res = table.concat(res, "_")

	if res ~= "xxx_yyy_zzz" then
		just:fail("unexpected result: %q", res)
	end
end

-- test runner
local function all_tests(tests)
	for i, t in ipairs(tests) do
		local name, test = t[1], t[2]

		print("# test " .. i .. ":", name)
		test()
		print("+ passed")
	end

	print("OK: " .. #tests .. " tests passed.")
end

app:run(all_tests, {
	{ "string.trim", test_trim },
	{ "string.expand", test_expand },
	{ "shell.quote", test_shell_quote },
	{ "io.lines_from", test_lines_from },
	{ "io.lines_from (default)", test_lines_from_2 },
})
