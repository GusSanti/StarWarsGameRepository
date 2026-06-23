local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TutorialState = require(ReplicatedStorage.Modules.TutorialState)

ReplicatedStorage.Events.Client.UpdateFirstTime.OnServerEvent:Connect(function(player)
	local tutorialData = TutorialState.findPlayerData(player)
	if not tutorialData.firstTime then
		repeat task.wait(.1) warn("Retrying") until player:FindFirstChild("FirstTime")
		tutorialData = TutorialState.findPlayerData(player)
	end
	if not tutorialData.modeCompleted then
		repeat task.wait(.1) warn("Retrying") until player:FindFirstChild("TutorialModeCompleted")
	end
	tutorialData = TutorialState.waitForPlayerData(player)

	local tutorialState = TutorialState.reconcile(tutorialData)
	if TutorialState.isResolved(tutorialState)
		or tutorialState.started
		or tutorialState.modeCompleted
	then
		return
	end

	TutorialState.apply(tutorialData, {
		firstTime = false,
		started = true,
		section = "start",
		step = 1,
		modeCompleted = false,
		completed = false,
		win = false,
	})
end)

ReplicatedStorage.Events.Client.RewardGems.OnServerEvent:Connect(function(player: Player) 
	if player:FindFirstChild('DataLoaded') and not player.TutorialLossGemsClaimed.Value then
		local gems = player:FindFirstChild("Gems")
		if gems then
			gems.Value += 250
		end

		player.TutorialLossGemsClaimed.Value = true -- fixed a stupid vuln mathrix did
	end
end)

ReplicatedStorage.Events.Client.UpdatePoints.OnServerEvent:Connect(function(player, combinedPoints: number, action)
	local points = player:FindFirstChild("JunkTraderPoints")
	if not points then
		repeat task.wait(.1) warn("Retrying") until points
	end

	if action == "add" then
		points.Value += combinedPoints
	elseif action == "subtract" then
		points.Value -= combinedPoints
	end

end)
