local Population = require "entities.Population"
local qpd = require "qpd.qpd"

local GeneticPopulation = {}
GeneticPopulation.__index = GeneticPopulation
qpd.table.assign_methods(GeneticPopulation, Population)

function GeneticPopulation:new(class, active_size, initial_random_population_size, population_history_size, specie_niche_initial_population_size, specie_niche_population_history_size, specie_mule_start, specie_all_roulette_start, specie_threshold, player_caugh_callback, reset_table, o)
	local o = o or {}
	setmetatable(o, self)

	o._fitness_attribute = "_fitness"

	o._class = class
	o._speciatable = o._class._speciatable
	o._player_caught_callback = player_caugh_callback
	if o._speciatable then
		o._species = {}
		o._specie_niche = {}
		o._specie_niche_count = {}
		o._specie_history_count = {}
		o._specie_initial_population_size = specie_niche_initial_population_size or math.max(initial_random_population_size/10, 30)
		o._specie_population_history_size = specie_niche_population_history_size or math.max(initial_random_population_size/10, 30)
		o._specie_mule_start = specie_mule_start
		o._specie_all_roulette_start = specie_all_roulette_start
		o._specie_threshold = specie_threshold
	else
		o._species = nil
		o._specie_niche = nil
	end

	o._active_size = active_size
	o._initial_random_population_size = initial_random_population_size
	o._random_init = initial_random_population_size
	o._genetic_population_size = population_history_size
	o._genetics_enabled = population_history_size and true or false
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
			local new_specie = o._population[i]:get_ann():speciate(o:get_species(), o._specie_threshold)
			if new_specie then
				o:new_specie(new_specie)
			end
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

function GeneticPopulation:set_new_speciation(value)
	print("new speciation still not backported")
end

function GeneticPopulation:add_to_history(actor)
	local actor_history = actor:get_history()

	-- history count
	if self._speciatable then
		local added_species_id = actor_history._specie_id -- we add first to not extinguish if species are the same
		self._specie_history_count[added_species_id] = self._specie_history_count[added_species_id] + 1

		local this_ann = actor:get_ann()
		this_ann._specie:add_to_history(actor, self._specie_population_history_size)
	end

	if #self._history > self._genetic_population_size then
		local lowest, lowest_index = qpd.table.get_lowest(self._history, self._fitness_attribute)

		if actor_history._fitness > lowest._fitness then
			-- history count
			if self._speciatable then
				local removed_species_id = lowest._specie_id
				self._specie_history_count[removed_species_id] = self._specie_history_count[removed_species_id] - 1
				self:check_extinct(removed_species_id)
			end

			-- history
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
	local dad
	if self._speciatable then
		local specie = self._species[mom._specie_id]
		dad = specie:roulette()
	else
		dad = self:_roulette(everybody)
	end

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

	if self._player_caught_callback and (this_actor:type() == "player") then
		self:_player_caught_callback()
	end

	-- replace
	if self._random_init > 0 then
		self._random_init = self._random_init - 1
		this_actor:reset(self:get_reset_table())
	elseif self._speciatable and #self._specie_niche > 0 then
		local specie = self._specie_niche[#self._specie_niche]
		local specie_id = specie:get_id()
		local mom = specie:get_leader()
		local dad = specie:roulette()
		this_actor:crossover(mom, dad, self:get_reset_table())
		self._specie_niche[#self._specie_niche] = nil
		self._specie_niche_count[specie_id] = self._specie_niche_count[specie_id] - 1
		self:check_extinct(specie_id)

		-- speciate
		local new_specie = this_actor:get_ann():speciate(self:get_species(), self._specie_threshold)
		self:new_specie(new_specie)
		if new_specie then
			print("[WARN] - Speciating in speciation niche!")
		end
	else
		-- find parents
		local mom, dad = self:_selection()

		-- cross
		this_actor:crossover(mom, dad, self:get_reset_table())
	end

	-- speciate
	if self._speciatable then
		local new_specie = this_actor:get_ann():speciate(self:get_species(), self._specie_threshold)
		self:new_specie(new_specie)
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

function GeneticPopulation:new_specie(new_specie)
	if new_specie then
		local new_specie_id = new_specie:get_id()
		self._specie_history_count[new_specie_id] = 0
		self._specie_niche_count[new_specie_id] = 0
		for _ = 1, self._specie_initial_population_size do
			self._specie_niche[#self._specie_niche + 1] = new_specie
			self._specie_niche_count[new_specie_id] = self._specie_niche_count[new_specie:get_id()] + 1
		end
	end
end

function GeneticPopulation:check_extinct(specie_id)
	if self._specie_niche_count[specie_id] == 0 then
		if self._specie_history_count[specie_id] <= 0 then
			self._species[specie_id]:purge()
			self._species[specie_id] = false
		end
	end
end

return GeneticPopulation