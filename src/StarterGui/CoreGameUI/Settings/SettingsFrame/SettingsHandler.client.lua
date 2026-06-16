local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local function ensureSoundGroup(name)
	local soundGroup = SoundService:FindFirstChild(name)
	if soundGroup and soundGroup:IsA("SoundGroup") then
		return soundGroup
	end

	if soundGroup then
		soundGroup:Destroy()
	end

	soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Parent = SoundService

	return soundGroup
end

local UI = ensureSoundGroup("UI")
local GameSound = ensureSoundGroup("Game")
local Music = ensureSoundGroup("Music")
local updateSettingEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("UpdateSetting")

local contents = script.Parent.Frame.Settings.Contents

local musicvolume = contents.Music_Volume.Contents.Bar.Contents
local gamevolume = contents.Game_Volume.Contents.Bar.Contents
local uivolume = contents.UI_Volume.Contents.Bar.Contents

local Auto_Skip_Waves = contents.Auto_Skip_Waves
local Disable_VFX = contents.Disable_VFX
local Disable_Damage_Indicator = contents.Disable_Damage_Indicator
local Skip_Summon_Animation = contents.Skip_Summon_Animation
local Reduce_Motion = contents.Reduce_Motion
local Auto_3x_Speed= contents.Auto_3x_Speed

local toggleoffposition = UDim2.fromScale(0.09, 0.5)
local toggleonposition = UDim2.fromScale(0.6, 0.5)
local sliderSyncLocks = {}
local lastPersistedValues = {}

local sliderConfigs = {
	MusicVolume = {
		SoundGroup = Music,
		Gui = musicvolume,
	},
	GameVolume = {
		SoundGroup = GameSound,
		Gui = gamevolume,
	},
	UIVolume = {
		SoundGroup = UI,
		Gui = uivolume,
	},
}

local function clampVolumeValue(value)
	return math.clamp(tonumber(value) or 0, 0, 1)
end

local function getSliderRangeScale(sliderGui)
	local knob = sliderGui.bettercircle
	return math.max(1 - knob.Size.X.Scale, 0.0001)
end

local function getSliderLeftScale(sliderGui)
	local knob = sliderGui.bettercircle
	return knob.Position.X.Scale - (knob.Size.X.Scale * knob.AnchorPoint.X)
end

local function getSliderValue(sliderGui)
	return clampVolumeValue(getSliderLeftScale(sliderGui) / getSliderRangeScale(sliderGui))
end

local function updateSliderVisuals(sliderGui, value)
	local knob = sliderGui.bettercircle
	local clampedValue = clampVolumeValue(value)
	local leftScale = clampedValue * getSliderRangeScale(sliderGui)
	local knobPositionScale = leftScale + (knob.Size.X.Scale * knob.AnchorPoint.X)
	local fillScale = math.clamp(leftScale + (knob.Size.X.Scale * 0.5), 0, 1)

	knob.Position = UDim2.new(knobPositionScale, 0, knob.Position.Y.Scale, knob.Position.Y.Offset)
	sliderGui.Bar.Size = UDim2.fromScale(fillScale, 1)
	sliderGui.Parent.Parent.Parent.Contents.Percentage.Text = string.format("%d%%", math.round(clampedValue * 100))

	return clampedValue
end

local function applySliderSetting(settingName, value, shouldPersist)
	local sliderConfig = sliderConfigs[settingName]
	if not sliderConfig then
		return
	end

	local clampedValue = clampVolumeValue(value)
	sliderSyncLocks[settingName] = true
	updateSliderVisuals(sliderConfig.Gui, clampedValue)
	sliderConfig.SoundGroup.Volume = clampedValue
	sliderSyncLocks[settingName] = false

	if shouldPersist and lastPersistedValues[settingName] ~= clampedValue then
		lastPersistedValues[settingName] = clampedValue
		updateSettingEvent:FireServer(settingName, clampedValue)
	end
end

function toggleon(gui)
	gui.Contents.Toggle.Toggle.Circle.Position = toggleonposition
	gui.Contents.Toggle.Toggle.Circle.BackgroundColor3 = Color3.fromRGB(34, 223, 119)
	gui.Contents.Toggle.Toggle.BackgroundColor3 = Color3.fromRGB(13, 115, 28)
end

function toggleoff(gui)
	gui.Contents.Toggle.Toggle.Circle.Position = toggleoffposition
	gui.Contents.Toggle.Toggle.Circle.BackgroundColor3 = Color3.fromRGB(244, 75, 83)
	gui.Contents.Toggle.Toggle.BackgroundColor3 = Color3.fromRGB(81, 24, 24)
end

function toggle(gui)
	if gui.Contents.Toggle.Toggle.BackgroundColor3 == Color3.fromRGB(13, 115, 28) then
		toggleoff(gui)
		return false
	else
		toggleon(gui)
		return true
	end
end

for settingName, sliderConfig in sliderConfigs do
	local settingValue = Player.Settings:WaitForChild(settingName)

	local function syncSliderFromSetting()
		local clampedValue = clampVolumeValue(settingValue.Value)
		applySliderSetting(settingName, clampedValue, false)
		lastPersistedValues[settingName] = clampedValue

		if math.abs(settingValue.Value - clampedValue) > 0.0001 then
			updateSettingEvent:FireServer(settingName, clampedValue)
		end
	end

	sliderConfig.Gui.bettercircle:GetPropertyChangedSignal("Position"):Connect(function()
		if sliderSyncLocks[settingName] then
			return
		end

		applySliderSetting(settingName, getSliderValue(sliderConfig.Gui), true)
	end)

	settingValue:GetPropertyChangedSignal("Value"):Connect(syncSliderFromSetting)
	syncSliderFromSetting()
end

local btnTable = {
	["VFX"] = Disable_VFX,
	['DamageIndicator'] = Disable_Damage_Indicator,
	['AutoSkip'] = Auto_Skip_Waves,
	['ReduceMotion'] = Reduce_Motion,
	['SummonSkip'] = Skip_Summon_Animation,
	["Auto3x"] = Auto_3x_Speed
}

for i,v in Player.Settings:GetChildren() do
	if v.Value and btnTable[v.Name] then
		toggleon(btnTable[v.Name])
	end
end

Disable_VFX.Contents.Toggle.Activated:Connect(function()
	--updateSettingEvent:FireServer(settingName, currentPercent)
	local result = toggle(Disable_VFX)
	updateSettingEvent:FireServer("VFX", result)
end)
Disable_Damage_Indicator.Contents.Toggle.Activated:Connect(function()
	local result = toggle(Disable_Damage_Indicator)
	updateSettingEvent:FireServer("DamageIndicator", result)
end)
Auto_Skip_Waves.Contents.Toggle.Activated:Connect(function()
	local result = toggle(Auto_Skip_Waves)
	updateSettingEvent:FireServer("AutoSkip", result)
end)
Reduce_Motion.Contents.Toggle.Activated:Connect(function()
	local result = toggle(Reduce_Motion)
	updateSettingEvent:FireServer("ReduceMotion", result)
end)
Skip_Summon_Animation.Contents.Toggle.Activated:Connect(function()
	local result = toggle(Skip_Summon_Animation)
	updateSettingEvent:FireServer("SummonSkip", result)--, currentPercent)
end)
Auto_3x_Speed.Contents.Toggle.Activated:Connect(function()
	if Player.OwnGamePasses["3x Speed"].Value then
		local result = toggle(Auto_3x_Speed)
		updateSettingEvent:FireServer("Auto3x", result)--, currentPercent)
	else
		print("no own.")
	end
end)

script.Parent.Frame.X_Close.Activated:Connect(function()
	--script.Parent.Visible = false -- note from Ace: WHO DID THIS LOL
	_G.CloseAll()
end)
