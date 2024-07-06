local WriteLib = {
    Give = function(Replica, Item: string, ItemData: {[string]: any} )
        Replica:Set(Item, ItemData)
    end
}

return WriteLib