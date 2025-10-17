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

	CharacterService:ThisShouldWork():andThen(function(Result)
		if Result.Success then
			print("This should work: ", Result.Message)
		else
			print("This should not work: ", Result.Message)
		end
	end)
end

return CharacterController