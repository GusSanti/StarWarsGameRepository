--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Vars
local Player = Players.LocalPlayer
local Gui = Player.PlayerGui
local GameGui = Gui:WaitForChild("GameGui")
local CoreGameGui = Gui:WaitForChild("CoreGameUI")
local NewUI = Gui:WaitForChild("NewUI", 5)

--// Frames
local Dialogue = CoreGameGui:WaitForChild("TutorialDialouge"):WaitForChild("Dialogue")

local Contents = Dialogue:WaitForChild("Contents")
local ContinueButton = Contents:WaitForChild("Options"):WaitForChild("Continue")

local tutorialEvents = {}
local tutorialSelectedTower = nil

if Player:GetAttribute("TutorialCompleted") then return end

local function getGuiButtonFromItem(item)
	if not item then return nil end
	if item:IsA("GuiButton") then return item end

	local btn = item:FindFirstChild("Btn", true)
		or item:FindFirstChild("Button", true)

	if btn and btn:IsA("GuiButton") then
		return btn
	end

	return item:FindFirstChildWhichIsA("GuiButton", true)
end

local function findButtonInSideMenu(name)
	NewUI = NewUI or Gui:FindFirstChild("NewUI")
	local sideMenu = NewUI and (NewUI:FindFirstChild("SideMenu") or NewUI:FindFirstChild("sideMenu") or NewUI:FindFirstChild("HUDButtons"))
	if not sideMenu then return nil end

	local normalizedName = string.lower(name):gsub("[%s_%-]+", "")

	for _, item in sideMenu:GetDescendants() do
		if string.lower(item.Name):gsub("[%s_%-]+", "") == normalizedName then
			local button = getGuiButtonFromItem(item)
			if button then
				return button
			end
		end
	end

	return nil
end

local function findLegacyHudButton(name)
	local hud = CoreGameGui:FindFirstChild("HUD")
	local leftPanel = hud and hud:FindFirstChild("LeftPanel")
	if not leftPanel then return nil end

	local lowerName = string.lower(name)

	for _, item in leftPanel:GetChildren() do
		if string.lower(item.Name) == lowerName then
			return getGuiButtonFromItem(item)
		end
	end

	return nil
end

local function waitForMenuButton(name)
	local button = findButtonInSideMenu(name) or findLegacyHudButton(name)

	while not button do
		task.wait(0.1)
		button = findButtonInSideMenu(name) or findLegacyHudButton(name)
	end

	button.Activated:Wait()
end

local function findUnitsFrame()
	NewUI = NewUI or Gui:FindFirstChild("NewUI")

	if NewUI and NewUI:FindFirstChild("Units") then
		return NewUI.Units
	end

	local unitsGui = Gui:FindFirstChild("UnitsGui")
	local inventory = unitsGui and unitsGui:FindFirstChild("Inventory")

	return inventory and inventory:FindFirstChild("Units")
end

local function findUnitsHandler()
	local playerScripts = Player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local uiHandlerFolder = playerScripts:FindFirstChild("UisHandler")
	local unitsHandler = uiHandlerFolder and uiHandlerFolder:FindFirstChild("UnitsHandler")
	if unitsHandler then
		return unitsHandler
	end

	return playerScripts:FindFirstChild("UnitsHandler", true)
end

local function findSelectedTowerValue()
	local unitsHandler = findUnitsHandler()
	local selectedTowerValue = unitsHandler and unitsHandler:FindFirstChild("SelectedTower")

	if selectedTowerValue and selectedTowerValue:IsA("ObjectValue") then
		return selectedTowerValue
	end

	return nil
end

local function findUnitsContentGrid()
	local unitsFrame = findUnitsFrame()
	if not unitsFrame then
		return nil
	end

	local mainFrame = unitsFrame:FindFirstChild("Main")
	local itemsTab = mainFrame and mainFrame:FindFirstChild("ItemsTab")
	local contentGrid = itemsTab and itemsTab:FindFirstChild("Content")
	if contentGrid then
		return contentGrid
	end

	return unitsFrame:FindFirstChild("Content", true)
end

local function getSelectableUnitEntries()
	local contentGrid = findUnitsContentGrid()
	if not contentGrid then
		return {}
	end

	local entries = {}

	for _, child in ipairs(contentGrid:GetChildren()) do
		local towerValue = child:FindFirstChild("TowerValue")
		if towerValue then
			local button = getGuiButtonFromItem(child)
			if button then
				table.insert(entries, {
					button = button,
					tower = towerValue.Value,
				})
			end
		end
	end

	return entries
end

local function isTowerEquipped(tower)
	if not tower then
		return false
	end

	local equippedSlot = tower:GetAttribute("EquippedSlot")
	return tower:GetAttribute("Equipped") == true
		or (typeof(equippedSlot) == "string" and equippedSlot ~= "")
end

local function waitForUnitSelection()
	local selectionEvent = Instance.new("BindableEvent")
	local selectionConnections = {}
	local selectionCompleted = false

	local function completeSelection(selectedTower)
		if selectionCompleted then
			return
		end

		selectionCompleted = true
		selectionEvent:Fire(selectedTower)
	end

	local function disconnectSelectionConnections()
		for _, connection in ipairs(selectionConnections) do
			connection:Disconnect()
		end

		table.clear(selectionConnections)
	end

	local function connectUnitButtons()
		local entries = getSelectableUnitEntries()
		if #entries == 0 then
			return false
		end

		for _, entry in ipairs(entries) do
			table.insert(selectionConnections, entry.button.Activated:Connect(function()
				if entry.tower and not isTowerEquipped(entry.tower) then
					completeSelection(entry.tower)
				end
			end))
		end

		return true
	end

	while not connectUnitButtons() do
		task.wait(0.1)
	end

	local selectedTower = selectionEvent.Event:Wait()
	disconnectSelectionConnections()
	selectionEvent:Destroy()

	return selectedTower
end

local function waitForTowerToEquip(initialTower)
	local selectedTowerValue = findSelectedTowerValue()

	while not selectedTowerValue do
		task.wait(0.1)
		selectedTowerValue = findSelectedTowerValue()
	end

	local equippedEvent = Instance.new("BindableEvent")
	local selectedTowerChangedConnection
	local towerConnections = {}

	local function disconnectTowerConnections()
		for _, connection in ipairs(towerConnections) do
			connection:Disconnect()
		end

		table.clear(towerConnections)
	end

	local function observeTower(tower, allowImmediateCompletion)
		disconnectTowerConnections()

		if not tower then
			return
		end

		if allowImmediateCompletion and isTowerEquipped(tower) then
			equippedEvent:Fire()
			return
		end

		table.insert(towerConnections, tower:GetAttributeChangedSignal("Equipped"):Connect(function()
			if isTowerEquipped(tower) then
				equippedEvent:Fire()
			end
		end))

		table.insert(towerConnections, tower:GetAttributeChangedSignal("EquippedSlot"):Connect(function()
			if isTowerEquipped(tower) then
				equippedEvent:Fire()
			end
		end))
	end

	observeTower(initialTower or selectedTowerValue.Value, true)

	selectedTowerChangedConnection = selectedTowerValue:GetPropertyChangedSignal("Value"):Connect(function()
		if selectedTowerValue.Value then
			observeTower(selectedTowerValue.Value, false)
		end
	end)

	equippedEvent.Event:Wait()

	selectedTowerChangedConnection:Disconnect()
	disconnectTowerConnections()
	equippedEvent:Destroy()
end

local function waitForUnitsVisibilityChanged()
	local unitsFrame = findUnitsFrame()

	while not unitsFrame do
		task.wait(0.1)
		unitsFrame = findUnitsFrame()
	end

	unitsFrame:GetPropertyChangedSignal('Visible'):Wait()
end

local function findSummonFrame()
	NewUI = NewUI or Gui:FindFirstChild("NewUI")

	if NewUI and NewUI:FindFirstChild("Summons") then
		return NewUI.Summons
	end

	local summonFolder = CoreGameGui:FindFirstChild("Summon")
	return summonFolder and summonFolder:FindFirstChild("SummonFrame")
end

local function findRewardPopupFrame()
	NewUI = NewUI or Gui:FindFirstChild("NewUI")

	local newRewardPopup = NewUI and NewUI:FindFirstChild("RewardPopUp")
	if newRewardPopup and newRewardPopup:IsA("GuiObject") then
		return newRewardPopup
	end

	local notifier = CoreGameGui:FindFirstChild("Notifier")
	local legacyRewardPopup = notifier and notifier:FindFirstChild("Obtained")
	if legacyRewardPopup and legacyRewardPopup:IsA("GuiObject") then
		return legacyRewardPopup
	end

	return nil
end

local function isRewardPopupVisible()
	local rewardPopup = findRewardPopupFrame()
	return rewardPopup and rewardPopup.Visible == true
end

local function waitForSummonRewardPopupToClose()
	local summonFrame = findSummonFrame()
	local observedSummonFlow = false
	local observedRewardPopup = isRewardPopupVisible()
	local deadline = os.clock() + 20

	while os.clock() < deadline do
		summonFrame = findSummonFrame() or summonFrame

		if isRewardPopupVisible() then
			observedRewardPopup = true
		end

		if summonFrame and summonFrame.Visible == false then
			observedSummonFlow = true
		end

		if observedRewardPopup and not isRewardPopupVisible() then
			task.wait(0.1)
			return
		end

		if observedSummonFlow and summonFrame and summonFrame.Visible and not isRewardPopupVisible() then
			task.wait(0.1)
			return
		end

		task.wait(0.1)
	end
end

local function getSummonActionButtons()
	local newSummons = findSummonFrame()
	local buttons = {}

	if newSummons and newSummons.Name == "Summons" then
		local bannerButtons = newSummons:FindFirstChild("Body")
			and newSummons.Body:FindFirstChild("Main")
			and newSummons.Body.Main:FindFirstChild("Banner")
			and newSummons.Body.Main.Banner:FindFirstChild("Buttons")

		if bannerButtons then
			for index = 1, 4 do
				local button = getGuiButtonFromItem(bannerButtons:FindFirstChild(tostring(index)))
				if button then
					table.insert(buttons, button)
				end
			end
		end
	end

	if #buttons > 0 then
		return buttons
	end

	local legacyBottomBar = CoreGameGui.Summon.SummonFrame.Banner.Bottom_Bar.Bottom_Bar
	for _, button in legacyBottomBar:GetChildren() do
		if button:IsA("GuiButton") then
			table.insert(buttons, button)
		end
	end

	return buttons
end

local function waitForSummonAction()
	local clickedOnSummon = false
	local buttons = getSummonActionButtons()

	while #buttons == 0 do
		task.wait(0.1)
		buttons = getSummonActionButtons()
	end

	for _, button in ipairs(buttons) do
		button.Activated:Once(function()
			clickedOnSummon = true
		end)
	end

	repeat task.wait(0.1) until clickedOnSummon
end

tutorialEvents["Continue"] = function(callback)
	ContinueButton.Visible = true
	ContinueButton.Activated:Wait()
	ContinueButton.Visible = false
	callback()
end

tutorialEvents["SummonButton"] = function(callback)
	waitForMenuButton("summon")

	callback()
end

tutorialEvents["SummonUnit"] = function(callback)
	print('Waiting for them to summon a unit')
	waitForSummonAction()

	callback()
end

tutorialEvents["EquipUnit"] = function(callback)
	print('Waiting for them to equip a unit')

	waitForUnitsVisibilityChanged()

	callback()
end

tutorialEvents["SelectUnit"] = function(callback)
	tutorialSelectedTower = waitForUnitSelection()

	callback()
end

tutorialEvents["CloseMenu"] = function(callback)
	print('Waiting for them to close menu')

	waitForUnitsVisibilityChanged()

	callback()
end


tutorialEvents['WaitForEquipUnit'] = function(callback)
	waitForTowerToEquip(tutorialSelectedTower)
	tutorialSelectedTower = nil

	callback()
end

tutorialEvents['ExitSummonArea'] = function(callback)
	waitForSummonRewardPopupToClose()

	callback()
end

tutorialEvents["PlayButton"] = function(callback)
	waitForMenuButton("play")
	callback()
end

tutorialEvents["Elevator"] = function(callback)
	ReplicatedStorage.Events:WaitForChild("Elevator").OnClientEvent:Wait()
	callback()
end

tutorialEvents["FinalPlay"] = function(callback)
	script.Parent.Parent.Parent.Parent.CoreGameUI.Story.StoryFrame.Frame.Bottom_Bar.Bottom_Bar.Play.Activated:Wait()
	callback()
end

tutorialEvents["Finished"] = function(callback)
	ReplicatedStorage.Events.Client.Tutorial:FireServer("begin_arena")
	task.wait(6)
	callback()
end

tutorialEvents["Summon2"] = function(callback)
	waitForMenuButton("summon")
	callback()
end

tutorialEvents["SummonUnit2"] = function(callback)
	waitForSummonAction()
	waitForSummonRewardPopupToClose()

	callback()
end

tutorialEvents["Finished2"] = function(callback)
	ReplicatedStorage.Events.Client.Tutorial:FireServer("complete")
	task.wait(6)
	callback()
end

return tutorialEvents
