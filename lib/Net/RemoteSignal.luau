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

    function RemoteSignal:FireAllExcept(Exempt: { Player } | Player, ...)
        self.Event:FireAllExcept(Exempt, ...)
    end

    function RemoteSignal:Connect(Callback: (Player: Player, ...any) -> ())
        return self.Event:Connect(Callback)
    end
else
    function RemoteSignal:Fire(...)
        self.Event:Fire(...)
    end

    function RemoteSignal:Connect(Callback: (...any) -> ())
        return self.Event:Connect(Callback)
    end
end

return RemoteSignal