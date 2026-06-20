local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CheckIfExists = ReplicatedStorage.Functions.BuyNowWP

CheckIfExists.OnServerInvoke = function(player, value)
	local itemValue = player:FindFirstChild(value)
	if itemValue and itemValue.Value >= 1 then
		return true
	else
		return false
	end
end
