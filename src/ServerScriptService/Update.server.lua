local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Events.Client.UpdateFirstTime.OnServerEvent:Connect(function(player)
	local firstTime = player:FindFirstChild("FirstTime")
	local tutorialMode = player:FindFirstChild("TutorialModeCompleted")
	local tutorialStarted = player:FindFirstChild("TutorialStarted")
	local tutorialSection = player:FindFirstChild("TutorialSection")
	local tutorialStep = player:FindFirstChild("TutorialStep")
	if not firstTime then
		firstTime = player:FindFirstChild("FirstTime")
		repeat task.wait(.1) warn("Retrying") until firstTime
	end
	if not tutorialMode then
		tutorialMode = player:FindFirstChild("TutorialModeCompleted")
		repeat task.wait(.1) warn("Retrying") until tutorialMode
	end

	firstTime.Value = false
	if tutorialStarted then
		tutorialStarted.Value = true
	end
	if tutorialSection then
		tutorialSection.Value = "start"
	end
	if tutorialStep then
		tutorialStep.Value = 1
	end
	tutorialMode.Value = false
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
