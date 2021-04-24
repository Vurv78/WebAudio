

local Common = include("autorun/wa_common.lua")
local Modify, isWhitelisted = Common.Modify, Common.isWhitelistedURL

util.AddNetworkString("wa_create")
util.AddNetworkString("wa_change")

_G.WebAudio = {} -- Interface to clientside Bass objects.
WebAudio.__index = WebAudio

local WebAudio = WebAudio

debug.getregistry()["WebAudio"] = WebAudio

-- For now just increment ids, I think it'll be fine this way.
local current_id = 1
local function getID()
    current_id = current_id + 1
    return current_id
end

function WebAudio:AddModify(n)
    self.modified = bit.bor(self.modified, n)
end

function WebAudio:SetVolume(n)
    if isnumber(n) then
        self.volume = n
        self:AddModify(Modify.volume)
    end
end

function WebAudio:SetTime(time)
    if isnumber(time) then
        self.time = time
        self:AddModify(Modify.time)
    end
end

function WebAudio:SetPos(v)
    if isvector(v) then
        self.pos = v
        self:AddModify(Modify.pos)
    end
end

function WebAudio:SetDirection(dir)
    if isvector(dir) then
        self.direction = dir
        self:AddModify(Modify.direction)
    end
end

function WebAudio:Play()
    self:AddModify(Modify.playing)
    self.playing = true
    self:Transmit()
end

function WebAudio:Stop()
    self:AddModify(Modify.playing)
    self.playing = false
    self:Transmit()
end

function WebAudio:SetPlaybackRate(rate)
    if isnumber(rate) then
        self.playback_rate = rate
        self:AddModify(Modify.playback_rate)
    end
end

local hasModifyFlag = Common.hasModifyFlag
function WebAudio:Transmit()
    net.Start("wa_change", true)
        -- Always present values
        net.WriteUInt(self.id, 8)
        local modified = self.modified
        net.WriteUInt(modified, 8)

        if not hasModifyFlag(modified, Modify.destroyed) then
            if hasModifyFlag(modified, Modify.volume) then
                net.WriteFloat(self.volume)
            end

            if hasModifyFlag(modified, Modify.time) then
                net.WriteUInt(self.time, 16)
            end

            if hasModifyFlag(modified, Modify.pos) then
                net.WriteVector(self.pos)
            end

            if hasModifyFlag(modified, Modify.direction) then
                net.WriteVector(self.direction)
            end

            if hasModifyFlag(modified, Modify.playback_rate) then
                net.WriteFloat(self.playback_rate)
            end

            if hasModifyFlag(modified, Modify.playing) then
                net.WriteBool(self.playing)
            end
        end
    net.Broadcast() -- TODO: Don't broadcast to people who have it disabled. Use getinfonum or addChangedCallback to build a table of players to send to. Efficient.
    self.modified = 0 -- Reset any modifications
end

function WebAudio:Destroy()
    self.destroyed = true
    self:AddModify(Modify.destroyed)
    self:Transmit()
    self = nil
end

function WebAudio:IsDestroyed()
    return self.destroyed
end


local function createInterface(_, url, owner)
    assert( url and isstring(url) and isWhitelisted(url), "'url' argument must be given a whitelisted url string." )
    --assert( owner and isentity(owner) and owner:IsPlayer(), "'owner' argument must be a valid player." ) -- For now each interface needs an owner.

    local self = setmetatable({}, WebAudio)

    -- Mutable
    self.volume = 1
    self.time = 0
    self.pos = pos
    self.playing = false
    self.playback_rate = 1
    self.modified = 0
    -- Mutable

    self.id = getID()
    self.url = url
    self.flags = "3d noblock noplay" -- For now, always be 'noblock'
    self.owner = owner

    net.Start("wa_create", true)
        net.WriteUInt(self.id, 8)
        net.WriteString(self.url)
        net.WriteString(self.flags)
        net.WriteEntity(self.owner)
    net.Broadcast()
    return self
end

setmetatable(WebAudio, { __call = createInterface })