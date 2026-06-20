local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local module = {}
local sounds = {}

local function getGameSoundGroup()
	local soundGroup = SoundService:FindFirstChild("Game")
	if soundGroup and soundGroup:IsA("SoundGroup") then
		return soundGroup
	end

	soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = "Game"
	soundGroup.Parent = SoundService

	return soundGroup
end

function module.playSound(sound: Sound, timeShouldRepeatAt: number)
	local soundRef = sound:Clone()
	table.insert(sounds, soundRef)
	soundRef.Parent = SoundService
	soundRef.SoundGroup = getGameSoundGroup()
	soundRef:Play()

	if timeShouldRepeatAt then
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not soundRef or not soundRef.Parent then
				connection:Disconnect()
				return
			end

			if soundRef.TimePosition >= timeShouldRepeatAt then
				soundRef.TimePosition = 0
				soundRef:Play()
			end
		end) 
	end
end

function module.stopAllSounds()
	for i,v in sounds do
		v:Destroy()
	end
end

return module
