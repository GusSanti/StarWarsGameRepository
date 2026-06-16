-- SERVICES
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS
local ROBUX_CHAR = "\u{E002}"

-- VARIABLES
local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer:FindFirstChild("DataLoaded")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UI = PlayerGui:WaitForChild("NewUI") 

local ShopFrame = UI:WaitForChild("Shop")
local Container = ShopFrame:WaitForChild("Content"):WaitForChild("Contents"):WaitForChild("Contents")

local FunctionsFolder = ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = FunctionsFolder:WaitForChild("GetMarketInfoByName")
local GlobalFunctions = require(ReplicatedStorage.Modules.GlobalFunctions)
local UtilityFunctions = require(ReplicatedStorage.Modules.Functions)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local BuyEvent = ReplicatedStorage.Events.Buy
local SessionOfferRandom = Random.new()
local SessionOfferDeadline = os.time() + SessionOfferRandom:NextInteger(15 * 60 * 60, 20 * 60 * 60)

local BundleConfigs = {
	["1"] = {
		MarketName = "Fawn",
		Title = "Fawn!",
		MainPreview = {
			Type = "Viewport",
			Name = "Fawn",
		},
		Slots = {
			[1] = {
				Type = "Viewport",
				Name = "Fawn",
				Label = "Fawn",
			},
			[2] = {
				Type = "Viewport",
				Name = "Fawn",
				Label = "Fawn",
				ShowBackground = true,
			},
			[3] = {
				Type = "Image",
				Image = 131476601794300,
				Label = "+2,500 Gems",
			},
			[4] = {
				Type = "Image",
				Image = 122847918518753,
				Label = "+15 Trait Points",
			},
			[5] = {
				Type = "Image",
				Image = 98492072936946,
				Label = "+5 Lucky Spins",
			},
		},
	},
	["2"] = {
		MarketName = "Anakin",
		Title = "Anakin!",
		MainPreview = {
			Type = "Viewport",
			Name = "Anikin Armor",
		},
		Slots = {
			[1] = {
				Type = "Viewport",
				Name = "Anikin Armor",
				Label = "Anakin",
			},
			[2] = {
				Type = "Viewport",
				Name = "Anikin Armor",
				Label = "Anakin",
				ShowBackground = true,
			},
			[3] = {
				Type = "Image",
				Image = 131476601794300,
				Label = "+6,000 Gems",
			},
			[4] = {
				Type = "Image",
				Image = 122847918518753,
				Label = "+60 Trait Points",
			},
			[5] = {
				Type = "Image",
				Image = 98492072936946,
				Label = "+15 Lucky Spins",
			},
			[6] = {
				Type = "Image",
				Image = 76937275295988,
				Label = "+5 Lucky Crystals",
			},
		},
	},
	["3"] = {
		MarketName = "Dartwader",
		Title = "Dartwader!",
		MainPreview = {
			Type = "Viewport",
			Name = "Dart Wader",
		},
		Slots = {
			[1] = {
				Type = "Viewport",
				Name = "Dart Wader",
				Label = "Dartwader",
			},
			[2] = {
				Type = "Viewport",
				Name = "Dart Wader",
				Label = "Dartwader",
				ShowBackground = true,
			},
			[3] = {
				Type = "Image",
				Image = 131476601794300,
				Label = "+10,000 Gems",
			},
			[4] = {
				Type = "Image",
				Image = 122847918518753,
				Label = "+100 Trait Points",
			},
			[5] = {
				Type = "Image",
				Image = 98492072936946,
				Label = "+25 Lucky Spins",
			},
			[6] = {
				Type = "Image",
				Image = 108934606157397,
				Label = "+5 Fortunate Crystals",
			},
		},
	},
}

local OfferTimerLabels = {}
local OfferBuyButtons = {}

-- FUNCTIONS
local function getTextTarget(instance)
	if not instance then
		return nil
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		return instance
	end

	return instance:FindFirstChildWhichIsA("TextLabel", true)
		or instance:FindFirstChildWhichIsA("TextButton", true)
end

local function setText(instance, text)
	local target = getTextTarget(instance)
	if target then
		target.Text = text
	end
end

local function formatCountdown(seconds)
	local safeSeconds = math.max(0, seconds)
	local hours = math.floor(safeSeconds / 3600)
	local minutes = math.floor((safeSeconds % 3600) / 60)
	local remainingSeconds = math.floor(safeSeconds % 60)

	return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
end

local function getPreviewContainer(frame)
	if not frame then
		return nil
	end

	return frame:FindFirstChild("Icon", true)
		or frame:FindFirstChildWhichIsA("ViewportFrame", true)
		or frame:FindFirstChildWhichIsA("ImageLabel", true)
end

local function clearGeneratedViewports(container)
	if not container then
		return
	end

	for _, child in container:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
end

local function populateViewportPreview(container, unitName, shiny)
	if not container or not unitName then
		return
	end

	clearGeneratedViewports(container)

	local viewport = ViewPortModule.CreateViewPort(unitName, shiny)
	if not viewport then
		return
	end

	viewport.BackgroundTransparency = 1
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Parent = container
end

local function populateImagePreview(container, imageId)
	if not container or not imageId then
		return
	end

	local imageTarget = if container:IsA("ImageLabel")
		then container
		else container:FindFirstChildWhichIsA("ImageLabel", true)

	if imageTarget then
		imageTarget.Image = `rbxassetid://{imageId}`
	end
end

local function populatePreview(frame, preview)
	if not frame or not preview then
		return
	end

	local previewContainer = getPreviewContainer(frame)
	if not previewContainer then
		return
	end

	if preview.Type == "Viewport" then
		populateViewportPreview(previewContainer, preview.Name, preview.Shiny == true)
	elseif preview.Type == "Image" then
		populateImagePreview(previewContainer, preview.Image)
	end
end

local function setupSlot(slotFrame, preview)
	if not slotFrame then
		return
	end

	slotFrame.Visible = preview ~= nil

	local icon = slotFrame:FindFirstChild("Icon", true)
	if not preview then
		if icon then
			clearGeneratedViewports(icon)
		end
		return
	end

	local bg = slotFrame:FindFirstChild("Bg", true)
	if preview.ShowBackground and bg and bg:IsA("GuiObject") then
		bg.Visible = true
	end

	if icon and icon:IsA("GuiObject") then
		icon.Visible = preview.HideIcon ~= true
		if preview.HideIcon then
			clearGeneratedViewports(icon)
		end
	end

	local textFrame = slotFrame:FindFirstChild("Text", true)
	local nameLabel = textFrame and textFrame:FindFirstChild("Name", true)
	if nameLabel then
		setText(nameLabel, preview.Label or "")
	end

	populatePreview(slotFrame, preview)
end

local function getBuyButton(frame)
	local buyRoot = frame and frame:FindFirstChild("Buy")
	if not buyRoot then
		return nil
	end

	if buyRoot:IsA("GuiButton") then
		return buyRoot
	end

	return buyRoot:FindFirstChild("Btn", true)
		or buyRoot:FindFirstChildWhichIsA("TextButton", true)
		or buyRoot:FindFirstChildWhichIsA("ImageButton", true)
end

local function getAmountLabel(frame)
	local buyRoot = frame and frame:FindFirstChild("Buy")
	if not buyRoot then
		return nil
	end

	return buyRoot:FindFirstChild("Amount", true)
end

local function registerOfferUi(offSaleLabel, buyButton)
	if offSaleLabel then
		table.insert(OfferTimerLabels, offSaleLabel)
	end

	if buyButton then
		table.insert(OfferBuyButtons, buyButton)
	end
end

local function setButtonInteractable(button, isInteractable)
	if not button or not button:IsA("GuiButton") then
		return
	end

	button.Active = isInteractable
	button.AutoButtonColor = isInteractable
end

local function updateOfferTimer()
	local remaining = math.max(0, SessionOfferDeadline - os.time())
	local timerText = `OFFSALE IN: {formatCountdown(remaining)}`

	for _, label in OfferTimerLabels do
		setText(label, timerText)
	end

	if remaining <= 0 then
		for _, button in OfferBuyButtons do
			if button:IsA("GuiButton") then
				button.Active = false
				button.AutoButtonColor = false
			end
		end
	end

	return remaining
end

local function SetupPassFrame(frame)
	local buyBtn = frame:FindFirstChild("Buy")
	local icon = frame:FindFirstChild("Icon")

	local label = frame:FindFirstChild("Robux")
	if label and not label:IsA("TextLabel") then
		label = label:FindFirstChildOfClass("TextLabel") or label
	end

	local info = GetMarketInfoByName:InvokeServer(frame.Name)
	if not info then return end

	local ownedFlag = LocalPlayer.OwnGamePasses:FindFirstChild(frame.Name)
	if ownedFlag then
		local function update()
			if ownedFlag.Value and label then
				label.Text = "Owned"
			end
		end
		ownedFlag:GetPropertyChangedSignal("Value"):Connect(update)
		update()
	end

	if buyBtn then
		buyBtn.MouseButton1Down:Connect(function()
			if info.OneTimePurchase and ownedFlag and ownedFlag.Value then return end
			BuyEvent:FireServer(info.Id)
		end)
		buyBtn:AddTag("Shine")
	end

	task.spawn(function()
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(
				info.Id,
				info.IsGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
			)
		end)
		if success and result and result.PriceInRobux and label then
			label.Text = `{ROBUX_CHAR}{UtilityFunctions.addCommas(result.PriceInRobux)}`
		end
	end)

	if icon then
		icon:AddTag("Bob")
		icon:AddTag("Scaling")
	end
end

local function SetupBundleFrame(frame, config)
	if not frame or not config then
		return
	end

	local info = GetMarketInfoByName:InvokeServer(config.MarketName)
	if not info then
		return
	end

	local texts = frame:FindFirstChild("Texts")
	if texts then
		setText(texts:FindFirstChild("Title"), config.Title)
		setText(texts:FindFirstChild("Remaining"), "1/1 Remaining")
		setText(texts:FindFirstChild("Limited"), "Limited")
	end

	populatePreview(frame:FindFirstChild("Character"), config.MainPreview)

	local slots = frame:FindFirstChild("Slots")
	if slots then
		for index = 1, 6 do
			setupSlot(slots:FindFirstChild(tostring(index)), config.Slots[index])
		end
	end

	local buyButton = getBuyButton(frame)
	local amountLabel = getAmountLabel(frame)
	local offSaleLabel = texts and texts:FindFirstChild("OffSale")
	local ownedFlag = info.OneTimePurchase and LocalPlayer.OwnGamePasses:FindFirstChild(config.MarketName)

	local function updateOwnedState()
		local isOwned = ownedFlag and ownedFlag.Value == true
		local isOfferActive = SessionOfferDeadline > os.time()
		local canBuy = isOfferActive and not isOwned

		if texts then
			setText(texts:FindFirstChild("Remaining"), isOwned and "0/1 Remaining" or "1/1 Remaining")
		end

		if amountLabel and isOwned then
			setText(amountLabel, "Owned")
		end

		setButtonInteractable(buyButton, canBuy)
	end

	registerOfferUi(offSaleLabel, buyButton)

	if buyButton then
		buyButton.Activated:Connect(function()
			if SessionOfferDeadline <= os.time() then
				return
			end

			if ownedFlag and ownedFlag.Value == true then
				return
			end

			BuyEvent:FireServer(info.Id)
		end)
		buyButton:AddTag("Shine")
	end

	task.spawn(function()
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(
				info.Id,
				info.IsGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
			)
		end)

		if success and result and result.PriceInRobux and amountLabel then
			setText(amountLabel, `{ROBUX_CHAR}{UtilityFunctions.addCommas(result.PriceInRobux)}`)
		end

		updateOwnedState()
	end)

	if ownedFlag then
		ownedFlag:GetPropertyChangedSignal("Value"):Connect(updateOwnedState)
	end

	updateOwnedState()
end

local function Animate(tag, fn)
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
	for _, obj in CollectionService:GetTagged(tag) do
		task.spawn(fn, obj)
	end
end

-- INIT
local closeBtn = ShopFrame:FindFirstChild("Closebtn"):WaitForChild("Btn")
if closeBtn then
	closeBtn.Activated:Connect(function()
		if _G.CloseAll then
			_G.CloseAll()
		end
	end)
end

for _, category in Container:GetChildren() do
	if category:IsA("Frame") then
		if category.Name == "GemSlections" then
			local mainFrame = category:FindFirstChild("Main")
			if mainFrame then
				local colossalPack = mainFrame:FindFirstChild("Colossal Pack")
				if colossalPack and colossalPack:IsA("Frame") and colossalPack:FindFirstChild("Buy") then
					SetupPassFrame(colossalPack)
				end

				local normalFrame = mainFrame:FindFirstChild("Normal")
				if normalFrame then
					for _, productFrame in normalFrame:GetChildren() do
						if productFrame:IsA("Frame") and productFrame:FindFirstChild("Buy") then
							SetupPassFrame(productFrame)
						end
					end
				end
			end
		else
			for _, productFrame in category:GetChildren() do
				if productFrame:IsA("Frame") and productFrame:FindFirstChild("Buy") then
					SetupPassFrame(productFrame)
				end
			end
		end
	end
end

local BundlesFrame = Container:FindFirstChild("Bundles")
local BundleList = BundlesFrame and BundlesFrame:FindFirstChild("Main")
if BundleList then
	for bundleName, config in BundleConfigs do
		SetupBundleFrame(BundleList:FindFirstChild(bundleName), config)
	end

	task.spawn(function()
		while updateOfferTimer() > 0 do
			task.wait(1)
		end

		updateOfferTimer()
	end)
end
