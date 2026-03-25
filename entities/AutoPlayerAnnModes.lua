AutoplayerAnnModes = AutoplayerAnnModes or {}
AutoplayerAnnModes.update = {}
AutoplayerAnnModes.new = {}

-- ── Direction utilities (pure, no entity state) ───────────────────────────────

local function rotate_left_dir(direction)
	if direction == "up"    then return "left"
	elseif direction == "down"  then return "right"
	elseif direction == "left"  then return "down"
	elseif direction == "right" then return "up"
	end
end

local function rotate_right_dir(direction)
	if direction == "up"    then return "right"
	elseif direction == "down"  then return "left"
	elseif direction == "left"  then return "up"
	elseif direction == "right" then return "down"
	end
end

local function flip_dir(direction)
	if direction == "up"    then return "down"
	elseif direction == "down"  then return "up"
	elseif direction == "left"  then return "right"
	elseif direction == "right" then return "left"
	end
end

-- ── Grid / sensor helpers (pure: take cell, orientation; no entity object) ────
-- All functions that previously took (self, ...) now take explicit data:
--   cell        = self._cell   (table with .x, .y)
--   orientation = self._orientation  (string "up"/"down"/"left"/"right")
--   ann         = self._ann   (only grade_path_* functions)
--   enabled_directions = self:get_enabled_directions()  (can_see_class, etc.)
-- This makes every helper independently testable without an AutoPlayer instance.

local function list_has_class(class_name, grid_actor_list)
	for i = 1, #grid_actor_list do
		if grid_actor_list[i]:is_type(class_name) then
			return true
		end
	end
	return false
end

local function distance_to_class_x(cell, dx, class, grid, search_path_length)
	local cell_x, cell_y = cell.x, cell.y
	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x + dx * i, cell_y) then
			return search_path_length
		end
		local collision_list = grid:get_collisions_in_cell(cell_x + dx * i, cell_y)
		if #collision_list > 0 and list_has_class(class, collision_list) then
			return i
		end
	end
	return search_path_length
end

local function distance_to_class_y(cell, dy, class, grid, search_path_length)
	local cell_x, cell_y = cell.x, cell.y
	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x, cell_y + dy * i) then
			return search_path_length
		end
		local collision_list = grid:get_collisions_in_cell(cell_x, cell_y + dy * i)
		if #collision_list > 0 and list_has_class(class, collision_list) then
			return i
		end
	end
	return search_path_length
end

local function distance_in_front_class(cell, orientation, class, grid, search_path_length)
	if orientation == "up"    then return distance_to_class_y(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return distance_to_class_y(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return distance_to_class_x(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return distance_to_class_x(cell,  1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function distance_in_back_class(cell, orientation, class, grid, search_path_length)
	if orientation == "up"    then return distance_to_class_y(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return distance_to_class_y(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return distance_to_class_x(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return distance_to_class_x(cell, -1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function distance_in_left_class(cell, orientation, class, grid, search_path_length)
	if orientation == "up"    then return distance_to_class_x(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return distance_to_class_x(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return distance_to_class_y(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return distance_to_class_y(cell, -1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function distance_in_right_class(cell, orientation, class, grid, search_path_length)
	if orientation == "up"    then return distance_to_class_x(cell,  1, class, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return distance_to_class_x(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return distance_to_class_y(cell, -1, class, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return distance_to_class_y(cell,  1, class, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function find_collision_in_path_x(cell, dx, grid, search_path_length)
	local cell_x, cell_y = cell.x, cell.y
	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x + dx * i, cell_y) then return i end
	end
	return search_path_length
end

local function find_collision_in_path_y(cell, dy, grid, search_path_length)
	local cell_x, cell_y = cell.x, cell.y
	for i = 1, search_path_length do
		if grid:is_blocked_cell(cell_x, cell_y + dy * i) then return i end
	end
	return search_path_length
end

local function distance_in_front_collision(cell, orientation, grid, search_path_length)
	if orientation == "up"    then return find_collision_in_path_y(cell, -1, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return find_collision_in_path_y(cell,  1, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return find_collision_in_path_x(cell, -1, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return find_collision_in_path_x(cell,  1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function distance_in_left_collision(cell, orientation, grid, search_path_length)
	if orientation == "up"    then return find_collision_in_path_x(cell, -1, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return find_collision_in_path_x(cell,  1, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return find_collision_in_path_y(cell,  1, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return find_collision_in_path_y(cell, -1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function distance_in_right_collision(cell, orientation, grid, search_path_length)
	if orientation == "up"    then return find_collision_in_path_x(cell,  1, grid, search_path_length)/search_path_length
	elseif orientation == "down"  then return find_collision_in_path_x(cell, -1, grid, search_path_length)/search_path_length
	elseif orientation == "left"  then return find_collision_in_path_y(cell, -1, grid, search_path_length)/search_path_length
	elseif orientation == "right" then return find_collision_in_path_y(cell,  1, grid, search_path_length)/search_path_length
	end
	print("no orientation set", orientation)
end

local function is_front_valid(cell, orientation, grid)
	if orientation == "up"    then return grid:is_blocked_cell(cell.x,     cell.y - 1) and 0 or 1
	elseif orientation == "down"  then return grid:is_blocked_cell(cell.x,     cell.y + 1) and 0 or 1
	elseif orientation == "left"  then return grid:is_blocked_cell(cell.x - 1, cell.y    ) and 0 or 1
	elseif orientation == "right" then return grid:is_blocked_cell(cell.x + 1, cell.y    ) and 0 or 1
	end
	print("no orientation set", orientation)
end

local function is_left_valid(cell, orientation, grid)
	if orientation == "up"    then return grid:is_blocked_cell(cell.x - 1, cell.y    ) and 0 or 1
	elseif orientation == "down"  then return grid:is_blocked_cell(cell.x + 1, cell.y    ) and 0 or 1
	elseif orientation == "left"  then return grid:is_blocked_cell(cell.x,     cell.y + 1) and 0 or 1
	elseif orientation == "right" then return grid:is_blocked_cell(cell.x,     cell.y - 1) and 0 or 1
	end
	print("no orientation set", orientation)
end

local function is_right_valid(cell, orientation, grid)
	if orientation == "up"    then return grid:is_blocked_cell(cell.x + 1, cell.y    ) and 0 or 1
	elseif orientation == "down"  then return grid:is_blocked_cell(cell.x - 1, cell.y    ) and 0 or 1
	elseif orientation == "left"  then return grid:is_blocked_cell(cell.x,     cell.y - 1) and 0 or 1
	elseif orientation == "right" then return grid:is_blocked_cell(cell.x,     cell.y + 1) and 0 or 1
	end
	print("no orientation set", orientation)
end

-- grade_path_*: also needs ann to run the per-direction sub-network
local function grade_path_x(cell, ann, dx, grid, search_path_length, ghost_state)
	local inputs = {
		find_collision_in_path_x(cell, dx, grid, search_path_length)/search_path_length,
		distance_to_class_x(cell, dx, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_x(cell, dx, "pill",  grid, search_path_length)/search_path_length,
		(ghost_state == "frightened") and 1 or 0,
	}
	local outputs = ann:get_outputs(inputs, true)
	return outputs[1], inputs
end

local function grade_path_y(cell, ann, dy, grid, search_path_length, ghost_state)
	local inputs = {
		find_collision_in_path_y(cell, dy, grid, search_path_length)/search_path_length,
		distance_to_class_y(cell, dy, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_y(cell, dy, "pill",  grid, search_path_length)/search_path_length,
		(ghost_state == "frightened") and 1 or 0,
	}
	local outputs = ann:get_outputs(inputs, true)
	return outputs[1], inputs
end

-- can_see_class needs enabled_directions (which directions are open to move)
local function can_see_class(cell, enabled_directions, class, grid, search_path_length)
	local see_class = false
	local best_distance = search_path_length
	local best_direction_index

	for i = 1, 2 do
		if enabled_directions[i] then
			local d = distance_to_class_y(cell, (-1)^i, class, grid, search_path_length)
			if d < best_distance then
				see_class = true
				best_distance = d
				best_direction_index = i
			end
		end
	end
	for i = 3, 4 do
		if enabled_directions[i] then
			local d = distance_to_class_x(cell, (-1)^i, class, grid, search_path_length)
			if d < best_distance then
				see_class = true
				best_distance = d
				best_direction_index = i
			end
		end
	end

	if see_class then
		return true, best_distance, grid.directions[best_direction_index]
	else
		return false
	end
end

-- ── Direction-to-callback maps (pure) ────────────────────────────────────────

local function get_distance_callback_and_dxy_from_direction(direction)
	if direction == "up"    then return distance_to_class_y, -1
	elseif direction == "down"  then return distance_to_class_y,  1
	elseif direction == "left"  then return distance_to_class_x, -1
	elseif direction == "right" then return distance_to_class_x,  1
	elseif direction == "idle"  then return false
	else print("[ERROR] - AutoPlayerAnnModes get_distance_callback_and_dxy_from_direction() - invalid direction") end
end

local function get_grade_callback_and_dxy_from_direction(direction)
	if direction == "up"    then return grade_path_y, -1
	elseif direction == "down"  then return grade_path_y,  1
	elseif direction == "left"  then return grade_path_x, -1
	elseif direction == "right" then return grade_path_x,  1
	elseif direction == "idle"  then return false
	else print("[ERROR] - AutoPlayerAnnModes get_grade_callback_and_dxy_from_direction() - invalid direction") end
end

-- ── Baseline helpers (pure) ───────────────────────────────────────────────────

local function can_get_pill(cell, enabled_directions, current_direction, grid, search_path_length)
	local see_pill, pill_distance, pill_direction = can_see_class(cell, enabled_directions, "pill", grid, search_path_length)
	if see_pill then
		local distance_fn, dxy = get_distance_callback_and_dxy_from_direction(current_direction)
		if distance_fn and distance_fn(cell, dxy, "ghost", grid, search_path_length) > pill_distance then
			return true, pill_direction
		end
	end
	return false
end

local function is_direction_good(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
	local direction_index = grid.direction_to_index[current_direction]
	local distance_fn, dxy = get_distance_callback_and_dxy_from_direction(current_direction)

	if ghost_state == "frightened" then
		return enabled_directions[direction_index] == true
	else
		return enabled_directions[direction_index] == true
			and distance_fn(cell, dxy, "ghost", grid, search_path_length) > 3
	end
end

local function find_good_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
	local prefer_x = (current_direction == "up" or current_direction == "down")

	if ghost_state ~= "frightened" then
		for value = search_path_length, 0, -1 do
			if prefer_x then
				if enabled_directions[3] and distance_to_class_x(cell, -1, "ghost", grid, search_path_length) >= value then return "left"  end
				if enabled_directions[4] and distance_to_class_x(cell,  1, "ghost", grid, search_path_length) >= value then return "right" end
				if enabled_directions[1] and distance_to_class_y(cell, -1, "ghost", grid, search_path_length) >= value then return "up"    end
				if enabled_directions[2] and distance_to_class_y(cell,  1, "ghost", grid, search_path_length) >= value then return "down"  end
			else
				if enabled_directions[1] and distance_to_class_y(cell, -1, "ghost", grid, search_path_length) >= value then return "up"    end
				if enabled_directions[2] and distance_to_class_y(cell,  1, "ghost", grid, search_path_length) >= value then return "down"  end
				if enabled_directions[3] and distance_to_class_x(cell, -1, "ghost", grid, search_path_length) >= value then return "left"  end
				if enabled_directions[4] and distance_to_class_x(cell,  1, "ghost", grid, search_path_length) >= value then return "right" end
			end
		end
	else
		for value = 0, search_path_length, 1 do
			if prefer_x then
				if enabled_directions[3] and distance_to_class_x(cell, -1, "ghost", grid, search_path_length) < value then return "left"  end
				if enabled_directions[4] and distance_to_class_x(cell,  1, "ghost", grid, search_path_length) < value then return "right" end
				if enabled_directions[1] and distance_to_class_y(cell, -1, "ghost", grid, search_path_length) < value then return "up"    end
				if enabled_directions[2] and distance_to_class_y(cell,  1, "ghost", grid, search_path_length) < value then return "down"  end
			else
				if enabled_directions[1] and distance_to_class_y(cell, -1, "ghost", grid, search_path_length) < value then return "up"    end
				if enabled_directions[2] and distance_to_class_y(cell,  1, "ghost", grid, search_path_length) < value then return "down"  end
				if enabled_directions[3] and distance_to_class_x(cell, -1, "ghost", grid, search_path_length) < value then return "left"  end
				if enabled_directions[4] and distance_to_class_x(cell,  1, "ghost", grid, search_path_length) < value then return "right" end
			end
		end
	end

	return nil
end

local function get_baseline_next_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
	if is_direction_good(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length) then
		return current_direction
	end
	return find_good_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
		or grid:get_random_valid_direction(cell.x, cell.y)
end

local function get_baseline_pill_next_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
	if ghost_state ~= "frightened" then
		local found_pill, pill_direction = can_get_pill(cell, enabled_directions, current_direction, grid, search_path_length)
		if found_pill then return pill_direction end
	end
	return get_baseline_next_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
end

local function get_baseline_pill_ghost_next_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
	if ghost_state == "frightened" then
		local found_ghost, _, ghost_direction = can_see_class(cell, enabled_directions, "ghost", grid, search_path_length)
		if found_ghost then return ghost_direction end
	end
	return get_baseline_pill_next_direction(cell, enabled_directions, current_direction, ghost_state, grid, search_path_length)
end

-- ── Random direction helpers (pure, no state) ─────────────────────────────────

local function get_random_direction()
	return qpd.random.choose("up", "down", "left", "right")
end

local function get_different_random_direction(current_direction)
	if current_direction == "up"    then return qpd.random.choose("down", "left", "right")
	elseif current_direction == "down"  then return qpd.random.choose("up",   "left", "right")
	elseif current_direction == "left"  then return qpd.random.choose("up",   "down", "right")
	elseif current_direction == "right" then return qpd.random.choose("up",   "down", "left")
	end
	return qpd.random.choose("up", "down", "left", "right")
end

-- ── grade_path helper (pure) ──────────────────────────────────────────────────

local function get_direction_grade(cell, ann, direction, grid, search_path_length, ghost_state)
	local callback, dxy = get_grade_callback_and_dxy_from_direction(direction)
	return callback(cell, ann, dxy, grid, search_path_length, ghost_state)
end

-- ── ANN update modes ──────────────────────────────────────────────────────────
-- Each update function still takes (self, ...) — self is the AutoPlayer entity.
-- It extracts cell/orientation/ann at the top, calls pure helpers, then writes
-- self._orientation and self._next_direction back at the end.

AutoplayerAnnModes.update.b1 = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local inputs = {
		is_left_valid(cell, orientation, grid),
		distance_in_front_collision(cell, orientation, grid, search_path_length),
		is_right_valid(cell, orientation, grid),
		distance_in_front_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_back_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_left_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_right_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_front_class(cell, orientation, "pill",  grid, search_path_length),
		distance_in_back_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_left_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_right_class(cell, orientation, "pill",  grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0,
	}

	local outputs = ann:get_outputs(inputs)
	if outputs[1] == 1 then orientation = rotate_left_dir(orientation) end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.b2 = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local inputs = {
		is_left_valid(cell, orientation, grid),
		distance_in_front_collision(cell, orientation, grid, search_path_length),
		is_right_valid(cell, orientation, grid),
		distance_in_front_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_back_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_left_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_right_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_front_class(cell, orientation, "pill",  grid, search_path_length),
		distance_in_back_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_left_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_right_class(cell, orientation, "pill",  grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0,
	}

	local outputs = ann:get_outputs(inputs)
	if outputs[1] == 1 then orientation = flip_dir(orientation) end
	if outputs[2] == 1 then orientation = rotate_left_dir(orientation) end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.b3 = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local inputs = {
		is_left_valid(cell, orientation, grid),
		distance_in_front_collision(cell, orientation, grid, search_path_length),
		is_right_valid(cell, orientation, grid),
		distance_in_front_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_back_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_left_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_right_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_front_class(cell, orientation, "pill",  grid, search_path_length),
		distance_in_back_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_left_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_right_class(cell, orientation, "pill",  grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0,
	}

	local outputs = ann:get_outputs(inputs)
	if outputs[1] == 1 then orientation = flip_dir(orientation) end
	if outputs[2] == 1 then orientation = rotate_left_dir(orientation) end
	if outputs[3] == 1 then orientation = rotate_left_dir(orientation) end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.nb4 = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local inputs = {
		is_left_valid(cell, orientation, grid),
		distance_in_front_collision(cell, orientation, grid, search_path_length),
		is_right_valid(cell, orientation, grid),
		distance_in_front_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_back_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_left_class(cell,  orientation, "ghost", grid, search_path_length),
		distance_in_right_class(cell, orientation, "ghost", grid, search_path_length),
		distance_in_front_class(cell, orientation, "pill",  grid, search_path_length),
		distance_in_back_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_left_class(cell,  orientation, "pill",  grid, search_path_length),
		distance_in_right_class(cell, orientation, "pill",  grid, search_path_length),
		(ghost_state == "frightened") and 1 or 0,
	}

	local outputs = ann:get_outputs(inputs)

	local greatest_index, greatest_value = 1, outputs[1]
	for i = 2, #outputs do
		if outputs[i] > greatest_value then
			greatest_index = i
			greatest_value = outputs[i]
		end
	end

	if     greatest_index == 2 then orientation = flip_dir(orientation)
	elseif greatest_index == 3 then orientation = rotate_left_dir(orientation)
	elseif greatest_index == 4 then orientation = rotate_right_dir(orientation)
	-- greatest_index == 1: keep orientation
	end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.nb4_flat = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local prev_direction = self._next_direction   -- flat mode uses the previous decision as input

	local inputs = {
		(prev_direction == "up")    and 1 or 0,
		(prev_direction == "down")  and 1 or 0,
		(prev_direction == "left")  and 1 or 0,
		(prev_direction == "right") and 1 or 0,
		find_collision_in_path_y(cell, -1, grid, search_path_length)/search_path_length,
		find_collision_in_path_y(cell,  1, grid, search_path_length)/search_path_length,
		find_collision_in_path_x(cell, -1, grid, search_path_length)/search_path_length,
		find_collision_in_path_x(cell,  1, grid, search_path_length)/search_path_length,
		distance_to_class_y(cell, -1, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_y(cell,  1, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_x(cell, -1, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_x(cell,  1, "ghost", grid, search_path_length)/search_path_length,
		distance_to_class_y(cell, -1, "pill",  grid, search_path_length)/search_path_length,
		distance_to_class_y(cell,  1, "pill",  grid, search_path_length)/search_path_length,
		distance_to_class_x(cell, -1, "pill",  grid, search_path_length)/search_path_length,
		distance_to_class_x(cell,  1, "pill",  grid, search_path_length)/search_path_length,
		(ghost_state == "frightened") and 1 or 0,
	}

	local outputs = ann:get_outputs(inputs)

	local greatest_index, greatest_value = 1, outputs[1]
	for i = 2, #outputs do
		if outputs[i] > greatest_value then
			greatest_index = i
			greatest_value = outputs[i]
		end
	end

	local orientation
	if     greatest_index == 1 then orientation = "up"
	elseif greatest_index == 2 then orientation = "down"
	elseif greatest_index == 3 then orientation = "left"
	elseif greatest_index == 4 then orientation = "right"
	end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.b1_path_grading = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local callback, dxy = get_grade_callback_and_dxy_from_direction(orientation)
	local grade = callback(cell, ann, dxy, grid, search_path_length, ghost_state)

	if grade == 1 then
		orientation = rotate_left_dir(orientation)
		self._orientation    = orientation
		self._next_direction = orientation
	end
end

AutoplayerAnnModes.update.b1_path_grading_simple = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	for _ = 1, 4 do
		local callback, dxy = get_grade_callback_and_dxy_from_direction(orientation)
		local grade = callback(cell, ann, dxy, grid, search_path_length, ghost_state)
		if grade == 1 then
			orientation = rotate_left_dir(orientation)
			self._next_direction = orientation
		else
			self._orientation    = orientation
			self._next_direction = orientation
			return
		end
	end
	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.b1_path_grading_hack = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	local orientation = self._orientation

	local grade = get_direction_grade(cell, ann, orientation, grid, search_path_length, ghost_state)
	if grade == 1 then
		local left = rotate_left_dir(orientation)
		if get_direction_grade(cell, ann, left, grid, search_path_length, ghost_state) == 0 then
			orientation = left
		else
			local right = rotate_right_dir(orientation)
			if get_direction_grade(cell, ann, right, grid, search_path_length, ghost_state) == 0 then
				orientation = right
			else
				orientation = flip_dir(orientation)
			end
		end
	end

	self._orientation    = orientation
	self._next_direction = orientation
end

AutoplayerAnnModes.update.nb4_path_grading = function (self, grid, search_path_length, ghost_state)
	local cell, ann = self._cell, self._ann
	self._orientation = self._direction  -- sync orientation (cosmetic)

	local enabled_directions = self:get_enabled_directions()
	local available_paths = {}
	if enabled_directions[1] then table.insert(available_paths, { grade = grade_path_y(cell, ann, -1, grid, search_path_length, ghost_state), direction = "up"    }) end
	if enabled_directions[2] then table.insert(available_paths, { grade = grade_path_y(cell, ann,  1, grid, search_path_length, ghost_state), direction = "down"  }) end
	if enabled_directions[3] then table.insert(available_paths, { grade = grade_path_x(cell, ann, -1, grid, search_path_length, ghost_state), direction = "left"  }) end
	if enabled_directions[4] then table.insert(available_paths, { grade = grade_path_x(cell, ann,  1, grid, search_path_length, ghost_state), direction = "right" }) end

	local old_direction = self._direction
	local best_index, best_grade

	if #available_paths >= 2 then
		-- Prefer to keep going in the same direction unless a strictly better path exists.
		if old_direction ~= "idle" then
			for i = 1, #available_paths do
				if available_paths[i].direction == old_direction then best_index = i end
			end
		end
		best_index = best_index or 1
		best_grade = available_paths[best_index].grade
		for i = 1, #available_paths do
			if available_paths[i].grade > best_grade then
				best_grade = available_paths[i].grade
				best_index = i
			end
		end
		self._next_direction = available_paths[best_index].direction
	elseif #available_paths >= 1 then
		self._next_direction = available_paths[1].direction
	else
		print("AutoPlayer has nowhere to go!")
	end
end

-- ── Baseline update modes ─────────────────────────────────────────────────────

AutoplayerAnnModes.update.baseline = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline
	local cell, enabled_directions = self._cell, self:get_enabled_directions()
	self._next_direction = get_baseline_next_direction(cell, enabled_directions, self._direction, ghost_state, grid, search_path_length)
end

AutoplayerAnnModes.update.baseline_pill = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_pill
	local cell, enabled_directions = self._cell, self:get_enabled_directions()
	self._next_direction = get_baseline_pill_next_direction(cell, enabled_directions, self._direction, ghost_state, grid, search_path_length)
end

AutoplayerAnnModes.update.baseline_pill_ghost = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_pill_ghost
	local cell, enabled_directions = self._cell, self:get_enabled_directions()
	self._next_direction = get_baseline_pill_ghost_next_direction(cell, enabled_directions, self._direction, ghost_state, grid, search_path_length)
end

AutoplayerAnnModes.update.baseline_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_random
	local cell, enabled_directions = self._cell, self:get_enabled_directions()
	if is_direction_good(cell, enabled_directions, self._direction, ghost_state, grid, search_path_length) then
		return
	end
	self._next_direction = get_different_random_direction(self._direction)
end

AutoplayerAnnModes.update.baseline_full_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_full_random
	self._next_direction = get_random_direction()
end

AutoplayerAnnModes.update.baseline_collide_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_collide_random
	if self._direction == "idle" then
		self._next_direction = get_different_random_direction(self._direction)
	end
end

AutoplayerAnnModes.update.baseline_valid_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_valid_random
	local cell, enabled_directions = self._cell, self:get_enabled_directions()
	if is_direction_good(cell, enabled_directions, self._direction, ghost_state, grid, search_path_length) then
		return
	end
	self:set_different_random_valid_direction()
end

AutoplayerAnnModes.update.baseline_valid_full_random = function (self, grid, search_path_length, ghost_state)
-- autoplayer_update_mode = baseline_valid_full_random
	self:set_random_valid_direction()
end

return AutoplayerAnnModes
