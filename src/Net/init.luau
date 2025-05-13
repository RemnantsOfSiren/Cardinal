local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local Net = IsServer and require(script.Server) or require(script.Client)

local RemoteSignal = require(script.RemoteSignal)
local RemoteProperty = require(script.RemoteProperty)

local function MakePacket(Bridge: string, Name: string, Args: { any })
    return {
        Net = Bridge,
        Args = Args,
        Event = Name,
    }
end

local Event = {}
Event.__index = Event

function Event.new(Bridge: string, Name: string)
    return setmetatable({
        Name = Name,
        Bridge = Bridge,
        _Invoke = nil,
        _Connections = {},
    }, Event)
end

function Event:Fire(Player, ...)
    local Packet = MakePacket(self.Bridge, self.Name, { ... })
    if IsServer then
        Net.ClientEvent.Fire(Player, Packet)
    else
        Net.ServerEvent.Fire(Packet)
    end
end

function Event:FireAll(...)
    if IsServer then
        Net.ClientEvent.FireAll(MakePacket(self.Bridge, self.Name, { ... }))
    end
end

function Event:FireAllExcept(List: { Player } | Player, ...)
    if IsServer then
        if typeof(List) ~= "table" then
            List = { List }
        end
        local PlayersInGame = Players:GetPlayers()
        for I = #PlayersInGame, 1, -1 do
            local Player = PlayersInGame[I]
            if table.find(List :: { Player }, Player) then
                table.remove(PlayersInGame, I)
            end
        end
        self:FireList(PlayersInGame, { ... })
    end
end

function Event:FireList(List: { Player }, ...)
    if IsServer then
        Net.ClientEvent.FireList(List, MakePacket(self.Bridge, self.Name, { ... }))
    end
end

function Event:SetCallback(Callback: (...any) -> nil)
    if not IsServer then
        error("SetCallback can only be called on the server.")
    end

    if self._Invoke then
        error(`Event {self.Name} already has a callback set. Only one callback can be set.`)
    end
    
    self._Invoke = Callback
end

function Event:Invoke(...)
    if not IsServer then
        return Net.RemoteFunction.Invoke(MakePacket(self.Bridge, self.Name, { ... }))
    end

    return nil
end

function Event:Connect(Callback: (...any) -> nil)
    table.insert(self._Connections, Callback)

    return {
        Disconnect = function()
            for I = #self._Connections, 1, -1 do
                if self._Connections[I] == Callback then
                    table.remove(self._Connections, I)
                    break
                end
            end
        end,
    }
end

local Bridges = {}

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(Name: string)
    if Bridges[Name] then
        return Bridges[Name]
    end

    local self = setmetatable({
        Name = Name,
        _Events = {},
    }, Bridge)

    Bridges[Name] = self

    return self
end

function Bridge:CreateEvent(Name: string)
    if self._Events[Name] then
        return self._Events[Name]
    end

    local _Event = Event.new(self.Name, Name)
    self._Events[Name] = _Event
    return _Event
end

if IsServer then
    Net.RemoteFunction.On(function(Player: Player, Packet)
        local Args = Packet.Args
        local EventName = Packet.Event
        local BridgeName = Packet.Net

        local _Bridge = Bridges[BridgeName]

        if not _Bridge then
            return
        end

        local _Event = _Bridge._Events[EventName]

        if _Event and _Event._Invoke then
            return _Event._Invoke(Player, unpack(Args))
        end

        return nil
    end)

    Net.ServerEvent.On(function(Player, Packet)
        local Args = Packet.Args
        local EventName = Packet.Event
        local BridgeName = Packet.Net

        local _Bridge = Bridges[BridgeName]

        if not _Bridge then
            return
        end

        local _Event = _Bridge._Events[EventName]

        if _Event and #_Event._Connections > 0 then
            for _, Callback in pairs(_Event._Connections) do
                task.spawn(Callback, Player, unpack(Args))
            end
        end
    end)
else
    Net.ClientEvent.On(function(Packet)
        local Args = Packet.Args
        local EventName = Packet.Event
        local BridgeName = Packet.Net
        
        local _Bridge = Bridges[BridgeName]

        if not _Bridge then
            return
        end

        local _Event = _Bridge._Events[EventName]

        if _Event and #_Event._Connections > 0 then
            for _, Callback in pairs(_Event._Connections) do
                task.spawn(Callback, unpack(Args))
            end
        end
    end)
end

return table.freeze({
	CreateSignal = RemoteSignal.new,
	CreateProperty = RemoteProperty.new,
	new = Bridge.new,
})
