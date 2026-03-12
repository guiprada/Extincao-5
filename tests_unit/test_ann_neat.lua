-- Tests for qpd/ann_neat.lua
-- Covers the bugs found in the code review and the defensive invariants.
package.path = "../?.lua;" .. package.path

-- Mock love (only needed for gamestate error path)
love = { graphics = { getWidth = function() return 800 end,
                       getHeight = function() return 600 end } }
-- Mock gamestate.switch so ANN errors don't crash the test process
package.preload["qpd.gamestate"] = function()
	return { switch = function(name) error("gamestate.switch(\"" .. name .. "\") called") end,
	         register = function() end }
end

local runner  = require "runner"
local ANN     = require "qpd.ann_neat"

local t = runner.new("ann_neat")

-- ---- helpers ----

local function make_ann(n_in, n_out, fully_connected)
	return ANN:new_genome(
		n_in,  "identity", nil,
		n_out, "tanh",     nil,
		nil, fully_connected or true,
		"tanh", nil)
end

-- ---- ANN construction ----

local ann = make_ann(3, 2, true)
t:ok(ann ~= nil, "new_genome: returns non-nil ANN")

local genome = ann:get_genome()
t:ok(genome ~= nil, "new_genome: genome accessible via get_genome()")

-- input + output neurons present
local n_neurons = #genome._neurons
t:ok(n_neurons >= 5, "new_genome: at least n_in + n_out neurons  (got " .. n_neurons .. ")")

-- layers: always at least input layer + output layer
t:ok(#genome._unique_layers >= 2, "new_genome: at least 2 unique layers")

-- unique_layers is sorted
for i = 2, #genome._unique_layers do
	t:ok(genome._unique_layers[i] > genome._unique_layers[i-1],
		"new_genome: unique_layers sorted at index " .. i)
end

-- ---- get_outputs ----

local outputs = ann:get_outputs({ 0.1, 0.5, 0.9 })
t:eq(#outputs, 2, "get_outputs: correct output count")
for i = 1, #outputs do
	t:ok(type(outputs[i]) == "number", "get_outputs: output[" .. i .. "] is a number")
end

-- ---- add_link: no self-loops on non-loopback calls ----
-- Bug fix verification: selected_output_neuron was previously assigned from
-- input_neuron_index — every link was a self-loop or silently failed.

local ann2   = make_ann(3, 2, true)
local genome2 = ann2:get_genome()
local initial_links = #genome2._links

for _ = 1, 30 do
	genome2:add_link(0)  -- chance_loopback = 0, so no loopbacks requested
end

-- Every non-recurrent link must connect two DIFFERENT neurons
local self_loops = 0
for i = 1, #genome2._links do
	local link = genome2._links[i]
	if not link:is_recurrent() then
		if link:get_input_neuron():get_id() == link:get_output_neuron():get_id() then
			self_loops = self_loops + 1
		end
	end
end
t:eq(self_loops, 0, "add_link: no self-loops in non-recurrent links after 30 add_link calls")

-- Links were actually added (genome grew)
t:ok(#genome2._links > initial_links,
	"add_link: genome has more links after calls  (before=" .. initial_links
	.. " after=" .. #genome2._links .. ")")

-- ---- add_link loopback: does not crash ----
-- Bug fix verification: loopback path previously passed :get_id() (number)
-- to get_link_innovation_id() which then tried to call :get_id() on that number.

local ok, err = pcall(function()
	local ann3    = make_ann(2, 2, true)
	local genome3 = ann3:get_genome()
	for _ = 1, 20 do
		genome3:add_link(1)  -- chance_loopback = 1, always request loopback
	end
end)
t:ok(ok, "add_link loopback: does not crash  " .. (ok and "" or ("error: " .. tostring(err))))

-- ---- add_neuron: layer count grows ----

local ann4    = make_ann(2, 1, true)
local genome4 = ann4:get_genome()
local layers_before = #genome4._unique_layers

for _ = 1, 5 do genome4:add_neuron() end

t:ok(#genome4._unique_layers >= layers_before,
	"add_neuron: unique_layers count non-decreasing after add_neuron calls")

-- ---- layer sort stability: # unchanged after sort ----
-- Defensive invariant from the observed LuaJIT sort corruption bug.

local ann5    = make_ann(4, 3, true)
local genome5 = ann5:get_genome()
-- Grow the network a bit so layers have more neurons to sort
for _ = 1, 8 do genome5:add_neuron() end
local ann5_built = ANN:new(genome5)
local genome5b   = ann5_built:get_genome()

-- Re-compile the genome and check that all layer lengths are consistent
-- with the neuron count (i.e. no neurons lost during sort)
local total_in_layers = 0
local g5_layers = ann5_built._layers
for i = 1, #g5_layers do
	total_in_layers = total_in_layers + #g5_layers[i]
end
t:eq(total_in_layers, #genome5b._neurons,
	"layer sort: total neurons in _layers equals genome neuron count")

return t:summary()
