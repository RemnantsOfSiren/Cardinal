local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }
local Signal = require(script.Parent.Parent.Parent.Signal) :: { any }

local function DeepCopy(Table: { any })
	local NewTable = {}

	for Index, Value in pairs(Table) do
		NewTable[Index] = if typeof(Value) == "table" then DeepCopy(Value) else Value
	end

	return NewTable
end

--[=[
    @class RemoteProperty
    A class that represents a signal that can be used to comminucate between the server and the client.
]=]

--[=[
    @function new
    @within RemoteProperty
    @param Net ServerNet | ClientNet
    @param Name string
    @param InitialValue any
    @return RemoteProperty
    Creates a new RemoteProperty object.
]=]

--[=[
    @method Observe
    @within RemoteProperty
    @param Callback (Player, ...any) -> ()
    @return RBXScriptConnection
    @server

    Connects a function to the signal.
]=]

--[=[
    @method Observe
    @within RemoteProperty
    @param Callback (...any) -> ()
    @return RBXScriptConnection
    @client

    Connects a function to the signal.
]=]

--[=[
    @method SetFor
    @within RemoteProperty
    @param Players Player | { Player }
    @param Value any
    @return nil
    @server
    
    Sets the value of the property for the specified players.
]=]

--[=[
    @method Set
    @within RemoteProperty
    @param Value any
    @return nil
    @server

    Sets the value of the property for all players.
]=]

--[=[
    @method GetFor
    @within RemoteProperty
    @param Player Player
    @return any
    @server

    Sets the value of the property for all players.
]=]

local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(
	Net: { CreateEvent: (self: unknown, string) -> unknown },
	Name: string,
	InitialValue: unknown
)
	local self = setmetatable({}, RemoteProperty)

	self.Cleaner = Trove.new()
	self.Event = Net:CreateEvent(Name)
	self.Changed = Signal.new()

	if RunService:IsServer() then
		self.Values = {}
		self._InitialValue = InitialValue

		local function OnPlayerAdded(Player: Player)
			self.Values[Player] = if typeof(InitialValue) == "table"
				then DeepCopy(self._InitialValue :: { any })
				else self._InitialValue
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

		self.Cleaner:Add(
			self.Event:Connect(function(Value: any)
				self.Value = Value
				self.Changed:Fire(Value)
			end),
			"Disconnect"
		)
	end

	return self
end

if RunService:IsServer() then
	function RemoteProperty:GetFor(Player: Player): any
		return self.Values[Player]
	end

	function RemoteProperty:SetFor(Players: { Player } | Player, Value: any)
		if type(Players) ~= "table" then
			Players = { Players }
		end

		for _, Player in Players :: { Player } do
			self.Values[Player] = if typeof(Value) == "table" then DeepCopy(Value :: { any }) else Value
			self.Event:Fire(Player, self.Values[Player])
			self.Changed:Fire(Player, self.Values[Player])
		end
	end

	function RemoteProperty:Set(Value)
		self._InitialValue = Value

		for Player in self.Values do
			self.Values[Player] = if typeof(Value) == "table" then DeepCopy(Value :: { any }) else Value
			self.Event:Fire(Player, self.Values[Player])
			self.Changed:Fire(Player, self.Values[Player])
		end
	end

	function RemoteProperty:Observe(Callback: (Player: Player, Value: any) -> ())
		for Player, Value in pairs(self.Values) do
			task.spawn(Callback, Player, Value)
		end

		return self.Event:Connect(function(Player: Player, Value: any)
			task.spawn(Callback, Player, Value)
		end)
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
	table.clear(self)
end

return RemoteProperty
