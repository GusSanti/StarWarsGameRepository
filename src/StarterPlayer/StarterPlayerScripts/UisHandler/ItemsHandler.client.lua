-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- CONSTANTS
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ViewModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewModule"))
local itemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local UIHandler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local ViewPortModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewPortModule"))

local ItemsUI = PlayerGui:WaitForChild("NewUI"):WaitForChild("ItemsFrame")
local MainFrame = ItemsUI:WaitForChild("Main")
local ItemsTab = MainFrame:WaitForChild("ItemsTab")

local ContentGrid = ItemsTab:WaitForChild("Content")
local TemplatesFolder = ContentGrid:WaitForChild("Template")
local TopLeftArea = MainFrame:WaitForChild("TopLeft")
local titleText = MainFrame:WaitForChild("Title")
local searchBox = TopLeftArea:WaitForChild("Search"):WaitForChild("TextBox")
local playerItemsFolder = LocalPlayer:WaitForChild("Items")

local itemsSelectionFrame = MainFrame:WaitForChild("ItemsSelection")
itemsSelectionFrame.Visible = false

-- VARIABLES
local DEBUG_ITEMS = false
local selectedButton = nil
local totalQuantity = 0
local blockOpen = true
local trackedItems = {}
local pendingXpFeedItemName = nil

-- FUNCTIONS
local function debugItems(...)
	if not DEBUG_ITEMS then
		return
	end

	warn("[ItemsDebug]", ...)
end

local function refreshTitle()
	totalQuantity = 0

	for _, item in pairs(playerItemsFolder:GetChildren()) do
		local value = tonumber(item.Value)
		if value and value > 0 then
			totalQuantity += value
		end
	end

	titleText.Text = "Items: " .. tostring(totalQuantity) .. "/∞"
end

local function clearXpFeedSelection()
	_G.levelupTowerSelection = false
	_G.levelupTowerSelectTower = nil
	_G.levelupTowerCancelSelection = nil
	pendingXpFeedItemName = nil
end

local function getTemplateForRarity(rarity)
	local exactTemplate = TemplatesFolder:FindFirstChild(rarity)
	if exactTemplate and exactTemplate:IsA("GuiObject") then
		return exactTemplate, false
	end

	local fallbackPriority = { "Epic", "Legendary", "Common", "Mythical", "Secret" }
	for _, fallbackName in ipairs(fallbackPriority) do
		local fallbackTemplate = TemplatesFolder:FindFirstChild(fallbackName)
		if fallbackTemplate and fallbackTemplate:IsA("GuiObject") then
			return fallbackTemplate, true
		end
	end

	for _, child in ipairs(TemplatesFolder:GetChildren()) do
		if child:IsA("GuiObject") then
			return child, true
		end
	end

	return nil, false
end

local function getRenderedQuantity()
	local renderedTotal = 0

	for _, child in ipairs(ContentGrid:GetChildren()) do
		if not child:IsA("GuiObject") then
			continue
		end

		local itemValue = child:FindFirstChild("ItemValue")
		local item = itemValue and itemValue.Value
		local value = item and tonumber(item.Value)
		if value and value > 0 then
			renderedTotal += value
		end
	end

	return renderedTotal
end

local function debugInventorySnapshot(reason)
	if not DEBUG_ITEMS then
		return
	end

	local visibleRows = {}
	for _, item in ipairs(playerItemsFolder:GetChildren()) do
		local value = tonumber(item.Value) or 0
		if value > 0 then
			local itemStats = itemStatsModule[item.Name]
			local rarity = itemStats and itemStats.Rarity or "NO_ITEM_STATS"
			local template = getTemplateForRarity(rarity)
			table.insert(visibleRows, string.format("%s x%d | rarity=%s | template=%s", item.Name, value, tostring(rarity), template and template.Name or "NONE"))
		end
	end

	table.sort(visibleRows)
	debugItems(reason, "countedTotal=" .. tostring(totalQuantity), "renderedTotal=" .. tostring(getRenderedQuantity()), "distinctItems=" .. tostring(#visibleRows))
	for _, row in ipairs(visibleRows) do
		debugItems(row)
	end
end

local function preloadVisualAssets()
	local assetsToLoad = {}

	for _, child in pairs(TemplatesFolder:GetDescendants()) do
		if child:IsA("ImageLabel") or child:IsA("ImageButton") then
			if child.Image ~= "" then
				table.insert(assetsToLoad, child.Image)
			end
		end
	end

	if #assetsToLoad > 0 then
		ContentProvider:PreloadAsync(assetsToLoad)
	end
end

local function filterItems(searchText)
	local lowerSearch = string.lower(searchText or "")

	for _, child in pairs(ContentGrid:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Template" then
			if lowerSearch == "" or string.find(string.lower(child.Name), lowerSearch) then
				child.Visible = true
			else
				child.Visible = false
			end
		end
	end
end

local SelectionLibrary
SelectionLibrary = {
	["Update"] = function(visible, item)
		if not visible then
			itemsSelectionFrame.Visible = false
			return
		end

		local itemStats = itemStatsModule[item.Name]
		if itemStats then
			local useButtonVisibleForType = { "XP_feed", "Boost" }

			itemsSelectionFrame.SelectionScrollingButtons.UseButton.Visible = table.find(useButtonVisibleForType, itemStats.Itemtype) ~= nil
			itemsSelectionFrame.ItemRarity.Text = itemStats.Rarity
			itemsSelectionFrame.ItemDescription.Text = itemStats.Description
		end

		itemsSelectionFrame.ItemName.Text = item.Name
		itemsSelectionFrame.Visible = true
	end,

	["View"] = function()
		if not selectedButton then
			return
		end

		itemsSelectionFrame.Visible = false

		local itemName = selectedButton.ItemValue.Value.Name
		local itemStats = itemStatsModule[itemName]
		if not itemStats then
			return
		end

		ViewModule.Item({
			itemStats,
			selectedButton.ItemValue.Value,
			LocalPlayer.Items[itemName].Value,
		})

		UIHandler.PlaySound("Redeem")
		selectedButton = nil
	end,

	["Use"] = function()
		if not selectedButton then
			return
		end

		local itemName = selectedButton.ItemValue.Value.Name
		local itemStats = itemStatsModule[itemName]
		if not itemStats then
			return
		end

		if itemStats.Itemtype == "XP_feed" then
			local itemValue = playerItemsFolder:FindFirstChild(itemName)
			if not itemValue or itemValue.Value <= 0 then
				if _G.Message then
					_G.Message("You do not have any of this item left.", Color3.fromRGB(255, 0, 0), nil, "Error")
				end
				return
			end

			pendingXpFeedItemName = itemName
			_G.levelupTowerSelection = true
			_G.levelupTowerSelectTower = function(_, tower)
				local currentItemValue = pendingXpFeedItemName and playerItemsFolder:FindFirstChild(pendingXpFeedItemName)
				if not pendingXpFeedItemName or not tower or tower.Parent ~= LocalPlayer:FindFirstChild("OwnedTowers") then
					clearXpFeedSelection()
					return
				end

				if not currentItemValue or currentItemValue.Value <= 0 then
					if _G.Message then
						_G.Message("You do not have any of this item left.", Color3.fromRGB(255, 0, 0), nil, "Error")
					end
					clearXpFeedSelection()
					return
				end

				local usedItemName = pendingXpFeedItemName
				clearXpFeedSelection()
				SelectionLibrary.Update(false)
				selectedButton = nil
				ReplicatedStorage.Events.UpdateTowerLevelEvent:FireServer(tower, { [usedItemName] = 1 })
				if _G.CloseAll then
					_G.CloseAll("ItemsFrame")
				end
			end
			_G.levelupTowerCancelSelection = function()
				clearXpFeedSelection()
				if _G.CloseAll then
					_G.CloseAll("ItemsFrame")
				end
			end

			SelectionLibrary.Update(false)
			selectedButton = nil
			if _G.Message then
				_G.Message("Select a unit to feed.", Color3.fromRGB(255, 170, 0))
			end
			if _G.CloseAll then
				_G.CloseAll("Units")
			end
			debugItems("xp-feed-selection-opened", itemName, "xp=" .. tostring(itemStats.XP_amount))
			return
		end

		if itemStats.Itemtype ~= "Boost" then
			if _G.Message then
				_G.Message("This item type is not wired to a use flow yet.", Color3.fromRGB(255, 170, 0), nil, "Warning")
			end
			debugItems("unsupported-item-use", itemName, "itemType=" .. tostring(itemStats.Itemtype))
			return
		end

		SelectionLibrary.Update(false)
		selectedButton = nil
		ReplicatedStorage.Events.UseItem:FireServer(itemName)
	end,
}

local function destroyItemViewport(itemUI, itemName)
	local profile = itemUI and itemUI:FindFirstChild("Profile")
	if not profile then
		return
	end

	local viewport = profile:FindFirstChild(itemName)
	if viewport then
		ViewPortModule.DestroyViewport(viewport)
	end
end

local function bindItemButton(button, item)
	local function buttonClick()
		if selectedButton and selectedButton == button then
			SelectionLibrary.Update(false)
			selectedButton = nil
			return
		end

		selectedButton = button
		SelectionLibrary.Update(true, item)
	end

	if button:IsA("GuiButton") then
		button.MouseButton1Down:Connect(buttonClick)
	else
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				buttonClick()
			end
		end)
	end
end

local function newItem(item)
	refreshTitle()

	if item.Value <= 0 then
		return
	end

	if ContentGrid:FindFirstChild(item.Name) then
		return
	end

	local itemStats = itemStatsModule[item.Name]
	local rarity = itemStats and itemStats.Rarity or "Rare"

	local templateToClone, usedFallbackTemplate = getTemplateForRarity(rarity)
	if not templateToClone then
		debugItems("missing-template", item.Name, "value=" .. tostring(item.Value), "rarity=" .. tostring(rarity))
		return
	end
	if usedFallbackTemplate then
		debugItems("fallback-template", item.Name, "value=" .. tostring(item.Value), "rarity=" .. tostring(rarity), "using=" .. templateToClone.Name)
	end
	if not itemStats then
		debugItems("missing-itemstats", item.Name, "value=" .. tostring(item.Value))
	end

	local button = templateToClone:Clone()
	button.Name = item.Name
	button.Visible = true

	local profile = button:WaitForChild("Profile")
	local textContainer = profile:WaitForChild("Text")
	textContainer:WaitForChild("NamePerson").Text = item.Name
	textContainer:WaitForChild("Amount").Text = "x" .. tostring(item.Value)

	local viewport = ViewPortModule.CreateViewPort(item.Name, false, false, false)
	if viewport then
		local defaultViewport = profile:FindFirstChild("ViewportFrame")
		if defaultViewport then
			defaultViewport:Destroy()
		end

		viewport.Parent = profile
		viewport.Size = UDim2.new(1, 0, 1, 0)
		viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.Name = item.Name
	end

	local itemValueObj = Instance.new("ObjectValue")
	itemValueObj.Name = "ItemValue"
	itemValueObj.Value = item
	itemValueObj.Parent = button

	button.Parent = ContentGrid
	bindItemButton(button, item)
	filterItems(searchBox.Text)
end

local function updateItem(item)
	local itemUI = ContentGrid:FindFirstChild(item.Name)

	if item.Value <= 0 then
		if itemUI then
			destroyItemViewport(itemUI, item.Name)
			itemUI:Destroy()
		end
		refreshTitle()
		return
	end

	if not itemUI then
		newItem(item)
		refreshTitle()
		debugInventorySnapshot("updateItem-created-" .. item.Name)
		return
	end

	local amountLabel = itemUI.Profile.Text.Amount
	amountLabel.Text = "x" .. tostring(item.Value)

	refreshTitle()
	filterItems(searchBox.Text)
	debugInventorySnapshot("updateItem-updated-" .. item.Name)
end

local function bindItemSignals(item)
	if trackedItems[item] then
		return
	end

	trackedItems[item] = true
	item.Changed:Connect(function()
		updateItem(item)
	end)
end

-- INIT
ItemsUI.Visible = false

ItemsUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if blockOpen then
		if _G.CloseAll then
			_G.CloseAll()
		else
			ItemsUI.Visible = false
		end
		return
	end
end)

itemsSelectionFrame.SelectionScrollingButtons.ViewButton.Activated:Connect(SelectionLibrary.View)
itemsSelectionFrame.SelectionScrollingButtons.UseButton.Activated:Connect(SelectionLibrary.Use)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	filterItems(searchBox.Text)
end)

playerItemsFolder.ChildAdded:Connect(function(item)
	bindItemSignals(item)
	newItem(item)
end)

playerItemsFolder.ChildRemoved:Connect(function(item)
	trackedItems[item] = nil

	local itemUI = ContentGrid:FindFirstChild(item.Name)
	if itemUI then
		destroyItemViewport(itemUI, item.Name)
		itemUI:Destroy()
	end

	refreshTitle()
	filterItems(searchBox.Text)
	debugInventorySnapshot("item-removed-" .. item.Name)
end)

task.spawn(function()
	preloadVisualAssets()

	for _, item in playerItemsFolder:GetChildren() do
		bindItemSignals(item)
		newItem(item)
	end

	refreshTitle()
	filterItems(searchBox.Text)
	debugInventorySnapshot("initial-build")
	blockOpen = false
end)
