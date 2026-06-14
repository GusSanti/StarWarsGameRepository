local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Towers = require(ReplicatedStorage.Modules.Towers)

local player = Players.LocalPlayer
repeat task.wait() until player:FindFirstChild('DataLoaded')
local storeAllPlayersTowerEquips = {}
local MAX_FOLLOW_SLOTS = 6

local function GetUnlockedSlotCount(player)
	local playerLevel = player:FindFirstChild("PlayerLevel")
	local level = playerLevel and playerLevel.Value or 0

	if level >= 30 then
		return 6
	elseif level >= 20 then
		return 5
	elseif level >= 10 then
		return 4
	end

	return 3
end

function TrackPlayerTowers(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild('DataLoaded')
	if not player.Parent then return end

	local currentEquips = {}

	local function GetDisplayPriorityEquips()
		local allEquipUnit = {}
		local maxSlots = math.min(GetUnlockedSlotCount(player), MAX_FOLLOW_SLOTS)

		for _, tower in player.OwnedTowers:GetChildren() do
			if tower:GetAttribute("Equipped") then
				table.insert(allEquipUnit, tower)
			end
		end

		table.sort(allEquipUnit, function(a, b)
			local aSlot = tonumber(a:GetAttribute("EquippedSlot")) or (MAX_FOLLOW_SLOTS + 1)
			local bSlot = tonumber(b:GetAttribute("EquippedSlot")) or (MAX_FOLLOW_SLOTS + 1)

			return aSlot < bSlot
		end)

		local equipList = {}
		for index, tower in allEquipUnit do
			if index > maxSlots then break end
			table.insert(equipList, tower)
		end

		return equipList
	end

	local function UpdateDisplay()
		local newPriorityEquips = GetDisplayPriorityEquips()
		local newEquips = {}
		local totalSlots = math.max(#newPriorityEquips, 1)

		for index, tower in newPriorityEquips do
			local oldInfo = nil
			for _, info in currentEquips do
				if info.TowerValue == tower then
					oldInfo = info
				end
			end

			if oldInfo then
				oldInfo.Module:UpdateSlot(index, totalSlots)
				table.insert(newEquips, oldInfo)
			else
				local towerModule = Towers.new(tower, player, index, tower:GetAttribute("Trait"), tower:GetAttribute("Shiny"), totalSlots)
				if towerModule then
					table.insert(newEquips, {
						TowerValue = tower,
						Module = towerModule
					})
				end
			end
		end

		for _, info in currentEquips do
			if not table.find(newEquips, info) then
				info.Module:Destroy()
			end
		end

		currentEquips = newEquips

		storeAllPlayersTowerEquips[player] = currentEquips
	end

	local function TrackEquipped(towerValue)
		UpdateDisplay()
		towerValue:GetAttributeChangedSignal("Equipped"):Connect(function()
			UpdateDisplay()
		end)

		towerValue:GetAttributeChangedSignal("EquippedSlot"):Connect(function()
			UpdateDisplay()
		end)

		towerValue:GetPropertyChangedSignal("Parent"):Connect(function()	--assumes the parent is nil
			pcall(UpdateDisplay)	--to stop error if player leaving
		end)
	end

	local playerLevel = player:FindFirstChild("PlayerLevel")
	if playerLevel then
		playerLevel.Changed:Connect(UpdateDisplay)
	end



	player.OwnedTowers.ChildAdded:Connect(TrackEquipped)
	for _,tower in player.OwnedTowers:GetChildren() do
		TrackEquipped(tower)
	end

end

function RemovePlayerTowers(player)
	if not storeAllPlayersTowerEquips[player] then return end
	for _,data in storeAllPlayersTowerEquips[player] do
		pcall(function()
			data.Module:Destroy()
		end)
	end
	storeAllPlayersTowerEquips[player] = nil
end
game.Players.PlayerRemoving:Connect(RemovePlayerTowers)
game.Players.PlayerAdded:Connect(TrackPlayerTowers)

for _,player in game.Players:GetPlayers() do
	pcall(function()
		task.spawn(function()
			TrackPlayerTowers(player)
		end)
	end)
end


