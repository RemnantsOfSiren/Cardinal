local RunService = game:GetService("RunService")

local RemoteSignal = {}
RemoteSignal.__index = RemoteSignal

function RemoteSignal.new(Net: { CreateEvent: (self: unknown, string) -> unknown }, Name: string)
    local self = setmetatable({}, RemoteSignal)

    self.Event = Net:CreateEvent(Name)
    
    return self
end

if RunService:IsServer() then
    function RemoteSignal:Fire(Player: Player, ...: any)
        self.Event:Fire(Player, ...)
    end

    function RemoteSignal:FireAll(...)
        self.Event:FireAll(...)
    end
else
    function RemoteSignal:Connect(Callback: () -> ())
        return self.Event:Connect(Callback)
    end
end

return RemoteSignal