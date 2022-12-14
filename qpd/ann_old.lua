-- Guilherme Cunha Prada 2022
local NN = {}
NN.__index = NN

local qpd_table = require "qpd.table"
local qpd_random = require "qpd.random"

-- Internal Classes
local _Neuron = {}
local _NeuronLayer = {}

function _Neuron:new(inputs, bias, o)
	-- if inputs is a number, it is used as n_inputs as the neuron is initialized with random values
	-- if inputs is a table, is is used as init values for the neuron
	local o = o or {}

	local this_type = type(inputs)
	local n_inputs
	if this_type == "table" then
		for key, value in ipairs(inputs) do
			o[key] = value
		end
		n_inputs = #inputs
	elseif this_type == "number" then
		for i = 1, inputs, 1 do
			o[i] = qpd_random.random() * qpd_random.choose(1, -1)
		end
		n_inputs = inputs
	else
		print("[ERROR] - _Neuron:new() - Could not initialize Neuron with type:", this_type)
		return nil
	end

	o.bias = bias or qpd_random.random() * qpd_random.choose(1, -1)

	o.value = nil

	setmetatable(o, self)
	self.__index = self
	return o
end

function _Neuron:to_string()
	local str = "("
	for i = 1, #self do
		str = string.format("%s %s", str, self[i])
	end
	str = string.format("%s)", str)
	return str
end

function _Neuron:update(inputs, float_output)
	local this_type = type(inputs)

	if this_type == "table" then
		local sum = 0
		for i = 1, #self do
			local weight = self[i]
			local input = inputs[i].value
			sum = sum + weight * input
		end

		if not float_output then
			if sum > self.bias then
				self.value = 1
			else
				self.value = 0
			end
		else
			self.value = sum + self.bias
		end
	elseif this_type == "number" then
		local input = self[1] * inputs
		if input > self.bias then
			self.value = 1
		else
			self.value = 0
		end
	else
		print("[ERROR] - _Neuron:update() - Received a bogus input:", inputs)
	end
end

function _NeuronLayer:new(neurons, inputs, bias, o)
	-- if neurons is a number, it is used as n_neurons as the layer is initialized with random neurons
	-- if neurons is a table, is is used as init values for neurons
	local o = o or {}

	local this_type = type(neurons)
	if this_type == "table" then
		for key, value in ipairs(neurons) do
			o[key] = value
		end
	elseif this_type == "number" then
		for i = 1, neurons, 1 do
			o[i] = _Neuron:new(inputs, bias)
		end
	else
		print("[ERROR] - _NeuronLayer:new() - Could not initialize NeuronLayer with type:", this_type)
		return nil
	end

	setmetatable(o, self)
	self.__index = self
	return o
end

function _NeuronLayer:to_string()
	local str = "["
	for i = 1, #self do
		str = string.format("%s %s", str, self[i]:to_string())
	end
	str = string.format("%s]", str)
	return str
end

function _NeuronLayer:update(inputs, float_output)
	for i = 1, #self do
		local neuron = self[i]
		neuron:update(inputs, float_output)
	end
end

function _NeuronLayer:update_entry_layer(inputs)
	for i = 1, #self do
		local neuron = self[i]
		local input = inputs[i]
		neuron:update(input)
	end
end

-- NN Class
function NN:new(inputs, outputs, hidden_layers, neurons_per_hidden_layer, o)
	local o = o or {}
	setmetatable(o, self)

	o[1] = _NeuronLayer:new(inputs, 1)
	local last_layer_count = inputs
	for i = 2, hidden_layers + 1 do
		o[i] = _NeuronLayer:new(neurons_per_hidden_layer, last_layer_count)
		last_layer_count = neurons_per_hidden_layer
	end
	local output_layer_index = #o + 1
	o[output_layer_index] = _NeuronLayer:new(outputs, last_layer_count)

	return o
end

-- layers = {
-- 	{
-- 		count = 5,
-- 		activation = "identity",
-- 	},
-- 	{
-- 		count = 3,
-- 		activation = "sigmoid",
--		extra = {p}
-- 	},
-- }

function NN:new_from_layers(layers, bias, o)
	local o = o or {}
	setmetatable(o, self)

	local last_layer_count = 1
	for i, layer in ipairs(layers) do
		_NeuronLayer:new(neurons, inputs, bias, o)
		o[i] = _NeuronLayer:new(layer.count, last_layer_count, layer.activation, layer.extra)
		last_layer_count = layer.count
	end

	return o
end

function NN:crossover(mom, dad, mutate_chance, mutate_percentage)
	local son = {}
	setmetatable(son, self)

	for i = 1, #mom do
		local layer = qpd_table.clone(mom[i])
		local new_layer = {}
		local crossover_layer = qpd_random.random(1, #layer)
		local crossover_neuron = qpd_random.random(1, #layer[1])
		for j = 1, #layer do
			local inputs = {}
			for k = 1, #layer[j] do

				if j >= crossover_layer and k >= crossover_neuron then
					inputs[k] = qpd_random.choose(mom[i][j][k], dad[i][j][k]) * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
					-- inputs[k] = qpd_random.choose(mom[i][j][k], dad[i][j][k], (mom[i][j][k] + dad[i][j][k]) /2) * (qpd_random.toss(mutate_chance) and qpd_random.choose(-mutate_percentage, mutate_percentage) or 1)
				else
					inputs[k] = mom[i][j][k] * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
				end
			end

			local bias
			if j >= crossover_layer then
				bias = qpd_random.choose(mom[i][j].bias, dad[i][j].bias) * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1)  or 1)
				-- bias = qpd_random.choose(mom[i][j].bias, dad[i][j].bias, (mom[i][j].bias + dad[i][j].bias) /2) * (qpd_random.toss(mutate_chance) and qpd_random.choose(-mutate_percentage, mutate_percentage) or 1)
			else
				bias = mom[i][j].bias * (qpd_random.toss(mutate_chance) and (qpd_random.choose(-mutate_percentage, mutate_percentage) + 1) or 1)
			end

			new_layer[j] = _Neuron:new(inputs, bias)
		end

		son[i] = _NeuronLayer:new(new_layer)
	end

	return son
end

function NN:to_string()
	local str = "{"
	for i = 1, #self do
		str = string.format("%s %s", str, self[i]:to_string())
	end
	str = string.format("%s}", str)
	return str
end

function NN:get_outputs(inputs, float_output)
	self[1]:update_entry_layer(inputs)
	local last_layer = self[1]

	for i = 2, #self - 1 do
		local neuron_layer = self[i]
		neuron_layer:update(last_layer)
		last_layer = neuron_layer
	end

	--output layer
	self[#self]:update(last_layer, float_output or false)

	local output_layer_index = #self
	return self[output_layer_index]
end

return NN