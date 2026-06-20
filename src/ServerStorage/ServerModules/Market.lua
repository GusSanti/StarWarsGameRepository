local Players = game:GetService("Players")
local MarketPlaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local PurchaseLog = DataStoreService:GetDataStore("PurchaseLog")
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local DiscordHook = require(game.ServerStorage.ServerModules.DiscordWebhook)
local PurchaseHook = DiscordHook.new("PurchaseLog")
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)
local Upgrades = require(ReplicatedStorage.Upgrades)
local ItemStats = require(ReplicatedStorage:WaitForChild("ItemStats"))

local GiftToList = {}
local ClientEvents = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client")
local ChatMessage = ClientEvents.ChatMessage
local Message = ClientEvents.Message
local PassesList = require(ReplicatedStorage.Modules.PassesList)

local ProcessingPurchases = {}
local PurchaseRewardSummaryEvent = ClientEvents:FindFirstChild("PurchaseRewardSummary")

if not PurchaseRewardSummaryEvent then
	PurchaseRewardSummaryEvent = Instance.new("RemoteEvent")
	PurchaseRewardSummaryEvent.Name = "PurchaseRewardSummary"
	PurchaseRewardSummaryEvent.Parent = ClientEvents
end

local RewardRarityPriority = {
	Secret = 7,
	Mythical = 6,
	Unique = 5,
	Legendary = 4,
	Epic = 3,
	Rare = 2,
	Common = 1,
}

local TrackedPurchaseCurrencies = {
	{
		valueName = "Gems",
		displayName = "Gems",
		viewportName = "Gems",
	},
	{
		valueName = "TraitPoint",
		displayName = "Willpower",
		viewportName = "Willpower",
	},
	{
		valueName = "LuckySpins",
		displayName = "Lucky Summons",
		viewportName = "LuckySpins",
	},
}

local TrackedPurchaseValues = {
	{
		path = {"ClanData", "CreationTokens"},
		displayName = "Clan Creation Token",
		cardTitle = "PURCHASE REWARD",
	},
}

game:GetService('Players').PlayerAdded:Connect(function(player)
	repeat task.wait() until not player or player:FindFirstChild('DataLoaded')
	if player and player.Parent then
		for i, v in PassesList.Information do
			if v.IsGamePass then
				if MarketPlaceService:UserOwnsGamePassAsync(player.UserId,v.Id) and player.OwnGamePasses:FindFirstChild(i) then
					player.OwnGamePasses[i].Value = true
				end
			end
		end
	end
end)

local module = {}

local OwnedProductFlagAliases = {
	["Cad Bunny Bundle"] = {"Cad Bunny Bundle", "Anakin"},
}

local function getOwnedProductFlagNames(productName)
	local aliasNames = OwnedProductFlagAliases[productName]
	if aliasNames then
		return aliasNames
	end

	return {productName}
end

local function getRewardRarityPriority(rarityName)
	return RewardRarityPriority[rarityName] or 0
end

local function getPurchaseRewardSortScore(entry)
	local categoryScore = 0

	if entry.entryType == "tower" then
		categoryScore = 5000
	elseif entry.entryType == "pass" then
		categoryScore = 4000
	elseif entry.entryType == "battlepass" then
		categoryScore = 3500
	elseif entry.entryType == "item" then
		categoryScore = 3000
	elseif entry.entryType == "currency" then
		categoryScore = 2000
	else
		categoryScore = 1000
	end

	return categoryScore + getRewardRarityPriority(entry.rarity) * 100 + math.min(entry.quantity or 1, 99)
end

local function buildTowerRewardName(baseName, isShiny, traitName)
	local displayName = tostring(baseName or "Reward")

	if isShiny then
		displayName = "Shiny " .. displayName
	end

	if traitName and traitName ~= "" then
		displayName = displayName .. " [" .. traitName .. "]"
	end

	return displayName
end

local function safeFindChildPath(root, path)
	local current = root

	for _, name in ipairs(path or {}) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

local function getNumberValue(root, childName)
	local child = root and root:FindFirstChild(childName)
	if child and child:IsA("ValueBase") and typeof(child.Value) == "number" then
		return child.Value
	end

	return 0
end

local function capturePurchaseRewardState(player)
	local snapshot = {
		currencies = {},
		items = {},
		passes = {},
		towers = {},
		battlepassPremium = false,
		battlepassTier = 0,
		values = {},
	}

	for _, currencyConfig in ipairs(TrackedPurchaseCurrencies) do
		snapshot.currencies[currencyConfig.valueName] = getNumberValue(player, currencyConfig.valueName)
	end

	local itemsFolder = player and player:FindFirstChild("Items")
	if itemsFolder then
		for _, itemValue in ipairs(itemsFolder:GetChildren()) do
			if itemValue:IsA("ValueBase") and typeof(itemValue.Value) == "number" then
				snapshot.items[itemValue.Name] = itemValue.Value
			end
		end
	end

	local ownGamePasses = player and player:FindFirstChild("OwnGamePasses")
	if ownGamePasses then
		for _, passValue in ipairs(ownGamePasses:GetChildren()) do
			if passValue:IsA("BoolValue") then
				snapshot.passes[passValue.Name] = passValue.Value == true
			end
		end
	end

	local ownedTowers = player and player:FindFirstChild("OwnedTowers")
	if ownedTowers then
		for _, towerValue in ipairs(ownedTowers:GetChildren()) do
			if towerValue:IsA("StringValue") then
				local uniqueId = towerValue:GetAttribute("UniqueID") or towerValue.Name
				snapshot.towers[tostring(uniqueId)] = {
					name = towerValue.Name,
					traitName = towerValue:GetAttribute("Trait"),
					isShiny = towerValue:GetAttribute("Shiny") == true,
					rarity = Upgrades[towerValue.Name] and Upgrades[towerValue.Name].Rarity or nil,
				}
			end
		end
	end

	local battlepassData = player and player:FindFirstChild("BattlepassData")
	if battlepassData then
		local premium = battlepassData:FindFirstChild("Premium")
		local tier = battlepassData:FindFirstChild("Tier")

		if premium and premium:IsA("BoolValue") then
			snapshot.battlepassPremium = premium.Value == true
		end

		if tier and tier:IsA("ValueBase") and typeof(tier.Value) == "number" then
			snapshot.battlepassTier = tier.Value
		end
	end

	for _, trackedValue in ipairs(TrackedPurchaseValues) do
		local valueObject = safeFindChildPath(player, trackedValue.path)
		if valueObject and valueObject:IsA("ValueBase") and typeof(valueObject.Value) == "number" then
			snapshot.values[table.concat(trackedValue.path, ".")] = valueObject.Value
		end
	end

	return snapshot
end

local function insertPurchaseRewardEntry(entries, entryData)
	entryData.sortScore = getPurchaseRewardSortScore(entryData)
	table.insert(entries, entryData)
end

local function buildPurchaseRewardSummary(productName, beforeState, afterState)
	if not (beforeState and afterState) then
		return nil
	end

	local entries = {}
	local totalQuantity = 0

	for _, currencyConfig in ipairs(TrackedPurchaseCurrencies) do
		local previousValue = beforeState.currencies[currencyConfig.valueName] or 0
		local currentValue = afterState.currencies[currencyConfig.valueName] or 0
		local diff = currentValue - previousValue

		if diff > 0 then
			insertPurchaseRewardEntry(entries, {
				entryType = "currency",
				name = currencyConfig.displayName,
				displayName = currencyConfig.displayName,
				viewportName = currencyConfig.viewportName,
				isCurrency = true,
				quantity = diff,
			})
			totalQuantity += diff
		end
	end

	for _, trackedValue in ipairs(TrackedPurchaseValues) do
		local valueKey = table.concat(trackedValue.path, ".")
		local previousValue = beforeState.values[valueKey] or 0
		local currentValue = afterState.values[valueKey] or 0
		local diff = currentValue - previousValue

		if diff > 0 then
			insertPurchaseRewardEntry(entries, {
				entryType = "value",
				name = trackedValue.displayName,
				displayName = trackedValue.displayName,
				quantity = diff,
				cardTitle = trackedValue.cardTitle,
			})
			totalQuantity += diff
		end
	end

	for itemName, currentValue in pairs(afterState.items) do
		local previousValue = beforeState.items[itemName] or 0
		local diff = currentValue - previousValue

		if diff > 0 then
			local itemInfo = ItemStats[itemName]
			insertPurchaseRewardEntry(entries, {
				entryType = "item",
				name = itemName,
				displayName = itemName,
				viewportName = itemName,
				rarity = itemInfo and itemInfo.Rarity or nil,
				quantity = diff,
			})
			totalQuantity += diff
		end
	end

	for uniqueId, towerInfo in pairs(afterState.towers) do
		if beforeState.towers[uniqueId] == nil then
			insertPurchaseRewardEntry(entries, {
				entryType = "tower",
				entryKey = "tower:" .. tostring(uniqueId),
				name = towerInfo.name,
				displayName = buildTowerRewardName(towerInfo.name, towerInfo.isShiny, towerInfo.traitName),
				viewportName = towerInfo.name,
				rarity = towerInfo.rarity,
				isShiny = towerInfo.isShiny,
				quantity = 1,
			})
			totalQuantity += 1
		end
	end

	for passName, currentValue in pairs(afterState.passes) do
		if currentValue == true and beforeState.passes[passName] ~= true and passName ~= productName then
			insertPurchaseRewardEntry(entries, {
				entryType = "pass",
				name = passName,
				displayName = passName,
				quantity = 1,
				cardTitle = "PASS",
			})
			totalQuantity += 1
		end
	end

	if afterState.battlepassPremium == true and beforeState.battlepassPremium ~= true then
		insertPurchaseRewardEntry(entries, {
			entryType = "battlepass",
			name = "Premium Battlepass",
			displayName = "Premium Battlepass",
			quantity = 1,
			cardTitle = "PASS",
		})
		totalQuantity += 1
	end

	local battlepassTierDiff = (afterState.battlepassTier or 0) - (beforeState.battlepassTier or 0)
	if battlepassTierDiff > 0 then
		insertPurchaseRewardEntry(entries, {
			entryType = "battlepass",
			name = "Battlepass Tier Skip",
			displayName = "Battlepass Tier Skip",
			quantity = battlepassTierDiff,
			cardTitle = "BATTLEPASS",
		})
		totalQuantity += battlepassTierDiff
	end

	table.sort(entries, function(a, b)
		if (a.sortScore or 0) ~= (b.sortScore or 0) then
			return (a.sortScore or 0) > (b.sortScore or 0)
		end

		if (a.quantity or 0) ~= (b.quantity or 0) then
			return (a.quantity or 0) > (b.quantity or 0)
		end

		return tostring(a.displayName or a.name or "") < tostring(b.displayName or b.name or "")
	end)

	if #entries == 0 then
		return nil
	end

	return {
		summaryTitle = string.format("%s Rewards", tostring(productName or "Purchase")),
		summaryCardTitle = "PURCHASE REWARD",
		entries = entries,
		featured = entries[1],
		totalQuantity = totalQuantity,
	}
end

local function firePurchaseRewardPopupState(player, action, summaryData)
	if not (player and player.Parent) then
		return
	end

	PurchaseRewardSummaryEvent:FireClient(player, {
		action = action,
		summary = summaryData,
		suppressForSeconds = 1.5,
	})
end

local function getOwnedProductFlag(player, productName)
	local ownGamePasses = player and player:FindFirstChild("OwnGamePasses")
	if not ownGamePasses then
		return nil
	end

	for _, flagName in ipairs(getOwnedProductFlagNames(productName)) do
		local ownedFlag = ownGamePasses:FindFirstChild(flagName)
		if ownedFlag then
			return ownedFlag
		end
	end

	return nil
end

local function setOwnedProductFlag(player, productName, ownedValue)
	local ownGamePasses = player and player:FindFirstChild("OwnGamePasses")
	if not ownGamePasses then
		return
	end

	for _, flagName in ipairs(getOwnedProductFlagNames(productName)) do
		local ownedFlag = ownGamePasses:FindFirstChild(flagName)
		if ownedFlag and ownedFlag:IsA("BoolValue") then
			ownedFlag.Value = ownedValue == true
		end
	end
end

local function playerOwnsProduct(player, productName, productInfo)
	if not productInfo or not player then
		return false
	end

	local ownedFlag = getOwnedProductFlag(player, productName)
	if not ownedFlag or ownedFlag.Value ~= true then
		return false
	end

	return productInfo.IsGamePass == true or productInfo.OneTimePurchase == true
end

function module.ProcessReceipt(ReceiptInfo)
	warn('devproduct purchased')
	warn(ReceiptInfo)

	local PlayerId = ReceiptInfo.PlayerId
	local ProductId = ReceiptInfo.ProductId
	local PurchaseId = ReceiptInfo.PurchaseId
	local Player = Players:GetPlayerByUserId(PlayerId)

	if not Player then 
		warn("Player not found for purchase")
		return Enum.ProductPurchaseDecision.NotProcessedYet 
	end

	local ProcessingKey = `{PlayerId}_{PurchaseId}`
	if ProcessingPurchases[ProcessingKey] then
		warn("Purchase already being processed:", ProcessingKey)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	ProcessingPurchases[ProcessingKey] = true

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo then
		ProcessingPurchases[ProcessingKey] = nil
		warn("No product info found for ID:", ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local RunFunction
	local IsGamePass
	local IsGift, GiftPlayer
	local PlayerProductKey = `{PlayerId}_{PurchaseId}`

	print('product info:')
	print(ProductInfo)

	if ProductInfo.Id == ProductId then
		print('Normal Product')
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]
			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]
			IsGamePass = false
		end
	elseif ProductInfo.GiftId == ProductId then
		GiftPlayer = GiftToList[Player]
		if GiftPlayer == nil or not GiftPlayer:FindFirstChild("DataLoaded") then 
			ProcessingPurchases[ProcessingKey] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet 
		end
		IsGift = true
		if ProductInfo.IsGamePass then
			RunFunction = PassesList.GamePasses[ProductInfo.Id]
			IsGamePass = true
		else
			RunFunction = PassesList.Products[ProductInfo.Id]
			IsGamePass = false
		end
		ChatMessage:FireAllClients(`<font color="rgb(0, 255, 238)"><font face="SourceSans"><i>{Player.DisplayName}</i> has bestowed a generous gift(<b>{ProductName}</b>) upon <i>{GiftPlayer.DisplayName}</i>.</font></font>`)
	else
		ProcessingPurchases[ProcessingKey] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, isPurchaseRecorded = pcall(function()
		local alreadyProcessed = PurchaseLog:GetAsync(PlayerProductKey)
		if alreadyProcessed then
			warn("Purchase already processed:", PlayerProductKey)
			return true
		end

		if Player.Parent == nil or not Player:FindFirstChild("DataLoaded") then
			warn("Buyer left game during processing")
			return false
		end

		if IsGift and (GiftPlayer.Parent == nil or not GiftPlayer:FindFirstChild("DataLoaded")) then
			warn("Gift recipient left game during processing")
			return false
		end

		--local functionSuccess, functionResult 
		--local targetPlayer = IsGift and GiftPlayer or Player

		--if IsGamePass then
		--	functionSuccess, functionResult = pcall(RunFunction, targetPlayer)
		--else
		--	functionSuccess, functionResult = pcall(RunFunction, ReceiptInfo, targetPlayer)
		--end


		local functionSuccess, functionResult 
		local targetPlayer = IsGift and GiftPlayer or Player
		local rewardSnapshotBefore = capturePurchaseRewardState(targetPlayer)

		if ProductInfo.OneTimePurchase and playerOwnsProduct(targetPlayer, ProductName, ProductInfo) then
			warn("One-time product receipt received for already-owned product:", ProductName, "Player:", targetPlayer.Name)
			return true
		end

		firePurchaseRewardPopupState(targetPlayer, "begin")

		if IsGamePass then
			functionSuccess, functionResult = pcall(RunFunction, targetPlayer)
		else
			functionSuccess, functionResult = pcall(RunFunction, ReceiptInfo, targetPlayer)
		end

		local rewardSummary = nil
		if functionSuccess and functionResult then
			rewardSummary = buildPurchaseRewardSummary(
				ProductName,
				rewardSnapshotBefore,
				capturePurchaseRewardState(targetPlayer)
			)
		end

		firePurchaseRewardPopupState(targetPlayer, "complete", rewardSummary)

		if not functionSuccess then
			warn(`Purchase Function Threw Error: {functionResult}`)
			return false
		end

		if not functionResult then
			warn("Reward function didn't explicitly return true — assuming success anyway")
		end

		if ProductInfo.OneTimePurchase then
			setOwnedProductFlag(targetPlayer, ProductName, true)
		end

		spawn(function()
			pcall(function()
				PurchaseLog:SetAsync(PlayerProductKey, true)
			end)
		end)

		warn("Purchase processed successfully")




		if not functionSuccess or not functionResult then
			warn(`Purchase Function Failed: {functionResult}`)
			warn(`PurchaseId: {PurchaseId} | PlayerName: {Player.Name} | ProductID: {ProductInfo.Id}`)
			return false
		end

		local marketplaceInfo = MarketPlaceService:GetProductInfo(ProductId, Enum.InfoType.Product)
		local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
		if priceInRobux and Player:FindFirstChild("RobuxSpent") then
			Player.RobuxSpent.Value += priceInRobux
		end

		spawn(function()
			pcall(function()
				PurchaseLog:SetAsync(PlayerProductKey, true)
			end)
		end)

		warn("Purchase processed successfully")
		return true
	end)

	ProcessingPurchases[ProcessingKey] = nil

	warn('Purchase processing result:')
	print(success, isPurchaseRecorded)

	if success and isPurchaseRecorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		warn(`Purchase processing failed - Success: {success}, Recorded: {isPurchaseRecorded}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function module.PromptGamePassPurchaseFinished(Player, GamePassId, wasPurchased)
	warn('gamepass purchase finished')

	if not wasPurchased then return end

	if not Player.Parent or not Player:FindFirstChild("DataLoaded") then
		warn("Player left before gamepass could be processed")
		return
	end

	local marketplaceInfo = MarketPlaceService:GetProductInfo(GamePassId, Enum.InfoType.GamePass)
	local priceInRobux = marketplaceInfo and marketplaceInfo.PriceInRobux
	if priceInRobux and Player:FindFirstChild("RobuxSpent") then
		Player.RobuxSpent.Value += priceInRobux
	end

	local gamepassFunction = PassesList.GamePasses[GamePassId]
	if gamepassFunction then
		local success, result = pcall(gamepassFunction, Player)
		if not success then
			warn(`Gamepass function failed: {result}`)
		end
	end
end

function module.GetInfoById(Id)
	for name, element in PassesList.Information do
		if element.GiftId == Id or element.Id == Id then
			return name, element
		end
	end
	warn('Product info not found for ID:', Id)
	return nil, nil
end

function module.Gift(FromPlayer, ToPlayer, ProductId)
	GiftToList[FromPlayer] = ToPlayer

	local ProductName, ProductInfo = module.GetInfoById(ProductId)
	if not ProductInfo or ProductInfo.GiftId ~= ProductId then 
		warn("Invalid gift product ID")
		return 
	end

	if playerOwnsProduct(ToPlayer, ProductName, ProductInfo) then
		warn("Recipient already owns this item")
		return 
	end

	if ToPlayer.Parent == nil then 
		warn("Gift recipient is not in game")
		return 
	end

	warn('Prompting gift purchase')
	MarketPlaceService:PromptProductPurchase(FromPlayer, ProductId)
end

function module.GetInfoByName(Name)
	return PassesList.Information[Name]
end

function module.Buy(Player, Id)
	warn('Initiating purchase for player:', Player.Name)
	local Name, Info = module.GetInfoById(Id)
	if not Info then 
		warn("No product info found for purchase")
		return 
	end

	if playerOwnsProduct(Player, Name, Info) then
		warn("User already owns this product")
		Message:FireClient(Player, "You already own this product.", Color3.fromRGB(255, 80, 80), nil, "Error")
		return
	end

	if Info.IsGamePass then
		MarketPlaceService:PromptGamePassPurchase(Player, Id)
	else
		MarketPlaceService:PromptProductPurchase(Player, Id)
	end
end

function module.CheckOwnGamePass(Player, GamePassName)
	local GamePass = PassesList.Information[GamePassName]
	if not GamePass then return nil end
	local UserId = Player.UserId
	if MarketPlaceService:UserOwnsGamePassAsync(UserId, GamePass.Id) then return true end
	repeat task.wait() until Player:FindFirstChild("DataLoaded")

	if Player.OwnGamePasses[GamePassName] and Player.OwnGamePasses[GamePassName].Value == true then
		return true
	else
		return false
	end
end

function module.UpdateOwnGamePasses(player)
	for passName, passInfo in PassesList.Information do
		if passInfo.IsGamePass == false then continue end
		local ownGamepass = MarketPlaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
		if not ownGamepass or (player.OwnGamePasses[passName] and player.OwnGamePasses[passName].Value) then continue end
		local gamepassFunction = PassesList.GamePasses[passInfo.Id]
		if gamepassFunction then
			pcall(gamepassFunction, player)
		end
	end
end

MarketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, waspurchased)
	module.PromptGamePassPurchaseFinished(player, id, waspurchased)
end)

return module
