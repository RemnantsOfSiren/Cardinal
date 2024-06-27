local HttpService = game:GetService("HttpService")

local Util = require(script.Parent.Parent.Utilities.Table)

local BridgeNet = require(script.Parent.Parent.Parent.BridgeNet) :: { any }
local LemonSignal = require(script.Parent.Parent.Parent.Signal) :: { any }
local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }

export type ReplicaConfig = {
	Name: string,
	Tags: { any }?,
	Data: { any },
	To: { Player } | Player | "All",
}

local Replicas = {}

local ReplicaServer = {}

local MainBridge = BridgeNet.ServerBridge("ReplicaServer")

MainBridge.OnServerInvoke = function(Player)
	local _Replicas = {}

	for Id, Replica in pairs(Replicas) do
		if
			(typeof(Replica.To) == "string" and Replica.To:lower() == "all")
			or (typeof(Replica.To) == "userdata" and Replica.To == Player)
			or (typeof(Replica.To) == "table" and table.find(Replica.To, Player))
		then
			if not _Replicas[Replica.Name] then
				_Replicas[Replica.Name] = {}
			end

			_Replicas[Replica.Name][Id] = {
				Tags = Util.CopyTable(Replica.Tags, true),
				Data = Util.CopyTable(Replica.Data, true),
			}
		end
	end

	return _Replicas
end

function ReplicaServer.NewReplica(Config: ReplicaConfig)
	local Id = HttpService:GenerateGUID(false)

	local Replica = {}

	Replica.Tags = Config.Tags or {}
	Replica.To = Config.To
	Replica.Name = Config.Name
	Replica.Cleaner = Trove.new()
	Replica.ServerEvents = {}

	function Replica:ConnectOnServerEvent(Callback: (...any) -> ())
		table.insert(Replica.ServerEvents, Callback)

		return function()
			table.remove(Replica.ServerEvents, table.find(Replica.ServerEvents, Callback))
		end
	end

	local Args = { "Create", Config.Name, Id, Replica.Tags, Config.Data }

	if Config.To == "All" then
		MainBridge:Fire(BridgeNet.AllPlayers(), Args)
	elseif typeof(Config.To) == "table" then
		MainBridge:Fire(BridgeNet.Players(Config.To), Args)
	else
		MainBridge:Fire(Config.To, Args)
	end

	--local Bridge = Bridges[Config.Name]
	Replica.Changed = LemonSignal.new()

	Replica.Changed:Connect(function(Indices, Value, OldValue)
		local _Args = { "Changed", Config.Name, Id, Indices, Value, OldValue }
		if Config.To == "All" then
			MainBridge:Fire(BridgeNet.AllPlayers(), _Args)
		elseif typeof(Config.To) == "table" then
			MainBridge:Fire(BridgeNet.Players(Config.To), _Args)
		else
			MainBridge:Fire(Config.To, _Args)
		end
	end)

	Replica.Cleaner:Add(MainBridge:Connect(function(Player, Args)
		local Event = Args[1]

		if Event ~= "Request" then
			return
		end

		if Args[2] == Config.Name and Args[3] == Id then
			for _, Callback in Replica.ServerEvents do
				task.spawn(Callback, Player, table.unpack(Args, 4))
			end
		end
	end), "Disconnect")

	Replica.Data = Config.Data

	local function Update(Indicies, Value)
		local Pointer = Replica.Data

		for I = 1, #Indicies - 1 do
			local Index = Indicies[I]
			Pointer = Pointer[Index] or Pointer[tonumber(Index)]
			if not Pointer then
				return warn(`Invalid Index: {Index}`)
			end
		end

		local LastIndex = Indicies[#Indicies]
		local Operator = if typeof(LastIndex) == "string" then LastIndex:match("[+%%-*/^]$") else nil

		if Operator then
			LastIndex = LastIndex:sub(1, LastIndex:find(Operator) - 1)
			Indicies[#Indicies] = LastIndex

			if typeof(Value) == "table" and not (Operator:find("+") or Operator:find("-")) then
				return warn("Invalid Operator for Table")
			end

			local CurrentValue = Pointer[LastIndex]

			if Operator:find("+") then
				if typeof(CurrentValue) == "table" then
					Value = Util.JoinTables(CurrentValue, { Value })

					local Keys = {}

					for Key in Value do
						if not CurrentValue[Key] then
							table.insert(Keys, Key)
						end
					end

					for _, Key in Keys do
						local _Indicies = table.clone(Indicies)
						_Indicies[#_Indicies + 1] = Key
						Replica.Changed:Fire(_Indicies, Value[Key], nil)
						CurrentValue[Key] = Value[Key]
					end

					return
				else
					CurrentValue += Value
				end
			elseif Operator:find("-") then
				if typeof(CurrentValue) == "table" then
					local Keys = {}

					for Key in CurrentValue do
						if Util.Equals(CurrentValue[Key], Value) then
							table.insert(Keys, Key)
						end
					end

					for _, Key in Keys do
						local _Indicies = table.clone(Indicies)
						_Indicies[#_Indicies + 1] = Key
						if typeof(Key) == "number" then
							table.remove(CurrentValue, Key)
						else
							CurrentValue[Key] = nil
						end
						Replica.Changed:Fire(_Indicies, nil, CurrentValue[Key])
					end
	
					return
				else
					CurrentValue -= Value
				end
			elseif Operator:find("*") then
				CurrentValue *= Value
			elseif Operator:find("/") then
				CurrentValue /= Value
			elseif Operator:find("^") then
				CurrentValue ^= Value
			elseif Operator:find("%") then
				CurrentValue %= Value
			end

			Value = CurrentValue
		end

		if Pointer[LastIndex] then
			local IndexType = Pointer[LastIndex] and "string" or "number"
			LastIndex = IndexType == "string" and LastIndex or tonumber(LastIndex)
		end

		local OldValue = Pointer[LastIndex]

		if typeof(OldValue) == "table" and typeof(Value) == "table" and Util.Equals(OldValue, Value, true) then
			return
		end

		if OldValue ~= Value then
			Pointer[LastIndex] = Value
			Indicies[#Indicies] = LastIndex
			Replica.Changed:Fire(Indicies, Value, OldValue)
		end

		return
	end

	function Replica:AddCleanupTask(Task: () -> nil)
		Replica.Cleaner:Add(Task, true)
	end

	function Replica:Set(Indicies: { unknown } | string, Value)
		local _Indicies: { unknown } = (
			if typeof(Indicies) == "string"
				then string.split(
					Indicies,
					(string.find(Indicies, ".") and ".") or (string.find(Indicies, "/") and "/")
				)
				else Indicies
		) :: { unknown }

		if #_Indicies == 0 and typeof(Value) == "table" then
			if Util.Equals(Replica.Data, Value, true) then
				return
			end

			local OldData = Util.CopyTable(Replica.Data, true)
			for Index, _Value in Value do
				if not OldData[Index] or OldData[Index] ~= _Value then
					Replica.Data[Index] = _Value
				end
			end
			Replica.Changed:Fire({}, Replica.Data, OldData)
		else
			Update(_Indicies, if typeof(Value) == "table" then Util.CopyTable(Value, true) else Value)
		end

		return nil
	end

	function Replica:ListenToChange(Indicies: { string | number } | string, Callback)
		local _Indicies: { unknown } = (
			if typeof(Indicies) == "string"
				then string.split(
					Indicies,
					(string.find(Indicies, ".") and ".") or (string.find(Indicies, "/") and "/")
				)
				else Indicies
		) :: { unknown }

		return Replica.Changed:Connect(function(ChangedIndicies, Value, OldValue)
			local Match = true

			for I, Index in pairs(_Indicies) do
				if Index ~= ChangedIndicies[I] then
					Match = false
					break
				end
			end

			if Match then
				task.spawn(Callback, Value, OldValue)
			end
		end)
	end

	function Replica:ListenToNewKey(Indicies: { string | number } | string, Callback)
		local _Indicies: { unknown } = (
			if typeof(Indicies) == "string"
				then string.split(
					Indicies,
					(string.find(Indicies, ".") and ".") or (string.find(Indicies, "/") and "/")
				)
				else Indicies
		) :: { unknown }

		return Replica.Changed:Connect(function(ChangedIndices, Value, OldValue)
			if not OldValue and ChangedIndices[#ChangedIndices - 1] == _Indicies[#_Indicies] then
				task.spawn(Callback, Value, ChangedIndices[#ChangedIndices])
			end
		end)
	end

	function Replica:ListenToKeyRemoved(Indicies: { string | number } | string, Callback)
		local _Indicies: { unknown } = (
			if typeof(Indicies) == "string"
				then string.split(
					Indicies,
					(string.find(Indicies, ".") and ".") or (string.find(Indicies, "/") and "/")
				)
				else Indicies
		) :: { unknown }

		return Replica.Changed:Connect(function(ChangedIndices, Value, OldValue)
			if not Value and ChangedIndices[#ChangedIndices - 1] == _Indicies[#_Indicies] then
				task.spawn(Callback, OldValue, ChangedIndices[#ChangedIndices])
			end
		end)
	end

	function Replica:Destroy()
		MainBridge:Fire({ "Destroy", Config.Name, Id })
		self.Changed:Destroy()
		self.Cleaner:Destroy()
		table.clear(self.Changed)
		table.clear(self.Cleaner)
		table.clear(self)
	end

	Replicas[Id] = Replica

	return Replica
end

return ReplicaServer
