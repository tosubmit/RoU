--[[
	SuperStrikerLeague
	Author: tosubmit
	https://github.com/tosubmit/RoU
]]

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or type(Rayfield) ~= "table" then
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteEvent = Remotes:WaitForChild("RemoteEvent")
local ContinueSprint = RemoteEvent:WaitForChild("ContinueSprint")

local State = {
    SpeedOptimization = false,
    SpeedValue = 20
}

local function GetRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local Window = Rayfield:CreateWindow({
    Name = "Super Striker League",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by tosubmit",
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local SpeedTab = Window:CreateTab("Speed", 4483362458)
SpeedTab:CreateSection("Speed Configuration")

SpeedTab:CreateSlider({
    Name = "Speed Multiplier",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = 20,
    Callback = function(Value)
        State.SpeedValue = Value
    end
})

SpeedTab:CreateToggle({
    Name = "Speed Optimization",
    CurrentValue = false,
    Callback = function(Value)
        State.SpeedOptimization = Value
    end
})

local lastFireTime = 0

RunService.Heartbeat:Connect(function(dt)
    if not State.SpeedOptimization then return end

    local root = GetRoot()
    local hum = GetHumanoid()

    if root and hum and hum.MoveDirection.Magnitude > 0 then
        local currentTime = os.clock()
        
        if currentTime - lastFireTime >= 0.2 then
            pcall(function()
                ContinueSprint:FireServer()
            end)
            lastFireTime = currentTime
        end

        local moveVector = hum.MoveDirection * State.SpeedValue * dt * 0.5
        root.CFrame = root.CFrame + moveVector
    end
end)
