local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cardinal = require(ReplicatedStorage.Packages.Cardinal)

Cardinal.Load(script.Services)

Cardinal.Start():andThen(function()
    print("Server started")
end)