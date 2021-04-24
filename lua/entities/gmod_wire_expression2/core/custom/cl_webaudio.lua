

local tbl = E2Helper.Descriptions
local function desc(name, description)
    tbl[name] = description
end

desc("createWebAudio(s)", "Creates a webaudio object")