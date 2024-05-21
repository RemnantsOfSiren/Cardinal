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

local Promise = require(script.Parent.Promise)
local Replicator = require(script.Replicator)
local Net = require(script.Net)

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
	Module = require(Module) -- ignore this linter error, it works fine it just doesn't like that it's an irregular path.
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

return {
    Replicator = if IsServer then Replicator.ReplicaServer else Replicator.ReplicaClient,
	Net = Net,

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
		@param Parent: Instance, Deep: boolean?, Exclusions: { string }? | The parent Instance to load from, whether to load deep, and any exclusions.
		@return void
	]]
	Load = function(Parent: Instance, Deep: boolean?, Exclusions: { string }?)
		if Started then
			return Promise.reject("Can't load Modules once the Loader is already started.")
		end

		local Modules = if Deep then Parent:GetDescendants() else Parent:GetChildren()

		for _, Module in pairs(Modules) do
			if Module:IsA("ModuleScript") then
				if Exclusions and IsAnExclusion(Exclusions, Module.Name) then
					continue
				end
				
				Load(Module)
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
					
					local Network = Net.new(Name)
					local GetEvents = Network:CreateEvent("GetEvents")
					local Events = GetEvents:Invoke()

					for _, Event in Events do
						local _Event = Network:CreateEvent(Event)

						_Net[Event] = function(_, ...)
							return _Event:Invoke(...)
						end
					end

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

		local Temp = {}

		for Name, Module in pairs(Loaded) do
			local Init = Module.OnInit or Module.Init

			if Init then
				table.insert(
					Temp,
					Promise.try(function()
						debug.profilebegin(`Initializing {Name}`)
						task.spawn(Init, Module)
						debug.profileend()
					end)
				)
			end
		end

		return Promise.allSettled(Temp)
			:andThen(function()
				table.clear(Temp)

				for Name, Module in pairs(Loaded) do
					local Start = Module.OnStart or Module.Start

					if Start then
						table.insert(
							Temp,
							Promise.try(function()
								debug.profilebegin(`Starting {Name}`)
								task.spawn(Start, Module)
								debug.profileend()
							end)
						)
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

                local Nets = {}

				for Name, Module in pairs(Loaded) do
                    if Module.Client then
						Module.Client.Server = Module
	
                        local _Net = Net.new(Module.Name or Name)
                        local ClientEvents = {}
                        local GetEvents = _Net:CreateEvent("GetEvents")

                        GetEvents:SetCallback(function()
                            return ClientEvents
                        end)
        
                        for Event, Callback in Module.Client do
                            if typeof(Callback) == "function" then
                                local _Event = _Net:CreateEvent(Event)
                                _Event:SetCallback(function(Player, ...) 
									return Callback(Module.Client, Player, ...)
								end)
                                table.insert(ClientEvents, Event)
                            end
                        end

                        table.insert(Nets, Name)
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

					local function CharacterAdded(Character)
						if not Character:IsDescendantOf(workspace) then
							while Player:IsDescendantOf(PlayerService) and not Character:IsDescendantOf(workspace) do
								task.wait()
							end

							if not Player:IsDescendantOf(PlayerService) then
								return
							end
						end

						Character:WaitForChild("HumanoidRootPart")

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

					if PlayerService.CharacterAutoLoads and Player.Character then
						task.spawn(CharacterAdded, Player.Character)
					end

					Player.CharacterAdded:Connect(CharacterAdded)
				end

				local function PlayerRemoving(Player)
					if #Events.PlayerService.PlayerRemoving then
						for _, Callback in pairs(Events.PlayerService.PlayerRemoving) do
							task.spawn(Callback, Player)
						end
					end
				end

				PlayerService.PlayerAdded:Connect(PlayerAdded)
				PlayerService.PlayerRemoving:Connect(PlayerRemoving)

				for _, Player in pairs(PlayerService:GetPlayers()) do
					task.spawn(PlayerAdded, Player)
				end

				if RunService:IsServer() then
					game:BindToClose(function()
						for _, Player in pairs(PlayerService:GetPlayers()) do
							task.spawn(PlayerRemoving, Player)
						end
					end)
				end

				if RunService:IsServer() then
					script:SetAttribute("ServerReady", true)
				end

				Started = true
			end)
	end,
}