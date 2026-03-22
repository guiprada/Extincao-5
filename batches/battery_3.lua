-- batches/battery_3.lua
-- Battery 3: NEAT vs fixed-topology neuroevolution.
--
-- 4 topologies × 2 fitness modes × 2 methods (NEAT / fixed) = 16 runs.
-- Topology (ann_layers + ann_mode) comes from conf snippets in batches/conf/.
--
-- Usage:
--   lua run_batch.lua batches/battery_3.lua
--   lua run_batch.lua batches/battery_3.lua   (parallel = true for speed)

local N_PLAYERS_NEAT  = 500   -- NEAT converges slower; more budget
local N_PLAYERS_FIXED = 300

-- ── NEAT population settings (from paper's take_1_neat) ──────────────────────

local NEAT = {
	autoplayer_neat_enable                            = true,
	autoplayer_neat_speciate                          = true,
	autoplayer_neat_initial_links                     = 1,
	autoplayer_neat_fully_connected                   = false,
	autoplayer_neat_negative_weight_initialization    = true,
	autoplayer_neat_add_neuron_with_unit_activation   = true,
	autoplayer_neat_specie_mule_start                 = false,
	autoplayer_neat_specie_all_roulette_start         = true,
	autoplayer_neat_specie_threshold                  = 3,
	autoplayer_neat_specie_niche_initial_population_size  = 30,
	autoplayer_neat_specie_niche_population_history_size  = 30,
	autoplayer_neat_add_neuron_chance                 = 0.01,
	autoplayer_neat_add_link_chance                   = 0.02,
	autoplayer_neat_loopback_link_chance              = 0.05,
	autoplayer_neat_randon_weight_reset_on_crossover_chance = 0,
	autoplayer_initial_random_population_size         = 1000,
	autoplayer_population_history_size                = 300,
}

-- ── Fixed-topology population settings (from paper's take_1_ne) ──────────────

local FIXED = {
	autoplayer_neat_enable                    = false,
	autoplayer_initial_random_population_size = 3000,
	autoplayer_population_history_size        = 300,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function merge(base, overrides)
	local t = {}
	for k, v in pairs(base)      do t[k] = v end
	for k, v in pairs(overrides) do t[k] = v end
	return t
end

local function neat_run(topology_file, fitness)
	local topo_name = topology_file:match("([^/\\]+)%.conf$"):gsub("^topology_", "")
	return {
		name      = topo_name .. "/" .. fitness .. "/NEAT",
		players   = N_PLAYERS_NEAT,
		conf_file = topology_file,
		conf      = merge(NEAT, { autoplayer_fitness_mode = fitness }),
	}
end

local function fixed_run(topology_file, fitness)
	local topo_name = topology_file:match("([^/\\]+)%.conf$"):gsub("^topology_", "")
	return {
		name      = topo_name .. "/" .. fitness .. "/fixed",
		players   = N_PLAYERS_FIXED,
		conf_file = topology_file,
		conf      = merge(FIXED, { autoplayer_fitness_mode = fitness }),
	}
end

-- ── Topology paths ────────────────────────────────────────────────────────────

local B1    = "batches/conf/topology_b1.conf"
local B1PGH = "batches/conf/topology_b1_path_grading_hack.conf"
local NB4   = "batches/conf/topology_nb4.conf"
local NB4PG = "batches/conf/topology_nb4_path_grading.conf"

-- ── Batch ─────────────────────────────────────────────────────────────────────

return {
	name     = "battery_3_neat_vs_fixed",
	parallel = false,   -- set true to run all 16 simultaneously
	runs = {
		-- b1
		neat_run(B1,    "movement_captures_hack_26"),
		neat_run(B1,    "lifetime"),
		fixed_run(B1,   "movement_captures_hack_26"),
		fixed_run(B1,   "lifetime"),
		-- b1_path_grading_hack
		neat_run(B1PGH, "movement_captures_hack_26"),
		neat_run(B1PGH, "lifetime"),
		fixed_run(B1PGH,"movement_captures_hack_26"),
		fixed_run(B1PGH,"lifetime"),
		-- nb4
		neat_run(NB4,   "movement_captures_hack_26"),
		neat_run(NB4,   "lifetime"),
		fixed_run(NB4,  "movement_captures_hack_26"),
		fixed_run(NB4,  "lifetime"),
		-- nb4_path_grading
		neat_run(NB4PG, "movement_captures_hack_26"),
		neat_run(NB4PG, "lifetime"),
		fixed_run(NB4PG,"movement_captures_hack_26"),
		fixed_run(NB4PG,"lifetime"),
	},
}
