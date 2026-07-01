local rfOk, Rayfield = pcall(function()
	return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not rfOk or type(Rayfield) ~= "table" then
	return
end

if getgenv().SSL_Active then
	return getgenv().SSL_Unload
end
getgenv().SSL_Active = true

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	Rayfield:Notify({
		Title = "Super Striker League",
		Content = "Remotes folder not found. Join a match first, then run.",
		Duration = 7,
	})
	getgenv().SSL_Active = false
	return
end

local RemoteFunctionFolder = Remotes:WaitForChild("RemoteFunction", 10)
local RemoteEventFolder    = Remotes:WaitForChild("RemoteEvent", 10)

local function getRF(name)
	return RemoteFunctionFolder and RemoteFunctionFolder:FindFirstChild(name)
end
local function getRE(name)
	return RemoteEventFolder and RemoteEventFolder:FindFirstChild(name)
end

local R = {
	ShootBall = getRF("ShootBall"),
	PassBall  = getRF("PassBall"),
	PowerUp   = getRF("UsePowerUp"),
	Activate  = getRE("ActivateSuper"),
	Continue  = getRE("ContinueSprint"),
	Toggle    = getRE("ToggleSprint"),
}

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local function tryRequire(name)
	if not Modules then return nil end
	local child = Modules:FindFirstChild(name)
	if not child then return nil end
	local ok, mod = pcall(require, child)
	if ok then return mod end
	return nil
end

local GameUtil      = tryRequire("GameUtil")
local SharedActions = tryRequire("SharedActions")
local Calculations  = GameUtil and GameUtil.Calculations

local State = {
	WalkSpeedEnabled = false,
	WalkSpeed        = 21,
	InfiniteStamina  = false,
	AutoSprint       = false,

	ShotChargeRatio  = 1.0,
	PassChargeRatio  = 0.6,

	AutoGoal         = false,
	AutoGoalDelay    = 0.35,

	AutoTackle       = false,
	AutoTackleRange  = 20,
	AutoTackleDelay  = 0.25,

	AutoPowerUp      = false,
	AutoPowerUpDelay = 1.0,

	AutoSuper        = false,
	AutoSuperDelay   = 5,

	BallESP          = false,
	AntiRagdoll      = false,
	AntiWhiffPenalty = false,
}

local Connections = {}
local function bind(conn)
	Connections[#Connections + 1] = conn
	return conn
end

local function getChar()
	return LocalPlayer.Character
end
local function getRoot()
	local c = getChar()
	return c and (c.PrimaryPart or c:FindFirstChild("HumanoidRootPart"))
end
local function getHumanoid()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function ballModel()
	return Workspace:FindFirstChild("!Ball")
end
local function ballPart()
	local m = ballModel()
	if not m then return nil end
	if m:IsA("BasePart") then return m end
	return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end

local function myData()
	if not GameUtil then return nil end
	local ok, d = pcall(GameUtil.GetReplicaPlayerData, LocalPlayer.Name)
	if ok then return d end
end
local function ballDataReplica()
	if not GameUtil then return nil end
	local ok, b = pcall(GameUtil.GetBallData)
	if ok then return b end
end

local function ballOwnerName()
	local b = ballDataReplica()
	if b then
		local ok, name = pcall(function() return b:Get("OwnerName") end)
		if ok then return name end
	end
	return nil
end

local function iOwnBall()
	local owner = ballOwnerName()
	if owner ~= nil then
		return owner == LocalPlayer.Name
	end
	local bp, root = ballPart(), getRoot()
	if bp and root then
		return (bp.Position - root.Position).Magnitude < 6
	end
	return false
end

local function myTeamId()
	local d = myData()
	if not d then return nil end
	local ok, td = pcall(function() return d:Get("TeamData") end)
	if ok and td then return td:Get("TeamId") end
end

local function goalDetectorPosition(goalId)
	local map = Workspace:FindFirstChild("!MAP")
	if not map then return nil end
	local key = map:FindFirstChild("!KeyElements")
	if not key then return nil end
	local goal = key:FindFirstChild("!Goal_" .. tostring(goalId))
	if not goal then return nil end
	local det = goal:FindFirstChild("!GoalDetector")
	if not det then return nil end
	return det.Position + det.CFrame.LookVector * 2
end

local function enemyGoalPosition()
	local teamId = myTeamId()
	if teamId then
		local pos = goalDetectorPosition(teamId % 2 + 1)
		if pos then return pos end
	end
	local root = getRoot()
	local map = Workspace:FindFirstChild("!MAP")
	local key = map and map:FindFirstChild("!KeyElements")
	if root and key then
		local best, bestDist
		for _, ch in ipairs(key:GetChildren()) do
			if ch.Name:match("^!Goal_") then
				local det = ch:FindFirstChild("!GoalDetector")
				if det then
					local d = (det.Position - root.Position).Magnitude
					if not bestDist or d > bestDist then
						bestDist = d
						best = det.Position + det.CFrame.LookVector * 2
					end
				end
			end
		end
		if best then return best end
	end
	return nil
end

local function reticleTarget()
	if Calculations then
		local ok, pos = pcall(function()
			return Calculations.GetTargetPositionAtReticle(150)
		end)
		if ok and pos then return pos end
	end
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.CFrame.Position + cam.CFrame.LookVector * 150
	end
	return nil
end

local function moveVector()
	local hum = getHumanoid()
	if hum and hum.MoveDirection.Magnitude > 0 then
		return hum.MoveDirection.Unit
	end
	local root = getRoot()
	if root then return root.CFrame.LookVector end
	return Vector3.new(0, 0, 0)
end

local function faceTarget(targetPos)
	local root = getRoot()
	if root and targetPos then
		pcall(function()
			root.CFrame = CFrame.new(root.Position,
				Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
		end)
	end
end

local function doShoot(targetPos)
	if not R.ShootBall then return end
	targetPos = targetPos or reticleTarget()
	if not targetPos then return end
	faceTarget(targetPos)
	pcall(function()
		R.ShootBall:InvokeServer(targetPos, moveVector())
	end)
end

local function doPass(targetPos, ratio)
	if not R.PassBall then return end
	targetPos = targetPos or reticleTarget()
	if not targetPos then return end
	ratio = math.clamp(ratio or State.PassChargeRatio, 0, 1)
	pcall(function()
		R.PassBall:InvokeServer(targetPos, ratio)
	end)
end

local function doSuper()
	if R.Activate then
		pcall(function() R.Activate:FireServer() end)
	end
end

local function doPowerUp(targetPos)
	if not R.PowerUp then return end
	targetPos = targetPos or reticleTarget()
	if not targetPos then return end
	pcall(function()
		R.PowerUp:InvokeServer(targetPos)
	end)
end

local function doDefensive(kind, direction)
	direction = direction or moveVector()
	if direction.Magnitude == 0 then
		local root = getRoot()
		if root then direction = root.CFrame.LookVector end
	end
	if SharedActions and SharedActions.DefensiveMove then
		pcall(function()
			SharedActions.DefensiveMove(LocalPlayer.Name, direction, kind)
		end)
	end
end
local function doTackle(direction) doDefensive("Tackle", direction) end
local function doDeke(direction) doDefensive("Deke", direction) end

local originalGetWalkSpeed
local function installWalkSpeedHook()
	if originalGetWalkSpeed then return end
	if not (Calculations and type(Calculations.GetWalkSpeed) == "function") then return end
	originalGetWalkSpeed = Calculations.GetWalkSpeed
	Calculations.GetWalkSpeed = function(...)
		local base = originalGetWalkSpeed(...)
		if State.WalkSpeedEnabled and base and base > 0 then
			return State.WalkSpeed
		end
		return base
	end
end
local function restoreWalkSpeedHook()
	if originalGetWalkSpeed then
		Calculations.GetWalkSpeed = originalGetWalkSpeed
		originalGetWalkSpeed = nil
	end
end
installWalkSpeedHook()

local function predictField(container, key, value)
	if not container then return end
	pcall(function()
		if container.Predict then
			container:Predict(key, value)
		elseif container.Set then
			container:Set(key, value)
		end
	end)
end

local lastSprint, lastGoal, lastSuper, lastTackle, lastPowerUp = 0, 0, 0, 0, 0

bind(RunService.Heartbeat:Connect(function()
	local now = os.clock()

	if State.AutoSprint and R.Continue and not iOwnBall() then
		if now - lastSprint >= 0.25 then
			lastSprint = now
			pcall(function() R.Continue:FireServer() end)
		end
	end

	if State.InfiniteStamina then
		local d = myData()
		if d then
			pcall(function()
				local sd = d:Get("StaminaData")
				if sd and sd:Get("Stamina") < 100 then
					predictField(sd, "Stamina", 100)
				end
			end)
		end
	end

	if State.AntiRagdoll then
		local d = myData()
		if d then
			pcall(function()
				if d:Get("IsKnockedDown") then
					predictField(d, "IsKnockedDown", false)
				end
			end)
		end
	end

	if State.AntiWhiffPenalty then
		local d = myData()
		if d then
			pcall(function()
				if d:Get("TackleWhiffPenaltyActive") then
					predictField(d, "TackleWhiffPenaltyActive", false)
				end
			end)
		end
	end

	if State.AutoGoal and iOwnBall() then
		if now - lastGoal >= State.AutoGoalDelay then
			lastGoal = now
			local goal = enemyGoalPosition()
			if goal then doShoot(goal) end
		end
	end

	if State.AutoTackle and not iOwnBall() then
		if now - lastTackle >= State.AutoTackleDelay then
			local bp = ballPart()
			local root = getRoot()
			local owner = ballOwnerName()
			if bp and root and owner ~= LocalPlayer.Name then
				local flat = Vector3.new(bp.Position.X - root.Position.X, 0, bp.Position.Z - root.Position.Z)
				if flat.Magnitude <= State.AutoTackleRange and flat.Magnitude > 0 then
					lastTackle = now
					doTackle(flat.Unit)
				end
			end
		end
	end

	if State.AutoPowerUp and R.PowerUp then
		if now - lastPowerUp >= State.AutoPowerUpDelay then
			local d = myData()
			local stored = true
			if d then
				stored = select(2, pcall(function()
					return d:Get("PowerUpData"):Get("PowerUpStored")
				end))
			end
			if stored then
				lastPowerUp = now
				doPowerUp(enemyGoalPosition() or reticleTarget())
			end
		end
	end

	if State.AutoSuper and R.Activate then
		if now - lastSuper >= State.AutoSuperDelay then
			lastSuper = now
			doSuper()
		end
	end
end))

local espGui
bind(RunService.RenderStepped:Connect(function()
	if not State.BallESP then
		if espGui then espGui:Destroy(); espGui = nil end
		return
	end
	local part = ballPart()
	if not part then return end
	if not espGui or espGui.Adornee ~= part then
		if espGui then espGui:Destroy() end
		espGui = Instance.new("BillboardGui")
		espGui.Name = "SSL_BallESP"
		espGui.Size = UDim2.fromOffset(70, 70)
		espGui.AlwaysOnTop = true
		espGui.Adornee = part
		espGui.Parent = part
		local f = Instance.new("Frame", espGui)
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
		f.BackgroundTransparency = 0.35
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	end
end))

local Window = Rayfield:CreateWindow({
	Name = "Super Striker League",
	LoadingTitle = "SSL Menu",
	LoadingSubtitle = "by duckesteles",
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})

local Move = Window:CreateTab("Movement", 4483362458)
Move:CreateSection("Speed")
if Calculations and type(Calculations.GetWalkSpeed) == "function" then
	Move:CreateToggle({
		Name = "WalkSpeed Override",
		CurrentValue = false,
		Callback = function(v) State.WalkSpeedEnabled = v end,
	})
	Move:CreateSlider({
		Name = "WalkSpeed",
		Range = {16, 120},
		Increment = 1,
		CurrentValue = 21,
		Callback = function(v) State.WalkSpeed = v end,
	})
else
	Move:CreateParagraph({ Title = "WalkSpeed", Content = "Speed hook unavailable in this executor (module require failed)." })
end
Move:CreateSection("Stamina")
Move:CreateToggle({
	Name = "Infinite Stamina",
	CurrentValue = false,
	Callback = function(v) State.InfiniteStamina = v end,
})
Move:CreateToggle({
	Name = "Auto Sprint",
	CurrentValue = false,
	Callback = function(v) State.AutoSprint = v end,
})

local Ball = Window:CreateTab("Ball", 4483362458)
Ball:CreateSection("Shooting")
Ball:CreateSlider({
	Name = "Shot Charge %",
	Range = {0, 100},
	Increment = 5,
	CurrentValue = 100,
	Callback = function(v) State.ShotChargeRatio = v / 100 end,
})
Ball:CreateButton({
	Name = "Shoot at Enemy Goal (now)",
	Callback = function()
		local goal = enemyGoalPosition()
		if goal then doShoot(goal) else
			Rayfield:Notify({ Title = "SSL", Content = "No goal found.", Duration = 4 })
		end
	end,
})
Ball:CreateToggle({
	Name = "Auto Goal",
	CurrentValue = false,
	Callback = function(v) State.AutoGoal = v end,
})
Ball:CreateSlider({
	Name = "Auto Goal Delay (s)",
	Range = {0, 3},
	Increment = 0.05,
	CurrentValue = 0.35,
	Callback = function(v) State.AutoGoalDelay = v end,
})
Ball:CreateSection("Passing")
Ball:CreateSlider({
	Name = "Pass Charge %",
	Range = {0, 100},
	Increment = 5,
	CurrentValue = 60,
	Callback = function(v) State.PassChargeRatio = v / 100 end,
})
Ball:CreateButton({
	Name = "Pass to Reticle (now)",
	Callback = function() doPass(nil, State.PassChargeRatio) end,
})
Ball:CreateSection("Power / Super")
Ball:CreateButton({
	Name = "Use Power-Up (now)",
	Callback = function() doPowerUp(enemyGoalPosition() or reticleTarget()) end,
})
Ball:CreateToggle({
	Name = "Auto Power-Up",
	CurrentValue = false,
	Callback = function(v) State.AutoPowerUp = v end,
})
Ball:CreateButton({
	Name = "Activate Super (now)",
	Callback = doSuper,
})
Ball:CreateToggle({
	Name = "Auto Super",
	CurrentValue = false,
	Callback = function(v) State.AutoSuper = v end,
})
Ball:CreateSlider({
	Name = "Auto Super Delay (s)",
	Range = {1, 30},
	Increment = 1,
	CurrentValue = 5,
	Callback = function(v) State.AutoSuperDelay = v end,
})

local Defense = Window:CreateTab("Defense", 4483362458)
if SharedActions and SharedActions.DefensiveMove then
	Defense:CreateSection("Tackle")
	Defense:CreateButton({
		Name = "Tackle (toward ball)",
		Callback = function()
			local bp = ballPart()
			local root = getRoot()
			if bp and root then
				local flat = Vector3.new(bp.Position.X - root.Position.X, 0, bp.Position.Z - root.Position.Z)
				doTackle(flat.Magnitude > 0 and flat.Unit or nil)
			else
				doTackle()
			end
		end,
	})
	Defense:CreateToggle({
		Name = "Auto Tackle (ball carrier in range)",
		CurrentValue = false,
		Callback = function(v) State.AutoTackle = v end,
	})
	Defense:CreateSlider({
		Name = "Auto Tackle Range",
		Range = {5, 37},
		Increment = 1,
		CurrentValue = 20,
		Callback = function(v) State.AutoTackleRange = v end,
	})
	Defense:CreateSlider({
		Name = "Auto Tackle Delay (s)",
		Range = {0.1, 2},
		Increment = 0.05,
		CurrentValue = 0.25,
		Callback = function(v) State.AutoTackleDelay = v end,
	})
	Defense:CreateSection("Deke")
	Defense:CreateButton({
		Name = "Deke (dodge)",
		Callback = function() doDeke() end,
	})
else
	Defense:CreateParagraph({ Title = "Tackle / Deke", Content = "Defensive moves unavailable in this executor (module require failed)." })
end
Defense:CreateSection("Protection")
Defense:CreateToggle({
	Name = "Anti Ragdoll",
	CurrentValue = false,
	Callback = function(v) State.AntiRagdoll = v end,
})
Defense:CreateToggle({
	Name = "Anti Whiff Penalty",
	CurrentValue = false,
	Callback = function(v) State.AntiWhiffPenalty = v end,
})

local Util = Window:CreateTab("Utility", 4483362458)
Util:CreateSection("Visual")
Util:CreateToggle({
	Name = "Ball ESP",
	CurrentValue = false,
	Callback = function(v) State.BallESP = v end,
})

local Settings = Window:CreateTab("Settings", 4483362458)
Settings:CreateParagraph({
	Title = "Status",
	Content = ("Remotes: %s | Modules: %s"):format(
		(R.ShootBall and R.PassBall) and "OK" or "MISSING",
		(GameUtil and SharedActions) and "OK" or "PARTIAL"
	),
})
Settings:CreateButton({
	Name = "Unload",
	Callback = function()
		if getgenv().SSL_Unload then getgenv().SSL_Unload() end
	end,
})

getgenv().SSL_Unload = function()
	for _, c in ipairs(Connections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(Connections)
	restoreWalkSpeedHook()
	if espGui then pcall(function() espGui:Destroy() end) end
	pcall(function() Rayfield:Destroy() end)
	getgenv().SSL_Active = false
	getgenv().SSL_Unload = nil
end

Rayfield:Notify({
	Title = "Super Striker League",
	Content = "Loaded. Check Settings tab for remote/module status.",
	Duration = 6,
})

return getgenv().SSL_Unload
