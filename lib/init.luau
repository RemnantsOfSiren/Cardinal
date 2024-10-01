--!strict
--!optimize 2

--[[
	Created by Byran E.

	Loader is a simplistic module loader, similar to that of Knit.
	It offers a few more functions, and removes the internal API for Networking,
	allowing for developer freedom.

	All events will run after OnInit and OnStart. This is to ensure all dependencies are loaded and started before any events are fired.

	Service
	[
		OnInit?: () -> ()
		OnStart?: () -> ()
	
		OnPlayerAdded?: (Player: Player) -> ()
		OnPlayerRemoving?: (Player: Player) -> ()
		OnCharacterAdded?: (Character: Model, Player: Player) -> ()

		On[Stepped, Heartbeat, PreAnimation, PreSimulation, PostAnimation, PostSimulation]?: (...) -> ()
	]

	```lua
		local Service = {}

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

	Controller
	[
		OnInit?: () -> ()
		OnStart?: () -> ()
	
		OnPlayerAdded?: (Player: Player) -> ()
		OnPlayerRemoving?: (Player: Player) -> ()
		OnCharacterAdded?: (Character: Model, Player: Player) -> ()

		OnLocalPlayer?: (Player: Player) -> () -> Only fires for the local Player
		OnLocalCharacter?: (Character: Model, Player: Player) -> () -> Only fires for the local Character

		On[Stepped, RenderStepped, Heartbeat, PreAnimation, PreSimulation, PostAnimation, PostSimulation]?: (...) -> ()
	]

	
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
]]

local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")

local Promise = require(script.Parent.Promise) :: { [any]: any }

local Net = require(script.Net)

type Packet = {
	Args: { [any]: any },
	Sent: boolean,
}

local EventLog: { [string]: { Packet }} = {
	["PlayerAdded"] = {},
	["CharacterAdded"] = {},
	["PlayerRemoving"] = {},
} -- Pre-emptive table in-case events are fired before the client/server is ready.

local function CreatePacket(...): Packet
	return {
		Args = {...},
		Sent = false,
	}
end

local function OnPlayerAdded(Player)
	table.insert(EventLog["PlayerAdded"], CreatePacket(Player))

	local function OnCharacterAdded(Character)
		table.insert(EventLog["CharacterAdded"], CreatePacket(Character, Player))
	end

	local Character = Player.Character or Player.CharacterAdded:Wait()
	OnCharacterAdded(Character)
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
	Module = require(Module) :: any
	if typeof(Module) == "table" then
		Loaded[Name] = Module
	end
end

local function IsAnExclusion(Exclusions: {string}, Name: string): boolean
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

return table.freeze({
	Net = Net,
	Icon = if not IsServer then require(script.Icon) else nil,
	Player = if not IsServer then PlayerService.LocalPlayer else nil,
	
	CreateSignal = function()
		return Signal
	end,

	CreateProperty = function(InitialValue: any)
		return {Property, InitialValue } 
	end,

	--[[
		@function OnStart
		@description Waits for the Loader to start.
		@return Promise<void>
	]]
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

	--[[
		@function Load
		@description Loads a ModuleScript into the Loader.
		@param Parent: Instance, DeeporPredicate: (ModuleScript) -> boolean |boolean?, Exclusions: { string }? | The parent Instance to load from, whether to load deep, and any exclusions.
		@return void
	]]
	Load = function(Parent: Instance, DeepOrPredicate: ((ModuleScript) -> boolean) | boolean?, Exclusions: { string }?)
		if Started then
			return Promise.reject("Can't load Modules once the Loader is already started.")
		end

		if not DeepOrPredicate then
			DeepOrPredicate = false
		end

		local Modules = {} :: { Instance }

		if typeof(DeepOrPredicate) == "function" then
			for _, ModuleScript in Parent:GetDescendants() do
				if ModuleScript:IsA("ModuleScript") and DeepOrPredicate(ModuleScript) then
					table.insert(Modules, ModuleScript)
				end
			end
		elseif typeof(DeepOrPredicate) == "boolean" then
			Modules = if DeepOrPredicate then 
				Parent:GetDescendants() else Parent:GetChildren()
		end

		for _, Object in pairs(Modules) do
			if Object:IsA("ModuleScript") then
				if Exclusions and IsAnExclusion(Exclusions, Object.Name) then
					continue
				end
				
				Load(Object)
			end
		end

		return Promise.resolve("Completed")
	end,

	--[[
		@function GetService
		@description Gets a service from the Loader by name (client only, and case sensitive).
		@return table | nil
	]]
    GetService = function(Name: string)
        if IsServer then
            return warn("GetService can only be called on the Client.")
        end
        
        if CachedNets then
            local Found = CachedNets[Name]

            if Found then
                return Found
            else
				local NetworkEvents = script:WaitForChild("NetworkEvents")
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

	--[[
		@function Start
		@description Starts the Loader, initializing and starting all services/controllers.
		@return Promise<void>
	]]
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
					elseif typeof(Callback) == "table" and typeof(Callback[1]) == "userdata" and Callback[1] == Property then
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
				task.spawn(function() 
					debug.profilebegin(`Initializing {Name}`)
					table.insert(Temp, Promise.try(function()
						Module.__Initialized = false
						Init(Module) 
						Module.__Initialized = true
					end))
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
						task.spawn(function() 
							debug.profilebegin(`Starting {Name}`)
							table.insert(Temp, Promise.try(function()
								Module.__Started = false
								Start(Module) 
								Module.__Started = true
							end))
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

				for Name, Module in pairs(Loaded) do
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

				local function CharacterAdded(Character, Player)
					if not Character:IsDescendantOf(workspace) then
						while Player:IsDescendantOf(PlayerService) and not Character:IsDescendantOf(workspace) do
							task.wait()
						end

						if not Player:IsDescendantOf(PlayerService) then
							return
						end
					end

					local Start = tick()

					while not Character.PrimaryPart and tick() - Start < 10 do
						task.wait()
					end
					
					if tick() - Start >= 10 then
						warn("Character's PrimaryPart took too long to be parented. Some code may not function as expected.")
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

				local function PlayerAdded(Player)
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
					game:BindToClose(function()
						task.cancel(Thread)

						for _, Player in pairs(PlayerService:GetPlayers()) do
							task.spawn(PlayerRemoving, Player)
						end
					end)
			
					script:SetAttribute("ServerReady", true)
				end

				Started = true
			end)
	end,
})