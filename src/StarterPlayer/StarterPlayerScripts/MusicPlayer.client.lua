local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local DEBUG_PREFIX = "[MusicPlayer][Lobby]"
local WAIT_TIMEOUT = 10

local function debugWarn(message: string, ...)
	warn((DEBUG_PREFIX .. " " .. message):format(...))
end

local function waitForChild(parent: Instance, childName: string, timeout: number?)
	local child = parent:WaitForChild(childName, timeout or WAIT_TIMEOUT)
	if not child then
		debugWarn("Missing %s under %s after %ss", childName, parent:GetFullName(), tostring(timeout or WAIT_TIMEOUT))
	end
	return child
end

local localplayer = game.Players.LocalPlayer
repeat task.wait() until localplayer:FindFirstChild("DataLoaded")
local playerSettings = waitForChild(localplayer, "Settings")

local musicFolder = waitForChild(ReplicatedStorage, "Music")
local musicTemplate = musicFolder and waitForChild(musicFolder, "MusicPlayer")
local musicPlayer = SoundService:FindFirstChild("MusicPlayer")
local MusicSoundGroup = SoundService:FindFirstChild("Music")
if not MusicSoundGroup or not MusicSoundGroup:IsA("SoundGroup") then
	debugWarn("SoundService.Music SoundGroup was missing; creating a client fallback")
	MusicSoundGroup = Instance.new("SoundGroup")
	MusicSoundGroup.Name = "Music"
	MusicSoundGroup.Parent = SoundService
end

local MusicLibrary = waitForChild(ReplicatedStorage, "MusicLibrary")
local InLobbyFolder = MusicLibrary and waitForChild(MusicLibrary, "InLobby")
local miscFolder = InLobbyFolder and waitForChild(InLobbyFolder, "Misc")
local defaultLobbySound = miscFolder and waitForChild(miscFolder, "Sound")
local DefaultLobbySoundId = defaultLobbySound and defaultLobbySound:IsA("Sound") and defaultLobbySound.SoundId or nil
local MaxVolume = musicTemplate and musicTemplate:IsA("Sound") and musicTemplate.Volume or 0.5
local ZoneModule = require(ReplicatedStorage.Modules.Zone)

local BAR_BORDER_SOUND_ID = "rbxassetid://108081931421357"
local RAID_BORDER_SOUND_ID = "rbxassetid://9046705140"

if not musicPlayer or not musicPlayer:IsA("Sound") then
	if musicTemplate and musicTemplate:IsA("Sound") then
		musicPlayer = musicTemplate:Clone()
		musicPlayer.Name = musicTemplate.Name
	else
		debugWarn("ReplicatedStorage.Music.MusicPlayer was missing; creating a client fallback Sound")
		musicPlayer = Instance.new("Sound")
		musicPlayer.Name = "MusicPlayer"
		musicPlayer.Volume = MaxVolume
	end
	musicPlayer.Parent = SoundService
end

musicPlayer.SoundGroup = MusicSoundGroup
musicPlayer.Volume = MaxVolume

local activeOverrides = {
	Bindable = nil,
	BarBorder = false,
	RaidBorder = false,
}

local function normalizeSoundId(id: number | string)
	local stringId = tostring(id)
	if not stringId:find("rbxassetid://", 1, true) then
		stringId = ("rbxassetid://%s"):format(stringId)
	end
	return stringId
end

local function getOverrideSoundId()
	if activeOverrides.Bindable then
		return activeOverrides.Bindable
	end

	if activeOverrides.RaidBorder then
		return RAID_BORDER_SOUND_ID
	end

	if activeOverrides.BarBorder then
		return BAR_BORDER_SOUND_ID
	end

	return nil
end

local function LoadNewMusic(id: number | string)
	local stringId = normalizeSoundId(id)
	local totalLoadCount = 0

	if stringId == "" or stringId == "rbxassetid://" then
		debugWarn("Cannot load an empty SoundId")
		return false
	end

	musicPlayer.SoundId = stringId

	local preloadOk, preloadErr = pcall(function()
		ContentProvider:PreloadAsync({ musicPlayer })
	end)
	if not preloadOk then
		debugWarn("PreloadAsync failed for %s: %s", stringId, tostring(preloadErr))
	end

	while not musicPlayer.IsLoaded and totalLoadCount < 10 do
		totalLoadCount += 1
		task.wait(0.5)
	end

	if musicPlayer.IsLoaded then
		return true, musicPlayer
	end

	debugWarn("Sound did not report IsLoaded after %ss, trying Play() anyway: %s", tostring(totalLoadCount * 0.5), stringId)
	return true, musicPlayer
end

local function reportPlaybackState(soundInstance: Sound)
	local groupVolume = soundInstance.SoundGroup and soundInstance.SoundGroup.Volume or nil
	debugWarn(
		"Play() did not start audio. SoundId=%s IsLoaded=%s IsPlaying=%s TimeLength=%s Volume=%s SoundGroupVolume=%s. Check if the asset is public/allowed for this experience.",
		tostring(soundInstance.SoundId),
		tostring(soundInstance.IsLoaded),
		tostring(soundInstance.IsPlaying),
		tostring(soundInstance.TimeLength),
		tostring(soundInstance.Volume),
		tostring(groupVolume)
	)
end

local function refreshMusic()
	musicPlayer:Stop()
	musicPlayer.TimePosition = 0
end

function PlayMusic()
	local MusicInstances = {}
	local currentMusicIndex = 1

	local function PreloadMusicAssets()
		local loadList = {}
		if not InLobbyFolder then
			debugWarn("Missing MusicLibrary.InLobby; lobby music cannot start")
			return
		end

		for _, sound in InLobbyFolder:GetDescendants() do
			if not sound:IsA("Sound") then
				continue
			end

			table.insert(loadList, sound)
			table.insert(MusicInstances, sound)
		end

		if #loadList > 0 then
			local preloadOk, preloadErr = pcall(function()
				ContentProvider:PreloadAsync(loadList)
			end)
			if not preloadOk then
				debugWarn("Lobby playlist preload failed: %s", tostring(preloadErr))
			end
		end
	end

	PreloadMusicAssets()

	if #MusicInstances == 0 then
		debugWarn("No Sound instances found in lobby playlist")
		return
	end

	debugWarn("Starting lobby playlist with %d track(s)", #MusicInstances)

	while true do
		local overrideSoundId = getOverrideSoundId()
		local targetSoundId
		local shouldAdvancePlaylist = false

		if overrideSoundId then
			targetSoundId = overrideSoundId
		else
			local currentSound = MusicInstances[currentMusicIndex]
			if not currentSound then
				debugWarn("Playlist index %d was nil; restarting playlist", currentMusicIndex)
				currentMusicIndex = 1
				task.wait(1)
				continue
			end

			targetSoundId = currentSound.SoundId
			shouldAdvancePlaylist = true
		end

		local successfulLoad, soundInstance = LoadNewMusic(targetSoundId)
		if successfulLoad and soundInstance then
			soundInstance.TimePosition = 0
			soundInstance:Play()
			task.wait(0.25)

			if not soundInstance.IsPlaying then
				reportPlaybackState(soundInstance)
				task.wait(10)
			end

			local loadedSoundId = soundInstance.SoundId
			local startedAt = os.clock()
			local waitDuration = soundInstance.TimeLength > 0 and soundInstance.TimeLength or 30

			repeat
				task.wait(0.25)
			until not soundInstance.IsPlaying
				or soundInstance.SoundId ~= loadedSoundId
				or os.clock() - startedAt >= waitDuration
		else
			task.wait(1)
		end

		if shouldAdvancePlaylist then
			currentMusicIndex = (currentMusicIndex < #MusicInstances and currentMusicIndex + 1) or 1
		end
	end
end

local function updateSoundVolume()
	musicPlayer.Volume = MaxVolume
	local musicVolume = playerSettings and playerSettings:FindFirstChild("MusicVolume")
	if musicVolume and musicVolume:IsA("NumberValue") then
		MusicSoundGroup.Volume = math.clamp(musicVolume.Value, 0, 1)
		if MusicSoundGroup.Volume <= 0 then
			debugWarn("MusicVolume setting is 0, so music is intentionally silent")
		end
	else
		debugWarn("Player.Settings.MusicVolume was missing; using current SoundGroup volume %s", tostring(MusicSoundGroup.Volume))
	end
end

local musicVolumeSetting = playerSettings and waitForChild(playerSettings, "MusicVolume")
if musicVolumeSetting then
	musicVolumeSetting:GetPropertyChangedSignal("Value"):Connect(updateSoundVolume)
end
updateSoundVolume()

repeat task.wait(1) until game:IsLoaded()

if DefaultLobbySoundId and musicPlayer.SoundId ~= normalizeSoundId(DefaultLobbySoundId) then
	LoadNewMusic(DefaultLobbySoundId)
end

task.spawn(PlayMusic)

local barBorders = waitForChild(workspace, "BarBorders")
if not barBorders then
	debugWarn("Zone music overrides disabled because workspace.BarBorders is missing")
	return
end

local container = barBorders:GetChildren()
local newZone = ZoneModule.new(container)
local ttime = 0.2

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local Target = localplayer:WaitForChild("PlayerGui"):WaitForChild("RaidProgress"):WaitForChild("Frame")

newZone.playerEntered:Connect(function(player)
	if player == localplayer then
		activeOverrides.BarBorder = true
		refreshMusic()
	end
end)

local Bindables = waitForChild(ReplicatedStorage, "Bindables")
local loadMusicBindable = Bindables and waitForChild(Bindables, "LoadMusic")
if loadMusicBindable and loadMusicBindable:IsA("BindableEvent") then
	loadMusicBindable.Event:Connect(function(ID)
		activeOverrides.Bindable = ID and normalizeSoundId(ID) or nil
		refreshMusic()
	end)
else
	debugWarn("Bindable override disabled because ReplicatedStorage.Bindables.LoadMusic is missing")
end

newZone.playerExited:Connect(function(player)
	if player == localplayer then
		activeOverrides.BarBorder = false
		refreshMusic()
	end
end)

local raidsBorder = waitForChild(workspace, "RaidsBorder")
local container2 = raidsBorder and waitForChild(raidsBorder, "EVIL")
if not container2 then
	debugWarn("Raid border music override disabled because workspace.RaidsBorder.EVIL is missing")
	return
end

local newZone2 = ZoneModule.new(container2)

newZone2.playerEntered:Connect(function(player)
	if player == localplayer then
		activeOverrides.RaidBorder = true
		tween(Target, ttime, { Position = UDim2.fromScale(0.5, 0.1) })
		refreshMusic()
	end
end)

newZone2.playerExited:Connect(function(player)
	if player == localplayer then
		activeOverrides.RaidBorder = false
		tween(Target, ttime, { Position = UDim2.fromScale(0.5, -0.2) })
		if DefaultLobbySoundId and not getOverrideSoundId() and musicPlayer.SoundId ~= normalizeSoundId(DefaultLobbySoundId) then
			LoadNewMusic(DefaultLobbySoundId)
		end
		refreshMusic()
	end
end)
