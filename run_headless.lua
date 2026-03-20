-- Headless simulation runner.
-- Runs the extinction simulation without a display, using lua5.4 standalone.
--
-- Usage (from the project root):
--   lua5.4 run_headless.lua [max_updates] [--players N] [--resume <run_dir>]
--
-- max_updates      number of gs.update() ticks to run (default: 500000).
--                  Ignored if --players is given.
-- --players N      stop after N total autoplayer replacements (recommended;
--                  this is the natural unit of evolutionary progress).
-- --resume <dir>   resume from a saved population checkpoint.
--                  <dir> is the run folder, e.g.:
--                    runs/neat_nb4_flat_lifetime/1773336963
--                  The conf is re-read normally; only the population gene
--                  pool is restored from the checkpoint.
--
-- Output lands in runs/<strategy>/<seed>/ (.data event log, run.conf,
-- population.lua checkpoint updated every generation and on exit).

-- ============================================================
-- love mock
-- ============================================================
-- Stubs every love.* API the codebase touches so modules load cleanly
-- and the update loop runs without a display.

local _stub_font  = { getHeight = function() return 12 end,
                       getWidth  = function() return 8  end }
local _stub_image = { getDimensions = function() return 32, 32 end,
                       getWidth  = function() return 32 end,
                       getHeight = function() return 32 end }

love = {
	graphics = {
		getWidth   = function()    return 800 end,
		getHeight  = function()    return 600 end,
		newImage   = function()    return _stub_image end,
		newFont    = function()    return _stub_font  end,
		setFont    = function()    end,
		getColor   = function()    return 1, 1, 1, 1 end,
		setColor   = function()    end,
		draw       = function()    end,
		print      = function()    end,
		printf     = function()    end,
		circle     = function()    end,
		line       = function()    end,
		rectangle  = function()    end,
		setCanvas  = function()    end,
		clear      = function()    end,
		present    = function()    end,
	},
	keyboard = {
		isDown = function() return false end,
	},
	filesystem = {
		isDirectory       = function() return false end,
		isFile            = function() return false end,
		getDirectoryItems = function() return {}    end,
	},
	window = {
		setMode  = function() end,
		setTitle = function() end,
	},
}

-- ============================================================
-- Bootstrap services
-- ============================================================
-- Mirror the minimal subset of main.lua's love.load() that the
-- simulation needs. Window and audio services are skipped entirely.

local qpd = require "qpd.qpd"

qpd.files.load("qpd/services/files.conf")
qpd.files.load("conf/files.conf")
qpd.keymap.load(qpd.files.keymap_conf)
qpd.strings.load(qpd.files.str_en)
qpd.fonts.load(qpd.files.fonts_conf)   -- calls newFont -> returns _stub_font

-- ============================================================
-- Parse arguments
-- ============================================================
local max_updates  = nil   -- set below after flag parsing
local max_players  = nil   -- stop after this many autoplayer replacements
local resume_dir   = nil
do
	local i = 1
	-- First positional arg (if numeric and not a flag) is max_updates.
	if arg and arg[i] and not arg[i]:match("^%-%-") then
		max_updates = tonumber(arg[i])
		i = i + 1
	end
	while arg and arg[i] do
		if arg[i] == "--players" and arg[i+1] then
			max_players = tonumber(arg[i+1])
			i = i + 2
		elseif arg[i] == "--resume" and arg[i+1] then
			resume_dir = arg[i+1]
			i = i + 2
		else
			i = i + 1
		end
	end
end
-- --players overrides max_updates; fall back to 500 000 update cap.
if not max_players and not max_updates then
	max_updates = 500000
end

-- ============================================================
-- Load and start simulation
-- ============================================================

local extinction = require "gamestates.extinction"
extinction.load()

-- Optionally restore population from a previous checkpoint.
if resume_dir then
	local pop_io = require "qpd.population_io"
	local data   = pop_io.load(resume_dir)
	if data and extinction.AutoPlayerPopulation then
		pop_io.restore(extinction.AutoPlayerPopulation, data)
		print("[headless] resumed from: " .. resume_dir)
	else
		print("[WARN] [headless] --resume: could not restore population from " .. resume_dir)
	end
end

-- Use max_dt for every tick: deterministic, physics-safe steps.
-- If game_fixed_distance_per_update is set in conf the update loop does
-- this automatically; we mirror that here for the headless case.
local dt  = extinction.max_dt
local pop = extinction.AutoPlayerPopulation

local goal_str
if max_players then
	goal_str = string.format("max_players=%d", max_players)
else
	goal_str = string.format("max_updates=%d", max_updates)
end

print(string.format("[headless] starting: %s  dt=%.6f  seed=%s%s",
	goal_str, dt, tostring(extinction.game_conf and extinction.game_conf.seed),
	resume_dir and ("  resume=" .. resume_dir) or ""))

local t0 = os.clock()
local updates_done = 0

if max_players then
	-- Run until the autoplayer replacement counter hits the target.
	local start_count = pop and pop._count or 0
	while (not pop or (pop._count - start_count) < max_players) do
		extinction.update(dt)
		updates_done = updates_done + 1
	end
else
	for _ = 1, max_updates do
		extinction.update(dt)
		updates_done = updates_done + 1
	end
end

local elapsed = os.clock() - t0
local players_done = pop and pop._count or 0

print(string.format("[headless] done: %d updates  %d total players  %.1f s  (%.0f updates/s)",
	updates_done, players_done, elapsed, updates_done / math.max(elapsed, 0.001)))

-- Final population save (complements the per-generation saves in extinction.lua).
extinction.unload()
