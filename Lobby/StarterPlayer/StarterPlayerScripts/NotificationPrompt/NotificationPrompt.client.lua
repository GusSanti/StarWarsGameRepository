local ExperienceNotificationService = game:GetService('ExperienceNotificationService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local TutorialState = require(ReplicatedStorage.Modules.TutorialState)

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local function canPromptOptIn()
    local success, canPrompt = pcall(function()
        return ExperienceNotificationService:CanPromptOptInAsync()
    end)
    return success and canPrompt
end

local tutorialState = TutorialState.normalizeSnapshot(TutorialState.snapshot(TutorialState.waitForPlayerData(Player)))

if TutorialState.isVictoryCompleted(tutorialState) then
    -- prompt
    task.wait(30)
    local success, canPrompt = canPromptOptIn()

    if canPrompt then
        ExperienceNotificationService:PromptOptIn()
    end
end
