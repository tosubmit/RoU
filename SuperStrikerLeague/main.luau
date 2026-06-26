if _G.SSL_AutomationConnections then
    for _, connection in ipairs(_G.SSL_AutomationConnections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
end
_G.SSL_AutomationConnections = {}

if _G.SSL_AutomationWindow then
    pcall(function() _G.SSL_AutomationWindow:Destroy() end)
end

local currentSession = {}
_G.CurrentSSLSession = currentSession

local success, Fluent = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)

if not success or not Fluent then
    warn("Failed to load interface provider!")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemoteEvent = Remotes:WaitForChild("RemoteEvent")

local ContinueSprint = RemoteEvent:WaitForChild("ContinueSprint")
local ToggleSprint = RemoteEvent:WaitForChild("ToggleSprint")

local State = {
    MovementOptimization = false,
    VelocityScaling = 20,
    AutomatedInteraction = false,
}

local Character, RootPart, Humanoid
local CachedBall = nil
local CachedGoal = nil

local function UpdateCharacter(char)
    Character = char
    RootPart = char:WaitForChild("HumanoidRootPart", 5)
    Humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
end

if LocalPlayer.Character then
    UpdateCharacter(LocalPlayer.Character)
end

local charConn = LocalPlayer.CharacterAdded:Connect(UpdateCharacter)
table.insert(_G.SSL_AutomationConnections, charConn)

local teamConn = LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    CachedGoal = nil
end)
table.insert(_G.SSL_AutomationConnections, teamConn)

local function GetRoot()
    if RootPart and RootPart.Parent then
        return RootPart
    end
    local char = LocalPlayer.Character
    RootPart = char and char:FindFirstChild("HumanoidRootPart")
    return RootPart
end

local function GetHumanoid()
    if Humanoid and Humanoid.Parent then
        return Humanoid
    end
    local char = LocalPlayer.Character
    Humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
    return Humanoid
end

local function GetBall()
    if CachedBall and CachedBall.Parent and CachedBall.Name == "Ball" then
        return CachedBall
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Ball" and child:IsA("BasePart") then
            CachedBall = child
            return child
        end
    end
    local gameProps = workspace:FindFirstChild("GameProps") or workspace:FindFirstChild("Game")
    if gameProps then
        local b = gameProps:FindFirstChild("Ball")
        if b and b:IsA("BasePart") then
            CachedBall = b
            return b
        end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Ball" and v:IsA("BasePart") then
            CachedBall = v
            return v
        end
    end
    return nil
end

local function SafeTeleport(targetPos)
    local root = GetRoot() or RootPart
    if not root then return end
    local distance = (root.Position - targetPos).Magnitude
    if distance < 1 then return end
    local maxSpeed = 300
    local stepDuration = 0.03
    local stepSize = maxSpeed * stepDuration
    local steps = math.ceil(distance / stepSize)
    for i = 1, steps do
        if not root or not root.Parent then break end
        local alpha = i / steps
        root.CFrame = root.CFrame:Lerp(CFrame.new(targetPos), alpha)
        task.wait(stepDuration)
    end
end

local function GetOpponentGoal()
    if CachedGoal and CachedGoal.Parent then
        return CachedGoal
    end
    local localPlayerTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""
    local targetGoalName = "BlueGoal"
    if localPlayerTeam == "Blue" or localPlayerTeam:lower():find("blue") then
        targetGoalName = "RedGoal"
    elseif localPlayerTeam == "Red" or localPlayerTeam:lower():find("red") then
        targetGoalName = "BlueGoal"
    else
        targetGoalName = "RedGoal"
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name:lower():find(targetGoalName:lower()) or (v.Name:lower():find("goal") and not v.Name:lower():find(localPlayerTeam:lower())) then
            if v:IsA("BasePart") or v:IsA("Model") then
                CachedGoal = v
                return v
            end
        end
    end
    return nil
end

local function TeleportToOpponentGoal()
    local goal = GetOpponentGoal()
    if goal then
        local pos = goal:IsA("Model") and goal:GetPivot().Position or goal.Position
        SafeTeleport(pos + Vector3.new(0, 3, 0))
    end
end

local function GrabPowerups()
    local root = GetRoot() or RootPart
    if not root then return end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name:lower():find("powerup") and v:FindFirstChildWhichIsA("TouchInterest") then
            firetouchinterest(root, v, 0)
            firetouchinterest(root, v, 1)
        end
    end
end

local Window = Fluent:CreateWindow({
    Title = "Super Striker League",
    SubTitle = "by github.com/tosubmit",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

_G.SSL_AutomationWindow = Window

local Tabs = {
    Main = Window:AddTab({ Title = "Movement", Icon = "run" }),
    Automation = Window:AddTab({ Title = "Automation", Icon = "gamepad" })
}

local Toggle = Tabs.Main:AddToggle("VelocityToggle", {
    Title = "Velocity Optimization",
    Default = false
})

Toggle:OnChanged(function()
    State.MovementOptimization = Toggle.Value
end)

local Slider = Tabs.Main:AddSlider("VelocitySlider", {
    Title = "Velocity Scaling",
    Min = 16,
    Max = 200,
    Default = 20,
    Rounding = 0,
    Callback = function(Value)
        State.VelocityScaling = Value
    end
})

Tabs.Main:AddButton({
    Title = "Trigger Sprint State",
    Callback = function()
        pcall(function()
            ToggleSprint:FireServer(true)
        end)
    end
})

local GrabToggle = Tabs.Automation:AddToggle("InteractionToggle", {
    Title = "Automated Interaction",
    Default = false
})

GrabToggle:OnChanged(function()
    State.AutomatedInteraction = GrabToggle.Value
end)

Tabs.Automation:AddButton({
    Title = "Relocate to Ball",
    Callback = function()
        local ball = GetBall()
        if ball then
            SafeTeleport(ball.Position)
        end
    end
})

Tabs.Automation:AddButton({
    Title = "Relocate to Opposition Goal",
    Callback = function()
        TeleportToOpponentGoal()
    end
})

Tabs.Automation:AddButton({
    Title = "Acquire Field Assets",
    Callback = function()
        GrabPowerups()
    end
})

local lastSprintFire = 0
local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not State.MovementOptimization then return end
    
    local root = GetRoot() or RootPart
    local hum = GetHumanoid() or Humanoid
    if not root or not hum or not root.Parent or not hum.Parent then
        local char = LocalPlayer.Character
        if char then
            RootPart = char:FindFirstChild("HumanoidRootPart")
            Humanoid = char:FindFirstChild("Humanoid")
        end
        return
    end
    
    if hum.MoveDirection.Magnitude > 0 then
        local now = os.clock()
        if now - lastSprintFire >= 0.1 then
            lastSprintFire = now
            pcall(function()
                ContinueSprint:FireServer()
            end)
        end
        
        local moveVector = hum.MoveDirection * State.VelocityScaling * dt * 0.5
        root.CFrame = root.CFrame + moveVector
    end
end)

table.insert(_G.SSL_AutomationConnections, heartbeatConn)

task.spawn(function()
    while _G.CurrentSSLSession == currentSession do
        if State.AutomatedInteraction then
            local root = GetRoot() or RootPart
            local ball = GetBall()
            if root and ball then
                pcall(function()
                    firetouchinterest(root, ball, 0)
                    firetouchinterest(root, ball, 1)
                end)
            end
        end
        task.wait(0.1)
    end
end)
