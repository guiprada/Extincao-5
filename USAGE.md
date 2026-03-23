# Extincao — Usage Guide

## Quick start

```bash
# Single headless run — stops after 50 000 autoplayer lifetimes
lua5.4 run_headless.lua --players 50000

# Resume from the last checkpoint of a previous run
lua5.4 run_headless.lua --players 50000 --resume runs/<strategy>/<seed>

# Old-style update-count cap (still works)
lua5.4 run_headless.lua 500000
```

## run_headless.lua arguments

| Argument | Default | Description |
|---|---|---|
| `[max_updates]` | 500 000 | Stop after this many simulation ticks. Ignored when `--players` is set. |
| `--players N` | — | **Recommended.** Stop after N total autoplayer replacements. This is the natural unit of evolutionary progress (one replacement ≈ one individual's lifetime). |
| `--resume <run_dir>` | — | Restore a saved population before starting. `<run_dir>` is the full path to a run folder, e.g. `runs/neat_nb4_flat_lifetime/1773336963`. |

Arguments can be combined freely:

```bash
lua5.4 run_headless.lua --players 100000 --resume runs/neat_nb4_flat_lifetime/1773336963
```

---

## Configuration

All experiment parameters live in `conf/extinction.conf`.
Game-engine parameters (window size, etc.) live in `conf/games.conf`.

Copy or symlink the desired config before launching:

```bash
cp my_experiment.conf conf/extinction.conf
lua5.4 run_headless.lua --players 50000
```

Key parameters in `extinction.conf`:

| Parameter | Description |
|---|---|
| `autoplayer_neat_enable` | `true` = NEAT neuro-evolution, `false` = fixed topology |
| `autoplayer_ann_mode` | Input feature set (e.g. `nb4_flat`, `b1`, `nb4_path_grading`) |
| `autoplayer_fitness_mode` | Fitness function (e.g. `lifetime`, `visited`, `movement_captures_lifetime_hack_26`) |
| `autoplayer_active_population` | Live players at any moment (~1 in headless, ~30 in graphical) |
| `autoplayer_neat_specie_niche_initial_population_size` | Gene-pool size per species |
| `seed` | Random seed. Omit to use `os.time()` (unique run each launch). |

---

## Output folder structure

Every run creates a folder under `runs/`:

```
runs/
  <strategy>/          ← derived from conf (neat/fixed + ann_mode + fitness_mode)
    <seed>/
      run.conf         ← copy of the conf used for this run
      run.data-0       ← per-actor event log (CSV)
      population.lua   ← latest population checkpoint (overwritten each generation)
```

Example:

```
runs/neat_nb4_flat_lifetime/1773336963/population.lua
```

`population.lua` is plain Lua source — human-readable and loadable with `loadfile()`.

---

## Experiment strategies (from the paper)

Runs are grouped automatically by strategy folder name.
The strategies in the paper, in order of capability:

| Strategy | Description |
|---|---|
| `BASELINE_FULL_RANDOM` | No capabilities — picks a random direction every step |
| `BASELINE_VALID_FULL_RANDOM` | Picks a random *valid* (non-wall) direction |
| `BASELINE_COLLIDE_RANDOM` | Randomises direction only on collision |
| `BASELINE_RANDOM` | Flees when vulnerable, attacks when opportunistic, otherwise random |
| `BASELINE_VALID_RANDOM` | Same + chooses valid directions |
| `BASELINE` | Flee + opportunistic attack, does not deviate route |
| `BASELINE_PILL` | Flee + attack + detours for pills |
| `BASELINE_PILL_GHOST` | Flee + attack + detours for pills and ghosts |

NEAT runs are named `neat_<ann_mode>_<fitness_mode>` and appear alongside these baselines for comparison.

---

## Running multiple experiments

A typical session:

```bash
# 1. Set conf for experiment A
cp conf/experiment_neat_nb4.conf conf/extinction.conf
lua5.4 run_headless.lua --players 50000

# 2. Set conf for experiment B
cp conf/experiment_neat_b1.conf conf/extinction.conf
lua5.4 run_headless.lua --players 50000

# 3. Continue a previous run
lua5.4 run_headless.lua --players 50000 --resume runs/neat_nb4_flat_lifetime/1773336963
```

---

## Graphical client

To watch an interesting run in LÖVE:

```bash
love .
```

The graphical client reads the same `conf/extinction.conf`.
Population checkpoints from headless runs can be resumed graphically once `--resume` support is wired into `extinction.load()` (currently only `run_headless.lua` passes the resume dir).

---

## Tests

```bash
cd tests_unit
lua5.4 test_ann_neat.lua        # 13 tests — ANN/NEAT core
lua5.4 test_population_io.lua   # 132 tests — save/load round-trip
```
