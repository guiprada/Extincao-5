local Population = require "entities.Population"
local qpd = require "qpd.qpd"

local GeneticPopulation = {}
GeneticPopulation.__index = GeneticPopulation
qpd.table.assign_methods(GeneticPopulation, Population)

function GeneticPopulation:new(class, active_size, population_size, genetic_population_size, new_table, reset_table, o)
	local o = o or {}
	setmetatable(o, self)

	o._fitness_attribute = "_fitness"

	o._class = class
	o._active_size = active_size
	o._population_size = population_size
	o._random_init = population_size
	o._genetic_population_size = genetic_population_size
	o._new_table = o._new_table
	o._reset_table = reset_table

	o._population = {}
	o._history = {}
	o._history_fitness_sum = 0
	o._count = 0

	for i = 1, o._active_size do
		o._population[i] = o._class:new(o._new_table)
		o._population[i]:reset(o:get_reset_table())
		o._count = o._count + 1
	end

	return o
end

function GeneticPopulation:set_fitness_attribute(value)
	self._fitness_attribute = value
end

function GeneticPopulation:set_neat_selection(value)
	self._neat_selection = value or true
end

function GeneticPopulation:set_neat_mode(value)
	self:set_fitness_attribute("_own_fitness")
	self:set_neat_selection(true)
end

function GeneticPopulation:add_to_history(actor)
	local actor_history = actor:get_history()

	-- if #self._history > math.floor(self._population_size/10) then
	if #self._history > self._genetic_population_size then
		local lowest, lowest_index = qpd.table.get_lowest(self._history, self._fitness_attribute)

		if actor_history._fitness > lowest._fitness then
			self._history_fitness_sum = self._history_fitness_sum - lowest._fitness

			self._history[lowest_index] = actor_history
			self._history_fitness_sum = self._history_fitness_sum + actor_history._fitness
		end
	else
		table.insert(self._history, actor_history)
		self._history_fitness_sum = self._history_fitness_sum + actor_history._fitness
	end
end

 function GeneticPopulation:_roulette(population, total_fitness)
	local total_fitness = total_fitness or qpd.table.sum(population, self._fitness_attribute)
	local slice = total_fitness * qpd.random.random()
	local sum = 0

	for _, actor in ipairs(population) do
		sum = sum + actor._fitness
		if (sum >= slice) then
			return actor
		end
	end

	print("[WARN] - GeneticPopulation:_roulette() - Returning last actor!")
	return population[#population]

-- SGenome& CgaBob::RouletteWheelSelection() { //(BUCKLAND, 113)
--	double fSlice = RandFloat() * m_dTotalFitnessScore;
--	double cfTotal = 0;
--	int SelectedGenome = 0;
--
--	for (int i=0; i<m_iPopSize; ++i) {
--		cfTotal += m_vecGenomes[i].dFitness;
--		if (cfTotal > fSlice) {
--			SelectedGenome = i;
--			break;
--		}
--	}
--
--	return m_vecGenomes[SelectedGenome];
-- }
end

function GeneticPopulation:_selection()
	local everybody = qpd.table.clone(self._history)

	-- add living actors
	for _, actor in ipairs(self._population) do
		if actor and actor._is_active then
			table.insert(everybody, actor)
		end
	end

	local mom = self:_roulette(everybody)
	local dad = self:_roulette(everybody)
	if not (mom and dad) then
		print("[WARN] - GeneticPopulation:_selection() - Did not get an actor from roulette(), choosing randomly!")
		mom = mom or self._history[#self._population]
		dad = dad or self._history[#self._history]
		print(string.format("mom: %s  | dad: %s", mom, dad))
	end

	if self._neat_selection then
		-- Use the best fitness genome as base, if they have equal fitness them use the shortest
		if mom[self._fitness_attribute] < dad[self._fitness_attribute] then
			mom, dad = dad, mom
		elseif mom[self._fitness_attribute] == dad[self._fitness_attribute] then
			-- they have equal fitness
			if mom:gene_count() > dad:gene_count() then
				mom, dad = dad, mom
			end
		end
	end

	return mom, dad
end

function GeneticPopulation:replace(i)
	self._count = self._count + 1
	self:add_to_history(self._population[i])

	if self._random_init > 0 then
		self._random_init = self._random_init - 1
		self._population[i]:reset(self:get_reset_table())
	else
		-- find parents
		local mom, dad = self:_selection()

		-- cross
		self._population[i]:crossover(mom, dad, self:get_reset_table())
	end
end

function GeneticPopulation:add_active()
	self._active_size = self._active_size + 1
	local i = self._active_size
	self._population[i] = self._class:new(self._new_table)

	if self._random_init > 0 then
		self._random_init = self._random_init - 1
		self._population[i]:reset(self:get_reset_table())
	else
		-- find parents
		local mom, dad = self:_selection()
		-- cross
		self._population[i]:crossover(mom, dad, self:get_reset_table())
	end
end

return GeneticPopulation