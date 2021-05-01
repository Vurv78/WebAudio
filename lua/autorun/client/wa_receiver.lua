

local Common = include("autorun/wa_common.lua")
local warn, notify = Common.warn, Common.notify

local math_min = math.min

-- Convars
local Enabled = Common.WAEnabled
local MaxVolume, MaxRadius = Common.WAMaxVolume, Common.WAMaxRadius

local WebAudios, WebAudioCounter = {}, 0
local AwaitingChanges = {}

local updateObject -- To be declared below

local WebAudio = WebAudio

timer.Create("wa_think", 200/1000, 0, function()
    local player_pos = LocalPlayer():GetPos()
    for id, stream in pairs(WebAudios) do
        local bass = stream.bass
        if bass then
            -- Handle Parenting
            local parent = stream.parent
            if parent and parent ~= NULL then
                local pos = parent:LocalToWorld(stream.parent_pos)
                bass:SetPos( pos )
                stream.pos = pos
            end

            -- Manually handle volume as you go farther from the stream.
            local dist_to_stream = player_pos:Distance( stream.pos )
            bass:SetVolume( stream.volume * ( 1 - math_min(dist_to_stream/stream.radius, 1) ) )
        end
    end
end)

--- Creates a WebAudio receiver and returns it.
-- @param number id ID of the serverside WebAudio object to receive from.
-- @param string url URL to play from the stream
-- @param Entity owner Owner of the stream for tracking purposes & future blocking/purging.
local function registerStream(id, url, owner)
    WebAudios[id] = WebAudio(id, url, owner)
    WebAudioCounter = WebAudioCounter + 1
end

net.Receive("wa_create", function(len)
    local id, url, owner = WebAudio:readID(), net.ReadString(), net.ReadEntity()

    if not Enabled:GetBool() then
        -- Shouldn't happen anymore
        notify("%s(%d) attempted to create a WebAudio object with url [\"%s\"], but you have WebAudio disabled!", owner:Nick(), owner:SteamID64(), url)
        return
    end

    if WebAudio:isWhitelistedURL(url) then
        notify("User %s(%d) created WebAudio object with url [\"%s\"]", owner:Nick(), owner:SteamID64(), url)
        sound.PlayURL(url, "3d noblock noplay", function(bass, errid, errname)
            if not errid then
                WebAudios[id].bass = bass

                local changes_awaiting = AwaitingChanges[id]
                if changes_awaiting then
                    updateObject(id, changes_awaiting, true, false)
                    AwaitingChanges[id] = nil
                end
            else
                warn("Error when creating WebAudio receiver with id %d, Error [%s]", id, errname)
            end
        end)
        registerStream(id, url, owner)
    else
        warn("User %s(%d) tried to create unwhitelisted WebAudio object with url [\"%s\"]", owner, owner:SteamID64(), url)
    end
end)

local Modify = Common.Modify
local hasModifyFlag = Common.hasModifyFlag

--- Stores changes on the Receiver object
-- @param number id ID of the Receiver Object, to be used to search the table of 'WebAudios'
-- @param number modify_enum Mixed bitwise enum that will be sent by the server to determine what changed in an object to avoid wasting a lot of bits for every piece of information.
-- @param boolean handle_bass Whether this object has a 'bass' object. If so, we can just immediately apply the changes to the object.
-- @param boolean inside_net Whether this function is inside the net message that contains the new information. If not, we're most likely just applying object changes to the receiver after waiting for the IGmodAudioChannel object to be created.
function updateObject(id, modify_enum, handle_bass, inside_net)
    -- Object destroyed
    local self = WebAudios[id]
    local bass = self.bass

    -- Keep in mind that the order of these needs to sync with wa_interface's reading order.
    if hasModifyFlag(modify_enum, Modify.destroyed) then
        self.destroyed = true
        if handle_bass then
            bass:Stop()
            WebAudios[ self.id ] = nil
            self = nil
        end
        return
    end

    -- Volume changed
    if hasModifyFlag(modify_enum, Modify.volume) then
        if inside_net then self.volume = math_min(net.ReadFloat(), MaxVolume:GetInt()/100) end
        if handle_bass then bass:SetVolume(self.volume) end
    end

    -- Playback time changed
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

    -- Direction changed.
    if hasModifyFlag(modify_enum, Modify.direction) then
        if inside_net then self.direction = net.ReadVector() end
        if handle_bass then
            bass:SetPos(self.pos, self.direction)
        end
    end

    -- Playback rate changed
    if hasModifyFlag(modify_enum, Modify.playback_rate) then
        if inside_net then self.playback_rate = net.ReadFloat() end
        if handle_bass then
            bass:SetPlaybackRate(self.playback_rate)
        end
    end

    -- Radius changed
    if hasModifyFlag(modify_enum, Modify.radius) then
        if inside_net then self.radius = math_min(net.ReadUInt(16), MaxRadius:GetInt()) end
        if handle_bass then
            local dist_to_stream = LocalPlayer():GetPos():Distance( self.pos )
            bass:SetVolume( self.volume * ( 1 - math_min(dist_to_stream/self.radius, 1) ) )
        end
    end

    -- Was parented or unparented
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
                self.parent = nil
            end
        end

        if handle_bass and self.parented then
            local parent = self.parent
            if parent and parent ~= NULL then
                bass:SetPos( self.parent:LocalToWorld(self.parent_pos) )
            end
        end
    end

    -- Playing / Paused state changed. Should always be at the bottom here
    if hasModifyFlag(modify_enum, Modify.playing) then
        if inside_net then self.playing = net.ReadBool() end
        -- Should always be true so..
        if handle_bass then
            if self.playing then
                -- If changed to be playing, play. Else pause
                bass:Play()
            else
                bass:Pause()
            end
        end
    end
end

net.Receive("wa_change", function(len)
    local id, modify_enum = WebAudio:readID(), WebAudio:readModify()
    local obj = WebAudios[id]

    if AwaitingChanges[id] then return end
    if not obj then return end -- Object was destroyed on the client for whatever reason. Most likely reason is wa_purge

    if obj.bass then
        -- Store and handle changes
        updateObject(id, modify_enum, true, true)
    else
        -- We don't have the bass object yet. Store the changes to update the object with later.
        AwaitingChanges[id] = modify_enum
        updateObject(id, modify_enum, false, true)
    end
end)

--- Destroys a stream and stops the underlying IGmodAudioChannel
-- @param number id ID of the stream to destroy
local function destroyStream(id)
    local stream = WebAudios[id]
    if stream then
        local bass = stream.bass
        if bass and bass:IsValid() then
            bass:Stop()
        end
        WebAudios[id] = nil
    end
end

--- Stops every currently existing stream
-- @param boolean write_ids Whether to net write IDs or not while looping through the streams. Used for wa_ignore.
local function stopStreams(write_ids)
    for id, stream in pairs(WebAudios) do
        if stream then
            destroyStream(id)
            if write_ids then
                -- If we are in wa_purge
                WebAudio:writeID(id)
            end
            WebAudios[id] = nil
        end
    end
end

concommand.Add("wa_purge", function()
    if WebAudioCounter == 0 then return end
    net.Start("wa_ignore", true)
        net.WriteUInt(WebAudioCounter, 8)
        stopStreams(true)
    net.SendToServer()
end, nil, "Purges all of the currently playing WebAudio streams")

--- When the client toggles wa_enable send this info to the server to stop sending net messages to them.
cvars.AddChangeCallback("wa_enable", function(convar, old, new)
    local enabled = new ~= "0"
    if not enabled then
        stopStreams(false)
    end
    net.Start("wa_enable", true)
        net.WriteBool(enabled) -- Tell the server we're
    net.SendToServer()
end)

local function createObject(_, id, url, owner, bass)
    local self = setmetatable({}, WebAudio)
    -- Mutable
    self.playing = false
    self.destroyed = false

    self.parented = false
    self.parent = nil -- Entity

    self.modified = 0

    self.playback_rate = 1
    self.volume = 1
    self.time = 0
    self.radius = math_min(200, MaxRadius:GetInt()) -- 200 by default or client's max radius if it's lower

    self.pos = Vector()
    self.direction = Vector()
    -- Mutable

    self.id = id
    self.url = url
    self.owner = owner

    -- Receiver Only
    self.bass = bass
    self.parent_pos = Vector() -- Local position to parent when it was initially parented.
    -- Receiver Only

    return self
end

local WA_STATIC_META = getmetatable(WebAudio)
WA_STATIC_META.__call = createObject

--- Returns the list of all WebAudio receivers.
-- @return table WebAudios
function WA_STATIC_META:getList()
    return WebAudios
end

--- Returns a WebAudio receiver struct from an id if there is one with that id.
-- @return WebAudio Struct
function WA_STATIC_META:getFromID(id)
    return WebAudios[id]
end