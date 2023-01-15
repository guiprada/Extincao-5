-- Guilherme Cunha Prada 2022
local GridActor = require "entities.GridActor"
local AutoPlayerAnnModes = require "entities.AutoPlayerAnnModes"

local AutoPlayer_NEAT = GridActor:new()
AutoPlayer_NEAT.__index = AutoPlayer_NEAT

local qpd = require "qpd.qpd"

local autoplayer_type_name = "player"

-------------------------------------------------------------------------------
local fitness_modes = {}
fitness_modes.movement = function (self)
	self._fitness = self:get_grid_cell_changes() * self:get_visited_count()
end

fitness_modes.updates = function (self)
	self._fitness = self:get_update_count()
end

fitness_modes.no_pill_updates = function (self)
	self._fitness = self:get_no_pill_update_count()
end

-------------------------------------------------------------------------------
function AutoPlayer_NEAT.init(search_path_length, mutate_chance, mutate_percentage, add_neuron_chance, add_link_chance, loopback_chance, ann_layers, ann_mode, crossover, fitness_mode, autoplayer_neat_speciate, initial_links, fully_connected)
	--AutoPlayer.init(search_path_length, mutate_chance, mutate_percentage, ann_layers, ann_mode, crossover, autoplayer_ann_backpropagation, autoplayer_fitness_mode, collision_purge, rotate_purge, initial_bias)
	AutoPlayer_NEAT._search_path_length = search_path_length

	AutoPlayer_NEAT._mutate_chance = mutate_chance
	AutoPlayer_NEAT._mutate_percentage = mutate_percentage
	AutoPlayer_NEAT._add_neuron_chance = add_neuron_chance
	AutoPlayer_NEAT._add_link_chance = add_link_chance
	AutoPlayer_NEAT._loopback_chance = loopback_chance
	AutoPlayer_NEAT._ann_layers = ann_layers and qpd.table.read_from_string(ann_layers) or false
	AutoPlayer_NEAT._ann_mode = ann_mode
	AutoPlayer_NEAT._crossover = crossover
	AutoPlayer_NEAT._autoplayer_fitness_mode = fitness_mode
	AutoPlayer_NEAT._speciatable = autoplayer_neat_speciate or false
	AutoPlayer_NEAT._initial_links = initial_links or false
	AutoPlayer_NEAT._fully_connected = fully_connected or false

	GridActor.register_type(autoplayer_type_name)
end

function AutoPlayer_NEAT:new(o)
	local o = GridActor:new(o or {})
	setmetatable(o, self)

	o._type = GridActor.get_type_by_name(autoplayer_type_name)
	self._target_grid = {}
	self._home_grid = {}

	return o
end

function AutoPlayer_NEAT:reset(reset_table)
	local ann, cell
	if reset_table then
		cell = reset_table.cell
		ann = reset_table.ann
	end

	cell = cell or AutoPlayer_NEAT._grid:get_valid_cell()

	if ann then
		self._ann = ann
	else
		self._ann = qpd.ann_neat:new_genome(
			AutoPlayer_NEAT._ann_layers[1].count,
			AutoPlayer_NEAT._ann_layers[1].activation_function_name,
			AutoPlayer_NEAT._ann_layers[1].activation_function_parameters,
			AutoPlayer_NEAT._ann_layers[3].count,
			AutoPlayer_NEAT._ann_layers[3].activation_function_name,
			AutoPlayer_NEAT._ann_layers[3].activation_function_parameters,
			AutoPlayer_NEAT._initial_links,
			AutoPlayer_NEAT._fully_connected,
			AutoPlayer_NEAT._ann_layers[2].activation_function_name,
			AutoPlayer_NEAT._ann_layers[2].activation_function_parameters
		)
	end

	-- telemetry
	self._fitness = 0
	self._visited_count = 0
	self._visited_grid = {}
	self._grid_cell_changes = 0
	self._pill_update_count = 0
	self._collision_count = 0

	GridActor.reset(self, cell)

	local target_grid = AutoPlayer_NEAT._grid:get_valid_cell()
	self._home_grid.x = target_grid.x
	self._home_grid.y = target_grid.y

	self._target_grid.x = target_grid.x
	self._target_grid.y = target_grid.y

	self._direction = self:get_random_valid_direction()
	self._orientation = self._direction

	if not self._max_cell then
		self._max_cell = {}
	end
	if not self._min_cell then
		self._min_cell = {}
	end
	self._min_cell.x = self._cell.x
	self._max_cell.x = self._cell.x
	self._min_cell.y = self._cell.y
	self._max_cell.y = self._cell.y
end

function AutoPlayer_NEAT:crossover(mom, dad)
	local new_ann = qpd.ann_neat:crossover(mom, dad, self._mutate_chance, self._mutate_percentage, AutoPlayer_NEAT._add_neuron_chance, AutoPlayer_NEAT._add_link_chance, AutoPlayer_NEAT._loopback_chance, self._crossover)
	-- reset
	self:reset({ann = new_ann})
end

function AutoPlayer_NEAT:draw()
	--AutoPlayer_NEAT body :)
	if (self._is_active) then
		love.graphics.setColor(0.9, 0.9, 0.9)

		love.graphics.circle("fill", self.x, self.y, self._tilesize*0.55)

		-- front dot
		love.graphics.setColor(1, 0, 1)
		--love.graphics.setColor(138/255,43/255,226/255, 0.9)
		love.graphics.circle("fill", self._front.x,	self._front.y, self._tilesize/5)
		-- front line, mesma cor
		-- love.graphics.setColor(1, 0, 1)
		love.graphics.line(self.x, self.y, self._front.x, self._front.y)

		-- orientation based "eyes"
		love.graphics.setColor(0.3, 0.2, 0.2)
		local eye_drift = self._tilesize * 0.3
		if self._orientation == "up" then
			love.graphics.circle("fill", self.x, self.y - eye_drift, self._tilesize*0.1)
		elseif self._orientation == "down" then
			love.graphics.circle("fill", self.x, self.y + eye_drift, self._tilesize*0.1)
		elseif self._orientation == "left" then
			love.graphics.circle("fill", self.x - eye_drift, self.y, self._tilesize*0.1)
		elseif self._orientation == "right" then
			love.graphics.circle("fill", self.x + eye_drift, self.y, self._tilesize*0.1)
		end

		-- reset color
		love.graphics.setColor(1,1,1)
	end
end

function AutoPlayer_NEAT:update(dt, speed, ghost_state, ...)
	if (self._is_active) then
		AutoPlayerAnnModes.update[AutoPlayer_NEAT._ann_mode](self, AutoPlayer_NEAT._grid, AutoPlayer_NEAT._search_path_length, ghost_state, ...)


		GridActor.update(self, dt, speed)

		-- telemetry updates
		self:update_collision_count()
		self:update_visited_count()
		self:update_grid_cell_changes()
		self:update_pill_update_count(ghost_state)

		-- fitness reward
		fitness_modes[AutoPlayer_NEAT._autoplayer_fitness_mode](self)
	end
end

function AutoPlayer_NEAT:update_collision_count()
	if self._has_collided then
		self._collision_count = self._collision_count + 1
	end
end

function AutoPlayer_NEAT:update_visited_count()
	if self._visited_grid[self._cell.x] then
		if self._visited_grid[self._cell.x][self._cell.y] then
			return
		else
			self._visited_grid[self._cell.x][self._cell.y] = true
		end
	else
		self._visited_grid[self._cell.x] = {}
		self._visited_grid[self._cell.x][self._cell.y] = true
	end
	self._visited_count = self._visited_count + 1
	return
end

function AutoPlayer_NEAT:update_grid_cell_changes()
	if self._changed_grid_cell then
		self._grid_cell_changes = self._grid_cell_changes + 1
	end
end

function AutoPlayer_NEAT:update_pill_update_count(ghost_state)
	if ghost_state == "frightened" then
		self._pill_update_count = self._pill_update_count + 1
	end
end

function AutoPlayer_NEAT:got_ghost()
end

function AutoPlayer_NEAT:got_pill()
end

function AutoPlayer_NEAT:get_ann()
	return self._ann or false
end

function AutoPlayer_NEAT:get_fitness()
	return self._fitness
end

function AutoPlayer_NEAT:get_grid_cell_changes()
	return self._grid_cell_changes
end

function AutoPlayer_NEAT:get_visited_count()
	return self._visited_count
end

function AutoPlayer_NEAT:get_pill_update_count()
	return self._pill_update_count
end

function AutoPlayer_NEAT:get_no_pill_update_count()
	return self:get_update_count() - self:get_pill_update_count()
end

function AutoPlayer_NEAT:get_collision_count()
	return self._collision_count
end

function AutoPlayer_NEAT:get_genes()
	local ann = self:get_ann()
	if ann then
		return ann:to_string()
	else
		return "false"
	end
end

function AutoPlayer_NEAT:get_history()
	local ann = self:get_ann()
	if ann then
		local specie = ann._specie
		local genome = ann:get_genome()
		return {_fitness = self:get_fitness(), _genome = genome, _specie_id = specie:get_id()}
	else
		print("ERROR - AutoPlayer_NEAT - Invalid ANN!")
		qpd.gamestate.switch("menu")
	end
end

-- function AutoPlayer_NEAT:type()
-- 	return "AutoPlayer_NEAT"
-- end

return AutoPlayer_NEAT
