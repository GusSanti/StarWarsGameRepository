local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
	return
end

local playerGui = player:WaitForChild("PlayerGui")
local cameraConnection = nil

local blockerGui = Instance.new("ScreenGui")
blockerGui.Name = "MobilePortraitBlocker"
blockerGui.DisplayOrder = 100000
blockerGui.IgnoreGuiInset = true
blockerGui.ResetOnSpawn = false
blockerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
blockerGui.Enabled = false
blockerGui.Parent = playerGui

local blockerFrame = Instance.new("Frame")
blockerFrame.Name = "Blocker"
blockerFrame.Size = UDim2.fromScale(1, 1)
blockerFrame.BackgroundColor3 = Color3.fromRGB(10, 7, 18)
blockerFrame.BackgroundTransparency = 0.15
blockerFrame.BorderSizePixel = 0
blockerFrame.Active = true
blockerFrame.Parent = blockerGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromScale(0.8, 0.12)
title.BackgroundTransparency = 1
title.Text = "Rotate your device"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.FredokaOne
title.Parent = blockerFrame

local description = Instance.new("TextLabel")
description.Name = "Description"
description.AnchorPoint = Vector2.new(0.5, 0.5)
description.Position = UDim2.fromScale(0.5, 0.54)
description.Size = UDim2.fromScale(0.78, 0.12)
description.BackgroundTransparency = 1
description.Text = "This game is only available in landscape mode."
description.TextColor3 = Color3.fromRGB(222, 222, 222)
description.TextScaled = true
description.Font = Enum.Font.GothamBold
description.Parent = blockerFrame

local function applyLandscapeLock()
	pcall(function()
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)

	pcall(function()
		StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)
end

local function isPortrait()
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	local viewportSize = camera.ViewportSize
	return viewportSize.X > 0 and viewportSize.Y > viewportSize.X
end

local function updateOrientationState()
	applyLandscapeLock()
	blockerGui.Enabled = isPortrait()
end

local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateOrientationState)
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera()
	updateOrientationState()
end)

pcall(function()
	playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(updateOrientationState)
end)

bindCamera()
updateOrientationState()
