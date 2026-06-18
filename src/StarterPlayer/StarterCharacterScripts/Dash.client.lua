local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local DASH_ACTION = "PlayerDash"
local DASH_COOLDOWN = 1
local DASH_DURATION = 0.18
local DASH_SPEED = 80
local DASH_FORCE = 100000
local DASH_SHARD_TEXTURE = "rbxassetid://8599882518"
local DASH_SHARD_BURST = 12
local DASH_SHARD_LIFETIME = NumberRange.new(0.18, 0.3)
local DASH_SHARD_SPEED = NumberRange.new(14, 22)
local DASH_SHARD_SPREAD = Vector2.new(16, 16)

local lastDashTime = 0

local function emitDashVFX(character)
	if typeof(_G.EmitDashDoubleJumpVFX) == "function" then
		_G.EmitDashDoubleJumpVFX(character)
	end
end

local function getFlatDirection(vector)
	local flatDirection = Vector3.new(vector.X, 0, vector.Z)
	if flatDirection.Magnitude <= 0.05 then
		return nil
	end

	return flatDirection.Unit
end

local function getDashDirection(character, humanoid)
	local moveDirection = getFlatDirection(humanoid.MoveDirection)
	if moveDirection then
		return moveDirection
	end

	local camera = workspace.CurrentCamera
	local cameraDirection = camera and getFlatDirection(camera.CFrame.LookVector)
	if cameraDirection then
		return cameraDirection
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	return rootPart and getFlatDirection(rootPart.CFrame.LookVector) or Vector3.new(0, 0, -1)
end

local function emitDashShards(rootPart, dashDirection)
	local shardOrigin = rootPart.Position - (dashDirection * 1.5)
	local shardAttachment = Instance.new("Attachment")
	shardAttachment.Name = "DashShardAttachment"
	shardAttachment.CFrame = rootPart.CFrame:ToObjectSpace(CFrame.lookAt(shardOrigin, shardOrigin + dashDirection))
	shardAttachment.Parent = rootPart

	local shardEmitter = Instance.new("ParticleEmitter")
	shardEmitter.Name = "DashShardEmitter"
	shardEmitter.Texture = DASH_SHARD_TEXTURE
	shardEmitter.EmissionDirection = Enum.NormalId.Back
	shardEmitter.Lifetime = DASH_SHARD_LIFETIME
	shardEmitter.Speed = DASH_SHARD_SPEED
	shardEmitter.Rate = 0
	shardEmitter.Rotation = NumberRange.new(0, 360)
	shardEmitter.RotSpeed = NumberRange.new(-240, 240)
	shardEmitter.SpreadAngle = DASH_SHARD_SPREAD
	shardEmitter.LightEmission = 0.2
	shardEmitter.LightInfluence = 0
	shardEmitter.Drag = 4
	shardEmitter.VelocityInheritance = 0.1
	shardEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	shardEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.75, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	shardEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 245, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 210, 255)),
	})
	shardEmitter.Parent = shardAttachment
	shardEmitter:Emit(DASH_SHARD_BURST)

	Debris:AddItem(shardAttachment, DASH_SHARD_LIFETIME.Max + 0.2)
end

local function dash()
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local now = os.clock()
	if now - lastDashTime < DASH_COOLDOWN then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or humanoid.Health <= 0 or humanoid.Sit then
		return
	end

	lastDashTime = now

	local oldDashVelocity = rootPart:FindFirstChild("DashVelocity")
	if oldDashVelocity then
		oldDashVelocity:Destroy()
	end

	local dashDirection = getDashDirection(character, humanoid)
	if dashDirection.Magnitude <= 0 then
		return
	end

	local dashVelocity = Instance.new("BodyVelocity")
	dashVelocity.Name = "DashVelocity"
	dashVelocity.MaxForce = Vector3.new(DASH_FORCE, 0, DASH_FORCE)
	dashVelocity.P = DASH_FORCE
	dashVelocity.Velocity = dashDirection * DASH_SPEED
	dashVelocity.Parent = rootPart
	emitDashShards(rootPart, dashDirection)

	emitDashVFX(character)

	Debris:AddItem(dashVelocity, DASH_DURATION)
end

ContextActionService:BindAction(DASH_ACTION, function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		dash()
	end

	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2)

ContextActionService:SetTitle(DASH_ACTION, "Dash")
ContextActionService:SetPosition(DASH_ACTION, UDim2.new(1, -110, 1, -210))
