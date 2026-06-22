local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitModule = require(ReplicatedStorage.Upgrades)
local TraitModule = require(ReplicatedStorage.Modules.Traits)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)

local AdminCommands = {}

local function getPlayerByName(playerName)
	for _, player in Players:GetPlayers() do
		if player.Name == playerName then
			return player
		end
	end
	warn("Player not found: " .. playerName)
	return nil
end

local function warnMissingValue(playerName, valueName)
	warn(playerName .. " does not have a " .. valueName .. " value.")
end

function AdminCommands.giveCoins(playerName, amount)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local coins = targetPlayer:FindFirstChild("Coins")
		if coins then
			coins.Value = coins.Value + amount
			print(playerName .. " has been given " .. amount .. " coins.")
		else
			warnMissingValue(playerName, "Coins")
		end
	end
end

function AdminCommands.giveGems(playerName, amount)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local gems = targetPlayer:FindFirstChild("Gems")
		if gems then
			gems.Value = gems.Value + amount
			print(playerName .. " has been given " .. amount .. " gems.")
		else
			warnMissingValue(playerName, "Gems")
		end
	end
end

function AdminCommands.giveUnit(playerName, unitName, trait)
	local targetPlayer = getPlayerByName(playerName)
	if targetPlayer then
		local towerStorage = targetPlayer:FindFirstChild("OwnedTowers")
		if towerStorage then
			if not UnitModule[unitName] then
				warn("Unit not found: " .. unitName)
				return
			end
			if not TraitModule.Traits[trait] then
				warn("Invalid trait: " .. trait)
				return
			end

			-- Create the new tower
			local newTower = Instance.new("StringValue")
			newTower.Name = unitName
			newTower.Value = trait
			newTower.Parent = towerStorage

			print(playerName .. " has been given a new unit: " .. unitName .. " with trait: " .. trait)
		else
			warnMissingValue(playerName, "OwnedTowers folder")
		end
	end
end

function AdminCommands.unlockAllMaps(playerName)
	local targetPlayer = getPlayerByName(playerName)
	if not targetPlayer then
		return
	end

	local worldStats = targetPlayer:FindFirstChild("WorldStats")
	local storyProgress = targetPlayer:FindFirstChild("StoryProgress")

	if not worldStats then
		warnMissingValue(playerName, "WorldStats folder")
		return
	end

	if not storyProgress then
		warnMissingValue(playerName, "StoryProgress folder")
		return
	end

	for _, worldName in ipairs(StoryModeStats.Worlds) do
		local worldFolder = worldStats:FindFirstChild(worldName)
		local actNames = StoryModeStats.LevelName[worldName] or {}

		if worldFolder then
			local levelStats = worldFolder:FindFirstChild("LevelStats")
			if levelStats then
				for actIndex = 1, #actNames do
					local actFolder = levelStats:FindFirstChild("Act" .. tostring(actIndex))
					if actFolder then
						local clears = actFolder:FindFirstChild("Clears")
						if clears then
							clears.Value = math.max(clears.Value, 1)
						end
					end
				end
			end
		end
	end

	local worldValue = storyProgress:FindFirstChild("World")
	local levelValue = storyProgress:FindFirstChild("Level")
	local lastWorldName = StoryModeStats.Worlds[#StoryModeStats.Worlds]
	local lastWorldActCount = lastWorldName and #(StoryModeStats.LevelName[lastWorldName] or {}) or 1

	if worldValue then
		worldValue.Value = #StoryModeStats.Worlds
	end

	if levelValue then
		levelValue.Value = lastWorldActCount
	end

	print(playerName .. " teve todos os mapas/acts desbloqueados.")
end

return AdminCommands
