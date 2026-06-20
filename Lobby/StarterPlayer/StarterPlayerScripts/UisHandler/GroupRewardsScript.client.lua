-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")

-- CONSTANTS
local GROUP_ID = 35339513

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local NewUI = PlayerGui:WaitForChild("NewUI")
local OpenFrame = NewUI:WaitForChild("GroupRewardsFrame")
local Main = OpenFrame:WaitForChild("Main")

local GroupRewardsInner = Main:FindFirstChild("Frame") or Main 
local RewardsFrame = GroupRewardsInner:WaitForChild("RewardsFrame")
local ClaimButton = GroupRewardsInner:WaitForChild("ClaimButton")

local CloseBtn = OpenFrame:WaitForChild("Closebtn")
local ExitButton = CloseBtn:WaitForChild("Btn")

local UIHandlerModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local Event = ReplicatedStorage:WaitForChild("Events"):WaitForChild("GroupRewards")
local Zone = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Zone"))
local Container = Zone.new(workspace:WaitForChild("GroupRewardsBox"):WaitForChild("JoinGroupandLikeHitbox"))

local claimedReward = Player:WaitForChild("ClaimedGroupReward")
local open = false

-- FUNCTIONS
local function UpdUi()
	if claimedReward.Value then
		ClaimButton.Interactable = false
		ClaimButton.TextLabel.Text = "Claimed"

		if Main:FindFirstChild("Claimed") then
			Main.Claimed.Visible = true
		end

		ClaimButton.Image = ClaimButton.ClaimedTexture.Value
		ClaimButton.TextLabel.Visible = false

		if RewardsFrame:FindFirstChild("GroupFrame") then
			RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		end
		if RewardsFrame:FindFirstChild("LikeFrame") then
			RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		end
	else
		local isInGroup = Player:IsInGroup(GROUP_ID)

		if Main:FindFirstChild("Claimed") then Main.Claimed.Visible = false end
		ClaimButton.Image = ClaimButton.NotClaimedTexture.Value
		ClaimButton.TextLabel.Visible = true
		ClaimButton.Interactable = true
		ClaimButton.TextLabel.Text = "Claim"

		local progressText = isInGroup and "1/1" or "0/1"
		local gradientState = isInGroup

		RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = gradientState
		RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = progressText
		RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = gradientState
		RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = progressText
	end
end

-- INIT

claimedReward.Changed:Connect(UpdUi)

ClaimButton.MouseButton1Up:Connect(function()
	if not claimedReward.Value then
		if Player:IsInGroup(GROUP_ID) then
			Event:FireServer() 
			_G.Message("Successfully", Color3.new(1, 0.666667, 0), nil, "Success")
		else
			_G.Message("You need to join the group and like the game", Color3.new(1, 0, 0), nil, "Error")
		end
	end
end)

ExitButton.Activated:Connect(function()
	open = false
	if type(_G.CloseAll) == "function" then
		_G.CloseAll()
	end
end)

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		open = true
		UpdUi()

		if type(_G.CloseAll) == "function" then
			_G.CloseAll('GroupRewardsFrame')
		end
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		open = false
		if type(_G.CloseAll) == "function" then
			_G.CloseAll()
		end
	end
end)