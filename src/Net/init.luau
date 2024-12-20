local RunService = game:GetService("RunService")

local BridgeNet = require(script.Parent.Parent.BridgeNet) :: { any }

local IsServer = RunService:IsServer()

type ServerBridge = typeof(BridgeNet.ServerBridge(""))
type ClientBridge = typeof(BridgeNet.ClientBridge(""))

export type ServerEvent = {
	Fire: (self: ServerEvent, Player, ...any) -> (),
	FireAll: (self: ServerEvent, ...any) -> (),
	FireAllExcept: (self: ServerEvent, { Player } | Player, ...any) -> (),
	Connect: (self: ServerEvent, Callback: () -> ()) -> (),
	SetCallback: (Callback: () -> ()) -> (),
}

export type ClientEvent = {
	Fire: (self: ClientEvent, ...any) -> (),
	Connect: (self: ClientEvent, Callback: () -> ()) -> (),
}

export type ServerNet = {
	CreateEvent: (self: ServerNet, Name: string) -> ServerEvent,
	AddInvoke: (self: ServerNet, EventName: string, Callback: () -> ...any?) -> (),
	Bridge: ServerBridge,
}

export type ClientNet = {
	CreateEvent: (self: ClientNet, Name: string) -> ClientEvent,
	Bridge: ClientBridge,
}

local RemoteSignal = require(script.RemoteSignal)
local RemoteProperty = require(script.RemoteProperty)

local CachedNets = {}

local function MakeEvent(Net: ServerNet | ClientNet, EventName: string): ServerEvent | ClientEvent
	local Event = {} :: ServerEvent | ClientEvent
	local Connections = {}

	local Bridge = Net.Bridge

	if IsServer then
		function Event:FireAll(...)
			Bridge:Fire(BridgeNet.AllPlayers(), { EventName, ... })
		end

		function Event:FireAllExcept(Exempt: { Player } | Player, ...)
			local _Exempt

			if typeof(Exempt) ~= "table" then
				_Exempt = { Exempt }
			else
				_Exempt = Exempt
			end

			Bridge:Fire(BridgeNet.PlayersExcept(_Exempt), { EventName, ... })
		end

		function Event:Fire(Player: Player | { Player }, ...)
			if typeof(Player) == "table" then
				Bridge:Fire(BridgeNet.Players(Player), { EventName, ... })
			else
				Bridge:Fire(Player, { EventName, ... })
			end
		end

		function Event:Connect(Callback: (...any) -> ())
			table.insert(Connections, Callback)

			return {
				Disconnect = function()
					table.remove(Connections, table.find(Connections, Callback))
				end,
			}
		end
	else
		function Event:Fire(...)
			Bridge:Fire({ EventName, ... })
		end

		function Event:Connect(Callback: (...any) -> ())
			table.insert(Connections, Callback)

			return {
				Disconnect = function()
					table.remove(Connections, table.find(Connections, Callback))
				end,
			}
		end
	end

	if IsServer then
		function Event:SetCallback(Callback: (...any) -> unknown)
			(Net :: ServerNet):AddInvoke(EventName, Callback)
		end

		Bridge:Connect(function(Player: Player, Args)
			local _EventName = Args[1]

			if _EventName ~= EventName then
				return
			end

			if Connections and #Connections > 0 then
				for _, Callback in pairs(Connections) do
					task.spawn(Callback, Player, unpack(Args, 2))
				end
			end
		end)
	else
		function Event:Invoke(...)
			local Args = { EventName, ... }
			return unpack(Bridge:InvokeServerAsync(Args))
		end

		Bridge:Connect(function(Args)
			local _EventName = Args[1]

			if _EventName ~= EventName then
				return
			end

			if Connections and #Connections > 0 then
				for _, Callback in pairs(Connections) do
					task.spawn(Callback, unpack(Args, 2))
				end
			end
		end)
	end

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
return table.freeze({
	CreateSignal = RemoteSignal.new,
	CreateProperty = RemoteProperty.new,

	new = function(Name: string): ServerNet | ClientNet
		if CachedNets[Name] then
			return CachedNets[Name]
		end

		local Bridge = if IsServer then BridgeNet.ServerBridge(Name) else BridgeNet.ClientBridge(Name)

		local Net = {} :: ServerNet | ClientNet

		Net.CreateEvent = MakeEvent :: (self: ServerNet | ClientNet, EventName: string) -> ServerEvent | ClientEvent

		Net.Bridge = Bridge

		if IsServer then
			local Invokes = {}

			function Net:AddInvoke(Event: string, Callback: () -> unknown?)
				if not Invokes[Event] then
					Invokes[Event] = Callback
				else
					warn("SetCallback can only be called once per Event.")
				end
			end

			Bridge.OnServerInvoke = function(Player, Args)
				local Event = table.remove(Args, 1)

				if Invokes[Event] then
					return { Invokes[Event](Player, unpack(Args)) }
				end

				return nil
			end
		end

		CachedNets[Name] = Net
		return Net
	end,
})
