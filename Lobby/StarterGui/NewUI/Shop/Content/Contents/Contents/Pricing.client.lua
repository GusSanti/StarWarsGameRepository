-- SERVICES
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local MarketPlaceService = game:GetService('MarketplaceService')

-- VARIABLES
local PassesList = require(ReplicatedStorage.Modules.PassesList).Information
local RobuxChar = ''

-- INIT
-- script.Parent é a pasta "Contents" que contém as categorias (ex: Boosters)
for _, category in pairs(script.Parent:GetChildren()) do
	if category:IsA('Frame') then
		for _, pass in pairs(category:GetChildren()) do
			if pass:IsA('Frame') then
				if PassesList[pass.Name] then
					local dat = nil

					if PassesList[pass.Name].IsGamePass then
						dat = MarketPlaceService:GetProductInfo(PassesList[pass.Name].Id, Enum.InfoType.GamePass)
					else
						dat = MarketPlaceService:GetProductInfo(PassesList[pass.Name].Id, Enum.InfoType.Product)
					end

					-- Pegando o texto direto da label "Robux" da nova estrutura
					local priceLabel = pass:FindFirstChild("Robux")
					if priceLabel and not priceLabel:IsA("TextLabel") then
						priceLabel = priceLabel:FindFirstChildOfClass("TextLabel") or priceLabel
					end

					if priceLabel and dat and dat.PriceInRobux then
						if not string.find(priceLabel.Text, 'Owned') then
							priceLabel.Text = RobuxChar .. tostring(dat.PriceInRobux)
						end
					end
				end
			end
		end
	end 
end