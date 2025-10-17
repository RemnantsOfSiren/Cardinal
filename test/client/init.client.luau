local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

Cardinal.Load(script.Controllers)

Cardinal.Start({ ServicePromise = true }):andThen(function()
	print("Client started")
end)
