local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }
local Signal = require(script.Parent.Parent.Parent.Signal) :: { any }
local Promise = require(script.Parent.Parent.Parent.Promise) :: { any }

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
	InitialValue: unknown,
	ServicePromise: boolean?
)
	local self = setmetatable({
		ServicePromise = if ServicePromise ~= nil then ServicePromise else false
	}, RemoteProperty)

	self.Cleaner = Trove.new()
	self.Event = Net:CreateEvent(Name)
	self.Changed = Signal.new()

	if RunService:IsServer() then
		self._ClientsReady = {}
		self.Values = {}
		self._InitialValue = InitialValue

		local function OnPlayerAdded(Player: Player)
			local Name = Player.Name
			self.Values[Name] = if typeof(InitialValue) == "table"
				then DeepCopy(self._InitialValue :: { any })
				else self._InitialValue
		end

		for _, Player in PlayerService:GetPlayers() do
			task.spawn(OnPlayerAdded, Player)
		end

		self.Cleaner:Connect(PlayerService.PlayerAdded, OnPlayerAdded)

		self.Cleaner:Connect(PlayerService.PlayerRemoving, function(Player: Player)
			local Name = Player.Name
			self.Values[Name] = nil
			self._ClientsReady[Name] = nil
		end)

		self.Event:Connect(function(Player: Player)
			local Name = Player.Name
			self._ClientsReady[Name] = true
			self.Event:Fire(Player, self.Values[Name])
			self.Changed:Fire(Player, self.Values[Name])
		end)
	else
		self.Value = InitialValue
		self._Ready = false

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

	function RemoteProperty:Set(Value)
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

	function RemoteProperty:Observe(Callback: (Player: Player, Value: any) -> ())
		for Name, Value in pairs(self.Values) do
			local Player = PlayerService:FindFirstChild(Name)
			task.spawn(Callback, Player, Value)
		end

		return self.Event:Connect(function(Player: Player, Value: any)
			task.spawn(Callback, Player, Value)
		end)
	end
else
	function RemoteProperty:IsReady()
		return self._Ready
	end

	function RemoteProperty:OnReady(): Promise | nil?
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

	function RemoteProperty:Get(): any
		return self.Value
	end

	function RemoteProperty:Connect(Callback: (any) -> ())
		local Connection = self.Changed:Connect(Callback)
		if not self._Ready then
			self._Ready = true
			self.Event:Fire()
		end
		return Connection
	end

	function RemoteProperty:Observe(Callback: (any) -> ())
		task.spawn(Callback, self.Value)
		return self:Connect(Callback)
	end

	function RemoteProperty:IsReady()

	end
end

function RemoteProperty:Destroy()
	self.Cleaner:Destroy()
	table.clear(self)
end

return RemoteProperty
