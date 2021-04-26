
-- Convars below only effect WebAudios in expression2 chips since those are the only ones that are automatically gc'ed and managed by this addon.
local WAEnabled = CreateConVar("wa_enable", "1", FCVAR_ARCHIVE, "Whether webaudio should be enabled to play on your client/server or not.", 0, 1) -- Both realms
local WAAdminOnly = CreateConVar("wa_admin_only", "0", FCVAR_REPLICATED, "Whether creation of WebAudio objects should be limited to admins. 0 for everyone, 1 for admins, 2 for superadmins. wa_enable_sv takes precedence over this", 0, 2)

-- TODO: Make volume possible to be configured by each client and not error the chip for sending at that volume. Would be annoying so ignoring for now.
local WAMaxVolume = CreateConVar("wa_volume_max", "200", FCVAR_REPLICATED, "Highest volume a webaudio sound can be played at, in percentage. 200 is 200%", 0)
local WAMaxStreamsPerUser = CreateConVar("wa_stream_max", "5", FCVAR_REPLICATED, "Max number of streams a player can have at once.", 1)

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
    volume = 1,
    time = 2,
    pos = 4,
    playing = 8,
    playback_rate = 16,
    direction = 32,
    parented = 64,

    destroyed = 128,
}

local function hasModifyFlag(...) return bit.band(...) ~= 0 end

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

    -- Convars
    WAEnabled = WAEnabled,
    WAAdminOnly = WAAdminOnly,
    WAMaxVolume = WAMaxVolume,
    WAMaxStreamsPerUser = WAMaxStreamsPerUser
}