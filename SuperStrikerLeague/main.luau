local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then
    warn("Failed to load interface provider!")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteEvent = Remotes:WaitForChild("RemoteEvent")

local ContinueSprint = RemoteEvent:WaitForChild("ContinueSprint")

local State = {
    SpeedOptimization = false,
    SpeedValue = 20,
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
    LoadingTitle = "Initializing...",
    LoadingSubtitle = "by tosubmit",
    Theme = "Default",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
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
    end,
})

SpeedTab:CreateToggle({
    Name = "Speed Optimization",
    CurrentValue = false,
    Callback = function(Value)
        State.SpeedOptimization = Value
    end,
})

RunService.Heartbeat:Connect(function(dt)
    local root = GetRoot()
    if not root then return end
    
    if State.SpeedOptimization then
        local hum = GetHumanoid()
        if hum and hum.MoveDirection.Magnitude > 0 then
            pcall(function()
                ContinueSprint:FireServer()
            end)
            
            local moveVector = hum.MoveDirection * State.SpeedValue * dt * 0.5
            root.CFrame = root.CFrame + moveVector
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if Rayfield:IsVisible() then
            Rayfield:SetVisibility(false)
        else
            Rayfield:SetVisibility(true)
        end
    end
end)
