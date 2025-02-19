local RunService = game:GetService("RunService")

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

function RemoteSignal.new(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string)
	local self = setmetatable({
        _Name = Name,
    }, RemoteSignal)

	self.Event = Net:CreateEvent(Name)

	return self
end

if RunService:IsServer() then
	function RemoteSignal:Fire(Players: { Player } | Player, ...: any)
		self.Event:Fire(Players, ...)
	end

	function RemoteSignal:FireAll(...)
		self.Event:FireAll(...)
	end

	function RemoteSignal:FireAllExcept(Exempt: { Player } | Player, ...)
		self.Event:FireAllExcept(Exempt, ...)
	end

	function RemoteSignal:Connect(Callback: (Player: Player, ...any) -> ())
		return self.Event:Connect(Callback)
	end

    function RemoteSignal:Once(Callback: (Player: Player, ...any) -> ())
        return self.Event:Once(Callback) 
    end
else
	function RemoteSignal:Fire(...)
		self.Event:Fire(...)
	end

	function RemoteSignal:Connect(Callback: (...any) -> ())
		return self.Event:Connect(Callback)
	end

    function RemoteSignal:Once(Callback: (...any) -> ())
        return self.Event:Once(Callback) 
    end
end

function RemoteSignal:Destroy()
	table.clear(self)
end

return RemoteSignal
