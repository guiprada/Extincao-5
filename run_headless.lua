-- Headless simulation runner.
-- Runs the extinction simulation without a display, using lua5.4 standalone.
--
-- Usage (from the project root):
--   lua5.4 run_headless.lua [max_updates]
--   lua5.4 run_headless.lua [max_updates] --resume <run_dir>
--
-- max_updates  number of gs.update() ticks to run (default: 500000)
-- --resume <run_dir>
--              Resume from a saved population checkpoint.
--              <run_dir> is the full path or relative path to the run folder,
--              e.g.  runs/neat_nb4_path_grading_lifetime/1773336963
--              The conf is loaded normally; only the population gene pool is
--              restored from the checkpoint.
--
-- Output lands in runs/<strategy>/<seed>/ (.data event log, run.conf, population.lua).

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
qpd.keymap.load(qpd.files.keymap_conf)
qpd.strings.load(qpd.files.str_en)
qpd.fonts.load(qpd.files.fonts_conf)   -- calls newFont -> returns _stub_font

-- ============================================================
-- Parse arguments
-- ============================================================
local max_updates = tonumber(arg and arg[1]) or 500000
local resume_dir  = nil
do
	local i = 2
	while arg and arg[i] do
		if arg[i] == "--resume" and arg[i+1] then
			resume_dir = arg[i+1]
			i = i + 2
		else
			i = i + 1
		end
	end
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
local dt = extinction.max_dt

print(string.format("[headless] starting: max_updates=%d  dt=%.6f  seed=%s%s",
	max_updates, dt, tostring(extinction.game_conf and extinction.game_conf.seed),
	resume_dir and ("  resume=" .. resume_dir) or ""))

local t0 = os.clock()
for i = 1, max_updates do
	extinction.update(dt)
end
local elapsed = os.clock() - t0

print(string.format("[headless] done: %d updates in %.1f s  (%.0f updates/s)",
	max_updates, elapsed, max_updates / elapsed))

-- Final population save (complements the per-generation saves in extinction.lua).
extinction.unload()
