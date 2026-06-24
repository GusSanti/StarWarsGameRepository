local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopZone = ReplicatedStorage.Events.Challenges.ChallengeShopLoading
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = workspace:WaitForChild("Challenge"):WaitForChild("ChallengeShopZone")
local zone = Zone.new(container)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local module = {}

zone.playerEntered:Connect(function(plr)
	if plr == Player then
		ShopZone:Fire(true)
	end
end)

zone.playerExited:Connect(function(plr)
	if plr == Player then
		ShopZone:Fire(false)
	end
end)

return module
