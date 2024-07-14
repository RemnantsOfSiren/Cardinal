local BridgeNet = require(script.Parent.Parent.Parent.BridgeNet) :: { any }
local LemonSignal = require(script.Parent.Parent.Parent.Signal) :: { any }
local Trove = require(script.Parent.Parent.Parent.Trove) :: { any }

local Util = require(script.Parent.Parent.Utilities.Table) :: { any }

local MainBridge = BridgeNet.ClientBridge("ReplicaServer")

local Replica = newproxy(false)
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

	function Replicator.AddNewReplica(Id, Tags, Data, WriteLib)
		if Replicator.Replicas[Id] then
			return
		end
		
		local Replica = {
			__type = Replica,
		}
		
		Replica.WriteFunctionFlag = false
		Replica.WriteLib = WriteLib and require(WriteLib)
		Replica.Id = Id
		Replica.Tags = Tags
		Replica.Data = Data
		Replica.Changed = LemonSignal.new()
		Replica.Cleaner = Trove.new()
		Replica._Callbacks = {}
		Replica._WriteCallbacks = {}
		Replica._OldData = Util.CopyTable(Data, true)

		function Replica:Write(FunctionName: string, ...)
			if not Replica.WriteLib then
				warn(`No WriteLib exists for {Name} replica!`)
				return
			end

			if not Replica.WriteLib[FunctionName] then
				return
			end

			if self.WriteFunctionFlag == false then
				return
			end

			local ReturnedValues = Replica.WriteLib[FunctionName](Replica, ...)

			local Callbacks = Replica._WriteCallbacks

			if Callbacks[FunctionName] then
				for _, Callback in Callbacks do
					task.spawn(Callback, ...)
				end
			end

			return ReturnedValues
		end

		function Replica:Update(Indicies, Value, OldValue)
			Replica._OldData = Util.CopyTable(Replica.Data, true)
			local _Data = Replica.Data

			for I = 1, #Indicies - 1 do
				_Data = _Data[Indicies[I]]
			end

			if not _Data then
				return
			end

			local LastIndex = Indicies[#Indicies]

			if typeof(LastIndex) == "number" then
				if not _Data[LastIndex] then
					table.insert(_Data, LastIndex, Value)
				elseif Value == nil then
					table.remove(_Data, LastIndex)
				end
			else
				_Data[Indicies[#Indicies]] = Value
			end

			Replica.Changed:Fire(Indicies, Value, OldValue)
		end

		function Replica:Set() -- Add this so that the client doesn't error out whenever the server runs :Set
			return
		end

		function Replica:ListenToWrite(WriteFunction: string, Callback)
			local Callbacks = Replica._WriteCallbacks[WriteFunction]
			if not Callbacks then
				Callbacks = {}
				Replica._WriteCallbacks[WriteFunction] = Callbacks
			end
			table.insert(Callbacks, Callback)
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

			return Replica.Changed:Connect(function(ChangedIndicies)
				local Match = true
				local _Data = Replica.Data
				local _OldData = Replica._OldData

				for I, Index in pairs(_Indicies) do
					_Data = _Data[Index]
					_OldData = _OldData[Index]

					if Index ~= ChangedIndicies[I] then
						Match = false
						break
					end
				end

				if Match then
					task.spawn(Callback, _Data, _OldData)
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
		local _, Name, Id, Tags, Data, WriteLib = unpack(Args)
		local Replicator = Replicators[Name] or CreateReplicator(Name)
		task.spawn(Replicator.AddNewReplica, Id, Tags, Data, WriteLib)
	elseif Args[1] == "Changed" then
		local _, Name, Id, Indicies, Value, OldValue = unpack(Args)
		local Replicator = Replicators[Name]

		if Replicator then
			local _Replica = Replicator.Replicas[Id]

			if not _Replica then
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
					_Replica:Update(_Indicies, Pointer[Index], OldPointer[Index])
				end
				return
			end

			_Replica:Update(Indicies, Value, OldValue)
		end
	elseif Args[1] == "Write" then
		local Name = Args[2]
		local Id = Args[3]
		local FunctionName = Args[4]

		local NewArgs = {}
		for i = 5, #Args do
			table.insert(NewArgs, Args[i])
		end

		local Replicator = Replicators[Name]

		if Replicator then
			local _Replica = Replicator.Replicas[Id]

			_Replica.WriteFunctionFlag = true
			_Replica.WriteLib[FunctionName](_Replica, table.unpack(NewArgs))
			_Replica.WriteFunctionFlag = false

			local Callbacks = _Replica._WriteCallbacks[FunctionName]
			if Callbacks then
				for _, Callback in ipairs(Callbacks) do
					task.spawn(Callback, table.unpack(NewArgs))
				end
			end
		end
	elseif Args[1] == "Destroy" then
		local _, Name, Id = unpack(Args)
		local Replicator = Replicators[Name]
		if Replicator then
			local _Replica = Replicator.Replicas[Id]
			if _Replica then
				_Replica:Destroy()
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

local ReplicaClient = {
	Replica = Replica,
}

function ReplicaClient.ListenToNewReplica(Name: string, Callback: (unknown) -> ())
	local Replicator = Replicators[Name] or CreateReplicator(Name)
	Replicator.Added:Connect(Callback)

	for _, _Replica in pairs(Replicator.Replicas) do
		task.spawn(Callback, _Replica)
	end
end

return ReplicaClient
