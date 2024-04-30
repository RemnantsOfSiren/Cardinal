local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Parent.Utilities.Table)

local BridgeNet = require(ReplicatedStorage.Packages._Index["ffrostflame_bridgenet2@1.0.0"]["bridgenet2"])
local LemonSignal = require(ReplicatedStorage.Packages._Index["data-oriented-house_lemonsignal@1.10.0"]["lemonsignal"])
local Trove = require(ReplicatedStorage.Packages._Index["sleitnick_trove@1.2.0"]["trove"])

export type ReplicaConfig = {
	Name: string,
	Tags: { any }?,
	Data: { any },
	To: { Player } | Player | "All",
}

local Bridges = {}
local Replicas = {}

local ReplicaServer = {}

local MainBridge = BridgeNet.ServerBridge("ReplicaServer")

MainBridge.OnServerInvoke = function(Player)
	local _Replicas = {}

	for Id, Replicator in pairs(Replicas) do
		if
			(typeof(Replicator.To) == "string" and Replicator.To:lower() == "all")
			or (typeof(Replicator.To) == "userdata" and Replicator.To == Player)
			or (typeof(Replicator.To) == "table" and table.find(Replicator.To, Player))
		then
			if not _Replicas[Replicator.Name] then
				_Replicas[Replicator.Name] = {}
			end

			_Replicas[Replicator.Name][Id] = {
				Tags = Util.CopyTable(Replicator.Tags, true),
				Data = Util.CopyTable(Replicator.Data, true),
			}
		end
	end

	return _Replicas
end

function ReplicaServer.NewReplica(Config: ReplicaConfig)
	local Id = HttpService:GenerateGUID(false)

	local Replicator = {}

	Replicator.Tags = Config.Tags or {}
	Replicator.To = Config.To
	Replicator.Name = Config.Name
	Replicator.Cleaner = Trove.new()
	Replicator.ServerEvents = {}

	function Replicator:ConnectOnServerEvent(Callback: (...any) -> ())
		table.insert(Replicator.ServerEvents, Callback)

		return function()
			table.remove(Replicator.ServerEvents, table.find(Replicator.ServerEvents, Callback))
		end
	end

	if not Bridges[Config.Name] then
		Bridges[Config.Name] = BridgeNet.ServerBridge(Config.Name)
	end

	local Args = { "Create", Config.Name, Id, Replicator.Tags, Config.Data }

	if Config.To == "All" then
		MainBridge:Fire(BridgeNet.AllPlayers(), Args)
	elseif typeof(Config.To) == "table" then
		MainBridge:Fire(BridgeNet.Players(Config.To), Args)
	else
		MainBridge:Fire(Config.To, Args)
	end

	local Bridge = Bridges[Config.Name]
	Replicator.Changed = LemonSignal.new()

	Replicator.Changed:Connect(function(Indices, Value, OldValue)
		local Args = { Id, Indices, Value, OldValue }
		if Config.To == "All" then
			Bridge:Fire(BridgeNet.AllPlayers(), Args)
		elseif typeof(Config.To) == "table" then
			Bridge:Fire(BridgeNet.Players(Config.To), Args)
		else
			Bridge:Fire(Config.To, Args)
		end
	end)

	Bridge:Connect(function(Player, Args)
		local Event = Args[1]

		if Event == "Request" and Args[2] == Id then
			for _, Callback in Replicator.ServerEvents do
				task.spawn(Callback, Player, table.unpack(Args, 3))
			end
		end
	end)

	Replicator.Data = Config.Data

	local function Update(Indicies, Value)
		local Pointer = Replicator.Data

		for I = 1, #Indicies - 1 do
			local Index = Indicies[I]
			Pointer = Pointer[Index] or Pointer[tonumber(Index)]
			if not Pointer then
				return warn(`Invalid Index: {Index}`)
			end
		end

		local LastIndex = Indicies[#Indicies]
		local Operator = LastIndex:match("[+%%-*/^]$")

		if Operator then
			LastIndex = LastIndex:sub(1, LastIndex:find(Operator) - 1)

			if typeof(Value) == "table" and not (Operator:find("+") or Operator:find("-")) then
				return warn("Invalid Operator for Table")
			end

			local CurrentValue = Pointer[LastIndex]

			if Operator:find("+") then
				if typeof(CurrentValue) == "table" then
					Value = Util.JoinTables(CurrentValue, { Value })
				else
					Value += CurrentValue
				end
			elseif Operator:find("-") then
				if typeof(Value) == "table" then
					Value = Util.RemoveValue(CurrentValue, Value)
				else
					Value += CurrentValue
				end
			elseif Operator:find("*") then
				Value *= Pointer[LastIndex]
			elseif Operator:find("/") then
				Value /= Pointer[LastIndex]
			elseif Operator:find("^") then
				Value ^= Pointer[LastIndex]
			elseif Operator:find("%") then
				Value %= Pointer[LastIndex]
			end
		end

		if Pointer[LastIndex] then
			local IndexType = Pointer[LastIndex] and "string" or "number"
			LastIndex = IndexType == "string" and LastIndex or tonumber(LastIndex)
		end

		local OldValue = Pointer[LastIndex]

		if OldValue ~= Value then
			Pointer[LastIndex] = Value
			Indicies[#Indicies] = LastIndex
			Replicator.Changed:Fire(Indicies, Value, OldValue)
		end

		return
	end

	function Replicator:AddCleanupTask(Task: () -> nil)
		Replicator.Cleaner:Add(Task, true)
	end

	function Replicator:Set(Indicies: { unknown } | string, Value)
		local _Indicies: { unknown } = (
			if typeof(Indicies) == "string"
				then string.split(
					Indicies,
					(string.find(Indicies, ".") and ".") or (string.find(Indicies, "/") and "/")
				)
				else Indicies
		) :: { unknown }

		if #_Indicies == 0 and typeof(Value) == "table" then
			local OldData = Util.CopyTable(Replicator.Data, true)
			Replicator.Data = Util.CopyTable(Value)
			Replicator.Changed:Fire({}, Replicator.Data, OldData)
		else
			Update(_Indicies, if typeof(Value) == "table" then Util.CopyTable(Value, true) else Value)
		end

		return nil
	end

	function Replicator:Destroy()
		MainBridge:Fire({ "Destroy", Config.Name, Id })
		self.Changed:Destroy()
		self.Cleaner:Destroy()
		table.clear(self.Changed)
		table.clear(self.Cleaner)
		table.clear(self)
	end

	Replicas[Id] = Replicator

	return Replicator
end

return ReplicaServer
