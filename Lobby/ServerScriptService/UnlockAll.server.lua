local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ALLOWED_USER_IDS = {
	[2012478972] = true,
}

local UpgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))

local function waitForDataLoaded(player: Player)
	while player.Parent and not player:FindFirstChild("DataLoaded") do
		task.wait(0.1)
	end

	return player.Parent ~= nil
end

local function waitForCreateTower(player: Player)
	while player.Parent and type(_G.createTower) ~= "function" do
		task.wait(0.1)
	end

	return player.Parent ~= nil
end

local function unlockAllUnits(player: Player)
	if not ALLOWED_USER_IDS[player.UserId] then
		return
	end

	if not waitForDataLoaded(player) then
		return
	end

	if not waitForCreateTower(player) then
		return
	end

	local ownedTowers = player:FindFirstChild("OwnedTowers")
	if not ownedTowers then
		return
	end

	local unlockedCount = 0

	for unitName, unitData in UpgradesModule do
		if type(unitData) == "table" and unitData.Upgrades and not ownedTowers:FindFirstChild(unitName) then
			local success = pcall(_G.createTower, ownedTowers, unitName)
			if success then
				unlockedCount += 1
			end
		end
	end

	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	local updateInventory = eventsFolder and eventsFolder:FindFirstChild("UpdateInventory")
	if updateInventory and updateInventory:IsA("RemoteEvent") then
		updateInventory:FireClient(player)
	end

	print(string.format("[UnlockAllUnitsById] %s (%d) recebeu %d units.", player.Name, player.UserId, unlockedCount))
end

for _, player in Players:GetPlayers() do
	task.spawn(unlockAllUnits, player)
end

Players.PlayerAdded:Connect(unlockAllUnits)
