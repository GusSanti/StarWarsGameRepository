-- SERVICES
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

-- CONSTANTS

-- VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local areateleports = workspace:WaitForChild("areateleports")

local newUI = playerGui:WaitForChild("NewUI")
local contentArea = newUI:WaitForChild("Areas"):WaitForChild("Main"):WaitForChild("Content"):WaitForChild("Content")

local framesToPreload = {}

-- FUNCTIONS

-- INIT

for _, v in contentArea:GetChildren() do
	if v:IsA("Frame") then
		table.insert(framesToPreload, v)
	end
end

task.spawn(function()
	if #framesToPreload > 0 then
		ContentProvider:PreloadAsync(framesToPreload)
	end
end)

for _, v in contentArea:GetChildren() do
	if v:IsA("Frame") then
		local buttonContainer = v:FindFirstChild("Button")
		local btn = buttonContainer and buttonContainer:FindFirstChild("Btn")

		if btn and btn:IsA("GuiButton") then
			btn.Activated:Connect(function()
				print("Clicou em:", v.Name)

				local character = player.Character

				if character and character:FindFirstChild("HumanoidRootPart") then
					local teleportPart = areateleports:FindFirstChild(v.Name)

					if teleportPart then
						character:PivotTo(teleportPart.CFrame)
					else
						warn("AVISO: Não foi encontrada a part de teleporte para '" .. v.Name .. "'. Verifique letras maiúsculas/minúsculas e espaços.")
					end
				end

				if _G.CloseAll then
					_G.CloseAll()
				end
			end)
		end
	end
end