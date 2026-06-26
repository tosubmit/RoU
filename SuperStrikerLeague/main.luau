if _G.SSL_AutomationConnections then
    for _, connection in ipairs(_G.SSL_AutomationConnections) do
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end
end
_G.SSL_AutomationConnections = {}

if _G.SSL_Library then
    pcall(function() _G.SSL_Library:Unload() end)
end

local currentSession = {}
_G.CurrentSSLSession = currentSession

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local success, Library = pcall(function()
    return loadstring(game:HttpGet(repo .. 'Library.lua'))()
end)

if not success or not Library then
    warn("Failed to load interface provider!")
    return
end

_G.SSL_Library = Library

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
local BodyVelocity = nil

local function UpdateCharacter(char)
    Character = char
    RootPart = char:WaitForChild("HumanoidRootPart", 5)
    Humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if RootPart then
        for _, v in ipairs(RootPart:GetChildren()) do
            if v:IsA("BodyVelocity") then
                pcall(function() v:Destroy() end)
            end
        end
    end
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
    
    local ping = 100
    pcall(function()
        ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    
    local baseSpeed = 120
    if ping > 300 then
        baseSpeed = 35
    elseif ping > 150 then
        baseSpeed = 70
    end
    
    local stepDuration = 0.04
    local stepSize = baseSpeed * stepDuration
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

local Window = Library:CreateWindow({
    Title = 'Super Striker League | by github.com/tosubmit',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab('Movement'),
    Automation = Window:AddTab('Automation')
}

local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Velocity & Sprint')
local RightGroupBox = Tabs.Automation:AddLeftGroupbox('Match Controls')

local VelocityToggle = LeftGroupBox:AddToggle('VelocityToggle', {
    Text = 'Velocity Optimization',
    Default = false
})

VelocityToggle:OnChanged(function()
    State.MovementOptimization = VelocityToggle.Value
end)

local VelocitySlider = LeftGroupBox:AddSlider('VelocitySlider', {
    Text = 'Velocity Scaling',
    Default = 20,
    Min = 16,
    Max = 100,
    Rounding = 0,
    Compact = false
})

VelocitySlider:OnChanged(function()
    State.VelocityScaling = VelocitySlider.Value
end)

LeftGroupBox:AddButton({
    Text = 'Trigger Sprint State',
    Func = function()
        pcall(function()
            ToggleSprint:FireServer(true)
        end)
    end
})

local InteractionToggle = RightGroupBox:AddToggle('InteractionToggle', {
    Text = 'Automated Interaction',
    Default = false
})

InteractionToggle:OnChanged(function()
    State.AutomatedInteraction = InteractionToggle.Value
end)

RightGroupBox:AddButton({
    Text = 'Relocate to Ball',
    Func = function()
        local ball = GetBall()
        if ball then
            SafeTeleport(ball.Position)
        end
    end
})

RightGroupBox:AddButton({
    Text = 'Relocate to Opposition Goal',
    Func = function()
        TeleportToOpponentGoal()
    end
})

RightGroupBox:AddButton({
    Text = 'Acquire Field Assets',
    Func = function()
        GrabPowerups()
    end
})

local lastSprintFire = 0
local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    local root = GetRoot() or RootPart
    local hum = GetHumanoid() or Humanoid
    
    if not root or not hum or not root.Parent or not hum.Parent then
        local char = LocalPlayer.Character
        if char then
            RootPart = char:FindFirstChild("HumanoidRootPart")
            Humanoid = char:FindFirstChild("Humanoid")
        end
        if BodyVelocity then
            pcall(function() BodyVelocity:Destroy() end)
            BodyVelocity = nil
        end
        return
    end
    
    if State.MovementOptimization then
        if hum.MoveDirection.Magnitude > 0 then
            if not BodyVelocity or BodyVelocity.Parent ~= root then
                pcall(function() if BodyVelocity then BodyVelocity:Destroy() end end)
                BodyVelocity = Instance.new("BodyVelocity")
                BodyVelocity.MaxForce = Vector3.new(1000000, 0, 1000000)
                BodyVelocity.Velocity = Vector3.new(0, 0, 0)
                BodyVelocity.Parent = root
            end
            
            local now = os.clock()
            if now - lastSprintFire >= 0.1 then
                lastSprintFire = now
                pcall(function()
                    ContinueSprint:FireServer()
                end)
            end
            
            BodyVelocity.Velocity = hum.MoveDirection * State.VelocityScaling
        else
            if BodyVelocity then
                BodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end
    else
        if BodyVelocity then
            pcall(function() BodyVelocity:Destroy() end)
            BodyVelocity = nil
        end
    end
end)

table.insert(_G.SSL_AutomationConnections, heartbeatConn)

task.spawn(function()
    while _G.CurrentSSLSession == currentSession do
        if State.AutomatedInteraction then
            local root = GetRoot() or RootPart
            local ball = GetBall()
            if root and ball then
                local distance = (root.Position - ball.Position).Magnitude
                if distance <= 35 then
                    pcall(function()
                        firetouchinterest(root, ball, 0)
                        firetouchinterest(root, ball, 1)
                    end)
                end
            end
        end
        task.wait(0.1)
    end
end)
