local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal) :: { any }

local CharacterService = {
    Client = {
        CurrentlyEquippped = Cardinal.CreateProperty("Nothing"),
    };
}

function CharacterService:OnPlayerAdded(Player)
    local Replica = Cardinal.Replicator.NewReplica({
        Name = "Items",
        Data = {
            Sword = {
                Name = "Sword",
                Damage = 10,
            },
            Shield = {
                Name = "Shield",
                Defense = 5,
            },
        },
        To = Player,
    })

    task.delay(5, function() 
        Replica:Set("Sword", {
            Name = "Sword",
            Damage = 15,
        })
    end)
end

function CharacterService.Client:EquipItem(player, item)
    --self.ItemEquipped:Fire(player, item)
    self.CurrentlyEquippped:SetFor(player, item)
end

return CharacterService