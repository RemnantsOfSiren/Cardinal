local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal) :: { any }

local CharacterService = {
    Client = {
        CurrentlyEquippped = Cardinal.CreateProperty("Nothing"),
    };
}

function CharacterService:OnPlayerAdded(Player)
    task.delay(5, function() Player:LoadCharacter() end)
end

function CharacterService.Client:EquipItem(player, item)
    self.CurrentlyEquippped:SetFor(player, item)
end

return CharacterService