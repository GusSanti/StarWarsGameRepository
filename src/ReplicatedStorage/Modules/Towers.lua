local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CollisionGroup = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CollisionGroup"))
local TraitModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Traits"))
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local UnitsFollowFolder = workspace:WaitForChild("UnitsFollowFolder")
local LocalPlayer = Players.LocalPlayer

local Towers = {}
Towers.__index = Towers

local SLOT_PART_SIZE = Vector3.new(1, 1, 1)
local SLOT_HEIGHT_OFFSET = -1.6
local SLOT_ARC_RADIANS = math.rad(150)
local SLOT_RADIUS = 5
local FOLLOW_RESPONSIVENESS = 6
local FOLLOW_MAX_VELOCITY = 16
local FOLLOW_MAX_FORCE = 45000
local ORIENTATION_RESPONSIVENESS = 10
local JUMP_ANIMATION_DURATION = 0.35
local TELEPORT_SNAP_DISTANCE = 10

local ANIMATION_CANDIDATES = {
	Idle = { "Idle", "idle" },
	Run = { "Run", "run", "Walk", "walk" },
	Jump = { "Jump", "jump", "Jumping", "jumping", "Fall", "fall", "Freefall", "freefall", "FreeFall" },
}

local DEFAULT_ANIMATION_IDS = {
	Jump = "rbxassetid://125750702",
}

local function getSlotOffset(slot: number, totalSlots: number)
	totalSlots = math.max(totalSlots or 1, 1)
	slot = math.clamp(slot or 1, 1, totalSlots)

	if totalSlots == 1 then
		return CFrame.new(0, SLOT_HEIGHT_OFFSET, SLOT_RADIUS)
	end

	local alpha = (slot - 1) / (totalSlots - 1)
	local angle = -SLOT_ARC_RADIANS / 2 + SLOT_ARC_RADIANS * alpha

	return CFrame.new(
		math.sin(angle) * SLOT_RADIUS,
		SLOT_HEIGHT_OFFSET,
		math.cos(angle) * SLOT_RADIUS
	)
end

local function getModelRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getAnimator(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		return humanoid:FindFirstChildOfClass("Animator") or humanoid
	end

	local animationController = model:FindFirstChildOfClass("AnimationController")
	if animationController then
		return animationController:FindFirstChildOfClass("Animator") or animationController
	end

	return nil
end

local function prepareModelPhysics(model: Model)
	for _, object in model:GetDescendants() do
		if not object:IsA("BasePart") then continue end

		object.Anchored = false
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.Massless = true
	end
end

local function findAnimation(animationFolder: Instance, candidates: { string }): Animation?
	local acceptedNames = {}
	for _, candidateName in candidates do
		acceptedNames[string.lower(candidateName)] = true
	end

	for _, child in animationFolder:GetChildren() do
		local childName = string.lower(child.Name)
		if acceptedNames[childName] then
			if child:IsA("Animation") then
				return child
			end

			local nestedAnimation = child:FindFirstChildWhichIsA("Animation", true)
			if nestedAnimation then
				return nestedAnimation
			end
		end
	end

	for _, descendant in animationFolder:GetDescendants() do
		if descendant:IsA("Animation") and acceptedNames[string.lower(descendant.Name)] then
			return descendant
		end
	end

	return nil
end

local function createDefaultAnimation(model: Model, animRequestName: string): Animation?
	local animationId = DEFAULT_ANIMATION_IDS[animRequestName]
	if not animationId then return nil end

	local animation = Instance.new("Animation")
	animation.Name = `Default{animRequestName}`
	animation.AnimationId = animationId
	animation.Parent = model

	return animation
end

function Towers.new(towerValue, player: Player, slot: number, traitName: string, shiny: boolean, totalSlots: number?)
	local name = towerValue.Name
	local newcharacter = player.Character or player.CharacterAdded:Wait()
	local humanoid = newcharacter:WaitForChild("Humanoid")
	local humanoidRootPart = newcharacter:WaitForChild("HumanoidRootPart")
	local tower = GetUnitModel[name]
	if tower then
		tower = tower:Clone()
	else
		print('Unable to find ', name)
		return
	end

	local towerRootPart = getModelRoot(tower)
	if not towerRootPart then
		tower:Destroy()
		warn("Unable to find root part for lobby follower", name)
		return
	end

	tower.PrimaryPart = towerRootPart
	prepareModelPhysics(tower)
	pcall(function()
		CollisionGroup:SetModel(tower, "Tower")
	end)

	local slotPart = Instance.new("Part")
	slotPart.Name = `LobbyTowerFollowSlot_{slot}`
	slotPart.Size = SLOT_PART_SIZE
	slotPart.Transparency = 1
	slotPart.CanCollide = false
	slotPart.CanTouch = false
	slotPart.CanQuery = false
	slotPart.Massless = true
	slotPart.Anchored = false
	slotPart.CFrame = humanoidRootPart.CFrame * getSlotOffset(slot, totalSlots or 1)
	slotPart.Parent = newcharacter

	local slotMotor = Instance.new("Motor6D")
	slotMotor.Name = "LobbyTowerFollowMotor"
	slotMotor.Part0 = humanoidRootPart
	slotMotor.Part1 = slotPart
	slotMotor.C0 = getSlotOffset(slot, totalSlots or 1)
	slotMotor.Parent = humanoidRootPart

	local towerAttachment = Instance.new("Attachment")
	towerAttachment.Name = "LobbyTowerFollowAttachment"
	towerAttachment.Parent = towerRootPart

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "LobbyTowerTargetAttachment"
	targetAttachment.Parent = slotPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "LobbyTowerAlignPosition"
	alignPosition.Attachment0 = towerAttachment
	alignPosition.Attachment1 = targetAttachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.MaxForce = FOLLOW_MAX_FORCE
	alignPosition.MaxVelocity = FOLLOW_MAX_VELOCITY
	alignPosition.Responsiveness = FOLLOW_RESPONSIVENESS
	alignPosition.RigidityEnabled = false
	alignPosition.Parent = towerRootPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "LobbyTowerAlignOrientation"
	alignOrientation.Attachment0 = towerAttachment
	alignOrientation.Attachment1 = targetAttachment
	alignOrientation.MaxTorque = 100000
	alignOrientation.MaxAngularVelocity = 30
	alignOrientation.Responsiveness = ORIENTATION_RESPONSIVENESS
	alignOrientation.RigidityEnabled = false
	alignOrientation.Parent = towerRootPart

	local self = setmetatable({
		Player = player,
		Character = newcharacter,
		Humanoid = humanoid,
		HumanoidRootPart = humanoidRootPart,
		Tower = tower,
		TowerRootPart = towerRootPart,
		TowerName = name,
		Slot = slot,
		TotalSlots = totalSlots or 1,
		SlotPart = slotPart,
		SlotMotor = slotMotor,
		TowerAttachment = towerAttachment,
		TargetAttachment = targetAttachment,
		AlignPosition = alignPosition,
		AlignOrientation = alignOrientation,
		ShouldAnimate = player == LocalPlayer,
		CurrentAnimName = nil,
		CurrentAnimTrack = nil,
		Connections = {},
		Animations = {},
		JumpAnimationUntil = 0,
		Animator = getAnimator(tower),
	}, Towers)

	TraitModule.AddVisualAura(tower, traitName)
	self.Connections["Trait"] = towerValue:GetAttributeChangedSignal("Trait"):Connect(function()
		TraitModule.AddVisualAura(tower, towerValue:GetAttribute("Trait"))
	end)

	tower.Parent = UnitsFollowFolder
	tower:PivotTo(humanoidRootPart.CFrame)
	self:Init()
	return self
end

function Towers:Init()
	self.Connections["TeleportRecovery"] = RunService.Heartbeat:Connect(function()
		self:RecoverFromTeleport()
	end)

	if self.ShouldAnimate then
		self.Connections["Jumping"] = self.Humanoid.Jumping:Connect(function(isJumping)
			if isJumping then
				self.JumpAnimationUntil = os.clock() + JUMP_ANIMATION_DURATION
				self:UpdateAnimation()
			end
		end)

		self.Connections["StateChanged"] = self.Humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall then
				self.JumpAnimationUntil = os.clock() + JUMP_ANIMATION_DURATION
				self:UpdateAnimation()
			end
		end)

		self.Connections["Animation"] = RunService.RenderStepped:Connect(function()
			self:UpdateAnimation()
		end)
		self:UpdateAnimation()
	end
end

function Towers:RecoverFromTeleport()
	if not self.Tower or not self.TowerRootPart or not self.SlotPart then return end
	if not self.Tower.Parent or not self.SlotPart.Parent then return end

	local distanceFromTarget = (self.TowerRootPart.Position - self.SlotPart.Position).Magnitude
	if distanceFromTarget < TELEPORT_SNAP_DISTANCE then return end

	self.Tower:PivotTo(self.SlotPart.CFrame)
	self.TowerRootPart.AssemblyLinearVelocity = Vector3.zero
	self.TowerRootPart.AssemblyAngularVelocity = Vector3.zero
end

function Towers:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end

	for _, track in self.Animations do
		track:Stop()
		track:Destroy()
	end

	if self.Tower then
		self.Tower:Destroy()
	end

	if self.SlotMotor then
		self.SlotMotor:Destroy()
	end

	if self.SlotPart then
		self.SlotPart:Destroy()
	end
end

function Towers:UpdateAnimation()
	local animRequestName
	local animSpeed = 1
	local distanceFromTarget = 0

	if self.TowerRootPart and self.SlotPart then
		distanceFromTarget = (self.TowerRootPart.Position - self.SlotPart.Position).Magnitude
	end

	local state = self.Humanoid:GetState()
	if os.clock() <= self.JumpAnimationUntil or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		animRequestName = "Jump"
	elseif self.Humanoid.MoveDirection.Magnitude > 0.05 or distanceFromTarget > 0.75 then
		animRequestName = "Run"
		animSpeed = math.max(self.Humanoid.WalkSpeed / 16, 0.75)
	else
		animRequestName = "Idle"
	end

	if self.CurrentAnimName == animRequestName then return end
	if not self.Tower or not self.Animator then return end

	if not self.Animations[animRequestName] then
		local animationFolder = self.Tower:FindFirstChild("Animations")
		local candidates = ANIMATION_CANDIDATES[animRequestName] or { animRequestName }
		local anim = animationFolder and findAnimation(animationFolder, candidates) or nil
		anim = anim or createDefaultAnimation(self.Tower, animRequestName)

		if anim then
			self.Animations[animRequestName] = self.Animator:LoadAnimation(anim)
		end
	end

	local track = self.Animations[animRequestName]
	if track then
		if self.CurrentAnimTrack and self.CurrentAnimTrack ~= track then
			self.CurrentAnimTrack:Stop()
		end
		self.CurrentAnimTrack = track
		self.CurrentAnimName = animRequestName
		track:Play(nil, nil, animSpeed)
	end
end

function Towers:UpdateSlot(newSlot, totalSlots)
	self.Slot = newSlot
	self.TotalSlots = totalSlots or self.TotalSlots

	if self.SlotMotor then
		self.SlotMotor.C0 = getSlotOffset(self.Slot, self.TotalSlots)
	end

	if self.SlotPart then
		self.SlotPart.Name = `LobbyTowerFollowSlot_{newSlot}`
	end

	if self.Tower then
		self.Tower.Parent = UnitsFollowFolder
	end
end

return Towers
