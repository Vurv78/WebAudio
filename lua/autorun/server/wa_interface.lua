

local Common = include("autorun/wa_common.lua")
local Modify = Common.Modify

util.AddNetworkString("wa_create")
util.AddNetworkString("wa_change")

-- Created in wa_common
local WebAudio = WebAudio

-- For now just increment ids, I think it'll be fine this way.
local current_id = 1
local function getID()
    current_id = current_id + 1
    return current_id
end

--- Adds a modify flag to the payload to be sent on transmission
-- @param number n Modify flag from the Modify struct in wa_common
-- @return boolean Whether it modified. Will return nil if stream is destroyed.
function WebAudio:AddModify(n)
    if self:IsDestroyed() then return end
    self.modified = bit.bor(self.modified, n)
end

--- Sets the volume of the stream
-- Does not transmit
-- @param number n Volume (1 is 100%, 2 is 200% ..)
-- @return boolean Whether volume was set. Will return nil if stream is destroyed or n is not number
function WebAudio:SetVolume(n)
    if self:IsDestroyed() then return end
    if isnumber(n) then
        self.volume = n
        self:AddModify(Modify.volume)
    end
end

--- Sets the current playback time of the stream.
-- Does not transmit
-- @param number time Playback time
-- @return boolean Whether playback time was successfully set. Will return nil if stream is destroyed or time is not number
function WebAudio:SetTime(time)
    if self:IsDestroyed() then return end
    if isnumber(time) then
        self.time = time
        self:AddModify(Modify.time)
    end
end

--- Sets the position of the stream.
-- @param Vector v Position
-- @return boolean Whether the position was set. Will return nil if stream is destroyed, v is not vector, or if the stream is parented.
function WebAudio:SetPos(v)
    if self:IsDestroyed() then return end
    if self:IsParented() then return end
    if isvector(v) then
        self.pos = v
        self:AddModify(Modify.pos)
    end
end

--- Sets the direction in which the stream will play
-- @param Vector dir Direction to set to
-- @return boolean Whether the direction was successfully set. Will return nil if stream is destroyed or dir is not vector.
function WebAudio:SetDirection(dir)
    if self:IsDestroyed() then return end
    if isvector(dir) then
        self.direction = dir
        self:AddModify(Modify.direction)
        return true
    end
end

--- Resumes or starts the stream.
-- @return boolean Successfully played, will return nil if the stream is destroyed
function WebAudio:Play()
    if self:IsDestroyed() then return end
    self:AddModify(Modify.playing)
    self.playing = true
    self:Transmit()
    return true
end

--- Pauses the stream and automatically transmits.
-- @return boolean Successfully paused, will return nil if the stream is destroyed
function WebAudio:Pause()
    if self:IsDestroyed() then return end
    self:AddModify(Modify.playing)
    self.playing = false
    self:Transmit()
    return true
end

--- Sets the playback rate of the stream.
-- @return boolean Successfully set rate, will return false if rate is not a number or if the stream is destroyed
function WebAudio:SetPlaybackRate(rate)
    if self:IsDestroyed() then return end
    if isnumber(rate) then
        self.playback_rate = rate
        self:AddModify(Modify.playback_rate)
        return true
    end
end

--- Destroys the WebAudio object.
-- @return boolean Whether it was successfully destroyed. Returns false if it was already destroyed.
function WebAudio:Destroy()
    if self:IsDestroyed() then return end
    self:AddModify(Modify.destroyed)
    self:Transmit()

    for k in next,self do
        self[k] = nil
    end
    self.destroyed = true
    return true
end

--- Returns whether the WebAudio object is Null
-- @return boolean Whether it's destroyed/null
function WebAudio:IsDestroyed()
    return self.destroyed
end

--- Returns whether the WebAudio object is valid and not destroyed.
function WebAudio:IsValid()
    return not self.destroyed
end

--- Returns whether the stream is parented or not. If it is parented, you won't be able to set it's position.
-- @return boolean Whether it's parented
function WebAudio:IsParented()
    return self.parented
end

--- Sets the parent of the WebAudio object. Nil to unparent
-- @param entity? parent Entity to parent to or nil to unparent.
-- @return boolean Whether it was successfully destroyed. Returns false if it was already destroyed.
function WebAudio:SetParent(ent)
    if self:IsDestroyed() then return end
    if isentity(ent) and ent:IsValid() then
        self.parented = true
        self.parent = ent
    else
        self.parented = false
        self.parent = nil
    end
    self:AddModify(Modify.parented)
    return true
end

local hasModifyFlag = Common.hasModifyFlag
--- Transmits all stored data on the server about the WebAudio object to the clients
-- @return boolean If successfully transmitted.
function WebAudio:Transmit()
    if self:IsDestroyed() then return end
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

            if hasModifyFlag(modified, Modify.parented) then
                net.WriteBool(self.parented)
                if self.parented then
                    net.WriteEntity(self.parent)
                end
            end
        end
    net.Broadcast() -- TODO: Don't broadcast to people who have it disabled. Use getinfonum or addChangedCallback to build a table of players to send to. Efficient.
    self.modified = 0 -- Reset any modifications
    return true
end


local function createInterface(_, url, owner)
    assert( WebAudio:isWhitelistedURL(url), "'url' argument must be given a whitelisted url string." )
    -- assert( owner and isentity(owner) and owner:IsPlayer(), "'owner' argument must be a valid player." )
    -- Commenting this out in case someone wants a webaudio object to be owned by the world or something.

    local self = setmetatable({}, WebAudio)

    -- Mutable
    self.volume = 1
    self.time = 0
    self.pos = Vector()
    self.playing = false
    self.playback_rate = 1
    self.modified = 0
    self.destroyed = false
    self.direction = Vector()

    self.parented = false
    self.parent = nil
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

local WA_STATIC_META = getmetatable(WebAudio)
WA_STATIC_META.__call = createInterface