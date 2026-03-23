-- run_batch.lua
-- Batch launcher and session monitor for headless extinction simulations.
--
-- Usage:
--   lua run_batch.lua [batch_file.lua]
--
-- If no batch_file is given, runs the DEFAULT_BATCH defined at the bottom of
-- this file.  A batch file must return a table with the shape shown below.
--
-- ── Batch spec format ────────────────────────────────────────────────────────
--
--   return {
--     name     = "my_experiment",   -- session label (optional)
--     parallel = false,             -- true = run all jobs simultaneously
--     runs = {
--       { players = 500 },
--       { players = 500, seed = 42 },
--       { updates = 200000, seed = 7 },
--       { players = 500, resume = "runs/neat_nb4_flat_lifetime/1234567890" },
--       named_config,               -- Lua variable reuse
--       named_config,               -- same spec, different seed (if seed is nil)
--     },
--   }
--
-- Each run spec fields:
--   name     string   label shown in the session table
--   players  number   stop after N autoplayer replacements (recommended)
--   updates  number   stop after N update ticks
--   seed     number   RNG seed (auto-assigned if nil)
--   resume   string   run directory to resume from
--   conf     table    arbitrary conf overrides, e.g.:
--                       conf = { autoplayer_neat_add_neuron_chance = 0.05 }
--                     Scalar values only (number, boolean, string).
-- ─────────────────────────────────────────────────────────────────────────────

local IS_WIN = package.config:sub(1,1) == "\\"

-- ── find Lua interpreter ──────────────────────────────────────────────────────

local function find_lua()
	local bundled = IS_WIN
		and { ".\\lua\\luajit.exe", ".\\lua\\lua5.4.exe" }
		or  { "./lua/luajit",       "./lua/lua5.4"       }
	for _, f in ipairs(bundled) do
		local h = io.open(f) ; if h then h:close() return f end
	end
	local check = IS_WIN and "where" or "command -v"
	for _, name in ipairs({ "luajit", "lua5.4", "lua" }) do
		local h = io.popen(check .. " " .. name .. (IS_WIN and " 2>nul" or " 2>/dev/null"))
		if h then
			local out = h:read("*a") ; h:close()
			if out and out:match("%S") then return name end
		end
	end
end

-- ── serialise a scalar conf value to a --conf key=value string ───────────────

local function conf_arg(key, val)
	local v
	if type(val) == "boolean" then
		v = val and "true" or "false"
	else
		v = tostring(val)
	end
	return "--conf " .. key .. "=" .. v
end

-- ── build the OS command for one run record ───────────────────────────────────

local function build_cmd(lua_exe, rec)
	local exe   = (lua_exe:match("%s") or IS_WIN) and ('"' .. lua_exe .. '"') or lua_exe
	local parts = { exe, "run_headless.lua" }

	if rec.updates then
		parts[#parts+1] = tostring(rec.updates)
	end
	if rec.players then
		parts[#parts+1] = "--players " .. tostring(rec.players)
	end
	if rec.seed then
		parts[#parts+1] = "--seed " .. tostring(rec.seed)
	end
	if rec.resume then
		parts[#parts+1] = '--resume "' .. rec.resume .. '"'
	end
	if rec.sentinel then
		parts[#parts+1] = '--sentinel "' .. rec.sentinel .. '"'
	end
	-- --conf-file comes first so individual --conf keys can override it.
	if rec.conf_file then
		parts[#parts+1] = '--conf-file "' .. rec.conf_file .. '"'
	end
	if rec.spec.conf then
		for k, v in pairs(rec.spec.conf) do
			parts[#parts+1] = conf_arg(k, v)
		end
	end

	return table.concat(parts, " ")
end

-- ── session table ─────────────────────────────────────────────────────────────

local function make_session(batch)
	local session = {
		name     = batch.name or "batch",
		parallel = batch.parallel or false,
		total    = #batch.runs,
		runs     = {},
	}
	-- Each run record wraps the user's spec with runtime state.
	for i, spec in ipairs(batch.runs) do
		session.runs[i] = {
			spec    = spec,
			-- resolved fields (may differ from spec due to auto-seed)
			players   = spec.players,
			updates   = spec.updates,
			resume    = spec.resume,
			conf_file = spec.conf_file,
			seed      = spec.seed,     -- nil until assigned
			status  = "pending",     -- pending | running | done | failed
			t0      = nil,
			elapsed = nil,
			log     = nil,
			sentinel = nil,
		}
	end
	return session
end

-- ── display helpers ───────────────────────────────────────────────────────────

local COL_STATUS = 9

local function rec_label(rec)
	local name = rec.spec.name
	local parts = name and { name } or {}
	if rec.players then parts[#parts+1] = "players=" .. rec.players end
	if rec.updates then parts[#parts+1] = "updates=" .. rec.updates end
	if rec.seed    then parts[#parts+1] = "seed="    .. rec.seed    end
	if rec.resume    then parts[#parts+1] = "resume"                       end
	if rec.conf_file then parts[#parts+1] = rec.conf_file:match("([^/\\]+)$") end
	if rec.spec.conf then
		local kv = {}
		for k, v in pairs(rec.spec.conf) do kv[#kv+1] = k .. "=" .. tostring(v) end
		if #kv > 0 then parts[#parts+1] = "{" .. table.concat(kv, ", ") .. "}" end
	end
	return #parts > 0 and table.concat(parts, "  ") or "(default)"
end

local function elapsed_str(rec)
	if rec.elapsed then
		return string.format("%7.1fs", rec.elapsed)
	elseif rec.t0 then
		return string.format("%7.1fs", os.clock() - rec.t0)
	end
	return "        "
end

local function print_session(session)
	local SEP = string.rep("-", 72)
	print(SEP)
	print(string.format("Batch: %-24s  (%d runs)%s",
		session.name, session.total,
		session.parallel and "  [parallel]" or ""))
	print(SEP)
	for i, rec in ipairs(session.runs) do
		print(string.format("  [%d/%d] %-" .. COL_STATUS .. "s  %s  %s",
			i, session.total, rec.status:upper(),
			elapsed_str(rec), rec_label(rec)))
	end
	print(SEP)
end

-- ── sleep helper ─────────────────────────────────────────────────────────────

local function sleep(secs)
	if IS_WIN then
		os.execute("timeout /T " .. secs .. " >nul")
	else
		os.execute("sleep " .. secs)
	end
end

-- ── sequential runner ─────────────────────────────────────────────────────────

local function run_sequential(session, lua_exe)
	for i, rec in ipairs(session.runs) do
		rec.status = "running"
		rec.t0     = os.clock()
		print(string.format("\n>>> [%d/%d]  %s\n", i, session.total, rec_label(rec)))

		local cmd = build_cmd(lua_exe, rec)
		local ok  = os.execute(cmd)
		rec.elapsed = os.clock() - rec.t0
		rec.status  = (ok == true or ok == 0) and "done" or "failed"

		print(string.format("\n<<< [%d/%d] %s  (%.1fs)\n",
			i, session.total, rec.status:upper(), rec.elapsed))
		print_session(session)
	end
end

-- ── parallel runner ───────────────────────────────────────────────────────────

local function run_parallel(session, lua_exe)
	local batch_id = tostring(os.time())

	-- Launch all jobs.
	for i, rec in ipairs(session.runs) do
		rec.sentinel = string.format("batch_%s_%d.sentinel", batch_id, i)
		rec.log      = string.format("batch_%s_%d.log",      batch_id, i)
		rec.t0       = os.clock()
		rec.status   = "running"

		local cmd = build_cmd(lua_exe, rec)

		if IS_WIN then
			-- Redirect into the log; sentinel written by run_headless.lua.
			os.execute('start "" /B cmd /C "' .. cmd .. ' >"' .. rec.log .. '" 2>&1"')
		else
			os.execute(cmd .. ' >"' .. rec.log .. '" 2>&1 &')
		end
	end

	print_session(session)

	-- Poll until all jobs finish.
	local function pending_count()
		local n = 0
		for _, rec in ipairs(session.runs) do
			if rec.status == "running" then n = n + 1 end
		end
		return n
	end

	while pending_count() > 0 do
		sleep(2)
		for _, rec in ipairs(session.runs) do
			if rec.status == "running" then
				local h = io.open(rec.sentinel)
				if h then
					local result = h:read("*a") ; h:close()
					os.remove(rec.sentinel)
					rec.elapsed = os.clock() - rec.t0
					rec.status  = result:match("^done") and "done" or "failed"
				end
			end
		end
		print_session(session)
	end

	-- Print log paths for inspection.
	print("Run logs:")
	for i, rec in ipairs(session.runs) do
		print(string.format("  [%d] %s", i, rec.log))
	end
end

-- ── auto-assign seeds to avoid collisions (important in parallel mode) ────────

local function assign_seeds(session)
	local base = os.time()
	for i, rec in ipairs(session.runs) do
		if not rec.seed then
			rec.seed = base + i   -- unique across the batch
		end
	end
end

-- ── main ──────────────────────────────────────────────────────────────────────

local batch
local batch_file = arg and arg[1]
if batch_file then
	local fn, err = loadfile(batch_file)
	if not fn then
		io.stderr:write("run_batch: cannot load batch file: " .. tostring(err) .. "\n")
		os.exit(1)
	end
	batch = fn()
else
	-- ── Default batch — edit or replace with a batch file ──────────────────
	batch = {
		name     = "default",
		parallel = false,
		runs = {
			{ players = 200 },
			{ players = 200 },
			{ players = 200 },
		},
	}
end

assert(type(batch) == "table" and type(batch.runs) == "table",
	"Batch must be a table with a 'runs' array field")

local lua_exe = find_lua()
if not lua_exe then
	io.stderr:write("run_batch: no Lua interpreter found.\n"
		.. "Install luajit or lua5.4, or place a binary in ./lua/\n")
	os.exit(1)
end

local session    = make_session(batch)
local wall_start = os.clock()

assign_seeds(session)
print_session(session)

if session.parallel then
	run_parallel(session, lua_exe)
else
	run_sequential(session, lua_exe)
end

-- Final summary
local n_done, n_failed = 0, 0
for _, rec in ipairs(session.runs) do
	if rec.status == "done"   then n_done   = n_done   + 1 end
	if rec.status == "failed" then n_failed = n_failed + 1 end
end
print(string.format("\nBatch '%s' finished in %.1fs — %d done, %d failed.",
	session.name, os.clock() - wall_start, n_done, n_failed))
if n_failed > 0 then os.exit(1) end
