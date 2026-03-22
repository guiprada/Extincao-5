-- run_batch.lua
-- Batch launcher and session monitor for headless extinction simulations.
--
-- Usage:
--   lua run_batch.lua [batch_file.lua]
--
-- If no batch_file is given, runs the DEFAULT_BATCH defined at the bottom of
-- this file.  A batch file must return a table with the shape shown below.
--
-- Batch spec format:
--   return {
--     name = "my_experiment",    -- label shown in output (optional)
--     runs = {
--       { players = 500 },
--       { players = 500, seed = 42 },
--       { updates = 200000, seed = 7 },
--       { players = 500, resume = "runs/neat_nb4_flat_lifetime/1234567890" },
--     },
--   }
--
-- Each run spec accepts:
--   players  number   stop after N autoplayer replacements (recommended)
--   updates  number   stop after N update ticks
--   seed     number   RNG seed (default: os.time())
--   resume   string   path to a previous run directory to resume from

local IS_WIN = package.config:sub(1,1) == "\\"

-- ── find Lua interpreter ──────────────────────────────────────────────────────

local function find_lua()
	local bundled = IS_WIN
		and { ".\\lua\\luajit.exe", ".\\lua\\lua5.4.exe" }
		or  { "./lua/luajit",       "./lua/lua5.4"       }
	for _, f in ipairs(bundled) do
		local h = io.open(f)
		if h then h:close() return f end
	end
	local check = IS_WIN and "where" or "command -v"
	for _, name in ipairs({ "luajit", "lua5.4", "lua" }) do
		local h = io.popen(check .. " " .. name .. " 2>nul")
		if h then
			local out = h:read("*a") ; h:close()
			if out and out:match("%S") then return name end
		end
	end
end

-- ── build the OS command for one run spec ────────────────────────────────────

local function build_cmd(lua_exe, spec)
	-- Quote the executable if it contains spaces or backslashes.
	local exe = lua_exe:match("%s") and ('"' .. lua_exe .. '"') or lua_exe
	local parts = { exe, "run_headless.lua" }
	if spec.updates then
		parts[#parts+1] = tostring(spec.updates)
	end
	if spec.players then
		parts[#parts+1] = "--players"
		parts[#parts+1] = tostring(spec.players)
	end
	if spec.seed then
		parts[#parts+1] = "--seed"
		parts[#parts+1] = tostring(spec.seed)
	end
	if spec.resume then
		parts[#parts+1] = "--resume"
		parts[#parts+1] = '"' .. spec.resume .. '"'
	end
	return table.concat(parts, " ")
end

-- ── session table ─────────────────────────────────────────────────────────────

local function make_session(batch)
	local session = {
		name  = batch.name or "batch",
		total = #batch.runs,
		runs  = {},
	}
	for i, spec in ipairs(batch.runs) do
		session.runs[i] = {
			spec    = spec,
			status  = "pending",   -- pending | running | done | failed
			elapsed = nil,
		}
	end
	return session
end

-- ── display helpers ───────────────────────────────────────────────────────────

local function spec_label(spec)
	local parts = {}
	if spec.players then parts[#parts+1] = "players=" .. spec.players end
	if spec.updates then parts[#parts+1] = "updates=" .. spec.updates end
	if spec.seed    then parts[#parts+1] = "seed="    .. spec.seed    end
	if spec.resume  then parts[#parts+1] = "resume='" .. spec.resume .. "'" end
	return #parts > 0 and table.concat(parts, "  ") or "(default)"
end

local STATUS_W = 9   -- column width for status label

local function print_session(session)
	local SEP = string.rep("-", 68)
	print(SEP)
	print(string.format("Batch: %-20s  (%d runs)", session.name, session.total))
	print(SEP)
	for i, r in ipairs(session.runs) do
		local status = r.status:upper()
		local time   = r.elapsed and string.format("%7.1fs", r.elapsed) or "        "
		print(string.format("  [%d/%d] %-" .. STATUS_W .. "s  %s  %s",
			i, session.total, status, time, spec_label(r.spec)))
	end
	print(SEP)
end

-- ── main ──────────────────────────────────────────────────────────────────────

-- Load batch definition.
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
	-- Default batch — edit freely or replace with a batch file.
	batch = {
		name = "default",
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

print_session(session)

for i, run in ipairs(session.runs) do
	run.status = "running"
	print(string.format("\n>>> [%d/%d] starting  %s\n", i, session.total, spec_label(run.spec)))

	local cmd = build_cmd(lua_exe, run.spec)
	local t0  = os.clock()
	local ok  = os.execute(cmd)
	run.elapsed = os.clock() - t0
	run.status  = (ok == true or ok == 0) and "done" or "failed"

	print(string.format("\n<<< [%d/%d] %s  (%.1fs)\n",
		i, session.total, run.status:upper(), run.elapsed))
	print_session(session)
end

-- Summary
local n_done, n_failed = 0, 0
for _, r in ipairs(session.runs) do
	if r.status == "done"   then n_done   = n_done   + 1 end
	if r.status == "failed" then n_failed = n_failed + 1 end
end
print(string.format("Batch finished in %.1fs — %d done, %d failed.",
	os.clock() - wall_start, n_done, n_failed))
if n_failed > 0 then os.exit(1) end
