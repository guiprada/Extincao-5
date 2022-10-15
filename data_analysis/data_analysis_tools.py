import numpy as np
import matplotlib.pyplot as plt

def test(str):
	print(str)

def create_and_save_destruction_heatmap(df, actor_type, path, run):
	df_destruction = df[df["event_type"] == "destroyed"]
	df_actor_destruction = df_destruction[df_destruction["actor_type"] == actor_type]
	# heatmap_points = list(zip(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"]))

	heatmap_hist, xedges, yedges = np.histogram2d(df_actor_destruction["cell_x"], df_actor_destruction["cell_y"], bins = (28, 14))
	extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
	#print(xedges[0] - 1, xedges[-1] + 1, yedges[0] - 1, yedges[-1] + 1)

	# %matplotlib inline
	plt.clf()
	plt.figure(figsize=(16,12))
	plt.imshow(heatmap_hist.T, extent = extent)
	plt.colorbar()
	plt.savefig(f"{path}{run}_heatmap_{actor_type}.png", dpi = 100)
	plt.show()
	plt.close()
