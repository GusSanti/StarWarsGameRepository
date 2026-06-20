local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local offsetVal =  1.149 - 1.194
local fadeOutTime = 0.2
local fadeInTime = 0.3
local intervalDelay = 0.3
local numberSwitchTime = 1
local spotlightScaleMultiplier = 1.06
local guideOverlayTransparency = 0.25

local module = {}

local function getOrCreateNumberValue(parent, name, value)
	local existingValue = parent:FindFirstChild(name)
	if existingValue and existingValue:IsA("NumberValue") then
		return existingValue
	end

	local newValue = Instance.new("NumberValue")
	newValue.Name = name
	newValue.Value = value
	newValue.Parent = parent
	return newValue
end

local function cacheOriginalPosition(obj: GuiBase2d)
	getOrCreateNumberValue(obj, "OriginalPositionX", obj.Position.X.Scale)
	getOrCreateNumberValue(obj, "OriginalPositionY", obj.Position.Y.Scale)
	getOrCreateNumberValue(obj, "OriginalPositionXOffset", obj.Position.X.Offset)
	getOrCreateNumberValue(obj, "OriginalPositionYOffset", obj.Position.Y.Offset)
end

local function getOriginalPosition(obj: GuiBase2d)
	cacheOriginalPosition(obj)

	return UDim2.new(
		obj.OriginalPositionX.Value,
		obj.OriginalPositionXOffset.Value,
		obj.OriginalPositionY.Value,
		obj.OriginalPositionYOffset.Value
	)
end

local function cacheOriginalSize(obj: GuiObject)
	getOrCreateNumberValue(obj, "OriginalSizeXScale", obj.Size.X.Scale)
	getOrCreateNumberValue(obj, "OriginalSizeXOffset", obj.Size.X.Offset)
	getOrCreateNumberValue(obj, "OriginalSizeYScale", obj.Size.Y.Scale)
	getOrCreateNumberValue(obj, "OriginalSizeYOffset", obj.Size.Y.Offset)
end

local function getOriginalSize(obj: GuiObject)
	cacheOriginalSize(obj)

	return UDim2.new(
		obj.OriginalSizeXScale.Value,
		obj.OriginalSizeXOffset.Value,
		obj.OriginalSizeYScale.Value,
		obj.OriginalSizeYOffset.Value
	)
end

local function setContainerScale(obj: GuiObject, multiplier: number)
	local originalSize = getOriginalSize(obj)
	local originalPosition = getOriginalPosition(obj)

	local newSize = UDim2.new(
		originalSize.X.Scale * multiplier,
		math.round(originalSize.X.Offset * multiplier),
		originalSize.Y.Scale * multiplier,
		math.round(originalSize.Y.Offset * multiplier)
	)

	local xScaleShift = (newSize.X.Scale - originalSize.X.Scale) * obj.AnchorPoint.X
	local yScaleShift = (newSize.Y.Scale - originalSize.Y.Scale) * obj.AnchorPoint.Y
	local xOffsetShift = math.round((newSize.X.Offset - originalSize.X.Offset) * obj.AnchorPoint.X)
	local yOffsetShift = math.round((newSize.Y.Offset - originalSize.Y.Offset) * obj.AnchorPoint.Y)

	obj.Size = newSize
	obj.Position = UDim2.new(
		originalPosition.X.Scale - xScaleShift,
		originalPosition.X.Offset - xOffsetShift,
		originalPosition.Y.Scale - yScaleShift,
		originalPosition.Y.Offset - yOffsetShift
	)
end

local function resetContainerScale(obj: GuiObject)
	obj.Size = getOriginalSize(obj)
	obj.Position = getOriginalPosition(obj)
end

local function updateSpotlightContainers(root: GuiBase2d, shouldExpand: boolean)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant.Name == "Container" then
			if shouldExpand then
				setContainerScale(descendant, spotlightScaleMultiplier)
			else
				resetContainerScale(descendant)
			end
		end
	end
end


function module.fadeIn(obj)
	local newPos = getOriginalPosition(obj)

	if obj:IsA('TextLabel') then
		tween(obj, fadeInTime, {Position = newPos, TextTransparency = 0})
	else
		tween(obj, fadeInTime, {Position = newPos, ImageTransparency = 0})
	end		
end

function module.fadeOut(obj: GuiBase2d)
	cacheOriginalPosition(obj)


	local newPos = UDim2.new(
		obj.Position.X.Scale,
		obj.Position.X.Offset,
		obj.Position.Y.Scale - offsetVal,
		obj.Position.Y.Offset
	)

	if obj:IsA('TextLabel') then
		tween(obj, fadeOutTime, {Position = newPos, TextTransparency = 1})
	else
		tween(obj, fadeOutTime, {Position = newPos, ImageTransparency = 1})
	end		


	--tween(obj.UIStroke, fadeOutTime, {Transparency = 1})
end

function module.toggle(state)
	if state then
		script.Parent.Visible = true
		tween(script.Parent, fadeOutTime, {BackgroundTransparency = guideOverlayTransparency})
		local countTracker = 1
		for i = 1, #script.Parent.Main:GetChildren() do
			local num = script.Parent.Main:FindFirstChild(tostring(countTracker))
			if num and num:IsA('GuiBase2d') then
				updateSpotlightContainers(num, true)

				for i, v in num:GetDescendants() do
					if v:IsA('GuiBase2d') and v.Name ~= 'Container' then
						module.fadeIn(v)
					end
				end

				task.wait(1)
				countTracker += 1
			end
		end

		task.wait(0.5)
		module.fadeIn(script.Parent.Continue)

		local Bindable = Instance.new('BindableEvent')
		script.Parent.Parent.ClansFrame.Interactable = false

		local conn1 = UserInputService.InputBegan:Connect(function(inpVal, gp)
			if not gp then
				if inpVal.UserInputType == Enum.UserInputType.MouseButton1 or inpVal.UserInputType == Enum.UserInputType.Touch then
					print('clocked')
					Bindable:Fire()
				end
			end
		end)

		Bindable.Event:Wait()

		script.Parent.Parent.ClansFrame.Interactable = true
		conn1:Disconnect()
		conn1 = nil
		Bindable:Destroy()

		module.toggle(false)
	else
		-- Disable
		for i,num in script.Parent.Main:GetChildren() do
			if num:IsA('GuiBase2d') then
				updateSpotlightContainers(num, false)

				for i, v in num:GetDescendants() do
					if v:IsA('GuiBase2d') and v.Name ~= 'Container' then
						module.fadeOut(v)
					end
				end
			end
		end

		module.fadeOut(script.Parent.Continue)
		tween(script.Parent, fadeOutTime, {BackgroundTransparency = 1})
		task.wait(fadeOutTime)
		script.Parent.Visible = false
	end
end


return module
