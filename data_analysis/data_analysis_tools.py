import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import os
import json
import re

########################################################################## Config
FIG_SIZE = (32, 48)
# FIG_SIZE = (8, 6)

BASELINE_STRING = "autoplayer_ann_mode = "
ANN_LAYERS_STRING = "autoplayer_ann_layers = "

########################################################################## Data Processing
# def json_parser(data):
# 	fixed = json_quote_properties(data)
# 	fixed = json_replace_equals(fixed)
# 	#print(data, fixed)
# 	return json.loads(fixed)

# def json_replace_equals(str):
# 	return str.replace('=', ':')

# def json_quote_properties(str):
# 	return re.sub(r"([A-z]+)", r'"\1"', str)

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

def create_lifetimes_dict(actor_type, df):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_creation = df[df["event_type"] == "created"]

	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
	df_actor_creation = df_creation[df_creation["actor_type"] == actor_type]

	# lifetime dict
	lifetimes_dict = {}
	for _, row in df_actor_destruction.iterrows():
		id = row["actor_id"]

		if not id in lifetimes_dict:
			lifetimes_dict[id] = dict()

		this_entry = lifetimes_dict[id]
		this_entry["updates"] = row["updates"]
		this_entry["destruction"] = row["timestamp"]

	for _, row in df_actor_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetimes_dict:
			lifetimes_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetimes_dict[id]
		this_entry["creation"] = row["timestamp"]

	return lifetimes_dict

def create_lifetimes_array(lifetimes_dict):
	# lifetime lists and arrays
	lifetime_list = []
	for _, value in lifetimes_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetimes_dict[key]["lifetime"] = value["destruction"] - value["creation"]
			lifetime_list.append(value["destruction"] - value["creation"])
			# print(key, lifetimes_dict[key]["lifetime"])
	return np.array(lifetime_list)

def create_and_save_updates_per_second(lifetimes_dict, path, run, mode):
	# updates/second
	ratio_list_x = []
	ratio_list_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in lifetimes_dict.items():
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


	# plots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Update per second for player | run: " + run +  " | ann_mode: " + mode)
	plt.scatter(ratio_list_x, ratio_list_y, label = "Updates/second", alpha = 0.5)
	plt.scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	plt.legend()
	plt.savefig(f"{path}{run}_update_per_second_player.png", dpi = 100)
	# plt.show()
	plt.close()

def create_and_save_seconds_per_update(lifetimes_dict, path, run, mode):
	# seconds/update
	ratio_list_x = []
	ratio_list_y = []
	long_freeze_x = []
	long_freeze_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in lifetimes_dict.items():
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

	# plots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Seconds per update for player | run: " + run +  " | ann_mode: " + mode)
	plt.scatter(ratio_list_x, ratio_list_y, label = "Seconds/update ratio", alpha = 0.5)
	plt.scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	plt.scatter(long_freeze_x, long_freeze_y, color = "purple", label = "long freeze", alpha = 0.3)
	plt.legend()
	plt.savefig(f"{path}{run}_update_ratio_player.png", dpi = 100)
	# plt.show()
	plt.close()

def create_and_save_destruction_heatmap(actor_type, df, path, run, mode):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
	# heatmap_points = list(zip(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"]))

	heatmap_hist, xedges, yedges = np.histogram2d(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"], bins = (28, 14))
	extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
	#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.imshow(heatmap_hist.T, extent = extent)
	plt.title("Destruction Heatmap for " + actor_type + " | run: " + run + " | ann_mode: " + mode)
	plt.colorbar()
	plt.savefig(f"{path}{run}_heatmap_{actor_type}.png", dpi = 100)
	# plt.show()
	plt.close()

def create_and_save_lifetime_plot(lifetimes_array, actor_type, path, run, mode):
	lifetime_avg_array_100 = create_array_of_interval_mean(lifetimes_array, 100)
	lifetime_avg_array_10 = create_array_of_interval_mean(lifetimes_array, 10)

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Lifetimes for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.scatter(range(len(lifetimes_array)), lifetimes_array, label = "lifetime", alpha = 0.1)
	plt.legend()
	plt.savefig(f"{path}{run}_lifetime_plot_{actor_type}.png", dpi = 100)
	# plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Mean lifetime for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.plot(lifetime_avg_array_100, label = "intervalar mean 100 blocks", alpha = 0.5)
	plt.plot(lifetime_avg_array_10, label = "intervalar mean 10 blocks")
	plt.hlines(lifetimes_array.mean(), 0, len(lifetimes_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
	plt.legend()
	plt.savefig(f"{path}{run}_lifetime_means_{actor_type}.png", dpi = 100)
	# plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Intervalar Lifetime Boxplot for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.boxplot(np.array_split(lifetimes_array.tolist(), 10))
	plt.savefig(f"{path}{run}_lifetime_boxplot10_{actor_type}.png", dpi = 100)
	# plt.show()
	plt.close()

def create_analysis_plot(df, actor_lifetimes_dict, player_lifetimes_dict, path, run, mode):
	# subplots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)

	fig, subplots = plt.subplots(5, 3, figsize = FIG_SIZE)

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

	subplot_row[0].set_title("Update per second for player | run: " + run +  " | ann_mode: " + mode)
	subplot_row[0].scatter(ratio_list_x, ratio_list_y, label = "Updates/second", alpha = 0.5)
	subplot_row[0].scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	subplot_row[0].legend()
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

	subplot_row[1].set_title("Seconds per update for player | run: " + run +  " | ann_mode: " + mode)
	subplot_row[1].scatter(ratio_list_x, ratio_list_y, label = "Seconds/update ratio", alpha = 0.5)
	subplot_row[1].scatter(short_lived_x, short_lived_y, color = "red", label = "short lived", alpha = 0.3)
	subplot_row[1].scatter(long_freeze_x, long_freeze_y, color = "purple", label = "long freeze", alpha = 0.3)
	subplot_row[1].legend()
	# updates
	updates_x = []
	updates_y = []
	counter = 0
	for index, value in player_lifetimes_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			counter = counter + 1
			updates_x.append(counter)
			updates_y.append(value["updates"])

	subplot_row[2].set_title("Seconds per update for player | run: " + run +  " | ann_mode: " + mode)
	subplot_row[2].scatter(updates_x, updates_y, label = "Seconds/update ratio", alpha = 0.5)
	subplot_row[2].legend()

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
		ax.set_title("Destruction Heatmap for " + actor_type + " | run: " + run + " | ann_mode: " + mode)
		plt.colorbar(img, ax = ax, location = "bottom")

	# lifetimes
	line_index = 2
	for actor_type, lifetimes_array in actor_lifetimes_dict.items():
		subplot_row = subplots[line_index]
		line_index = line_index + 1

		lifetime_avg_array_100 = create_array_of_interval_mean(lifetimes_array, 100)
		lifetime_avg_array_10 = create_array_of_interval_mean(lifetimes_array, 10)

		ax1 = subplot_row[0]
		ax1.set_title("Lifetimes for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
		ax1.scatter(range(len(lifetimes_array)), lifetimes_array, label = "lifetime", alpha = 0.1)
		ax1.legend()

		ax2 = subplot_row[1]
		ax2.set_title("Mean Lifetime for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
		ax2.plot(lifetime_avg_array_100, label = "intervalar mean 100 blocks", alpha = 0.5)
		ax2.plot(lifetime_avg_array_10, label = "intervalar mean 10 blocks")
		ax2.hlines(lifetimes_array.mean(), 0, len(lifetimes_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
		ax2.legend()

		ax3 = subplot_row[2]
		ax3.set_title("Intervalar Lifetimes Boxplot for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
		ax3.boxplot(np.array_split(lifetimes_array.tolist(), 10))

	plt.savefig(f"{path}{run}_all.png", dpi = 100)
	plt.show()
	plt.close()

def create_plots(path, run):
	this_baseline_mode = None
	this_ann_layers = None
	print(path, run)
	with open(f"{path}{run}.conf", 'r') as f:
		for line in f.readlines():
			if BASELINE_STRING in line:
				this_baseline_mode = line.replace(BASELINE_STRING, "")
				print(this_baseline_mode)
			elif ANN_LAYERS_STRING in line:
				this_ann_layers = line.replace(ANN_LAYERS_STRING, "")
				print(this_ann_layers)

	data = pd.read_csv(f"{path}{run}.data_fixed", skipinitialspace = True, converters = {"genes":gene_parser}, quotechar="'")
	print("loaded data!")
	# print(data.info())

	# create_and_save_destruction_heatmap("player", data, path, run, this_baseline_mode)
	# create_and_save_destruction_heatmap("ghost", data, path, run, this_baseline_mode)
	# create_and_save_destruction_heatmap("pill", data, path, run, this_baseline_mode)

	player_lifetimes_dict = create_lifetimes_dict("player", data)
	ghost_lifetimes_dict = create_lifetimes_dict("ghost", data)
	pill_lifetimes_dict = create_lifetimes_dict("pill", data)

	player_lifetimes_array = create_lifetimes_array(player_lifetimes_dict)
	ghost_lifetimes_array = create_lifetimes_array(ghost_lifetimes_dict)
	pill_lifetimes_array = create_lifetimes_array(pill_lifetimes_dict)

	# create_and_save_seconds_per_update(player_lifetimes_dict, path, run, this_baseline_mode)
	# create_and_save_updates_per_second(player_lifetimes_dict, path, run, this_baseline_mode)

	# create_and_save_lifetime_plot(player_lifetimes_array, "player", path, run, this_baseline_mode)
	# create_and_save_lifetime_plot(ghost_lifetimes_array, "ghost", path, run, this_baseline_mode)
	# create_and_save_lifetime_plot(pill_lifetimes_array, "pill", path, run, this_baseline_mode)

	actor_lifetimes_dict = {
		"player": player_lifetimes_array,
		"ghost": ghost_lifetimes_array,
		"pill": pill_lifetimes_array,
	}
	create_analysis_plot(data, actor_lifetimes_dict, player_lifetimes_dict, path, run, this_baseline_mode)