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
	@prop Name? string
	@within Service
	@within Controller
	Name of the Service/Controller.
]=]
--[=[
	@prop Priority? number
	@within Service
	@within Controller
	Priority of the Service/Controller.
]=]
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

--[[
================================================================================
Services
================================================================================
]]
local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")


--[[
================================================================================
Dependencies
================================================================================
]]
local Net = require("@self/Net") :: { [any]: any }
local Trove = require("./Trove") :: { [any]: any }
local Signal = require("./Signal") :: { [any]: any }
local Promise = require("./Promise") :: { [any]: any }

--[[
================================================================================
Types
================================================================================
]]
type Promise<T> = {
	catch: (self: Promise<T>, Callback: (any) -> any) -> Promise<T>,
	andThen: (self: Promise<T>, Callback: (T) -> any) -> Promise<T>,
	finally: (self: Promise<T>, Callback: () -> any) -> Promise<T>,
}

type Packet = {
	Args: { [any]: any },
	Sent: boolean,
}

export type LoadOptions = {
  Deep: boolean?,
  Predicate: ((ModuleScript) -> boolean)?,
  Exclusions: { string }?,
}

type Runnable = {
	Name: string?,
	Priority: number?,
	_Started: boolean?,
	_Initialized: boolean?,
	OnInit: (self: Runnable) -> ()?,
	OnStart: (self: Runnable) -> ()?,
	
	OnStepped: (self: Runnable, StartTime: number, DeltaTime: number) -> ()?,
	OnHeartbeat: (self: Runnable, DeltaTime: number) -> ()?,
	
	OnPreSimulation: (self: Runnable, DeltaTime: number) -> ()?,
	OnPostSimulation: (self: Runnable, DeltaTime: number) -> ()?,
	
	OnPreAnimation: (self: Runnable, DeltaTime: number) -> ()?,
	OnPostAnimation: (self: Runnable, DeltaTime: number) -> ()?,
	
	OnPlayerAdded: (self: Runnable, Player: Player) -> ()?,
	OnPlayerRemoving: (self: Runnable, Player: Player) -> ()?,
	OnCharacterAdded: (self: Runnable, Character: Model, Player: Player) -> ()?,
}

export type ServerSignal = Net.ServerSignal
export type ServerProperty<T> = Net.ServerProperty<T>

export type ClientSignal = Net.ClientSignal
export type ClientProperty<T> = Net.ClientProperty<T>

export type Service = Runnable & {
	Client: { [string]: any }?,
}

export type Controller = Runnable & {
	OnInit: () -> ()?,
	OnStart: () -> ()?,
	OnLocalPlayer: (Player: Player) -> ()?,
	OnRenderStepped: (DeltaTime: number) -> ()?,
	OnLocalCharacter: (Character: Model, Player: Player) -> ()?,
}
--[[
================================================================================
Variables
================================================================================
]]
local IsServer = RunService:IsServer()
local IsStudio = RunService:IsStudio()

local Cleaner = Trove.new()

local EventLog: { [string]: { Packet } } = {
	["PlayerAdded"] = {},
	["CharacterAdded"] = {},
	["PlayerRemoving"] = {},
}

local Connection = {}

local Loaded = {}
local Started = false
local CachedNets = if not IsServer then {} else nil

local SignalMarker = newproxy(true)
getmetatable(SignalMarker).__tostring = function()
	return "SIGNAL_MARKER"
end

local PropertyMarker = newproxy(true)
getmetatable(PropertyMarker).__tostring = function()
	return "PROPERTY_MARKER"
end

local BindToCloseSignal = if IsServer then Signal.new() else nil

local CustomEvents = {
  ["BindToClose"] = BindToCloseSignal,
}

local ServicePromise = false

--[[
================================================================================
Private Methods
================================================================================
]]
local function CreatePacket(...): Packet
	return {
		Args = { ... },
		Sent = false,
	}
end

local function OnCharacterAdded(Character: Model, Name: string)
	table.insert(EventLog["CharacterAdded"], CreatePacket(Character, Name))
end

local function OnPlayerAdded(Player: Player)
	local Name = Player.Name

	table.insert(EventLog["PlayerAdded"], CreatePacket(Name))

	if Player.Character then
		task.spawn(OnCharacterAdded, Player.Character, Name)
	end

	Connection[Name] = Player.CharacterAdded:Connect(function(Character)
		task.spawn(OnCharacterAdded, Character, Name)
	end)
end

local function Load(Module: ModuleScript)
  local Name = Module.Name

  local Success, Error = pcall(function()
    Module = require(Module) :: any
  end)

	if Success then
		if typeof(Module) == "table" then
			Loaded[Name] = Module
		else
			if IsStudio then
				warn(`@Cardinal - Warning: {Name} module does not return a table. This has not been loaded.`)
			end
		end
	else
		error(`@Cardinal - Error Loading {Name}: ` .. Error :: string)
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

--[[
================================================================================
Initialize
================================================================================
]]
Cleaner:Connect(PlayerService.PlayerAdded, OnPlayerAdded)

for _, Player in PlayerService:GetPlayers() do
	task.spawn(OnPlayerAdded, Player)
end

Cleaner:Connect(PlayerService.PlayerRemoving, function(Player)
	table.insert(EventLog["PlayerRemoving"], CreatePacket(Player))

	local Name = Player.Name
	if Connection[Name] then
		Connection[Name]:Disconnect()
		Connection[Name] = nil
	end
end)

if not IsServer then
	if workspace.StreamingEnabled and IsStudio then
		-- Run this warning only in studio, to avoid from people who don't understand reporting this as an issue.
		warn("Some-things may not function as expected due to StreamingEnabled.")
	end

	if not script:GetAttribute("ServerReady") then
		while not script:GetAttribute("ServerReady") do
			task.wait()
		end
  end
else
  game:BindToClose(function(Reason: Enum.CloseReason)
    if BindToCloseSignal then
      BindToCloseSignal:Fire(Reason)
    end

    Cleaner:Destroy()
  end)
end

--[=[
	@function Load
	@within Cardinal
	@param Parent: Instance
	@param LoadOptions { Deep: boolean?, Predicate: ((ModuleScript) -> boolean)?, Exclusions: { string }? }?
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
	@param Options: { ServicePromise: boolean?, Timeout: number? }?
	@return Promise<string>
	Starts the Loader, initializing and starting all services/controllers.
	Options:
		ServicePromise is an optional boolean that will determine if the client callback functions should return a Promise.
		Timeout is an optional number that will determine the timeout for the initialization and starting of the services/controllers.
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
	@return SignalMarker
	Flags that a new "Remote" Signal should be made
]=]

--[=[
	@function CreateProperty
	@within Cardinal
	@return PropertyMarker
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
	@function AddCustomLifecycle
	@within Cardinal
	@param Name: string
	@param Signal: any
	Adds a custom lifecycle event to the Loader. This will allow you to add custom events that can be used in your services/controllers.
]=]

--[=[
	@class Cardinal	
	The main driver functions for Cardinal
]=]

--[[
================================================================================
Return
================================================================================
]]
return {
	Player = if not IsServer then PlayerService.LocalPlayer else nil,
	
	AddCustomLifecycle = function(Name: string, _Signal: any)
		if CustomEvents[Name] then
			return Promise.reject("Custom lifecycle already exists.")
		end
		
		CustomEvents[Name] = _Signal
		
		if Started then
			Cleaner:Connect(_Signal, function(...) 
				for _, Module in pairs(Loaded :: { [any]: any }) do
					local Lifecycle = Module[`On{Name}`] or Module[Name]

					if Lifecycle and typeof(Lifecycle) == "function" then
						task.spawn(Lifecycle, Module, ...)
					end
				end
			end)
		end
	end,

	CreateSignal = (if IsServer then function()
		return SignalMarker
	end else function()
		warn("@Cardinal - CreateSignal can only be called on the Server.")
		return nil
	end) :: () -> Net.ServerSignal?,

	CreateProperty = (if IsServer then function(InitialValue: any)
		return { PropertyMarker, InitialValue } :: any -- ignore this linter issue as this point in memory gets overridden later
	end else function()
		warn("@Cardinal - CreateProperty can only be called on the Server.")
		return nil
	end) :: (InitialValue: any) -> Net.ServerProperty<any>?,

	OnStart = function()
		if Started then
			return Promise.resolve()
		else
			return Promise.new(function(Resolve)
				repeat
					task.wait()
				until Started
				return Resolve()
			end)
		end
	end,

	Load = function(Parent: Instance, LoadOptions: LoadOptions?)
		if Started then
			if IsStudio then
				warn("Can't load Modules once the Loader is already started.")
			end

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

	GetService = function(Name: string): { [string]: any }?
		if IsServer then
			if IsStudio then
				warn("GetService can only be called on the Client.")
			end

			return nil
		end

		if CachedNets then
			local Found = CachedNets[Name]

			if Found then
				return Found
			else
				local NetworkEvents = script:WaitForChild("NetworkEvents") :: StringValue
				local Nets = NetworkEvents.Value:split(":")

				if table.find(Nets, Name) then
					local _Net: { [any]: any } = {}

					local Network = Net.new(Name) :: { CreateEvent: (any, string) -> { [any]: any } }

					local GetEvents = Network:CreateEvent("GetEvents")
					local GetSignals = Network:CreateEvent("GetSignals")
					local GetProperties = Network:CreateEvent("GetProperties")

					for _, Event in GetEvents:Invoke() do
						local _Event = Network:CreateEvent(Event)

						_Net[Event] = function(_, ...)
							if ServicePromise then
								local Args = { ... }
								return Promise.new(function(Resolve)
									return Resolve(_Event:Invoke(unpack(Args)))
								end)
							else
								return _Event:Invoke(...)
							end
						end
					end

					for _, Info in GetProperties:Invoke() do
						_Net[Info[1]] = Net.CreateProperty(Network, Info[1], Info[2], ServicePromise)
					end

					for _, _Signal in GetSignals:Invoke() do
						_Net[_Signal] = Net.CreateSignal(Network, _Signal)
					end

					_Net.Bridge = Network

					CachedNets[Name] = _Net
					return _Net :: any
				end
			end
		end

		return nil
	end,

	Start = function(Options: { ServicePromise: boolean?, Timeout: number? }?)
		if Started then
			return Promise.reject("Loader is already started.")
		end

		if Options and Options.ServicePromise ~= nil then
			ServicePromise = Options.ServicePromise
		end

		local Nets = {}
		local Temp: { any } = {}
		local Timeout = if Options and Options.Timeout then Options.Timeout else 10

		local Modules = {} :: { Controller | Service }

		for Name, Module in pairs(Loaded) do
			if typeof(Module) == "table" and not Module.Name then
				Module.Name = Name
			end

			table.insert(Modules, Module)
		end

		table.sort(Modules, function(A: Controller | Service, B: Controller | Service)
			return (A.Priority or 0) < (B.Priority or 0)
		end)

		for _, Module in pairs(Modules) do
			local HasClient = typeof(Module) == "table" and (Module :: Service).Client ~= nil
			local Client = (Module :: Service).Client :: any

			if HasClient then
				local Name = (Module :: Service).Name :: string
				Client.Server = Module

				local _Net = Net.new(Name) :: { CreateEvent: (any, string) -> { [any]: any } }
				(Module :: any).Net = _Net

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

				if IsServer and Client then
					for Event, Callback in Client do
						local typeOfCallback = typeof(Callback)

						if typeOfCallback == "function" then
							local _Event = _Net:CreateEvent(Event)

							_Event:SetCallback(function(Player, ...)
								return Callback(Client, Player, ...)
							end)

							table.insert(ClientEvents, Event)
						elseif typeOfCallback == "userdata" and Callback == SignalMarker then
							Client[Event] = Net.CreateSignal(_Net, Event)
							table.insert(ClientSignals, Event)
						elseif
							typeOfCallback == "table"
							and typeof(Callback[1]) == "userdata"
							and Callback[1] == PropertyMarker
						then
							local InitialValue = Callback[2]
							Client[Event] = Net.CreateProperty(_Net, Event, InitialValue)
							table.insert(ClientProperties, { Event, InitialValue })
						end
					end
				elseif not IsServer and Client then
					warn(`@Cardinal - Creating Client Exposed functionality should be handled on the Server. Please remove .Client from {Module.Name} Controller.`)
				end

				table.insert(Nets, Module.Name)
			end
		end

		for _, Module: Runnable in pairs(Modules) do
			local Name = Module.Name
			local Init = Module.OnInit :: (self: Runnable) -> ()?

			if Init then
				(Module :: Runnable)._Initialized = false
				
				Cleaner:Add(task.spawn(function()
					local T = tick()

					repeat
						task.wait()
					until tick() - T > Timeout or Module._Initialized

					if not Module._Initialized then
						warn(`@Cardinal - module: {Name} took too long to initialize.`)
					end
				end), true)

				Cleaner:Add(task.spawn(function()
					debug.profilebegin(`Initializing {Name}`)
					table.insert(
						Temp,
						Promise.try(function()
							Init(Module :: Runnable)
							Module._Initialized = true
						end) :: any
					)
					debug.profileend()
				end), true)
			end
		end

		return Promise.allSettled(Temp)
			:andThen(function()
				table.clear(Temp)

				for _, Module: Runnable in pairs(Modules) do
					local Name = Module.Name
					local Start = Module.OnStart

					if Start then
						Module._Started = false
						Cleaner:Add(task.spawn(function()
							local T = tick()

							repeat
								task.wait()
							until tick() - T > Timeout or Module._Started

							if not Module._Started then
								warn(`@Cardinal - module: {Name} took too long to start.`)
							end
						end), true)

						Cleaner:Add(task.spawn(function()
							debug.profilebegin(`Starting {Name}`)
							table.insert(
								Temp,
								Promise.try(function()
									Start(Module)
									Module._Started = true
								end) :: any
							)
							debug.profileend()
						end), true)
					end
				end
			end)
			:finally(function()
				local Events: {
					RunService: { [string]: { (...any) -> () } },
					PlayerService: { [string]: { (...any) -> () } },
					CustomEvents: { [string]: { (...any) -> () } },
				} = {
					RunService = {},
					PlayerService = {
						PlayerAdded = {},
						CharacterAdded = {},
						PlayerRemoving = {},
					},
					CustomEvents = {},
				}

				for Event in pairs(CustomEvents) do
					if not Events.CustomEvents[Event] then
						Events.CustomEvents[Event] = {}
					end
				end

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

					for Function: string, Callback: any in pairs(Module :: { [string]: any }) do
						if Function == "Name" or typeof(Callback) ~= "function" then
							continue
						end

						local Event: string = string.gsub(Function, "On", "")

						local Success = pcall(function()
							local C = (RunService :: any)[Event]:Once(function() end)
							if C then
								C:Disconnect()
							end
						end)

						if Success then
							if not Events.RunService[Event] then
								Events.RunService[Event] = {}
							end

							table.insert(Events.RunService[Event], function(...)
								(Callback :: (any, ...any)->())(Module, ...)
							end)
						elseif Events.PlayerService[Event] then
							table.insert(Events.PlayerService[Event], function(...)
								(Callback :: (any, ...any)->())(Module, ...)
							end)
						elseif CustomEvents[Event] then
							table.insert(Events.CustomEvents[Event], function(...)
								(Callback :: (any, ...any)->())(Module, ...)
							end)
						end
					end
				end

				for Event, Callbacks in pairs(Events.RunService) do
					Cleaner:Connect((RunService :: any)[Event], function(...)
						for _, Callback in pairs(Callbacks) do
							task.spawn((Callback :: (...any)->()), ...)
						end
					end)
				end

				for Event, _Signal in pairs(CustomEvents) do
					Cleaner:Connect(_Signal, function(...)
						for _, Callback in pairs(Events.CustomEvents[Event]) do
							task.spawn((Callback :: (...any)->()), ...)
						end
					end)
				end

				local function CharacterAdded(Character: Instance, Player: Player)
					local Name = Player.Name

					if not Character:IsDescendantOf(workspace) then
						while PlayerService:FindFirstChild(Name) and not Character:IsDescendantOf(workspace) do
							task.wait()
						end

						if not PlayerService:FindFirstChild(Name) then
							return
						end
					end

					local Start = tick()

					if Character:IsA("Model") then
						while not Character.PrimaryPart and tick() - Start < Timeout do
							task.wait()
						end
					end

					if tick() - Start >= Timeout then
						warn(
							"Character's PrimaryPart took too long to be parented. Some code may not function as expected."
						)
					end

					if #Events.PlayerService.CharacterAdded > 0 then
						for _, Callback in pairs(Events.PlayerService.CharacterAdded) do
							task.spawn((Callback :: (...any)->()), Character, Player)
						end
					end
					
					if
						RunService:IsClient()
						and Player == PlayerService.LocalPlayer
						and #Events.PlayerService.LocalCharacter > 0
					then
						for _, Callback in pairs(Events.PlayerService.LocalCharacter) do
							task.spawn((Callback :: (...any)->()), Character, Player)
						end
					end
				end

				local function PlayerAdded(Player: Player)
					if #Events.PlayerService.PlayerAdded > 0 then
						for _, Callback in pairs(Events.PlayerService.PlayerAdded) do
							task.spawn((Callback :: (...any)->()), Player)
						end
					end

					if
						RunService:IsClient()
						and Player == PlayerService.LocalPlayer
						and #Events.PlayerService.LocalPlayer > 0
					then
						for _, Callback in pairs(Events.PlayerService.LocalPlayer) do
							task.spawn((Callback :: (...any)->()), Player)
						end
					end
				end

				local function PlayerRemoving(Player)
					if #Events.PlayerService.PlayerRemoving then
						for _, Callback in pairs(Events.PlayerService.PlayerRemoving) do
							task.spawn((Callback :: (...any)->()), Player)
						end
					end
				end

				task.spawn(function()
					while true do
						for Event: string, Log: { Packet } in EventLog do
							for I = #Log, 1, -1 do
								local Packet: Packet = Log[I]
								
								if not Packet then
									continue
								end

								if not Packet.Sent then
									if Event == "PlayerAdded" then
										local Name = Packet.Args[1]
										local Player = PlayerService:FindFirstChild(Name)
										if not Player then
											if IsStudio then
												print("Player no longer exists: ", Name)
											end
											table.remove(Log, I)
											continue
										end
										task.spawn(PlayerAdded, Player :: Player)
										Player = nil
									elseif Event == "CharacterAdded" then
										local Character = Packet.Args[1]
										local Name = Packet.Args[2]
										local Player = PlayerService:FindFirstChild(Name)
										if not Player then
											if IsStudio then
												print("Player no longer exists: ", Name)
											end
											table.remove(Log, I)
											continue
										end
										task.spawn(CharacterAdded, Character, Player :: Player)
										Player = nil
									elseif Event == "PlayerRemoving" then
										local Player = Packet.Args[1]	
										task.spawn(PlayerRemoving, Player)
										Player = nil
									end

									Packet.Sent = true
									table.remove(Log, I)
								end
							end
						end
						
						task.wait()
					end
				end)
				
				if RunService:IsServer() then
					local _Net = Instance.new("StringValue")
					_Net.Name = "NetworkEvents"
					_Net.Value = table.concat(Nets, ":")
					_Net.Parent = script
					script:SetAttribute("ServerReady", true)
				end

				Started = true
				return Promise.resolve("@Cardinal - Started")
			end)
	end,
} :: {
	Load: (Parent: Instance, LoadOptions: LoadOptions?) -> Promise<string>,
	Start: (Options: { ServicePromise: boolean?, Timeout: number? }?) -> Promise<string>,
	OnStart: () -> Promise<nil>,
	GetService: (Name: string) -> { [string]: any }?,
	CreateSignal: () -> Net.ServerSignal?,
	CreateProperty: (InitialValue: any) -> Net.ServerProperty<any>?,
	AddCustomLifecycle: (Name: string, Signal: any) -> nil,
}
