--!strict

local UserInputService : UserInputService = game:GetService('UserInputService')
local LocalPlayer = game:GetService('Players').LocalPlayer
if not LocalPlayer then
	return
end
local Character , HumanoidRootPart , Humanoid : Humanoid

local JumpUsage = 1
local RequestCooldown = 0.15
local LastRequestTime = 0

local insert = table.insert

local HumanoidStateType = Enum.HumanoidStateType
local Freefall = HumanoidStateType.Freefall
local Jumping = HumanoidStateType.Jumping
local Landed = HumanoidStateType.Landed

local Animation = Instance.new('Animation')
Animation.AnimationId = 'rbxassetid://138346988653356'
local AnimationTrack : AnimationTrack

local VFXPart = script.VFXPart
local CachedVFX : { ParticleEmitter }
local SetVFX = function()
	if not Character then
		return
	end
	if not CachedVFX then
		local NewVFXPart = VFXPart:Clone()
		NewVFXPart.Weld.Part1 = Character.PrimaryPart
		NewVFXPart.Parent = Character
		--
		local VFXDescendants = {}
		for __ , ParticleEmitter in NewVFXPart:GetDescendants() do
			if ParticleEmitter:IsA('ParticleEmitter') then
				insert( VFXDescendants , ParticleEmitter )
			end
		end
		CachedVFX = VFXDescendants
	end
end

local DashCachedCharacter = nil
local DashCachedVFX = nil
local DashCachedVFXPart = nil
local DashBaseC0 = nil

local function resetState()
	Character = nil
	HumanoidRootPart = nil
	Humanoid = nil
	JumpUsage = 1
	CachedVFX = nil
	DashCachedCharacter = nil
	DashCachedVFX = nil
	DashCachedVFXPart = nil
	DashBaseC0 = nil

	if AnimationTrack then
		AnimationTrack:Destroy()
		AnimationTrack = nil
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	resetState()
end)

local function getDashVFX(targetCharacter)
	if not targetCharacter then
		return nil
	end

	local rootPart = targetCharacter.PrimaryPart or targetCharacter:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	if DashCachedCharacter == targetCharacter and DashCachedVFXPart and DashCachedVFXPart.Parent == targetCharacter and DashCachedVFX then
		DashCachedVFXPart.Weld.Part1 = rootPart
		return DashCachedVFX
	end

	local newVFXPart = VFXPart:Clone()
	newVFXPart.Name = VFXPart.Name .. "_Dash"
	newVFXPart.Weld.Part1 = rootPart
	DashBaseC0 = newVFXPart.Weld.C0
	newVFXPart.Parent = targetCharacter

	local emitters = {}
	for __ , ParticleEmitter in newVFXPart:GetDescendants() do
		if ParticleEmitter:IsA('ParticleEmitter') then
			insert( emitters , ParticleEmitter )
		end
	end

	DashCachedCharacter = targetCharacter
	DashCachedVFXPart = newVFXPart
	DashCachedVFX = emitters

	return emitters
end

local function emitDashDoubleJumpVFX(targetCharacter)
	local emitters = getDashVFX(targetCharacter)
	if not emitters then
		return
	end

	if DashCachedVFXPart and DashCachedVFXPart:FindFirstChild("Weld") then
		DashCachedVFXPart.Weld.C0 = (DashBaseC0 or CFrame.new()) * CFrame.new(0, 0, 1) * CFrame.Angles(math.rad(90), 0, 0)
	end

	for __ , ParticleEmitter : ParticleEmitter in emitters do
		ParticleEmitter:Emit( 20 )
	end
end

_G.EmitDashDoubleJumpVFX = emitDashDoubleJumpVFX

UserInputService.JumpRequest:Connect(function()
	if tick() - LastRequestTime < RequestCooldown then
		return
	end
	LastRequestTime = tick()
	if not ( Character or HumanoidRootPart or Humanoid ) then
		Character = LocalPlayer.Character :: Model
		HumanoidRootPart = Character.PrimaryPart
		Humanoid = Character:FindFirstChildOfClass('Humanoid') :: Humanoid
		Humanoid.StateChanged:Connect(function( Old , New )
			if New == Landed then
				JumpUsage = 1
			end
		end)
		if AnimationTrack then
			AnimationTrack:Destroy()
		end
		SetVFX()
	end
	--
	if Humanoid:GetState() :: Enum.HumanoidStateType == Freefall and JumpUsage >= 1 then
		JumpUsage -= 1
		Humanoid:ChangeState( Jumping , true )
		if not AnimationTrack then
			AnimationTrack = Humanoid:FindFirstChildOfClass('Animator'):LoadAnimation( Animation )
		end
		AnimationTrack:Play( 0.1 , 1 , 0.7 )
		--
		if CachedVFX then
			for __ , ParticleEmitter : ParticleEmitter in CachedVFX do
				ParticleEmitter:Emit( 20 )
			end
		end
	end
end)
