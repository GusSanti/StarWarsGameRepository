local TutorialState = {}

TutorialState.VALID_SECTIONS = {
	start = true,
	arena = true,
	["end"] = true,
	complete = true,
}

TutorialState.SECTION_ORDER = {
	start = 1,
	arena = 2,
	["end"] = 3,
	complete = 4,
}

local function readValue(field, defaultValue)
	if field == nil then
		return defaultValue
	end

	if typeof(field) == "Instance" and field:IsA("ValueBase") then
		return field.Value
	end

	return field
end

local function writeValue(field, value)
	if field ~= nil and typeof(field) == "Instance" and field:IsA("ValueBase") then
		field.Value = value
	end
end

function TutorialState.waitForPlayerData(player: Player)
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

function TutorialState.findPlayerData(player: Player)
	return {
		firstTime = player:FindFirstChild("FirstTime"),
		started = player:FindFirstChild("TutorialStarted"),
		section = player:FindFirstChild("TutorialSection"),
		step = player:FindFirstChild("TutorialStep"),
		modeCompleted = player:FindFirstChild("TutorialModeCompleted"),
		completed = player:FindFirstChild("TutorialCompleted"),
		win = player:FindFirstChild("TutorialWin"),
	}
end

function TutorialState.sanitizeStep(step)
	local numericStep = tonumber(step)
	if not numericStep then
		return 1
	end

	return math.max(1, math.floor(numericStep))
end

function TutorialState.getSectionOrder(sectionName)
	return TutorialState.SECTION_ORDER[sectionName] or 0
end

function TutorialState.canAdvanceToSection(currentSection, nextSection)
	return TutorialState.getSectionOrder(nextSection) >= TutorialState.getSectionOrder(currentSection)
end

function TutorialState.snapshot(tutorialData)
	return {
		firstTime = readValue(tutorialData.firstTime, false) == true,
		started = readValue(tutorialData.started, false) == true,
		section = readValue(tutorialData.section, "start"),
		step = TutorialState.sanitizeStep(readValue(tutorialData.step, 1)),
		modeCompleted = readValue(tutorialData.modeCompleted, false) == true,
		completed = readValue(tutorialData.completed, false) == true,
		win = readValue(tutorialData.win, false) == true,
	}
end

function TutorialState.isVictoryCompleted(state)
	return state.modeCompleted == true
		and state.win == true
		and state.completed == true
end

function TutorialState.isMatchInProgress(state)
	return state.modeCompleted == true
		and state.win == false
		and state.completed == false
end

function TutorialState.isResolved(state)
	return state.completed == true
		or state.section == "complete"
end

function TutorialState.normalizeSnapshot(snapshot)
	-- Keep the tutorial flags in a canonical combination before any script branches on them.
	local normalized = {
		firstTime = snapshot.firstTime == true,
		started = snapshot.started == true,
		section = TutorialState.VALID_SECTIONS[snapshot.section] and snapshot.section or "start",
		step = TutorialState.sanitizeStep(snapshot.step),
		modeCompleted = snapshot.modeCompleted == true,
		completed = snapshot.completed == true,
		win = snapshot.win == true,
	}

	if TutorialState.isResolved(normalized) then
		normalized.firstTime = false
		normalized.started = false
		normalized.modeCompleted = true
		normalized.completed = true
		normalized.section = "complete"
		normalized.step = 1
		return normalized
	end

	if normalized.started then
		normalized.firstTime = false
	end

	if normalized.section == "end" or normalized.win == true then
		normalized.firstTime = false
		normalized.started = true
		normalized.modeCompleted = true
		normalized.completed = false
		normalized.section = "end"
		return normalized
	end

	if normalized.section == "arena" then
		normalized.firstTime = false
		normalized.started = true
		normalized.modeCompleted = true
		normalized.completed = false
		normalized.win = false
		return normalized
	end

	if normalized.modeCompleted == true then
		normalized.firstTime = false
		normalized.started = true
		normalized.completed = false
		normalized.win = false
		return normalized
	end

	normalized.completed = false
	normalized.win = false
	return normalized
end

function TutorialState.apply(tutorialData, snapshot)
	writeValue(tutorialData.firstTime, snapshot.firstTime)
	writeValue(tutorialData.started, snapshot.started)
	writeValue(tutorialData.section, snapshot.section)
	writeValue(tutorialData.step, snapshot.step)
	writeValue(tutorialData.modeCompleted, snapshot.modeCompleted)
	writeValue(tutorialData.completed, snapshot.completed)
	writeValue(tutorialData.win, snapshot.win)
end

function TutorialState.reconcile(tutorialData)
	local normalized = TutorialState.normalizeSnapshot(TutorialState.snapshot(tutorialData))
	TutorialState.apply(tutorialData, normalized)
	return normalized
end

return TutorialState
