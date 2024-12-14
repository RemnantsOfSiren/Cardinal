local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = {
	Client = {
		TestSignal = Cardinal.CreateSignal(),
		TestProperty = Cardinal.CreateProperty(false),
	},
}

function CharacterService:OnPlayerAdded(Player)
	self.Client.TestProperty:SetFor(Player, true)
end

function CharacterService:OnCharacterAdded(_, Player)
	task.delay(0, self.Client.TestSignal.Fire, self.Client.TestSignal, Player)
end

return CharacterService
