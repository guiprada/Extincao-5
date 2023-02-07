-- Guilherme Cunha Prada 2022
local GridActor = require "entities.GridActor"
local AutoPlayerAnnModes = require "entities.AutoPlayerAnnModes"

local AutoPlayer = GridActor:new()
AutoPlayer.__index = AutoPlayer

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

fitness_modes.cells_visited = function (self)
	self._fitness = self._visited_count
end

fitness_modes.movement2 = function (self)
	local updates = self:get_update_count()
	if updates > 0 then
		self._fitness = (self:get_grid_cell_changes()/self:get_update_count()) + self:get_visited_count()
	else
		self._fitness = self:get_visited_count()
	end
end

fitness_modes.movement_captures = function (self)
	self._fitness = self:get_visited_count() + 2 * self._pills_caught + self._ghosts_caught
end

-------------------------------------------------------------------------------
function AutoPlayer.init(search_path_length, mutate_chance, mutate_percentage, ann_layers, ann_mode, crossover, autoplayer_ann_backpropagation, autoplayer_fitness_mode, collision_purge, rotate_purge, initial_bias, start_idle, start_on_center)
	AutoPlayer._search_path_length = search_path_length

	AutoPlayer._mutate_chance = mutate_chance
	AutoPlayer._mutate_percentage = mutate_percentage
	AutoPlayer._ann_layers = ann_layers and qpd.table.read_from_string(ann_layers) or false
	-- for _, line in pairs(AutoPlayer._ann_layers) do
	-- 	for _, value in pairs(line) do
	-- 		print(value)
	-- 	end
	-- end
	AutoPlayer._ann_mode = ann_mode
	AutoPlayer._crossover = crossover
	AutoPlayer._autoplayer_ann_backpropagation = autoplayer_ann_backpropagation
	AutoPlayer._autoplayer_fitness_mode = autoplayer_fitness_mode
	AutoPlayer._collision_purge = collision_purge or false
	AutoPlayer._rotate_purge = rotate_purge or false
	AutoPlayer._initial_bias = initial_bias
	AutoPlayer._start_idle = start_idle or false
	AutoPlayer._start_on_center = start_on_center or false

	GridActor.register_type(autoplayer_type_name)
end

function AutoPlayer:new(o)
	local o = GridActor:new(o or {})
	setmetatable(o, self)

	o._type = GridActor.get_type_by_name(autoplayer_type_name)
	self._target_grid = {}
	self._home_grid = {}

	return o
end

function AutoPlayer:reset(reset_table)
	local cell, ann
	if reset_table then
		cell = reset_table.cell
		ann = reset_table.ann
	end

	cell = cell or AutoPlayer._grid:get_valid_cell()

	if self._ann_layers then
		self._ann = ann or qpd.ann:new(self._ann_layers, self._initial_bias)
	end

	-- telemetry
	self._fitness = 0
	self._visited_count = 0
	self._visited_grid = {}
	self._grid_cell_changes = 0
	self._pill_update_count = 0
	self._collision_count = 0
	self._ghosts_caught = 0
	self._pills_caught = 0

	cell = AutoPlayer._start_on_center and {x = 14, y = 6} or cell
	if self._start_idle then
		cell = cell or AutoPlayer._grid:get_valid_cell()
		GridActor.reset(self, cell)

		self._direction = "idle"
		self._orientation = "up"

		-- self._home_grid.x = cell.x
		-- self._home_grid.y = cell.y

		-- self._target_grid.x = cell.x
		-- self._target_grid.y = cell.y
	else
		cell = cell or AutoPlayer._grid:get_valid_cell()
		GridActor.reset(self, cell)

		-- local target_grid = AutoPlayer_NEAT._grid:get_valid_cell()
		-- self._home_grid.x = target_grid.x
		-- self._home_grid.y = target_grid.y

		-- self._target_grid.x = target_grid.x
		-- self._target_grid.y = target_grid.y

		self._direction = self:get_random_valid_direction()
		self._orientation = self._direction
	end

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

function AutoPlayer:crossover(mom, dad)
	local new_ann
	if AutoPlayer._ann_layers then
		new_ann = qpd.ann:crossover(mom._ann, dad._ann, self._mutate_chance, self._mutate_percentage, self._crossover)
		-- reset
	end
	self:reset({ann = new_ann})
end

function AutoPlayer:draw()
	--AutoPlayer body :)
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

local function collision_purge(actor)
	actor._idle_count = actor._idle_count or 0

	if actor._direction == "idle" then
		actor._idle_count = actor._idle_count + 1
		if actor._idle_count > 5 then
			actor._is_active = false
			actor:log("destroyed", "collision purged")
			return
		end
	else
		actor._idle_count = 0
	end
end

local function rotate_purge(actor)
	actor._rotate_count = actor._rotate_count or 0

	-- if actor._direction ~= actor._next_direction then
	if actor._orientation ~= actor._last_orientation then
		actor._rotate_count = actor._rotate_count + 1
		if actor._rotate_count > 12 then
			actor._is_active = false
			actor:log("destroyed", "rotate purged")
			return
		end
	else
		actor._rotate_count = 0
	end
	actor._last_orientation = actor._orientation
end

function AutoPlayer:update(dt, speed, ghost_state, ...)
	if (self._is_active) then
		AutoPlayerAnnModes.update[AutoPlayer._ann_mode](self, AutoPlayer._grid, AutoPlayer._search_path_length, ghost_state, ...)
		GridActor.update(self, dt, speed)

		-- purges
		if self._collision_purge then
			collision_purge(self)
		end
		if self._rotate_purge then
			rotate_purge(self)
		end

		-- telemetry updates
		self:update_collision_count()
		self:update_visited_count()
		self:update_grid_cell_changes()
		self:update_pill_update_count(ghost_state)

		-- fitness reward
		fitness_modes[AutoPlayer._autoplayer_fitness_mode](self)
	end
end

function AutoPlayer:update_collision_count()
	if self._has_collided then
		self._collision_count = self._collision_count + 1
	end
end

function AutoPlayer:update_visited_count()
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

function AutoPlayer:update_grid_cell_changes()
	if self._changed_grid_cell then
		self._grid_cell_changes = self._grid_cell_changes + 1
	end
end

function AutoPlayer:update_pill_update_count(ghost_state)
	if ghost_state == "frightened" then
		self._pill_update_count = self._pill_update_count + 1
	end
end

function AutoPlayer:got_ghost()
	self._ghosts_caught = self._ghosts_caught + 1
end

function AutoPlayer:got_pill()
	self._pills_caught = self._pills_caught + 1
end

function AutoPlayer:get_ann()
	return self._ann or false
end

function AutoPlayer:get_fitness()
	return self._fitness
end

function AutoPlayer:get_grid_cell_changes()
	return self._grid_cell_changes
end

function AutoPlayer:get_visited_count()
	return self._visited_count
end

function AutoPlayer:get_pill_update_count()
	return self._pill_update_count
end

function AutoPlayer:get_no_pill_update_count()
	return self:get_update_count() - self:get_pill_update_count()
end

function AutoPlayer:get_collision_count()
	return self._collision_count
end

function AutoPlayer:get_genes()
	local ann = self:get_ann()
	if ann then
		return ann:to_string()
	else
		return "false"
	end
end

function AutoPlayer:get_history()
	return {_fitness = self:get_fitness(), _ann = self:get_ann()}
end

return AutoPlayer
