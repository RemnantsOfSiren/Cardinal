--!strict
--!optimize 2

--[[
	Created by Byran E.

	Loader is a simplistic module loader, similar to that of Knit.
	It offers a few more functions, and removes the internal API for Networking,
	allowing for developer freedom.

	All events will run after OnInit and OnStart. This is to ensure all dependencies are loaded and started before any events are fired.
]]

--[=[
	@prop Client? {[string]: (self: self, Player: Player, ...) -> nil | () -> nil } | nil
	@within Service
]=]
--[=[
	@method OnInit?
	@within Service
	Fires when the Service is initialized.
]=]
--[=[
	@method OnStart?
	@within Service
	Fires when the Service is Started.
]=]
--[=[
	@method OnPlayerAdded?
	@within Service
	Fires when a Player is added.
]=]
--[=[
	@method OnPlayerRemoving?
	@within Service
	Fires when a Player is removed.
]=]
--[=[
	@method OnCharacterAdded?
	@within Service
	@param Character Instance
	@param Player Player
	Fires when a Character is added.
]=]
--[=[
	@method OnStepped?
	@within Service
	@param ElapsedTime number
	@param DeltaTime number
	Fires when the Stepped event is fired.
]=]
--[=[
	@method OnHeartbeat?
	@within Service
	@param DeltaTime number
	Fires when the Heartbeat event is fired.
]=]
--[=[
	@method OnPreAnimation?
	@within Service
	@param DeltaTime number
	Fires when the PreAnimation event is fired.
]=]
--[=[
	@method OnPreSimulation?
	@within Service
	@param DeltaTime number
	Fires when the PreSimulation event is fired.
]=]
--[=[
	@method OnPostAnimation?
	@within Service
	@param DeltaTime number
	Fires when the PostAnimation event is fired.
]=]
--[=[
	@method OnPostSimulation?
	@within Service
	@param DeltaTime number
	Fires when the PostSimulation event is fired.
]=]

--[=[
	@class Service
	@server

	All functions are optional for you to add, and will be called if they exist.
	
	Example Service
	```lua
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage:WaitForChild("Packages")
	local Cardinal = require(Packages:WaitForChild("Cardinal"))

	local Service = {
		Client = {
			TestSignal = Cardinal.CreateSignal(),
			TestProperty = Cardinal.CreateProperty(0),
		},
	}

	function Service:OnInit()
		print("Service Initialized")
	end

	function Service:OnStart()
		print("Service Started")
	end

	function Service:OnPlayerAdded(Player)
		print("Player Added: ", Player)
	end

	function Service:OnCharacterAdded(Character, Player)
		print("Character Added: ", Character, Player)
	end

	function Service:OnHeartbeat(DeltaTime)
		print("Heartbeats stepping...")
	end

	return Service
	```
]=]

--[=[
	@method OnInit
	@within Controller
	Fires when the Controller is initialized.
]=]
--[=[
	@method OnStart
	@within Controller
	Fires when the Controller is Started.
]=]
--[=[
	@method OnPlayerAdded
	@within Controller
	@param Player Player
	Fires when a Player is added.
]=]
--[=[
	@method OnPlayerRemoving
	@within Controller
	@param Player Player
	Fires when a Player is removed.
]=]
--[=[
	@method OnCharacterAdded
	@within Controller
	@param Character Instance
	@param Player Player
	Fires when a Character is added.
]=]
--[=[
	@method OnLocalPlayer
	@within Controller
	@param Player Player
	Fires when the local player is added.
]=]
--[=[
	@method OnLocalCharacter
	@within Controller
	@param Character Instance
	@param Player Player
	Fires when the local player has a Character added.
]=]
--[=[
	@method OnStepped
	@within Controller
	@param ElapsedTime number
	@param DeltaTime number
	Fires when the Stepped event is fired.
]=]
--[=[
	@method OnRenderStepped
	@within Controller
	@param DeltaTime number
	Fires when the RenderStepped event is fired.
]=]
--[=[
	@method OnHeartbeat
	@within Controller
	@param DeltaTime number
	Fires when the Heartbeat event is fired.
]=]
--[=[
	@method OnPreAnimation
	@within Controller
	@param DeltaTime number
	Fires when the PreAnimation event is fired.
]=]
--[=[
	@method OnPreSimulation
	@within Controller
	@param DeltaTime number
	Fires when the PreSimulation event is fired.
]=]
--[=[
	@method OnPostAnimation
	@within Controller
	@param DeltaTime number
	Fires when the PostAnimation event is fired.
]=]
--[=[
	@method OnPostSimulation
	@within Controller
	@param DeltaTime number
	Fires when the PostSimulation event is fired.
]=]

--[=[
	@class Controller
	@client
	
	All functions are optional for you to add, and will be called if they exist.

	Example Controller:
	```lua
	local Controller = {}

	function Controller:OnInit()
		print("Controller Initialized")
	end

	function Controller:OnStart()
		print("Controller Started")
	end

	function Controller:OnPlayerAdded(Player)
		print("Player Added: ", Player)
	end

	function Controller:OnCharacterAdded(Character, Player)
		print("Character Added: ", Character, Player)
	end

	function Controller:OnHeartbeat(DeltaTime)
		print("Heartbeats stepping...")
	end

	return Service
	```
]=]

type Callback = (Instance) -> () -> nil

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")

local Promise = require(script.Parent.Promise) :: { [any]: any }

local Net = require(script.Net) :: any

type Packet = {
	Args: { [any]: any },
	Sent: boolean,
}

local EventLog: { [string]: { Packet } } = {
	["PlayerAdded"] = {},
	["CharacterAdded"] = {},
	["PlayerRemoving"] = {},
} -- Pre-emptive table in-case events are fired before the client/server is ready.

local function CreatePacket(...): Packet
	return {
		Args = { ... },
		Sent = false,
	}
end

local function OnPlayerAdded(Player)
	table.insert(EventLog["PlayerAdded"], CreatePacket(Player))

	local function OnCharacterAdded(Character)
		table.insert(EventLog["CharacterAdded"], CreatePacket(Character, Player))
	end

	if Player.Character then
		task.spawn(OnCharacterAdded, Player.Character)
	end

	Player.CharacterAdded:Connect(OnCharacterAdded)
end

PlayerService.PlayerAdded:Connect(OnPlayerAdded)

for _, Player in PlayerService:GetPlayers() do
	task.spawn(OnPlayerAdded, Player)
end

PlayerService.PlayerRemoving:Connect(function(Player)
	table.insert(EventLog["PlayerRemoving"], CreatePacket(Player))
end)

export type ClientNet = Net.ClientNet
export type ServerNet = Net.ServerNet
export type ServerEvent = Net.ServerEvent
export type ClientEvent = Net.ClientEvent

local IsServer = RunService:IsServer()

if not IsServer then
	if workspace.StreamingEnabled then
		warn("Some-things may not function as expected due to StreamingEnabled.")
	end

	if not script:GetAttribute("ServerReady") then
		while not script:GetAttribute("ServerReady") do
			task.wait(0)
		end
	end
end

local Loaded = {}
local Started = false
local CachedNets = if not IsServer then {} else nil

local function Load(Module: ModuleScript)
	local Name = Module.Name

	local Success, Error = pcall(function()
		Module = require(Module) :: any
	end)

	if Success and typeof(Module) == "table" then
		Loaded[Name] = Module
	elseif not Success then
		error(`@Cardinal - Error Loading {Name}: ` .. Error)
	end
end

local function IsAnExclusion(Exclusions: { string }, Name: string): boolean
	for _, Exclusion in pairs(Exclusions) do
		if Name:lower():find(Exclusion:lower()) then
			return true
		end
	end
	return false
end

export type Service = {
	OnInit: () -> ()?,
	OnStart: () -> ()?,
	OnPlayerAdded: (Player: Player) -> ()?,
	OnPlayerRemoving: (Player: Player) -> ()?,
	OnCharacterAdded: (Character: Model, Player: Player) -> ()?,
	OnStepped: (StartTime: number, DeltaTime: number) -> ()?,
	OnHeartbeat: (DeltaTime: number) -> ()?,
	OnPreAnimation: (DeltaTime: number) -> ()?,
	OnPreSimulation: (DeltaTime: number) -> ()?,
	OnPostAnimation: (DeltaTime: number) -> ()?,
	OnPostSimulation: (DeltaTime: number) -> ()?,
	Client: unknown?,
}

export type Controller = {
	OnInit: () -> ()?,
	OnStart: () -> ()?,
	OnPlayerAdded: (Player: Player) -> ()?,
	OnPlayerRemoving: (Player: Player) -> ()?,
	OnCharacterAdded: (Character: Model, Player: Player) -> ()?,
	OnLocalPlayer: (Player: Player) -> ()?,
	OnLocalCharacter: (Character: Model, Player: Player) -> ()?,
	OnStepped: (StartTime: number, DeltaTime: number) -> ()?,
	OnRenderStepped: (DeltaTime: number) -> ()?,
	OnHeartbeat: (DeltaTime: number) -> ()?,
	OnPreAnimation: (DeltaTime: number) -> ()?,
	OnPreSimulation: (DeltaTime: number) -> ()?,
	OnPostAnimation: (DeltaTime: number) -> ()?,
	OnPostSimulation: (DeltaTime: number) -> ()?,
}

local Signal = newproxy(false)
local Property = newproxy(false)

--[=[
	@function Load
	@within Cardinal
	@param Parent: Instance
	@param LoadOptions: { Deep: boolean?, Predicate: ((ModuleScript) -> boolean)?, Exclusions: { string }? }?
	@return Promise<string>
	Loads a ModuleScript into the Loader. 

	LoadOptions:

	Deep is an optional boolean that will determine if the Loader should load all ModuleScripts in the Parent's descendants.
	
	Predicate is an optional function that will be used to determine if the ModuleScript should be loaded.
	
	Exclusions is an optional table of strings that will be used to exclude certain ModuleScripts from being loaded.
]=]

--[=[
	@function Start
	@within Cardinal
	@return Promise<string>
	Starts the Loader, initializing and starting all services/controllers.
]=]

--[=[
	@function GetService
	@within Cardinal
	@param Name: string
	@return table | nil
	@client
	Gets a service from the Loader by name (client only, and case sensitive).
]=]

--[=[
	@function CreateSignal
	@within Cardinal
	@return SignalFlag
	Flags that a new "Remote" Signal should be made
]=]

--[=[
	@function CreateProperty
	@within Cardinal
	@return SignalFlag
	Flags that a new "Remote" Signal should be made
]=]

--[=[
	@function OnStart
	@within Cardinal
	@return Promise<nil>
	@yields
	Waits for the Loader to start.
]=]

--[=[
	@prop Icon Icon
	@within Cardinal
	@client

	This is an expose for TopbarPlus (https://devforum.roblox.com/t/1017485)

	it returns the Icon module, due to the Wally for topbarplus being broken, I've just ported it directly into Cardinal.
]=]

--[=[
	@prop Net Net
	@within Cardinal
]=]

--[=[
	@class Cardinal	
	The main driver functions for Cardinal
]=]

export type LoadOptions = {
	Deep: boolean?,
	Predicate: ((ModuleScript) -> boolean)?,
	Exclusions: { string }?,
}

return table.freeze({
	Net = Net,
	Icon = if not IsServer then require(script.Icon) else nil,
	Player = if not IsServer then PlayerService.LocalPlayer else nil,

	CreateSignal = function()
		return Signal
	end,

	CreateProperty = function(InitialValue: any)
		return { Property, InitialValue }
	end,

	OnStart = function()
		if Started then
			return Promise.resolve()
		else
			return Promise.new(function(Resolve)
				repeat
					task.wait(0)
				until Started
				return Resolve()
			end)
		end
	end,

	Load = function(Parent: Instance, LoadOptions: LoadOptions?)
		if Started then
			return Promise.reject("Can't load Modules once the Loader is already started.")
		end

		local Deep = if LoadOptions and LoadOptions.Deep then LoadOptions.Deep else false
		local Predicate = if LoadOptions and LoadOptions.Predicate then LoadOptions.Predicate else nil
		local Exclusions = if LoadOptions and LoadOptions.Exclusions then LoadOptions.Exclusions else nil
		
		local Modules = {} :: { ModuleScript }

		for _, Object in pairs(if Deep then Parent:GetDescendants() else Parent:GetChildren()) do
			if Object:IsA("ModuleScript") then
				table.insert(Modules, Object)
			end
		end

		if Predicate then
			for I = #Modules, 1, -1 do
				local ModuleScript = Modules[I]
				if not Predicate(ModuleScript) then
					table.remove(Modules, I)
				end
			end
		end

		for _, Object in pairs(Modules) do
			if Object:IsA("ModuleScript") then
				if Exclusions and IsAnExclusion(Exclusions, Object.Name) then
					continue
				end

				Load(Object)
			end
		end

		return Promise.resolve("@Cardinal - Loading Completed")
	end,

	GetService = function(Name: string)
		if IsServer then
			return warn("GetService can only be called on the Client.")
		end

		if CachedNets then
			local Found = CachedNets[Name]

			if Found then
				return Found
			else
				local NetworkEvents = script:WaitForChild("NetworkEvents") :: StringValue
				local Nets = NetworkEvents.Value:split(":")

				if table.find(Nets, Name) then
					local _Net = {}

					local Network = Net.new(Name) :: { CreateEvent: (any, string) -> { [any]: any } }

					local GetEvents = Network:CreateEvent("GetEvents")
					local GetProperties = Network:CreateEvent("GetProperties")
					local GetSignals = Network:CreateEvent("GetSignals")

					for _, Event in GetEvents:Invoke() do
						local _Event = Network:CreateEvent(Event)

						_Net[Event] = function(_, ...)
							return _Event:Invoke(...)
						end
					end

					for _, Info in GetProperties:Invoke() do
						_Net[Info[1]] = Net.CreateProperty(Network, Info[1], Info[2])
					end

					for _, _Signal in GetSignals:Invoke() do
						_Net[_Signal] = Net.CreateSignal(Network, _Signal)
					end

					_Net.Bridge = Network

					CachedNets[Name] = _Net
					return _Net
				end
			end
		end
	end,

	Start = function()
		if Started then
			return Promise.reject("Loader is already started.")
		end

		local Nets = {}
		local Temp = {}

		for Name, Module in Loaded do
			if Module.Client then
				Module.Client.Server = Module

				local _Net = Net.new(Module.Name or Name) :: { CreateEvent: (any, string) -> { [any]: any } }
				Module.Net = _Net

				local ClientEvents = {}
				local ClientSignals = {}
				local ClientProperties = {}

				local GetEvents = _Net:CreateEvent("GetEvents")

				GetEvents:SetCallback(function()
					return ClientEvents
				end)

				local GetProperties = _Net:CreateEvent("GetProperties")

				GetProperties:SetCallback(function()
					return ClientProperties
				end)

				local GetSignals = _Net:CreateEvent("GetSignals")

				GetSignals:SetCallback(function()
					return ClientSignals
				end)

				for Event, Callback in Module.Client do
					if typeof(Callback) == "function" then
						local _Event = _Net:CreateEvent(Event)

						_Event:SetCallback(function(Player, ...)
							return Callback(Module.Client, Player, ...)
						end)

						table.insert(ClientEvents, Event)
					elseif typeof(Callback) == "userdata" and Callback == Signal then
						Module.Client[Event] = Net.CreateSignal(_Net, Event)
						table.insert(ClientSignals, Event)
					elseif
						typeof(Callback) == "table"
						and typeof(Callback[1]) == "userdata"
						and Callback[1] == Property
					then
						local InitialValue = Callback[2]
						Module.Client[Event] = Net.CreateProperty(_Net, Event, InitialValue)
						table.insert(ClientProperties, { Event, InitialValue })
					end
				end

				table.insert(Nets, Name)
			end
		end

		for Name, Module in pairs(Loaded) do
			local Init = Module.OnInit or Module.Init

			if Init then
				Module.__Initialized = false
				task.spawn(function()
					local T = tick()

					repeat
						task.wait()
					until tick() - T > 10 or Module.__Initialized

					if not Module.__Initialized then
						error(`@Cardinal - module: {Name} took too long to initialize.`)
					end
				end)

				task.spawn(function()
					debug.profilebegin(`Initializing {Name}`)
					table.insert(
						Temp,
						Promise.try(function()
							Init(Module)
							Module.__Initialized = true
						end)
					)
					debug.profileend()
				end)
			end
		end

		return Promise.allSettled(Temp)
			:andThen(function()
				table.clear(Temp)

				for Name, Module in pairs(Loaded) do
					local Start = Module.OnStart or Module.Start

					if Start then
						Module.__Started = false
						task.spawn(function()
							local T = tick()

							repeat
								task.wait()
							until tick() - T > 10 or Module.__Started

							if not Module.__Started then
								error(`@Cardinal - module: {Name} took too long to start.`)
							end
						end)

						task.spawn(function()
							debug.profilebegin(`Starting {Name}`)
							table.insert(
								Temp,
								Promise.try(function()
									Start(Module)
									Module.__Started = true
								end)
							)
							debug.profileend()
						end)
					end
				end
			end)
			:finally(function()
				local Events = {
					RunService = {},
					PlayerService = {
						PlayerAdded = {},
						CharacterAdded = {},
						PlayerRemoving = {},
					},
				}

				if RunService:IsClient() then
					Events.PlayerService.LocalPlayer = {}
					Events.PlayerService.LocalCharacter = {}
				end

				for _, Module in pairs(Loaded) do
					if Module.__Initialized ~= nil then
						repeat
							task.wait()
						until Module.__Initialized
					end

					if Module.__Started ~= nil then
						repeat
							task.wait()
						until Module.__Started
					end

					for Function, Callback in pairs(Module) do
						if Function == "Name" or typeof(Callback) ~= "function" then
							continue
						end

						local Event = string.gsub(Function, "On", "")

						local Success = pcall(function()
							local C = RunService[Event]:Once(function() end)
							if C then
								C:Disconnect()
							end
						end)

						if Success then
							if not Events.RunService[Event] then
								Events.RunService[Event] = {}
							end

							table.insert(Events.RunService[Event], function(...)
								Callback(Module, ...)
							end)
						elseif Events.PlayerService[Event] then
							table.insert(Events.PlayerService[Event], function(...)
								Callback(Module, ...)
							end)
						end
					end
				end

				local Net = Instance.new("StringValue")
				Net.Name = "NetworkEvents"
				Net.Value = table.concat(Nets, ":")
				Net.Parent = script

				for Event, Callbacks in pairs(Events.RunService) do
					RunService[Event]:Connect(function(...)
						for _, Callback in pairs(Callbacks) do
							task.spawn(Callback, ...)
						end
					end)
				end

				local function CharacterAdded(Character: Instance, Player: Player)
					if not Character:IsDescendantOf(workspace) then
						while Player:IsDescendantOf(PlayerService) and not Character:IsDescendantOf(workspace) do
							task.wait()
						end

						if not Player:IsDescendantOf(PlayerService) then
							return
						end
					end

					local Start = tick()

					if Character:IsA("Model") then
						while not Character.PrimaryPart and tick() - Start < 10 do
							task.wait()
						end
					end

					if tick() - Start >= 10 then
						warn(
							"Character's PrimaryPart took too long to be parented. Some code may not function as expected."
						)
					end

					if #Events.PlayerService.CharacterAdded > 0 then
						for _, Callback in pairs(Events.PlayerService.CharacterAdded) do
							task.spawn(Callback, Character, Player)
						end
					end

					if
						RunService:IsClient()
						and Player == PlayerService.LocalPlayer
						and #Events.PlayerService.LocalCharacter > 0
					then
						for _, Callback in pairs(Events.PlayerService.LocalCharacter) do
							task.spawn(Callback, Character, Player)
						end
					end
				end

				local function PlayerAdded(Player: Player)
					if #Events.PlayerService.PlayerAdded > 0 then
						for _, Callback in pairs(Events.PlayerService.PlayerAdded) do
							task.spawn(Callback, Player)
						end
					end

					if
						RunService:IsClient()
						and Player == PlayerService.LocalPlayer
						and #Events.PlayerService.LocalPlayer > 0
					then
						for _, Callback in pairs(Events.PlayerService.LocalPlayer) do
							task.spawn(Callback, Player)
						end
					end
				end

				local function PlayerRemoving(Player)
					if #Events.PlayerService.PlayerRemoving then
						for _, Callback in pairs(Events.PlayerService.PlayerRemoving) do
							task.spawn(Callback, Player)
						end
					end
				end

				local Thread = task.spawn(function()
					while true do
						for Event: string, Log: { Packet } in EventLog do
							for I = #Log, 1, -1 do
								local Packet: Packet = Log[I]
								if not Packet then
									continue
								end

								if not Packet.Sent then
									if Event == "PlayerAdded" then
										task.spawn(PlayerAdded, unpack(Packet.Args))
									elseif Event == "CharacterAdded" then
										task.spawn(CharacterAdded, unpack(Packet.Args))
									elseif Event == "PlayerRemoving" then
										task.spawn(PlayerRemoving, unpack(Packet.Args))
									end
									Packet.Sent = true
								else
									table.remove(Log, I)
								end
							end
						end
						task.wait()
					end
				end)

				if RunService:IsServer() then
					local Success, Error = pcall(game.BindToClose, game, function()
						task.cancel(Thread)

						for _, Player in pairs(PlayerService:GetPlayers()) do
							task.spawn(PlayerRemoving, Player)
						end
					end)

					if not Success then
						error(`@Cardinal - Error binding to close: ` .. Error)
					end

					script:SetAttribute("ServerReady", true)
				end

				Started = true
				script:SetAttribute("Started", true)
				return Promise.resolve("@Cardinal - Started")
			end)
	end,
})
