local Util = {}

function Util.CopyTable(Table: { any }, Deep: boolean?)
	local NewTable = {}

	for Index, Value in pairs(Table) do
		if typeof(Value) == "table" and Deep then
			NewTable[Index] = Util.CopyTable(Value, Deep)
		else
			NewTable[Index] = Value
		end
	end

	return NewTable
end

function Util.JoinTables(...)
	local NewTable = {}

	for _, Table in pairs({ ... }) do
		for Index, Value in pairs(Table) do
			if typeof(Index) == "number" then
				table.insert(NewTable, Value)
			else
				NewTable[Index] = Value
			end
		end
	end

	return NewTable
end

function Util.Equals(Table1: { any }, Table2: { any }, Deep: boolean?)
	if typeof(Table1) ~= "table" or typeof(Table2) ~= "table" then
		warn("One of the arguments is not a table")
		return false
	end

	if #Table1 ~= #Table2 then
		return false
	end

	for Index, Value in pairs(Table1) do
		if typeof(Value) == "table" and Deep then
			if not Util.Equals(Value, Table2[Index], Deep) then
				return false
			end
		elseif Value ~= Table2[Index] then
			return false
		end
	end

	return true
end

return Util
