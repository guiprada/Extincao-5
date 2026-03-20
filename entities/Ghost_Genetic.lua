-- Ghost_Genetic: extends Ext-5 Ghost with Ext-3 genetic fear genes and crossover.
-- Inherits: update, collided, draw, movement from Ghost (Ext-5).
--
-- Known differences vs original Ext-3 implementation (TODOs):
--   1. _grid_pos_closest_pill is never set — Ghost:update() does not track the
--      nearest pill, so go_to_closest_pill always falls back to wander.
--      Override update() here to track it if this gene should be functional.
--   2. Collision detection is pixel-distance (< tilesize), not cell-distance.
--      Ext-3 may have used manhattan cell distance; threshold may differ.
--   3. Fitness = _n_catches only. Ext-3 may have had a richer fitness function
--      (penalties for being eaten, bonuses for herding, etc.).
--   4. There may be further behavioral differences not yet identified.
local Ghost = require "entities.Ghost"
local Ghost_Genetic = Ghost:new()
Ghost_Genetic.__index = Ghost_Genetic

local qpd = require "qpd.qpd"

-- Class vars (shadow Ghost's where needed)
Ghost_Genetic._fear_spread    = 50
Ghost_Genetic._ghost_fear_on  = false
Ghost_Genetic._chase_feared_on   = false
Ghost_Genetic._scatter_feared_on = false
Ghost_Genetic._sibling_ghosts = {}

-- chase_feared_gene (1-9): behavior when chasing and target within fear_target cells
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
-- scatter_feared_gene (1-5): behavior when scattering and target within fear_target cells
local scatter_feared_dispatch = {
	[1] = function(g, t, m) g:go_home(m) end,
	[2] = function(g, t, m) g:go_to_closest_pill(m) end,
	[3] = function(g, t, m) g:go_to_group(m) end,
	[4] = function(g, t, m) g:run_from_target(t, m) end,
	[5] = function(g, t, m) g:wander(m) end,
}

---------------------------------------------------------------
function Ghost_Genetic.init(grid,
							initial_state,
							target_spread,
							fear_spread,
							ghost_fear_on,
							chase_feared_on,
							scatter_feared_on)
	Ghost.init(grid, initial_state, target_spread)
	Ghost_Genetic._fear_spread       = fear_spread    or 50
	Ghost_Genetic._ghost_fear_on     = ghost_fear_on  or false
	Ghost_Genetic._chase_feared_on   = chase_feared_on   or false
	Ghost_Genetic._scatter_feared_on = scatter_feared_on or false
end

function Ghost_Genetic.set_sibling_ghosts(ghosts)
	Ghost_Genetic._sibling_ghosts = ghosts
end

function Ghost_Genetic:new(o)
	local o = Ghost:new(o or {})
	setmetatable(o, self)
	return o
end

function Ghost_Genetic:reset(reset_table)
	Ghost.reset(self, reset_table)

	local fear_target, chase_feared_gene, scatter_feared_gene
	if reset_table then
		fear_target          = reset_table.fear_target
		chase_feared_gene    = reset_table.chase_feared_gene
		scatter_feared_gene  = reset_table.scatter_feared_gene
	end
	self._fear_target         = fear_target         or qpd.random.random(0, Ghost_Genetic._fear_spread)
	self._chase_feared_gene   = chase_feared_gene   or qpd.random.random(1, 9)
	self._scatter_feared_gene = scatter_feared_gene or qpd.random.random(1, 5)
end

function Ghost_Genetic:get_history()
	return {
		_fitness              = self._fitness,
		_target_offset        = self._target_offset,
		_home                 = self._home,
		_try_order            = {self._try_order[1], self._try_order[2], self._try_order[3], self._try_order[4]},
		_fear_target          = self._fear_target,
		_chase_feared_gene    = self._chase_feared_gene,
		_scatter_feared_gene  = self._scatter_feared_gene,
	}
end

function Ghost_Genetic:crossover(mom, dad, reset_table)
	-- target_offset: pick one parent's value, mutate ±2, clamp to target_spread
	local base_offset = (qpd.random.random() < 0.5) and mom._target_offset or dad._target_offset
	base_offset = base_offset or 0
	local new_offset = base_offset + qpd.random.random(-2, 2)
	if Ghost._target_spread > 0 then
		new_offset = math.max(-Ghost._target_spread, math.min(Ghost._target_spread, new_offset))
	end

	-- fear_target: average of parents ± small mutation, clamp to fear_spread
	local mom_fear = mom._fear_target or qpd.random.random(0, Ghost_Genetic._fear_spread)
	local dad_fear = dad._fear_target or qpd.random.random(0, Ghost_Genetic._fear_spread)
	local new_fear_target = math.floor((mom_fear + dad_fear) / 2) + qpd.random.random(-5, 5)
	new_fear_target = math.max(0, math.min(Ghost_Genetic._fear_spread, new_fear_target))

	-- try_order: per-element 40% mom / 20% dad / 40% random
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
		home                = new_home,
		target_offset       = new_offset,
		fear_target         = new_fear_target,
		try_order           = new_try_order,
		chase_feared_gene   = new_chase_feared_gene,
		scatter_feared_gene = new_scatter_feared_gene,
	})
end

function Ghost_Genetic:go_to_closest_pill(possible_next_moves)
	if not self._grid_pos_closest_pill then
		self:wander(possible_next_moves)
		return
	end
	local destination = {
		x = self._grid_pos_closest_pill.x,
		y = self._grid_pos_closest_pill.y,
	}
	self:get_closest(possible_next_moves, destination)
end

function Ghost_Genetic:go_to_group(possible_next_moves)
	local avg_x, avg_y, count = 0, 0, 0
	for _, g in ipairs(Ghost_Genetic._sibling_ghosts) do
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
	self:get_closest(possible_next_moves, {
		x = math.floor(avg_x / count),
		y = math.floor(avg_y / count),
	})
end

function Ghost_Genetic:find_next_direction(target)
	if self._debounce_get_next_direction == true then
		return
	else
		self._debounce_get_next_direction = true

		self.enabled_directions = self:get_enabled_directions()
		if (#self.enabled_directions < 1) then
			self._direction = "idle"
		elseif not Ghost._grid:is_corridor(self._cell.x, self._cell.y) then
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
					if Ghost._grid.oposite_direction[self._direction] ~= cell._direction then
						table.insert(possible_next_moves, cell)
					end
				end
			end

			if (#possible_next_moves == 0) then
				self._direction = "idle"
			elseif (target._is_active) then
				if (Ghost._state == "chasing") then
					if Ghost_Genetic._ghost_fear_on and Ghost_Genetic._chase_feared_on then
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
					if Ghost_Genetic._ghost_fear_on and Ghost_Genetic._scatter_feared_on then
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

return Ghost_Genetic
