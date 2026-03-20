-- Guilherme Cunha Prada 2019
local GridActor = require "entities.GridActor"
local Ghost = GridActor:new()
Ghost.__index = Ghost

local qpd = require "qpd.qpd"
local ghost_type_name = "ghost"

Ghost._state = "none"
Ghost._sequential_home = false
Ghost._shuffle_try_order = false

Ghost._ghost_homes = {
	{x = 1, y = 1},
	{x = 28, y = 14},
	{x = 1, y = 14},
	{x = 28, y = 1},
}

-- Genetic ghost configuration (set via Ghost.init)
Ghost._fear_spread = 50
Ghost._ghost_fear_on = false
Ghost._chase_feared_on = false
Ghost._scatter_feared_on = false
Ghost._sibling_ghosts = {}

-- Behavior dispatch tables for fear genes
-- chase_feared_gene (1-9): behavior when ghost is in chase state and player is within fear_target cells
local chase_feared_dispatch = {
	[1] = function(g, t, m) g:go_home(m) end,
	[2] = function(g, t, m) g:go_to_closest_pill(m) end,
	[3] = function(g, t, m) g:go_to_group(m) end,
	[4] = function(g, t, m) g:run_from_target(t, m) end,
	[5] = function(g, t, m) g:wander(m) end,
	[6] = function(g, t, m) g:go_to_target(t, m) end,
	[7] = function(g, t, m) g:catch_target(t, m) end,
	[8] = function(g, t, m) g:surround_target_back(t, m) end,
	[9] = function(g, t, m) g:surround_target_front(t, m) end,
}
-- scatter_feared_gene (1-5): behavior when ghost is in scatter state and player is within fear_target cells
local scatter_feared_dispatch = {
	[1] = function(g, t, m) g:go_home(m) end,
	[2] = function(g, t, m) g:go_to_closest_pill(m) end,
	[3] = function(g, t, m) g:go_to_group(m) end,
	[4] = function(g, t, m) g:run_from_target(t, m) end,
	[5] = function(g, t, m) g:wander(m) end,
}
---------------------------------------------------------------
function Ghost.get_random_home_index()
	return qpd.random.random(1, #Ghost._ghost_homes)
end

function Ghost.set_state(new_state)
	Ghost._state = new_state
end

function Ghost.set_speed(new_speed)
	Ghost._speed = new_speed
end

function Ghost.set_shuffle_try_order(value)
	Ghost._shuffle_try_order = value or true
end

function Ghost.set_sibling_ghosts(ghosts)
	Ghost._sibling_ghosts = ghosts
end

function Ghost.init(grid,
					initial_state,
					target_spread,
					fear_spread,
					ghost_fear_on,
					chase_feared_on,
					scatter_feared_on)
	Ghost._grid = grid
	Ghost._target_spread = target_spread or 0
	Ghost._fear_spread = fear_spread or 50
	Ghost._ghost_fear_on = ghost_fear_on or false
	Ghost._chase_feared_on = chase_feared_on or false
	Ghost._scatter_feared_on = scatter_feared_on or false
	Ghost.set_state(initial_state)

	GridActor.register_type(ghost_type_name)
end

function Ghost:new(o)
	local o = GridActor:new(o or {})
	setmetatable(o, self)

	o._home = Ghost.get_random_home_index() -- determined by pos_index, it is a phenotype
	o._try_order = {} -- gene

	o._type = GridActor.get_type_by_name(ghost_type_name)

	return  o
end

function Ghost:reset(reset_table)
	local home, target_offset, try_order, pos, direction
	local fear_target, chase_feared_gene, scatter_feared_gene
	if reset_table then
		home = reset_table.home
		target_offset = reset_table.target_offset
		try_order = reset_table.try_order
		pos = reset_table.pos
		direction = reset_table.direction
		fear_target = reset_table.fear_target
		chase_feared_gene = reset_table.chase_feared_gene
		scatter_feared_gene = reset_table.scatter_feared_gene
	end

	self._home = home or Ghost.get_random_home_index()

	target_offset = target_offset or qpd.random.random(math.floor(-Ghost._target_spread), math.ceil(Ghost._target_spread))
	try_order = try_order or nil

	if not try_order then
		try_order = {}
		for i = 1, 4, 1 do
			try_order[i] = i
		end
		qpd.array.shuffle(try_order)
	end

	self._try_order[1] = try_order[1]
	self._try_order[2] = try_order[2]
	self._try_order[3] = try_order[3]
	self._try_order[4] = try_order[4]

	GridActor.reset(self, pos or Ghost._grid:get_valid_cell())

	self._n_catches = 0
	self._fitness = 0

	self._target_offset = target_offset

	-- genetic genes
	self._fear_target = fear_target or qpd.random.random(0, Ghost._fear_spread)
	self._chase_feared_gene = chase_feared_gene or qpd.random.random(1, 9)
	self._scatter_feared_gene = scatter_feared_gene or qpd.random.random(1, 5)

	-- set a valid direction
	self:set_direction(direction)
end

function Ghost:reposition(pos, target_offset, home)
	if pos then
		GridActor.reposition(self, pos)
		self:set_direction()
	end

	self._target_offset = target_offset or self._target_offset
	self._home = home or self._home
end

function Ghost:set_direction(direction)
	self._direction = direction or self:get_random_valid_direction()
	self._debounce_get_next_direction = true
	self:update_dynamic_front()
end

function Ghost:get_target_offset()
	return self._target_offset
end

function Ghost:set_target_offset(value)
	self._target_offset = value
end

function Ghost:increase_home()
	self._home = self._home + 1
	if self._home > #self._ghost_homes then
		self._home = 1
	end
end

function Ghost:get_home()
	return Ghost._ghost_homes[self._home]
end

function Ghost:get_history()
	return {
		_fitness = self._fitness,
		_target_offset = self._target_offset,
		_home = self._home,
		_try_order = {self._try_order[1], self._try_order[2], self._try_order[3], self._try_order[4]},
		_fear_target = self._fear_target,
		_chase_feared_gene = self._chase_feared_gene,
		_scatter_feared_gene = self._scatter_feared_gene,
	}
end

function Ghost:crossover(mom, dad, reset_table)
	-- target_offset: pick one parent's value, mutate ±2, clamp to target_spread
	local base_offset = (qpd.random.random() < 0.5) and mom._target_offset or dad._target_offset
	base_offset = base_offset or 0
	local new_offset = base_offset + qpd.random.random(-2, 2)
	if Ghost._target_spread > 0 then
		new_offset = math.max(-Ghost._target_spread, math.min(Ghost._target_spread, new_offset))
	end

	-- fear_target: average of parents ± small mutation, clamp to fear_spread
	local mom_fear = mom._fear_target or qpd.random.random(0, Ghost._fear_spread)
	local dad_fear = dad._fear_target or qpd.random.random(0, Ghost._fear_spread)
	local new_fear_target = math.floor((mom_fear + dad_fear) / 2) + qpd.random.random(-5, 5)
	new_fear_target = math.max(0, math.min(Ghost._fear_spread, new_fear_target))

	-- try_order: per-element 40% mom / 20% dad / 40% random direction
	local mom_order = mom._try_order or {1, 2, 3, 4}
	local dad_order = dad._try_order or {1, 2, 3, 4}
	local new_try_order = {}
	for i = 1, 4 do
		local r = qpd.random.random()
		if r < 0.4 then
			new_try_order[i] = mom_order[i]
		elseif r < 0.6 then
			new_try_order[i] = dad_order[i]
		else
			new_try_order[i] = qpd.random.random(1, 4)
		end
	end

	-- chase_feared_gene: 40% mom / 40% dad / 20% random
	local new_chase_feared_gene
	local r3 = qpd.random.random()
	if r3 < 0.4 then
		new_chase_feared_gene = mom._chase_feared_gene or qpd.random.random(1, 9)
	elseif r3 < 0.8 then
		new_chase_feared_gene = dad._chase_feared_gene or qpd.random.random(1, 9)
	else
		new_chase_feared_gene = qpd.random.random(1, 9)
	end

	-- scatter_feared_gene: 40% mom / 40% dad / 20% random
	local new_scatter_feared_gene
	local r4 = qpd.random.random()
	if r4 < 0.4 then
		new_scatter_feared_gene = mom._scatter_feared_gene or qpd.random.random(1, 5)
	elseif r4 < 0.8 then
		new_scatter_feared_gene = dad._scatter_feared_gene or qpd.random.random(1, 5)
	else
		new_scatter_feared_gene = qpd.random.random(1, 5)
	end

	-- home: 90% keep mom's home, 10% random
	local new_home = (qpd.random.random() < 0.9) and mom._home or qpd.random.random(1, #Ghost._ghost_homes)

	self:reset({
		home = new_home,
		target_offset = new_offset,
		fear_target = new_fear_target,
		try_order = new_try_order,
		chase_feared_gene = new_chase_feared_gene,
		scatter_feared_gene = new_scatter_feared_gene,
	})
end

function Ghost:is_type(type_name)
	if type_name == ghost_type_name then
		return true
	else
		return false
	end
end

function Ghost:draw(state)
	if self._is_active then
		if(self._target_offset <= 0)then
			if (self._target_offset == -1) then
				love.graphics.setColor(0.2, 0.5, 0.8)
			elseif (self._target_offset == -2) then
				love.graphics.setColor(0.4, 0.5, 0.6)
			elseif (self._target_offset == -3) then
				love.graphics.setColor(0.6, 0.5, 0.4)
			elseif (self._target_offset == -4) then
				love.graphics.setColor(0.8, 0.5, 0.2)
			else--if (self._target_offset < -4) then
				love.graphics.setColor(1, 0.5, 0)
			end
		else
			if (self._target_offset == 1) then
				love.graphics.setColor(0.5, 0.2, 0.8)
			elseif (self._target_offset == 2) then
				love.graphics.setColor(0.5, 0.4, 0.6)
			elseif (self._target_offset == 3) then
				love.graphics.setColor(0.5, 0.6, 0.4)
			elseif (self._target_offset == 4) then
				love.graphics.setColor(0.5, 0.8, 0.2)
			else--if (self._target_offset > 4) then
				love.graphics.setColor(0.5, 1, 0)
			end
		end

		love.graphics.circle("fill", self.x, self.y, Ghost._tilesize * 0.5)

		local middle_x, middle_y = qpd.point.middle_point2(self, self._front)
		middle_x, middle_y = qpd.point.middle_point(self.x, self.y, middle_x, middle_y)
		middle_x, middle_y = qpd.point.middle_point(self.x, self.y, middle_x, middle_y)
		love.graphics.circle("fill", middle_x, middle_y, Ghost._tilesize/4)

		love.graphics.setColor(1, 1, 1)
	end
end

function Ghost:collided(other)
	if other:is_type("player") then
		if (Ghost._state ~= "frightened") then
			--print("you loose, my target is: " .. self._target_offset)
			-- Ghost.reporter.report_catched(self._target_offset)

			self._n_catches = self._n_catches + 1
			other._is_active = false
			other:log("destroyed", self:get_id())
		else
			if self.got_ghost then
				self:got_ghost()
			end
			self._is_active = false
			self:log("destroyed", other:get_id())
		end
	end
end

function Ghost:update(dt, speed, targets)
	if (self._is_active) then
		if speed*dt > (GridActor._tilesize/2) then
			print("physics sanity check failed, Actor traveled distance > tilesize/2")
		end

		self._lifetime = self._lifetime + dt

		if self._shuffle_try_order then
			qpd.array.shuffle(self._try_order)
		end

		if GridActor._tilesize ~= self._tilesize then
			self._tilesize = GridActor._tilesize
			-- here we just center on grid, we should perhaps do a scaling
			self:center_on_cell()
		end
		Ghost._grid:update_collision(self)

		self._fitness = self._n_catches

		-- updates average distance to player and group,
		-- it is used for collision
		local target
		if #targets > 0 then
			target = targets[1]
			local target_distance = qpd.point.distance2(target, self)
			for i = 2, #targets do
				local this_target = targets[i]
				if this_target._is_active then
					local this_target_distance = qpd.point.distance2(this_target, self)
					if (this_target_distance < target_distance) then
						target = this_target
						target_distance = this_target_distance
					end
				end
			end

			if target_distance < Ghost._tilesize then
				self:collided(target)
			end
		else
			print("no target")
			target = Ghost._grid:get_invalid_cell()
		end

		self:update_dynamic_front()
		self:update_cell()

		-- check collision with wall
		self._has_collided = false
		if(self:is_front_wall()) then
			self:center_on_cell() -- it stops relayed cornering
			self._debounce_get_next_direction = false
			self:find_next_direction(target)
			self._has_collided = true
		else
			if self._changed_grid_cell then
				self._debounce_get_next_direction = false
				self._already_centered = false
			end

			--on tile center, or close
			local dist_grid_center = qpd.point.distance(self.x, self.y, Ghost._grid.cell_to_center_point(self._cell.x, self._cell.y, self._tilesize))
			if (dist_grid_center < speed*dt) and not(self._already_centered) then
				self._already_centered = true
				if ( self._direction == "up" or self._direction== "down") then
					self:center_on_cell_y()
				elseif ( self._direction == "left" or self._direction== "right") then
					self:center_on_cell_x()
				end
				self:find_next_direction(target)
			end

			if self._direction ~= "idle" then
				local this_speed = dt * speed
				if self._direction == "up" then self.y = self.y - this_speed
				elseif self._direction == "down" then self.y = self.y + this_speed
				elseif self._direction == "left" then self.x = self.x - this_speed
				elseif self._direction == "right" then self.x = self.x +this_speed
				end
			end
		end
	end
end

function Ghost:find_next_direction(target)
	if self._debounce_get_next_direction == true then
		return
	else
		self._debounce_get_next_direction = true

		self.enabled_directions = self:get_enabled_directions()
		if (#self.enabled_directions < 1) then
			-- print("enabled_directions cant be empty")
			self._direction = "idle"
		elseif not Ghost._grid:is_corridor(self._cell.x, self._cell.y) then
		-- if 	(Ghost._grid.grid_types[self._cell.y][self._cell.x]~=3 and-- invertido
		-- 	Ghost._grid.grid_types[self._cell.y][self._cell.x]~=12 ) then
		-- 	check which one is closer to the target
		-- 	make a table to contain the posible destinations
			local possible_next_moves = {}
			for i = 1, #self._try_order, 1 do
				if (self.enabled_directions[self._try_order[i]] == true) then
					local cell = {}
					if(self._try_order[i] == 1) then
						cell.x = self._cell.x
						cell.y = self._cell.y - 1
						cell._direction = "up"
					elseif(self._try_order[i] == 2) then
						cell.x = self._cell.x
						cell.y = self._cell.y + 1
						cell._direction = "down"
					elseif(self._try_order[i] == 3) then
						cell.x = self._cell.x - 1
						cell.y = self._cell.y
						cell._direction = "left"
					elseif(self._try_order[i] == 4) then
						cell.x = self._cell.x + 1
						cell.y = self._cell.y
						cell._direction = "right"
					end

					-- ghost can not reverse direction, so
					if Ghost._grid.oposite_direction[self._direction] ~= cell._direction then
						table.insert(possible_next_moves, cell)
					end
				end
			end

			if (#possible_next_moves == 0) then
				-- print("possible_next_moves cant be empty")
				self._direction = "idle"
			elseif (target._is_active) then
				if (Ghost._state == "chasing") then
					if Ghost._ghost_fear_on and Ghost._chase_feared_on then
						local cell_dist = math.abs(target._cell.x - self._cell.x) + math.abs(target._cell.y - self._cell.y)
						if cell_dist <= self._fear_target then
							local fn = chase_feared_dispatch[self._chase_feared_gene]
							if fn then fn(self, target, possible_next_moves)
							else self:go_to_target(target, possible_next_moves) end
						else
							self:go_to_target(target, possible_next_moves)
						end
					else
						self:go_to_target(target, possible_next_moves)
					end
				elseif (Ghost._state == "scattering") then
					if Ghost._ghost_fear_on and Ghost._scatter_feared_on then
						local cell_dist = math.abs(target._cell.x - self._cell.x) + math.abs(target._cell.y - self._cell.y)
						if cell_dist <= self._fear_target then
							local fn = scatter_feared_dispatch[self._scatter_feared_gene]
							if fn then fn(self, target, possible_next_moves)
							else self:go_home(possible_next_moves) end
						else
							self:go_home(possible_next_moves)
						end
					else
						self:go_home(possible_next_moves)
					end
				elseif (Ghost._state == "frightened") then
					self:wander(possible_next_moves)
				else
					print("error, invalid ghost_state: ", Ghost._state)
				end
			else
				self:go_home(possible_next_moves)
			end
		end
	end
end

---------------------------------------------------------------
function Ghost:catch_target(target, possible_next_moves)
	local destination = {}

	destination.x = target._cell.x
	destination.y = target._cell.y

	self:get_closest(possible_next_moves, destination)
end

function Ghost:go_to_target(target, possible_next_moves)
	local destination = {}

	if (target._direction == "up") then
		destination.x =  target._cell.x
		destination.y = -self._target_offset + target._cell.y
	elseif (target._direction == "down") then
		destination.x = target._cell.x
		destination.y = self._target_offset + target._cell.y
	elseif (target._direction == "left") then
		destination.x = -self._target_offset + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "right") then
		destination.x = self._target_offset + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "idle") then
		destination.x = target._cell.x
		destination.y = target._cell.y
	end

	self:get_closest(possible_next_moves, destination)
end

function Ghost:surround_target_front(target, possible_next_moves)
	local destination = {}

	if (target._direction == "up") then
		destination.x =  target._cell.x
		destination.y = -4 + target._cell.y
	elseif (target._direction == "down") then
		destination.x = target._cell.x
		destination.y = 4 + target._cell.y
	elseif (target._direction == "left") then
		destination.x = -4 + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "right") then
		destination.x = 4 + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "idle") then
		destination.x = target._cell.x
		destination.y = target._cell.y
	end

	self:get_closest(possible_next_moves, destination)
end

function Ghost:surround_target_back(target, possible_next_moves)
	local destination = {}

	if (target._direction == "up") then
		destination.x =  target._cell.x
		destination.y = 4 + target._cell.y
	elseif (target._direction == "down") then
		destination.x = target._cell.x
		destination.y = -4 + target._cell.y
	elseif (target._direction == "left") then
		destination.x = 4 + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "right") then
		destination.x = -4 + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "idle") then
		destination.x = target._cell.x
		destination.y = target._cell.y
	end

	self:get_closest(possible_next_moves, destination)
end

function Ghost:wander(possible_next_moves)
	local destination = {}
	local valid_cell = Ghost._grid:get_invalid_cell()

	destination.x = valid_cell.x
	destination.y = valid_cell.y

	self:get_closest(possible_next_moves, destination)
end

function Ghost:go_home(possible_next_moves)
	local destination = {}
	local home = self:get_home()
	destination.x = home.x
	destination.y = home.y

	self:get_closest(possible_next_moves, destination)
end

function Ghost:go_to_group(possible_next_moves)
	-- compute average cell position of all active sibling ghosts
	local avg_x, avg_y, count = 0, 0, 0
	for _, g in ipairs(Ghost._sibling_ghosts) do
		if g._is_active and g ~= self then
			avg_x = avg_x + g._cell.x
			avg_y = avg_y + g._cell.y
			count = count + 1
		end
	end
	if count == 0 then
		self:go_home(possible_next_moves)
		return
	end
	local destination = {x = math.floor(avg_x / count), y = math.floor(avg_y / count)}
	self:get_closest(possible_next_moves, destination)
end


function Ghost:run_from_target(target, possible_next_moves)
	local destination = {}

	if (target._direction == "up") then
		destination.x =  target._cell.x
		destination.y = -self._target_offset + target._cell.y
	elseif (target._direction == "down") then
		destination.x = target._cell.x
		destination.y = self._target_offset + target._cell.y
	elseif (target._direction == "left") then
		destination.x = -self._target_offset + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "right") then
		destination.x = self._target_offset + target._cell.x
		destination.y = target._cell.y
	elseif (target._direction == "idle") then
		destination.x = target._cell.x
		destination.y = target._cell.y
	end

	self:get_furthest(possible_next_moves, destination)
end

function Ghost:go_to_closest_pill(possible_next_moves)
	if not self._grid_pos_closest_pill then
		self:wander(possible_next_moves)
		return
	end
	local destination = {}

	destination.x = self._grid_pos_closest_pill.x
	destination.y = self._grid_pos_closest_pill.y

	self:get_closest(possible_next_moves, destination)
end


function Ghost:get_closest(possible_next_moves, destination)
	local shortest = 1
	local shortest_distance = qpd.point.distance2(possible_next_moves[shortest], destination)
	for i = 2, #possible_next_moves, 1 do
		local this_dist = qpd.point.distance2(possible_next_moves[i], destination)
		if (this_dist <= shortest_distance) then
			shortest = i
			shortest_distance = this_dist
		end
	end
	self._direction = possible_next_moves[shortest]._direction
end

function Ghost:get_furthest(possible_next_moves, destination)
	local furthest = 1
	local furthest_distance = qpd.point.distance2(possible_next_moves[furthest], destination)
	for i = 2, #possible_next_moves, 1 do
		local this_dist = qpd.point.distance2(possible_next_moves[i], destination)
		if (this_dist >= possible_next_moves[furthest].dist) then
			furthest = i
			furthest_distance = this_dist
		end
	end
	self._direction = possible_next_moves[furthest]._direction
end

function Ghost:flip_direction()
	if (self._is_active == false) then return end
	if(self._direction == "up") then self._direction = "down"
	elseif(self._direction == "down") then self._direction = "up"
	elseif(self._direction == "left") then self._direction = "right"
	elseif(self._direction == "right") then self._direction = "left" end
end

return Ghost