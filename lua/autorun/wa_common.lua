
-- SERVER / REPLICATED Convars
local WAAdminOnly = CreateConVar("wa_admin_only", "0", FCVAR_REPLICATED, "Whether creation of WebAudio objects should be limited to admins. 0 for everyone, 1 for admins, 2 for superadmins. wa_enable_sv takes precedence over this", 0, 2)
local WAMaxStreamsPerUser = CreateConVar("wa_stream_max", "5", FCVAR_REPLICATED, "Max number of streams a player can have at once.", 1)

-- SHARED Convars
local WAEnabled = CreateConVar("wa_enable", "1", FCVAR_ARCHIVE + FCVAR_USERINFO, "Whether webaudio should be enabled to play on your client/server or not.", 0, 1)
-- TODO: When we add selective targets maybe allow use of WebAudios at higher configs but only send it to clients that allow this.
local WAMaxVolume = CreateConVar("wa_volume_max", "300", FCVAR_ARCHIVE, "Highest volume a webaudio sound can be played at, in percentage. 200 is 200%. SHARED Convar", 0)
local WAMaxRadius = CreateConVar("wa_radius_max", "10000", FCVAR_ARCHIVE, "Farthest distance a WebAudio stream can be heard from. Will clamp to this value. SHARED Convar", 0)

-- Note that none of these convars affect the Lua Api on the SERVER. On the client they may however if they are aren't FCVAR_REPLICATED


if not WebAudio and not WA_Circular_Include then
    include("autorun/wa_init.lua")
end

local function printf(...) print(string.format(...)) end

local Black = Color(0, 0, 0)
local Color_Warn = Color(243, 71, 41)
local Color_Notify = Color(65, 172, 235)
local White = Color(255, 255, 255)

local function warn(...)
    local msg = string.format(...)
    MsgC(Black, "[", Color_Warn, "WA", Black, "]", White, ": ", msg, "\n")
end

local function notify(...)
    local msg = string.format(...)
    MsgC(Black, "[", Color_Notify, "WA", Black, "]", White, ": ", msg, "\n")
end

-- Modification Enum.
-- If you ever change a setting of the Interface object, will add one of these flags to it.
-- This will be sent to the client to know what to read in the net message to save networking
local Modify = {
    volume = 2^0,
    time = 2^1,
    pos = 2^2,
    playing = 2^3,
    playback_rate = 2^4,
    direction = 2^5,
    parented = 2^6,
    radius = 2^7,

    destroyed = 2^8,
}

local function hasModifyFlag(...) return bit.band(...) ~= 0 end

--- Debug function that's exported as well
local function getFlags(number)
    local out = {}
    for enum_name, enum_val in pairs(Modify) do
        if hasModifyFlag(number, enum_val) then
            table.insert(out, enum_name)
        end
    end
    return out
end

local WhitelistCommon = {}
if not WA_Circular_Include then
    -- Don't include if we've been included from wa_whitelist.lua
    WhitelistCommon = include("autorun/wa_whitelist.lua")
end

return {
    -- Whitelist re-exports
    Whitelist = WhitelistCommon.Whitelist,
    CustomWhitelist = WhitelistCommon.CustomWhitelist,

    -- Lib functions
    printf = printf,
    warn = warn,
    notify = notify,

    -- Enums
    Modify = Modify,
    hasModifyFlag = hasModifyFlag,
    getFlags = getFlags,

    -- Convars
    WAEnabled = WAEnabled,
    WAAdminOnly = WAAdminOnly,

    WAMaxVolume = WAMaxVolume,
    WAMaxStreamsPerUser = WAMaxStreamsPerUser,
    WAMaxRadius = WAMaxRadius
}