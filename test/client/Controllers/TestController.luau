local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService

local Controller = {}

function Controller:OnInit()
    CharacterService = Cardinal.GetService("CharacterService")
end

function Controller:OnLocalCharacter(Character)
    print("Character added", Character)

    CharacterService.TestSignal:Once(function()
        print("Test signal received")
    end)
end

return Controller