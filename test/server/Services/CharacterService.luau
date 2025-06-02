local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local CharacterService = {
	Client = {
		TestSignal = Cardinal.CreateSignal(),
		TestProperty = Cardinal.CreateProperty(false),
	},
}

local BindableEvent = Instance.new("BindableEvent")

function CharacterService:OnStart()
	Cardinal.AddCustomLifecycle("TestEvent", BindableEvent.Event)

	task.spawn(function() 
		while true do
			BindableEvent:Fire("TestEvent", "Hello", "World")
			task.wait(1)
		end
	end)
end

function CharacterService:OnTestEvent(...)
	print(...)
end

function CharacterService:OnPlayerAdded(Player)
	self.Client.TestProperty:SetFor(Player, true)
end

function CharacterService:OnCharacterAdded(_, Player)
	task.delay(0, self.Client.TestSignal.Fire, self.Client.TestSignal, Player)
	task.spawn(function()
		while true do
			self.Client.TestSignal:Fire(Player, "1", "2", "3")
			task.wait()
		end
	end)
end

function CharacterService.Client:ThisShouldWork(Player)
	print("This should work for", Player.Name)
	return {
		Success = true,
		Message = "This worked!",
	}
end

return CharacterService
