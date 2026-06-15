
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ItemStatsModule = require( ReplicatedStorage:WaitForChild('ItemStats') )
local GetItemModule = require( ReplicatedStorage.Modules.GetItemModel )
local BalanceConfig = require(ReplicatedStorage.BalanceConfig)
local GalacticMarketConfig = BalanceConfig.GalacticMarket or {DefaultStock = 1}
local BuyTravelingMerchantItem = ReplicatedStorage:WaitForChild('Functions'):WaitForChild('BuyTravelingMerchantItem')

local workspaceTravelingMerchant = workspace.TravelingMerchant
local ClosedSign = workspace:WaitForChild("ClosedSign")

local TravelingMerchant = workspace:WaitForChild("Merchant")
local TravelingMerchantItems = TravelingMerchant.Items
local TravelingMerchantItemSlots = TravelingMerchant.ItemSlots
local LeavingAt = TravelingMerchant.LeavingAt
local ReturnAt = TravelingMerchant.ReturnAt
local isOpen = TravelingMerchant.isOpen
local CheckCurrency = require(ReplicatedStorage.ShopSystem).CheckCurrency
local IsRoll = false

local function getMerchantStock(itemStats)
	return math.max(1, tonumber(itemStats.MerchantQuantity) or GalacticMarketConfig.DefaultStock or 1)
end


BuyTravelingMerchantItem:SetAttribute("ActiveHandlerScript", script:GetFullName())
BuyTravelingMerchantItem.OnServerInvoke = function( Player : Player , ItemName : string )
	if not TravelingMerchantItems:FindFirstChild( ItemName ) then
		return 'Invalid' , 'Item Not In Shop'
	end
	local ItemStats = ItemStatsModule[ItemName]
	local PriceType = ItemStats.Price.Type
	local PriceAmount = ItemStats.Price.Amount
	if Player[PriceType].Value < PriceAmount then
		return 'Invalid' , `Not Enough {PriceType}`
	end
	--
	local PlayerBoughtFromTravelingMerchant = Player['BoughtFromTravelingMerchant']
	local MerchantLeavingTime = PlayerBoughtFromTravelingMerchant.MerchantLeavingTime
	local ItemsBought = PlayerBoughtFromTravelingMerchant.ItemsBought
	if MerchantLeavingTime.Value ~= LeavingAt.Value then
		ItemsBought:ClearAllChildren()
		MerchantLeavingTime.Value = LeavingAt.Value
	end
	local MaxStock = getMerchantStock(ItemStats)
	local BoughtValue = ItemsBought:FindFirstChild(ItemName)
	local BoughtAmount = BoughtValue and math.max(BoughtValue.Value, 1) or 0
	if BoughtAmount >= MaxStock then
		return 'Invalid' , 'Out of Stock', 0, MaxStock
	end
	--
	Player[PriceType].Value -= PriceAmount
	local TraitPointsNumber = tonumber( ItemName:match('%d+') )
	if TraitPointsNumber ~= nil then
		Player.TraitPoint.Value += TraitPointsNumber
	else
		local SpecificItem = Player.Items[ItemName]
		
		
		if SpecificItem.Value < 0 then
			SpecificItem.Value = 0
		end
		
		SpecificItem.Value += 1	
		
	end
	--
	if not BoughtValue then
		BoughtValue = Instance.new('NumberValue')
		BoughtValue.Name = ItemName
		BoughtValue.Parent = ItemsBought
	end
	BoughtValue.Value = BoughtAmount + 1
	local RemainingStock = math.max(MaxStock - BoughtValue.Value, 0)
	return 'Valid' , `Successfully Purchased {ItemName} For {PriceAmount} {PriceType}`, RemainingStock, MaxStock
end





local insert = table.insert
local find = table.find
local floor = math.floor

local function GetSellableItems()
	
	
	
	local List = {}
	
	--insert(List, "LuckySpins")
	
	for __ , Info in ItemStatsModule do
		if Info.InMerchant then
			insert( List , Info )
		end
	end
	return List
end

local function GetNewSetOfItemStats( UniqueSeed )
	local rng = Random.new( UniqueSeed )
	local NewList = {}
	local SellableItems = GetSellableItems()
	
	while #NewList < 3 do
		local NewItemIndex = rng:NextInteger( 1 , #SellableItems )
		
		--if NewItemIndex == "LuckySpins" then
			
		--end
		
		if not find( NewList , SellableItems[NewItemIndex] ) then
			insert( NewList , SellableItems[NewItemIndex] )
		end
		task.wait()
	end
	return NewList
end

local function CalculateLeaveTime()
	local CurrentTime = os.time()
	local LeaveAt = ( floor( CurrentTime / 3600 ) * 3600 ) + ( ( ( floor( ( floor( CurrentTime / 60 ) % 60 ) / 15 ) ) + 1 ) * 15 * 60)
	return LeaveAt , LeaveAt + ( 15 * 60 )
end

local LatestUpdatedQuarter = -1
while task.wait( 1 ) do
	local TimeNow = os.time()
	local CurrentQuarter = floor( TimeNow / ( 15 * 60 ) )
	local LeaveAtTime , ReturnAtTime = CalculateLeaveTime()
	LeavingAt.Value = LeaveAtTime
	ReturnAt.Value = ReturnAtTime
	--
	local MiddleMet = TimeNow >= LeaveAtTime and TimeNow < ReturnAtTime
	if MiddleMet and isOpen.Value then
		isOpen.Value = false
		TravelingMerchantItems:ClearAllChildren()
	end
	local CSNP = ( MiddleMet and workspaceTravelingMerchant or ReplicatedStorage ) :: Instance
	if ClosedSign.Parent ~= CSNP then
		ClosedSign.Parent = CSNP
	end
	if MiddleMet then
		return
	end
	--
	if CurrentQuarter ~= LatestUpdatedQuarter then
		TravelingMerchantItems:ClearAllChildren()
		for Index , ItemStats in GetNewSetOfItemStats( CurrentQuarter ) do
			local ItemClone = GetItemModule[ItemStats.Name]
			if not ItemClone then continue end
			
			ItemClone = ItemClone:Clone()
			
			local PrimaryPart = ItemClone.PrimaryPart
			if not PrimaryPart then
				continue
			end
			PrimaryPart.CFrame = TravelingMerchantItemSlots[tostring(Index)].CFrame
			PrimaryPart.Anchored = true
			ItemClone.Parent = TravelingMerchantItems
		end
		LatestUpdatedQuarter = CurrentQuarter
		isOpen.Value = true
	end
end
