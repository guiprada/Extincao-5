local Population = require "entities.Population"
local qpd = require "qpd.qpd"

local GeneticPopulation = {}
GeneticPopulation.__index = GeneticPopulation
qpd.table.assign_methods(GeneticPopulation, Population)

function GeneticPopulation:new(class, active_size, population_size, genetic_population_size, reset_table, o)
	local o = o or {}
	setmetatable(o, self)

	o._fitness_attribute = "_fitness"

	o._class = class
	o._speciatable = o._class._speciatable
	if o._speciatable then
		self._species = {}
		self._specie_niche = {}
	else
		self._species = nil
	end

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

		if o._speciatable then
			o._population[i]:get_ann():speciate(self:get_species())
		end

		o._count = o._count + 1
	end



	return o
end

function GeneticPopulation:get_species()
	return self._species
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
			local actor_history = actor:get_history()
			table.insert(everybody, actor_history)
		end
	end

	local mom = self:_roulette(everybody)
	local dad = self:_roulette(everybody)

	if not (mom and dad) then
		print("[WARN] - GeneticPopulation:_selection() - Did not get an actor from roulette(), choosing randomly!")
		mom = mom or everybody[qpd.random.random(#everybody)]
		dad = dad or everybody[qpd.random.random(#everybody)]
		print(string.format("mom: %s  | dad: %s", mom, dad))
	end

	if self._neat_selection then
		-- Use the best fitness genome as base, if they have equal fitness them use the shortest
		if mom[self._fitness_attribute] < dad[self._fitness_attribute] then
			mom, dad = dad, mom
		elseif mom[self._fitness_attribute] == dad[self._fitness_attribute] then
			-- they have equal fitness
			if mom._genome:get_gene_count() > dad._genome:get_gene_count() then
				mom, dad = dad, mom
			end
		end
	end

	return mom, dad
end

function GeneticPopulation:replace(i)
	self._count = self._count + 1

	local this_actor = self._population[i]
	self:add_to_history(this_actor)

	-- speciate
	if self._speciatable then
		local new_specie = this_actor:get_ann():speciate(self:get_species())
		if new_specie then
			for _ = 1, self._population_size do
				self._specie_niche[#self._specie_niche + 1] = new_specie
			end
		end

		local this_ann = self._population[i]:get_ann()
		this_ann._specie:add_to_history(this_actor)
	end

	-- replace
	if self._random_init > 0 then
		self._random_init = self._random_init - 1
		this_actor:reset(self:get_reset_table())
	elseif self._speciatable and #self._specie_niche > 0 then
		local specie = self._specie_niche[#self._specie_niche]
		local mom = specie:get_leader()
		local dad = specie:get_member() or mom
		this_actor:crossover(mom, dad, self:get_reset_table())
		self._specie_niche[#self._specie_niche] = nil

		-- speciate
		local new_specie = this_actor:get_ann():speciate(self:get_species())
		if new_specie then
			print("[WARN] - Speciating in speciation niche!")
			for i = 1, self._population_size do
				self._specie_niche[#self._specie_niche + 1] = new_specie
			end
		end
	else
		-- remove from species
		-- if self._class._speciatable then
		-- 	this_actor:get_ann():remove_from_species(self:get_species())
		-- end

		-- find parents
		local mom, dad = self:_selection()

		-- cross
		this_actor:crossover(mom, dad, self:get_reset_table())
	end
end

function GeneticPopulation:add_active()
	self._active_size = self._active_size + 1
	local i = self._active_size
	local this_actor = self._population[i]
	this_actor = self._class:new(self._new_table)

	if self._random_init > 0 then
		self._random_init = self._random_init - 1
		this_actor:reset(self:get_reset_table())
	else
		-- find parents
		local mom, dad = self:_selection()

		-- cross
		this_actor:crossover(mom, dad, self:get_reset_table())
	end
end

return GeneticPopulation