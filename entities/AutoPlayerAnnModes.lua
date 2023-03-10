local AutoplayerAnnModes = {}
AutoplayerAnnModes.update = {}
AutoplayerAnnModes.new = {}

local qpd = require "qpd.qpd"

local orientation_direction_to_action = {
	["up"] = {
		["up"] = "keep",
		["down"] = "flip",
		["left"] = "rotate_left",
		["right"] = "rotate_right",
	},
	["down"] = {
		["up"] = "flip",
		["down"] = "keep",
		["left"] = "rotate_right",
		["right"] = "rotate_left",
	},
	["left"] = {
		["up"] = "rotate_right",
		["down"] = "rotate_left",
		["left"] = "keep",
		["right"] = "flip",
	},
	["right"] = {
		["up"] = "rotate_left",
		["down"] = "rotate_right",
		["left"] = "flip",
		["right"] = "keep",
	},
}

-- helper functions
local function print_array(array)
	for _, item in ipairs(array) do
		io.write(item, " | ")
	end
	print("")
end

local function rotate_left_dir(direction)
	if direction == "up" then
		return "left"
	elseif direction == "down" then
		return "right"
	elseif direction == "left" then
		return "down"
	elseif direction == "right" then
		return "up"
	end
end

local function rotate_right_dir(direction)
	if direction == "up" then
		return "right"
	elseif direction == "down" then
		return "left"
	elseif direction == "left" then
		return "up"
	elseif direction == "right" then
		return "down"
	end
end

local function flip_dir(direction)
	if direction == "up" then
		return "down"
	elseif direction == "down" then
		return "up"
	elseif direction == "left" then
		return "right"
	elseif direction == "right" then
		return "left"
	end
end

local function rotate_left(self)
	self._orientation = rotate_left_dir(self._orientation)
end

local function rotate_right(self)
	self._orientation = rotate_right_dir(self._orientation)
end

local function flip(self)
	self._orientation = flip_dir(self._orientation)
end

local function keep(self)
end

local function list_has_class(class_name, grid_actor_list)
	for i = 1, #grid_actor_list do
		if grid_actor_list[i]:is_type(class_name) then
			return true
		end
	end

	return false
end

-- Autoplayer helper Methods
local function distance_to_class_x(self, dx, class, grid, search_path_length)
	local cell_x, cell_y = self._cell.x, self._cell.y

	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x + dx * i, cell_y) then
			return search_path_length
		end

		local collision_list = grid:get_collisions_in_cell(cell_x + dx * i, cell_y)
		if (#collision_list > 0) then
			if list_has_class(class, collision_list) then
				return i
			end
		end
	end
	return search_path_length
end

local function distance_to_class_y(self, dy, class, grid, search_path_length)
	local cell_x, cell_y = self._cell.x, self._cell.y

	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x, cell_y + dy * i) then
			return search_path_length
		end

		local collision_list = grid:get_collisions_in_cell(cell_x, cell_y + dy * i)
		if (#collision_list > 0) then
			if list_has_class(class, collision_list) then
				return i
			end
		end
	end
	return search_path_length
end

local function distance_in_front_class(self, class, grid, search_path_length)
	if self._orientation == "up" then
		return distance_to_class_y(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return distance_to_class_y(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return distance_to_class_x(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return distance_to_class_x(self, 1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function distance_in_back_class(self, class, grid, search_path_length)
	if self._orientation == "up" then
		return distance_to_class_y(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return distance_to_class_y(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return distance_to_class_x(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return distance_to_class_x(self, -1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function distance_in_left_class(self, class, grid, search_path_length)
	if self._orientation == "up" then
		return distance_to_class_x(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return distance_to_class_x(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return distance_to_class_y(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return distance_to_class_y(self, -1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function distance_in_right_class(self, class, grid, search_path_length)
	if self._orientation == "up" then
		return distance_to_class_x(self, 1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return distance_to_class_x(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return distance_to_class_y(self, -1, class, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return distance_to_class_y(self, 1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function find_collision_in_path_x(self, dx, grid, search_path_length)
	local cell_x, cell_y = self._cell.x, self._cell.y

	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x + dx * i, cell_y) then
			return i
		end
	end
	return search_path_length
end

local function find_collision_in_path_y(self, dy, grid, search_path_length)
	local cell_x, cell_y = self._cell.x, self._cell.y

	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x, cell_y + dy * i) then
			return i
		end
	end
	return search_path_length
end

local function distance_in_front_collision(self, grid, search_path_length)
	if self._orientation == "up" then
		return find_collision_in_path_y(self, -1, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return find_collision_in_path_y(self, 1, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return find_collision_in_path_x(self, -1, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return find_collision_in_path_x(self, 1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function distance_in_left_collision(self, grid, search_path_length)
	if self._orientation == "up" then
		return find_collision_in_path_x(self, -1, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return find_collision_in_path_x(self, 1, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return find_collision_in_path_y(self, 1, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return find_collision_in_path_y(self, -1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function distance_in_right_collision(self, grid, search_path_length)
	if self._orientation == "up" then
		return find_collision_in_path_x(self, 1, grid, search_path_length)/search_path_length
	elseif self._orientation == "down" then
		return find_collision_in_path_x(self, -1, grid, search_path_length)/search_path_length
	elseif self._orientation == "left" then
		return find_collision_in_path_y(self, -1, grid, search_path_length)/search_path_length
	elseif self._orientation == "right" then
		return find_collision_in_path_y(self, 1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", self._orientation)
end

local function is_front_valid(self, grid)
	if self._orientation == "up" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y - 1) and 0 or 1
	elseif self._orientation == "down" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y + 1) and 0 or 1
	elseif self._orientation == "left" then
		return grid:is_blocked_cell(self._cell.x - 1, self._cell.y) and 0 or 1
	elseif self._orientation == "right" then
		return grid:is_blocked_cell(self._cell.x + 1, self._cell.y) and 0 or 1
	end
	print("no orientation set", self._orientation)
end

local function is_left_valid(self, grid)
	if self._orientation == "up" then
		return grid:is_blocked_cell(self._cell.x - 1, self._cell.y) and 0 or 1
	elseif self._orientation == "down" then
		return grid:is_blocked_cell(self._cell.x + 1, self._cell.y) and 0 or 1
	elseif self._orientation == "left" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y + 1) and 0 or 1
	elseif self._orientation == "right" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y - 1) and 0 or 1
	end
	print("no orientation set", self._orientation)
end

local function is_right_valid(self, grid)
	if self._orientation == "up" then
		return grid:is_blocked_cell(self._cell.x + 1, self._cell.y) and 0 or 1
	elseif self._orientation == "down" then
		return grid:is_blocked_cell(self._cell.x - 1, self._cell.y) and 0 or 1
	elseif self._orientation == "left" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y - 1) and 0 or 1
	elseif self._orientation == "right" then
		return grid:is_blocked_cell(self._cell.x, self._cell.y + 1) and 0 or 1
	end
	print("no orientation set", self._orientation)
end

local function is_collision_x(self, dx, grid)
	return grid:is_blocked_cell(self._cell.x + dx, self._cell.y) and 1 or 0
end

local function is_collision_y(self, dy, grid)
	return grid:is_blocked_cell(self._cell.x, self._cell.y + dy) and 1 or 0
end

local function grade_path_x(self, dx, grid, search_path_length, ghost_state)
	local inputs = {
		-- grid:is_blocked_cell(self._cell.x + dx, self._cell.y) and 1 or 0,
		find_collision_in_path_x(self, dx, grid, search_path_length)/search_path_length,
		distance_to_class_x(self, dx, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_x(self, dx, "pill", grid, search_path_length)/search_path_length,
		-- distance_to_class_x(self, dx, "player", grid, search_path_length)/search_path_length,
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "frightened") and 0 or 1, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}
	-- print_array(inputs)
	local outputs = self._ann:get_outputs(inputs, true)

	return outputs[1], inputs
end

local function grade_path_y(self, dy, grid, search_path_length, ghost_state)
	local inputs = {
		-- grid:is_blocked_cell(self._cell.x, self._cell.y + dy) and 1 or 0,
		find_collision_in_path_y(self, dy, grid, search_path_length)/search_path_length,
		distance_to_class_y(self, dy, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_y(self,dy, "pill", grid, search_path_length)/search_path_length,
		-- distance_to_class_y(self, dy,"player", grid, search_path_length)/search_path_length,
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "frightened") and 0 or 1, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}
	-- print_array(inputs)
	local outputs = self._ann:get_outputs(inputs, true)

	return outputs[1], inputs
end

local function can_see_class(self, class, grid, search_path_length)
	local enabled_directions = self:get_enabled_directions()

	local see_class = false
	local best_class_distance = search_path_length
	local best_class_direction_index
	for i = 1, 2 do
		if enabled_directions[i] then
			local this_distance = distance_to_class_y(self, (-1)^i, class, grid, search_path_length)
			if (this_distance < best_class_distance) then
				see_class = true
				best_class_distance = this_distance
				best_class_direction_index = i
			end
		end
	end
	for i = 3, 4 do
		if enabled_directions[i] then
			local this_distance = distance_to_class_x(self, (-1)^i, class, grid, search_path_length)
			if (this_distance < best_class_distance) then
				see_class = true
				best_class_distance = this_distance
				best_class_direction_index = i
			end
		end
	end

	if see_class then
		return true, best_class_distance, grid.directions[best_class_direction_index]
	else
		return false
	end
end

local function get_distance_callback_and_dxy_from_direction(direction)
	if direction == "up" then
		return distance_to_class_y, -1
	elseif direction == "down" then
		return distance_to_class_y, 1
	elseif direction == "left" then
		return distance_to_class_x,-1
	elseif direction == "right" then
		return distance_to_class_x, 1
	elseif direction == "idle" then
		return false
	else
		print("[ERROR] - AutoPlayerAnnModes get_distance_callback_and_dxy_from_direction() - Received a invalid direction")
	end
end

local function get_grade_callback_and_dxy_from_direction(direction)
	if direction == "up" then
		return grade_path_y, -1
	elseif direction == "down" then
		return grade_path_y, 1
	elseif direction == "left" then
		return grade_path_x,-1
	elseif direction == "right" then
		return grade_path_x, 1
	elseif direction == "idle" then
		return false
	else
		print("[ERROR] - AutoPlayerAnnModes get_grade_callback_and_dxy_from_direction() - Received a invalid direction")
	end
end

local function can_get_pill(self, current_direction, grid, search_path_length)
	local see_pill, pill_distance, pill_direction = can_see_class(self, "pill", grid, search_path_length)

	if see_pill then
		local distance_function, dxy = get_distance_callback_and_dxy_from_direction(current_direction)
		if distance_function and (distance_function(self, dxy, "ghost", grid, search_path_length) > pill_distance) then
			return true, pill_direction
		end
	end

	return false
end

local function is_direction_good(self, current_direction, ghosts_state, grid, search_path_length)
	local enabled_directions = self:get_enabled_directions()
	local direction_index = grid.direction_to_index[current_direction]

	local distance_function, dxy = get_distance_callback_and_dxy_from_direction(current_direction)

	if ghosts_state == "frightened" then
		if enabled_directions[direction_index] then
			-- if (distance_function(self, dxy, "ghost", grid, search_path_length) <= (search_path_length - 1)) then
				return true
			-- end
		end
	else
		if enabled_directions[direction_index] then
			if (distance_function(self, dxy, "ghost", grid, search_path_length) > 3) then
				return true
			end
		end
	end

	return false
end

local function find_good_direction(self, current_direction, ghosts_state, grid, search_path_length)
	local enabled_directions = self:get_enabled_directions()

	local prefer_x
	if current_direction == "up" then
		prefer_x = true
	elseif current_direction == "down" then
		prefer_x = true
	elseif current_direction == "left" then
		prefer_x = false
	elseif current_direction == "right" then
		prefer_x = false
	elseif current_direction == "idle" then
		prefer_x = false
	else
		print("[ERROR] - AutoPlayerAnnModes find_good_direction() - Received a invalid direction")
	end

	if ghosts_state ~= "frightened" then
		for value = search_path_length, 0, -1 do
			if prefer_x then
				if enabled_directions[3] then
					if (distance_to_class_x(self, -1, "ghost", grid, search_path_length) >= value) then
						return "left"
					end
				end
				if enabled_directions[4] then
					if (distance_to_class_x(self, 1, "ghost", grid, search_path_length) >= value) then
						return "right"
					end
				end
				if enabled_directions[1] then
					if (distance_to_class_y(self, -1, "ghost", grid, search_path_length) >= value) then
						return "up"
					end
				end
				if enabled_directions[2] then
					if (distance_to_class_y(self, 1, "ghost", grid, search_path_length) >= value) then
						return "down"
					end
				end
			else
				if enabled_directions[1] then
					if (distance_to_class_y(self, -1, "ghost", grid, search_path_length) >= value) then
						return "up"
					end
				end
				if enabled_directions[2] then
					if (distance_to_class_y(self, 1, "ghost", grid, search_path_length) >= value) then
						return "down"
					end
				end
				if enabled_directions[3] then
					if (distance_to_class_x(self, -1, "ghost", grid, search_path_length) >= value) then
						return "left"
					end
				end
				if enabled_directions[4] then
					if (distance_to_class_x(self, 1, "ghost", grid, search_path_length) >= value) then
						return "right"
					end
				end
			end
		end
	else
		for value = 0, search_path_length, 1 do
			if prefer_x then
				if enabled_directions[3] then
					if (distance_to_class_x(self, -1, "ghost", grid, search_path_length) < value) then
						return "left"
					end
				end
				if enabled_directions[4] then
					if (distance_to_class_x(self, 1, "ghost", grid, search_path_length) < value) then
						return "right"
					end
				end
				if enabled_directions[1] then
					if (distance_to_class_y(self, -1, "ghost", grid, search_path_length) < value) then
						return "up"
					end
				end
				if enabled_directions[2] then
					if (distance_to_class_y(self, 1, "ghost", grid, search_path_length) < value) then
						return "down"
					end
				end
			else
				if enabled_directions[1] then
					if (distance_to_class_y(self, -1, "ghost", grid, search_path_length) < value) then
						return "up"
					end
				end
				if enabled_directions[2] then
					if (distance_to_class_y(self, 1, "ghost", grid, search_path_length) < value) then
						return "down"
					end
				end
				if enabled_directions[3] then
					if (distance_to_class_x(self, -1, "ghost", grid, search_path_length) < value) then
						return "left"
					end
				end
				if enabled_directions[4] then
					if (distance_to_class_x(self, 1, "ghost", grid, search_path_length) < value) then
						return "right"
					end
				end
			end
		end
	end

	return nil
end

-------------------------------------------------------------------------------
local function get_random_direction()
	return qpd.random.choose("up", "down", "left", "right")
end

local function get_different_random_direction(current_direction)
	if current_direction == "up" then
		return qpd.random.choose("down", "left", "right")
	elseif current_direction == "down" then
		return qpd.random.choose("up", "left", "right")
	elseif current_direction == "left" then
		return qpd.random.choose("up", "down", "right")
	elseif current_direction == "right" then
		return qpd.random.choose("up", "down", "left")
	end

	return qpd.random.choose("up", "down", "left", "right")
end

local function get_baseline_next_direction(self, grid, search_path_length, ghost_state, current_direction)
	current_direction = current_direction or self._direction

	if is_direction_good(self, current_direction, ghost_state, grid, search_path_length) then
		return current_direction
	end

	local next_direction = find_good_direction(self, current_direction, ghost_state, grid, search_path_length)
	if not next_direction then
		next_direction = grid:get_random_valid_direction(self._cell.x, self._cell.y)
	end
	return next_direction
end

local function get_baseline_pill_next_direction(self, grid, search_path_length, ghost_state, current_direction)
	current_direction = current_direction or self._direction

	if ghost_state ~= "frightened" then
		local found_pill, pill_direction = can_get_pill(self, current_direction, grid, search_path_length)
		if found_pill then
			return pill_direction
		end
	end

	return get_baseline_next_direction(self, grid, search_path_length, ghost_state, current_direction)
end

local function get_baseline_pill_ghost_next_direction(self, grid, search_path_length, ghost_state, current_direction)
	current_direction = current_direction or self._direction

	if ghost_state == "frightened" then
		local found_ghost, ghost_direction = can_see_class(self, "ghost", grid, search_path_length)
		if found_ghost then
			return ghost_direction
		end
	end

	return get_baseline_pill_next_direction(self, grid, search_path_length, ghost_state, current_direction)
end

-- implementations
-- NN Class
-- layers = {
-- 	{
-- 		count = 5,
-- 		activation_function_name = = "identity",
-- 	},
-- 	{
-- 		count = 3,
-- 		activation_function_name = = "sigmoid",
--		activation_function_parameters = {p = 1}
-- 	},
-- }

AutoplayerAnnModes.update.b1 = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = b1
-- autoplayer_ann_layers = {{count = 12, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 4, activation_function_name = "binary_step"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.3
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	local inputs = {
		is_left_valid(self, grid),
		distance_in_front_collision(self, grid, search_path_length),
		is_right_valid(self, grid),
		distance_in_front_class(self, "ghost", grid, search_path_length),
		distance_in_back_class(self, "ghost", grid, search_path_length),
		distance_in_left_class(self, "ghost", grid, search_path_length),
		distance_in_right_class(self, "ghost", grid, search_path_length),
		distance_in_front_class(self, "pill", grid, search_path_length),
		distance_in_back_class(self, "pill", grid, search_path_length),
		distance_in_left_class(self, "pill", grid, search_path_length),
		distance_in_right_class(self, "pill", grid, search_path_length),
		-- distance_in_front_class(self, "player", grid, search_path_length),
		-- distance_in_back_class(self, "player", grid, search_path_length),
		-- distance_in_left_class(self, "player", grid, search_path_length),
		-- distance_in_right_class(self, "player", grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}

	local outputs = self._ann:get_outputs(inputs)
	if outputs[1] == 1 then
		rotate_left(self)
	end

	self._next_direction = self._orientation
end

AutoplayerAnnModes.update.b2 = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = b2
-- autoplayer_ann_layers = {{count = 12, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 4, activation_function_name = "binary_step"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.3
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	local inputs = {
		is_left_valid(self, grid),
		distance_in_front_collision(self, grid, search_path_length),
		is_right_valid(self, grid),
		distance_in_front_class(self, "ghost", grid, search_path_length),
		distance_in_back_class(self, "ghost", grid, search_path_length),
		distance_in_left_class(self, "ghost", grid, search_path_length),
		distance_in_right_class(self, "ghost", grid, search_path_length),
		distance_in_front_class(self, "pill", grid, search_path_length),
		distance_in_back_class(self, "pill", grid, search_path_length),
		distance_in_left_class(self, "pill", grid, search_path_length),
		distance_in_right_class(self, "pill", grid, search_path_length),
		-- distance_in_front_class(self, "player", grid, search_path_length),
		-- distance_in_back_class(self, "player", grid, search_path_length),
		-- distance_in_left_class(self, "player", grid, search_path_length),
		-- distance_in_right_class(self, "player", grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}

	local outputs = self._ann:get_outputs(inputs)
	if outputs[1] == 1 then
		flip(self)
	end
	if outputs[2] == 1 then
		rotate_left(self)
	end

	self._next_direction = self._orientation
end

AutoplayerAnnModes.update.b3 = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = b3
-- autoplayer_ann_layers = {{count = 12, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 4, activation_function_name = "binary_step"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.3
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	local inputs = {
		is_left_valid(self, grid),
		distance_in_front_collision(self, grid, search_path_length),
		is_right_valid(self, grid),
		distance_in_front_class(self, "ghost", grid, search_path_length),
		distance_in_back_class(self, "ghost", grid, search_path_length),
		distance_in_left_class(self, "ghost", grid, search_path_length),
		distance_in_right_class(self, "ghost", grid, search_path_length),
		distance_in_front_class(self, "pill", grid, search_path_length),
		distance_in_back_class(self, "pill", grid, search_path_length),
		distance_in_left_class(self, "pill", grid, search_path_length),
		distance_in_right_class(self, "pill", grid, search_path_length),
		-- distance_in_front_class(self, "player", grid, search_path_length),
		-- distance_in_back_class(self, "player", grid, search_path_length),
		-- distance_in_left_class(self, "player", grid, search_path_length),
		-- distance_in_right_class(self, "player", grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}

	local outputs = self._ann:get_outputs(inputs)
	if outputs[1] == 1 then
		flip(self)
	end
	if outputs[2] == 1 then
		rotate_left(self)
	end
	if outputs[3] == 1 then
		rotate_left(self)
	end

	self._next_direction = self._orientation
end

AutoplayerAnnModes.update.nb4 = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = nb4
-- autoplayer_ann_layers = {{count = 13, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 4, activation_function_name = "identity"}}
-- autoplayer_ann_backpropagation = true
-- autoplayer_ann_learning_rate = 0.1
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	local old_orientation = self._orientation
	local inputs = {
		is_left_valid(self, grid),
		distance_in_front_collision(self, grid, search_path_length),
		is_right_valid(self, grid),
		distance_in_front_class(self, "ghost", grid, search_path_length),
		distance_in_back_class(self, "ghost", grid, search_path_length),
		distance_in_left_class(self, "ghost", grid, search_path_length),
		distance_in_right_class(self, "ghost", grid, search_path_length),
		distance_in_front_class(self, "pill", grid, search_path_length),
		distance_in_back_class(self, "pill", grid, search_path_length),
		distance_in_left_class(self, "pill", grid, search_path_length),
		distance_in_right_class(self, "pill", grid, search_path_length),
		-- distance_in_front_class(self, "player", grid, search_path_length),
		-- distance_in_back_class(self, "player", grid, search_path_length),
		-- distance_in_left_class(self, "player", grid, search_path_length),
		-- distance_in_right_class(self, "player", grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0, -- ghosts frightened
		-- (ghost_state == "chasing") and 1 or 0, -- ghosts chasing
		-- (ghost_state == "scattering") and 1 or 0, -- ghosts scattering,
	}

	local outputs = self._ann:get_outputs(inputs)

	local greatest_index = 1
	local greatest_value = outputs[greatest_index]
	for i = 1, #outputs do
		if outputs[i] > greatest_value then
			greatest_index = i
		end
	end

	if greatest_index == 1 then
		keep(self)
	elseif greatest_index == 2 then
		flip(self)
	elseif greatest_index == 3 then
		rotate_left(self)
	elseif greatest_index == 4 then
		rotate_right(self)
	end

	if self._autoplayer_ann_backpropagation then
		local good_direction = get_baseline_next_direction(self, grid, search_path_length, ghost_state, old_orientation)
		local targets = qpd.table.clone(outputs)
		targets[greatest_index] = 0

		local action = orientation_direction_to_action[old_orientation][good_direction]

		if action == "keep" then
			targets[1] = greatest_value
		elseif action == "flip" then
			targets[2] = greatest_value
		elseif action == "rotate_left" then
			targets[3] = greatest_value
		elseif action == "rotate_right" then
			targets[4] = greatest_value
		else
			targets[1] = greatest_value
		end
		self._ann:adjust_weights(inputs, targets, outputs)
	end

	self._next_direction = self._orientation
	-- if self._direction == "idle" then
	-- 	print("idle", self._next_direction)
	-- end
end

AutoplayerAnnModes.update.b1_path_grading = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = b1_path_grading
-- autoplayer_ann_layers = {{count = 5, activation_function_name = "identity"}, {count = 5, activation_function_name = "binary_step"}, {count = 1, activation_function_name = "binary_step"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.1
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates

	local old_direction = self._direction

	local callback, dxy = get_grade_callback_and_dxy_from_direction(self._orientation)
	--grade_path_y(self, -1, grid, search_path_length, ghost_state)
	local grade, inputs = callback(self, dxy, grid, search_path_length, ghost_state)

	if (grade == 1) then
		rotate_left(self)
		self._next_direction = self._orientation
	end

	-- print_array(inputs)
	-- print(grade)
	-- print()

	-- if self._autoplayer_ann_backpropagation and (grade == 1) then
	-- 	if is_direction_good(self, old_direction, ghost_state, grid, search_path_length) then
	-- 		self._ann:adjust_weights(inputs, {0}, {1})
	-- 	end
	-- end

	-- if self._autoplayer_ann_backpropagation and (grade >= 0) then
	-- 	if is_direction_good(self, old_direction, ghost_state, grid, search_path_length) then
	-- 		self._ann:adjust_weights(inputs, {-1}, {grade})
	-- 	end
	-- elseif self._autoplayer_ann_backpropagation and (grade < 0) then
	-- 	if not is_front_valid(self, grid) then
	-- 		self._ann:adjust_weights(inputs, {1}, {grade})
	-- 	end
	-- end
end

AutoplayerAnnModes.update.b1_path_grading_simple = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = b1_path_grading
-- autoplayer_ann_layers = {{count = 5, activation_function_name = "identity"}, {count = 5, activation_function_name = "binary_step"}, {count = 1, activation_function_name = "binary_step"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.1
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	for _ = 1, 4 do
		local callback, dxy = get_grade_callback_and_dxy_from_direction(self._orientation)

		local grade, inputs = callback(self, dxy, grid, search_path_length, ghost_state)

		if (grade == 1) then
			rotate_left(self)
			self._next_direction = self._orientation
		else
			self._next_direction = self._orientation
			return
		end
	end
end

local function get_direction_grade(self, direction, grid, search_path_length, ghost_state)
	local callback, dxy = get_grade_callback_and_dxy_from_direction(direction)
	return callback(self, dxy, grid, search_path_length, ghost_state)
end
AutoplayerAnnModes.update.b1_path_grading_hack = function (self, grid, search_path_length, ghost_state)
	local grade, inputs = get_direction_grade(self, self._orientation, grid, search_path_length, ghost_state)

	if grade == 1 then
		grade, _ = get_direction_grade(self, rotate_left_dir(self._orientation), grid, search_path_length, ghost_state)
		if grade == 0 then
			rotate_left(self)
		else
			grade, _ = get_direction_grade(self, rotate_right_dir(self._orientation), grid, search_path_length, ghost_state)
			if grade == 0 then
				rotate_right(self)
			else
				flip(self)
			end
		end
	end
	self._next_direction = self._orientation
end

AutoplayerAnnModes.update.nb4_path_grading = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = nb4_path_grading
-- autoplayer_ann_layers = {{count = 4, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 5, activation_function_name = "relu"}, {count = 1, activation_function_name = "identity"}}
-- autoplayer_ann_backpropagation = false
-- autoplayer_ann_learning_rate = 0.1
-- autoplayer_crossover = false
-- autoplayer_mutate_chance = 0.05
-- autoplayer_mutate_percentage = 0.05
-- autoplayer_population = 6000
-- autoplayer_fitness_mode = no_pill_updates
	self._orientation = self._direction  -- not needed, just to keep it synced for graphics

	local enabled_directions = self:get_enabled_directions()
	local available_paths = {}
	if enabled_directions[1] == true then -- "up"
		local this_direction = {}
		this_direction.grade = grade_path_y(self, -1, grid, search_path_length, ghost_state)
		this_direction.direction = "up"
		table.insert(available_paths, this_direction)
	end
	if enabled_directions[2] == true then -- "down"
		local this_direction = {}
		this_direction.grade = grade_path_y(self, 1, grid, search_path_length, ghost_state)
		this_direction.direction = "down"
		table.insert(available_paths, this_direction)
	end
	if enabled_directions[3] == true then -- "left"
		local this_direction = {}
		this_direction.grade = grade_path_x(self, -1, grid, search_path_length, ghost_state)
		this_direction.direction = "left"
		table.insert(available_paths, this_direction)
	end
	if enabled_directions[4] == true then -- "right"
		local this_direction = {}
		this_direction.grade = grade_path_x(self, 1, grid, search_path_length, ghost_state)
		this_direction.direction = "right"
		table.insert(available_paths, this_direction)
	end

	local old_direction = self._direction
	local best_index
	local best_grade
	if (#available_paths >= 2) then
		-- keep going unless there is a strictly better path
		if old_direction ~= "idle" then
			for i = 1, #available_paths do
				if available_paths[i].direction == old_direction then
					best_index = i
				end
			end
		end
		if not best_index then
			best_index = 1
		end

		best_grade = available_paths[best_index].grade

		for i = 1, #available_paths do
			if (available_paths[i].grade > best_grade) then
				best_grade = available_paths[i].grade
				best_index = i
			end
		end
		self._next_direction = available_paths[best_index].direction
	elseif (#available_paths >= 1) then
		self._next_direction = available_paths[1].direction
	else
		print("AutoPlayer has nowhere to go!")
	end

	if self._autoplayer_ann_backpropagation then
		local good_direction = get_baseline_pill_ghost_next_direction(self, grid, search_path_length, ghost_state, old_direction)
		if self._next_direction ~= good_direction then
			-- local good_direction_index = grid.directions
			local target = {0}
			local inputs = available_paths[best_index].inputs
			local outputs = {available_paths[best_index].grade}
			self._ann:adjust_weights(inputs, target, outputs)
		end
	end
end

-------------------------------------------------------------------------------
AutoplayerAnnModes.update.baseline = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	self._next_direction = get_baseline_next_direction(self, grid, search_path_length, ghost_state)
end

AutoplayerAnnModes.update.baseline_pill = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_pill
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	self._next_direction = get_baseline_pill_next_direction(self, grid, search_path_length, ghost_state)
end

AutoplayerAnnModes.update.baseline_pill_ghost = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_pill
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	self._next_direction = get_baseline_pill_ghost_next_direction(self, grid, search_path_length, ghost_state)
end

AutoplayerAnnModes.update.baseline_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_random
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	if is_direction_good(self, self._direction, ghost_state, grid, search_path_length) then
		return
	end

	self._next_direction = get_different_random_direction(self._direction)
end

AutoplayerAnnModes.update.baseline_full_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_full_random
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	self._next_direction = get_random_direction()
end

AutoplayerAnnModes.update.baseline_collide_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_full_random
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	if self._direction == "idle" then
		self._next_direction = get_different_random_direction(self._direction)
	end
end

AutoplayerAnnModes.update.baseline_valid_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_valid_random
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	if is_direction_good(self, self._direction, ghost_state, grid, search_path_length) then
		return
	end

	self:set_different_random_valid_direction()
end

AutoplayerAnnModes.update.baseline_valid_full_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_ann_mode = baseline_valid_full_random
-- autoplayer_population = 1
-- autoplayer_fitness_mode = movement
	self:set_random_valid_direction()
end

return AutoplayerAnnModes