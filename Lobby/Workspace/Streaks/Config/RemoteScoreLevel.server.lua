wait(1)
local score = game:GetService("DataStoreService"):GetOrderedDataStore("Streaks")
function script.UploadScore.OnServerInvoke(player)
	repeat task.wait() until not player.Parent or player:FindFirstChild(script.Score.Value)
	print(player:WaitForChild(script.Score.Value).Value, "Plr streak")
	score:SetAsync(player.UserId, player:WaitForChild(script.Score.Value).Value)
end