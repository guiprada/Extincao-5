import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import os
import json
import re

#timestamp, actor_id, actor_type, event_type, other, cell_x, cell_y, updates, no_pill_updates, visited_count, grid_cell_changes, collision_count, genes
########################################################################## Config
FIG_SIZE = (16, 24)
# FIG_SIZE = (8, 6)

SMALL_LEGEND_FONTSIZE = 7

ANN_MODE_STRING = "autoplayer_ann_mode = "
ANN_LAYERS_STRING = "autoplayer_ann_layers = "

OVERRIDE_OLD_DATAFRAME = False

########################################################################## Data Processing
def gene_parser(data):
	return data

def quote_gene(path):
	with open(path, 'r') as infile:
		with open(path + "_fixed", 'w') as outfile:
			for line in infile:
				line = line.replace("{", "'{")
				line = line.replace("}", "}'")
				outfile.write(line)

	print("finished: ", path)

def join_data(path):
	filenames = []
	n = 0
	while (os.path.exists(f"{path}-{n}")):
		filenames.append(f"{path}-{n}")
		n = n + 1

	if len(filenames) > 0:
		with open(path, 'w') as outfile:
			for filename in filenames:
				with open(filename) as infile:
					for line in infile:
						outfile.write(line)

########################################################################## Analysis
def create_array_of_interval_mean(array, interval_count):
	interval_arrays_list = np.array_split(array.tolist(), interval_count)
	interval_avg_list = []
	for subarray in interval_arrays_list:
		avg = subarray.mean()
		new_avg = np.full(len(subarray), avg)
		interval_avg_list.extend(new_avg.tolist())

	return np.asarray(interval_avg_list)

def create_lifetime_dict(df):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_creation = df[df["event_type"] == "created"]

	# lifetime dict
	lifetimes_dict = {}
	for _, row in df_destruction.iterrows():
		id = row["actor_id"]

		if not id in lifetimes_dict:
			lifetimes_dict[id] = dict()

		this_entry = lifetimes_dict[id]
		this_entry["actor_id"] = row["actor_id"]
		this_entry["actor_type"] = row["actor_type"]
		this_entry["other_id"] = row["other"]
		this_entry["updates"] = row["updates"]
		this_entry["no_pill_updates"] = row["no_pill_updates"]
		this_entry["visited_count"] = row["visited_count"]
		this_entry["grid_cell_changes"] = row["grid_cell_changes"]
		this_entry["collision_count"] = row["collision_count"]
		this_entry["cell_x"] = row["cell_x"]
		this_entry["cell_y"] = row["cell_y"]

		this_entry["destruction"] = row["timestamp"]


	for _, row in df_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetimes_dict:
			lifetimes_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetimes_dict[id]
		this_entry["creation"] = row["timestamp"]

	return lifetimes_dict

def create_analysis_plot(df, actor_lifetimes_dict, player_lifetimes_dict, path, run, mode):
	errors = list()
	# subplots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)

	fig, subplots = plt.subplots(7, 3, figsize = FIG_SIZE)
	fig.suptitle("run: " + run +  " | ann_mode: " + mode, size = 20, y = 0)

	subplot_row = subplots[0]
	# updates/second
	ratio_list_x = []
	ratio_list_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in player_lifetimes_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
			lifetime = (value["destruction"] - value["creation"])
			updates = value["updates"]

			if lifetime == 0:
				short_lived_x.append(index)
				short_lived_y.append(0)
			else:
				ratio_list_x.append(index)
				ratio_list_y.append(updates/lifetime)

	subplot_row[0].set_title("Update per second for player")
	subplot_row[0].scatter(ratio_list_x, ratio_list_y, label = "Updates/second", alpha = 0.5)
	subplot_row[0].scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	plt.setp(subplot_row[0].get_xticklabels(), rotation=30, horizontalalignment='right')
	subplot_row[0].legend(fontsize = SMALL_LEGEND_FONTSIZE)

	# seconds/update
	ratio_list_x = []
	ratio_list_y = []
	long_freeze_x = []
	long_freeze_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in player_lifetimes_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
			lifetime = (value["destruction"] - value["creation"])
			updates = value["updates"]

			if lifetime == 0:
				short_lived_x.append(index)
				short_lived_y.append(0.99)
			elif updates == 0:
				long_freeze_x.append(index)
				long_freeze_y.append(0.98)
				pass
			else:
				ratio_list_x.append(index)
				ratio_list_y.append(lifetime / updates)

	subplot_row[1].set_title("Seconds per update for player")
	subplot_row[1].scatter(ratio_list_x, ratio_list_y, label = "Seconds/update ratio", alpha = 0.5)
	subplot_row[1].scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	subplot_row[1].scatter(long_freeze_x, long_freeze_y, color = "purple", label = "long freeze", alpha = 0.3)
	plt.setp(subplot_row[1].get_xticklabels(), rotation=30, horizontalalignment='right')
	subplot_row[1].legend(fontsize = SMALL_LEGEND_FONTSIZE)
	# updates
	updates_x = []
	updates_y = []
	counter = 0
	for index, value in player_lifetimes_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			counter = counter + 1
			updates_x.append(counter)
			updates_y.append(value["updates"])

	subplot_row[2].set_title("Updates per player")
	subplot_row[2].scatter(updates_x, updates_y, label = "updates per player", alpha = 0.5)
	plt.setp(subplot_row[2].get_xticklabels(), rotation=30, horizontalalignment='right')
	subplot_row[2].legend(fontsize = SMALL_LEGEND_FONTSIZE)

	# destruction heatmaps
	subplot_row = subplots[1]
	row_index = 0
	for actor_type in actor_lifetimes_dict.keys():
		ax = subplot_row[row_index]
		row_index = row_index + 1

		df_destruction = df[df["event_type"] == "destroyed"]
		df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
		# heatmap_points = list(zip(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"]))

		heatmap_hist, xedges, yedges = np.histogram2d(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"], bins = (28, 14))
		extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
		#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

		img = ax.imshow(heatmap_hist.T, extent = extent)
		ax.set_title("Destruction Heatmap for " + actor_type)
		plt.setp(ax.get_xticklabels(), rotation=30, horizontalalignment='right')
		plt.colorbar(img, ax = ax, location = "bottom")

	# lifetimes
	line_index = 2
	for actor_type, lifetimes_array in actor_lifetimes_dict.items():
		subplot_row = subplots[line_index]
		line_index = line_index + 1

		lifetime_avg_array_100 = create_array_of_interval_mean(lifetimes_array, 100)
		lifetime_avg_array_10 = create_array_of_interval_mean(lifetimes_array, 10)

		ax1 = subplot_row[0]
		ax1.set_title("Lifetime for " + actor_type)
		ax1.scatter(range(1, len(lifetimes_array) + 1), lifetimes_array, label = "lifetime", alpha = 0.1)
		plt.setp(ax1.get_xticklabels(), rotation=30, horizontalalignment='right')
		ax1.legend(fontsize = SMALL_LEGEND_FONTSIZE)

		ax2 = subplot_row[1]
		ax2.set_title("Mean Lifetime for " + actor_type)
		ax2.plot(lifetime_avg_array_100, label = "intervalar mean 100 blocks", alpha = 0.5)
		ax2.plot(lifetime_avg_array_10, label = "intervalar mean 10 blocks")
		ax2.hlines(lifetimes_array.mean(), 0, len(lifetimes_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
		plt.setp(ax2.get_xticklabels(), rotation=30, horizontalalignment='right')
		ax2.legend(fontsize = SMALL_LEGEND_FONTSIZE)

		ax3 = subplot_row[2]
		ax3.set_title("Lifetime Boxplot for " + actor_type)
		plt.setp(ax3.get_xticklabels(), rotation=30, horizontalalignment='right')
		ax3.boxplot(np.array_split(lifetimes_array.tolist(), 10), widths = 0.8)

	subplot_row = subplots[5]
	ax1 = subplot_row[0]
	ax2 = subplot_row[1]
	ax3 = subplot_row[2]

	destroyed_actors = df[df["event_type"] == "destroyed"]
	destroyed_players = destroyed_actors[destroyed_actors["actor_type"] == "player"]
	destroyed_ghosts = destroyed_actors[destroyed_actors["actor_type"] == "ghost"]
	destroyed_pills = destroyed_actors[destroyed_actors["actor_type"] == "pill"]

	#ghosts caught per autoplayer
	ghosts_caught_by_player = []
	for _, player_id in destroyed_players["actor_id"].items():
		ghosts_destroyed_by_player = destroyed_ghosts[destroyed_ghosts["other"] == player_id]
		ghosts_caught_by_player.append(ghosts_destroyed_by_player.shape[0])

	ax1.set_title("Ghosts caught per player")
	ax1.scatter(range(1, len(ghosts_caught_by_player) + 1), ghosts_caught_by_player, label = "ghosts caught", alpha = 0.1)
	plt.setp(ax1.get_xticklabels(), rotation=30, horizontalalignment='right')

	#pills caught per autoplayer
	pills_caught_by_player = []
	for _, player_id in destroyed_players["actor_id"].items():
		pills_destroyed_by_player = destroyed_pills[destroyed_pills["other"] == player_id]
		pills_caught_by_player.append(pills_destroyed_by_player.shape[0])

	ax2.set_title("Pill caught per player")
	ax2.scatter(range(1, len(pills_caught_by_player) + 1), pills_caught_by_player, label = "pills caught", alpha = 0.1)
	plt.setp(ax2.get_xticklabels(), rotation=30, horizontalalignment='right')

	#ghosts caught per pill
	ax3.set_title("Ghosts/pill per player")
	pill_creation_destruction_string = "pills created: " + str(len(df.query("actor_type == 'pill' & event_type == 'created'"))) + " pills destroyed: " + str(len(destroyed_pills))
	for index, item in enumerate(pills_caught_by_player):
		if item == 0:
			old_value = pills_caught_by_player[index]
			pills_caught_by_player[index] = 1
			if ghosts_caught_by_player[index] != 0:
				error_string = "Error in fixing ghosts/pill lists for index: " + str(index) + " | " + str(pill_creation_destruction_string)
				print(error_string)
				errors.append(error_string)

	ghosts_per_pill_by_player = np.asarray(ghosts_caught_by_player)/np.asarray(pills_caught_by_player)
	ax3.scatter(range(1, len(ghosts_per_pill_by_player) + 1), ghosts_per_pill_by_player, label = "ghosts caught per pill", alpha = 0.1)
	plt.setp(ax3.get_xticklabels(), rotation=30, horizontalalignment='right')

	#lifetime count distribution
	#df.value_counts.plot(kind = "bar")
	subplot_row = subplots[6]
	ax1 = subplot_row[0]
	unique = np.unique(actor_lifetimes_dict["player"])
	min, max = unique.min(), unique.max()
	n_bins = unique.shape[0]
	ax1.set_title("Player Lifetime histogram")
	ax1.hist(actor_lifetimes_dict["player"], bins = n_bins, range = (min, max))

	#visited_count
	ax2 = subplot_row[1]
	visited_cells_by_player = []
	for _, visited_count in destroyed_players["visited_count"].items():
		visited_cells_by_player.append(visited_count)

	ax2.set_title("Unique Cells Visited per player")
	ax2.scatter(range(1, len(ghosts_caught_by_player) + 1), ghosts_caught_by_player, label = "unique cells visited per player", alpha = 0.1)
	plt.setp(ax2.get_xticklabels(), rotation=30, horizontalalignment='right')

	#grid_cell_changes/lifetime
	ax3 = subplot_row[2]
	grid_cell_changes_by_player = []
	for player in player_lifetimes_dict.values():
		if (player["creation"] is not None) and (player["destruction"] is not None):
			lifetime = player["creation"] - player["destruction"]
			if lifetime != 0:
				grid_cell_changes_by_player.append(player["grid_cell_changes"]/lifetime)
			else:
				if player["grid_cell_changes"] > 0:
					error_string = "Short lived player got pill"
					print(error_string)
					errors.append(error_string)

	ax3.set_title("Cell changes per lifetime per player")
	ax3.scatter(range(1, len(ghosts_caught_by_player) + 1), ghosts_caught_by_player, label = "cell changes per lifetime per player", alpha = 0.1)
	plt.setp(ax3.get_xticklabels(), rotation=30, horizontalalignment='right')

	#collision_count



	#######################################################################################################################
	#######################################################################################################################


	#genes

	#######################################################################################################################
	#######################################################################################################################

	# set the spacing between subplots
	# fig.tight_layout()
	plt.subplots_adjust(
		left=0.1,
		bottom=0.1,
		right=0.9,
		top=0.9,
		wspace=0.2,
		hspace=0.4)

	plt.savefig(f"{path}{run}_all.png", dpi = 100)
	plt.show()
	plt.close()

	return errors

def add_scatter_plot_to_axis(axis, scatter_x, scatter_y, title, label):
	axis.set_title(title)
	axis.scatter(scatter_x, scatter_y, label = label, alpha = 0.1)
	axis.hlines(scatter_y.mean(), 0, len(scatter_x), label = "mean", colors = "red", linestyles = "dotted", alpha = 1)
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def add_scatter_plot_to_axis_from_dicts(axis, plot_dicts_list, title):
	axis.set_title(title)
	for plot_dict in plot_dicts_list:
		axis.scatter(plot_dict["x"], plot_dict["y"], label = plot_dict["label"], alpha = plot_dict["alpha"], color = plot_dict["color"])
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def add_heatmap_to_axis(axis, x, y, bins, title):
	heatmap_hist, xedges, yedges = np.histogram2d(x, y, bins)
	extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
	#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

	img = axis.imshow(heatmap_hist.T, extent = extent)
	axis.set_title(title)
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	plt.colorbar(img, ax = axis, location = "bottom")

def add_intervalar_means_plot_to_axis(axis, scatter_x, scatter_y, title):
		scatter_y_100 = create_array_of_interval_mean(scatter_y, 100)
		scatter_y_10 = create_array_of_interval_mean(scatter_y, 10)

		axis.set_title(title)
		axis.plot(scatter_x, scatter_y_100, label = "intervalar mean 100 blocks", color = "green", alpha = 0.8)
		axis.plot(scatter_x, scatter_y_10, label = "intervalar mean 10 blocks", color = "blue", alpha = 0.8)
		axis.hlines(scatter_y.mean(), 0, len(scatter_x), label = "mean", colors = "red", linestyles = "dotted", alpha = 1)
		plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
		axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def generate_run_report_from_dict(run_dict):
	player_df = run_dict["df"][run_dict["df"]["actor_type"] == "player"]
	player_df_count = player_df.shape[0]
	ghost_df = run_dict["df"][run_dict["df"]["actor_type"] == "ghost"]
	pill_df = run_dict["df"][run_dict["df"]["actor_type"] == "pill"]

	errors = list()

	# subplots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)

	fig, subplots = plt.subplots(6, 3, figsize = FIG_SIZE)

	## Config string
	config_string = "run: " + run_dict["run_id"] +  " | ann_mode: " + run_dict["mode"]
	if "layers" in run_dict:
		config_string = config_string + run_dict["layers"].replace("}, {", "},\n{")

	fig.suptitle(config_string, size = 20, y = 0)

	## Updates/second
	updates_second_plot_dicts_list = list()

	player_df_filtered = player_df.query("updates > 0 and lifetime > 0")
	player_df_filtered_count = player_df_filtered.shape[0]
	# print(player_df_filtered_count, player_df_count)
	updates_second_filtered_plot_dict = {
		"x": player_df_filtered["actor_id"],
		"y": player_df_filtered["updates_per_second"],
		"label": "updates > 0 and lifetime > 0",
		"alpha": min(1000/player_df_filtered_count, 1),
		"color": "red",
	}
	updates_second_plot_dicts_list.append(updates_second_filtered_plot_dict)

	player_df_filtered = player_df.query("updates == 0 or lifetime == 0")
	player_df_filtered_count = player_df_filtered.shape[0]
	# print(player_df_filtered_count, player_df_count)
	updates_second_plot_dict = {
		"x": player_df_filtered["actor_id"],
		"y": player_df_filtered["updates_per_second"],
		"label": "updates == 0 or lifetime == 0",
		"alpha": 0.5,
		"color": "blue",
	}
	updates_second_plot_dicts_list.append(updates_second_plot_dict)

	add_scatter_plot_to_axis_from_dicts(subplots[0][0], updates_second_plot_dicts_list, "Updates per second x player actor_id")

	## Fails
	fails_plot_dicts_list = list()
	short_lived = player_df.query("lifetime == 0")
	short_lived_fails_plot_dict = {
		"x": short_lived["actor_id"],
		"y": short_lived["lifetime"],
		"label": "short lived",
		"alpha": 0.5,
		"color": "yellow",
	}
	fails_plot_dicts_list.append(short_lived_fails_plot_dict)

	frozen = player_df.query("updates == 0 and lifetime > 0")
	fails_frozen_plot_dict = {
		"x": frozen["actor_id"],
		"y": frozen["lifetime"],
		"label": "frozen",
		"alpha": 0.5,
		"color": "red",
	}
	fails_plot_dicts_list.append(fails_frozen_plot_dict)
	add_scatter_plot_to_axis_from_dicts(subplots[0][1], fails_plot_dicts_list, "Frozen and Short lived x player_actor_id")

	## Updates per player
	add_scatter_plot_to_axis(subplots[0][2], range(player_df.shape[0]), player_df["updates"], "Updates per player", "updates per player")

	## Player
	add_heatmap_to_axis(subplots[1][0], player_df["cell_x"], player_df["cell_y"], bins = (28, 14), title = "Destruction Heatmap for Player")
	add_scatter_plot_to_axis(subplots[1][1], range(player_df.shape[0]), player_df["lifetime"], "Player Lifetime x Generation", "lifetime")
	add_intervalar_means_plot_to_axis(subplots[1][2], range(player_df.shape[0]), player_df["lifetime"], "Player Lifetime x Generation Interval")

	## Ghost
	add_heatmap_to_axis(subplots[2][0], ghost_df["cell_x"], ghost_df["cell_y"], bins = (28, 14), title = "Destruction Heatmap for Ghost")
	add_scatter_plot_to_axis(subplots[2][1], range(ghost_df.shape[0]), ghost_df["lifetime"], "Ghost Lifetime x Generation", "lifetime")
	add_intervalar_means_plot_to_axis(subplots[2][2], range(ghost_df.shape[0]), ghost_df["lifetime"], "Ghost Lifetime x Generation Interval")

	## Pills
	add_heatmap_to_axis(subplots[3][0], pill_df["cell_x"], pill_df["cell_y"], bins = (28, 14), title = "Destruction Heatmap for Pill")
	add_scatter_plot_to_axis(subplots[3][1], range(pill_df.shape[0]), pill_df["lifetime"], "Pill Lifetime x Generation", "lifetime")
	add_intervalar_means_plot_to_axis(subplots[3][2], range(pill_df.shape[0]), pill_df["lifetime"], "Pill Lifetime x Generation Interval")

	## Pills captured x autoplayer generation
	add_scatter_plot_to_axis(subplots[4][0], range(player_df.shape[0]), player_df["pills_captured"], "Pills captured x player generation", "pills captured")

	## Ghosts captured x autoplayer generation
	add_scatter_plot_to_axis(subplots[4][1], range(player_df.shape[0]), player_df["ghosts_captured"], "Ghosts captured x player generation", "ghosts captured")

	## Ghosts/pill x autoplayer generation
	add_scatter_plot_to_axis(subplots[4][2], range(player_df.shape[0]), player_df["ghosts_captured"]/player_df["pills_captured"], "Ghost/Pill x player generation", "Ghost/Pill")

	## Visited_count x autoplayer generation
	add_scatter_plot_to_axis(subplots[5][0], range(player_df.shape[0]), player_df["visited_count"], "Grid cells visited x player generation", "grid cells visited")

	## grid_cell_changes/updates x autoplayer generation
	add_scatter_plot_to_axis(subplots[5][1], range(player_df.shape[0]), player_df["grid_cell_changes"]/player_df["updates"], "Grid cells changes/updates  x player generation", "grid cells changes/updates")

	## collision_count/updates x autoplayer generation
	add_scatter_plot_to_axis(subplots[5][2], range(player_df.shape[0]), player_df["collision_count"]/player_df["updates"], "Collision count/updates x player generation", "collision count/updates")

	#Plot and save
	plt.subplots_adjust(
		left=0.1,
		bottom=0.1,
		right=0.9,
		top=0.9,
		wspace=0.2,
		hspace=0.4)

	plt.savefig(f"{run_dict['path']}{run_dict['run_id']}_all2.png", dpi = 100)
	plt.show()
	plt.close()

	return errors


def count_captured(row, df):
	if row["actor_type"] == "player":
		player_id = row["actor_id"]
		return df[df["other_id"] == player_id].shape[0]
	else:
		return None

def load_dataframe(path, run):
	actors_df = None
	errors = list()
	if (OVERRIDE_OLD_DATAFRAME) or (not os.path.exists(f"{path}{run}.pd")):
		data = pd.read_csv(f"{path}{run}.data_fixed", skipinitialspace = True, converters = {"genes":gene_parser}, quotechar="'")
		data = data.drop(["genes"], axis = 1)

		actors_dict = create_lifetime_dict(data)
		actors_df = pd.DataFrame.from_dict(actors_dict, orient="index")

		# clean not destructed
		# print(actors_df["destruction"].isna().sum())
		actors_df["destruction"].dropna(inplace = True)

		# lifetimes
		actors_df["lifetime"] = actors_df["destruction"] - actors_df["creation"]

		# updates_per_second
		actors_df["updates_per_second"] = actors_df["updates"] / actors_df["lifetime"]

		# seconds_per_update
		actors_df["seconds_per_update"] = actors_df["lifetime"] / actors_df["updates"]

		# # actors df
		# players_df = actors_df[actors_df["actor_type"] == "player"]
		# ghosts_df = actors_df[actors_df["actor_type"] == "ghost"]
		# pills_df = actors_df[actors_df["actor_type"] == "pill"]

		# ghosts caught per player
		actors_df["ghosts_captured"] = actors_df.apply(count_captured, axis = 1, args = (actors_df[actors_df["actor_type"] == "ghost"],))

		# pills caught per player
		actors_df["pills_captured"] = actors_df.apply(count_captured, axis = 1, args = (actors_df[actors_df["actor_type"] == "pill"],))

		actors_df.index = pd.RangeIndex(len(actors_df.index))
		actors_df.to_csv(f"{path}{run}.pd", index=False)
	else:
		print("Dataframe: ", f"{path}{run}.pd", " loaded.")
		actors_df = pd.read_csv(f"{path}{run}.pd")

	return actors_df, errors

####################################################################################################################################
# def json_parser(data):
# 	fixed = json_quote_properties(data)
# 	fixed = json_replace_equals(fixed)
# 	#print(data, fixed)
# 	return json.loads(fixed)

# def json_replace_equals(str):
# 	return str.replace('=', ':')

# def json_quote_properties(str):
# 	return re.sub(r"([A-z]+)", r'"\1"', str)

# def create_lifetime_dict_for_actor_type(actor_type, df):
# 	df_destruction = df[df["event_type"] == "destroyed"]
# 	df_creation = df[df["event_type"] == "created"]

# 	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
# 	df_actor_creation = df_creation[df_creation["actor_type"] == actor_type]

# 	# lifetime dict
# 	lifetimes_dict = {}
# 	for _, row in df_actor_destruction.iterrows():
# 		id = row["actor_id"]

# 		if not id in lifetimes_dict:
# 			lifetimes_dict[id] = dict()

# 		this_entry = lifetimes_dict[id]
# 		this_entry["actor_id"] = row["actor_id"]
# 		this_entry["actor_type"] = row["actor_type"]
# 		this_entry["other"] = row["other"]
# 		this_entry["updates"] = row["updates"]
# 		this_entry["no_pill_updates"] = row["no_pill_updates"]
# 		this_entry["visited_count"] = row["visited_count"]
# 		this_entry["grid_cell_changes"] = row["grid_cell_changes"]
# 		this_entry["collision_count"] = row["collision_count"]

# 		this_entry["destruction"] = row["timestamp"]


# 	for _, row in df_actor_creation.iterrows():
# 		id = row["actor_id"]

# 		if not id in lifetimes_dict:
# 			lifetimes_dict[id] = {"creation":None, "destruction":None}

# 		this_entry = lifetimes_dict[id]
# 		this_entry["creation"] = row["timestamp"]

# 	return lifetimes_dict

# def create_lifetimes_array(lifetimes_dict):
# 	# lifetime lists and arrays
# 	lifetime_list = []
# 	for _, value in lifetimes_dict.items():
# 		if (value["destruction"] is not None) and (value["creation"] is not None):
# 			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
# 			lifetime_list.append(value["destruction"] - value["creation"])
# 			# print(key, lifetimes_dict[key]["lifetime"])
# 	return np.array(lifetime_list)

# def create_and_save_updates_per_second(lifetimes_dict, path, run, mode):
# 	# updates/second
# 	ratio_list_x = []
# 	ratio_list_y = []
# 	short_lived_x = []
# 	short_lived_y = []
# 	for index, value in lifetimes_dict.items():
# 		if (not value["destruction"] is None) and (not value["creation"] is None):
# 			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
# 			lifetime = (value["destruction"] - value["creation"])
# 			updates = value["updates"]

# 			if lifetime == 0:
# 				short_lived_x.append(index)
# 				short_lived_y.append(0)
# 			else:
# 				ratio_list_x.append(index)
# 				ratio_list_y.append(updates/lifetime)


# 	# plots
# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.title("Update per second for player | run: " + run +  " | ann_mode: " + mode)
# 	plt.scatter(ratio_list_x, ratio_list_y, label = "Updates/second", alpha = 0.5)
# 	plt.scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
# 	plt.legend()
# 	plt.savefig(f"{path}{run}_update_per_second_player.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# def create_and_save_seconds_per_update(lifetimes_dict, path, run, mode):
# 	# seconds/update
# 	ratio_list_x = []
# 	ratio_list_y = []
# 	long_freeze_x = []
# 	long_freeze_y = []
# 	short_lived_x = []
# 	short_lived_y = []
# 	for index, value in lifetimes_dict.items():
# 		if (not value["destruction"] is None) and (not value["creation"] is None):
# 			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
# 			lifetime = (value["destruction"] - value["creation"])
# 			updates = value["updates"]

# 			if lifetime == 0:
# 				short_lived_x.append(index)
# 				short_lived_y.append(0.99)
# 			elif updates == 0:
# 				long_freeze_x.append(index)
# 				long_freeze_y.append(0.98)
# 				pass
# 			else:
# 				ratio_list_x.append(index)
# 				ratio_list_y.append(lifetime / updates)

# 	# plots
# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.title("Seconds per update for player | run: " + run +  " | ann_mode: " + mode)
# 	plt.scatter(ratio_list_x, ratio_list_y, label = "Seconds/update ratio", alpha = 0.5)
# 	plt.scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
# 	plt.scatter(long_freeze_x, long_freeze_y, color = "purple", label = "long freeze", alpha = 0.3)
# 	plt.legend()
# 	plt.savefig(f"{path}{run}_update_ratio_player.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# def create_and_save_destruction_heatmap(actor_type, df, path, run, mode):
# 	df_destruction = df[df["event_type"] == "destroyed"]
# 	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
# 	# heatmap_points = list(zip(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"]))

# 	heatmap_hist, xedges, yedges = np.histogram2d(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"], bins = (28, 14))
# 	extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
# 	#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.imshow(heatmap_hist.T, extent = extent)
# 	plt.title("Destruction Heatmap for " + actor_type + " | run: " + run + " | ann_mode: " + mode)
# 	plt.colorbar()
# 	plt.savefig(f"{path}{run}_heatmap_{actor_type}.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# def create_and_save_lifetime_plot(lifetimes_array, actor_type, path, run, mode):
# 	lifetime_avg_array_100 = create_array_of_interval_mean(lifetimes_array, 100)
# 	lifetime_avg_array_10 = create_array_of_interval_mean(lifetimes_array, 10)

# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.title("Lifetimes for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
# 	plt.scatter(range(1, len(lifetimes_array) + 1), lifetimes_array, label = "lifetime", alpha = 0.1)
# 	plt.legend()
# 	plt.savefig(f"{path}{run}_lifetime_plot_{actor_type}.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.title("Mean lifetime for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
# 	plt.plot(lifetime_avg_array_100, label = "intervalar mean 100 blocks", alpha = 0.5)
# 	plt.plot(lifetime_avg_array_10, label = "intervalar mean 10 blocks")
# 	plt.hlines(lifetimes_array.mean(), 0, len(lifetimes_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
# 	plt.legend()
# 	plt.savefig(f"{path}{run}_lifetime_means_{actor_type}.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# 	plt.clf()
# 	plt.figure(figsize = FIG_SIZE)
# 	plt.title("Intervalar Lifetime Boxplot for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
# 	plt.boxplot(np.array_split(lifetimes_array.tolist(), 10))
# 	plt.savefig(f"{path}{run}_lifetime_boxplot10_{actor_type}.png", dpi = 100)
# 	# plt.show()
# 	plt.close()

# def create_plots(path, run):
# 	this_baseline_mode = None
# 	this_ann_layers = None
# 	print(path, run)
# 	with open(f"{path}{run}.conf", 'r') as f:
# 		for line in f.readlines():
# 			if BASELINE_STRING in line:
# 				this_baseline_mode = line.replace(BASELINE_STRING, "")
# 				print(this_baseline_mode)
# 			elif ANN_LAYERS_STRING in line:
# 				this_ann_layers = line.replace(ANN_LAYERS_STRING, "")
# 				print(this_ann_layers)

# 	data = pd.read_csv(f"{path}{run}.data_fixed", skipinitialspace = True, converters = {"genes":gene_parser}, quotechar="'")
# 	data = data.drop(["genes"], axis = 1)
# 	print("loaded data!")
# 	# print(data.info())

# 	# create_and_save_destruction_heatmap("player", data, path, run, this_baseline_mode)
# 	# create_and_save_destruction_heatmap("ghost", data, path, run, this_baseline_mode)
# 	# create_and_save_destruction_heatmap("pill", data, path, run, this_baseline_mode)

# 	player_lifetimes_dict = create_lifetime_dict_for_actor_type("player", data)
# 	ghost_lifetimes_dict = create_lifetime_dict_for_actor_type("ghost", data)
# 	pill_lifetimes_dict = create_lifetime_dict_for_actor_type("pill", data)

# 	player_lifetimes_array = create_lifetimes_array(player_lifetimes_dict)
# 	ghost_lifetimes_array = create_lifetimes_array(ghost_lifetimes_dict)
# 	pill_lifetimes_array = create_lifetimes_array(pill_lifetimes_dict)

# 	# create_and_save_seconds_per_update(player_lifetimes_dict, path, run, this_baseline_mode)
# 	# create_and_save_updates_per_second(player_lifetimes_dict, path, run, this_baseline_mode)

# 	# create_and_save_lifetime_plot(player_lifetimes_array, "player", path, run, this_baseline_mode)
# 	# create_and_save_lifetime_plot(ghost_lifetimes_array, "ghost", path, run, this_baseline_mode)
# 	# create_and_save_lifetime_plot(pill_lifetimes_array, "pill", path, run, this_baseline_mode)

# 	actor_lifetimes_dict = {
# 		"player": player_lifetimes_array,
# 		"ghost": ghost_lifetimes_array,
# 		"pill": pill_lifetimes_array,
# 	}
# 	return create_analysis_plot(data, actor_lifetimes_dict, player_lifetimes_dict, path, run, this_baseline_mode)
