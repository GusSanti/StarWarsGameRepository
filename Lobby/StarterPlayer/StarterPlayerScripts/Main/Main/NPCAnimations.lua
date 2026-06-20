local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefaultIdle = ReplicatedStorage.DefaultNPCIdle

local NPCs = {
	workspace:WaitForChild('CodesArea'):WaitForChild('NPC'),
	workspace:WaitForChild('Prestige'):WaitForChild('NPC'),
	--workspace:WaitForChild('Challenge'):WaitForChild('ChallengeShopZone'):WaitForChild('NPC'),
	workspace:WaitForChild('PrestigeShop'):WaitForChild('NPC'),
	workspace:WaitForChild('IndexBox'):WaitForChild("NPC"),
	workspace:WaitForChild('EvolutionBox'):WaitForChild('NPC'),
	workspace:WaitForChild('Willpower'):WaitForChild('NPC'),
	workspace:WaitForChild('JunkTrader'):WaitForChild('NPC'),
	workspace:WaitForChild('CraftHitbox'):WaitForChild('NPC'),
	workspace:WaitForChild('RaidShopArea'):WaitForChild('NPC'),
	--workspace:WaitForChild("EventMain"):WaitForChild("special event"):WaitForChild("Fawn"),
}

for i,v:Model in NPCs do
	local Humanoid = v:FindFirstChild('Humanoid') or Instance.new('Humanoid', v) :: Humanoid
	local Animator = Humanoid:FindFirstChild('Animator') :: Animator
	
	if not Animator then
		Animator = Instance.new('Animator', Humanoid)
	end
	
	local track = nil :: AnimationTrack
	
	if v:FindFirstChild('Animations') and v.Animations:FindFirstChild('Idle') then
		warn(v.Name .. "Animating")
		track = Animator:LoadAnimation(v.Animations.Idle)
	else
		track = Animator:LoadAnimation(DefaultIdle) :: AnimationTrack
	end
	
	
	
	track.Looped = true
	
	track:Play()
end



return {}