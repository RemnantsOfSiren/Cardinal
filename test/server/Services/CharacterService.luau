local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = {
	Client = {
		TestSignal = Cardinal.CreateSignal(),
	},
}

function CharacterService:OnStart()
	task.wait(11)
end

function CharacterService:OnPlayerAdded(Player)
	-- task.delay(10, function()
	-- 	Player:LoadCharacter()
	-- end)
end

function CharacterService:OnCharacterAdded(_, Player)
	print("Character added", Player)
	task.delay(0, self.Client.TestSignal.Fire, self.Client.TestSignal, Player)
end

return CharacterService
