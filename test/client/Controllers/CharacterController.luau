local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService

local CharacterController = {}

function CharacterController:OnInit()
	CharacterService = Cardinal.GetService("CharacterService")

	CharacterService.TestProperty:Observe(function(Value)
		print("Test property changed: ", Value)
	end)
end

function CharacterController:OnLocalPlayer(Player)
	print("Player added", Player)
  
	CharacterService.TestSignal:Connect(function(...)
		print("Test signal received: ", ...)
	end)

	print(CharacterService:ThisShouldWork())
end

return CharacterController