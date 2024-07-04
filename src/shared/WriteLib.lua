local WriteLib = {
    Give = function(Replica, Item: string, ItemData: {[string]: any} )
        print(Replica, Item, ItemData)
        Replica:Set(Item, ItemData)
    end
}

return WriteLib