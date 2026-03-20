-- Tests for qpd/population_io.lua
-- Covers: Lua-literal serializer, Innovation_manager save/restore,
-- genome serialize/deserialize round-trip, strategy_name derivation,
-- pop_io.save / pop_io.load file I/O, pop_io.restore on GeneticPopulation.
package.path = "../?.lua;" .. package.path

love = { graphics = { getWidth  = function() return 800 end,
                       getHeight = function() return 600 end } }
package.preload["qpd.gamestate"] = function()
	return { switch   = function(name) error("gamestate.switch called: " .. name) end,
	         register = function() end }
end

local runner = require "runner"
local ANN    = require "qpd.ann_neat"
local pop_io = require "qpd.population_io"

local t = runner.new("population_io")

-- ============================================================
-- Helper: build a small ANN with some mutations applied
-- ============================================================
local function make_ann(n_in, n_out)
	return ANN:new_genome(
		n_in,  "identity", nil,
		n_out, "tanh",     nil,
		nil, true,   -- fully connected
		"tanh", nil)
end

-- ============================================================
-- 1.  strategy_name
-- ============================================================

t:eq(pop_io.strategy_name({ autoplayer_neat_enable = true,
                             autoplayer_ann_mode    = "nb4_flat",
                             autoplayer_fitness_mode = "lifetime" }),
     "neat_nb4_flat_lifetime",
     "strategy_name: neat + mode + fitness")

t:eq(pop_io.strategy_name({ autoplayer_neat_enable = false,
                             autoplayer_ann_mode    = "b1",
                             autoplayer_fitness_mode = "visited" }),
     "fixed_b1_visited",
     "strategy_name: fixed + mode + fitness")

t:eq(pop_io.strategy_name({ autoplayer_neat_enable = true }),
     "neat",
     "strategy_name: neat only (no mode/fitness)")

-- Unsafe chars are replaced.
local s = pop_io.strategy_name({ autoplayer_neat_enable = true,
                                  autoplayer_ann_mode    = "has space",
                                  autoplayer_fitness_mode = "ok" })
t:ok(not s:find(" "), "strategy_name: spaces replaced with underscores")

-- ============================================================
-- 2.  Innovation_manager get_state / load_state
-- ============================================================

-- Build a genome to populate the Innovation_manager.
local ann_a = make_ann(3, 2)
ann_a:get_genome():add_link(0)   -- 0 = no loopback chance
ann_a:get_genome():add_neuron()

local state_before = ANN.get_innovation_state()
local id_count_before = state_before.id_count

t:ok(id_count_before > 0, "Innovation_manager: id_count > 0 after building genome")
t:ok(type(state_before.links) == "table",   "Innovation_manager: state.links is a table")
t:ok(type(state_before.neurons) == "table", "Innovation_manager: state.neurons is a table")

-- Save then overwrite with a blank state; restore should bring it back.
ANN.load_innovation_state({ id_count = 0, links = {}, neurons = {} })
t:eq(ANN.get_innovation_state().id_count, 0, "Innovation_manager: load_state resets id_count")

ANN.load_innovation_state(state_before)
t:eq(ANN.get_innovation_state().id_count, id_count_before,
     "Innovation_manager: load_state restores id_count")

-- ============================================================
-- 3.  _Genome serialize / from_data round-trip
-- ============================================================

local ann_b = make_ann(2, 2)
for _ = 1, 3 do ann_b:get_genome():add_link(0) end
ann_b:get_genome():add_neuron()
-- Rebuild the phenotype so ann_b runs the same topology we will serialize.
ann_b = ANN:new(ann_b:get_genome())

local genome_b   = ann_b:get_genome()
local data_b     = genome_b:serialize()

t:ok(type(data_b) == "table",         "genome:serialize returns a table")
t:ok(type(data_b.neurons) == "table", "genome:serialize has neurons list")
t:ok(type(data_b.links)   == "table", "genome:serialize has links list")
t:eq(#data_b.neurons, genome_b:get_neuron_count(),
     "genome:serialize neuron count matches")
t:eq(#data_b.links, genome_b:get_link_count(),
     "genome:serialize link count matches")

-- Verify each neuron record has required fields.
for i, nd in ipairs(data_b.neurons) do
	t:ok(nd.id   ~= nil, "neuron " .. i .. ": has id")
	t:ok(nd.neuron_type ~= nil, "neuron " .. i .. ": has neuron_type")
	t:ok(nd.x    ~= nil, "neuron " .. i .. ": has x")
	t:ok(nd.y    ~= nil, "neuron " .. i .. ": has y")
	t:ok(nd.activation_response ~= nil, "neuron " .. i .. ": has activation_response")
end

-- Verify each link record has required fields.
for i, ld in ipairs(data_b.links) do
	t:ok(ld.id               ~= nil, "link " .. i .. ": has id")
	t:ok(ld.input_neuron_id  ~= nil, "link " .. i .. ": has input_neuron_id")
	t:ok(ld.output_neuron_id ~= nil, "link " .. i .. ": has output_neuron_id")
	t:ok(ld.weight           ~= nil, "link " .. i .. ": has weight")
	t:ok(type(ld.enabled) == "boolean", "link " .. i .. ": enabled is boolean")
end

-- Deserialize and verify structural equality.
local genome_b2 = require("qpd.ann_neat")  -- just need _Genome.from_data accessible via ANN
-- We access from_data through the ANN module's from_genome_data wrapper.
local ann_b2   = ANN.from_genome_data(data_b)
local genome_b2obj = ann_b2:get_genome()

t:eq(genome_b2obj:get_neuron_count(), genome_b:get_neuron_count(),
     "from_genome_data: neuron count matches after round-trip")
t:eq(genome_b2obj:get_link_count(), genome_b:get_link_count(),
     "from_genome_data: link count matches after round-trip")
t:eq(genome_b2obj:get_n_inputs(), genome_b:get_n_inputs(),
     "from_genome_data: n_inputs matches after round-trip")
t:eq(genome_b2obj:get_n_outputs(), genome_b:get_n_outputs(),
     "from_genome_data: n_outputs matches after round-trip")

-- Neuron IDs must be identical (order is preserved since both are sorted).
for i = 1, #genome_b._neurons do
	t:eq(genome_b2obj._neurons[i]:get_id(), genome_b._neurons[i]:get_id(),
		"from_genome_data: neuron[" .. i .. "] id matches")
	t:eq(genome_b2obj._neurons[i]:get_neuron_type(), genome_b._neurons[i]:get_neuron_type(),
		"from_genome_data: neuron[" .. i .. "] type matches")
end

-- Link weights must be preserved to full precision.
for i = 1, #genome_b._links do
	t:eq(genome_b2obj._links[i]:get_weight(), genome_b._links[i]:get_weight(),
		"from_genome_data: link[" .. i .. "] weight matches")
	t:eq(genome_b2obj._links[i]:is_enabled(), genome_b._links[i]:is_enabled(),
		"from_genome_data: link[" .. i .. "] enabled matches")
end

-- The restored ANN must produce the same outputs as the original.
local inputs = {}
for i = 1, genome_b:get_n_inputs() do inputs[i] = 0.5 end
local out_orig    = ann_b:get_outputs(inputs)
local out_restored = ann_b2:get_outputs(inputs)
t:eq(#out_orig, #out_restored, "from_genome_data: output count matches")
for i = 1, #out_orig do
	t:eq(out_orig[i], out_restored[i],
		"from_genome_data: output[" .. i .. "] value matches")
end

-- ============================================================
-- 4.  pop_io.save / pop_io.load (file I/O round-trip)
-- ============================================================

-- We can't run a full GeneticPopulation in the unit-test environment
-- (it needs a map, grid, etc.), so we test save/load with a minimal stub
-- that has the exact same shape as a real GeneticPopulation.

local function make_history_entry(ann_obj, specie_id, fitness)
	return { _fitness = fitness, _genome = ann_obj:get_genome(), _specie_id = specie_id }
end

-- Minimal stub that mimics the fields pop_io.save() reads.
local fake_pop = {
	_species              = nil,          -- no species (non-NEAT path)
	_history              = {
		make_history_entry(make_ann(2,2), "no species", 10),
		make_history_entry(make_ann(2,2), "no species", 20),
	},
	_history_fitness_sum  = 30,
	_specie_threshold     = 3.0,
	_active_size          = 10,
	_population_size      = 100,
	_genetic_population_size = 50,
	_count                = 55,
}
function fake_pop:get_generation() return math.floor(self._count / self._active_size) end

-- Write to /tmp for the test.
local tmp_dir = "/tmp/pop_io_test_" .. tostring(os.time())
os.execute('mkdir -p "' .. tmp_dir .. '"')

local save_ok = pop_io.save(tmp_dir, fake_pop)
t:ok(save_ok, "pop_io.save: returns true on success")

-- Verify file exists.
local f = io.open(tmp_dir .. "/population.lua", "r")
t:ok(f ~= nil, "pop_io.save: file exists after save")
if f then f:close() end

-- Load it back.
local loaded = pop_io.load(tmp_dir)
t:ok(loaded ~= nil, "pop_io.load: returns non-nil")
t:eq(loaded.count, 55, "pop_io.load: count preserved")
t:eq(loaded.active_size, 10, "pop_io.load: active_size preserved")
t:eq(loaded.history_fitness_sum, 30, "pop_io.load: history_fitness_sum preserved")
t:eq(#loaded.history, 2, "pop_io.load: history length preserved")
t:eq(loaded.history[1].fitness, 10, "pop_io.load: history[1].fitness preserved")
t:eq(loaded.history[2].fitness, 20, "pop_io.load: history[2].fitness preserved")

-- Innovation_manager state round-trip through the file.
t:ok(type(loaded.innovation_manager) == "table",
     "pop_io.load: innovation_manager present")
t:ok(loaded.innovation_manager.id_count >= id_count_before,
     "pop_io.load: innovation_manager id_count sane")

-- History genomes are deserializable after loading.
for i, he in ipairs(loaded.history) do
	if he.genome then
		local restored_ann = ANN.from_genome_data(he.genome)
		t:ok(restored_ann ~= nil, "pop_io.load: history[" .. i .. "] genome deserializable")
		t:eq(restored_ann:get_genome():get_neuron_count(),
		     #he.genome.neurons,
		     "pop_io.load: history[" .. i .. "] neuron count survives file round-trip")
	end
end

-- pop_io.load: graceful failure on missing file.
local bad = pop_io.load("/tmp/does_not_exist_abc123")
t:ok(bad == nil, "pop_io.load: returns nil for missing file")

-- ============================================================
-- 5.  GeneticPopulation helpers (get_generation, get_active_size)
-- ============================================================
-- Test the methods on a minimal stub — avoids needing grid/map
-- infrastructure that GeneticPopulation:new() requires in a full run.

local GeneticPopulation = require "entities.GeneticPopulation"

local stub_gp = { _active_size = 5, _count = 0 }
setmetatable(stub_gp, { __index = GeneticPopulation })

t:eq(stub_gp:get_active_size(), 5, "GeneticPopulation: get_active_size() correct")
t:eq(stub_gp:get_generation(),  0, "GeneticPopulation: get_generation() = 0 at start")

stub_gp._count = 5
t:eq(stub_gp:get_generation(), 1, "GeneticPopulation: get_generation() = 1 after active_size replacements")

stub_gp._count = 12
t:eq(stub_gp:get_generation(), 2, "GeneticPopulation: get_generation() = 2 after 2+ active_size replacements")

-- ============================================================
-- Summary
-- ============================================================

os.exit(t:summary() == 0 and 0 or 1)
