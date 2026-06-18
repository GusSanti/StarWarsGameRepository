-- SERVICES
local StarterGui = game:GetService("StarterGui")

-- CONSTANTS
local MAX_RETRIES = 5
local RETRY_DELAY = 0.5

-- VARIABLES
local isInventoryDisabled = false
local attempts = 0

-- FUNCTIONS
local function disableBackpack()
	local success, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	if not success then
		warn("Falha ao tentar desativar o inventário nativo: " .. tostring(err))
		return false
	end

	return true
end

-- INIT
local function init()
	while not isInventoryDisabled and attempts < MAX_RETRIES do
		isInventoryDisabled = disableBackpack()

		if not isInventoryDisabled then
			attempts += 1
			task.wait(RETRY_DELAY)
		end
	end
end

init()