-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- CONSTANTS
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local CoreGameUI = PlayerGui:WaitForChild("CoreGameUI")
local NewUI = PlayerGui:WaitForChild("NewUI", 5)

-- Refatoração de caminhos absolutos (Substituindo o antigo script.Parent)
local WillpowerBase = CoreGameUI:WaitForChild("Willpower")
local WillpowerFrameBase = WillpowerBase:WaitForChild("WillpowerFrame")
local MainFrame = WillpowerFrameBase:WaitForChild("Frame")
local SelectedTower = WillpowerBase:WaitForChild("SelectedTower")
local GiftFolder = CoreGameUI:WaitForChild("Gift")
local GiftFrame = GiftFolder:WaitForChild("GiftFrame")
local SelectedGiftId = GiftFolder:WaitForChild("SelectedGiftId")

local ChangeUnit = MainFrame:WaitForChild("Contents"):WaitForChild("Unit")
local UnitFrame = ChangeUnit:WaitForChild("Contents")
local TraitReroll = MainFrame:WaitForChild("Bottom_Bar"):WaitForChild("Bottom_Bar"):WaitForChild("Reroll")
local AutoReroll = MainFrame:WaitForChild("Bottom_Bar"):WaitForChild("Bottom_Bar"):WaitForChild("AutoReroll")
local RobuxReroll = MainFrame:WaitForChild("Bottom_Bar"):WaitForChild("Bottom_Bar"):WaitForChild("LuckyWillpower")

local RerollText = MainFrame:WaitForChild("Contents"):WaitForChild("Willpower_Total")
local LuckyText = MainFrame:WaitForChild("Contents"):WaitForChild("LuckyWillpower")
local Luckyicon = MainFrame:WaitForChild("Contents"):WaitForChild("LuckyWillpowerIcon")
local TraitLabel = MainFrame:WaitForChild("Contents"):WaitForChild("Current_Willpower"):WaitForChild("Unit_Willpower")

local NormalReroll = player:WaitForChild("TraitPoint")
local LuckyReroll = player:WaitForChild("LuckyWillpower")

local Inventory = PlayerGui:WaitForChild("UnitsGui"):WaitForChild("Inventory"):WaitForChild("Units")

local Functions = ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = Functions:WaitForChild("GetMarketInfoByName")
local BuyEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")
local CheckIfExists = Functions:WaitForChild("BuyNowWP")
local LuckyWillpowerInfo = GetMarketInfoByName:InvokeServer("LuckyWillpower")

-- Módulos
local UIHandlerModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local UpgradesModule = require(ReplicatedStorage.Upgrades)
local Zone = require(ReplicatedStorage.Modules.Zone)
local Traits = require(ReplicatedStorage.Modules.Traits)
local BalanceConfig = require(ReplicatedStorage.BalanceConfig)

local WILLPOWER_INDEX_ORDER = {
	"Strong I", "Strong II", "Strong III", "Range I", "Range II", "Range III",
	"Nimble I", "Nimble II", "Nimble III", "Experience", "Precision Protocol",
	"Arms Dealer", "Tyrant's Damage", "Lightspeed", "Star Killer", "Padawan",
	"Apprentice", "Lord", "Merchant", "Mandalorian", "Tyrant's Wrath",
	"Cosmic Crusader", "Waders Will",
}

-- VARIABLES
local NewWillPower = NewUI and NewUI:WaitForChild("WillPower", 5)
local isAutoRerolling = false
local restoreNewWillpowerIndexOnReturn = false
local lastWillpowerSelectionOpenAt = 0
local productPriceCache = {}
local cooldowntick = 0
local mythicalpluscooldown = false
local open = false

local traitcolors = Traits.TraitColors
local WillpowerPityConfig = BalanceConfig.Willpower or {
	LegendaryPityRequired = 250,
	MythicalPityRequired = 500,
}
local populateNewWillpowerPanels
local getSelectedWillpowerTraitText
local selectedTowerTraitChangedConnection

local baseColorBottom = Color3.fromRGB(27, 102, 0)
local baseColorTop = Color3.fromRGB(19, 163, 0)
local toggledColorBottom = Color3.fromRGB(102,0,0)
local toggledColorTop = Color3.fromRGB(255,0,0)

-- FUNCTIONS
local function updateWillpowerPityBars()
	local mythicalPity = player:FindFirstChild("MythicalPityWP")
	local legendaryPity = player:FindFirstChild("LegendaryPityWP")
	local pityBars = WillpowerFrameBase.Frame:WaitForChild("Pity_Bars")
	local mythicalFrame = pityBars:FindFirstChild("Mythical_Pity") or pityBars:FindFirstChild("MythicalPity")
	local legendaryFrame = pityBars:FindFirstChild("Legendary_Pity") or pityBars:FindFirstChild("LegendaryPity") or pityBars:FindFirstChild("Legendar yPity")
	if not mythicalFrame or not legendaryFrame then
		return
	end
	local mythicalRequired = WillpowerPityConfig.MythicalPityRequired
	local legendaryRequired = WillpowerPityConfig.LegendaryPityRequired
	local mythicalCurrent = mythicalPity and mythicalPity.Value or 0
	local legendaryCurrent = legendaryPity and legendaryPity.Value or 0

	mythicalFrame.Contents.Bar.Size = UDim2.fromScale(math.clamp(mythicalCurrent / mythicalRequired, 0, 1), 1)
	mythicalFrame.Contents.Pity.Text = mythicalCurrent .. "/" .. mythicalRequired

	legendaryFrame.Contents.Bar.Size = UDim2.fromScale(math.clamp(legendaryCurrent / legendaryRequired, 0, 1), 1)
	legendaryFrame.Contents.Pity.Text = legendaryCurrent .. "/" .. legendaryRequired
end

local function findChildPath(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
		if not current then return nil end
	end
	return current
end

local function findFirstGuiButton(root)
	if not root then return nil end
	if root:IsA("GuiButton") then return root end
	local preferredButton = root:FindFirstChild("Btn", true) or root:FindFirstChild("Button", true)
	if preferredButton and preferredButton:IsA("GuiButton") then return preferredButton end
	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function findTextObject(root, names)
	if not root then return nil end
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found and (found:IsA("TextLabel") or found:IsA("TextButton")) then return found end
	end
	return nil
end

local function findImageObject(root)
	if not root then return nil end
	local preferredImage = root:FindFirstChild("Icon", true) or root:FindFirstChild("Ray", true) or root:FindFirstChild("Image", true)
	if preferredImage and (preferredImage:IsA("ImageLabel") or preferredImage:IsA("ImageButton")) then return preferredImage end
	return root:FindFirstChildWhichIsA("ImageLabel", true) or root:FindFirstChildWhichIsA("ImageButton", true)
end

local function getDebugInstancePath(instance)
	if not instance then return "nil" end
	local success, fullName = pcall(function() return instance:GetFullName() end)
	return success and fullName or instance.Name
end

local function debugWillpower(message)
	-- warn("[WillpowerDebug] " .. message)
end

local function isScreenPointInside(gui, screenPoint)
	if not (gui and gui:IsA("GuiObject") and gui.Visible) then return false end
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	return screenPoint.X >= position.X and screenPoint.Y >= position.Y and screenPoint.X <= position.X + size.X and screenPoint.Y <= position.Y + size.Y
end

local function isGuiActuallyVisible(gui)
	if not (gui and gui:IsA("GuiObject")) then return false end
	local current = gui
	while current do
		if current:IsA("GuiObject") and current.Visible == false then return false end
		if current:IsA("LayerCollector") and current.Enabled == false then return false end
		current = current.Parent
	end
	return true
end

local function formatGuiObjects(guiObjects)
	local names = {}
	for index, guiObject in ipairs(guiObjects) do
		if index > 6 then break end
		table.insert(names, getDebugInstancePath(guiObject))
	end
	return table.concat(names, " | ")
end

local function resolveGuiActionTarget(root, preferRoot)
	if not root then return nil, nil end
	if root:IsA("GuiButton") then return root, "Activated" end
	if preferRoot and root:IsA("GuiObject") then return root, "InputBegan" end
	local preferredButton = root:FindFirstChild("Btn", true) or root:FindFirstChild("Button", true)
	if preferredButton and preferredButton:IsA("GuiButton") then return preferredButton, "Activated" end
	local anyButton = root:FindFirstChildWhichIsA("GuiButton", true)
	if anyButton then return anyButton, "Activated" end
	if root:IsA("GuiObject") then return root, "InputBegan" end
	return nil, nil
end

local function connectGuiAction(root, attributeName, debugName, callback, preferRoot)
	local actionTarget, actionMode = resolveGuiActionTarget(root, preferRoot)
	if not actionTarget then return nil end
	if actionTarget:GetAttribute(attributeName) then return actionTarget end

	actionTarget:SetAttribute(attributeName, true)
	local lastTriggerAt = 0
	local function trigger(source)
		lastTriggerAt = os.clock()
		callback()
	end

	if actionMode == "Activated" then
		actionTarget.Activated:Connect(function() trigger("Activated") end)
	else
		actionTarget.Active = true
		actionTarget.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				trigger("InputBegan")
			end
		end)
	end

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not (actionTarget.Parent and isGuiActuallyVisible(actionTarget) and isGuiActuallyVisible(root)) then return end

		local screenPoint = Vector2.new(input.Position.X, input.Position.Y)
		if not isScreenPointInside(actionTarget, screenPoint) then return end

		local guiObjects = PlayerGui:GetGuiObjectsAtPosition(screenPoint.X, screenPoint.Y)
		local foundInStack = false
		for _, guiObject in ipairs(guiObjects) do
			if guiObject == actionTarget or guiObject:IsDescendantOf(actionTarget) or actionTarget:IsDescendantOf(guiObject) then
				foundInStack = true
				break
			end
		end

		if not foundInStack then return end
		if os.clock() - lastTriggerAt < 0.15 then return end

		trigger("FallbackInputEnded")
	end)

	return actionTarget
end

local function copyViewportProperty(targetViewport, sourceViewport, propertyName)
	local readSuccess, value = pcall(function() return sourceViewport[propertyName] end)
	if not readSuccess then return end
	pcall(function() targetViewport[propertyName] = value end)
end

local function clearViewportTarget(viewport)
	if not viewport then return end
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
end

local function setPlaceholderGraphicsVisible(container, visible)
	if not (container and container:IsA("GuiObject")) then return end
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant ~= container and descendant.Name == "Placeholder" and descendant:IsA("GuiObject") and not descendant:IsA("ViewportFrame") then
			descendant.Visible = visible
		end
	end
end

local function getViewportTarget(container)
	if not container then return nil end
	if container:IsA("ViewportFrame") then return container end
	local directViewport = container:FindFirstChild("ViewportFrame")
	if directViewport and directViewport:IsA("ViewportFrame") then return directViewport end
	return container:FindFirstChildWhichIsA("ViewportFrame", true)
end

local function attachViewport(container, unitName, shiny)
	local targetViewport = getViewportTarget(container)
	if not targetViewport then return end

	clearViewportTarget(targetViewport)
	setPlaceholderGraphicsVisible(container, unitName == nil)

	local placeholderGraphic = container:IsA("GuiObject") and container:FindFirstChild("Placeholder")
	if placeholderGraphic and placeholderGraphic ~= targetViewport and placeholderGraphic:IsA("GuiObject") then
		placeholderGraphic.Visible = unitName == nil
	end

	if not unitName then return end

	local viewport = ViewPortModule.CreateViewPort(unitName, shiny, true)
	if not viewport then return end

	copyViewportProperty(targetViewport, viewport, "BackgroundTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageColor3")
	copyViewportProperty(targetViewport, viewport, "Ambient")
	copyViewportProperty(targetViewport, viewport, "LightColor")
	copyViewportProperty(targetViewport, viewport, "LightDirection")
	copyViewportProperty(targetViewport, viewport, "CurrentCamera")

	local worldModel = viewport:FindFirstChildOfClass("WorldModel")
	if worldModel then worldModel.Parent = targetViewport end

	if ViewPortModule.DestroyViewport then
		ViewPortModule.DestroyViewport(viewport)
	else
		viewport:Destroy()
	end
end

local function getNumberedGuiChildren(container)
	local children = {}
	if not container then return children end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and tonumber(child.Name) then
			table.insert(children, child)
		end
	end
	table.sort(children, function(a, b) return tonumber(a.Name) < tonumber(b.Name) end)
	return children
end

local function ensureNumberedGuiChildren(container, amount)
	local children = getNumberedGuiChildren(container)
	local template = children[#children]
	if not template then return children end

	for index = #children + 1, amount do
		local clone = template:Clone()
		clone.Name = tostring(index)
		clone.LayoutOrder = index
		clone.Visible = true
		clone:SetAttribute("WillpowerIndexClone", true)
		clone.Parent = container
	end

	return getNumberedGuiChildren(container)
end

local function setTextIfExists(target, text)
	if target and (target:IsA("TextLabel") or target:IsA("TextButton")) then
		target.Text = tostring(text or "")
	end
end

local function collectTextObjects(root)
	local objects = {}
	if not root then return objects end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(objects, descendant)
		end
	end
	table.sort(objects, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
		return a:GetFullName() < b:GetFullName()
	end)
	return objects
end

local function copyTextByName(source, target, sourceNames, targetNames)
	local sourceText = findTextObject(source, sourceNames)
	local targetText = findTextObject(target, targetNames)
	if sourceText and targetText then
		targetText.Text = sourceText.Text
		return true
	end
	return false
end

local function copyOrderedTexts(source, target)
	local sourceTexts = collectTextObjects(source)
	local targetTexts = collectTextObjects(target)
	for index, targetText in ipairs(targetTexts) do
		local sourceText = sourceTexts[index]
		if sourceText then targetText.Text = sourceText.Text end
	end
end

local function copyIcon(source, target)
	local sourceImage = findImageObject(source)
	local targetImage = findImageObject(target)
	if sourceImage and targetImage then
		targetImage.Image = sourceImage.Image
		return true
	end
	return false
end

local function findShopPriceLabel(card)
	local button = card and card:FindFirstChild("Button")
	return findTextObject(button, {"Text", "Price"}) or findTextObject(card, {"Price"})
end

local function getProductPriceText(productId)
	if not productId then return nil end
	if productPriceCache[productId] then return productPriceCache[productId] end

	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)

	if not success or not productInfo or not productInfo.PriceInRobux then return nil end
	local priceText = tostring(productInfo.PriceInRobux) .. "R$"
	productPriceCache[productId] = priceText

	return priceText
end

local function generateTraitDescription(traitData)
	local descriptions = {}
	if traitData.Damage and traitData.Damage > 0 then table.insert(descriptions, "Increases damage by " .. traitData.Damage .. "%") end
	if traitData.Range and traitData.Range > 0 then table.insert(descriptions, "Increases range by " .. traitData.Range .. "%") end
	if traitData.Cooldown and traitData.Cooldown > 0 then table.insert(descriptions, "Decreases cooldown by " .. traitData.Cooldown .. "%") end
	if traitData.BossDamage and traitData.BossDamage > 0 then table.insert(descriptions, "Increases boss damage by " .. traitData.BossDamage .. "%") end
	if traitData.Money and traitData.Money > 0 then table.insert(descriptions, "Increases money by " .. traitData.Money .. "%") end
	if traitData.Exp and traitData.Exp > 0 then table.insert(descriptions, "Increases experience by " .. traitData.Exp .. "%") end

	if traitData.TowerBuffs then
		local towerBuffs = {}
		if traitData.TowerBuffs.Damage and traitData.TowerBuffs.Damage ~= 1 then table.insert(towerBuffs, "damage by " .. math.floor((traitData.TowerBuffs.Damage - 1) * 100) .. "%") end
		if traitData.TowerBuffs.Range and traitData.TowerBuffs.Range ~= 1 then table.insert(towerBuffs, "range by " .. math.floor((traitData.TowerBuffs.Range - 1) * 100) .. "%") end
		if traitData.TowerBuffs.Cooldown and traitData.TowerBuffs.Cooldown ~= 1 then table.insert(towerBuffs, "cooldown by " .. math.floor((1 - traitData.TowerBuffs.Cooldown) * 100) .. "%") end
		if #towerBuffs > 0 then table.insert(descriptions, "Global Buffs: increases " .. table.concat(towerBuffs, ", increases ")) end
	end

	if #descriptions == 0 then return "No stat bonuses" end
	return table.concat(descriptions, ", ")
end

local function getNewWillPowerFrame()
	if NewWillPower and NewWillPower.Parent then return NewWillPower end
	NewUI = PlayerGui:FindFirstChild("NewUI")
	NewWillPower = NewUI and NewUI:FindFirstChild("WillPower")
	return NewWillPower
end

local function getWillpowerMenuTarget()
	return getNewWillPowerFrame() and "WillPower" or "WillpowerFrame"
end

local function getCloseAllFunction(timeoutSeconds)
	local closeAll = _G.CloseAll
	local timeoutAt = os.clock() + (timeoutSeconds or 1)
	while typeof(closeAll) ~= "function" and os.clock() < timeoutAt do
		task.wait()
		closeAll = _G.CloseAll
	end
	return typeof(closeAll) == "function" and closeAll or nil
end

local function safeCloseAll(targetName)
	local newFrame = getNewWillPowerFrame()
	local unitsFrame = NewUI and NewUI:FindFirstChild("Units")
	local indexFrame = newFrame and newFrame:FindFirstChild("Index")

	if targetName == "Units" and unitsFrame and unitsFrame:IsA("GuiObject") then
		if newFrame and newFrame:IsA("GuiObject") then newFrame.Visible = false end
		if indexFrame and indexFrame:IsA("GuiObject") then
			restoreNewWillpowerIndexOnReturn = indexFrame.Visible == true
			indexFrame.Visible = false
		else
			restoreNewWillpowerIndexOnReturn = false
		end
		unitsFrame.Visible = true
		return true
	end

	if targetName == getWillpowerMenuTarget() and newFrame and newFrame:IsA("GuiObject") then
		newFrame.Visible = true
		if indexFrame and indexFrame:IsA("GuiObject") then indexFrame.Visible = restoreNewWillpowerIndexOnReturn end
		restoreNewWillpowerIndexOnReturn = false
		local currentUnits = NewUI and NewUI:FindFirstChild("Units")
		if currentUnits and currentUnits:IsA("GuiObject") then currentUnits.Visible = false end
		return true
	end

	if targetName == nil and newFrame and newFrame:IsA("GuiObject") then
		newFrame.Visible = false
		if unitsFrame and unitsFrame:IsA("GuiObject") then unitsFrame.Visible = false end
		if indexFrame and indexFrame:IsA("GuiObject") then indexFrame.Visible = false end
		restoreNewWillpowerIndexOnReturn = false
		return true
	end

	local closeAll = getCloseAllFunction(1)
	if closeAll then
		closeAll(targetName)
		return true
	end

	return false
end

local function getNewWillpowerContents()
	local newFrame = getNewWillPowerFrame()
	return findChildPath(newFrame, {"Body", "Main", "Contents"})
end

local function updateNewWillpowerProfile()
	local contents = getNewWillpowerContents()
	local profile = contents and findChildPath(contents, {"Profile"})
	local willpowerSection = contents and findChildPath(contents, {"Willpower"})
	local selectedTowerData = SelectedTower.Value
	local currentTrait = getSelectedWillpowerTraitText()
	local traitData = selectedTowerData and Traits.Traits[selectedTowerData:GetAttribute("Trait")] or nil
	local descriptionText = "Select a unit to begin!"

	if selectedTowerData then
		descriptionText = traitData and generateTraitDescription(traitData) or "This unit has no Willpower yet."
	end

	if profile then
		local addButtonRoot = profile:FindFirstChild("+")
		local placeholderContainer = findChildPath(profile, {"Placeholder"})
		local shadow = profile:FindFirstChild("Shadow")
		local hasTower = selectedTowerData ~= nil

		if addButtonRoot and addButtonRoot:IsA("GuiObject") then addButtonRoot.Visible = not hasTower end
		if shadow and shadow:IsA("GuiObject") then shadow.Visible = hasTower end

		attachViewport(placeholderContainer, hasTower and selectedTowerData.Name or nil, hasTower and selectedTowerData:GetAttribute("Shiny") or nil)
	end

	setTextIfExists(findTextObject(findChildPath(willpowerSection, {"Current"}) or willpowerSection, {"Text"}), currentTrait)
	setTextIfExists(findTextObject(findChildPath(willpowerSection, {"Description"}) or willpowerSection, {"Text", "Description"}), descriptionText)
end

getSelectedWillpowerTraitText = function()
	local selectedTowerData = SelectedTower.Value
	if not selectedTowerData then return "No Willpower" end

	local trait = selectedTowerData:GetAttribute("Trait")
	if trait and trait ~= "" then return trait end

	return "No Willpower"
end

local function updateNewWillpowerStatusEffects()
	local contents = getNewWillpowerContents()
	local statusEffects = contents and findChildPath(contents, {"Willpower", "Statuseffects"})
	local current = contents and findChildPath(contents, {"Willpower", "Current"})

	setTextIfExists(findChildPath(statusEffects, {"1", "Text"}), NormalReroll.Value .. "/1")
	setTextIfExists(findChildPath(statusEffects, {"2", "Text"}), LuckyReroll.Value .. "/1")
	setTextIfExists(current and current:FindFirstChild("Text"), getSelectedWillpowerTraitText())
end

local function clearWillpowerSelectionMode()
	_G.traitTowerSelection = false
	_G.traitTowerSelectTower = nil
	_G.traitTowerCancelSelection = nil
end

local function openWillpowerUnitSelection()
	_G.traitTowerSelection = true
	_G.traitTowerSelectTower = function(_, tower)
		if not tower then return false end
		SelectedTower.Value = tower
		clearWillpowerSelectionMode()
		safeCloseAll(getWillpowerMenuTarget())
		return true
	end
	_G.traitTowerCancelSelection = clearWillpowerSelectionMode
	safeCloseAll("Units")
end

local function requestWillpowerUnitSelection()
	if os.clock() - lastWillpowerSelectionOpenAt < 0.15 then return end
	lastWillpowerSelectionOpenAt = os.clock()
	openWillpowerUnitSelection()
end

local function wireNewWillpowerAddButton()
	local contents = getNewWillpowerContents()
	local profile = contents and findChildPath(contents, {"Profile"})
	local addButtonRoot = contents and findChildPath(contents, {"Profile", "+"})
	local placeholderContainer = contents and findChildPath(contents, {"Profile", "Placeholder"})
	local shadow = profile and profile:FindFirstChild("Shadow")

	connectGuiAction(profile, "WillpowerProfileRootConnected", "ProfileRoot", requestWillpowerUnitSelection, true)
	connectGuiAction(addButtonRoot, "WillpowerAddConnected", "AddButton", requestWillpowerUnitSelection)
	connectGuiAction(placeholderContainer, "WillpowerProfileConnected", "ProfilePlaceholder", requestWillpowerUnitSelection)
	connectGuiAction(shadow, "WillpowerProfileShadowConnected", "ProfileShadow", requestWillpowerUnitSelection)
end

local function populateNewWillpowerIndex()
	local newFrame = getNewWillPowerFrame()
	local targetContents = findChildPath(newFrame, {"Index", "Contents"})
	if not targetContents then return end

	local oldContents = findChildPath(WillpowerFrameBase, {"Index", "Index", "Contents"})
	local targetCards = ensureNumberedGuiChildren(targetContents, #WILLPOWER_INDEX_ORDER)

	for index, targetCard in ipairs(targetCards) do
		local traitName = WILLPOWER_INDEX_ORDER[index]
		local traitData = traitName and Traits.Traits[traitName]
		local sourceCard = oldContents and traitName and oldContents:FindFirstChild(traitName)

		targetCard.Visible = traitData ~= nil

		if traitData then
			local copiedIcon = sourceCard and copyIcon(sourceCard, targetCard)

			if not (sourceCard and copyTextByName(sourceCard, targetCard, {"Title", "Name"}, {"Title", "Name"})) then
				setTextIfExists(findTextObject(targetCard, {"Title", "Name"}), traitName)
			end

			if not (sourceCard and copyTextByName(sourceCard, targetCard, {"Subtext", "Description", "Text"}, {"Text", "Description"})) then
				setTextIfExists(findTextObject(targetCard, {"Text", "Description"}), traitData and generateTraitDescription(traitData) or "")
			end

			local targetIcon = findImageObject(targetCard)
			if not copiedIcon and targetIcon and traitData and traitData.ImageID then
				targetIcon.Image = traitData.ImageID
			end
		end
	end
end

local function updatePrice(SelectedTowerObj)
	local statsTower = UpgradesModule[SelectedTowerObj.Name]
	local priceMultiplier = 1
	local trait = SelectedTowerObj:GetAttribute("Trait")

	if TraitsModule.Traits[trait] then
		if TraitsModule.Traits[trait]["Money"] then
			priceMultiplier = (1 - (TraitsModule.Traits[trait]["Money"] / 100))
		end
	end

	local priceVal = math.round(statsTower["Upgrades"][1].Price * priceMultiplier)
	MainFrame.Contents.Unit.Contents.UnitPrice.Text = priceVal .. " $"
end

local function Reroll(LuckyRoll)
	local tower = SelectedTower.Value
	if tower then
		if not mythicalpluscooldown then
			mythicalpluscooldown = true
			local trait = nil

			if LuckyRoll then
				trait = ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower, LuckyRoll)
			else
				trait = ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower)
			end

			updateWillpowerPityBars()

			if Traits.Traits[trait] then
				local rarity = Traits.Traits[trait].Rarity
				local color = traitcolors[rarity].Gradient

				if rarity == "Unique" or rarity == "Mythical" then
					_G.Message("You got a " .. rarity .. " trait!", Color3.new(1, 0.666667, 0))
					UIHandlerModule.PlaySound("LuckActive")
					UIHandlerModule.CreateConfetti()
					task.delay(3, function() mythicalpluscooldown = false end)
				else
					task.delay(0.02, function() mythicalpluscooldown = false end)
				end

				TraitLabel.Size = UDim2.new(0, 0, 0, 0)
				TweenService:Create(TraitLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0.67, 0)}):Play()
				TraitLabel.Text = trait
				MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[tower:GetAttribute("Trait")].ImageID
				MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = color
				TraitLabel.UIGradient.Color = color

				return rarity, trait
			else
				mythicalpluscooldown = false
				if type(trait) == "string" and trait ~= "" then
					_G.Message(trait, Color3.new(0.776471, 0.239216, 0.239216))
				end
				UIHandlerModule.PlaySound("Error")
				return nil
			end
		else
			_G.Message("Please wait before rerolling again!", Color3.new(0.776471, 0.239216, 0.239216))
			return nil
		end
	else
		_G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) 
	end
end

local function updateOpenState()
	local newFrame = getNewWillPowerFrame()
	open = WillpowerFrameBase.Visible or (newFrame and newFrame.Visible) or false
end

local function wireNewWillpowerShopCard(card, productName)
	if not (card and productName) then return nil end

	-- Isso é onde o delay acontecia, agora está rodando em paralelo sem travar o jogador!
	task.spawn(function()
		local success, info = pcall(function()
			return GetMarketInfoByName:InvokeServer(productName)
		end)

		if not success or not info then return end

		local buyButton = findChildPath(card, {"Button", "Btn"}) or findFirstGuiButton(card:FindFirstChild("Button"))
		local giftButton = findFirstGuiButton(card:FindFirstChild("Buttom")) or findFirstGuiButton(card:FindFirstChild("Gift"))

		if buyButton and buyButton:GetAttribute("WillpowerProductName") ~= productName then
			buyButton:SetAttribute("WillpowerProductName", productName)
			buyButton.Activated:Connect(function()
				BuyEvent:FireServer(info.Id)
			end)
		end

		if giftButton and info.GiftId and giftButton:GetAttribute("WillpowerGiftName") ~= productName then
			giftButton:SetAttribute("WillpowerGiftName", productName)
			giftButton.Activated:Connect(function()
				SelectedGiftId.Value = info.GiftId
				GiftFrame.Visible = true
			end)
		end
	end)
end

local function getOldWillpowerShopCards()
	local sideShopContents = MainFrame.Parent:FindFirstChild("Side_Shop") and MainFrame.Parent.Side_Shop:FindFirstChild("Contents")
	local cards = {}

	if not sideShopContents then return cards end

	for _, child in ipairs(sideShopContents:GetChildren()) do
		if child:IsA("GuiObject") and child:FindFirstChild("Contents") then
			table.insert(cards, child)
		end
	end

	table.sort(cards, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
		return a.Name < b.Name
	end)

	return cards
end

local function populateNewWillpowerGems()
	local newFrame = getNewWillPowerFrame()
	local targetContents = findChildPath(newFrame, {"Gems", "Contents"})
	if not targetContents then return end

	local sourceCards = getOldWillpowerShopCards()
	local targetCards = getNumberedGuiChildren(targetContents)

	for index, targetCard in ipairs(targetCards) do
		local sourceCard = sourceCards[index]
		targetCard.Visible = sourceCard ~= nil

		if sourceCard then
			copyIcon(sourceCard, targetCard)

			local copiedTitle = copyTextByName(sourceCard, targetCard, {"Title", "Name"}, {"Title", "Name"})
			local copiedText = copyTextByName(sourceCard, targetCard, {"Text", "Price", "Subtext"}, {"Text", "Price"})

			if not copiedTitle and not copiedText then
				copyOrderedTexts(sourceCard, targetCard)
			elseif not copiedTitle then
				setTextIfExists(findTextObject(targetCard, {"Title", "Name"}), sourceCard.Name)
			end

			-- Trazendo o GetProductPriceText para o background para evitar delays na UI
			task.spawn(function()
				wireNewWillpowerShopCard(targetCard, sourceCard.Name)
				local priceText = getProductPriceText(GetMarketInfoByName:InvokeServer(sourceCard.Name).Id)
				if priceText then
					setTextIfExists(findShopPriceLabel(targetCard), priceText)
				end
			end)
		end
	end
end

populateNewWillpowerPanels = function()
	populateNewWillpowerIndex()
	populateNewWillpowerGems()
	wireNewWillpowerAddButton()

	local newFrame = getNewWillPowerFrame()
	local indexFrame = newFrame and newFrame:FindFirstChild("Index")
	local closeButtonRoot = findChildPath(newFrame, {"Body", "Closebtn"})
	local indexButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Index"})
	local rerollButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Reroll"})
	local robuxRerollButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Robux_Reroll"})
	local selectUnitButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Select_Unit"})

	connectGuiAction(closeButtonRoot, "WillpowerCloseConnected", "CloseButton", function() safeCloseAll() end)
	connectGuiAction(indexButtonRoot, "WillpowerIndexConnected", "IndexButton", function()
		local targetIndex = indexFrame and indexFrame:IsA("GuiObject") and indexFrame or MainFrame.Parent:FindFirstChild("Index")
		if not (targetIndex and targetIndex:IsA("GuiObject")) then return end
		UIHandlerModule.PlaySound(targetIndex.Visible and "Close" or "Open")
		targetIndex.Visible = not targetIndex.Visible
		restoreNewWillpowerIndexOnReturn = targetIndex.Visible == true
	end)
	connectGuiAction(rerollButtonRoot, "WillpowerRerollConnected", "RerollButton", function()
		if isAutoRerolling then
			_G.Message("Stop autorolling to roll manually!", Color3.new(255, 0, 0))
			return
		end
		Reroll()
	end)
	connectGuiAction(robuxRerollButtonRoot, "WillpowerLuckyConnected", "RobuxRerollButton", function()
		local Check = CheckIfExists:InvokeServer("LuckyWillpower")
		if not Check then
			if LuckyWillpowerInfo then
				MarketplaceService:PromptProductPurchase(player, LuckyWillpowerInfo.Id)
			end
		else
			Reroll(true)
		end
	end)
	connectGuiAction(selectUnitButtonRoot, "WillpowerSelectUnitConnected", "SelectUnitButton", function()
		requestWillpowerUnitSelection()
	end)

	updateNewWillpowerProfile()
	updateNewWillpowerStatusEffects()
end

local function NewTokenUI(ui)
	-- Também resolvendo o delay do SideShop original
	task.spawn(function()
		local BuyButton = ui.Contents:WaitForChild("Buy")
		local GiftButton = ui.Contents:WaitForChild("Gift")
		local Info = GetMarketInfoByName:InvokeServer(ui.Name) 

		connectGuiAction(BuyButton, "WillpowerLegacyBuyConnected", "LegacyBuyButton", function()
			BuyEvent:FireServer(Info.Id)
		end)

		connectGuiAction(GiftButton, "WillpowerLegacyGiftConnected", "LegacyGiftButton", function()
			SelectedGiftId.Value = Info.GiftId
			GiftFrame.Visible = true
		end)
	end)
end

-- INIT
RerollText.Text = NormalReroll.Value.."/1"
LuckyText.Text = LuckyReroll.Value.."/1"

if NormalReroll.Value >= 1 then
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end

if LuckyReroll.Value >= 1 then
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end

SelectedTower.Changed:Connect(function()
	if selectedTowerTraitChangedConnection then
		selectedTowerTraitChangedConnection:Disconnect()
		selectedTowerTraitChangedConnection = nil
	end

	if not SelectedTower.Value then
		updateNewWillpowerProfile()
		updateNewWillpowerStatusEffects()
		return
	end

	if MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame") then MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame"):Destroy() end

	local trait = SelectedTower.Value:GetAttribute("Trait")
	if trait and trait ~= "" then
		TraitLabel.Text = trait
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[trait].ImageID
		MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
	else
		TraitLabel.Text = "No WillPower"
		TraitLabel.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = ""
	end

	local statsTower = UpgradesModule[SelectedTower.Value.Name]
	local rarity = statsTower["Rarity"] or "Rare"
	MainFrame.Contents.Unit.Contents.Border.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Glow.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")

	updatePrice(SelectedTower.Value)

	if SelectedTower.Value then
		local observedTower = SelectedTower.Value
		selectedTowerTraitChangedConnection = observedTower:GetAttributeChangedSignal("Trait"):Connect(function()
			if SelectedTower.Value ~= observedTower then return end
			updatePrice(observedTower)
			updateNewWillpowerProfile()
			updateNewWillpowerStatusEffects()
		end)
	end

	local CharModel = GetUnitModel[SelectedTower.Value.Name]
	if CharModel then
		local vp = ViewPortModule.CreateViewPort(SelectedTower.Value.Name,SelectedTower.Value:GetAttribute("Shiny"),true)
		vp.ZIndex = 5
		vp.Active = false
		vp.AnchorPoint = Vector2.new(.5,.5)
		vp.Position = UDim2.new(.5,0,.5,0)
		vp.Size = UDim2.new(1.1,0,1,0)
		vp.Parent = MainFrame.Contents.Unit.Contents
		MainFrame.Contents.Unit.Contents.Icon_Container.Shiny_Icon.Visible = SelectedTower.Value:GetAttribute("Shiny")

		UnitFrame.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")
		UnitFrame.Plus.Transparency = 1
		UnitFrame.Plus.UIStroke.Transparency = 1
		UnitFrame.Indicator.ImageLabel.Visible = false

		if player:FindFirstChild("OwnGamePasses"):FindFirstChild("2x Willpower Luck").Value == true or player:FindFirstChild("Buffs"):FindFirstChild("WillpowerLuckyCrystal") then
			UnitFrame.Indicator.ImageLabel.Visible = true
		end
	else
		warn("Selected tower was not found as a model. Selected tower name: "..SelectedTower.Value.Name)
	end

	updateNewWillpowerProfile()
	updateNewWillpowerStatusEffects()
end)

NormalReroll.Changed:Connect(function()
	RerollText.Text = NormalReroll.Value.."/1"
	if NormalReroll.Value >= 1 then
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end
	updateNewWillpowerStatusEffects()
end)

LuckyReroll.Changed:Connect(function()
	LuckyText.Text = LuckyReroll.Value.."/1"
	if LuckyReroll.Value >= 1 then
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end
	updateNewWillpowerStatusEffects()
end)

local mythicalPityValue = player:WaitForChild("MythicalPityWP", 10)
local legendaryPityValue = player:WaitForChild("LegendaryPityWP", 10)
if mythicalPityValue then
	mythicalPityValue.Changed:Connect(updateWillpowerPityBars)
end
if legendaryPityValue then
	legendaryPityValue.Changed:Connect(updateWillpowerPityBars)
end

MainFrame.Bottom_Bar.Bottom_Bar.Index.Activated:Connect(function()
	UIHandlerModule.PlaySound(MainFrame.Parent.Index.Visible and "Close" or "Open")
	MainFrame.Parent.Index.Visible = not MainFrame.Parent.Index.Visible
end)

TraitReroll.Activated:Connect(function()
	if isAutoRerolling then _G.Message("Stop autorolling to roll manually!", Color3.new(255,0,0)) return end
	Reroll()
end)

WillpowerFrameBase:GetPropertyChangedSignal('Visible'):Connect(updateOpenState)

if NewWillPower then
	NewWillPower:GetPropertyChangedSignal("Visible"):Connect(function()
		updateOpenState()
		if NewWillPower.Visible and populateNewWillpowerPanels then
			populateNewWillpowerPanels()
		end
	end)
end

updateOpenState()

AutoReroll.Activated:Connect(function()
	local tower = SelectedTower.Value
	if not tower then _G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) return end

	isAutoRerolling = not isAutoRerolling

	if isAutoRerolling then
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(toggledColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(toggledColorTop)
	else
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end

	task.spawn(function()
		while isAutoRerolling do
			local result, trait = Reroll()

			if not open then
				isAutoRerolling = false
				break
			end

			if result == "Mythical" or trait == 'Cosmic Crusader' or trait == "Waders Will" then
				isAutoRerolling = false
				break
			end

			if player.TraitPoint.Value <= 0 then
				isAutoRerolling = false
				break
			end

			task.wait(0.25)
		end
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end)
end)

connectGuiAction(ChangeUnit, "WillpowerLegacyChangeUnitConnected", "LegacyChangeUnit", requestWillpowerUnitSelection)

connectGuiAction(RobuxReroll, "WillpowerLegacyLuckyConnected", "LegacyRobuxReroll", function()
	-- Mais um lugar salvo do delay!
	task.spawn(function()
		local Check = CheckIfExists:InvokeServer("LuckyWillpower")
		if not Check then
			if LuckyWillpowerInfo then
				MarketplaceService:PromptProductPurchase(player, LuckyWillpowerInfo.Id)
			end
		else
			Reroll(true)
		end
	end)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userID,productID,isPurchase)
	if userID ~= player.UserId then return end
	if not isPurchase or not LuckyWillpowerInfo or productID ~= LuckyWillpowerInfo.Id then return end
	Reroll(true)
end)

MainFrame.X_Close.Activated:Connect(function()
	safeCloseAll()
end)

for _, ui in MainFrame.Parent.Side_Shop.Contents:GetChildren() do
	if not ui:FindFirstChild("Contents") then continue end
	NewTokenUI(ui)
end

populateNewWillpowerPanels()

local Container = workspace:WaitForChild('Willpower'):WaitForChild("Hitbox")
local zone = Zone.new(Container)

zone.playerEntered:Connect(function(plr)
	if plr == player then
		UIHandlerModule.DisableAllButtons()
		populateNewWillpowerPanels()
		safeCloseAll(getWillpowerMenuTarget())
		_G.CanSummon = false
		open = true

		updateWillpowerPityBars()
	end
end)

zone.playerExited:Connect(function(plr)
	if plr == player then
		_G.CanSummon = true
		clearWillpowerSelectionMode()
		safeCloseAll()
		UIHandlerModule.EnableAllButtons()
	end
end)
