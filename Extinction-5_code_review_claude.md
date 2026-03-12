# Extinction-5 — Code Review & Analysis Notes
_by Claude Sonnet 4.6, session 2026-03-09_

## Project Summary
NEAT (NeuroEvolution of Augmenting Topologies) implemented from scratch in Lua,
applied to ghost behavior in a Pac-Man-style simulation. MBA paper project.
Lua (84.5%) + Python + Jupyter for data analysis. Paper: 96 pages.

## Architecture
- NEAT implemented from scratch in Lua — significant engineering undertaking
- Network topologies tested via `ensaios.conf`: relu/tanh combos, shallow to deep
  (4 relu → 1 binary_step up to 4+3+3 layers with tanh)
- 8 baseline specialist algorithms for comparison (key methodological asset)
- Headless run mode (`run_headless.lua`) for batch experiments — never fully working
- Python/Jupyter pipeline for data analysis
- Service-oriented architecture: files → keymaps → window → fonts → strings → gamestates
- Multiple gamestate types: menu, extinction, war_of_the_worlds, settings, config screens
- Localization support, first-run detection

## Experimental Design (3 batteries)

### Bateria 1 — Baseline specialists
8 specialist algorithms, each incrementally adding capabilities:
- full_random → random_ghost → random_ghost_collision → ... → pill_ghost_fixed
Discovered: fps (update rate) interfered with `lifetime` metric. Created `internal_lifetime`
(game-internal tick count) to decouple from real-time variability. Key fix — pre-NEAT telemetry
was polluted by hardware speed.

### Bateria 2 — Fixed topology neuroevolution
98 tests across topology/activation combos. Selected 4 for bateria 3:
- **b1** (1x3 tanh): minimal network, learns basic movement
- **b1_path_grading_hack** (1x3 tanh): fitness hack rewards path diversity
- **nb4** (1x12 relu): wider, slower to start (must learn all movement rules from scratch)
- **nb4_path_grading** (3x3 relu): wide + path grading

Two fitness functions compared:
- `movement_captures_hack_26`: rewards movement + captures
- `lifetime`: rewards survival

### Bateria 3 — Fixed topology vs NEAT (Figuras 19–34)
8 fixed-topology runs (Figs 19-26) × 8 NEAT runs (Figs 27-34), same 4 modes × 2 fitness functions.

## Key Results from Bateria 3

### Fixed topology observations
- **b1 + movement_captures_hack_26** (Fig 19): Good movement, subtle lifetime growth trend. Still
  improving when interrupted. High collision individuals still present (expected for b1 mode).
- **b1_path_grading_hack + movement_captures_hack_26** (Fig 20): Good movement, acquired fast.
  Stuck in local maximum. Capture heatmap shows concentration in upper-right quadrant — convergent
  behavior from path_grading constraint.
- **nb4 + movement_captures_hack_26** (Fig 21): Good movement acquired rapidly. Heatmap shows
  difficulty escaping shortest corridor of the maze.
- **nb4_path_grading + movement_captures_hack_26** (Fig 22): Best combined result — good lifetime
  (evasion indicator) + good movement + still growing when interrupted. **Top performer.**
- **b1 + lifetime** (Fig 23): Movement and lifetime in full development when interrupted. Long run
  (~400k iterations). High correlation: movement ↑ → pill capture ↑ → lifetime ↑, collision ↓.
- **b1_path_grading_hack + lifetime** (Fig 24): Comparable levels to best observed. Signs of
  stagnation. Evasion capability inferred from lifetime levels reached.
- **nb4 + lifetime** (Fig 25): Only started improving at ~300k iterations (expected — learning all
  movement rules from scratch). Strong growth spike near end. High movement/pill/lifetime correlation,
  inverse correlation with collisions.
- **nb4_path_grading + lifetime** (Fig 26): Good lifetime, moderate movement, timid growth when
  interrupted. Evasion inferred.

### NEAT observations
- **NEAT b1 + movement_captures_hack_26** (Fig 27): Initial improvement, then stagnation. Species
  count stayed at 1 throughout — barely speciated, initial topology prevailed. Learned to evade
  **without** learning proper movement.
- **NEAT b1_path_grading_hack + movement_captures_hack_26** (Fig 28): Metrics deteriorated for most
  of the run, abrupt recovery just before interrupted. Capability addition (topology growth) failed
  to work correctly. Second species nearly extinct. Same pattern: evasion without movement.
- **NEAT nb4 + movement_captures_hack_26** (Fig 29): Stagnation + worsening metrics, then late
  recovery. 4-5 stable species visible. Most complex species dynamics observed.
- **NEAT nb4_path_grading + movement_captures_hack_26** (Fig 30): 1-2 species. Reasonable but
  noisy performance. Collision count → ~0 (notable).
- **NEAT b1 + lifetime** (Fig 31): ~2 species. Reasonable lifetime. Good visited_count initially
  but decreased over time (convergence toward fewer cells).
- **NEAT b1_path_grading_hack + lifetime** (Fig 32): ~2 species. Lifetime around mean. Second
  species present to end — more topology variation than movement_captures variant. Suggests fitness
  function shapes speciation dynamics.
- **NEAT nb4 + lifetime** (Fig 33): 4-5 stable species. Lifetime ~0.55 (lowest of NEAT batch).
  Visited_count declining. Stagnation pattern.
- **NEAT nb4_path_grading + lifetime** (Fig 34): **Best NEAT result.** 5-6 species, strong
  lifetime growth (reaching 2.5+). Visited_count high and growing. Collision → ~0.
  Clear speciation events visible. Still growing when interrupted.

## Cross-Analysis Conclusions

### fitness movement_captures_hack_26 — double-edged
Rewards movement quickly but can hurt long-term evolution. Multiple runs show population acquiring
movement fast, then stagnating — the fitness function stops being informative. Paper explicitly
notes this: "pode atrapalhar a evolução da população a longo prazo."

### NEAT underperformed vs fixed topology in these runs
NEAT runs generally showed: slower start, stagnation phases, and less overall performance. BUT:
- Runs were cut shorter (fewer iterations for NEAT runs than fixed-topology equivalents)
- NEAT must discover topology AND weights simultaneously — needs more time
- The best NEAT run (nb4_path_grading + lifetime, Fig 34) showed strong trajectory still growing
- Author frames this as expected: NEAT is method development phase, not results phase

### The "evasion without movement" phenomenon
Multiple NEAT runs (Figs 27, 28) converged to evasion strategies that avoided the player without
learning maze navigation. A degenerate local optimum — survives by not engaging. Analogous to
Ext-3's cowardice result (14/-14 target_offset). The same attractor appears in NEAT.

### Species count as health indicator
- Low species (1-2): topology not growing, NEAT behaving like fixed topology
- 4-5 stable species: proper speciation, but potentially fragmented fitness landscape
- Growing species count → innovation happening
- Sudden species collapse → fitness landscape shifted or species extinction event

### nb4_path_grading consistently best topology
In both fixed topology and NEAT: nb4_path_grading variants performed best.
Path grading hack + wider hidden layer = sufficient diversity pressure + capacity.

## What Worked
- Scope escalation from Ext-3 is real: hand-coded GA → NEAT from scratch
- `notes` file shows genuine research mindset: honest about bugs, failures, plans
- Identified real Lua footgun: `ipairs` vs `#` table length on hash-part tables
- Experimental topology sweep is real methodology
- Data analysis pipeline separation (Python for analysis, Lua for simulation) is mature
- `internal_lifetime` metric fix is genuine methodological contribution
- Species count tracking added for NEAT runs — appropriate extension of analysis framework
- 160 commits — sustained effort

## What Didn't / Gaps
- Headless mode never fully functional — limited batch experiment capacity
- Three corrupted data files — acknowledged in paper
- NEAT capability addition (`add_link`) had a critical bug in `releases/final` — **confirmed March 2026**
  - `qpd/ann_neat.lua` line 881: `selected_output_neuron = self._neurons[input_neuron_index]` (should be `output_neuron_index`)
  - One-character copy-paste error. `output_neuron_index` is correctly selected and validated on lines 871-876, then silently discarded.
  - Result: every call to `add_link` created a self-loop or silently failed. No new forward/recurrent connections ever formed.
  - Secondary bug line 855: loopback path passes `:get_id()` (number) instead of neuron object to `Innovation_manager` — runtime error on loopback attempts.
  - `add_neuron()` was unaffected and functional — topology DID grow, but only via neuron-splitting (2 new links per call), never via direct link addition.
  - Bug present from first commit (`5c61d62`). March 3, 2023 commit (`7295b2c`) touched add_link only to remove `_sort_links()` — bug was never fixed.
  - **All NEAT experiments in the paper ran with `add_link` broken.** Conclusions about methodology remain valid. Claims about topology augmentation should be revisited.
- Test naming reflects exploratory trajectory, not pre-designed experiment.
- No README in repo — 96-page paper accompanies, so this matters less than it appears
- NEAT runs too short to show full trajectory — most still growing when interrupted

## Author's Framing (important)
Empirical, not hypothesis-driven. Design emerged from observation. Mentor stayed out of the way —
worked largely alone without specialized guidance. Views this as method and tooling development,
not results science yet. The goal: build the tools so *others* (and evolution itself) can play
and produce results. Results are the next phase.

Quote worth preserving:
> "If you can assure results it's not science, it is a job, an industry or else —
>  we are heading to the unmapped."

## Technical Debt Carried into Primordial
- Better telemetry data acquisition (identified gap)
- Better test run launch strategy (identified gap)
- Remote code execution grid + auto result collection (planned for Primordial)
- Headless batch runs that actually work
- Fitness function design: movement_captures_hack_26 vs lifetime trade-off is real and unresolved
- NEAT `add_link` bug: fix line 881 (`input_neuron_index` → `output_neuron_index`) and line 855 (pass neuron object, not `:get_id()`)
- Add unit test: after `add_link()`, assert `selected_input_neuron ~= selected_output_neuron`
- Re-run NEAT batteries with fix — first clean NEAT result
