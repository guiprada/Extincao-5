import numpy as np
import matplotlib.pyplot as plt
import os

FIG_SIZE = (32, 24)
# FIG_SIZE = (8, 6)

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

def create_and_save_destruction_heatmap(df, actor_type, path, run, mode):
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
	plt.show()
	plt.close()

def create_and_save_updates_per_second(df, path, run, mode):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_creation = df[df["event_type"] == "created"]

	df_actor_destruction = df_destruction[df_destruction["actor_type"] == "player"]
	df_actor_creation = df_creation[df_creation["actor_type"] == "player"]

	# lifetime dict
	lifetime_dict = {}
	for _, row in df_actor_destruction.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = dict()

		this_entry = lifetime_dict[id]
		this_entry["updates"] = row["updates"]
		this_entry["destruction"] = row["timestamp"]

	for _, row in df_actor_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetime_dict[id]
		this_entry["creation"] = row["timestamp"]

	# seconds/update
	ratio_list_x = []
	ratio_list_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in lifetime_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetime_dict[key]["lifetime"] = value["destruction"] - value["creation"]
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
	plt.plot(ratio_list_x, ratio_list_y, label = "Updates/second")
	plt.plot(short_lived_x, short_lived_y, color = "red", linestyle = "dotted", label = "short lived")
	plt.legend()
	plt.savefig(f"{path}{run}_update_per_second_player.png", dpi = 100)
	plt.show()
	plt.close()

def create_and_save_seconds_per_update(df, path, run, mode):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_creation = df[df["event_type"] == "created"]

	df_actor_destruction = df_destruction[df_destruction["actor_type"] == "player"]
	df_actor_creation = df_creation[df_creation["actor_type"] == "player"]

	# lifetime dict
	lifetime_dict = {}
	for _, row in df_actor_destruction.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = dict()

		this_entry = lifetime_dict[id]
		this_entry["updates"] = row["updates"]
		this_entry["destruction"] = row["timestamp"]

	for _, row in df_actor_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetime_dict[id]
		this_entry["creation"] = row["timestamp"]

	# seconds/update
	ratio_list_x = []
	ratio_list_y = []
	long_freeze_x = []
	long_freeze_y = []
	short_lived_x = []
	short_lived_y = []
	for index, value in lifetime_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetime_dict[key]["lifetime"] = value["destruction"] - value["creation"]
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
	plt.plot(ratio_list_x, ratio_list_y, label = "Seconds/update ratio")
	plt.plot(short_lived_x, short_lived_y, color = "red", linestyle = "dotted", label = "short lived")
	plt.plot(long_freeze_x, long_freeze_y, color = "green", linestyle = "dotted", label = "long freeze")
	plt.plot()
	plt.legend()
	plt.savefig(f"{path}{run}_update_ratio_player.png", dpi = 100)
	plt.show()
	plt.close()

def create_and_save_lifetime_plot(df, actor_type, path, run, mode):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_creation = df[df["event_type"] == "created"]

	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
	df_actor_creation = df_creation[df_creation["actor_type"] == actor_type]

	# lifetime dict
	lifetime_dict = {}
	for _, row in df_actor_destruction.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetime_dict[id]
		this_entry["destruction"] = row["timestamp"]

	for _, row in df_actor_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetime_dict:
			lifetime_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetime_dict[id]
		this_entry["creation"] = row["timestamp"]

	# lifetime lists and arrays
	lifetime_list = []
	for _, value in lifetime_dict.items():
		if (not value["destruction"] is None) and (not value["creation"] is None):
			# lifetime_dict[key]["lifetime"] = value["destruction"] - value["creation"]
			lifetime_list.append(value["destruction"] - value["creation"])
			# print(key, lifetime_dict[key]["lifetime"])
	lifetime_array = np.array(lifetime_list)

	lifetime_arrays_list_100 = np.array_split(lifetime_array, 100)
	lifetime_avg_list_100 = []
	for subarray in lifetime_arrays_list_100:
		avg = subarray.mean()
		new_avg = np.full(len(subarray), avg)
		lifetime_avg_list_100.extend(new_avg.tolist())

	lifetime_arrays_list_10 = np.array_split(lifetime_array, 10)
	lifetime_avg_list_10 = []
	for subarray in lifetime_arrays_list_10:
		avg = subarray.mean()
		new_avg = np.full(len(subarray), avg)
		lifetime_avg_list_10.extend(new_avg.tolist())

	# plots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Lifetimes and Mean for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.plot(lifetime_array, label = "lifetime", alpha = 0.1)
	plt.plot(lifetime_avg_list_100, label = "intervalar mean 100 blocks", alpha = 0.3)
	plt.plot(lifetime_avg_list_10, label = "intervalar mean 10 blocks")
	plt.hlines(lifetime_array.mean(), 0, len(lifetime_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
	plt.legend()
	plt.savefig(f"{path}{run}_lifetime_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Lifetimes for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.plot(lifetime_array, label = "lifetime", alpha = 0.8)
	plt.legend()
	plt.savefig(f"{path}{run}_lifetime_plot_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Mean for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.plot(lifetime_avg_list_100, label = "intervalar mean 100 blocks", alpha = 0.3)
	plt.plot(lifetime_avg_list_10, label = "intervalar mean 10 blocks")
	plt.hlines(lifetime_array.mean(), 0, len(lifetime_array), label = "mean", colors = "red", linestyles = "dotted", alpha = 0.5)
	plt.legend()
	plt.savefig(f"{path}{run}_lifetime_means_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Intervalar Boxplot for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.boxplot(lifetime_arrays_list_10)
	plt.savefig(f"{path}{run}_lifetime_boxplot10_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()

	plt.clf()
	plt.figure(figsize = FIG_SIZE)
	plt.title("Intervalar Boxplot for " + actor_type + " | run: " + run +  " | ann_mode: " + mode)
	plt.boxplot(lifetime_arrays_list_100)
	plt.savefig(f"{path}{run}_lifetime_boxplot100_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()

	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]

	return lifetime_array