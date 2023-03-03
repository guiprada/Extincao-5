print("starting")

love = {
	graphics = {
		getWidth = function () return 800 end,
		getHeight = function () return 600 end
	}
}

local extinction = require "gamestates.extinction"
extinction.load()
while true do

end