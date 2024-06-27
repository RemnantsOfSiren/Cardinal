local BridgeNet = require(script.Parent.Parent.Parent.BridgeNet) :: { any }
local LemonSignal = require(script.Parent.Parent.Parent.Signal) :: { any }
local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }

local MainBridge = BridgeNet.ClientBridge("ReplicaServer")

local Replicators = {}

local function GetAllIndicies(Data)
	local Indicies = {}

	for Index, Value in pairs(Data) do
		if typeof(Value) == "table" then
			local SubIndicies = { Index }
			for _, SubIndex in GetAllIndicies(Value) do
				table.insert(Indicies, {
					unpack(table.clone(SubIndicies)),
					SubIndex,
				})
			end
			continue
		end

		table.insert(Indicies, { Index })
	end

	return Indicies
end

local function CreateReplicator(Name)
	local Replicator = {}
	Replicator.Replicas = {}

	Replicator.Added = LemonSignal.new()
	Replicators[Name] = Replicator

	function Replicator.AddNewReplica(Id, Tags, Data)
		if Replicator.Replicas[Id] then
			return
		end
		
		local Replica = {}

		Replica.Id = Id
		Replica.Tags = Tags
		Replica.Data = Data
		Replica.Changed = LemonSignal.new()
		Replica.Cleaner = Trove.new()
		Replica._Callbacks = {}

		function Replica:Update(Indicies, Value, OldValue)
			local Data = Replica.Data

			for I = 1, #Indicies - 1 do
				Data = Data[Indicies[I]]
			end

			if not Data then
				return
			end

			local LastIndex = Indicies[#Indicies]

			if typeof(LastIndex) == "number" then
				if not Data[LastIndex] then
					table.insert(Data, LastIndex, Value)
				elseif Value == nil then
					table.remove(Data, LastIndex)
				end
			else
				Data[Indicies[#Indicies]] = Value
			end

			Replica.Changed:Fire(Indicies, Value, OldValue)
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

		function Replica:FireServer(...)
			MainBridge:Fire({ "Request", Name, Id, ... })
		end

		function Replica:AddCleanupTask(Task: () -> nil)
			Replica.Cleaner:Add(Task, true)
		end

		function Replica:Destroy()
			Replicator.Replicas[Id] = nil
			Replica.Changed:Destroy()
			table.clear(Replica)
		end

		Replicator.Replicas[Id] = Replica
		Replicator.Added:Fire(Replica)
	end

	return Replicator
end

MainBridge:Connect(function(Args)
	if Args[1] == "Create" then
		local _, Name, Id, Tags, Data = unpack(Args)
		local Replicator = Replicators[Name] or CreateReplicator(Name)
		task.spawn(Replicator.AddNewReplica, Id, Tags, Data)
	elseif Args[1] == "Changed" then
		local _, Name, Id, Indicies, Value, OldValue = unpack(Args)
		local Replicator = Replicators[Name]

		if Replicator then
			local Replica = Replicator.Replicas[Id]

			if not Replica then
				return
			end

			if #Indicies == 0 then
				Indicies = GetAllIndicies(Value)

				for _, _Indicies in Indicies do
					local Pointer = Value
					local OldPointer = OldValue

					for I = 1, #_Indicies - 1 do
						local Index = _Indicies[I]
						Pointer = Pointer[Index]
						OldPointer = OldPointer[Index]
					end

					local Index = _Indicies[#_Indicies]
					Replica:Update(_Indicies, Pointer[Index], OldPointer[Index])
				end
				return
			end

			Replica:Update(Indicies, Value, OldValue)
		end
	elseif Args[1] == "Destroy" then
		local _, Name, Id = unpack(Args)
		local Replicator = Replicators[Name]
		if Replicator then
			local Replica = Replicator.Replicas[Id]
			if Replica then
				Replica:Destroy()
			end
		end
	end
end)

task.spawn(function()
	local Data = MainBridge:InvokeServerAsync()

	for Name, Replicas in Data do
		local Replicator = Replicators[Name] or CreateReplicator(Name)

		for Id, Info in pairs(Replicas) do
			task.spawn(Replicator.AddNewReplica, Id, Info.Tags, Info.Data)
		end
	end
end)

local ReplicaClient = {}

function ReplicaClient.ListenToNewReplica(Name: string, Callback: (unknown) -> ())
	local Replicator = Replicators[Name] or CreateReplicator(Name)
	Replicator.Added:Connect(Callback)

	for _, Replica in pairs(Replicator.Replicas) do
		task.spawn(Callback, Replica)
	end
end

return ReplicaClient
