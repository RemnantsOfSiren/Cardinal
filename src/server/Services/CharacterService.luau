local CharacterService = {}

function CharacterService:OnPlayerAdded(Player)
    task.delay(5, function() 
        Player:LoadCharacter() 
    end)
end

function CharacterService:OnCharacterAdded(Character)
    print("Character added to game")
end

return CharacterService