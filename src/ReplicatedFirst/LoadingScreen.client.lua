local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	_G.GameLoaded = true
	_G.LoadingScreenComplete = true
	script:Destroy()
	return
end

local StarterGui = game:GetService("StarterGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local LoadingGui = TeleportService:GetArrivingTeleportGui() or script:WaitForChild("LoadingGui")
local WorldImage = LoadingGui:WaitForChild("WorldImage")
local Main = WorldImage:WaitForChild("Main")
local TeleportInfo = Main:WaitForChild("TeleportInfo")
local LoadingTextLabel = WorldImage:WaitForChild("LoadingText")
local SkipButton = WorldImage:WaitForChild("SkipButton")

local ForceLoad = false
local Finished = false
local AssetsLoaded = false
local Controls = nil

local function SetChatEnabled(enabled)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, enabled)
	end)
end

local function GetControls()
	if Controls then
		return Controls
	end

	local playerScripts = Player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local playerModuleScript = playerScripts:FindFirstChild("PlayerModule")
	if not playerModuleScript then
		return nil
	end

	local success, playerModule = pcall(require, playerModuleScript)
	if not success then
		warn("Failed to load PlayerModule for loading screen controls:", playerModule)
		return nil
	end

	if type(playerModule.GetControls) ~= "function" then
		return nil
	end

	Controls = playerModule:GetControls()
	return Controls
end

local function SetControlsEnabled(enabled)
	local controls = GetControls()
	if not controls then
		return
	end

	pcall(function()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function GetReadyCharacterParts()
	local character = Player.Character
	if not character or character.Parent ~= Workspace then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return nil, nil, nil
	end

	return character, humanoid, rootPart
end

local function IsCharacterReadyToWalk()
	local character, humanoid, rootPart = GetReadyCharacterParts()
	if not character or not humanoid or not rootPart then
		return false, nil
	end

	if humanoid.Health <= 0 then
		return false, nil
	end

	if rootPart.Anchored or humanoid.WalkSpeed <= 0 then
		return false, nil
	end

	local currentCamera = Workspace.CurrentCamera
	if not currentCamera then
		return false, nil
	end

	local cameraSubject = currentCamera.CameraSubject
	if cameraSubject ~= humanoid and not (cameraSubject and cameraSubject:IsDescendantOf(character)) then
		return false, nil
	end

	return true, rootPart
end

local function WaitForGameplayReady()
	local stableChecks = 0
	local lastPosition = nil
	local timedOutAt = os.clock() + 20
	local requiredStableChecks = 6

	repeat
		if Finished then
			return false
		end

		local isReady, rootPart = IsCharacterReadyToWalk()
		if isReady then
			local currentPosition = rootPart.Position
			if lastPosition and (currentPosition - lastPosition).Magnitude <= 0.15 then
				stableChecks += 1
			else
				stableChecks = 0
			end

			lastPosition = currentPosition
		else
			stableChecks = 0
			lastPosition = nil
		end

		LoadingTextLabel.Text = "Finalizing Spawn..."
		task.wait(0.1)
	until (
		game:IsLoaded()
			and Player:FindFirstChild("DataLoaded")
			and (AssetsLoaded or ForceLoad)
			and stableChecks >= requiredStableChecks
	) or os.clock() >= timedOutAt

	return not Finished
end

SetChatEnabled(false)

task.spawn(function()
	local deadline = os.clock() + 10

	while not Finished and os.clock() < deadline do
		local controls = GetControls()
		if controls then
			SetControlsEnabled(false)
			return
		end

		task.wait(0.1)
	end
end)

local function LoadIntoGame()
	if Finished then
		return
	end

	Finished = true
	
	task.wait(3)

	local UIHandler = require(
		ReplicatedStorage
			:WaitForChild("Modules")
			:WaitForChild("Client")
			:WaitForChild("UIHandler")
	)

	UIHandler.Transition()

	SetChatEnabled(true)
	SetControlsEnabled(true)

	Debris:AddItem(LoadingGui, 2)

	print("Setting loaded as true!")

	_G.LoadingScreenComplete = true
end

local function PreloadOneByOne(root)
	local assets = root:GetDescendants()
	local totalAssets = #assets

	for index, asset in ipairs(assets) do
		if ForceLoad or Finished then
			return false
		end

		LoadingTextLabel.Text = `Loading Assets {index}/{totalAssets}`

		local success, err = pcall(function()
			ContentProvider:PreloadAsync({ asset })
		end)

		if not success then
			warn("Failed to preload asset:", asset:GetFullName(), err)
		end

		task.wait()
	end

	return true
end

LoadingGui.Parent = PlayerGui
_G.GameLoaded = true

task.spawn(function()
	task.wait(10)

	if Finished or LoadingGui.Parent == nil then
		return
	end

	SkipButton.Visible = true

	SkipButton.MouseButton1Down:Connect(function()
		if Finished then
			return
		end

		ForceLoad = true
		SkipButton.Visible = false
		LoadingTextLabel.Text = "Finishing Setup..."
	end)
end)

task.spawn(function()
	task.wait(10)

	if not Finished then
		SetChatEnabled(true)
	end
end)

PreloadOneByOne(LoadingGui)

task.wait()

ReplicatedFirst:RemoveDefaultLoadingScreen()

PreloadOneByOne(workspace)

AssetsLoaded = true

local dotCounter = 1
local dots = {
	".",
	"..",
	"..."
}

repeat
	LoadingTextLabel.Text = `Loading{dots[dotCounter]}`
	dotCounter = dotCounter < 3 and dotCounter + 1 or 1

	task.wait(0.5)
until ForceLoad or Finished or (
	game:IsLoaded()
		and Player:FindFirstChild("DataLoaded")
		and AssetsLoaded
)

if ForceLoad or Finished then
	LoadingTextLabel.Text = "Finishing Setup..."
end

if not WaitForGameplayReady() or Finished then
	return
end

LoadIntoGame()
