repeat task.wait(0.1) until _G.LoadingScreenComplete

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local funcs = require(ReplicatedStorage.Modules.Functions)
local DailyRewardModule = require(ReplicatedStorage.Modules.DailyReward)
local TutorialState = require(ReplicatedStorage.Modules.TutorialState)

local tutorialFolder = script:FindFirstChild("Tutorial") or script.Parent:WaitForChild("Tutorial")
local tutorialStartSteps = require(tutorialFolder:WaitForChild("TutotrialStartSteps"))
local tutorialEndSteps = require(tutorialFolder:WaitForChild("TutotrialEndSteps"))
local events = require(tutorialFolder:WaitForChild("Events"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NewUI = playerGui:WaitForChild("NewUI")
local CoreGameUI = playerGui:WaitForChild("CoreGameUI")

local rootGui = script.Parent
local dialogueFrame = rootGui:WaitForChild("Dialogue")
local dialogueScale = dialogueFrame:FindFirstChildOfClass("UIScale")
local pointersFolder = rootGui:FindFirstChild("Pointers")
local pointer = pointersFolder and pointersFolder:FindFirstChild("Pointer", true)

local contents = dialogueFrame:WaitForChild("Contents")
local bgText = contents:WaitForChild("Bg_Text")
local label = bgText:WaitForChild("TextLabel")
local continueButton = contents:WaitForChild("Options"):WaitForChild("Continue")
continueButton.Visible = false

local DailyRewardFrame = NewUI:FindFirstChild("DailyRewardFrame") or NewUI:WaitForChild("DailyRewardFrame", 10)
local DAILY_REWARD_RESOLVED_ATTR = "DailyRewardStartupResolved"
local DAILY_REWARD_SHOWN_ATTR = "DailyRewardStartupShown"
local DAILY_REWARD_CLOSED_BY_BUTTON_ATTR = "DailyRewardClosedByButton"
local TutorialRemote = ReplicatedStorage.Events.Client:WaitForChild("Tutorial")
local GetUnits = ReplicatedStorage:WaitForChild("GetUnitsButton")

local LOBBY_REENTRY_STEP = 9
local DEFAULT_FOCUS_PADDING = Vector2.new(20, 20)
local DEFAULT_FOCUS_MIN_SIZE = Vector2.new(96, 96)
local TUTORIAL_FOCUS_OFFSET_Y = 53
local TUTORIAL_FOCUS_OUTLINE_COLOR = Color3.fromRGB(80, 170, 255)

local textThread = nil
local focusConnection = nil
local focusResolver = nil

repeat task.wait(0.1) until player:FindFirstChild("DataLoaded")

local firstTime = player:WaitForChild("FirstTime")
local tutorialStarted = player:WaitForChild("TutorialStarted")
local tutorialSection = player:WaitForChild("TutorialSection")
local tutorialStep = player:WaitForChild("TutorialStep")
local tutorialModeCompleted = player:WaitForChild("TutorialModeCompleted")
local tutorialCompleted = player:WaitForChild("TutorialCompleted")
local tutorialWin = player:WaitForChild("TutorialWin")
local tutorialLossGemsClaimed = player:WaitForChild("TutorialLossGemsClaimed")

local function getTutorialStateSnapshot()
	return TutorialState.normalizeSnapshot(TutorialState.snapshot({
		firstTime = firstTime,
		started = tutorialStarted,
		section = tutorialSection,
		step = tutorialStep,
		modeCompleted = tutorialModeCompleted,
		completed = tutorialCompleted,
		win = tutorialWin,
	}))
end

local POINTER_POSITIONS = {
	[2] = UDim2.fromScale(0.06, 0.59),
	[3] = UDim2.new(0.571, 0, 0.6, 0),
	[5] = UDim2.new(0.03, 0, 0.42, 0),
	[7] = UDim2.fromScale(0.59, 0.78),
	[8] = UDim2.new(0.735, 0, 0.27, 0),
	[9] = UDim2.fromScale(0.062, 0.7),
}

local END_POINTER_POS = {
	[1] = UDim2.fromScale(0.066, 0.62),
	[2] = UDim2.new(0.411, 0, 0.669, 0),
}

local function createFocusSegment(name, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Visible = false
	frame.ZIndex = zIndex
	frame.Parent = rootGui
	return frame
end

local FocusTop = createFocusSegment("TutorialFocusTop", 1)
local FocusBottom = createFocusSegment("TutorialFocusBottom", 1)
local FocusLeft = createFocusSegment("TutorialFocusLeft", 1)
local FocusRight = createFocusSegment("TutorialFocusRight", 1)

local FocusOutline = Instance.new("Frame")
FocusOutline.Name = "TutorialFocusOutline"
FocusOutline.BackgroundTransparency = 1
FocusOutline.BorderSizePixel = 0
FocusOutline.Visible = false
FocusOutline.ZIndex = 2
FocusOutline.Parent = rootGui

local FocusStroke = Instance.new("UIStroke")
FocusStroke.Color = TUTORIAL_FOCUS_OUTLINE_COLOR
FocusStroke.Thickness = 2
FocusStroke.Transparency = 0.1
FocusStroke.Parent = FocusOutline

local FocusCorner = Instance.new("UICorner")
FocusCorner.CornerRadius = UDim.new(0, 14)
FocusCorner.Parent = FocusOutline

local function setFocusVisible(isVisible)
	FocusTop.Visible = isVisible
	FocusBottom.Visible = isVisible
	FocusLeft.Visible = isVisible
	FocusRight.Visible = isVisible
	FocusOutline.Visible = isVisible
end

local function ensureOverlayRootCoversScreen()
	if not rootGui:IsA("GuiObject") then
		return
	end

	-- Keep the blackout layer fullscreen even when mobile layout/safe-area settings differ.
	if rootGui.AnchorPoint ~= Vector2.new(0, 0) then
		rootGui.AnchorPoint = Vector2.new(0, 0)
	end

	if rootGui.Position ~= UDim2.fromOffset(0, 0) then
		rootGui.Position = UDim2.fromOffset(0, 0)
	end

	if rootGui.Size ~= UDim2.fromScale(1, 1) then
		rootGui.Size = UDim2.fromScale(1, 1)
	end
end

local function getOverlayBounds()
	ensureOverlayRootCoversScreen()

	local hasAbsolutePosition, overlayPosition = pcall(function()
		return rootGui.AbsolutePosition
	end)
	local hasAbsoluteSize, overlaySize = pcall(function()
		return rootGui.AbsoluteSize
	end)

	if hasAbsolutePosition and hasAbsoluteSize then
		return overlayPosition, overlaySize
	end

	local camera = workspace.CurrentCamera
	if camera then
		return Vector2.new(0, 0), camera.ViewportSize
	end

	return Vector2.new(0, 0), Vector2.new(1920, 1080)
end

local function getLocalTargetRect(target)
	local overlayPosition, overlaySize = getOverlayBounds()
	local absolutePosition = target.AbsolutePosition
	local absoluteSize = target.AbsoluteSize

	return overlayPosition, overlaySize, absolutePosition - overlayPosition, absoluteSize
end

local function hidePointer()
	if pointer then
		pointer.Visible = false
	end

	if pointersFolder and pointersFolder:IsA("GuiObject") then
		pointersFolder.Visible = false
	end
end

local function showPointer(pointerPosition)
	if not (pointer and pointerPosition) then
		hidePointer()
		return
	end

	pointer.Position = pointerPosition
	pointer.Visible = true

	if pointersFolder and pointersFolder:IsA("GuiObject") then
		pointersFolder.Visible = true
	end
end

local function stopFocusTracking()
	if focusConnection then
		focusConnection:Disconnect()
		focusConnection = nil
	end

	focusResolver = nil
	setFocusVisible(false)
end

local function isGuiVisible(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") or guiObject.AbsoluteSize.X <= 0 or guiObject.AbsoluteSize.Y <= 0 then
		return false
	end

	local current = guiObject
	while current and current ~= rootGui do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end

		current = current.Parent
	end

	return true
end

local function getGuiButtonFromItem(item)
	if not item then
		return nil
	end

	if item:IsA("GuiButton") then
		return item
	end

	local button = item:FindFirstChild("Btn", true)
		or item:FindFirstChild("Button", true)

	if button and button:IsA("GuiButton") then
		return button
	end

	return item:FindFirstChildWhichIsA("GuiButton", true)
end

local normalizeName

local function getHighlightTargetFromItem(item)
	if not item then
		return nil
	end

	if item:IsA("GuiButton") and (item.Name == "Btn" or item.Name == "Button") then
		local parent = item.Parent
		if parent and parent:IsA("GuiObject") then
			return parent
		end
	end

	if item:IsA("GuiObject") then
		return item
	end

	local parent = item.Parent
	return parent and parent:IsA("GuiObject") and parent or nil
end

local function getNamedHighlightTarget(item, targetName)
	local normalizedTarget = normalizeName(targetName)
	local current = item
	local bestMatch = getHighlightTargetFromItem(item)

	while current and current ~= rootGui do
		if current:IsA("GuiObject") then
			if normalizeName(current.Name) == normalizedTarget and current.Name ~= "Btn" and current.Name ~= "Button" then
				bestMatch = current
			end

			local parent = current.Parent
			if parent and parent:IsA("GuiObject") and normalizeName(parent.Name) == normalizedTarget then
				bestMatch = parent
			end
		end

		current = current.Parent
	end

	return bestMatch
end

normalizeName = function(name)
	if typeof(name) ~= "string" then
		return ""
	end

	return string.lower(name):gsub("^%d+", ""):gsub("[%s_%-_]+", "")
end

local function findItemInSideMenu(name)
	local sideMenu = NewUI:FindFirstChild("SideMenu") or NewUI:FindFirstChild("sideMenu") or NewUI:FindFirstChild("HUDButtons")
	if not sideMenu then
		return nil
	end

	local normalizedTarget = normalizeName(name)
	if normalizedTarget == "inventory" or normalizedTarget == "unit" then
		normalizedTarget = "units"
	end

	for _, item in ipairs(sideMenu:GetDescendants()) do
		local normalizedItem = normalizeName(item.Name)
		if normalizedItem == "inventory" or normalizedItem == "unit" then
			normalizedItem = "units"
		end

		if normalizedItem == normalizedTarget then
			local highlightTarget = getNamedHighlightTarget(item, name)
			if highlightTarget and highlightTarget ~= sideMenu then
				return highlightTarget
			end
		end
	end

	return nil
end

local function findLegacyHudItem(name)
	local hud = CoreGameUI:FindFirstChild("HUD")
	local leftPanel = hud and hud:FindFirstChild("LeftPanel")
	if not leftPanel then
		return nil
	end

	local normalizedTarget = normalizeName(name)
	for _, item in ipairs(leftPanel:GetChildren()) do
		if normalizeName(item.Name) == normalizedTarget then
			return getHighlightTargetFromItem(item)
		end
	end

	return nil
end

local function findMenuButton(name)
	return findItemInSideMenu(name) or findLegacyHudItem(name)
end

local function findUnitsFrame()
	if NewUI:FindFirstChild("Units") then
		return NewUI.Units
	end

	local unitsGui = playerGui:FindFirstChild("UnitsGui")
	local inventory = unitsGui and unitsGui:FindFirstChild("Inventory")
	return inventory and inventory:FindFirstChild("Units")
end

local function findUnitsButton()
	local success, result = pcall(function()
		return GetUnits:Invoke()
	end)

	if success and result then
		return getHighlightTargetFromItem(result)
	end

	return findMenuButton("units")
end

local function findUnitsCloseButton()
	local unitsFrame = findUnitsFrame()
	if not unitsFrame then
		return nil
	end

	return getHighlightTargetFromItem(unitsFrame:FindFirstChild("X_Close", true))
		or getHighlightTargetFromItem(unitsFrame:FindFirstChild("Closebtn", true))
		or getHighlightTargetFromItem(unitsFrame:FindFirstChild("CloseButton", true))
		or getHighlightTargetFromItem(unitsFrame:FindFirstChild("Close", true))
end

local function findUnitsEquipButton()
	local unitsFrame = findUnitsFrame()
	if not unitsFrame then
		return nil
	end

	local directButton = unitsFrame:FindFirstChild("Equip", true)
	return getHighlightTargetFromItem(directButton)
end

local function findUnitsSelectionTarget()
	local unitsFrame = findUnitsFrame()
	if not unitsFrame then
		return nil
	end

	local mainFrame = unitsFrame:FindFirstChild("Main")
	local itemsTab = mainFrame and mainFrame:FindFirstChild("ItemsTab")
	local contentGrid = itemsTab and itemsTab:FindFirstChild("Content")

	return getHighlightTargetFromItem(contentGrid)
		or getHighlightTargetFromItem(itemsTab)
		or getHighlightTargetFromItem(mainFrame)
end

local function findSummonFrame()
	if NewUI:FindFirstChild("Summons") then
		return NewUI.Summons
	end

	local summonFolder = CoreGameUI:FindFirstChild("Summon")
	return summonFolder and summonFolder:FindFirstChild("SummonFrame")
end

local function getSummonActionButton(buttonIndex)
	local summonFrame = findSummonFrame()
	if not summonFrame then
		return nil
	end

	if summonFrame.Name == "Summons" then
		local buttons = summonFrame:FindFirstChild("Body")
			and summonFrame.Body:FindFirstChild("Main")
			and summonFrame.Body.Main:FindFirstChild("Banner")
			and summonFrame.Body.Main.Banner:FindFirstChild("Buttons")

		if buttons then
			return getHighlightTargetFromItem(buttons:FindFirstChild(tostring(buttonIndex)))
		end
	end

	local legacyBar = summonFrame:FindFirstChild("Banner")
		and summonFrame.Banner:FindFirstChild("Bottom_Bar")
		and summonFrame.Banner.Bottom_Bar:FindFirstChild("Bottom_Bar")

	if not legacyBar then
		return nil
	end

	local legacyNames = {
		[1] = "Lucky_Summons",
		[2] = "Summon",
		[3] = "Summon10",
		[4] = "AutoSummon",
	}

	return getHighlightTargetFromItem(legacyBar:FindFirstChild(legacyNames[buttonIndex]))
end

local function findStoryPlayButton()
	NewUI = NewUI or playerGui:FindFirstChild("NewUI")

	local function findStoryAction(root)
		if not root then
			return nil
		end

		return getHighlightTargetFromItem(root:FindFirstChild("Join", true))
			or getHighlightTargetFromItem(root:FindFirstChild("Play", true))
	end

	local newStoryFrame = NewUI and NewUI:FindFirstChild("StoryFrame")
	if newStoryFrame then
		return findStoryAction(newStoryFrame)
	end

	local legacyStoryFrame = CoreGameUI:FindFirstChild("Play_Menu")
		and CoreGameUI.Play_Menu:FindFirstChild("Frame")
		and CoreGameUI.Play_Menu.Frame:FindFirstChild("Story")

	return findStoryAction(legacyStoryFrame)
end

local STEP_HIGHLIGHTS = {
	start = {
		[2] = function()
			return {target = findMenuButton("summon")}
		end,
		[3] = function()
			return {target = getSummonActionButton(3), minSize = Vector2.new(180, 84)}
		end,
		[5] = function()
			return {target = findUnitsButton()}
		end,
		[6] = function()
			return {target = findUnitsSelectionTarget(), minSize = Vector2.new(420, 320)}
		end,
		[7] = function()
			return {target = findUnitsEquipButton(), minSize = Vector2.new(170, 80)}
		end,
		[8] = function()
			return {target = findUnitsCloseButton()}
		end,
		[9] = function()
			return {target = findMenuButton("play")}
		end,
		[11] = function()
			return {target = findStoryPlayButton(), minSize = Vector2.new(180, 84)}
		end,
	},
	["end"] = {
		[1] = function()
			return {target = findMenuButton("summon")}
		end,
		[2] = function()
			return {target = getSummonActionButton(2), minSize = Vector2.new(180, 84)}
		end,
	},
}

local function updateFocusRect()
	if not focusResolver then
		setFocusVisible(false)
		return
	end

	local focusData = focusResolver()
	local hasFocusMetadata = typeof(focusData) == "table"
	local target = hasFocusMetadata and focusData.target or focusData

	while typeof(target) == "table" do
		target = target.target or target.button or target.gui or target.instance
	end

	if not (typeof(target) == "Instance" and target:IsA("GuiObject") and isGuiVisible(target)) then
		setFocusVisible(false)
		return
	end

	local padding = hasFocusMetadata and focusData.padding or DEFAULT_FOCUS_PADDING
	local minSize = hasFocusMetadata and focusData.minSize or DEFAULT_FOCUS_MIN_SIZE
	local _, overlaySize, localPosition, absoluteSize = getLocalTargetRect(target)
	if overlaySize.X <= 0 or overlaySize.Y <= 0 then
		setFocusVisible(false)
		return
	end

	local center = localPosition + absoluteSize * 0.5 + Vector2.new(0, TUTORIAL_FOCUS_OFFSET_Y)
	local holeWidth = math.min(math.max(absoluteSize.X + padding.X * 2, minSize.X), overlaySize.X)
	local holeHeight = math.min(math.max(absoluteSize.Y + padding.Y * 2, minSize.Y), overlaySize.Y)
	local holeLeft = math.floor(math.clamp(center.X - holeWidth * 0.5, 0, math.max(overlaySize.X - holeWidth, 0)))
	local holeTop = math.floor(math.clamp(center.Y - holeHeight * 0.5, 0, math.max(overlaySize.Y - holeHeight, 0)))
	local holeRight = math.ceil(math.clamp(holeLeft + holeWidth, 0, overlaySize.X))
	local holeBottom = math.ceil(math.clamp(holeTop + holeHeight, 0, overlaySize.Y))

	holeWidth = holeRight - holeLeft
	holeHeight = holeBottom - holeTop

	FocusTop.Position = UDim2.fromOffset(0, 0)
	FocusTop.Size = UDim2.fromOffset(overlaySize.X, holeTop)

	FocusBottom.Position = UDim2.fromOffset(0, holeBottom)
	FocusBottom.Size = UDim2.fromOffset(overlaySize.X, math.max(overlaySize.Y - holeBottom, 0))

	FocusLeft.Position = UDim2.fromOffset(0, holeTop)
	FocusLeft.Size = UDim2.fromOffset(holeLeft, holeHeight)

	FocusRight.Position = UDim2.fromOffset(holeRight, holeTop)
	FocusRight.Size = UDim2.fromOffset(math.max(overlaySize.X - holeRight, 0), holeHeight)

	FocusOutline.Position = UDim2.fromOffset(holeLeft, holeTop)
	FocusOutline.Size = UDim2.fromOffset(holeWidth, holeHeight)

	setFocusVisible(true)
end

local function startFocusTracking(resolver)
	focusResolver = resolver
	updateFocusRect()

	if not focusConnection then
		focusConnection = RunService.RenderStepped:Connect(updateFocusRect)
	end
end

local function getPointerPosition(phaseKey, stepIndex)
	if phaseKey == "start" then
		return POINTER_POSITIONS[stepIndex]
	end

	return END_POINTER_POS[stepIndex]
end

local function getStepHighlight(phaseKey, stepIndex)
	local phaseHighlights = STEP_HIGHLIGHTS[phaseKey]
	return phaseHighlights and phaseHighlights[stepIndex] or nil
end

local function cancelTextThread()
	if textThread then
		pcall(task.cancel, textThread)
		textThread = nil
	end
end

local function waitForDailyRewardCloseButton()
	if DailyRewardModule.GetTimeUntilClaim(player) > 0 then
		return
	end

	if not DailyRewardFrame then
		return
	end

	local openDeadline = os.clock() + 12
	while os.clock() < openDeadline do
		if NewUI:GetAttribute(DAILY_REWARD_CLOSED_BY_BUTTON_ATTR) == true then
			return
		end

		if DailyRewardFrame.Visible then
			break
		end

		if NewUI:GetAttribute(DAILY_REWARD_SHOWN_ATTR) ~= true
			and NewUI:GetAttribute(DAILY_REWARD_RESOLVED_ATTR) == true
		then
			-- Do not deadlock the tutorial if the startup prompt never makes it on screen.
			return
		end

		task.wait(0.1)
	end

	if not DailyRewardFrame.Visible then
		return
	end

	local closeDeadline = os.clock() + 60
	while DailyRewardFrame.Visible and os.clock() < closeDeadline do
		if NewUI:GetAttribute(DAILY_REWARD_CLOSED_BY_BUTTON_ATTR) == true then
			return
		end

		task.wait(0.1)
	end
end

local function animateText(step, phaseKey)
	local characters = string.split(step.text or "", "")
	if #characters == 0 then
		dialogueFrame.Visible = false
		hidePointer()
		stopFocusTracking()
		return
	end

	dialogueFrame.Visible = true
	label.Text = ""

	for index = 1, #characters do
		label.Text ..= characters[index]
		task.wait(0.01)
	end

	local highlightResolver = getStepHighlight(phaseKey, step.index)
	if highlightResolver then
		hidePointer()
		startFocusTracking(highlightResolver)
		return
	end

	stopFocusTracking()
	showPointer(getPointerPosition(phaseKey, step.index))
end

local function saveTutorialCheckpoint(sectionName, stepIndex)
	TutorialRemote:FireServer("checkpoint", {
		section = sectionName,
		step = stepIndex,
		started = true,
		firstTime = false,
	})
end

local function normalizeTutorialResumeStep(sectionName, stepIndex)
	if sectionName ~= "start" then
		return stepIndex
	end

	if stepIndex == 3 or stepIndex == 4 then
		return 2
	end

	if stepIndex >= 6 and stepIndex <= 8 then
		return 5
	end

	return stepIndex
end

local function stepRequiresContinueButton(step)
	return step and step.waitFor == "Continue"
end

local function updateContinueButtonVisibility(step)
	continueButton.Visible = stepRequiresContinueButton(step)
end

local function runStepSequence(steps, phaseKey, startIndex)
	dialogueFrame.Visible = true

	for stepNum = startIndex, #steps do
		local step = steps[stepNum]
		cancelTextThread()
		saveTutorialCheckpoint(phaseKey, stepNum)
		updateContinueButtonVisibility(step)
		textThread = task.spawn(animateText, step, phaseKey)

		local waitFunc = events[step.waitFor]
		if waitFunc then
			waitFunc(function()
				warn("Completed step: " .. stepNum)
			end)
		else
			warn("Missing tutorial event for: " .. tostring(step.waitFor))
		end
	end
end

local function RunTutorial()
	local tutorialState = getTutorialStateSnapshot()

	if TutorialState.isResolved(tutorialState) then
		return
	end

	local info = TweenInfo.new(0.35, Enum.EasingStyle.Exponential)
	local sectionName = tutorialState.section
	local startIndex = tutorialState.step

	if sectionName == "start" then
		if not (tutorialState.firstTime or tutorialState.started) then
			return
		end

		local normalizedStartIndex = math.clamp(
			normalizeTutorialResumeStep("start", startIndex),
			1,
			#tutorialStartSteps
		)

		if normalizedStartIndex ~= startIndex then
			saveTutorialCheckpoint("start", normalizedStartIndex)
		end

		runStepSequence(tutorialStartSteps, "start", normalizedStartIndex)
	elseif sectionName == "arena" then
		if not tutorialState.started then
			return
		end

		runStepSequence(tutorialStartSteps, "start", LOBBY_REENTRY_STEP)
	elseif sectionName == "end" then
		if not tutorialState.started then
			return
		end

		for stepNum = math.clamp(startIndex, 1, #tutorialEndSteps), #tutorialEndSteps do
			local step = tutorialEndSteps[stepNum]
			cancelTextThread()
			saveTutorialCheckpoint("end", stepNum)

			local displayStep = step
			if step.index == 1 and tutorialState.win == false then
				if not tutorialLossGemsClaimed.Value then
					ReplicatedStorage.Events.Client.RewardGems:FireServer()
				end

				displayStep = {
					index = 1,
					text = "Seems like you lost, no worries. I'll reward you with crystals so you can summon more units to aid you to victory next time!",
				}
			end

			updateContinueButtonVisibility(step)
			textThread = task.spawn(animateText, displayStep, "end")

			local waitFunc = events[step.waitFor]
			if waitFunc then
				waitFunc(function()
					warn("Completed step: " .. stepNum)
				end)
			else
				warn("Missing tutorial event for: " .. tostring(step.waitFor))
			end
		end
	else
		return
	end

	cancelTextThread()
	stopFocusTracking()
	hidePointer()
	continueButton.Visible = false

	if dialogueScale then
		funcs.tween(dialogueScale, info, {Scale = 0}):Play()
	end
end

waitForDailyRewardCloseButton()
RunTutorial()
