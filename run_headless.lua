-- Headless simulation runner.
-- Runs the extinction simulation without a display, using lua5.4 standalone.
--
-- Usage (from the project root):
--   lua5.4 run_headless.lua [max_updates]
--
-- max_updates: number of gs.update() ticks to run (default: 500000)
--
-- The simulation reads conf/extinction.conf and conf/games.conf as normal.
-- To run a specific experiment, copy or symlink the desired test config to
-- conf/extinction.conf before launching.
--
-- Output lands in logs/ as usual (.data files for analysis).

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
	timer = {
		getTime = os.clock,
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
-- Load and start simulation
-- ============================================================

local extinction = require "gamestates.extinction"
extinction.load()

-- Use max_dt for every tick: deterministic, physics-safe steps.
-- If game_fixed_distance_per_update is set in conf the update loop does
-- this automatically; we mirror that here for the headless case.
local dt          = extinction.max_dt
local max_updates = tonumber(arg and arg[1]) or 500000

print(string.format("[headless] starting: max_updates=%d  dt=%.6f  seed=%s",
	max_updates, dt, tostring(extinction.game_conf and extinction.game_conf.seed)))

local t0 = os.clock()
for i = 1, max_updates do
	extinction.update(dt)
end
local elapsed = os.clock() - t0

print(string.format("[headless] done: %d updates in %.1f s  (%.0f updates/s)",
	max_updates, elapsed, max_updates / elapsed))
