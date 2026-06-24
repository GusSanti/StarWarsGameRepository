local storyElevators = workspace:WaitForChild("StoryElevators", 10)
if storyElevators then
	for i,v in pairs(storyElevators:GetChildren()) do
		if v:IsA('Model') then
			local skript = script.ElevatorServer:Clone()
			skript.Parent = v
			skript.Enabled = true
		end
	end
else
	warn("StoryElevators was not found in Workspace.")
end


if script:FindFirstChild('RaidElevatorServer') then
	local raidElevators = workspace:WaitForChild("RaidElevators", 10)
	if raidElevators then
		for i,v in pairs(raidElevators:GetChildren()) do
			local skript = script.RaidElevatorServer:Clone()
			skript.Parent = v
			skript.Enabled = true
		end
	else
		warn("RaidElevators was not found in Workspace.")
	end
end

local versusElevators = workspace:WaitForChild("VersusElevators", 10)
if versusElevators then
	for i,v in versusElevators:GetChildren() do
		local skript = script.VersusElevatorServer:Clone()
		skript.Parent = v
		skript.Enabled = true
	end
else
	warn("VersusElevators was not found in Workspace.")
end
