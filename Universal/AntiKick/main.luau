if getgenv().SSL_Interception_Active then
    return
end
getgenv().SSL_Interception_Active = true

local Players: Players = game:GetService("Players")
local StarterGui: StarterGui = game:GetService("StarterGui")
local LocalPlayer: Player = Players.LocalPlayer

type GenericFunction = (...any) -> ...any

local function LogInterception(reason: any): ()
    warn(string.format("Execution intercepted. Reason: %s", type(reason) == "string" and reason or "Unknown"))
end

local OldKick: GenericFunction
OldKick = hookfunction(LocalPlayer.Kick, newcclosure(function(self: any, ...: any): ()
    if not checkcaller() and self == LocalPlayer then
        LogInterception((...))
        return
    end
    return OldKick(self, ...)
end))

local DummyKick: GenericFunction
DummyKick = newcclosure(function(self: any, ...: any): ()
    if not checkcaller() and self == LocalPlayer then
        LogInterception((...))
        return
    end
    return OldKick(self, ...)
end)

local OldNamecall: GenericFunction
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self: any, ...: any): any
    if not checkcaller() and self == LocalPlayer then
        local method: string = getnamecallmethod()
        if method == "Kick" or method == "kick" then
            LogInterception((...))
            return nil
        end
    end
    return OldNamecall(self, ...)
end))

local OldIndex: GenericFunction
OldIndex = hookmetamethod(game, "__index", newcclosure(function(self: any, key: any): any
    if not checkcaller() and self == LocalPlayer then
        if key == "Kick" or key == "kick" then
            return DummyKick
        end
    end
    return OldIndex(self, key)
end))

pcall(function(): ()
    local renv = getrenv()
    if renv and renv.debug and renv.debug.info then
        local OldDebugInfo: GenericFunction
        OldDebugInfo = hookfunction(renv.debug.info, newcclosure(function(...: any): any
            local target = (...)
            if target == DummyKick then
                return coroutine.yield(coroutine.running())
            end
            return OldDebugInfo(...)
        end))
    end
end)

pcall(function(): ()
    StarterGui:SetCore("SendNotification", {
        Title = "System",
        Text = "Interception Active",
        Duration = 5
    })
end)
