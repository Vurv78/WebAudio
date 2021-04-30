--- Initiate WebAudio struct for both realms

if WebAudio then return end -- Already initiated

_G.WebAudio = {}
WebAudio.__index = WebAudio

debug.getregistry()["WebAudio"] = WebAudio

local function isWebAudio(v)
    if not istable(v) then return end
    return debug.getmetatable(v) == WebAudio
end

-- Static Methods
local WebAudioStatic = {}
-- For consistencies' sake, Static functions will be lowerCamelCase, while object / meta methods will be CamelCase.

--- Returns an unusable WebAudio object that just has the destroyed field set to true.
-- @return webaudio The null stream
function WebAudioStatic:getNULL()
    return setmetatable({ destroyed = true }, WebAudio)
end

-- We have these functions so that maybe we can change the number of bits if we make a convar for the global number of WebAudios. Just a thought.

--- Same as net.ReadUInt but doesn't need the bit length in order to adapt our code more easily.
-- @return number UInt8
function WebAudioStatic:readID()
    return net.ReadUInt(9)
end

--- Same as net.WriteUInt but doesn't need the bit length in order to adapt our code more easily.
-- @param number id ID to write in the net message
function WebAudioStatic:writeID(id)
    net.WriteUInt(id, 9)
end

--- Reads a WebAudio Modify enum
-- @return number UInt16
function WebAudioStatic:readModify()
    return net.ReadUInt(16)
end

--- Writes a WebAudio Modify enum
-- @param number UInt16
function WebAudioStatic:writeModify(modify)
    net.WriteUInt(modify, 16)
end


WebAudioStatic.instanceOf = isWebAudio
WebAudioStatic.isWebAudio = isWebAudio

setmetatable(WebAudio, {
    __index = WebAudioStatic
})