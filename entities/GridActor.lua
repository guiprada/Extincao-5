-- Guilherme Cunha Prada 2020
local GridActor = {}
GridActor.__index = GridActor

local qpd = require "qpd.qpd"

local registered_types_list = {
	"generic",
}

local registered_types = {
	[registered_types_list[1]] = 1,
}

function GridActor.init(grid, tilesize, event_logger)
	GridActor._grid = grid
	GridActor._tilesize = tilesize

	GridActor._event_logger = event_logger
	GridActor._current_actor_id = 0
end

function GridActor.set_tilesize(tilesize)
	GridActor._tilesize = tilesize
end

function GridActor.get_tilesize()
	return GridActor._tilesize
end

function GridActor.get_type_by_name(type_name)
	local type = registered_types[type_name]
	if type then
		return type
	else
		print("[ERROR] - GridActor.get_type() - unkwnown type:", type_name)
		return nil
	end
end

function GridActor.register_type(type_name)
	if not registered_types[type_name] then
		table.insert(registered_types_list, type_name)
		registered_types[type_name] = #registered_types_list
	end
end

function GridActor:new(o)
	local o = o or {}
	setmetatable(o, self)

	o._lifetime = 0
	o._cell = {}
	o._enabled_directions = {}
	o._front = {}
	o._last_cell = {}

	o._is_active = false
	o._changed_grid_cell = false
	o._has_collided = false
	o._direction = "idle"
	o._next_direction = "idle"

	o._cell.x = 0
	o._cell.y = 0

	o.x = 0
	o.y = 0

	-- we set it negative so it enters the first on tile change
	o._last_cell.x = -1
	o._last_cell.y = -1

	o._front.x = 0
	o._front.y = 0

	o._relay_x_counter = 0
	o._relay_y_counter = 0
	o._relay_x = 0
	o._relay_y = 0
	o._relay_loop_counter = 3 -- controls how many gameloops it takes to relay

	o._type = GridActor.get_type_by_name("generic")

	return o
end

function GridActor:reset(cell)
	GridActor._current_actor_id = GridActor._current_actor_id + 1
	self._id = GridActor._current_actor_id

	self._lifetime = 0
	self._changed_grid_cell = false
	self._has_collided = false
	self._direction = "idle"
	self._next_direction = "idle"

	self._cell.x = cell.x
	self._cell.y = cell.y

	self._tilesize = GridActor._tilesize
	self.x, self.y = GridActor._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize)

	-- we set it negative so it enters the first on tile change
	self._last_cell.x = -1
	self._last_cell.y = -1

	self._relay_x_counter = 0
	self._relay_y_counter = 0
	self._relay_x = 0
	self._relay_y = 0
	self._relay_loop_counter = 3 -- controls how many gameloops it takes to relay

	self._front.x = self.x
	self._front.y = self.y

	self._is_active = true

	self._update_count = 0

	self:log("created")
end

function GridActor:is_type(type_name)
	if type_name == registered_types_list[self._type] then
		return true
	else
		return false
	end
end

function GridActor:draw()
	if (self._is_active) then
		love.graphics.setColor(1, 1, 0)
		love.graphics.circle("fill", self.x, self.y, self._tilesize*0.55)
	end
end

function GridActor:update(dt, speed)
	if speed*dt > (GridActor._tilesize/4) then
		print("physics sanity check failed, Actor traveled distance > tilesize/4")
	end

	self._lifetime = self._lifetime +  dt

	self._update_count = self._update_count + 1

	if GridActor._tilesize ~= self._tilesize then
		self._tilesize = GridActor._tilesize
		-- here we just center on grid, we should perhaps do it smoother
		self:center_on_cell()
	end

	if (self._is_active) then
		-- apply next_direction
		if self._next_direction ~= "idle" then
			local cell_center_x, cell_center_y = GridActor._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize)

			if  self._next_direction == "up" and self._enabled_directions[1] == true then
				self._direction = self._next_direction
				self._relay_x = self.x - cell_center_x
				self._relay_x_counter = self._relay_loop_counter
			elseif  self._next_direction == "down" and self._enabled_directions[2] == true then
				self._direction = self._next_direction
				self._relay_x = self.x - cell_center_x
				self._relay_x_counter = self._relay_loop_counter
			elseif  self._next_direction == "left" and self._enabled_directions[3] == true then
				self._direction = self._next_direction
				self._relay_y = self.y - cell_center_y
				self._relay_y_counter = self._relay_loop_counter
			elseif  self._next_direction == "right" and self._enabled_directions[4] == true then
				self._direction = self._next_direction
				self._relay_y = self.y - cell_center_y
				self._relay_y_counter = self._relay_loop_counter
			end
		end

		-- check collision with wall
		self._has_collided = false
		if(self:is_front_wall()) then
			self._direction = "idle"
			self._next_direction = "idle"
			self:center_on_cell() -- it stops relayed cornering
			self._has_collided = true
		end

		-- do move :)
		if self._direction ~= "idle" then
			if self._direction == "up" then self.y = self.y - speed * dt
			elseif self._direction == "down" then self.y = self.y + speed * dt
			elseif self._direction == "left" then self.x = self.x - speed * dt
			elseif self._direction == "right" then self.x = self.x + speed * dt
			end
		end

		-- update o info
		self:update_dynamic_front()
		self:update_cell()

		--on change tile
		self._changed_grid_cell = false
		if  self._cell.x ~= self._last_cell.x then
			self._changed_grid_cell = "x"
		end
		if self._cell.y ~= self._last_cell.y then
			if self._changed_grid_cell then
				self._changed_grid_cell = "xy"
			else
				self._changed_grid_cell = "y"
			end
		end

		if self._changed_grid_cell then
			self._enabled_directions = self:get_enabled_directions()
		end

		-- relays mov for cornering
		if self._relay_x_counter >= 1 then
			self.x = self.x - self._relay_x/self._relay_loop_counter
			self._relay_x_counter = self._relay_x_counter -1
			if self._relay_x_counter == 0 then self:center_on_cell_x() end
		end

		if self._relay_y_counter >= 1 then
			self.y = self.y - self._relay_y/self._relay_loop_counter
			self._relay_y_counter = self._relay_y_counter -1
			if self._relay_y_counter == 0 then self:center_on_cell_y() end
		end

		GridActor._grid:update_collision(self)
	end
end

function GridActor:get_random_valid_direction()
	return self._grid:get_random_valid_direction(self._cell.x, self._cell.y)
end

function GridActor:set_random_valid_direction()
	self._next_direction = self._grid:get_random_valid_direction(self._cell.x, self._cell.y)
end

function GridActor:set_different_random_valid_direction()
	self._next_direction = self._grid:get_different_random_valid_direction(self._cell.x, self._cell.y, self._direction)
end

function GridActor:center_on_cell()
	self.x, self.y = GridActor._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize)
end

function GridActor:center_on_cell_x()
	self._relay_x_counter = 0
	self._relay_y_counter = 0
	self.x, _ = GridActor._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize)
end

function GridActor:center_on_cell_y()
	_, self.y = GridActor._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize)
end

function GridActor:update_dynamic_front()
	-- returns the point that is lookahead in front of the player
	-- it does consider the direction obj is set
	local point = {}
	-- the player has a dynamic center
	local lookahead = (self._tilesize/2)
	if self._direction == "up" then
		point.y = self.y - lookahead
 		point.x = self.x
	elseif self._direction == "down" then
		point.y = self.y + lookahead
		point.x = self.x
	elseif self._direction == "left" then
		point.x = self.x - lookahead
		point.y = self.y
	elseif self._direction == "right" then
		point.x = self.x + lookahead
		point.y = self.y
	else -- "idle"
		point.y = self.y
		point.x = self.x
	end

	self._front = point
end

function GridActor:update_cell()
	local last_cell_x, last_cell_y = self._cell.x, self._cell.y
	self._cell.x, self._cell.y = GridActor._grid.point_to_cell(self.x, self.y, self._tilesize)
	if self._cell.x ~= last_cell_x or self._cell.y ~= last_cell_y then -- changed cell
		self._last_cell.x, self._last_cell.y = last_cell_x, last_cell_y
		self._changed_grid_cell = true
	else
		self._changed_grid_cell = false
	end
end

function GridActor:get_cell_in_front()
	if self._direction == "up" then
		return self._cell.x, self._cell.y - 1
	elseif self._direction == "down" then
		return self._cell.x, self._cell.y + 1
	elseif self._direction == "left" then
		return self._cell.x - 1, self._cell.y
	elseif self._direction == "right" then
		return self._cell.x + 1, self._cell.y
	else -- "idle"
		return self._cell.x, self._cell.y
	end
end

function GridActor:get_enabled_directions()
	return GridActor._grid:get_enabled_directions(self._cell.x, self._cell.y)
end

function GridActor:is_front_wall()
	local cell_x, cell_y = self:get_cell_in_front()
	return GridActor._grid:is_blocked_cell(cell_x, cell_y)
end

function GridActor:is_cell_valid()
	return GridActor._grid:is_valid_cell(self._cell.x, self._cell.y)
end

function GridActor:get_id()
	return self._id
end

function GridActor:get_update_count()
	return self._update_count
end

function GridActor:get_no_pill_update_count()
	return nil
end

function GridActor:get_visited_count()
	return nil
end

function GridActor:get_grid_cell_changes()
	return nil
end

function GridActor:get_genes()
	return nil
end

function GridActor:get_fitness()
	return nil
end

function GridActor:get_collision_count()
	return nil
end

function GridActor:type()
	return registered_types_list[self._type]
end

local _time_callback = os.time
function GridActor:log(event_type, other)
	local event_table = {}
	event_table["timestamp"] = _time_callback()
	event_table["actor_id"] = self:get_id()
	event_table["actor_type"] = self:type()
	event_table["event_type"] = event_type
	event_table["other"] = other
	event_table["cell_x"] = self._cell.x
	event_table["cell_y"] = self._cell.y
	event_table["updates"] = self:get_update_count()
	event_table["no_pill_updates"] = self:get_no_pill_update_count()
	event_table["visited_count"] = self:get_visited_count()
	event_table["grid_cell_changes"] = self:get_grid_cell_changes()
	event_table["collision_count"] = self:get_collision_count()
	event_table["fps"] = tostring(love.timer.getFPS())
	event_table["lifetime"] = self._lifetime
	event_table["genes"] = self:get_genes()

	GridActor._event_logger:log(event_table)
end

function GridActor:enablePreciseTime()
	print("GridActor precise timer enabled!")
	_time_callback = love.timer.getTime
end

return GridActor
