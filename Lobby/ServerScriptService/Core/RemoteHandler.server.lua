local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService('Players')

local VALID_TUTORIAL_SECTIONS = {
	start = true,
	arena = true,
	["end"] = true,
	complete = true,
}

local TUTORIAL_SECTION_ORDER = {
	start = 1,
	arena = 2,
	["end"] = 3,
	complete = 4,
}

local function getTutorialData(player: Player)
	return {
		firstTime = player:WaitForChild("FirstTime"),
		started = player:WaitForChild("TutorialStarted"),
		section = player:WaitForChild("TutorialSection"),
		step = player:WaitForChild("TutorialStep"),
		modeCompleted = player:WaitForChild("TutorialModeCompleted"),
		completed = player:WaitForChild("TutorialCompleted"),
		win = player:WaitForChild("TutorialWin"),
	}
end

local function getTutorialSectionOrder(sectionName)
	return TUTORIAL_SECTION_ORDER[sectionName] or 0
end

local function isCompletedTutorialState(tutorialData)
	return tutorialData.completed.Value == true
		or tutorialData.section.Value == "complete"
end

local function normalizeCompletedTutorialState(tutorialData)
	tutorialData.firstTime.Value = false
	tutorialData.started.Value = false
	tutorialData.modeCompleted.Value = true
	tutorialData.completed.Value = true
	tutorialData.section.Value = "complete"
	tutorialData.step.Value = 1
end

local function canAdvanceToTutorialSection(currentSection, nextSection)
	return getTutorialSectionOrder(nextSection) >= getTutorialSectionOrder(currentSection)
end

local function sanitizeTutorialStep(step)
	local numericStep = tonumber(step)
	if not numericStep then
		return 1
	end

	return math.max(1, math.floor(numericStep))
end

ReplicatedStorage.Events.Client.Tutorial.OnServerEvent:Connect(function(player, action, payload)
	local tutorialData = getTutorialData(player)

	if action == "checkpoint" then
		if isCompletedTutorialState(tutorialData) then
			normalizeCompletedTutorialState(tutorialData)
			return
		end

		if typeof(payload) ~= "table" then
			return
		end

		if typeof(payload.started) == "boolean" then
			tutorialData.started.Value = tutorialData.started.Value or payload.started
		end

		if payload.firstTime == false then
			tutorialData.firstTime.Value = false
		end

		if payload.modeCompleted == true then
			tutorialData.modeCompleted.Value = true
		end

		if payload.win == true then
			tutorialData.win.Value = true
		end

		if VALID_TUTORIAL_SECTIONS[payload.section] then
			if not canAdvanceToTutorialSection(tutorialData.section.Value, payload.section) then
				return
			end

			tutorialData.section.Value = payload.section
		end

		if payload.step ~= nil then
			tutorialData.step.Value = sanitizeTutorialStep(payload.step)
		end

		return
	end

	if action == "begin_arena" then
		if isCompletedTutorialState(tutorialData) or not canAdvanceToTutorialSection(tutorialData.section.Value, "arena") then
			if isCompletedTutorialState(tutorialData) then
				normalizeCompletedTutorialState(tutorialData)
			end
			return
		end

		tutorialData.firstTime.Value = false
		tutorialData.started.Value = true
		tutorialData.modeCompleted.Value = true
		tutorialData.section.Value = "arena"
		tutorialData.step.Value = 1
		return
	end

	if action == "match_result" then
		if isCompletedTutorialState(tutorialData) or not canAdvanceToTutorialSection(tutorialData.section.Value, "end") then
			if isCompletedTutorialState(tutorialData) then
				normalizeCompletedTutorialState(tutorialData)
			end
			return
		end

		local won = payload == true
			or (typeof(payload) == "table" and payload.win == true)

		tutorialData.firstTime.Value = false
		tutorialData.started.Value = true
		tutorialData.modeCompleted.Value = true
		tutorialData.win.Value = won
		tutorialData.completed.Value = false
		tutorialData.section.Value = "end"
		tutorialData.step.Value = 1
		return
	end

	if action == "complete" then
		if not tutorialData.started.Value then
			return
		end

		normalizeCompletedTutorialState(tutorialData)
		return
	end

	if tutorialData.win.Value == true then
		normalizeCompletedTutorialState(tutorialData)
	else
		warn("Player probably an exploiter lmao")
	end
end)

local function playerAdded(player: Player)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")

	local tutorialData = getTutorialData(player)
	local tutorialSection = player:WaitForChild("TutorialSection")
	local tutorialStep = player:WaitForChild("TutorialStep")
	local tutorialCompleted = player:WaitForChild("TutorialCompleted")

	if tutorialCompleted.Value
		or tutorialSection.Value == "complete"
	then
		normalizeCompletedTutorialState(tutorialData)
	elseif not VALID_TUTORIAL_SECTIONS[tutorialSection.Value] then
		tutorialSection.Value = "start"
	end

	if tutorialStep.Value < 1 then
		tutorialStep.Value = 1
	end
end


for _, module in script:GetChildren() do
	local Remote = ReplicatedStorage:FindFirstChild(module.Name, true)
	if Remote then
		local func = require(module)
		if Remote:IsA("RemoteEvent") then
			Remote.OnServerEvent:Connect(func)
			--print("Connected",module)
		elseif Remote:IsA("RemoteFunction") then
			Remote.OnServerInvoke = func
			--print("Connected",module)
		end
	end
end

for _, player in players:GetPlayers() do
	playerAdded(player)
end

players.PlayerAdded:Connect(playerAdded)
