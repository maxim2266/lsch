function basename(s)
	return (s or arg[0]):match("[^/]+$")
end

-- print message to STDERR
local function show_msg(kind, msg)
	return io.stderr:write(basename(), ": [", kind, "] ", msg, "\n")
end

function perror(msg)
	return show_msg("error", msg)
end

function pwarning(msg)
	return show_msg("warning", msg)
end

-- like assert(), but with more checks
function just(ok, err, code, ...)
	if ok then
		return ok, err, code, ...
	end

	if math.type(code) == "integer" then
		if err == "signal" then
			error("interrupted with signal " .. code)
		elseif err == "exit" then
			-- just raise an integer error object
			error(code)
		end
	end

	error(err, 2)
end

-- check pcall return and either re-raise the error, or return results
function just_check(ok, err, ...)
	if ok then
		return err, ...
	end

	error(err, 2)
end

-- wraps fn to create error handler for try() function
function on_error(fn, ...)
	if not fn then
		return nil
	end

	if select("#", ...) == 0 then
		return function(ok , err, ...)
			if ok then
				return err, ...
			end

			fn()
			error(err)
		end
	end

	local params = table.pack(...)

	return function(ok , err, ...)
		if ok then
			return err, ...
		end

		fn(table.unpack(params))
		error(err)
	end
end

-- invokes fn in protected mode, on failure calls err_handler and re-raises the error;
-- err_handler must be created via on_error() function
function try(err_handler, fn, ...)
	if not err_handler then
		return fn(...)
	end

	return err_handler(pcall(fn, ...))
end

-- application entry point
function run(fn, ...)
	local ok, err = pcall(fn, ...)

	if not ok then
		if math.type(err) == "integer" then
			os.exit(err)
		end

		perror(err)
		os.exit(1)
	end
end
