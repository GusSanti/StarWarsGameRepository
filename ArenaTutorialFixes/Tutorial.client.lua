local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Info = workspace:WaitForChild("Info")

local tutorialFolder = script:FindFirstChild("Tutorial") or script.Parent:WaitForChild("Tutorial")
local tutorialSteps = require(tutorialFolder:WaitForChild("TutotrialSteps"))
local events = require(tutorialFolder:WaitForChild("Events"))

local player = Players.LocalPlayer
local dialogueFrame = script.Parent:WaitForChild("Dialogue")
local dialogueScale = dialogueFrame:FindFirstChildOfClass("UIScale")
local contents = dialogueFrame:WaitForChild("Contents")
local bgText = contents:WaitForChild("Bg_Text")
local label = bgText:WaitForChild("TextLabel")

local TutorialRemote = ReplicatedStorage.Events.Client:WaitForChild("Tutorial")
local textThread = nil
local gameOverConnection = nil
local matchResultSaved = false

local lostText = "Oh no! You ended up losing, no worries, you can try again."

local function animateText(text: string)
	local characters = string.split(text or "", "")
	label.Text = ""

	for index = 1, #characters do
		label.Text ..= characters[index]
		task.wait(0.01)
	end
end

local function tween(instance: Instance, tweenInfo: TweenInfo, props: {[string]: any})
	local tweenObject = TweenService:Create(instance, tweenInfo, props)
	tweenObject:Play()
	return tweenObject
end

local function stopTextThread()
	if textThread then
		pcall(task.cancel, textThread)
		textThread = nil
	end
end

local function showStepText(text: string)
	stopTextThread()
	textThread = task.spawn(function()
		animateText(text)
	end)
end

local function saveArenaCheckpoint(stepIndex)
	TutorialRemote:FireServer("checkpoint", {
		section = "arena",
		step = stepIndex,
		started = true,
		firstTime = false,
		modeCompleted = true,
	})
end

local function saveMatchResult(won)
	if matchResultSaved then
		return
	end

	matchResultSaved = true
	TutorialRemote:FireServer("match_result", {
		win = won,
	})
end

local function shouldSkipTutorial()
	return Info.Raid.Value == true
		or Info.Infinity.Value == true
		or Info.Event.Value == true
		or Info.ChallengeNumber.Value ~= -1
end

local function RunTutorial()
	if shouldSkipTutorial() then
		return
	end

	dialogueFrame.Visible = true

	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Exponential)
	if dialogueScale then
		tween(dialogueScale, tweenInfo, {Scale = 1})
	end

	matchResultSaved = false
	local lost = false

	if gameOverConnection then
		gameOverConnection:Disconnect()
	end

	gameOverConnection = Info.GameOver:GetPropertyChangedSignal("Value"):Connect(function()
		if not Info.GameOver.Value then
			return
		end

		saveMatchResult(Info.Victory.Value == true)

		if not Info.Victory.Value then
			lost = true
			showStepText(lostText)

			task.delay(2, function()
				if dialogueScale then
					tween(dialogueScale, tweenInfo, {Scale = 0})
				end
			end)
		end
	end)

	for stepNum, step in ipairs(tutorialSteps) do
		if Info.Victory.Value or lost then
			break
		end

		saveArenaCheckpoint(stepNum)

		if step.callback then
			pcall(step.callback)
		end

		showStepText(step.text)

		local waitFunc = events[step.waitFor]
		if waitFunc then
			waitFunc(function()
				warn("Completed step: " .. stepNum)
			end)
		else
			warn("Missing tutorial event for: " .. tostring(step.waitFor))
		end
	end

	if gameOverConnection then
		gameOverConnection:Disconnect()
		gameOverConnection = nil
	end

	if lost then
		return
	end

	saveMatchResult(true)

	if dialogueScale then
		tween(dialogueScale, tweenInfo, {Scale = 0})
	end

	warn("[TUTORIAL]: Completed :)")
end

repeat
	task.wait(0.1)
until player:FindFirstChild("DataLoaded")

local tutorialCompleted = player:WaitForChild("TutorialCompleted")
local tutorialSection = player:WaitForChild("TutorialSection")

if not tutorialCompleted.Value and tutorialSection.Value == "arena" then
	RunTutorial()
end
