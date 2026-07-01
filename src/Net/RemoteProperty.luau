--!strict
--!optimize 2

local PlayerService = game:GetService("Players")

local Packages = script.Parent.Parent.Parent :: any

local Trove = require(Packages.Trove) :: { [any]: any }
local Signal = require(Packages.Signal) :: { [any]: any }
local Promise = require(Packages.Promise) :: { [any]: any }

type Promise = typeof(Promise.new())

local function DeepCopy(Table: { any })
	local NewTable = {}

	for Index, Value in pairs(Table) do
		NewTable[Index] = if typeof(Value) == "table" then DeepCopy(Value) else Value
	end

	return NewTable
end

--[=[
    @class RemoteProperty
    A class that represents a property that can be used to communicate between the server and the client.
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

    Gets the value of the property for the specified player.
]=]

local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

type Trove = typeof(Trove.new())
type Signal = typeof(Signal.new())

type RemoteProperty<T> = typeof(setmetatable({} :: {
	Event: Signal,
	Cleaner: Trove,
	Changed: Signal,
	ServicePromise: boolean,
}, RemoteProperty))

export type ServerRemoteProperty<T> = RemoteProperty<T> & {
	Set: (self: ServerRemoteProperty<T>, Value: T) -> nil,
	GetFor: (self: ServerRemoteProperty<T>, Player: Player) -> T,
	SetFor: (self: ServerRemoteProperty<T>, Players: { Player } | Player, Value: T) -> nil,
	Observe: (self: ServerRemoteProperty<T>, Callback: (Player: Player, Value: T) -> ()) -> RBXScriptConnection,
	IsReady: (self: ServerRemoteProperty<T>) -> boolean,
}

export type ClientRemoteProperty<T> = RemoteProperty<T> & {
	Get: (self: ClientRemoteProperty<T>) -> T,
	Connect: (self: ClientRemoteProperty<T>, Callback: (Value: T) -> ()) -> RBXScriptConnection,
	Observe: (self: ClientRemoteProperty<T>, Callback: (Value: T) -> ()) -> RBXScriptConnection,
	IsReady: (self: ClientRemoteProperty<T>) -> boolean,
}

function RemoteProperty.new<T>(
	Net: { CreateEvent: (self: unknown, string) -> unknown },
	Name: string,
	InitialValue: T,
	ServicePromise: boolean?
)
	local self = setmetatable({
		ServicePromise = if ServicePromise ~= nil then ServicePromise else false
	}, RemoteProperty)

	self.Cleaner = Trove.new()
	self.Event = Net:CreateEvent(Name)
	self.Changed = Signal.new()

	return self
end

function RemoteProperty:Destroy()
	self.Cleaner:Destroy()
	table.clear(self)
end

local ClientProperty = {}
ClientProperty.__index = ClientProperty
setmetatable(ClientProperty, RemoteProperty)

local function MakeClientProperty<T>(
	Net: { CreateEvent: (self: unknown, string) -> unknown },
	Name: string,
	InitialValue: unknown,
	ServicePromise: boolean?
): ClientRemoteProperty<T>
	local self = setmetatable(RemoteProperty.new(Net, Name, InitialValue, ServicePromise) :: any, ClientProperty) :: any

	self.Value = InitialValue
	self._Ready = false

	self.Cleaner:Add(
		self.Event:Connect(function(Value: any)
			self.Value = Value
			self.Changed:Fire(Value)
		end),
		"Disconnect"
	)

	return self :: ClientRemoteProperty<T>
end

function ClientProperty:IsReady()
	return self._Ready
end

function ClientProperty:OnReady(): Promise | nil?
	if self.ServicePromise then
		return Promise.new(function(Resolve, Reject) 
			if self._Ready then
				Resolve()
			else
				repeat
					task.wait()
				until self._Ready

				Resolve()
			end
		end)
	else
		if not self._Ready then
			local thread
			
			task.spawn(function()
				repeat
					task.wait()
				until self._Ready
				if thread then
					coroutine.resume(thread)
				end
			end)

			thread = coroutine.yield()
		end
	end

	return nil
end

function ClientProperty:Get(): any
	return self.Value
end

function ClientProperty:Connect(Callback: (any) -> ())
	local Connection = self.Changed:Connect(Callback)
	if not self._Ready then
		self._Ready = true
		self.Event:Fire()
	end
	return Connection
end

function ClientProperty:Observe(Callback: (any) -> ())
	task.spawn(Callback, self.Value)
	return self:Connect(Callback)
end

local ServerProperty = {}
ServerProperty.__index = ServerProperty
setmetatable(ServerProperty, RemoteProperty)

local function MakeServerProperty<T>(
	Net: { CreateEvent: (self: unknown, string) -> unknown },
	Name: string,
	InitialValue: T,
	ServicePromise: boolean?
): ServerRemoteProperty<T>
	local self = setmetatable(RemoteProperty.new(Net, Name, InitialValue, ServicePromise) :: any, ServerProperty) :: any

	self._ClientsReady = {}
	self.Values = {}
	self._InitialValue = InitialValue

	local function OnPlayerAdded(Player: Player)
		local PlrName = Player.Name
		self.Values[PlrName] = if typeof(InitialValue) == "table"
			then DeepCopy(self._InitialValue :: { any })
			else self._InitialValue
	end

	for _, Player in PlayerService:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end

	self.Cleaner:Connect(PlayerService.PlayerAdded, OnPlayerAdded)

	self.Cleaner:Connect(PlayerService.PlayerRemoving, function(Player: Player)
		local PlrName = Player.Name
		self.Values[PlrName] = nil
		self._ClientsReady[PlrName] = nil
	end)

	self.Event:Connect(function(Player: Player)
		local PlrName = Player.Name
		self._ClientsReady[PlrName] = true
		self.Event:Fire(Player, self.Values[PlrName])
		self.Changed:Fire(Player, self.Values[PlrName])
	end)

	return self :: ServerRemoteProperty<T>
end

function ServerProperty:GetFor(Player: Player): any
	return self.Values[Player.Name]
end

function ServerProperty:SetFor(Players: { Player } | Player, Value: any)
	if type(Players) ~= "table" then
		Players = { Players }
	end

	for _, Player in Players :: { Player } do
		task.spawn(function()
			local Name = Player.Name

			if not self._ClientsReady[Name] then
				while PlayerService:FindFirstChild(Name) and not self._ClientsReady[Name] do
					task.wait()
				end
			end

			self.Values[Name] = if typeof(Value) == "table" then DeepCopy(Value :: { any }) else Value
			self.Event:Fire(Player, self.Values[Name])
			self.Changed:Fire(Player, self.Values[Name])
		end)
	end
end

function ServerProperty:Set(Value)
	self._InitialValue = Value

	for Name in self.Values do
		task.spawn(function()
			if not self._ClientsReady[Name] then
				while PlayerService:FindFirstChild(Name) and not self._ClientsReady[Name] do
					task.wait()
				end
			end

			local Player = PlayerService:FindFirstChild(Name)
			
			if Player then
				self.Values[Name] = if typeof(Value) == "table" then DeepCopy(Value :: { any }) else Value
				self.Event:Fire(Player, self.Values[Name])
				self.Changed:Fire(Player :: Player, self.Values[Name])
			end
		end)
	end
end

function ServerProperty:Observe(Callback: (Player: Player, Value: any) -> ())
	for Name, Value in pairs(self.Values) do
		local Player = PlayerService:FindFirstChild(Name :: string) :: Player
		
		if Player then
			task.spawn(Callback, Player, Value)
		end
	end

	return self.Event:Connect(function(Player: Player, Value: any)
		task.spawn(Callback, Player, Value)
	end)
end

function ServerProperty:IsReady()
	return true
end

return table.freeze({
	Server = MakeServerProperty,
	Client = MakeClientProperty,
})
