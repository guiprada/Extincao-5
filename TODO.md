----------------- REFACTORING (next steps, in order)
- Clean up remaining dead code and old files across the project
	- Remove old files and tests. Is the paper enough for us to compare to our new results? (We should this after they are replaced by batches)
	- We are rebuilding, so it might be a good idea to rename some config(or anyother renaming :))
		- autoplayer_ann_mode - should be autoplayer_update_mode

* Fix headless runner (crashes on config path in table.lua:143)
- Headless runner testing and improvements?
* Population saving and loading
- Population saving and loading testing and improvoments

- Batched tests (run multiple configs/seeds automatically)
	- Create configurations for the OG papers batteries 1, 2, 3 - We should be able to start a script and wait for the results.
	- Batched runner tests and improvements

- Batched test run and population analysis
	- Should we generate a html hypertext of std Batched test output?

- Tests -- add tests to everything, starting with ANN infrastructure:
	- ann_neat: unit tests for crossover, speciation, compatibility score,
	  add_neuron, add_link (especially the forward-link fix), get_outputs
	- ann: unit tests for forward pass
	- cover edge cases: single neuron, fully connected, empty species list
- The qpd-framework did not come out as expected. I think the workflow should be:
	- create project folder, let us call it sample_proj/
	- inside sample_proj you clone qpd -> sample_proj/qpd/
	- you execute sample_proj/qpd/inflate.bat and it will copy its folders to project root, ie it will copy /sample_proj/qpd/gamestates/* to sample_proj/gamestates/*
	- the resulting workflow will be, any upstream changes to qpd are imedially available - the core libs are in place and ready - supporting files are available but should be moved/merged manually - so they can be customized without the risk of being overwritten

----------------- KNOWN BUGS / INVESTIGATION
- ipairs vs # on _layers: OPEN. table.sort on o._layers[i] was observed to
  change #_layers[i] in practice. Hash-part contamination was investigated and
  ruled out (user removed it, bug persisted). Root cause unknown — possibly a
  LuaJIT sort quirk with specific input patterns, or a side effect during
  comparison. Defensive clone-check kept in ANN:new(). NOTE: the recovery path
  uses qpd_array.clone which does NOT exist in array.lua — if sort corruption
  is triggered, the recovery will crash. Either add array.clone or replace
  recovery with a plain numeric-loop copy.

----------------- TODO
- TESTAR usar a distancia para um cruzamento como entrada
- TESTAR usar o vetor para a pilula mais proxima como entrada
- TESTAR usar usar como entrada a saida de 4 redes neurais qualificadoras + a orientacao atual
- TESTAR ORDEM DA FILA DA ESPECIACAO - ALEATORIA E INVERSA(COMO ERA)
- TESTAR NEAT INICIANDO TUDO COM PESO 1 para garantir que sera ativado!
- ATUALMENTE OS PESOS PODEM SER NULOS E A MUTACAO E MULTIPLICATIVA!(IMPLEMENTAR MUTACAO ADITIVA!)
- TESTAR NEAT COM PESOS NEGATIVOS
- TESTAR NEAT COM TUDO ALEATORIO
- melhorar resolucao de tempo
- adicionar velocidade constante como opcao
- Adicionar servidor de populacao
	- Adicionar suporte a headless
- todas as configuracoes em lua
- remove unused neurons from NEAT fenotype
- implementar funcoes que nao usam "self" para AutoplayerAnnModes.lua
- implementar gameplay data capture and offline learning
- implementar teste com o dataset mnist
- NEAT para fantasmas
- implementar load and save population
- Add map and population loading
- add the pheromone thingy :) -- WTF?
- tecnicas para aumentar diversidade.
	-(modificar totalmente um gene no crossover)
	- Valor de corte para especiacao diminui com o tempo(proporcional a geracao, ou a contagem de geracoes sem especiacao, ou a quantidade de especies ativas)
		- taxa de mutacao e adicionar neuronios e links dinamica.
- visualizador de topologia do neat(funcionamento em tempo real?)
- serializar ANN neat
- Fantasmas capturados tem um delay para voltarem(pressao para captura)
- Player spawnan em um linha onde nao ha spawn de pilulas nem fantasmas
- Melhorar robustez do sistema de log
- Object pools
- Testar cooevolucao
- Testar adaptabilidade da populacao uma vez convergida
- layout em uma configuracao lua

----------------- DONE
- implementar NEAT
	- verificar se o link ja existe
- split population_size and _history size
- Very simple, look at front and rotate_left(or rotate_right)
- ann_neat.lua: replace with next branch version, fix all known bugs, add comments
	- add_link forward path copy-paste bug fixed (output_neuron_index)
	- unique_layers now sorted (was commented out)
	- dead _inputs[] array removed from _Neuron
	- compatibility score division-by-zero guard
	- INPUT_PROPORTIONAL_ACTIVATION implemented
	- _Link self-registers in constructor
	- id_to_neuron flat lookup replaces two-level position dict
- Clean up old/duplicate ANN files (ann_old, ann_not_so_old, _ann_neat_old,
  _ann_neat_stock, ann_neat_hybrid, ann_neat_TCC, ann_neat_new, ann_neat_stock)
- Compatibility score formula corrected to match NEAT paper:
    score = c1*D/N + c2*E/N + c3*W_bar
  Original code had a precedence bug that added raw n_matched/longest to the
  excess term. New formula is correct. qpd.ann (non-NEAT) still active and needed
  by AutoPlayer.lua and extinction.lua — not dead code.

----------------- CORRUPTED
1671132502 B2
1670698681 B3
1667082412 NB4



-----------------------------------------
----------------- NOTES
** to adapt this to ghosts we could get a next position only when out of corridors **
** should mutation be only  for greater amplitude?(since crossover always diminishes it) **

- BASELINE, um algoritmo especialista que foge quando vulnerável e ataca quando oportuno, mas não sai da rota para procurar pilulas ou fantasmas.
- BASELINE_PILL, um algoritmo especialista que foge quando vulnerável e ataca quando oportuno, desvia da rota para procurar pilulas mas não para fantasmas.
- BASELINE_PILL_GHOST, um algoritmo especialista que foge quando vulnerável e ataca quando oportuno, desvia da rota para procurar pilulas e capturar fantasmas.
- BASELINE_RANDOM, um algoritmo especialista que foge quando vulnerável e ataca quando oportuno, caso a rota atual seja ruim, assume uma outra rota aleatoriamente.
- BASELINE_COLLIDE_RANDOM, um algoritmo especialista caso tenha ocorrido uma colisão, assume uma outra rota aleatoriamente.
- BASELINE_FULL_RANDOM, um algoritmo especialista que, assume uma outra rota aleatoriamente.
- BASELINE_VALID_RANDOM, um algoritmo especialista que foge quando vulnerável e ataca quando oportuno, caso a rota atual seja ruim, assume uma outra rota válida aleatoriamente.
- BASELINE_VALID_FULL_RANDOM, um algoritmo especialista que, assume uma outra rota válida aleatoriamente.



- em ordem de capacidades
*- BASELINE_FULL_RANDOM. (nenhuma capacidade)
*- BASELINE_VALID_FULL_RANDOM. (capacidade de escolher uma rota valida)
*- BASELINE_COLLIDE_RANDOM. (detecta colisão)
*- BASELINE_RANDOM. (capacidade de fugir e atacar)
*- BASELINE_VALID_RANDOM. (capacidade de fugir e ataque oportuno e escolher rotas validas)
*- BASELINE. (capacidade de fugir e ataque oportuno, nao desvia rota para capturar)
*- BASELINE_PILL. (capacidade de fugir e ataque oportuno, desvia rota para capturar pilulas)
*- BASELINE_PILL_GHOST. (capacidade de fugir e ataque oportuno, desvia rota para capturar)
