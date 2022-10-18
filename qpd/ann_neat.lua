-- Guilherme Cunha Prada 2022
local ANN = {}
ANN.__index = ANN

local qpd_table = require "qpd.table"
local qpd_random = require "qpd.random"
local ann_activation_functions = require "qpd.ann_activation_functions"

local MAX_LOOPBACK_LINK_TRIES = 5
local MAX_LINK_TRIES = 10
local Innovation_manager -- create singleton instance, will be initialized after _Innovation_manager implementation

------------------------------------------------------------------------------- Types
local _link_types = {
	"forward",
	"recurrent",
	"looped_recurrent"
}

local _neuron_types = {
	"input",
	"hidden",
	"bias",
	"output",
	"none",
}

local _ann_run_types = {
	"snapshot",
	"active"
-- you have to select one of these types when updating the network
-- If snapshot is chosen the network depth is used to completely
-- flush the inputs through the network. active just updates the
-- network each time-step
}

-- internal functions
local function get_random_link_weight()
	return qpd_random.random()
end

local function get_random_activation_response(input_count)
	input_count = input_count or 1
	return qpd_random.random() * input_count
end

-- Internal Classes
-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Link
local _Link_Gene = {}

function _Link_Gene:new(from_neuron, to_neuron, weight, enabled, innovation_id, o)
	local o = o or {}
	setmetatable(o, self)

	o._from_neuron = from_neuron
	o._to_neuron = to_neuron
	o._weight = weight
	o._enabled = enabled
	o._innovation_id = innovation_id


	o._recurrent = false
	local from_neuron = Innovation_manager:get_innovation(from_neuron)
	local to_neuron = Innovation_manager:get_innovation(to_neuron)

	o._recurrent = from_neuron:is_link_recurrent(to_neuron)

	return o
end

function _Link_Gene:mutate(mutate_chance, mutate_percentage)
	self._weight = self._weight * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
end

function _Link_Gene:inherit(mutate_chance, mutate_percentage)
	return qpd_table.clone(self):mutate(mutate_chance, mutate_percentage)
end

function _Link_Gene:get_id()
	return self._innovation_id
end

function _Link_Gene:type()
	return "_Link_Gene"
end
-------------------------------------------------------------------------------
local _Link = {}

function _Link:new(input_neuron, output_neuron, weight, recurrent, o)
	local o = o or {}
	setmetatable(o, self)

	o._input = input_neuron
	o._output = output_neuron
	o._weight = weight
	o._recurrent = recurrent

	return o
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Neuron
local _Neuron_Gene = {}

function _Neuron_Gene:new(type, recurrent, activation_response, innovation_id, x, y, o)
	local o = o or {}
	setmetatable(o, self)

	o._type = type
	o._recurrent = recurrent
	o._activation_response = activation_response
	o._innovation_id = innovation_id
	o._x = x
	o._y = y

	return o
end

function _Neuron_Gene:mutate(mutate_chance, mutate_percentage)
	self._activation_response = self._activation_response * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
end

function _Neuron_Gene:inherit(mutate_chance, mutate_percentage)
	return qpd_table.clone(self):mutate(mutate_chance, mutate_percentage)
end

function _Neuron_Gene:is_link_recurrent(other)
	if self._x > other._x then
		return true
	end
	if self._x == other._x then
		if self._y > other._y then
			return true
		end
	end

	return false
end

function _Neuron_Gene:get_id()
	return self._innovation_id
end

function _Neuron_Gene:type()
	return "_Neuron_Gene"
end

-------------------------------------------------------------------------------
local _Neuron = {}

function _Neuron:new(type, innovation_id, input_links, output_links, activatation_function, activation_response, activation_parameters, o)
	local o = o or {}
	setmetatable(o, self)

	o._input_links = input_links or {}
	o._output_links = output_links or {}

	o._innovation_id = innovation_id

	o._type = type

	o._activation_response = activation_response
	o._activation_function = activatation_function
	o._activation_parameters = activation_parameters

	o._inputs = {}
	for i = 1, #o._input_links do
		o._inputs[i] = 0
	end
	o._activation_sum = 0
	o._activation_output = 0

	return o
end

function _Neuron:add_input_link(link)
	table.insert(self._input_links, link)
	table.insert(self._inputs, 0)
end

function _Neuron:add_output_link(link)
	table.insert(self._output_links, link)
end

function _Neuron:update(input)
	if input then
		self._activation_sum = input
		self._activation_output = self._activation_function(self._activation_sum, self._activation_response, self._activation_parameters)
	else
		self._activation_sum = 0
		for i = 1, #self._input_links do
			local this_link = self._input_links[i]
			self._activation_sum = self._activation_sum + this_link._weight * this_link._activation_output
			self._activation_output = self._activation_function(self._activation_sum, self._activation_response, self._activation_parameters)
		end
	end
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Innovation Manager
local _Innovation_manager = {}

function _Innovation_manager:new(o)
	local o = o or {}
	setmetatable(o, self)

	o._id_count = 0
	o._links = {}
	o._neurons = {}
	o._innovations = {}

	return o
end

function _Innovation_manager:get_innovation(innovation_id)
	return self._innovations[innovation_id]
end

function _Innovation_manager:_new_link(from_neuron, to_neuron)
	self._id_count = self._id_count + 1

	local new_link = _Link_Gene:new(from_neuron, to_neuron, 0, false, self._id_count)
	self._innovations[self._id_count] = new_link
	return new_link
end

function _Innovation_manager:get_link_innovation_id(from_neuron, to_neuron)
	local innovation_id
	if self._links[from_neuron] then
		if self._links[from_neuron][to_neuron] then
			innovation_id = self._links[from_neuron][to_neuron]
		end
	else
		self._links[from_neuron] = {}
	end

	if not innovation_id then
		local new_link = self:_new_link(from_neuron, to_neuron)
		innovation_id = new_link:get_id()
		self._links[from_neuron][to_neuron] = innovation_id
	end

	return innovation_id
end

-- assign singleton instance
Innovation_manager = _Innovation_manager:new()

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Species
local _Species = {}

local _species_count = 0

function _Species:new(leader, o)
	local o = o or {}
	setmetatable(o, self)

	o._leader = leader
	o._specimes = {}
	_species_count = _species_count + 1
	o._id = _species_count
	o._best_fitness = o._leader:get_fitness()
	o._av_fitness = o._best_fitness
	o._generations_with_no_fitness_improvement = 0
	o._age = 0
	o._required_spawns = 0

	return o
end

function _Species:adjusted_fitnesses()
end

function _Species:add_member(new_genome)
end

function _Species:purge()
end

function _Species:calculate_spawn_amount()
	-- calculates how many offspring this species should spawn
end

function _Species:spawn()
	-- spawns an individual from the species selected at random
	-- from the best CParams::dSurvivalRate percent
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Genome
local _Genome = {}

local _genome_count = 0

local function _innovation_sorter(a, b)
	return a._innovation_id < b._innovation_id
end

function _Genome:new(n_inputs, n_outputs, neurons, links, o)
	local o = o or {}
	setmetatable(o, self)

	_genome_count = _genome_count + 1
	o._id = _genome_count

	o:sort_genes()

	o._n_inputs = n_inputs
	o._n_outputs = n_outputs

	o._layers = _Genome:get_layers()

	-- o._amount_to_spawn = 0
	return o
end

function _Genome:get_layers()
	local unique_layer_dict = {}
	for i = 1, #self._neurons do
		local this_layer = self._neurons[i]
		if not unique_layer_dict[this_layer] then
			unique_layer_dict[this_layer] = true
		end
	end

	-- find and sort layers
	local unique_layers = {}
	for layer, _ in pairs(unique_layer_dict) do
		unique_layers[#unique_layers + 1] = layer
	end

	table.sort(unique_layers)

	return unique_layers
end

function _Genome:crossover(dad, mutate_chance, mutate_percentage, chance_add_neuron, chance_add_link, chance_loopback)
	-- mom is always fitter or shorter
	local mom = self

	local neurons = {}
	-- neurons
	local mom_index = 1
	local dad_index = 1

	while (mom_index <= #mom._neurons) do
		local mom_neuron_gene = mom._neurons[mom_index]
		local dad_neuron_gene = dad._neurons[dad_index]

		if mom_neuron_gene._innovation_id == dad_neuron_gene._innovation_id then
			local new_neuron = qpd_random.choose(mom_neuron_gene, dad_neuron_gene):inherit(mutate_chance, mutate_percentage)
			table.insert(neurons, new_neuron)
			mom_index = mom_index + 1
			dad_index = dad_index + 1
		elseif mom_neuron_gene._innovation_id < dad_neuron_gene._innovation_id then
			local new_neuron = mom_neuron_gene:inherit(mutate_chance, mutate_percentage)
			table.insert(neurons, new_neuron)
			mom_index = mom_index + 1
		else
			dad_index = dad_index + 1
		end
	end

	local links = {}
	while (mom_index <= #mom._links) do
		local mom_link_gene = mom._links[mom_index]
		local dad_link_gene = dad._links[dad_index]

		if mom_link_gene._innovation_id == dad_link_gene._innovation_id then
			local new_link = qpd_random.choose(mom_link_gene, dad_link_gene):inherit(mutate_chance, mutate_percentage)
			table.insert(links, new_link)
			mom_index = mom_index + 1
			dad_index = dad_index + 1
		elseif mom_link_gene._innovation_id < dad_link_gene._innovation_id then
			local new_link = mom_link_gene:inherit(mutate_chance, mutate_percentage)
			table.insert(links, new_link)
			mom_index = mom_index + 1
		else
			dad_index = dad_index + 1
		end
	end

	local new_genome = _Genome:new(mom._n_inputs, mom._n_outputs, neurons, links)

	if qpd_random.toss(chance_add_neuron) then
		new_genome:add_neuron()
	end
	if qpd_random.toss(chance_add_link) then
		new_genome:add_link(chance_loopback)
	end

	return new_genome
end

function _Genome:gene_count()
	return #self._neurons + #self._links
end

function _Genome:sort_links()
	table.sort(self._links, _innovation_sorter)
end

function _Genome:sort_neurons()
	table.sort(self._neurons, _innovation_sorter)
end

function _Genome:sort_genes()
	self:sort_neurons()
	self:sort_links()
end

function _Genome:add_neuron()

	self:sort_neurons()
end

function _Genome:add_link(chance_loopback)
	local selected_from_neuron
	local selected_to_neuron

	-- check if we should attempt to create a loopback link
	if qpd_random.toss(chance_loopback) then
		-- create loopback
		-- find suitable neuron(no input, no bias and not already looped)
		local tries_count = MAX_LOOPBACK_LINK_TRIES
		while (tries_count > 0) do
			local neuron_index = qpd_random.random(#self._neurons)
			if 	self._neurons[neuron_index]._type ~= "input" and
				self._neurons[neuron_index]._type ~= "bias" and
				self._neurons[neuron_index]._loopback ~= true then
				tries_count = 0
				selected_from_neuron = self._neurons[neuron_index]
				selected_to_neuron = selected_from_neuron
			else
				tries_count = tries_count - 1
			end
		end
	end
	if not selected_from_neuron and not selected_to_neuron then
		-- try to find to unlinked neurons
		local tries_count = MAX_LINK_TRIES
		while (tries_count > 0) do
			local from_neuron_index = qpd_random.random(#self._neurons)
			local to_neuron_index = qpd_random.random(#self._neurons)
			-- the to_neuron can not be an input
			-- they can not be the same
			if 	self._neurons[from_neuron_index]:get_id() ~= self._neurons[to_neuron_index]:get_id() and
				self._neurons[to_neuron_index]._type ~= "input" then
				tries_count = 0
				selected_from_neuron = self._neurons[from_neuron_index]
				selected_to_neuron = self._neurons[from_neuron_index]
			else
				tries_count = tries_count - 1
			end
		end
	end

	if selected_from_neuron and selected_to_neuron then
		-- create link
		-- _Link_Gene:new(from_neuron, to_neuron, weight, enabled, innovation_id, o)

		local new_link = _Link_Gene:new(
			selected_from_neuron._innovation_id,
			selected_to_neuron._innovation_id,
			get_random_link_weight(),
			true,
			Innovation_manager:get_link_innovation_id(selected_from_neuron._innovation_id, selected_to_neuron._innovation_id)
		)
		table.insert(self._links, new_link)
	end

	--
	self:sort_links()
end

function _Genome:get_compatibility_score(other)
end

function _Genome:duplicate_link()
	-- returns true if the specified link is already part of the genome
end

function _Genome:get_element_pos(neuron_id)
	-- given a neuron id this function just finds its position in neurons array
end

function _Genome:already_have_this_neuron_id(id)
	-- tests if the passed ID is the same as any existing neuron IDs. Used in add_neuron()
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- ANN
local ANN = {}

function ANN:new(genome, entry_layer_activation_function_name, hidden_layer_activation_function_name, output_layer_activation_function_name, activation_response, activation_function_parameters, o)
	local o = o or {}
	setmetatable(o, self)

	o._genome = genome

	-- fill in layer_to_layer_position_dict and start layers array.
	o._layers = {}
	local layer_to_layer_position_dict = {}
	for i = 1, #genome._layers do
		local this_layer = genome._layers[i]
		layer_to_layer_position_dict[this_layer] = i

		o._layers[i] = {}
	end

	-- fill in layers
	for i = 1, #genome._neurons do
		local this_neuron_gene = genome._neurons[i]
		local this_layer = layer_to_layer_position_dict[this_neuron_gene._x]

		local activation_function
		if i == 1 then
			activation_function = ann_activation_functions[entry_layer_activation_function_name]
		elseif i == #genome._neurons then
			activation_function = ann_activation_functions[output_layer_activation_function_name]
		else
			activation_function = ann_activation_functions[hidden_layer_activation_function_name]
		end

		local this_neuron = _Neuron:new(
			this_neuron_gene._type,
			this_neuron_gene._innovation_id,
			activation_function,
			this_neuron_gene._activation_response,
			this_neuron_gene._activation_parameters)
		table.insert(o._layers[this_layer], this_neuron)
	end

	-- sort layer and fill neuron_id_to_position
	local neuron_id_to_position = {}
	for i = 1, #genome._layers do
		table.sort(o._layers[i], function (a, b) return a.y < b.y end)

		for j = 1, #self._layers[i] do
			local this_neuron = self._layers[i][j]
			neuron_id_to_position[this_neuron._id] = {x = i, y = j}
		end
	end

	-- create links
	for i = 1, #genome._links do
		local this_link_gene = genome._links[i]
		local input_neuron_position  = neuron_id_to_position[this_link_gene.input]
		local output_neuron_position = neuron_id_to_position[this_link_gene.output]

		local input_neuron = o._layers[input_neuron_position._x][input_neuron_position._y]
		local output_neuron = o._layers[output_neuron_position._x][output_neuron_position._y]

		local this_link = _Link:new(input_neuron, output_neuron, this_link_gene._weight, this_link_gene._recurrent)
		input_neuron:add_output_link(this_link)
		output_neuron:add_input_link(this_link)
	end

	return o
end

function ANN:crossover(mom, dad, mutate_chance, mutate_percentage, _crossover, chance_add_neuron, chance_add_link, chance_loopback)
	return ANN:new(mom._genome:crossover(dad._genome, mutate_chance, mutate_percentage, chance_add_neuron, chance_add_link, chance_loopback))
end

function ANN:gene_count()
	return self._genome:gene_count()
end

function ANN:get_outputs(inputs, run_type)
	-- update input layer
	for i = 1, #self._layers[1] do
		local this_neuron = self._layers[1][i]
		this_neuron:update(inputs[i])
	end

	-- update other layers
	for i = 2, #self._layers do
		for j = 1, #self._layers[i] do
			local this_neuron = self._layers[i][j]
			this_neuron:update()
		end
	end

	-- get outputs
	local outputs = {}
	for i = 1, #self._layers[#self._layers] do
		outputs[i] = self._layers[#self._layers][i]._activation_output
	end

	return outputs
end

return ANN