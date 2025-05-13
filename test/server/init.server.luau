local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

local Event = Instance.new("BindableEvent")
Cardinal.AddCustomLifecycle("TestEvent", Event.Event)

task.spawn(function()
	while true do
		Event:Fire("Hello from the server!")
		task.wait(1)
	end
end)

Cardinal.Load(script.Services)

Cardinal.Start():andThen(function()
	print("Server started")
end)
