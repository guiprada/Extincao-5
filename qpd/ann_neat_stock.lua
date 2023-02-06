-- Guilherme Cunha Prada 2022
local NEAT = {}
NEAT.__index = NEAT

local qpd_table = require "qpd.table"
local qpd_random = require "qpd.random"
local ann_activation_functions = require "qpd.ann_activation_functions"

local LEARNING_RATE = 0.1

function NEAT.set_learning_rate(learning_rate)
	LEARNING_RATE = learning_rate
end

------------------------------------------------------------------------------- Types
local _link_types = {
	"forward",
	"recurrent",
	"looped_recurrent"
}

local _neuron_types = {
	"input",
	"hidden",
	"bias",
	"output",
	"none",
}

local _ann_run_types = {
	"snapshot",
	"active"
-- you have to select one of these types when updating the network
-- If snapshot is chosen the network depth is used to completely
-- flush the inputs through the network. active just updates the
-- network each time-step
}

-- Internal Classes
-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Link
local _Link_Gene = {}

function _Link_Gene:new(from_neuron, to_neuron, weight, enabled, recurrent, innovation_id, o)
	local o = o or {}
	setmetatable(o, self)

	o._from_neuron = from_neuron
	o._to_neuron = to_neuron
	o._weight = weight
	o._enabled = enabled
	o._recurrent = recurrent
	o._innovation_id = innovation_id

	return o
end

-------------------------------------------------------------------------------
local _Link = {}

function _Link:new(input, output, weight, recurrent, o)
	local o = o or {}
	setmetatable(o, self)

	o._in = input
	o._out = output
	o._weight = weight
	o._recurrent = recurrent

	return o
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Neuron
local _Neuron_Gene = {}

function _Neuron_Gene:new(id, type, recurrent, activation_response, x, y, o)
	local o = o or {}
	setmetatable(o, self)

	o._id = id
	o._type = type
	o._recurrent = recurrent
	o._activation_response = activation_response
	o._x = x
	o._y = y

	return o
end

-------------------------------------------------------------------------------
local _Neuron = {}

function _Neuron:new(input_links, output_links, id, type, activation_response, x, y, split_x, split_y, o)
	local o = o or {}
	setmetatable(o, self)

	o._input_links = input_links
	o._output_links = output_links

	o._type = type
	o._id = id
	o._activation_responste = activation_response

	o._x = x
	o._y = y
	o._splix_x = split_x
	o._splix_y = split_y

	o._activation_sum = false
	o._activation_output = false

	return o
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Innovation
local _Innovation = {}

local _innovation_id_count = 0
_Innovation.types = {
	"link", "neuron"
}

function  _Innovation:new_link(neuron_in, neuron_out, o)
	local o = o or {}
	setmetatable(o, self)

	o._type = "link"

	_innovation_id_count = _innovation_id_count + 1
	o._id = _innovation_id_count
	o._neuron_in = neuron_in
	o._neuron_out = neuron_out

	return o
end

function  _Innovation:new_neuron(neuron_type, o)
	local o = o or {}
	setmetatable(o, self)

	o._type = "neuron"

	_innovation_id_count = _innovation_id_count + 1
	o._id = _innovation_id_count
	o._neuron_type = neuron_type

	return o
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Species
local _Species = {}

local _species_count = 0

function _Species:new(leader, o)
	local o = o or {}
	setmetatable(o, self)

	o._leader = leader
	o._specimes = {}
	_species_count = _species_count + 1
	o._id = _species_count
	o._best_fitness = o._leader:get_fitness()
	o._av_fitness = o._best_fitness
	o._generations_with_no_fitness_improvement = 0
	o._age = 0
	o._required_spawns = 0

	return o
end

function _Species:adjusted_fitnesses()
-- this method boosts the fitnesses of the young, penalizes the
-- fitnesses of the old and then performs fitness sharing over
-- all the members of the species(BUCKLAND, 392)

-- 	void CSpecies::AdjustFitnesses()
-- 	{
-- 		double total = 0;
-- 		for (int gen=0; gen<m_vecMembers.size(); ++gen) {
-- 			double fitness = m_vecMembers[gen]->Fitness();
--
-- 			//boost the fitness scores if the species is young
-- 			if (m_iAge < CParams::iYoungBonusAgeThreshhold) {
-- 				fitness *= CParams::dYoungFitnessBonus;
-- 			}
--
-- 			//punish older species
-- 			if (m_iAge > CParams::iOldAgeThreshold) {
-- 				fitness *= CParams::dOldAgePenalty;
-- 			}
--
-- 			total += fitness;
--
-- 			//apply fitness sharing to adjusted fitnesses
-- 			double AdjustedFitness = fitness/m_vecMembers.size();
-- 			m_vecMembers[gen]->SetAdjFitness(AdjustedFitness);
-- 		}
-- 	}
end

function _Species:add_member(new_genome)
end

function _Species:purge()
end

function _Species:calculate_spawn_amount()
	-- calculates how many offspring this species should spawn
end

function _Species:spawn()
-- spawns an individual from the species selected at random
-- from the best CParams::dSurvivalRate percent
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- ANN
local _ANN = {}

function _ANN:new(neurons, depth, o)
	local o = o or {}
	setmetatable(o, self)

	o._neurons = neurons
	o._depth = depth

	return o
end

function _ANN:update(inputs, run_type)
	-- update network for this clock cycle(BUCKLAND, 407)

-- 	vector<double> CNeuralNet::Update(const vector<double> &inputs, const run_type type)
-- 	{
-- 		//create a vector to put the outputs into
-- 		vector<double> outputs;
--
-- 		//if the mode is snapshot then we require all the neurons to be
-- 		//iterated through as many times as the network is deep. If the
-- 		//mode is set to active the method can return an output after
-- 		//just one iteration
-- 		int FlushCount = 0;
--
-- 		if (type == snapshot) {
-- 			FlushCount = m_iDepth;
-- 		} else {
-- 			FlushCount = 1;
-- 		}
--
-- 		//iterate through the network FlushCount times
-- 		for (int i=0; i<FlushCount; ++i) {
-- 			//clear the output vector
-- 			outputs.clear();
-- 			//this is an index into the current neuron
-- 			int cNeuron = 0;
--
-- 			//first set the outputs of the 'input' neurons to be equal
-- 			//to the values passed into the function in inputs
-- 			while (m_vecpNeurons[cNeuron]->NeuronType == input) {
-- 				m_vecpNeurons[cNeuron]->dOutput = inputs[cNeuron];
-- 				++cNeuron;
-- 			}
--
-- 			//set the output of the bias to 1
-- 			m_vecpNeurons[cNeuron++]->dOutput = 1;
--
-- 			//then we step through the network a neuron at a time
-- 			while (cNeuron < m_vecpNeurons.size()) {
-- 				//this will hold the sum of all the inputs x weights
-- 				double sum = 0;
--
-- 				//sum this neuron's inputs by iterating through all the links into
-- 				//the neuron
-- 				for (int lnk=0; lnk<m_vecpNeurons[cNeuron]->vecLinksIn.size(); ++lnk) {
-- 					//get this link's weight
-- 					double Weight = m_vecpNeurons[cNeuron]->vecLinksIn[lnk].dWeight;
--
-- 					//get the output from the neuron this link is coming from
-- 					double NeuronOutput = m_vecpNeurons[cNeuron]->vecLinksIn[lnk].pIn->dOutput;
--
-- 					//add to sum
-- 					sum += Weight * NeuronOutput;
-- 				}
--
-- 				//now put the sum through the activation function and assign the
-- 				//value to this neuron's output
-- 				m_vecpNeurons[cNeuron]->dOutput = Sigmoid(sum, m_vecpNeurons[cNeuron]->dActivationResponse);
--
-- 				if (m_vecpNeurons[cNeuron]->NeuronType == output) {
-- 					//add to our outputs
-- 					outputs.push_back(m_vecpNeurons[cNeuron]->dOutput);
-- 				}
--
-- 				//next neuron
-- 				++cNeuron;
-- 			}
-- 		}//next iteration through the network
--
-- 		//the network outputs need to be reset if this type of update is performed
-- 		//otherwise it is possible for dependencies to be built on the order
-- 		//the training data is presented
-- 		if (type == snapshot) {
-- 			for (int n=0; n<m_vecpNeurons.size(); ++n) {
-- 				m_vecpNeurons[n]->dOutput = 0;
-- 			}
-- 		}
--
-- 		//return the outputs
-- 		return outputs;
-- }
end

function _ANN:draw()
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- Genome
local _Genome = {}

function _Genome:new(n_inputs, n_outputs, id, neurons, links, fenotype, o)
	local o = o or {}
	setmetatable(o, self)

	o._id = id
	o._neurons = neurons
	o._links = links

	o._fenotype = o:create_fenotype()
	o._fitness = 0
	o._adjusted_fitness = 0
	o._amount_to_spawn = 0

	o._n_inputs = n_inputs
	o._n_outputs = n_outputs

	return o
end

function _Genome:create_fenotype()
	-- (BUCKLAND, 402)

-- 	CNeuralNet* CGenome::CreatePhenotype(int depth)
-- 	{
-- 		//first make sure there is no existing phenotype for this genome
-- 		DeletePhenotype();
--
-- 		//this will hold all the neurons required for the phenotype
-- 		vector<SNeuron*> vecNeurons;
-- 		//first, create all the required neurons
-- 		for (int i=0; i<m_vecNeurons.size(); i++) {
-- 			SNeuron* pNeuron = new SNeuron(m_vecNeurons[i].NeuronType,
-- 			m_vecNeurons[i].iID,
-- 			m_vecNeurons[i].dSplitY,
-- 			m_vecNeurons[i].dSplitX,
-- 			m_vecNeurons[i].dActivationResponse);
-- 			vecNeurons.push_back(pNeuron);
-- 		}
--
-- 		//now to create the links.
-- 		for (int cGene=0; cGene<m_vecLinks.size(); ++cGene) {
-- 			//make sure the link gene is enabled before the connection is created
-- 			if (m_vecLinks[cGene].bEnabled) {
-- 				//get the pointers to the relevant neurons
-- 				int element = GetElementPos(m_vecLinks[cGene].FromNeuron);
-- 				SNeuron* FromNeuron = vecNeurons[element];
-- 				element = GetElementPos(m_vecLinks[cGene].ToNeuron);
-- 				SNeuron* ToNeuron = vecNeurons[element];
--
-- 				//create a link between those two neurons and assign the weight stored
-- 				//in the gene
-- 				SLink tmpLink(m_vecLinks[cGene].dWeight,
-- 					FromNeuron,
-- 					ToNeuron,
-- 					m_vecLinks[cGene].bRecurrent);
--
-- 				//add new links to neuron
-- 				FromNeuron->vecLinksOut.push_back(tmpLink);
-- 				ToNeuron->vecLinksIn.push_back(tmpLink);
-- 			}
-- 		}
-- 		//now the neurons contain all the connectivity information, a neural
-- 		//network may be created from them.
-- 		m_pPhenotype = new CNeuralNet(vecNeurons, depth);
--
-- 		return m_pPhenotype;
-- 	}
end

function _Genome:add_link()
	-- add a link to the genome dependent upon the mutation rate(BUCKLAND, 368)

--	void CGenome::AddLink(
--		double MutationRate,
--		double ChanceOfLooped,
--  	CInnovation &innovation, //the database of innovations
--  	int NumTrysToFindLoop,
--  	int NumTrysToAddLink)
-- 	{
--  	//just return dependent on the mutation rate
--  	if (RandFloat() > MutationRate) return;
--
--  	//define holders for the two neurons to be linked. If we find two
--  	//valid neurons to link these values will become >= 0.
--		int ID_neuron1 = -1;
--		int ID_neuron2 = -1;
--
--  	//flag set if a recurrent link is selected to be added
--		bool bRecurrent = false;
--		//first test to see if an attempt should be made to create a
--		//link that loops back into the same neuron
--		if (RandFloat() < ChanceOfLooped) {
--			//YES: try NumTrysToFindLoop times to find a neuron that is not an
--			//input or bias neuron and does not already have a loopback
--			//connection
--			while(NumTrysToFindLoop--) {
--				//grab a random neuron
--				int NeuronPos = RandInt(m_iNumInputs+1, m_vecNeurons.size()-1);
--
--				//check to make sure the neuron does not already have a loopback
--				//link and that it is not an input or bias neuron
--				if	(!m_vecNeurons[NeuronPos].bRecurrent &&
--					(m_vecNeurons[NeuronPos].NeuronType != bias) &&
--					(m_vecNeurons[NeuronPos].NeuronType != input)) {
--						ID_neuron1 = ID_neuron2 = m_vecNeurons[NeuronPos].iID;
--						m_vecNeurons[NeuronPos].bRecurrent = true;
--						bRecurrent = true;
--						NumTrysToFindLoop = 0;
--				}
--			}
--		} else {
--			//No: try to find two unlinked neurons. Make NumTrysToAddLink attempts
--			while(NumTrysToAddLink--) {
--				//choose two neurons, the second must not be an input or a bias
--				ID_neuron1 = m_vecNeurons[RandInt(0, m_vecNeurons.size()-1)].iID;
--				ID_neuron2 = m_vecNeurons[RandInt(m_iNumInputs+1, m_vecNeurons.size()-1)].iID;
--				if (ID_neuron2 == 2) {
--					continue;
--				}
--
--				//make sure these two are not already linked and that they are
--				//not the same neuron
--				if	( !( DuplicateLink(ID_neuron1, ID_neuron2) ||
--					(ID_neuron1 == ID_neuron2))) {
--					NumTrysToAddLink = 0;
--				} else {
--					ID_neuron1 = -1;
--					ID_neuron2 = -1;
--				}
--			}
-- 		}
--
--		//return if unsuccessful in finding a link
--		if ( (ID_neuron1 < 0) || (ID_neuron2 < 0) ) {
--			return;
--		}
--
--		//check to see if we have already created this innovation
--		int id = innovation.CheckInnovation(ID_neuron1, ID_neuron2, new_link);
--
--		//is this link recurrent?
--		if (m_vecNeurons[GetElementPos(ID_neuron1)].dSplitY > m_vecNeurons[GetElementPos(ID_neuron2)].dSplitY) {
--			bRecurrent = true;
--		}
--
--		if ( id < 0) {
--			//we need to create a new innovation
--			innovation.CreateNewInnovation(ID_neuron1, ID_neuron2, new_link);
--
--			//now create the new gene
--			int id = innovation.NextNumber() - 1;
--			SLinkGene NewGene(ID_neuron1,
--				ID_neuron2,
--				true,
--				id,
--				RandomClamped(),
--				bRecurrent);
--				m_vecLinks.push_back(NewGene);
--		} else {
--			//the innovation has already been created so all we need to
--			//do is create the new gene using the existing innovation ID
--			SLinkGene NewGene(ID_neuron1,
--				ID_neuron2,
--				true,
--				id,
--				RandomClamped(),
--				bRecurrent);
--
--				m_vecLinks.push_back(NewGene);
--		}
-- 		return;
-- 	}

end

function _Genome:add_neuron()
	-- add a neuron to the genome dependent upon the mutation rate(BUCKLAND, 373)

-- 	void CGenome::AddNeuron(
-- 		ouble MutationRate,
-- 		CInnovation &innovations, //the innovation database
-- 		int NumTrysToFindOldLink)
-- 	{
-- 		//just return dependent on mutation rate
-- 		if (RandFloat() > MutationRate) return;

-- 		//if a valid link is found into which to insert the new neuron
-- 		//this value is set to true.
-- 		bool bDone = false;

-- 		//this will hold the index into m_vecLinks of the chosen link gene
-- 		int ChosenLink = 0;

-- 		//first a link is chosen to split. If the genome is small the code makes
-- 		//sure one of the older links is split to ensure a chaining effect does
-- 		//not occur. Here, if the genome contains less than 5 hidden neurons it
-- 		//is considered to be too small to select a link at random.
-- 		const int SizeThreshold = m_iNumInputs + m_iNumOutPuts + 5;

-- 		if (m_vecLinks.size() < SizeThreshold) {
-- 			while(NumTrysToFindOldLink--) {
-- 				//choose a link with a bias towards the older links in the genome
-- 				ChosenLink = RandInt(0, NumGenes()-1-(int)sqrt(NumGenes()));

-- 				//make sure the link is enabled and that it is not a recurrent link
-- 				//or has a bias input
-- 				int FromNeuron = m_vecLinks[ChosenLink].FromNeuron;

-- 				if	( (m_vecLinks[ChosenLink].bEnabled) &&
-- 					(!m_vecLinks[ChosenLink].bRecurrent) &&
-- 					(m_vecNeurons[GetElementPos(FromNeuron)].NeuronType != bias)) {
-- 					bDone = true;
-- 					NumTrysToFindOldLink = 0;
-- 				}
-- 			}

-- 			if (!bDone) {
-- 				//failed to find a decent link
-- 				return;
-- 			}
-- 		} else {
-- 			//the genome is of sufficient size for any link to be acceptable
-- 			while (!bDone) {
-- 				ChosenLink = RandInt(0, NumGenes()-1);

-- 				//make sure the link is enabled and that it is not a recurrent link
-- 				//or has a BIAS input
-- 				int FromNeuron = m_vecLinks[ChosenLink].FromNeuron;

-- 				if	( (m_vecLinks[ChosenLink].bEnabled) &&
-- 					(!m_vecLinks[ChosenLink].bRecurrent) &&
-- 					(m_vecNeurons[GetElementPos(FromNeuron)].NeuronType != bias))
-- 				{
-- 					bDone = true;
-- 				}
-- 			}
-- 		}
-- 		//disable this gene
-- 		m_vecLinks[ChosenLink].bEnabled = false;

-- 		//grab the weight from the gene (we want to use this for the weight of
-- 		//one of the new links so the split does not disturb anything the
-- 		//NN may have already learned
-- 		double OriginalWeight = m_vecLinks[ChosenLink].dWeight;

-- 		//identify the neurons this link connects
-- 		int from = m_vecLinks[ChosenLink].FromNeuron;
-- 		int to = m_vecLinks[ChosenLink].ToNeuron;

-- 		//calculate the depth and width of the new neuron. We can use the depth
-- 		//to see if the link feeds backwards or forwards
-- 		double NewDepth = (m_vecNeurons[GetElementPos(from)].dSplitY +
-- 		m_vecNeurons[GetElementPos(to)].dSplitY) /2;

-- 		double NewWidth = (m_vecNeurons[GetElementPos(from)].dSplitX +
-- 		m_vecNeurons[GetElementPos(to)].dSplitX) /2;

-- 		//Now to see if this innovation has been created previously by
-- 		//another member of the population
-- 		int id = innovations.CheckInnovation(
-- 			from,
-- 			to,
-- 			new_neuron
-- 		);

-- 		/*it is possible for NEAT to repeatedly do the following:
-- 		1. Find a link. Lets say we choose link 1 to 5
-- 		2. Disable the link,
-- 		3. Add a new neuron and two new links
-- 		4. The link disabled in Step 2 may be re-enabled when this genome
-- 		is recombined with a genome that has that link enabled.
-- 		5 etc etc
-- 		Therefore, the following checks to see if a neuron ID is already being used.
-- 		If it is, the function creates a new innovation for the neuron. */
--  		if (id >= 0)
-- 		{
-- 			int NeuronID = innovations.GetNeuronID(id);
-- 			if (AlreadyHaveThisNeuronID(NeuronID))
-- 			{
-- 				id = -1;
-- 			}
-- 		}

-- 		if (id < 0) //this is a new innovation
-- 		{
-- 			//add the innovation for the new neuron
-- 			int NewNeuronID = innovations.CreateNewInnovation(
-- 				from,
-- 				to,
-- 				new_neuron,
-- 				hidden,
-- 				NewWidth,
-- 				NewDepth
-- 			);

-- 			//Create the new neuron gene and add it.
-- 			m_vecNeurons.push_back(
-- 				SNeuronGene(
-- 					hidden,
-- 					NewNeuronID,
-- 					NewDepth,
-- 					NewWidth
-- 				)
-- 			);
-- 			//Two new link innovations are required, one for each of the
-- 			//new links created when this gene is split.

-- 			//----------------------------------first link

-- 			//get the next innovation ID
-- 			int idLink1 = innovations.NextNumber();

-- 			//create the new innovation
-- 			innovations.CreateNewInnovation(
-- 				from,
-- 				NewNeuronID,
-- 				new_link
-- 			);

-- 			//create the new gene
-- 			SLinkGene link1(
-- 				from,
-- 				NewNeuronID,
-- 				true,
-- 				idLink1,
-- 				1.0
-- 			);

-- 			m_vecLinks.push_back(link1);

-- 			//----------------------------------second link

-- 			//get the next innovation ID
-- 			int idLink2 = innovations.NextNumber();

-- 			//create the new innovation
-- 			innovations.CreateNewInnovation(
-- 				NewNeuronID,
-- 				to,
-- 				new_link
-- 			);
-- 			//create the new gene
-- 			SLinkGene link2(
-- 				NewNeuronID,
-- 				to,
-- 				true,
-- 				idLink2,
-- 				OriginalWeight
-- 			);

--  			m_vecLinks.push_back(link2);
--  		}
--  		else //existing innovation
--  		{
-- 			//this innovation has already been created so grab the relevant neuron
-- 			//and link info from the innovation database
-- 			int NewNeuronID = innovations.GetNeuronID(id);

-- 			//get the innovation IDs for the two new link genes
-- 			int idLink1 = innovations.CheckInnovation(from, NewNeuronID, new_link);
-- 			int idLink2 = innovations.CheckInnovation(NewNeuronID, to, new_link);

-- 			//this should never happen because the innovations *should* have already
-- 			//occurred
-- 			if ( (idLink1 < 0) || (idLink2 < 0) )
-- 			{
-- 				MessageBox(NULL, "Error in CGenome::AddNode", "Problem!", MB_OK);
-- 				return;
-- 			}

-- 			//now we need to create 2 new genes to represent the new links
-- 			SLinkGene link1(from, NewNeuronID, true, idLink1, 1.0);
-- 			SLinkGene link2(NewNeuronID, to, true, idLink2, OriginalWeight);

-- 			m_vecLinks.push_back(link1);
-- 			m_vecLinks.push_back(link2);

-- 			//create the new neuron
-- 			SNeuronGene NewNeuron(hidden, NewNeuronID, NewDepth, NewWidth);

-- 			//and add it
-- 			m_vecNeurons.push_back(NewNeuron);
--  		}
-- 		return;
-- 	}
end

function _Genome:crossover(mom, dad)
	-- (BUCKLAND, 381)

-- 	CGenome Cga::Crossover(CGenome& mum, CGenome& dad)
-- 	{
-- 		//first, calculate the genome we will using the disjoint/excess
-- 		//genes from. This is the fittest genome. If they are of equal
-- 		//fitness use the shorter (because we want to keep the networks
-- 		//as small as possible)
-- 		parent_type best;
--
-- 		if (mum.Fitness() == dad.Fitness()) {
-- 			//if they are of equal fitness and length just choose one at
-- 			//random
-- 			if (mum.NumGenes() == dad.NumGenes()) {
-- 				best = (parent_type)RandInt(0, 1);
-- 			} else {
-- 				if (mum.NumGenes() < dad.NumGenes()) {
-- 					best = MUM;
-- 				} else {
-- 					best = DAD;
-- 				}
-- 			}
-- 		} else {
-- 			if (mum.Fitness() > dad.Fitness()) {
-- 				best = MUM;
-- 			} else {
-- 				best = DAD;
-- 			}
-- 		}
--
-- 		//these vectors will hold the offspring's neurons and genes
-- 		vector<SNeuronGene> BabyNeurons;
-- 		vector<SLinkGene> BabyGenes;
--
-- 		//temporary vector to store all added neuron IDs
-- 		vector<int> vecNeurons;
--
-- 		//create iterators so we can step through each parents genes and set
-- 		//them to the first gene of each parent
-- 		vector<SLinkGene>::iterator curMum = mum.StartOfGenes();
-- 		vector<SLinkGene>::iterator curDad = dad.StartOfGenes();
--
-- 		//this will hold a copy of the gene we wish to add at each step
-- 		SLinkGene SelectedGene;
--
-- 		//step through each parents genes until we reach the end of both
-- 		while (!((curMum == mum.EndOfGenes()) && (curDad == dad.EndOfGenes()))) {
-- 			//the end of mum's genes have been reached
-- 			if ((curMum == mum.EndOfGenes())&&(curDad != dad.EndOfGenes())) {
-- 				//if dad is fittest
-- 				if (best == DAD) {
-- 					//add dads genes
-- 					SelectedGene = *curDad;
-- 				}
--
-- 				//move onto dad's next gene
-- 				++curDad;
-- 			} else if ( (curDad == dad.EndOfGenes()) && (curMum != mum.EndOfGenes())) { //the end of dad's genes have been reached
-- 				//if mum is fittest
-- 				if (best == MUM) {
-- 					//add mums genes
-- 					SelectedGene = *curMum;
-- 				}
--
-- 				//move onto mum's next gene
-- 				++curMum;
-- 			} else if (curMum->InnovationID < curDad->InnovationID) { //if mums innovation number is less than dads
-- 				//if mum is fittest add gene
-- 				if (best == MUM) {
-- 					SelectedGene = *curMum;
-- 				}
--
-- 				//move onto mum's next gene
-- 				++curMum;
-- 			} else if (curDad->InnovationID < curMum->InnovationID) { //if dad's innovation number is less than mum's
-- 				//if dad is fittest add gene
-- 				if (best = DAD) {
-- 					SelectedGene = *curDad;
-- 				}
--
-- 				//move onto dad's next gene
-- 				++curDad;
-- 			} else if (curDad->InnovationID == curMum->InnovationID) { //if innovation numbers are the same
-- 				//grab a gene from either parent
-- 				if (RandFloat() < 0.5f) {
-- 					SelectedGene = *curMum;
-- 				} else {
-- 					SelectedGene = *curDad;
-- 				}
--
-- 				//move onto next gene of each parent
-- 				++curMum;
-- 				++curDad;
-- 			}
--
-- 			//add the selected gene if not already added
-- 			if (BabyGenes.size() == 0) {
-- 				BabyGenes.push_back(SelectedGene);
-- 			} else {
-- 				if (BabyGenes[BabyGenes.size()-1].InnovationID != SelectedGene.InnovationID) {
-- 					BabyGenes.push_back(SelectedGene);
-- 				}
-- 			}
--
-- 			//Check if we already have the neurons referred to in SelectedGene.
-- 			//If not, they need to be added.
-- 			AddNeuronID(SelectedGene.FromNeuron, vecNeurons);
-- 			AddNeuronID(SelectedGene.ToNeuron, vecNeurons);
-- 		}//end while
--
-- 		//now create the required neurons. First sort them into order
-- 		sort(vecNeurons.begin(), vecNeurons.end());
--
-- 		for (int i=0; i<vecNeurons.size(); i++) {
-- 			BabyNeurons.push_back(m_pInnovation->CreateNeuronFromID(vecNeurons[i]));
-- 		}
--
-- 		//finally, create the genome
-- 		CGenome babyGenome(m_iNextGenomeID++,
-- 			BabyNeurons,
-- 			BabyGenes,
-- 			mum.NumInputs(),
-- 			mum.NumOutputs()
--		);
-- 		return babyGenome;
-- 	}
end

function _Genome:mutate_weights(mutation_rate, portability_new_mutation, max_perturbation)
	-- this function mutates the connection weights
end

function _Genome:mutate_activation_response(mutation_rate, max_perturbation)
	-- perturbs the activation responses of the neurons
end

function _Genome:get_compatibility_score(other)
-- calculates the compatibility score between this genome and another genome(BUCKLAND, 387)

-- 	double CGenome: :GetCompatibilityScore(const CGenome &genome)
-- 	{
-- 		//travel down the length of each genome counting the number of
-- 		//disjoint genes, the number of excess genes and the number of
-- 		//matched genes
-- 		double NumDisjoint = 0;
-- 		double NumExcess - 0
-- 		double NumMatched = 0
--
-- 		//this records the summed difference of weights in matched genes
-- 		double WeightDifference = 0:
--
--		 //indexes into each genome. They are incremented as we
-- 		//step down each genomes length.
-- 		int g1 = 0;
-- 		int g2 = 0;
--
-- 		while ( (g1 < m_vecLinks.size()-1) || (g2 < genome.m_vecLinks.size()-1) ) {
-- 			//we've reached the end of genome1 but not genome2 so increment
-- 			//the excess score
-- 			if (g1 == m_vecLinks.size()-1) {
-- 				++g2;
-- 				++NumExcess;
-- 				continue;
-- 			}
--
-- 			//and vice versa
-- 			if (g2 == genome.m_vecLinks.size()-1) {
-- 				++g1;
-- 				++NumExcess;
-- 				continue;
-- 			}
--
-- 			//get innovation numbers for each gene at this point
-- 			int id1 = m_vecLinks[g1].InnovationID;
-- 			int id2 = genome.m_vecLinks[g2].InnovationID;
--
-- 			//innovation numbers are identical so increase the matched score
-- 			if (id1 == id2) {
-- 				++g1;
-- 				++g2;
-- 				++NumMatched;
--
-- 				//get the weight difference between these two genes
-- 				WeightDifference += fabs(m_vecLinks[g1].dWeight ?
-- 				genome.m_vecLinks[g2].dWeight);
-- 			}
--
-- 			//innovation numbers are different so increment the disjoint score
-- 			if (id1 < id2) {
-- 				++NumDisjoint;
-- 				++g1;
-- 			}
--
-- 			if (id1 > id2) {
-- 				++NumDisjoint;
-- 				++g2;
-- 			}
--
-- 		}//end while
--
-- 		//get the length of the longest genome
-- 		int longest = genome.NumGenes();
-- 		if (NumGenes() > longest) {
-- 			longest = NumGenes();
-- 		}
--
-- 		//these are multipliers used to tweak the final score.
-- 		const double mDisjoint = 1;
-- 		const double mExcess = 1;
-- 		const double mMatched = 0.4;
--
-- 		//finally calculate the scores
-- 		double score = (mExcess * NumExcess / ( double)longest) +
-- 			(mDisjoint * NumDisjoint / (double)longest) +
-- 			(mMatched * WeightDifference / NumMatched);
-- 		return score;
-- 	}
end

function _Genome:sort_genes()
end

function _Genome:duplicate_link()
	-- returns true if the specified link is already part of the genome
end

function _Genome:get_element_pos(neuron_id)
	-- given a neuron id this function just finds its position in neurons array
end

function _Genome:already_have_this_neuron_id(id)
	-- tests if the passed ID is the same as any existing neuron IDs. Used in add_neuron()
end

-------------------------------------------------------------------------------
------------------------------------------------------------------------------- NEAT
function NEAT:new(o)
	local o = o or {}
	setmetatable(o, self)

	return o
end

function NEAT:epoch()
	-- (BUCKLAND, 393)

-- 	vector<CNeuralNet*> Cga::Epoch(const vector<double> &FitnessScores)
-- 	{
-- 		//first check to make sure we have the correct amount of fitness scores
-- 		if (FitnessScores.size() != m_vecGenomes.size()) {
-- 			MessageBox(NULL,"Cga::Epoch(scores/ genomes mismatch)!","Error", MB_OK);
-- 		}
-- 		ResetAndKill()
--
-- 		//update the genomes with the fitnesses scored in the last run
-- 		for (int gen=0; gen<m_vecGenomes.size(); ++gen) {
-- 			m_vecGenomes[gen].SetFitness(FitnessScores[gen]);
-- 		}
--
-- 		//sort genomes and keep a record of the best performers
-- 		SortAndRecord();
--
-- 		//separate the population into species of similar topology, adjust
-- 		//fitnesses and calculate spawn levels
-- 		SpeciateAndCalculateSpawnLevels();
--
-- 		//this will hold the new population of genomes
-- 		vector<CGenome> NewPop;
--
-- 		//request the offspring from each species. The number of children to
-- 		//spawn is a double which we need to convert to an int.
-- 		int NumSpawnedSoFar = 0;
-- 		CGenome baby;
--
-- 		//now to iterate through each species selecting offspring to be mated and
-- 		//mutated
-- 		for (int spc=0; spc<m_vecSpecies.size(); ++spc) {
-- 			//because of the number to spawn from each species is a double
-- 			//rounded up or down to an integer it is possible to get an overflow
-- 			//of genomes spawned. This statement just makes sure that doesn't
-- 			//happen
-- 			if (NumSpawnedSoFar < CParams::iNumSweepers) {
-- 				//this is the amount of offspring this species is required to
-- 				// spawn. Rounded simply rounds the double up or down.
-- 				int NumToSpawn = Rounded(m_vecSpecies[spc].NumToSpawn());
-- 				bool bChosenBestYet = false;
-- 				while (NumToSpawn--) {
-- 					//first grab the best performing genome from this species and transfer
-- 					//to the new population without mutation. This provides per species
-- 					//elitism
-- 					if (!bChosenBestYet) {
-- 						baby = m_vecSpecies[spc].Leader();
-- 						bChosenBestYet = true;
-- 					} else {
-- 						//if the number of individuals in this species is only one
-- 						//then we can only perform mutation
-- 						if (m_vecSpecies[spc].NumMembers() == 1) {
-- 							//spawn a child
-- 							baby = m_vecSpecies[spc].Spawn();
-- 						} else { //if greater than one we can use the crossover operator
-- 							//spawn1
-- 							CGenome g1 = m_vecSpecies[spc].Spawn();
-- 							if (RandFloat() < CParams::dCrossoverRate) {
-- 								//spawn2, make sure it's not the same as g1
-- 								CGenome g2 = m_vecSpecies[spc].Spawn();
--
-- 								// number of attempts at finding a different genome
-- 								int NumAttempts = 5;
-- 								while ( (g1.ID() == g2.ID()) && (NumAttempts--) ) {
-- 									g2 = m_vecSpecies[spc].Spawn();
-- 								}
--
-- 								if (g1.ID() != g2.ID()) {
-- 									baby = Crossover(g1, g2);
-- 								}
-- 							} else {
-- 								baby = g1;
-- 							}
-- 						}
--
-- 						++m_iNextGenomeID;
-- 						baby.SetID(m_iNextGenomeID);
--
-- 						//now we have a spawned child lets mutate it! First there is the
-- 						//chance a neuron may be added
-- 						if (baby.NumNeurons() < CParams::iMaxPermittedNeurons) {
-- 							baby.AddNeuron(CParams::dChanceAddNode,
-- 							*m_pInnovation,
-- 							CParams::iNumTrysToFindOldLink);
-- 						}
--
-- 						//now there's the chance a link may be added
-- 						baby.AddLink(CParams::dChanceAddLink,
-- 						CParams::dChanceAddRecurrentLink,
-- 							*m_pInnovation,
-- 							CParams::iNumTrysToFindLoopedLink,
-- 							CParams::iNumAddLinkAttempts);
--
-- 						//mutate the weights
-- 						baby.MutateWeights(CParams::dMutationRate,
-- 						CParams::dProbabilityWeightReplaced,
-- 						CParams::dMaxWeightPerturbation);
--
-- 						//mutate the activation response
-- 						baby.MutateActivationResponse(CParams::dActivationMutationRate,
-- 						CParams::dMaxActivationPerturbation);
-- 					}
--
-- 					//sort the babies genes by their innovation numbers
-- 					baby.SortGenes();
--
-- 					//add to new pop
-- 					NewPop.push_back(baby);
-- 					++NumSpawnedSoFar;
-- 					if (NumSpawnedSoFar == CParams::iNumSweepers) {
-- 						NumToSpawn = 0;
-- 					}
-- 				}//end while
-- 			}//end if
-- 		}//next species
--
-- 		//if there is an underflow due to a rounding error when adding up all
-- 		//the species spawn amounts, and the amount of offspring falls short of
-- 		//the population size, additional children need to be created and added
-- 		//to the new population. This is achieved simply, by using tournament
-- 		//selection over the entire population.
-- 		if (NumSpawnedSoFar < CParams::iNumSweepers) {
-- 			//calculate the amount of additional children required
-- 			int Rqd = CParams::iNumSweepers - NumSpawnedSoFar;
-- 			//grab them
-- 			while (Rqd--) {
-- 				NewPop.push_back(TournamentSelection(m_iPopSize/5));
-- 			}
-- 		}
--
-- 		//replace the current population with the new one
-- 		m_vecGenomes = NewPop;
-- 		//create the new phenotypes
-- 		vector<CNeuralNet*> new_phenotypes;
-- 		for (gen=0; gen<m_vecGenomes.size(); ++gen) {
-- 			//calculate max network depth
-- 			int depth = CalculateNetDepth(m_vecGenomes[gen]);
-- 			CNeuralNet* phenotype = m_vecGenomes[gen].CreatePhenotype(depth);
-- 			new_phenotypes.push_back(phenotype);
-- 		}
--
-- 		//increase generation counter
-- 		++m_iGeneration;
-- 		return new_phenotypes;
-- 	}
end


return NEAT