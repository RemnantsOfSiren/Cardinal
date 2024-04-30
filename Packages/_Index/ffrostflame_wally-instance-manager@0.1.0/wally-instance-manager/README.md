# Wally Instance Manager

---

### Why does this exist?
This project exists to allow for Wally projects to easily add instances under ReplicatedStorage without causing version issues or dependency issues.

### Usage
```lua
local wallyInstanceManager = require(...)

local myProjectsRemoteEvent = Instance.new("RemoteEvent")

-- The first argument to the `add` function MUST be the project folder.
wallyInstanceManager.add(script.Parent, myProjectsRemoteEvent)

wallyInstanceManager.get(script.Parent, "RemoteEvent")

wallyInstanceManager.waitForInstance(script.Parent, "RemoteEvent", 3)
```