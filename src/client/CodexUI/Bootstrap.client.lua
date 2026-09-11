-- Additive client startup; does not start Claude's server framework.
local Controller=require(script.Parent:WaitForChild("Controller"))
Controller.start()
