local RunService = game:GetService("RunService")

local BridgeNet = require(script.Parent.Parent.BridgeNet) :: { any }

local IsServer = RunService:IsServer()

type ServerBridge = typeof(BridgeNet.ServerBridge(""))
type ClientBridge = typeof(BridgeNet.ClientBridge(""))

export type ServerEvent = {
	Fire: (self: ServerEvent, Player, ...any) -> (),
	_Name: string,
	FireAll: (self: ServerEvent, ...any) -> (),
	Connect: (self: ServerEvent, Callback: () -> ()) -> (),
	SetCallback: (Callback: () -> ()) -> (),
	FireAllExcept: (self: ServerEvent, { Player } | Player, ...any) -> (),
}

export type ClientEvent = {
	_Name: string,
	Fire: (self: ClientEvent, ...any) -> (),
	Connect: (self: ClientEvent, Callback: () -> ()) -> (),
}

export type ServerNet = {
	Name: string,
	AddInvoke: (self: ServerNet, EventName: string, Callback: () -> ...any?) -> (),
	CreateEvent: (self: ServerNet, Name: string) -> ServerEvent,
}

export type ClientNet = {
	Name: string,
	CreateEvent: (self: ClientNet, Name: string) -> ClientEvent,
}

local RemoteSignal = require(script.RemoteSignal)
local RemoteProperty = require(script.RemoteProperty)

local Bridge = if IsServer then BridgeNet.ServerBridge("Cardinal") else BridgeNet.ClientBridge("Cardinal")

local Cache = {}

Bridge:Connect(function(...)
	local Args = if typeof(...) == "table" then ... else { ... }

	local _Bridge = table.remove(Args, 1)
	if not Cache[_Bridge] then
		Cache[_Bridge] = {}
	end

	local _Event = table.remove(Args, 1)
	if not Cache[_Bridge][_Event] then
		Cache[_Bridge][_Event] = {}
	end
	
	table.insert(Cache[_Bridge][_Event], {
		Sent = false,
		Args = if IsServer then Args[2] else Args,
		Player = if IsServer then Args[1] else nil,
	})
end)

local function MakeEvent(Net: ServerNet | ClientNet, EventName: string): ServerEvent | ClientEvent
	local Event = {
		_Name = EventName,
	} :: ServerEvent | ClientEvent

	local EventCache = {}
	local Connections = {}

	if IsServer then
		function Event:FireAll(...)
			Bridge:Fire(BridgeNet.AllPlayers(), { Net.Name, EventName, ... })
		end

		function Event:FireAllExcept(Exempt: { Player } | Player, ...)
			local _Exempt

			if typeof(Exempt) ~= "table" then
				_Exempt = { Exempt }
			else
				_Exempt = Exempt
			end

			Bridge:Fire(BridgeNet.PlayersExcept(_Exempt), { Net.Name, EventName, ... })
		end

		function Event:Fire(Player: Player | { Player }, ...)
			if typeof(Player) == "table" then
				Bridge:Fire(BridgeNet.Players(Player), { Net.Name, EventName, ... })
			else
				Bridge:Fire(Player, { Net.Name, EventName, ... })
			end
		end
	else
		function Event:Fire(...)
			Bridge:Fire({ Net.Name, EventName, ... })
		end
	end

	function Event:Connect(Callback: (...any) -> ())
		EventCache[Callback] = {}

		local Events = Cache[Net.Name] and Cache[Net.Name][EventName]

		if Events and #Events > 0 then
			for _, Data in pairs(Events) do
				if not table.find(EventCache[Callback], Data) then
					table.insert(EventCache[Callback], Data)

					if IsServer then
						task.spawn(Callback, Data.Player, unpack(Data.Args))
					else
						task.spawn(Callback, unpack(Data.Args))
					end
				end
			end
		end

		table.insert(Connections, Callback)

		return {
			Disconnect = function()
				for Index = #Connections, 1, -1 do
					if Connections[Index] == Callback then
						table.remove(Connections, Index)
					end
				end
			end,
		}
	end

	function Event:Once(Callback: (...any) -> ())
		local Connection
		Connection = self:Connect(function(...)
			if Connection then
				Connection:Disconnect()
				task.spawn(Callback, ...)
			end
		end)
		return Connection
	end

	if IsServer then
		function Event:SetCallback(Callback: (...any) -> unknown)
			(Net :: ServerNet):AddInvoke(EventName, Callback)
		end
	else
		function Event:Invoke(...)
			local Args = { Net.Name, EventName, ... }
			return unpack(Bridge:InvokeServerAsync(Args))
		end
	end

	task.spawn(function()
		while true do
			local Events = Cache[Net.Name] and Cache[Net.Name][EventName]
			
			if Events and #Events > 0 then
				for _, Data in pairs(Events) do
					if Connections and #Connections > 0 then
						for _, Callback in pairs(Connections) do
							if not table.find(EventCache[Callback], Data) then
								table.insert(EventCache[Callback], Data)
								if IsServer then
									task.spawn(Callback, Data.Player, unpack(Data.Args))
								else
									task.spawn(Callback, unpack(Data.Args))
								end
							end

							Data.Sent = true
						end
					end
				end
			end

			if Events and #Events > 0 then
				for Index = #Events, 1, -1 do
					if Events[Index].Sent then
						table.remove(Events, Index)
					end
				end
			end

			task.wait()
		end
	end)

	return Event
end

--[=[
	@function CreateSignal
	@within Net
	@param Bridge ServerBridge | ClientBridge
	@param Name string
]=]

--[=[
	@function CreateProperty
	@within Net
	@param Bridge ServerBridge | ClientBridge
	@param Name string
	@param Value any
]=]

--[=[
	@function new
	@within Net
	@param Name string
	@return ServerNet | ClientNet
]=]

--[=[
	@class Net

	A Module that allows for easier communication between the Server and Client.

	Cardinal internally uses this module to handle the server-client communication.

	```lua
	local Service = {
		Client = {},
	} -- will tell Cardinal that this is a service needs to create a new Net, allowing for functions in this table to be what we call "client-exposed" functions.
	
	function Service.Client:Hello(Player) -- this function will be exposed to the client
		print("Hello", Player)
	end

	-- in the client
	local Cardinal = require(Path.to.Cardinal)
	
	local Service

	local Controller = {}

	function Controller:OnInit()
		Service = Cardinal.GetService("Service") -- this is the best practice in requiring a service on the client, OnInit will run after the server is fully ready so this ensures that the service is ready to be used.
		Service:Hello() -- this will call the Hello function on the server
	end
	```
]=]

local Bridges = {}

if IsServer then
	Bridge.OnServerInvoke = function(Player, Args)
		local _Bridge = table.remove(Args, 1)
		local Found = Bridges[_Bridge]
		if Found then
			local _Event = table.remove(Args, 1)
			local Event = Found and Found.Invokes[_Event]
			if Event then
				return { Event(Player, unpack(Args)) }
			end
		end
	end
end

return table.freeze({
	CreateSignal = RemoteSignal.new,
	CreateProperty = RemoteProperty.new,

	new = function(Name: string): ServerNet | ClientNet
		if Bridges[Name] then
			return Bridges[Name]
		end

		local Net = {} :: ServerNet | ClientNet

		Net.Name = Name
		Net.CreateEvent = MakeEvent :: (self: ServerNet | ClientNet, EventName: string) -> ServerEvent | ClientEvent

		if IsServer then
			local Invokes = {}

			function Net:AddInvoke(Event: string, Callback: () -> unknown?)
				if not Invokes[Event] then
					Invokes[Event] = Callback
				else
					warn("SetCallback can only be called once per Event.")
				end
			end

			Net.Invokes = Invokes
		end

		Bridges[Name] = Net
		return Net
	end,
})
