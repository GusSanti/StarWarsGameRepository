local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local PlayerData = ClientDataLoaded.getPlayerData()
local Functions = require(ReplicatedStorage.Modules.Functions)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local NewValues = NewUI:FindFirstChild("Values")

local function addLabelIfPresent(labels, label)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		table.insert(labels, label)
	end
end

local function addLegacyNewValueLabel(labels, currencyName)
	local valueFrame = NewValues and NewValues:FindFirstChild(currencyName)
	if not valueFrame then return end

	local label = valueFrame:FindFirstChild("Text")
	addLabelIfPresent(labels, label)

	if #labels > 0 then return end

	addLabelIfPresent(labels, valueFrame:FindFirstChildWhichIsA("TextLabel", true))
end

local function getCurrencyBarContents()
	local currencyBar = PlayerGui:FindFirstChild("Currency_Bar", true)
	local contents = currencyBar and (currencyBar:FindFirstChild("Contents") or currencyBar:FindFirstChild("Contents", true))

	if contents then
		contents.Visible = true
	end

	return contents
end

local function waitForCurrencyBarContents(timeout)
	local contents = getCurrencyBarContents()
	local startTime = os.clock()

	while not contents and os.clock() - startTime < timeout do
		task.wait(0.1)
		contents = getCurrencyBarContents()
	end

	return contents
end

local function addCurrencyBarValueLabel(labels, currencyName)
	local contents = getCurrencyBarContents()
	local currencyFrame = contents and contents:FindFirstChild(currencyName)
	if not currencyFrame then return end

	local labelCount = #labels
	local valueLabel = currencyFrame:FindFirstChild("Value")
	addLabelIfPresent(labels, valueLabel)

	if #labels > labelCount then return end

	addLabelIfPresent(labels, currencyFrame:FindFirstChildWhichIsA("TextLabel", true))
end

local function getValueLabels(currencyName)
	local labels = {}
	addLegacyNewValueLabel(labels, currencyName)
	addCurrencyBarValueLabel(labels, currencyName)

	return labels
end

local function updateCurrency(currencyName)
	local currency = PlayerData:FindFirstChild(currencyName)
	if not currency then return end

	local formattedValue = Functions.addCommas(currency.Value)

	local oldCurrencyFrame = script.Parent:FindFirstChild(currencyName)
	local oldAmount = oldCurrencyFrame and oldCurrencyFrame:FindFirstChild("Amount")
	if oldAmount and oldAmount:IsA("TextLabel") then
		oldAmount.Text = formattedValue
	end

	for _, newValueLabel in getValueLabels(currencyName) do
		newValueLabel.Text = formattedValue
		newValueLabel.TextTransparency = 0
		newValueLabel.Visible = true
	end
end

local watchedCurrencies = {}
local watchedContents = {}
local addWatchedCurrency

local function updateCurrencyBarContents(contents)
	if not contents or watchedContents[contents] then return end

	watchedContents[contents] = true

	for _, v: Frame in contents:GetChildren() do
		if v:IsA('Frame') then
			addWatchedCurrency(v.Name)
			updateCurrency(v.Name)
		end
	end

	contents.ChildAdded:Connect(function(child)
		if child:IsA("Frame") then
			addWatchedCurrency(child.Name)
			updateCurrency(child.Name)
		end
	end)
end

addWatchedCurrency = function(currencyName)
	if watchedCurrencies[currencyName] then return end

	local currency = PlayerData:FindFirstChild(currencyName) :: NumberValue
	if not currency then return end

	watchedCurrencies[currencyName] = true
	updateCurrency(currencyName)
	currency.Changed:Connect(function()
		updateCurrency(currencyName)
	end)
end

for _, v: Frame in script.Parent:GetChildren() do
	if v:IsA('Frame') then
		addWatchedCurrency(v.Name)
	end
end

if NewValues then
	for _, v: Frame in NewValues:GetChildren() do
		if v:IsA('Frame') then
			addWatchedCurrency(v.Name)
		end
	end
end

local currencyBarContents = getCurrencyBarContents()
if currencyBarContents then
	updateCurrencyBarContents(currencyBarContents)
else
	for _, currencyName in { "Coins", "Gems" } do
		addWatchedCurrency(currencyName)
	end
end

task.spawn(function()
	local contents = waitForCurrencyBarContents(5)
	if not contents then return end

	updateCurrencyBarContents(contents)
end)

PlayerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "Currency_Bar" then
		local contents = descendant:FindFirstChild("Contents") or descendant:FindFirstChild("Contents", true)
		updateCurrencyBarContents(contents)
	elseif descendant.Name == "Contents" and descendant.Parent and descendant.Parent.Name == "Currency_Bar" then
		updateCurrencyBarContents(descendant)
	elseif descendant.Name == "Value" then
		local currencyFrame = descendant:FindFirstAncestor("Coins") or descendant:FindFirstAncestor("Gems")
		if currencyFrame and currencyFrame.Parent and currencyFrame.Parent.Name == "Contents" and currencyFrame.Parent.Parent and currencyFrame.Parent.Parent.Name == "Currency_Bar" then
			updateCurrency(currencyFrame.Name)
		end
	end
end)
