local module = {}

local releaseHandler = nil

function module.setReleaseHandler(handler)
	releaseHandler = handler
end

function module.releasePlayersForTeleport(players, onReady)
	if typeof(releaseHandler) ~= "function" then
		if typeof(onReady) == "function" then
			onReady()
		end
		return
	end

	releaseHandler(players, onReady)
end

return module
