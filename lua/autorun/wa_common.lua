
local WAEnabled = CreateConVar("wa_enable", "1", FCVAR_USERINFO, "Whether webaudio should be enabled or not.", 0, 1)
local WAMaxVolume = CreateConVar("wa_volume_max", "200", FCVAR_REPLICATED, "Highest volume a webaudio sound can be played at, in percentage. 200 is 200%", 0)
local WAMaxStreamsPerUser = CreateConVar("wa_max_streams", "5", FCVAR_REPLICATED, "Max number of streams a player can have at once.", 1)

local function printf(...) print(string.format(...)) end

local function isWebAudio(v)
    if not istable(v) then return end
    return debug.getmetatable(v) == debug.getregistry().WebAudio
end

-- Modification Enum.
-- If you ever change a setting of the Interface object, will add one of these flags to it, to be sent to the client to know
-- What to read.
local Modify = {
    volume = 1,
    time = 2,
    pos = 4,
    playing = 8,
    playback_rate = 16,
    direction = 32,

    destroyed = 64,
}

local function hasModifyFlag(...) return bit.band(...) ~= 0 end

local WhitelistCommon = include("autorun/wa_whitelist.lua")
return {
    isWhitelistedURL = WhitelistCommon.isWhitelistedURL,
    Whitelist = WhitelistCommon.Whitelist,
    printf = printf,
    Modify = Modify,
    isWebAudio = isWebAudio,
    hasModifyFlag = hasModifyFlag,

    WAEnabled = WAEnabled,
    WAMaxVolume = WAMaxVolume,
    WAMaxStreamsPerUser = WAMaxStreamsPerUser
}