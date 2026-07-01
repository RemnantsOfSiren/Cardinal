--!strict
--!optimize 2

--[=[
    @class RemoteSignal
    A class that represents a signal that can be used to comminucate between the server and the client.
]=]

--[=[
    @function new
    @within RemoteSignal
    @param Net ServerNet | ClientNet
    @param Name string
    @return RemoteSignal
    Creates a new RemoteSignal object.
]=]

--[=[
    @method Connect
    @within RemoteSignal
    @param Callback (...any) -> ()
    @return RBXScriptConnection

    Connects a function to the signal.
]=]

--[=[
    @method Fire
    @within RemoteSignal
    @param Players Player | { Player }
    @param ... any
    @return nil
    @server
    Fires the signal to the specified players.
]=]

--[=[
    @method FireAll
    @within RemoteSignal
    @param ... any
    @return nil
    @server
    Fires the signal to all players.
]=]

--[=[
    @method FireAllExcept
    @within RemoteSignal
    @param Players Player | { Player }
    @param ... any
    @return nil
    @server
    Fires the signal to all players except the ones specified.
]=]

--[=[
    @method Fire
    @within RemoteSignal
    @param ... any
    @return nil
    @client
    Fires the signal to the specified players.
]=]

local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

type RemoteSignal = typeof(setmetatable({} :: {
    _Name: string,
    _Event: any,
}, RemoteSignal))

export type ServerRemoteSignal = RemoteSignal & {
    Fire: (self: ServerRemoteSignal, Players: { Player } | Player, ...any) -> nil,
    Once: (self: ServerRemoteSignal, Callback: (Player: Player, ...any) -> ()) -> RBXScriptConnection,
    Connect: (self: ServerRemoteSignal, Callback: (Player: Player, ...any) -> ()) -> RBXScriptConnection,
    FireAll: (self: ServerRemoteSignal, ...any) -> nil,
    FireAllExcept: (self: ServerRemoteSignal, Exempt: { Player } | Player, ...any) -> nil,
}

export type ClientRemoteSignal = RemoteSignal & {
    Fire: (self: ClientRemoteSignal, ...any) -> nil,
    Once: (self: ClientRemoteSignal, Callback: (...any) -> ()) -> RBXScriptConnection,
    Connect: (self: ClientRemoteSignal, Callback: (...any) -> ()) -> RBXScriptConnection,
}

function RemoteSignal.new(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string)
	return setmetatable({
        _Name = Name,
        _Event = Net:CreateEvent(Name),
    }, RemoteSignal)
end

function RemoteSignal:Destroy()
	table.clear(self)
end

local ClientSignal = {}
ClientSignal.__index = ClientSignal
setmetatable(ClientSignal, RemoteSignal)

local function MakeClientSignal(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string) : ClientRemoteSignal
    local self = setmetatable(RemoteSignal.new(Net, Name) :: any, ClientSignal) :: any
    return self :: ClientRemoteSignal
end

function ClientSignal:Fire(...)
    self._Event:Fire(...)
end

function ClientSignal:Connect(Callback: (...any) -> ())
    return self._Event:Connect(Callback)
end

function ClientSignal:Once(Callback: (...any) -> ())
    return self._Event:Once(Callback)
end

local ServerSignal = {}
ServerSignal.__index = ServerSignal
setmetatable(ServerSignal, RemoteSignal)

local function MakeServerSignal(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string) : ServerRemoteSignal
    local self = setmetatable(RemoteSignal.new(Net, Name) :: any, ServerSignal) :: any
    return self :: ServerRemoteSignal
end

function ServerSignal:Fire(Players: { Player } | Player, ...: any)
    if typeof(Players) == "Instance" then
        self._Event:Fire(Players, ...)
    else
        self._Event:FireList(Players, ...)
    end
end

function ServerSignal:FireAll(...)
    self._Event:FireAll(...)
end

function ServerSignal:FireAllExcept(Exempt: { Player } | Player, ...)
    self._Event:FireAllExcept(Exempt, ...)
end

function ServerSignal:Connect(Callback: (Player: Player, ...any) -> ())
    return self._Event:Connect(Callback)
end

function ServerSignal:Once(Callback: (Player: Player, ...any) -> ())
    return self._Event:Once(Callback) 
end

return table.freeze({
    Server = MakeServerSignal,
    Client = MakeClientSignal,
})
