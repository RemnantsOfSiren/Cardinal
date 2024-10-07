local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService

local CharacterController = {}

function CharacterController:OnInit()
	CharacterService = Cardinal.GetService("CharacterService")
end

function CharacterController:OnLocalPLayer(Character)
	print("Character added", Character)
  
	CharacterService.TestSignal:Connect(function()
		print("Test signal received")
	end)
end

return CharacterController