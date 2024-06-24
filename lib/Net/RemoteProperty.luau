local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Parent.Utilities.Table)
local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }
local Signal = require(script.Parent.Parent.Parent.Signal) :: { any }

local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string, InitialValue: unknown)
    local self = setmetatable({}, RemoteProperty)
    
    self.Cleaner = Trove.new()
    self.Event = Net:CreateEvent(Name)

    if RunService:IsServer() then
        self.Values = {}
        self._InitialValue = InitialValue

        local function OnPlayerAdded(Player: Player)
            self.Values[Player] = if typeof(InitialValue) == "table" then Util.CopyTable(self._InitialValue :: { any }, true) else self._InitialValue
        end

        for _, Player in PlayerService:GetPlayers() do
            task.spawn(OnPlayerAdded, Player)
        end

        self.Cleaner:Connect(PlayerService.PlayerAdded, OnPlayerAdded)
        
        self.Cleaner:Connect(PlayerService.PlayerRemoving, function(Player: Player)
            self.Values[Player] = nil
        end)
    else
        self.Value = InitialValue
        self.Changed = Signal.new()

        self.Cleaner:Add(self.Event:Connect(function(Value: any)
            self.Value = Value
            self.Changed:Fire(Value)
        end), "Disconnect")
    end

    return self
end

if RunService:IsServer() then
    function RemoteProperty:GetFor(Player: Player): any
        return self.Values[Player]
    end

    function RemoteProperty:SetFor(Player: Player, Value: any)
        self.Values[Player] = Value
        self.Event:Fire(Player, Value)
    end

    function RemoteProperty:Set(Value)
        self._InitialValue = Value
        
        for Player in self.Values do
            self.Values[Player] = Value
            self.Event:Fire(Player, Value)
        end
    end
else
    function RemoteProperty:Get(): any
        return self.Value
    end

    function RemoteProperty:Observe(Callback: (any) -> ())
        task.spawn(Callback, self.Value)
        return self.Changed:Connect(Callback)
    end
end

function RemoteProperty:Destroy()
    self.Cleaner:Destroy()
end

return RemoteProperty