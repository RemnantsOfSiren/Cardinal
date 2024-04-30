local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BridgeNet = require(ReplicatedStorage.Packages._Index["ffrostflame_bridgenet2@1.0.0"]["bridgenet2"])
local LemonSignal = require(ReplicatedStorage.Packages._Index["data-oriented-house_lemonsignal@1.10.0"]["lemonsignal"])
local Trove = require(ReplicatedStorage.Packages._Index["sleitnick_trove@1.2.0"]["trove"])

local MainBridge = BridgeNet.ClientBridge("ReplicaServer")

local Replicators = {}

local function CreateReplicator(Name)
	local Replicator = {}
	Replicator.Replicas = {}

	Replicator.Added = LemonSignal.new()
	Replicators[Name] = Replicator

	local Bridge = BridgeNet.ClientBridge(Name)

	function Replicator.AddNewReplica(Id, Tags, Data)
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

			Data[Indicies[#Indicies]] = Value
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

		function Replica:FireServer(...)
			Bridge:Fire({ "Request", Id, ... })
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

	Bridge:Connect(function(Args)
		local Id, Indicies, Value, OldValue = unpack(Args)

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
	end)

	return Replicator
end

MainBridge:Connect(function(Args)
	local Event = table.remove(Args, 1)
	if Event == "Create" then
		local Name, Id, Tags, Data = unpack(Args)
		local Replicator = Replicators[Name] or CreateReplicator(Name)
		task.spawn(Replicator.AddNewReplica, Id, Tags, Data)
	elseif Event == "Destroy" then
		local Name, Id = unpack(Args)
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
