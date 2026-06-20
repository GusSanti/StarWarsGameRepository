local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local updateSettingEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UpdateSetting")

repeat task.wait() until LocalPlayer:FindFirstChild("DataLoaded")

local PlayerSettings = LocalPlayer:WaitForChild("Settings")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

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

local SoundGroups = {
	Music = ensureSoundGroup("Music"),
	Game = ensureSoundGroup("Game"),
	UI = ensureSoundGroup("UI"),
}

local VolumeSettings = {
	MusicVolume = "Music",
	GameVolume = "Game",
	UIVolume = "UI",
}

local function clampVolumeValue(value)
	return math.clamp(tonumber(value) or 0, 0, 1)
end

local function syncVolumeSetting(settingName)
	local setting = PlayerSettings:FindFirstChild(settingName)
	if not setting or not setting:IsA("NumberValue") then
		return
	end

	local clampedValue = clampVolumeValue(setting.Value)
	SoundGroups[VolumeSettings[settingName]].Volume = clampedValue

	if math.abs(setting.Value - clampedValue) > 0.0001 then
		updateSettingEvent:FireServer(settingName, clampedValue)
	end
end

local function classifySoundGroup(sound)
	if sound.Name == "MusicPlayer" then
		return SoundGroups.Music
	end

	if sound:IsDescendantOf(PlayerGui) then
		return SoundGroups.UI
	end

	if sound:IsDescendantOf(workspace) then
		return SoundGroups.Game
	end

	if sound:IsDescendantOf(SoundService) then
		if sound.SoundGroup and SoundGroups[sound.SoundGroup.Name] == sound.SoundGroup then
			return sound.SoundGroup
		end

		local lowerName = string.lower(sound.Name)
		local lowerPath = string.lower(sound:GetFullName())
		if lowerName == "hudsfx" or string.find(lowerPath, "newsfx", 1, true) then
			return SoundGroups.UI
		end

		return SoundGroups.Game
	end

	return nil
end

local function routeSound(sound)
	if not sound:IsA("Sound") then
		return
	end

	local targetGroup = classifySoundGroup(sound)
	if targetGroup and sound.SoundGroup ~= targetGroup then
		sound.SoundGroup = targetGroup
	end
end

local function routeExistingSounds(root)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Sound") then
			routeSound(descendant)
		end
	end
end

local function watchRoot(root)
	root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Sound") then
			routeSound(descendant)
		end
	end)
end

for settingName in VolumeSettings do
	local setting = PlayerSettings:WaitForChild(settingName)
	setting:GetPropertyChangedSignal("Value"):Connect(function()
		syncVolumeSetting(settingName)
	end)
	syncVolumeSetting(settingName)
end

routeExistingSounds(PlayerGui)
routeExistingSounds(workspace)
routeExistingSounds(SoundService)

watchRoot(PlayerGui)
watchRoot(workspace)
watchRoot(SoundService)
