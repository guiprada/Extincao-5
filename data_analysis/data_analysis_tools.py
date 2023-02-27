import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import scipy.stats as stats
import os
import json
import re
import math

#timestamp, actor_id, actor_type, event_type, other, cell_x, cell_y, updates, no_pill_updates, visited_count, grid_cell_changes, collision_count, genes
########################################################################## Config
# FIG_SIZE = (16, 24)
FIG_SIZE = (12, 18)

SMALL_LEGEND_FONTSIZE = 10

ANN_MODE_STRING = "autoplayer_ann_mode = "
ANN_LAYERS_STRING = "autoplayer_ann_layers = "

OVERRIDE_OLD_DATAFRAME = False

IMAGE_DPI = 100

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
		if "lifetime" in row:
			this_entry["internal_lifetime"] = row["lifetime"]
			this_entry["fps"] = row["fps"]

		this_entry["destruction"] = row["timestamp"]


	for _, row in df_creation.iterrows():
		id = row["actor_id"]

		if not id in lifetimes_dict:
			lifetimes_dict[id] = {"creation":None, "destruction":None}

		this_entry = lifetimes_dict[id]
		this_entry["creation"] = row["timestamp"]

	return lifetimes_dict

def add_scatter_plot_to_axis(axis, scatter_x, scatter_y, title, label, alpha = 1, scale = 1):
	axis.set_title(title)
	axis.scatter(scatter_x, scatter_y, label = label, alpha = alpha, edgecolors='none', s = scale)
	axis.hlines(scatter_y.mean(), 0, len(scatter_x), label = "mean", colors = "red", linestyles = "dotted", alpha = 1)
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	# axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def add_scatter_plot_to_axis_from_dicts(axis, plot_dicts_list, title, yticks = None, legend_loc = "best"):
	axis.set_title(title)

	if yticks is not None:
		axis.set_yticks(yticks)

	for plot_dict in plot_dicts_list:
		axis.scatter(plot_dict["x"], plot_dict["y"], label = plot_dict["label"], alpha = plot_dict["alpha"], color = plot_dict["color"], s = plot_dict["scale"], edgecolors='none')
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')

	axis.legend(fontsize = SMALL_LEGEND_FONTSIZE, loc = legend_loc)

def add_heatmap_to_axis(axis, x, y, bins, title):
	heatmap_hist, xedges, yedges = np.histogram2d(x, y, bins)
	extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
	#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

	img = axis.imshow(heatmap_hist.T, extent = extent)
	axis.set_title(title)
	# plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	plt.colorbar(img, ax = axis, location = "left")

def add_intervalar_means_plot_to_axis(axis, scatter_x, scatter_y, title, alpha = 1):
		scatter_y_100 = create_array_of_interval_mean(scatter_y, 100)
		scatter_y_10 = create_array_of_interval_mean(scatter_y, 10)

		axis.set_title(title)
		axis.plot(scatter_x, scatter_y_100, label = "intervalar mean 100 blocks", color = "blue", alpha = alpha)
		axis.plot(scatter_x, scatter_y_10, label = "intervalar mean 10 blocks", color = "green", alpha = alpha)
		axis.hlines(scatter_y.mean(), 0, len(scatter_x), label = "mean", colors = "red", linestyles = "dotted", alpha = alpha)
		plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
		axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def add_scatter_and_intervalar_means_plot_to_axis(axis, scatter_x, scatter_y, title, label, scale = 1, alpha = 1):
	scatter_y_100 = create_array_of_interval_mean(scatter_y, 100)
	scatter_y_10 = create_array_of_interval_mean(scatter_y, 10)

	axis.set_title(title)
	# clip_max = scatter_y_100.max()
	# clip_min = scatter_y_100.min()
	# scatter_zip = zip(scatter_x, scatter_y)
	# scatter_zip_clipped = [p for p in scatter_zip if p[1] <= clip_max and p[1]>= clip_min]
	# if len(scatter_zip_clipped) > 0:
	# 	scatter_x_clipped, scatter_y_clipped = zip(*scatter_zip_clipped)
	# 	axis.scatter(scatter_x_clipped, scatter_y_clipped, label = label, alpha = alpha, color = "orange", edgecolors='none', s = scale)
	axis.plot(scatter_x, scatter_y_100, label = "intervalar mean 100 blocks", color = "green", alpha = alpha)
	axis.plot(scatter_x, scatter_y_10, label = "intervalar mean 10 blocks", color = "purple", alpha = alpha)
	axis.hlines(scatter_y.mean(), 0, scatter_x.max(), label = "mean", colors = "red", linestyles = "dotted", alpha = alpha)
	axis.ticklabel_format(style = "plain")
	plt.setp(axis.get_xticklabels(), rotation=30, horizontalalignment='right')
	# axis.legend(fontsize = SMALL_LEGEND_FONTSIZE)

def add_distribution_plot_to_axis(axis, data, title):
	axis.set_title(title)
	axis.hist(data, bins = 50)

def mann_whitneyu_compare(A, B, label, alpha = 0.05):
		text_analysis = label + ":"

		##
		mw_eq = stats.mannwhitneyu(A, B, use_continuity=True, alternative = "two-sided")
		text_analysis += "\n" + "mannwhitneyu two-sided: " + str(mw_eq)
		if mw_eq[1] < alpha:
			text_analysis += "  --  reject equal"
		else:
			text_analysis += "  --  accept equal"

		##
		mw_less = stats.mannwhitneyu(A, B, use_continuity=True, alternative = "less")
		text_analysis += "\n" + "mannwhitneyu less: "+ str(mw_less)

		if mw_less[1] < (alpha/2):
			text_analysis += "  --  A less than B"
		else:
			text_analysis += "  --  accept equal"

		##
		mw_more = stats.mannwhitneyu(A, B, use_continuity=True, alternative = "greater")
		text_analysis += "\n" + "mannwhitneyu greater: "+ str(mw_more)

		if mw_more[1] < (alpha/2):
			text_analysis += "  --  A greater than B"
		else:
			text_analysis += "  --  accept equal"

		return text_analysis

def compare_run_dict_list_means(run_dict_A, run_dict_B):
	player_df_A = run_dict_A["df"].loc[run_dict_A["df"]["actor_type"] == "player"]
	player_df_B = run_dict_B["df"].loc[run_dict_B["df"]["actor_type"] == "player"]

	ghost_df_A = run_dict_A["df"].loc[run_dict_A["df"]["actor_type"] == "ghost"]
	ghost_df_B = run_dict_B["df"].loc[run_dict_B["df"]["actor_type"] == "ghost"]

	pill_df_A = run_dict_A["df"].loc[run_dict_A["df"]["actor_type"] == "pill"]
	pill_df_B = run_dict_B["df"].loc[run_dict_B["df"]["actor_type"] == "pill"]

	# non_zero_lifetime_player_df = player_df.query("lifetime > 0")
	# non_zero_updates_player_df = player_df.query("updates > 0")
	# non_zero_pills_captured_player_df = player_df.query("pills_captured > 0")

	text_analysis = ""
	#updates per second
	text_analysis += mann_whitneyu_compare(player_df_A["updates_per_second"].dropna(), player_df_B["updates_per_second"].dropna(), "updates/second") + "\n\n"

	#updates
	text_analysis += mann_whitneyu_compare(player_df_A["updates"].dropna(), player_df_B["updates"].dropna(), "updates") + "\n\n"

	#lifetime
	text_analysis += mann_whitneyu_compare(player_df_A["lifetime"].dropna(), player_df_B["lifetime"].dropna(), "lifetime") + "\n\n"

	#ghost lifetime
	text_analysis += mann_whitneyu_compare(ghost_df_A["lifetime"].dropna(), ghost_df_B["lifetime"].dropna(), "ghost lifetime") + "\n\n"

	#pill lifetime
	text_analysis += mann_whitneyu_compare(pill_df_A["lifetime"].dropna(), pill_df_B["lifetime"].dropna(), "pill lifetime") + "\n\n"

	#pills_captured
	text_analysis += mann_whitneyu_compare(player_df_A["pills_captured"].dropna(), player_df_B["pills_captured"].dropna(), "pills_captured") + "\n\n"

	#ghosts_captured
	text_analysis += mann_whitneyu_compare(player_df_A["pills_captured"].dropna(), player_df_B["pills_captured"].dropna(), "pills captured") + "\n\n"

	#ghosts_caputred/pill_captured
	#visited_count
	#grid_cell_changes/updates
	#collision_count/updates


	print(text_analysis)

def filter_low_performance(df, intervals = 10):
	# performance_df = df["updates_per_second"]
	# performance_df_intervals = create_array_of_interval_mean(performance_df, 100)
	# cut_position_start = 0
	# cut_position_end = 0
	# for interval in performance_df_intervals:
		# print(interval)
	if df["run_id"] in ["1675110985", "1675111001", "1675111017"]:
		entries = df["df"].shape[0]
		drop_point = entries/2
		print(entries, drop_point)
		df["df"] = df["df"][:math.floor(drop_point)]
		print(df["df"].head())
		print(df["df"].tail())

def generate_run_report_from_dict(run_dict, filter_low_performance = False, show = False):
	if "internal_lifetime" in run_dict["df"]:
		print("--------------------------------------------------------------------------------------------------------")
		return generate_run_report_from_dict_internal_lifetime(run_dict, filter_low_performance = filter_low_performance, show = show)

	if filter_low_performance:
		filter_low_performance(run_dict["df"])

	player_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "player"]
	non_zero_lifetime_player_df = player_df.query("lifetime > 0")
	non_zero_updates_player_df = player_df.query("updates > 0")
	non_zero_pills_captured_player_df = player_df.query("pills_captured > 0")

	# player_df.index += 1
	player_df.reset_index(drop = True, inplace=True)
	player_df.reset_index(inplace=True)

	non_zero_lifetime_player_df.reset_index(drop = True, inplace=True)
	non_zero_lifetime_player_df.reset_index(inplace=True)
	non_zero_updates_player_df.reset_index(drop = True, inplace=True)
	non_zero_updates_player_df.reset_index(inplace=True)
	non_zero_pills_captured_player_df.reset_index(drop = True, inplace=True)
	non_zero_pills_captured_player_df.reset_index(inplace=True)

	ghost_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "ghost"]
	ghost_df.reset_index(drop = True, inplace=True)
	ghost_df.reset_index(inplace = True)

	pill_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "pill"]
	pill_df.reset_index(drop = True, inplace=True)
	pill_df.reset_index(inplace = True)

	errors = list()

	# subplots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)

	fig, subplots = plt.subplot_mosaic(
	"""
	AAABBB
	CCCDDD
	EEEFFF
	GGGHHH
	IIJJKK
	LLMMNN
	""",figsize = FIG_SIZE)

	## Config string
	config_string = "run: " + run_dict["run_id"] +  " | ann_mode: " + run_dict["mode"]
	if "layers" in run_dict:
		config_string = config_string + run_dict["layers"].replace("}, {", "},\n{")

	fig.suptitle(config_string, size = 20, y = 0)

	## Updates/second
	add_scatter_plot_to_axis(subplots["A"], non_zero_lifetime_player_df["index"], non_zero_lifetime_player_df["updates_per_second"], "updates/lifetime x player iteration(lifetime>0)", "updates/lifetime", alpha = 1, scale = 1)

	## Updates per player
	add_scatter_plot_to_axis(subplots["B"], player_df["index"], player_df["updates"], "updates x player iteration", "updates", alpha = 1, scale = 1)

	## Player
	add_heatmap_to_axis(subplots["C"], player_df["cell_x"], player_df["cell_y"], bins = (28, 14), title = "Capture heatmap for player")
	add_scatter_plot_to_axis(subplots["D"], player_df["index"], player_df["lifetime"], "lifetime x player iteration", "lifetime", alpha = 1, scale = 1)

	## Ghost
	add_heatmap_to_axis(subplots["E"], ghost_df["cell_x"], ghost_df["cell_y"], bins = (28, 14), title = "Capture heatmap for ghost")
	add_scatter_plot_to_axis(subplots["F"], ghost_df["index"], ghost_df["lifetime"], "lifetime x ghost iteration", "lifetime", alpha = 1, scale = 1)

	## Pills
	add_heatmap_to_axis(subplots["G"], pill_df["cell_x"], pill_df["cell_y"], bins = (28, 14), title = "Capture heatmap for pill")
	add_scatter_plot_to_axis(subplots["H"], pill_df["index"], pill_df["lifetime"], "lifetime x pill iteration", "lifetime", alpha = 1, scale = 1)

	## pills captured x autoplayer generation
	add_scatter_plot_to_axis(subplots["I"], player_df["index"], player_df["pills_captured"], "pills_captured x player iteration", "pills_captured")

	## Ghosts captured x autoplayer generation
	add_scatter_plot_to_axis(subplots["J"], player_df["index"], player_df["ghosts_captured"], "ghosts_captured x player iteration", "ghosts_captured")

	## Ghosts/pill x autoplayer generation
	add_scatter_plot_to_axis(subplots["K"], non_zero_pills_captured_player_df["index"], non_zero_pills_captured_player_df["ghosts_captured"]/non_zero_pills_captured_player_df["pills_captured"], "ghosts_captured/pills_captured x player iteration", "ghosts_captured/pills_captured")

	## Visited_count x autoplayer generation
	add_scatter_plot_to_axis(subplots["L"], player_df["index"], player_df["visited_count"], "visited_count x player iteration", "visited_count")

	## grid_cell_changes/updates x autoplayer generation
	add_scatter_plot_to_axis(subplots["M"], non_zero_updates_player_df["index"], non_zero_updates_player_df["grid_cell_changes"]/non_zero_updates_player_df["updates"], "grid_cell_changes/updates  x player iteration", "grid_cell_changes/updates")

	## collision_count/updates x autoplayer generation
	add_scatter_plot_to_axis(subplots["N"], non_zero_updates_player_df["index"], non_zero_updates_player_df["collision_count"]/non_zero_updates_player_df["updates"], "collision_count/updates x player iteration", "collision_count/updates")

	# distributions
	# add_distribution_plot_to_axis(subplots[0][2], player_df["updates"], "updates distribution for players")
	# add_distribution_plot_to_axis(subplots[1][2], player_df["lifetime"], "lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[2][2], non_zero_lifetime_player_df["lifetime"], "non_zero lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[3][2], player_df["updates_per_second"].replace([np.inf, -np.inf], np.nan).dropna(), "updates/lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[4][2], player_df["visited_count"], "cells visited distribution for players")
	# add_distribution_plot_to_axis(subplots[5][2], player_df["grid_cell_changes"], "cell changes distribution for players")


	#Plot and save
	# plt.subplots_adjust(
	# 	# left=0.1,
	# 	# bottom=0.1,
	# 	# right=0.9,
	# 	# top=0.9,
	# 	# wspace=0.2,
	# 	hspace=0.4
	# )
	plt.tight_layout()

	plt.savefig(f"{run_dict['path']}{run_dict['run_id']}_plots.png", dpi = IMAGE_DPI)
	if show:
		plt.show()
	plt.close()

	## Analise textual
	text_analysis = config_string + '\n'
	text_analysis += "Total player entries: " + str(player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_lifetime player entries: " + str(non_zero_lifetime_player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_pills_captured player entries: " + str(non_zero_pills_captured_player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_updates player entries: " + str(non_zero_updates_player_df.shape[0])
	text_analysis += '\n' + "Total zero_lifetime player entries: " + str(player_df.query("lifetime == 0").shape[0])
	text_analysis += '\n' + "Total zero_updates player entries: " + str(player_df.query("updates == 0").shape[0])
	text_analysis += '\n' + "Total zero_updates player entries with lifetime > 0: " + str(player_df.query("updates == 0 and lifetime > 0").shape[0])
	text_analysis += '\n' + "Total zero_pill player entries: " + str(player_df.query("pills_captured == 0").shape[0])
	text_analysis += '\n' + "Total pill entries: " + str(pill_df.shape[0])
	text_analysis += '\n' + "Total ghost entries: " + str(ghost_df.shape[0])

	text_analysis += '\n' + 30*'-' + "Describes :)" + '\n'
	text_analysis += '\n' + "updates/lifetime: " + '\n' + str(non_zero_lifetime_player_df["updates_per_second"].describe()) + '\n'
	text_analysis += '\n' + "updates: " + '\n' + str(player_df["updates"].describe()) + '\n'
	text_analysis += '\n' + "lifetime for player: " + '\n' + str(player_df["lifetime"].describe()) + '\n'
	text_analysis += '\n' + "lifetime for ghosts: " + '\n' + str(ghost_df["lifetime"].describe()) + '\n'
	text_analysis += '\n' + "lifetime for pills: " + '\n' + str(pill_df["lifetime"].describe()) + '\n'
	text_analysis += '\n' + "visited_count: " + '\n' + str(player_df["visited_count"].describe()) + '\n'
	text_analysis += '\n' + "grid_cell_changes: " + '\n' + str(player_df["grid_cell_changes"].describe()) + '\n'
	text_analysis += '\n' + "grid_cell_changes/updates: " + '\n' + str((non_zero_updates_player_df["grid_cell_changes"]/non_zero_updates_player_df["updates"]).describe()) + '\n'
	text_analysis += '\n' + "collision_count: " + '\n' + str(player_df["collision_count"].describe()) + '\n'
	text_analysis += '\n' + "collision_count/updates: " + '\n' + str((non_zero_updates_player_df["collision_count"]/non_zero_updates_player_df["updates"]).describe()) + '\n'
	text_analysis += '\n' + "ghosts_captured: " + '\n' + str(player_df["ghosts_captured"].describe()) + '\n'
	text_analysis += '\n' + "pills_captured: " + '\n' + str(player_df["pills_captured"].describe()) + '\n'
	text_analysis += '\n' + "ghosts_captured/pills_captured: " + '\n' + str((non_zero_pills_captured_player_df["ghosts_captured"]/non_zero_pills_captured_player_df["pills_captured"]).describe()) + '\n'
	text_analysis += '\n' + "ghosts lifetime: " + '\n' + str(ghost_df["lifetime"].describe()) + '\n'
	text_analysis += '\n' + "pills lifetime: " + '\n' + str(pill_df["lifetime"].describe()) + '\n'

	##
	text_analysis += '\n' + 30*'-' + "Correlacoes :)" + '\n'
	text_analysis += '\n' + "A taxa de atualizacao e as outras metricas" + '\n'
	desired_correlations = {
		"updates/lifetime lifetime": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["lifetime"]),
		"updates/lifetime updates": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["updates"]),
		"updates/lifetime visited_count": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["visited_count"]),
		"updates/lifetime grid_cell_changes": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["grid_cell_changes"]),
		"updates/lifetime collision_count": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["collision_count"]),
		"updates/lifetime ghosts_captured": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["ghosts_captured"]),
		"updates/lifetime pills_captured": (non_zero_lifetime_player_df["updates_per_second"], non_zero_lifetime_player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "Updates e as outras metricas" + '\n'
	desired_correlations = {
		"updates lifetime": (player_df["updates"], player_df["lifetime"]),
		"updates visited_count": (player_df["updates"], player_df["visited_count"]),
		"updates grid_cell_changes": (player_df["updates"], player_df["grid_cell_changes"]),
		"updates collision_count": (player_df["updates"], player_df["collision_count"]),
		"updates ghosts_captured": (player_df["updates"], player_df["ghosts_captured"]),
		"updates pills_captured": (player_df["updates"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "Lifetime e as outras metricas" + '\n'
	desired_correlations = {
		"lifetime visited_count": (player_df["lifetime"], player_df["visited_count"]),
		"lifetime grid_cell_changes": (player_df["lifetime"], player_df["grid_cell_changes"]),
		"lifetime collision_count": (player_df["lifetime"], player_df["collision_count"]),
		"lifetime ghosts_captured": (player_df["lifetime"], player_df["ghosts_captured"]),
		"lifetime pills_captured": (player_df["lifetime"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "As metricas de movimentacao" + '\n'
	desired_correlations = {
		"visited_count grid_cell_changes": (player_df["visited_count"], player_df["grid_cell_changes"]),
		"visited_count collision_count": (player_df["visited_count"], player_df["collision_count"]),
		"visited_count ghosts_captured": (player_df["visited_count"], player_df["ghosts_captured"]),
		"visited_count pills_captured": (player_df["visited_count"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'


	##
	text_analysis += '\n' + "As metricas de movimentacao" + '\n'
	desired_correlations = {
		"visited_count grid_cell_changes": (player_df["visited_count"], player_df["grid_cell_changes"]),
		"visited_count collision_count": (player_df["visited_count"], player_df["collision_count"]),
		"grid_cell_changes collision_count": (player_df["grid_cell_changes"], player_df["collision_count"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "As metricas de captura" + '\n'
	desired_correlations = {
		"ghosts_captured pills_captured": (player_df["ghosts_captured"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	if show:
		print(text_analysis)

	with open(f"{run_dict['path']}{run_dict['run_id']}_analysis.txt", 'w') as f:
		f.write(text_analysis)

	return errors

def generate_run_report_from_dict_internal_lifetime(run_dict, filter_low_performance = False, show = False):
	if filter_low_performance:
		filter_low_performance(run_dict["df"])

	player_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "player"]
	non_zero_internal_lifetime_player_df = player_df.query("internal_lifetime > 0")
	non_zero_updates_player_df = player_df.query("updates > 0")
	non_zero_pills_captured_player_df = player_df.query("pills_captured > 0")

	# player_df.index += 1
	player_df.reset_index(drop = True, inplace=True)
	player_df.reset_index(inplace=True)

	non_zero_internal_lifetime_player_df.reset_index(drop = True, inplace=True)
	non_zero_internal_lifetime_player_df.reset_index(inplace=True)
	non_zero_updates_player_df.reset_index(drop = True, inplace=True)
	non_zero_updates_player_df.reset_index(inplace=True)
	non_zero_pills_captured_player_df.reset_index(drop = True, inplace=True)
	non_zero_pills_captured_player_df.reset_index(inplace=True)

	ghost_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "ghost"]
	ghost_df.reset_index(drop = True, inplace=True)
	ghost_df.reset_index(inplace = True)

	pill_df = run_dict["df"].loc[run_dict["df"]["actor_type"] == "pill"]
	pill_df.reset_index(drop = True, inplace=True)
	pill_df.reset_index(inplace = True)

	errors = list()

	# subplots
	plt.clf()
	plt.figure(figsize = FIG_SIZE)

	fig, subplots = plt.subplot_mosaic(
	"""
	AAABBB
	CCCDDD
	EEEFFF
	GGGHHH
	IIJJKK
	LLMMNN
	""",figsize = FIG_SIZE)

	## Config string
	config_string = "run: " + run_dict["run_id"] +  " | ann_mode: " + run_dict["mode"]
	if "layers" in run_dict:
		config_string = config_string + run_dict["layers"].replace("}, {", "},\n{")

	fig.suptitle(config_string, size = 20, y = 0)

	## Updates/second
	add_scatter_plot_to_axis(subplots["A"], player_df["index"], player_df["fps"], "fps x player iteration", "fps", alpha = 1, scale = 1)

	## Updates per player
	add_scatter_plot_to_axis(subplots["B"], player_df["index"], player_df["updates"], "updates x player iteration", "updates", alpha = 1, scale = 1)

	## Player
	add_heatmap_to_axis(subplots["C"], player_df["cell_x"], player_df["cell_y"], bins = (28, 14), title = "Capture heatmap for player")
	add_scatter_plot_to_axis(subplots["D"], player_df["index"], player_df["internal_lifetime"], "internal_lifetime x player iteration", "internal_lifetime", alpha = 1, scale = 1)

	## Ghost
	add_heatmap_to_axis(subplots["E"], ghost_df["cell_x"], ghost_df["cell_y"], bins = (28, 14), title = "Capture heatmap for ghost")
	add_scatter_plot_to_axis(subplots["F"], ghost_df["index"], ghost_df["internal_lifetime"], "internal_lifetime x ghost iteration", "internal_lifetime", alpha = 1, scale = 1)

	## Pills
	add_heatmap_to_axis(subplots["G"], pill_df["cell_x"], pill_df["cell_y"], bins = (28, 14), title = "Capture heatmap for pill")
	add_scatter_plot_to_axis(subplots["H"], pill_df["index"], pill_df["internal_lifetime"], "internal_lifetime x pill iteration", "internal_lifetime", alpha = 1, scale = 1)

	## pills captured x autoplayer generation
	add_scatter_plot_to_axis(subplots["I"], player_df["index"], player_df["pills_captured"], "pills_captured x player iteration", "pills_captured")

	## Ghosts captured x autoplayer generation
	add_scatter_plot_to_axis(subplots["J"], player_df["index"], player_df["ghosts_captured"], "ghosts_captured x player iteration", "ghosts_captured")

	## Ghosts/pill x autoplayer generation
	add_scatter_plot_to_axis(subplots["K"], non_zero_pills_captured_player_df["index"], non_zero_pills_captured_player_df["ghosts_captured"]/non_zero_pills_captured_player_df["pills_captured"], "ghosts_captured/pills_captured x player iteration", "ghosts_captured/pills_captured")

	## Visited_count x autoplayer generation
	add_scatter_plot_to_axis(subplots["L"], player_df["index"], player_df["visited_count"], "visited_count x player iteration", "visited_count")

	## grid_cell_changes/internal_lifetime x autoplayer generation
	add_scatter_plot_to_axis(subplots["M"], non_zero_updates_player_df["index"], non_zero_updates_player_df["grid_cell_changes"]/non_zero_updates_player_df["internal_lifetime"], "grid_cell_changes/internal_lifetime  x\n player iteration", "grid_cell_changes/internal_lifetime")

	## collision_count/internal_lifetime x autoplayer generation
	add_scatter_plot_to_axis(subplots["N"], non_zero_updates_player_df["index"], non_zero_updates_player_df["collision_count"]/non_zero_updates_player_df["internal_lifetime"], "collision_count/internal_lifetime x\n player iteration", "collision_count/internal_lifetime")

	# distributions
	# add_distribution_plot_to_axis(subplots[0][2], player_df["updates"], "updates distribution for players")
	# add_distribution_plot_to_axis(subplots[1][2], player_df["internal_lifetime"], "internal_lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[2][2], non_zero_internal_lifetime_player_df["internal_lifetime"], "non_zero internal_lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[3][2], player_df["updates_per_second"].replace([np.inf, -np.inf], np.nan).dropna(), "updates/internal_lifetime distribution for players")
	# add_distribution_plot_to_axis(subplots[4][2], player_df["visited_count"], "cells visited distribution for players")
	# add_distribution_plot_to_axis(subplots[5][2], player_df["grid_cell_changes"], "cell changes distribution for players")


	#Plot and save
	# plt.subplots_adjust(
	# 	# left=0.1,
	# 	# bottom=0.1,
	# 	# right=0.9,
	# 	# top=0.9,
	# 	# wspace=0.2,
	# 	hspace=0.4
	# )
	plt.tight_layout()

	plt.savefig(f"{run_dict['path']}{run_dict['run_id']}_plots.png", dpi = IMAGE_DPI)
	if show:
		plt.show()
	plt.close()

	## Analise textual
	text_analysis = config_string + '\n'
	text_analysis += "Total player entries: " + str(player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_internal_lifetime player entries: " + str(non_zero_internal_lifetime_player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_pills_captured player entries: " + str(non_zero_pills_captured_player_df.shape[0])
	text_analysis += '\n' + "Total non_zero_updates player entries: " + str(non_zero_updates_player_df.shape[0])
	text_analysis += '\n' + "Total zero_internal_lifetime player entries: " + str(player_df.query("internal_lifetime == 0").shape[0])
	text_analysis += '\n' + "Total zero_updates player entries: " + str(player_df.query("updates == 0").shape[0])
	text_analysis += '\n' + "Total zero_updates player entries with internal_lifetime > 0: " + str(player_df.query("updates == 0 and internal_lifetime > 0").shape[0])
	text_analysis += '\n' + "Total zero_pill player entries: " + str(player_df.query("pills_captured == 0").shape[0])
	text_analysis += '\n' + "Total pill entries: " + str(pill_df.shape[0])
	text_analysis += '\n' + "Total ghost entries: " + str(ghost_df.shape[0])

	text_analysis += '\n' + 30*'-' + "Describes :)" + '\n'
	text_analysis += '\n' + "fps: " + '\n' + str(player_df["fps"].describe()) + '\n'
	text_analysis += '\n' + "updates: " + '\n' + str(player_df["updates"].describe()) + '\n'
	text_analysis += '\n' + "internal_lifetime for player: " + '\n' + str(player_df["internal_lifetime"].describe()) + '\n'
	text_analysis += '\n' + "internal_lifetime for ghosts: " + '\n' + str(ghost_df["internal_lifetime"].describe()) + '\n'
	text_analysis += '\n' + "internal_lifetime for pills: " + '\n' + str(pill_df["internal_lifetime"].describe()) + '\n'
	text_analysis += '\n' + "visited_count: " + '\n' + str(player_df["visited_count"].describe()) + '\n'
	text_analysis += '\n' + "grid_cell_changes: " + '\n' + str(player_df["grid_cell_changes"].describe()) + '\n'
	text_analysis += '\n' + "grid_cell_changes/internal_lifetime: " + '\n' + str((non_zero_updates_player_df["grid_cell_changes"]/non_zero_updates_player_df["internal_lifetime"]).describe()) + '\n'
	text_analysis += '\n' + "collision_count: " + '\n' + str(player_df["collision_count"].describe()) + '\n'
	text_analysis += '\n' + "collision_count/internal_lifetime: " + '\n' + str((non_zero_updates_player_df["collision_count"]/non_zero_updates_player_df["internal_lifetime"]).describe()) + '\n'
	text_analysis += '\n' + "ghosts_captured: " + '\n' + str(player_df["ghosts_captured"].describe()) + '\n'
	text_analysis += '\n' + "pills_captured: " + '\n' + str(player_df["pills_captured"].describe()) + '\n'
	text_analysis += '\n' + "ghosts_captured/pills_captured: " + '\n' + str((non_zero_pills_captured_player_df["ghosts_captured"]/non_zero_pills_captured_player_df["pills_captured"]).describe()) + '\n'
	text_analysis += '\n' + "ghosts internal_lifetime: " + '\n' + str(ghost_df["internal_lifetime"].describe()) + '\n'
	text_analysis += '\n' + "pills internal_lifetime: " + '\n' + str(pill_df["internal_lifetime"].describe()) + '\n'

	##
	text_analysis += '\n' + 30*'-' + "Correlacoes :)" + '\n'
	text_analysis += '\n' + "A taxa de atualizacao e as outras metricas" + '\n'
	desired_correlations = {
		"fps internal_lifetime": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["internal_lifetime"]),
		"fps updates": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["updates"]),
		"fps visited_count": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["visited_count"]),
		"fps grid_cell_changes": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["grid_cell_changes"]),
		"fps collision_count": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["collision_count"]),
		"fps ghosts_captured": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["ghosts_captured"]),
		"fps pills_captured": (non_zero_internal_lifetime_player_df["fps"], non_zero_internal_lifetime_player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "Updates e as outras metricas" + '\n'
	desired_correlations = {
		"updates internal_lifetime": (player_df["updates"], player_df["internal_lifetime"]),
		"updates visited_count": (player_df["updates"], player_df["visited_count"]),
		"updates grid_cell_changes": (player_df["updates"], player_df["grid_cell_changes"]),
		"updates collision_count": (player_df["updates"], player_df["collision_count"]),
		"updates ghosts_captured": (player_df["updates"], player_df["ghosts_captured"]),
		"updates pills_captured": (player_df["updates"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "Internal_lifetime e as outras metricas" + '\n'
	desired_correlations = {
		"internal_lifetime visited_count": (player_df["internal_lifetime"], player_df["visited_count"]),
		"internal_lifetime grid_cell_changes": (player_df["internal_lifetime"], player_df["grid_cell_changes"]),
		"internal_lifetime collision_count": (player_df["internal_lifetime"], player_df["collision_count"]),
		"internal_lifetime ghosts_captured": (player_df["internal_lifetime"], player_df["ghosts_captured"]),
		"internal_lifetime pills_captured": (player_df["internal_lifetime"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "As metricas de movimentacao" + '\n'
	desired_correlations = {
		"visited_count grid_cell_changes": (player_df["visited_count"], player_df["grid_cell_changes"]),
		"visited_count collision_count": (player_df["visited_count"], player_df["collision_count"]),
		"visited_count ghosts_captured": (player_df["visited_count"], player_df["ghosts_captured"]),
		"visited_count pills_captured": (player_df["visited_count"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'


	##
	text_analysis += '\n' + "As metricas de movimentacao" + '\n'
	desired_correlations = {
		"visited_count grid_cell_changes": (player_df["visited_count"], player_df["grid_cell_changes"]),
		"visited_count collision_count": (player_df["visited_count"], player_df["collision_count"]),
		"grid_cell_changes collision_count": (player_df["grid_cell_changes"], player_df["collision_count"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	##
	text_analysis += '\n' + "As metricas de captura" + '\n'
	desired_correlations = {
		"ghosts_captured pills_captured": (player_df["ghosts_captured"], player_df["pills_captured"]),
	}
	for label, series in desired_correlations.items():
		text_analysis += pp_correlations(series[0], series[1], label) + '\n'

	if show:
		print(text_analysis)

	with open(f"{run_dict['path']}{run_dict['run_id']}_analysis.txt", 'w') as f:
		f.write(text_analysis)

	return errors

def calculate_correlations(s1, s2):
	pearson = s1.corr(s2, method = "pearson")
	spearman = s1.corr(s2, method = "spearman")
	kendall = s1.corr(s2, method = "kendall")
	return (pearson, spearman, kendall)

def pp_correlations(s1, s2, label):
	correlations = calculate_correlations(s1, s2)
	result = label + " r: " + str(correlations[0]) + " rs: "  + str(correlations[1]) + " T: " + str(correlations[2])
	# print(result)
	return result


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
