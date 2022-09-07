local function do_pump(src, fn) --> length of tail
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

	return #tail
end

-- feed fn with lines from source, using "\0" symbol as line delimiter
function pump(source, fn)
	-- source stream
	local src

	if source == nil then
		src = io.input()
	elseif type(source) == "string" then
		src = just(io.open(source))
	elseif io.type(source) == "file" then
		src = source
	else
		error(string.format('unexpected source type "%s" in function pump()', type(source)), 2)
	end

	-- run the pump
	local n = try(source and on_error(io.close, src), do_pump, src, fn)

	if source then
		just(src:close())
	end

	-- the last line must be terminated too
	if n ~= 0 then
		error((type(source) == "string" and source or "input") .. ": missing terminator on the last line")
	end
end
