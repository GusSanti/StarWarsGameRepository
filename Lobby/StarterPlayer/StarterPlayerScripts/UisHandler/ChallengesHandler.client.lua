-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local Events = ReplicatedStorage:WaitForChild("Events")
local ChallengesEvents = Events:WaitForChild("Challenges")
local ChallengePurchase = ChallengesEvents:WaitForChild("ChallengePurchase")
local CreditsChanged = ChallengesEvents:WaitForChild("CheckCurrency")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ViewPortModule = require(Modules:WaitForChild("ViewPortModule"))

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGUI = Player:WaitForChild("PlayerGui")

local NewUI = PlayerGUI:WaitForChild("NewUI")
local ChallengeShopGUI = NewUI:WaitForChild("ChallengeShopFrame")
local Main = ChallengeShopGUI:WaitForChild("Main")
local RewardsTab = Main:WaitForChild("RewardsTab")
local TextAmount = RewardsTab:WaitForChild("TextAmount")
local RewardsContainer = RewardsTab:WaitForChild("Rewards"):WaitForChild("Rewards")

local CoreGameUI = PlayerGUI:WaitForChild("CoreGameUI")
local Prompt = CoreGameUI:WaitForChild("Prompt"):WaitForChild("Prompt")
local CurrencyCongratsLabel = PlayerGUI:WaitForChild("GameGui"):WaitForChild("PRShop"):WaitForChild("Success")

local ItemNameAliases = {
	["Red Crystal"] = "Crystal (Red)",
}

local debounceFlags = {}
local selectedItem = nil
local rewardButtonsConnected = false

-- FUNCTIONS
local function ShowSuccessMessage(typeOf, name, quantity)
	if typeOf == "Currency" then
		local itemName = typeof(name) == "Instance" and name.Name or tostring(name)
		CurrencyCongratsLabel.Text = tostring(quantity) .. "x " .. itemName .. " Earned!"
		CurrencyCongratsLabel.Visible = true
		task.wait(2)
		CurrencyCongratsLabel.Visible = false
	end

	if typeOf == nil then
		_G.Message("Purchase Failed", Color3.fromRGB(255, 5, 17))
	else
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

local function ResolveRewardItemName(rewardCard)
	local configuredName = rewardCard:GetAttribute("ItemName")
		or rewardCard:GetAttribute("ShopItemName")
		or rewardCard:GetAttribute("ProductName")
	local itemName = configuredName or rewardCard.Name

	return ItemNameAliases[itemName] or itemName
end

local function GetRewardCardButton(rewardCard)
	if rewardCard:IsA("GuiButton") then
		return rewardCard
	end

	return rewardCard:FindFirstChildWhichIsA("GuiButton", true)
end

local function GetRewardCards()
	local rewardCards = {}

	for _, child in ipairs(RewardsContainer:GetChildren()) do
		if not child:IsA("GuiObject") then
			continue
		end

		local button = GetRewardCardButton(child)
		if button then
			local itemName = ResolveRewardItemName(child)
			rewardCards[itemName] = {
				Card = child,
				Button = button,
			}
		end
	end

	return rewardCards
end

local function DestroyViewportInstance(viewport)
	if not viewport then
		return
	end

	if ViewPortModule.DestroyViewport then
		ViewPortModule.DestroyViewport(viewport)
	end

	if viewport.Parent then
		viewport:Destroy()
	end
end

local function ApplyViewportLayout(viewport, referenceViewport)
	if referenceViewport then
		viewport.Name = referenceViewport.Name
		viewport.AnchorPoint = referenceViewport.AnchorPoint
		viewport.Position = referenceViewport.Position
		viewport.Size = referenceViewport.Size
		viewport.AutomaticSize = referenceViewport.AutomaticSize
		viewport.LayoutOrder = referenceViewport.LayoutOrder
		viewport.Rotation = referenceViewport.Rotation
		viewport.ZIndex = referenceViewport.ZIndex
		viewport.Visible = referenceViewport.Visible
		viewport.ClipsDescendants = referenceViewport.ClipsDescendants
		return
	end

	viewport.Name = "ViewportFrame"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
end

local function SetupViewPorts()
	for itemName, rewardData in pairs(GetRewardCards()) do
		local placeholder = rewardData.Card:FindFirstChild("Placeholder")
		if not placeholder then
			continue
		end

		local existingViewport = placeholder:FindFirstChildWhichIsA("ViewportFrame")
		if existingViewport and existingViewport:GetAttribute("ChallengeShopItem") == itemName then
			continue
		end

		local viewport = ViewPortModule.CreateViewPort(itemName)
		if not viewport then
			continue
		end

		local icon = placeholder:FindFirstChild("Icon")
		if icon and (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) then
			icon.Image = ""
		end

		ApplyViewportLayout(viewport, existingViewport)
		DestroyViewportInstance(existingViewport)

		viewport:SetAttribute("ChallengeShopItem", itemName)
		viewport.Parent = placeholder
	end
end

local function UpdateCurrencyDisplay()
	local creditsValue = CreditsChanged:InvokeServer(Player)
	TextAmount.Text = "Republic Credits: x" .. tostring(creditsValue)
end

local function ConnectRewardButtons()
	if rewardButtonsConnected then
		return
	end

	rewardButtonsConnected = true

	for itemName, rewardData in pairs(GetRewardCards()) do
		local button = rewardData.Button
		debounceFlags[itemName] = false

		button.Activated:Connect(function()
			if debounceFlags[itemName] then
				return
			end

			debounceFlags[itemName] = true
			selectedItem = itemName
			Prompt.Visible = true

			task.wait(1)
			debounceFlags[itemName] = false
		end)
	end
end

local function SetChallengeShopVisible(visible)
	if visible then
		UpdateCurrencyDisplay()
		SetupViewPorts()
		ConnectRewardButtons()

		if _G.CloseAll then
			_G.CloseAll("ChallengeShopFrame")
		else
			ChallengeShopGUI.Visible = true
		end
	else
		if _G.CloseAll and ChallengeShopGUI.Visible then
			_G.CloseAll()
		else
			ChallengeShopGUI.Visible = false
		end
	end
end

-- INIT
Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		ChallengePurchase:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

ChallengeShopGUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if ChallengeShopGUI.Visible then
		UpdateCurrencyDisplay()
		SetupViewPorts()
		ConnectRewardButtons()
	end
end)

ChallengesEvents:WaitForChild("ChallengeShopLoading").Event:Connect(function(visible)
	SetChallengeShopVisible(visible)
end)

ChallengePurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)

local currency = Player:WaitForChild("RepublicCredits", 10)
if currency then
	currency:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateCurrencyDisplay()
	end)
end
