-- batches/battery_2.lua
-- Battery 2: Fixed-topology neuroevolution (no NEAT).
--
-- Tests the 4 selected topologies against the two main fitness modes.
-- Topology (ann_layers + ann_mode) comes from conf snippets in batches/conf/.
-- All other settings use project defaults from extinction.conf.
--
-- Usage:
--   lua run_batch.lua batches/battery_2.lua

local N_PLAYERS = 300   -- autoplayer replacements per run

-- Shared fixed-topology population settings.
local FIXED = {
	autoplayer_neat_enable                    = false,
	autoplayer_initial_random_population_size = 3000,
	autoplayer_population_history_size        = 300,
}

local function run(topology, fitness)
	local c = {}
	for k, v in pairs(FIXED) do c[k] = v end
	c.autoplayer_fitness_mode = fitness
	return {
		name      = topology:match("([^/\\]+)%.conf$"):gsub("^topology_", "") .. "/" .. fitness,
		players   = N_PLAYERS,
		conf_file = topology,
		conf      = c,
	}
end

local B1     = "batches/conf/topology_b1.conf"
local B1PGH  = "batches/conf/topology_b1_path_grading_hack.conf"
local NB4    = "batches/conf/topology_nb4.conf"
local NB4PG  = "batches/conf/topology_nb4_path_grading.conf"

return {
	name     = "battery_2_fixed_topology",
	parallel = false,
	runs = {
		run(B1,    "movement_captures_hack_26"),
		run(B1,    "lifetime"),
		run(B1PGH, "movement_captures_hack_26"),
		run(B1PGH, "lifetime"),
		run(NB4,   "movement_captures_hack_26"),
		run(NB4,   "lifetime"),
		run(NB4PG, "movement_captures_hack_26"),
		run(NB4PG, "lifetime"),
	},
}
