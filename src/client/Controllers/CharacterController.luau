local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = Cardinal.GetService("CharacterService")

local CharacterController = {}

function CharacterController:OnInit()
    -- CharacterService.ItemEquipped:Connect(function(Item)
    --     print(Item)
    -- end)

    CharacterService.CurrentlyEquippped:Observe(print)

    Cardinal.Replicator.ListenToNewReplica("Items", function(Replica) 
        Replica:ListenToChange("Items", print)
        Replica:ListenToWrite("Give", function(...)
            print(...)
        end)
    end)

end

function CharacterController:OnStart()
    CharacterService:EquipItem("Sword")
end

return CharacterController