local ReplicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService('Players')
local TutorialState = require(ReplicatedStorage.Modules.TutorialState)

local function getTutorialData(player: Player)
	return TutorialState.waitForPlayerData(player)
end

ReplicatedStorage.Events.Client.Tutorial.OnServerEvent:Connect(function(player, action, payload)
	local tutorialData = getTutorialData(player)
	local tutorialState = TutorialState.reconcile(tutorialData)

	if action == "checkpoint" then
		if TutorialState.isResolved(tutorialState) then
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

		if TutorialState.VALID_SECTIONS[payload.section] then
			if not TutorialState.canAdvanceToSection(tutorialState.section, payload.section) then
				return
			end

			tutorialData.section.Value = payload.section
		end

		if payload.step ~= nil then
			tutorialData.step.Value = TutorialState.sanitizeStep(payload.step)
		end

		TutorialState.reconcile(tutorialData)

		return
	end

	if action == "begin_arena" then
		if TutorialState.isResolved(tutorialState)
			or not TutorialState.canAdvanceToSection(tutorialState.section, "arena")
		then
			return
		end

		tutorialData.firstTime.Value = false
		tutorialData.started.Value = true
		tutorialData.modeCompleted.Value = true
		tutorialData.completed.Value = false
		tutorialData.win.Value = false
		tutorialData.section.Value = "arena"
		tutorialData.step.Value = 1
		return
	end

	if action == "match_result" then
		if TutorialState.isResolved(tutorialState)
			or not TutorialState.canAdvanceToSection(tutorialState.section, "end")
		then
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
		if not tutorialState.started or tutorialState.section ~= "end" then
			return
		end

		TutorialState.apply(tutorialData, {
			firstTime = false,
			started = false,
			section = "complete",
			step = 1,
			modeCompleted = true,
			completed = true,
			win = tutorialState.win,
		})
		return
	end

	if tutorialState.win == true then
		TutorialState.apply(tutorialData, {
			firstTime = false,
			started = false,
			section = "complete",
			step = 1,
			modeCompleted = true,
			completed = true,
			win = true,
		})
	else
		warn("Player probably an exploiter lmao")
	end
end)

local function playerAdded(player: Player)
	repeat task.wait(.1) until player:FindFirstChild("DataLoaded")

	local tutorialData = getTutorialData(player)
	TutorialState.reconcile(tutorialData)
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
