-- Guilherme Cunha Prada 2022
local ANN = {}
ANN.__index = ANN

local qpd_table = require "qpd.table"
local qpd_random = require "qpd.random"
local ann_activation_functions = require "qpd.ann_activation_functions"

local MAX_LOOPBACK_LINK_TRIES = 5
local MAX_LINK_TRIES = 10
local MAX_NEURON_TRIES = 5

local Innovation_manager -- create singleton instance, will be initialized after _Innovation_manager implementation

local _genome_count = 0
local _species_count = 0

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
local function _get_random_link_weight()
	return qpd_random.random()
end

local function _get_random_activation_response(input_count)
	input_count = input_count or 1
	return qpd_random.random() * input_count
end

local function _innovation_sorter(a, b)
	return a._innovation_id < b._innovation_id
end

-- Internal Classes
-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Link
local _Link_Gene = {}

function _Link_Gene:new(input_neuron, output_neuron, weight, innovation_id, o)
	local o = o or {}
	setmetatable(o, self)

	o._input_neuron = input_neuron
	o._output_neuron = output_neuron
	o._weight = weight
	o._enabled = true
	o._innovation_id = innovation_id


	o._recurrent = false
	local input_neuron = Innovation_manager:get_innovation(input_neuron)
	local output_neuron = Innovation_manager:get_innovation(output_neuron)

	o._recurrent = input_neuron:is_link_recurrent(output_neuron)

	return o
end

function _Link_Gene:mutate(mutate_chance, mutate_percentage)
	self._weight = self._weight * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
end

function _Link_Gene:inherit(mutate_chance, mutate_percentage)
	return qpd_table.clone(self):mutate(mutate_chance, mutate_percentage)
end

function _Link_Gene:get_weight()
	return self._weight
end

function _Link_Gene:is_enabled()
	return self._enabled
end

function _Link_Gene:set_enabled(value)
	self._enabled = value or true
end

function _Link_Gene:get_input_x()
	return self._input_neuron:get_x()
end

function _Link_Gene:get_input_y()
	return self._input_neuron:get_y()
end

function _Link_Gene:get_output_x()
	return self._output_neuron:get_x()
end

function _Link_Gene:get_output_y()
	return self._output_neuron:get_y()
end

function _Link_Gene:get_id()
	return self._innovation_id
end

function _Link_Gene:is_recurrent()
	return self._recurrent
end

function _Link_Gene:type()
	return "_Link_Gene"
end

-------------------------------------------------------------------------------
local _Link = {}

function _Link:new(input_neuron, output_neuron, weight, recurrent, o)
	local o = o or {}
	setmetatable(o, self)

	o._input_neuron = input_neuron
	o._output_neuron = output_neuron
	o._weight = weight
	o._recurrent = recurrent

	return o
end

function _Link:new_from_gene(link_gene, layers, neuron_id_to_position)
	local input_neuron_position  = neuron_id_to_position[link_gene.input]
	local output_neuron_position = neuron_id_to_position[link_gene.output]

	local input_neuron = layers[input_neuron_position:get_x()][input_neuron_position:get_y()]
	local output_neuron = layers[output_neuron_position:get_y()][output_neuron_position:get_y()]

	return _Link:new(input_neuron, output_neuron, link_gene:get_weight(), link_gene:is_recurrent())
end

function _Link:get_input_neuron()
	return self._input_neuron
end

function _Link:get_output_neuron()
	return self._output_neuron
end

function _Link:get_output()
	return self._weight * self:get_input_neuron():get_output()
end

function _Link:type()
	return "_Link"
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Neuron
local _Neuron_Gene = {}

function _Neuron_Gene:new(type, recurrent, activation_response, activation_function, activation_function_parameters, innovation_id, x, y, o)
	local o = o or {}
	setmetatable(o, self)

	o._type = type
	o._recurrent = recurrent
	o._activation_response = activation_response
	o._activation_function = activation_function
	o._activation_function_parameters = activation_function_parameters
	o._innovation_id = innovation_id
	o._x = x
	o._y = y

	return o
end

function _Neuron_Gene:mutate(mutate_chance, mutate_percentage)
	self:set_activation_response(self:get_activation_response() * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1))
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

function _Neuron_Gene:get_activation_response()
	return self._activation_response
end

function _Neuron_Gene:set_activation_response(value)
	self._activation_response = value
end

function _Neuron_Gene:get_activation_function()
	return self._activation_function
end

function _Neuron_Gene:get_activation_function_parameters()
	return self._activation_function_parameters
end

function _Neuron_Gene:get_x()
	return self._x
end

function _Neuron_Gene:get_y()
	return self._y
end

function _Neuron_Gene:set_loopback(value)
	self._loopback = value or true
end

function _Neuron_Gene:is_loopback()
	return self._loopback
end

function _Neuron_Gene:get_id()
	return self._innovation_id
end

function _Neuron_Gene:get_neuron_type()
	return self._type
end

function _Neuron_Gene:type()
	return "_Neuron_Gene"
end

-------------------------------------------------------------------------------
local _Neuron = {}

function _Neuron:new(type, innovation_id, input_links, output_links, activation_response, activatation_function, activation_function_parameters, o)
	local o = o or {}
	setmetatable(o, self)

	o._input_links = input_links or {}
	o._output_links = output_links or {}

	o._innovation_id = innovation_id

	o._type = type

	o._activation_response = activation_response
	o._activation_function = activatation_function
	o._activation_function_parameters = activation_function_parameters

	o._inputs = {}
	for i = 1, #o._input_links do
		o._inputs[i] = 0
	end
	o._activation_sum = 0
	o._activation_output = 0

	return o
end

function _Neuron:new_from_gene(neuron_gene)
	return _Neuron:new(
		neuron_gene:get_neuron_type(),
		neuron_gene:get_id(),
		nil,
		nil,
		neuron_gene:get_activation_response(),
		neuron_gene:get_activation_function(),
		neuron_gene:get_activation_function_parameters())
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
		self._activation_output = self:get_activation_function()(self:get_activation_sum(), self:get_activation_response(), self:get_activation_function_parameters())
	else
		self._activation_sum = 0
		for i = 1, #self._input_links do
			local this_link = self._input_links[i]
			self._activation_sum = self._activation_sum + this_link:get_output()
		end
		self._activation_output = self:get_activation_function()(self:get_activation_sum(), self:get_activation_response(), self:get_activation_function_parameters())
	end
end

function _Neuron:get_activation_response()
	return self._activation_response
end

function _Neuron:get_activation_function()
	return self._activation_function
end

function _Neuron:get_activation_function_parameters()
	return self._activation_function_parameters
end

function _Neuron:get_activation_sum()
	return self._activation_sum
end

function _Neuron:get_output()
	return self._activation_output
end

function _Neuron:get_x()
	return self._x
end

function _Neuron:get_y()
	return self._y
end

function _Neuron:get_neuron_type()
	return self._type
end

function _Neuron:type()
	return "_Neuron"
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

function _Innovation_manager:_new_link(input_neuron, output_neuron)
	self._id_count = self._id_count + 1

	local new_link = _Link_Gene:new(input_neuron, output_neuron, 0, false, self._id_count)
	self._innovations[self._id_count] = new_link
	return new_link
end

function _Innovation_manager:get_link_innovation_id(input_neuron, output_neuron)
	local innovation_id
	if self._links[input_neuron] then
		if self._links[input_neuron][output_neuron] then
			innovation_id = self._links[input_neuron][output_neuron]
		end
	else
		self._links[input_neuron] = {}
	end

	if not innovation_id then
		local new_link = self:_new_link(input_neuron, output_neuron)
		innovation_id = new_link:get_id()
		self._links[input_neuron][output_neuron] = innovation_id
	end

	return innovation_id
end

function _Innovation_manager:type()
	return "_Innovation_manager"
end
-- assign singleton instance
Innovation_manager = _Innovation_manager:new()

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Species
local _Species = {}

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

function _Species:type()
	return "_Species"
end
-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Genome
local _Genome = {}

function _Genome:new(neurons, links, o)
	local o = o or {}
	setmetatable(o, self)

	_genome_count = _genome_count + 1
	o._id = _genome_count

	o._neurons = neurons
	o._links = links
	o:_sort_genes()

	o:_init_n_inputs()
	o:_init_n_outputs()
	o:_init_unique_layers()

	-- o._amount_to_spawn = 0
	return o
end

function _Genome:_init_n_inputs()
	local n_inputs = 0
	for i = 1, #self._neurons do
		local this_neuron = self._neurons[i]
		if this_neuron:get_neuron_type() == "input" then
			n_inputs = n_inputs + 1
		end
	end
	self._n_inputs = n_inputs
end

function _Genome:_init_n_outputs()
	local n_outputs = 0
	for i = 1, #self._neurons do
		local this_neuron = self._neurons[i]
		if this_neuron:get_neuron_type() == "output" then
			n_outputs = n_outputs + 1
		end
	end
	self._n_inputs = n_outputs
end

function _Genome:_init_unique_layers()
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

	self._unique_layers = unique_layers
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

	local new_genome = _Genome:new(neurons, links)

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

function _Genome:get_n_inputs()
	return self._n_inputs
end

function _Genome:get_n_outputs()
	return self._n_outputs
end

function _Genome:get_size()
	return #self._neurons + #self._links
end

function _Genome:_sort_links()
	table.sort(self._links, _innovation_sorter)
end

function _Genome:_sort_neurons()
	table.sort(self._neurons, _innovation_sorter)
end

function _Genome:_sort_genes()
	self:_sort_neurons()
	self:_sort_links()
end

function _Genome:_has_link(link_gene_id)
	for i = 1, #self._links do
		local this_link_gene_id = self._links[i]:get_id()
		if this_link_gene_id == link_gene_id then
			return true
		elseif this_link_gene_id < link_gene_id then -- the links are ordered, so we can do an early exit
			return false
		end
	end
	return false
end

function _Genome:add_link(chance_loopback)
	local selected_input_neuron
	local selected_output_neuron
	local innovation_id

	-- check if we should attempt to create a loopback link
	if qpd_random.toss(chance_loopback) then
		-- create loopback
		-- find suitable neuron(no input, no bias and not already looped)
		local tries = MAX_LOOPBACK_LINK_TRIES
		while (tries > 0) do
			local neuron_index = qpd_random.random(#self._neurons)
			if 	self._neurons[neuron_index]:get_neuron_type() ~= "input" and
				self._neurons[neuron_index]:get_neuron_type() ~= "bias" and
				self._neurons[neuron_index]:is_loopback() then

				innovation_id = Innovation_manager:get_link_innovation_id(self._neurons[neuron_index]:get_id(), self._neurons[neuron_index]:get_id())
				if not self:_has_link(innovation_id) then
					tries = 0
					local selected_neuron = self._neurons[neuron_index]
					selected_neuron:set_loopback(true)
					selected_input_neuron = selected_neuron
					selected_output_neuron = selected_neuron
				end
			else
				tries = tries - 1
			end
		end
	else
		-- try to find to unlinked neurons
		local tries = MAX_LINK_TRIES
		while (tries > 0) do
			local input_neuron_index = qpd_random.random(#self._neurons)
			local output_neuron_index = qpd_random.random(#self._neurons)
			-- the output_neuron can not be an input
			-- they can not be the same
			if 	self._neurons[input_neuron_index]:get_id() ~= self._neurons[output_neuron_index]:get_id() and
				self._neurons[output_neuron_index]:get_neuron_type() ~= "input" then
				innovation_id = Innovation_manager:get_link_innovation_id(self._neurons[input_neuron_index], self._neurons[output_neuron_index])
				if not self:_has_link(innovation_id) then
					tries = 0
					selected_input_neuron = self._neurons[input_neuron_index]
					selected_output_neuron = self._neurons[input_neuron_index]
				end
			else
				tries = tries - 1
			end
		end
	end

	if selected_input_neuron and selected_output_neuron then
		-- create link
		-- _Link_Gene:new(input_neuron, output_neuron, weight, enabled, innovation_id, o)

		local new_link = _Link_Gene:new(
			selected_input_neuron._innovation_id,
			selected_output_neuron._innovation_id,
			_get_random_link_weight(),
			innovation_id
		)
		-- if not self:_has_link(new_link) then
		table.insert(self._links, new_link)
		self:_sort_links()
		-- end
	end
end

function _Genome:add_neuron()
	local chosen_link
	-- if the genome is smaller than threshold we select with a bias towards older links to avoid a chaining effect
	local size_threshold = self:get_n_inputs() + self:get_n_outputs() + 5

	if self:get_size() < size_threshold then
		-- no chaining bias, choose an older link
		local tries = MAX_NEURON_TRIES
		while (tries > 0) do
			local n_links = #self._links
			chosen_link = self._links[qpd_random(1, n_links - 1 - math.floor(n_links))]

			-- link has to be enabled, is not recurrent and does not have a bias input neuron
			local input_neuron = chosen_link:get_input_neuron()
			if 	chosen_link:is_enabled() and
				(not chosen_link:is_recurrent()) and
				input_neuron:get_neuron_type() ~= "bias" then
					tries = 0
			else
				chosen_link = nil
			end
			tries = tries - 1
		end
	else
		local tries = MAX_NEURON_TRIES
		while (tries > 0) do
			local n_links = #self._links
			chosen_link = self._links[qpd_random(1, n_links)]

			-- link has to be enabled, is not recurrent and does not have a bias input neuron
			local input_neuron = chosen_link:get_input_neuron()
			if 	chosen_link:is_enabled() and
				(not chosen_link:is_recurrent()) and
				input_neuron:get_neuron_type() ~= "bias" then
					tries = 0
			else
				chosen_link = nil
			end
			tries = tries - 1
		end
	end

	if chosen_link then
		-- disable link
		-- create new neuron
		-- check innovation_id
		-- create new links

		self:_sort_neurons()
	end
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

function _Genome:type()
	return "_Genome"
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- ANN
local ANN = {}

function ANN:new(genome, entry_layer_activation_function_name, o)
	local o = o or {}
	setmetatable(o, self)

	o._genome = genome

	-- fill in layer_to_layer_position_dict and start layers array.
	o._layers = {}
	local layer_to_layer_position_dict = {}
	for i = 1, #genome._unique_layers do
		local this_layer = genome._unique_layers[i]
		layer_to_layer_position_dict[this_layer] = i

		o._layers[i] = {}
	end

	-- fill in layers
	for i = 1, #genome._neurons do
		local this_neuron_gene = genome._neurons[i]
		local this_layer = layer_to_layer_position_dict[this_neuron_gene._x]
		local this_neuron = _Neuron:new_from_gene(this_neuron_gene)

		table.insert(o._layers[this_layer], this_neuron)
	end

	-- sort layer and fill neuron_id_to_position
	local neuron_id_to_position = {}
	for i = 1, #genome._unique_layers do
		table.sort(o._layers[i], function (a, b) return a.y < b.y end)

		for j = 1, #self._layers[i] do
			local this_neuron = self._layers[i][j]
			neuron_id_to_position[this_neuron._id] = {x = i, y = j}
		end
	end

	-- create links
	for i = 1, #genome._links do
		local this_link_gene = genome._links[i]
		if this_link_gene:is_enabled() then
			local this_link = _Link:new_from_gene(this_link_gene, o._layers, neuron_id_to_position)
			this_link:get_input_neuron():add_output_link(this_link)
			this_link:get_output_neuron():add_input_link(this_link)
		end
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
		outputs[i] = self._layers[#self._layers][i]:get_output()
	end

	return outputs
end

function ANN:type()
	return "ANN_neat"
end

return ANN