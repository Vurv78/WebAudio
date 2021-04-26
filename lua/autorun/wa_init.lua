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


WebAudioStatic.instanceOf = isWebAudio
WebAudioStatic.isWebAudio = isWebAudio

setmetatable(WebAudio, {
    __index = WebAudioStatic
})