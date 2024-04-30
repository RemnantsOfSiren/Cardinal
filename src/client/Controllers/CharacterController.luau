local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = Cardinal.GetService("CharacterService")

local CharacterController = {}

function CharacterController:OnInit()
    Cardinal.Replicator.ListenToNewReplica("Items", function(Replica) 
        print(Replica.Data)
        Replica.Changed:Connect(print)
    end)
end

function CharacterController:OnStart()
    CharacterService:EquipItem("Sword")
end

return CharacterController