local WriteLib = {
	Give = function(Replica, Item: string, ItemData: { [string]: any })
		Replica:Set(Item, ItemData)
	end,
	Take = function(Replica, Item: string)
		Replica:Set(Item, nil)
	end,
}

return WriteLib
