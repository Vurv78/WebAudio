

local Common = include("autorun/wa_common.lua")
local warn, notify, whitelisted = Common.warn, Common.notify, Common.isWhitelistedURL
local Enabled = Common.WAEnabled

local Audios, AwaitingChanges, WAudio = {}, {}, {}
WAudio.__index = WAudio
local updateObject -- To be declared below

local function createObject(_, id, url, owner, bass)
    local self = setmetatable({}, WAudio)
    -- Mutable
    self.volume = 1
    self.time = 0
    self.pos = nil -- Start as nil for parenting to work.
    self.playing = false
    self.playback_rate = 1
    self.modified = 0
    self.destroyed = false
    self.direction = Vector()
    -- Mutable

    self.id = id
    self.url = url
    self.owner = owner

    -- Receiver Only
    self.bass = bass
    self.parent_pos = Vector()
    -- Receiver Only

    return self
end

setmetatable(WAudio, { __call = createObject })

net.Receive("wa_create", function(len)
    local id, url, flags, owner = net.ReadUInt(8), net.ReadString(), net.ReadString(), net.ReadEntity()

    if not Enabled:GetBool() then
        notify("%s(%d) attempted to create a WebAudio object with url [\"%s\"], but you have WebAudio disabled!", owner:Nick(), owner:SteamID64(), url)
        return
    end

    if whitelisted(url) then
        notify("User %s(%d) created WebAudio object with url [\"%s\"]", owner:Nick(), owner:SteamID64(), url)
        sound.PlayURL(url, flags, function(bass, errid, errname)
            if not errid then
                Audios[id].bass = bass

                local changes_awaiting = AwaitingChanges[id]
                if changes_awaiting then
                    updateObject(id, changes_awaiting, true, false)
                    AwaitingChanges[id] = nil
                end
            end
        end)
        Audios[id] = WAudio(id, url, owner)
    else
        warn("User %s(%d) tried to create unwhitelisted WebAudio object with url [\"%s\"]", owner, owner:SteamID64(), url)
    end
end)

local Modify = Common.Modify
local hasModifyFlag = Common.hasModifyFlag

--- Stores changes on the Receiver object
-- @param number id ID of the Receiver Object, to be used to search the table of 'Audios'
-- @param number modify_enum Mixed bitwise enum that will be sent by the server to determine what changed in an object to avoid wasting a lot of bits for every piece of information.
-- @param boolean handle_bass Whether this object has a 'bass' object. If so, we can just immediately apply the changes to the object.
-- @param boolean inside_net Whether this function is inside the net message that contains the new information. If not, we're most likely just applying object changes to the receiver after waiting for the IGmodAudioChannel object to be created.
function updateObject(id, modify_enum, handle_bass, inside_net)
    -- Object destroyed
    local self = Audios[id]
    local bass = self.bass

    if hasModifyFlag(modify_enum, Modify.destroyed) then
        self.destroyed = true
        if handle_bass then
            timer.Remove("wa_parent_" .. self.id) -- Parent timer
            bass:Stop()
            Audios[ self.id ] = nil
            self = nil
        end
        return
    end

    -- Volume changed
    if hasModifyFlag(modify_enum, Modify.volume) then
        if inside_net then self.volume = net.ReadFloat() end
        if handle_bass then bass:SetVolume(self.volume) end
    end

    -- Time changed
    if hasModifyFlag(modify_enum, Modify.time) then
        if inside_net then self.time = net.ReadUInt(16) end
        if handle_bass then
            bass:SetTime(self.time) -- 18 hours max, if you need more, wtf..
        end
    end

    -- 3D Position changed
    if hasModifyFlag(modify_enum, Modify.pos) then
        if inside_net then self.pos = net.ReadVector() end
        if handle_bass then
            bass:SetPos(self.pos)
        end
    end

    -- Playback rate changed
    if hasModifyFlag(modify_enum, Modify.playback_rate) then
        if inside_net then self.playback_rate = net.ReadFloat() end
        if handle_bass then
            bass:SetPlaybackRate(self.playback_rate)
        end
    end

    -- Direction changed.
    if hasModifyFlag(modify_enum, Modify.direction) then
        if inside_net then self.direction = net.ReadVector() end
        -- Should always be true so..
        if handle_bass then
            bass:SetPos(self.pos, self.direction)
        end
    end

    -- Playing / Paused state changed
    if hasModifyFlag(modify_enum, Modify.playing) then
        if inside_net then self.playing = net.ReadBool() end
        -- Should always be true so..
        if handle_bass then
            if self.playing then
                -- If changed to be playing, play. Else stop
                bass:Play()
            else
                bass:Pause()
            end
        end
    end

    if hasModifyFlag(modify_enum, Modify.parented) then
        if inside_net then
            self.parented = net.ReadBool()
            if self.parented then
                local ent = net.ReadEntity()
                self.parent = ent
                if self.pos ~= nil then
                    -- We've initialized and received a changed position before
                    self.parent_pos = ent:WorldToLocal(self.pos)
                else
                    -- self.pos hasn't been touched, play the sound at the entity's position.
                    self.parent_pos = Vector()
                end
            else
                timer.Remove("wa_parent_" .. self.id)
                self.parent = nil
            end
        end

        if handle_bass and self.parented then
            local parent = self.parent
            if parent and parent ~= NULL then
                bass:SetPos( self.parent:LocalToWorld(self.parent_pos) )
            end
            timer.Create("wa_parent_" .. self.id, 0.1, 0, function()
                if parent ~= NULL then
                    bass:SetPos( parent:LocalToWorld(self.parent_pos) )
                elseif self.id then
                    -- If the prop was removed but the stream hasn't been destroyed, remove the timer here.
                    timer.Remove("wa_parent_" .. self.id)
                end
            end)
        end
    end
end

net.Receive("wa_change", function(len)
    local id, modify_enum = net.ReadUInt(8), net.ReadUInt(8)
    local obj = Audios[id]

    if AwaitingChanges[id] then return end
    if not obj then return end -- Hm..

    if obj.bass then
        -- Store and handle changes
        updateObject(id, modify_enum, true, true)
    else
        -- We don't have the bass object yet. Store the changes to update the object with later.
        AwaitingChanges[id] = modify_enum
        updateObject(id, modify_enum, false, true)
    end
end)