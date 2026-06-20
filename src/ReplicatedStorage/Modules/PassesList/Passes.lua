local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)

local Passes = {

	[3282596429] = function(Player)
		local bpData = Player.BattlepassData

		Player.OwnGamePasses['Episode 2 Pass'].Value = true
		Player.LuckySpins.Value += 5
		bpData.Premium.Value = true
		bpData.Tier.Value += 20

		return true
	end,

	[1883447034] = function(Player)	--Extra Storage
		Player.OwnGamePasses["Extra Storage"].Value = true
		Player.MaxUnits.Value = 250

		local userId = Player.UserId
		local amount = 149
		local itemType = "Pass"
		local itemId = "Exta Storage"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1882847010] = function(Player)	--VIP
		Player.OwnGamePasses["VIP"].Value = true

		local character = Player.Character
		local overhead = character and character.Head:FindFirstChild("_overhead") or false
		if overhead and Player.OwnGamePasses["Ultra VIP"] == false then
			overhead.Frame.Tag_Frame.Visible = true
			overhead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
			overhead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
			overhead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
		end

		local userId = Player.UserId
		local amount = 299
		local itemType = "Pass"
		local itemId = "VIP"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[1881161567] = function(Player)	--Shiny Hunter
		Player.OwnGamePasses["Shiny Hunter"].Value = true

		local userId = Player.UserId
		local amount = 799
		local itemType = "Pass"
		local itemId = "Shiny Hunter"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1884461005] = function(Player)	--Display 3 Units
		Player.OwnGamePasses["Display 3 Units"].Value = true

		local userId = Player.UserId
		local amount = 199
		local itemType = "Pass"
		local itemId = "Display 3 Units"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1883567052] = function(Player)	--x2 gems
		Player.OwnGamePasses["x2 Gems"].Value = true

		local userId = Player.UserId
		local amount = 999
		local itemType = "Pass"
		local itemId = "x2 Gems"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1884281000] = function(Player) -- Ultra VIP
		print("Run")
		Player.OwnGamePasses["Ultra VIP"].Value = true

		local character = Player.Character
		local overhead = character and character.Head:FindFirstChild("_overhead") or false
		if overhead then
			overhead.Frame.Tag_Frame.Visible = true
			overhead.Frame.Tag_Frame.Tag_Text.UltraVIP_Gradient.Enabled = true
			overhead.Frame.Tag_Frame.Tag_Text.Text = `[ULTRA VIP]`
			overhead.Frame.Name_Frame.Name_Text.UltraVIP_Gradient.Enabled = true
		end

		local userId = Player.UserId
		local amount = 799
		local itemType = "Pass"
		local itemId = "Ultra VIP"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1882433122] = function(Player) --2x Player XP
		Player.OwnGamePasses["2x Player XP"].Value = true

		local userId = Player.UserId
		local amount = 799
		local itemType = "Pass"
		local itemId = "2x Player XP"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1883567051] = function(Player) --2x Speed
		Player.OwnGamePasses["2x Speed"].Value = true

		local userId = Player.UserId
		local amount = 299
		local itemType = "Pass"
		local itemId = "2x Speed"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[1882781048] = function(Player) --3x Speed
		Player.OwnGamePasses["3x Speed"].Value = true

		local userId = Player.UserId
		local amount = 699
		local itemType = "Pass"
		local itemId = "3x Speed"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[1883201060] = function(Player) -- 2x Luck 
		Player.OwnGamePasses["x2 Luck"].Value = true
		local userId = Player.UserId
		local amount = 899
		local itemType = "Pass"
		local itemId = "2x Luck"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[1883231050] = function(Player)
		Player.OwnGamePasses["2x Willpower Luck"].Value = true 
		local userId = Player.UserId
		local amount = 699
		local itemType = "Pass"
		local itemId = "2x Willpower Luck"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[1882673092] = function(Player) -- 2x Raid 
		Player.OwnGamePasses["x2 Raid Luck"].Value = true
		local userId = Player.UserId
		local amount = 399
		local itemType = "Pass"
		local itemId = "2x Luck"
		local cartType = "InGame"
		local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,



	[96330340673883] = function( Player ) -- NEW premium pass 3282596429
		Player.OwnGamePasses['Premium Season Pass'].Value = true
		Player.EpisodePass.Premium.Value = true
		return true
	end,
}

return Passes
