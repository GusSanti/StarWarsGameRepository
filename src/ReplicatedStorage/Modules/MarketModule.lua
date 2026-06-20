local PassesList = require(script.Parent.PassesList)
local MarketInfo = PassesList.Information

local function getProductId(productName)
	local info = MarketInfo[productName]
	return info and info.Id or nil
end

return {
	Gems = {
		{
			Name = "Mini",
			Value = 50,
			Price = 50,
			Discount = "",
			ProductID = getProductId("Mini Pack"),
			ImageID = "http://www.roblox.com/asset/?id=107010136394116"
		},
		{
			Name = "Small",
			Value = 250,
			Price = 220,
			Discount = "+14% More",
			ProductID = getProductId("Small Pack"),
			ImageID = "http://www.roblox.com/asset/?id=89345973827883"
		},
		{
			Name = "Medium",
			Value = 475,
			Price = 375,
			Discount = "+27% More",
			ProductID = getProductId("Medium Pack"),
			ImageID = "http://www.roblox.com/asset/?id=89345973827883"
		},
		{
			Name = "Large",
			Value = 975,
			Price = 600,
			Discount = "+54% More",
			ProductID = getProductId("Large Pack"),
			ImageID = "http://www.roblox.com/asset/?id=87821053230387"
		},
		{
			Name = "Huge",
			Value = 2000,
			Price = 999,
			Discount = "+100% More",
			ProductID = getProductId("Huge Pack"),
			ImageID = "http://www.roblox.com/asset/?id=89442390259942"
		},
		{
			Name = "Massive",
			Value = 5000,
			Price = 1999,
			Discount = "+150% More",
			ProductID = getProductId("Massive Pack"),
			ImageID = "http://www.roblox.com/asset/?id=135473840229986"
		},
		{
			Name = "Colossal",
			Value = 10000,
			Price = 3499,
			Discount = "+200% More",
			ProductID = getProductId("Colossal Pack"),
			ImageID = "http://www.roblox.com/asset/?id=97040419437626"
		},
    },
    Credits = {
        {
            Name = "Mini",
            Value = 50,
            Price = 50,
            Discount = "",
            ProductID = getProductId("Mini Pack"),
            ImageID = "http://www.roblox.com/asset/?id=107010136394116"
        },
        {
            Name = "Small",
            Value = 250,
            Price = 220,
            Discount = "+14% More",
            ProductID = getProductId("Small Pack"),
            ImageID = "http://www.roblox.com/asset/?id=89345973827883"
        },
        {
            Name = "Medium",
            Value = 475,
            Price = 375,
            Discount = "+27% More",
            ProductID = getProductId("Medium Pack"),
            ImageID = "http://www.roblox.com/asset/?id=89345973827883"
        },
        {
            Name = "Large",
            Value = 975,
            Price = 600,
            Discount = "+54% More",
            ProductID = getProductId("Large Pack"),
            ImageID = "http://www.roblox.com/asset/?id=87821053230387"
        },
    },
	Items = {
		{
			Name = "Lucky Crystal",
			Value = 1,
			ProductID = getProductId("Lucky Crystal")
		},
		{
			Name = "Fortunate Crystal",
			Value = 1,
			ProductID = getProductId("Fortunate Crystal")
		}
	},
	TraitPoint = {
		{
			Name = "1",
			Value = 1,
			ProductID = getProductId("LuckyWillpower")
		}
	},
	Packs = {
		{
			Name = "Starter Pack",
			ProductID = getProductId("Starter Pack"),
		},
	},
}
