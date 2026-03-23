-- batches/battery_1.lua
-- Battery 1: Baseline specialist algorithms (no neuroevolution).
--
-- Each mode encodes a hand-crafted decision strategy for the autoplayer.
-- Runs are stopped by update count (no population to evolve).
--
-- Usage:
--   lua run_batch.lua batches/battery_1.lua

local N_UPDATES = 500000   -- ticks per run; adjust as needed

local function baseline(mode)
	return {
		name    = mode,
		updates = N_UPDATES,
		conf = {
			autoplayer_ann_mode                   = mode,
			autoplayer_fitness_mode               = "movement",
			autoplayer_neat_enable                = false,
			autoplayer_initial_random_population_size = 0,
			autoplayer_population_history_size    = 0,
		},
	}
end

return {
	name     = "battery_1_baselines",
	parallel = false,
	runs = {
		baseline("baseline"),
		baseline("baseline_pill_ghost"),
		baseline("baseline_pill"),
		baseline("baseline_random"),
		baseline("baseline_collide_random"),
		baseline("baseline_valid_random"),
		baseline("baseline_valid_full_random"),
		baseline("baseline_full_random"),
	},
}
