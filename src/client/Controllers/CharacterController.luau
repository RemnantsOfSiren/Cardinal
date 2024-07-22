local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = Cardinal.GetService("CharacterService")

local CharacterController = {}

-- function CharacterController:OnInit()
--     -- CharacterService.ItemEquipped:Connect(function(Item)
--     --     print(Item)
--     -- end)

--     CharacterService.CurrentlyEquippped:Observe(print)

--     Cardinal.Replicator.ListenToNewReplica("Items", function(Replica) 
-- 		Replica:ListenToWrite("Give", print)
-- 		Replica:ListenToWrite("Take", print)
--     end)

-- end

-- function CharacterController:OnStart()
--     CharacterService:EquipItem("Sword")
-- end

function CharacterController:OnLocalCharacter(Character)
  print("Character added", Character)
end

return CharacterController