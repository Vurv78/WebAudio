

local Audios = {}
local AwaitingChanges = {}

local WAudio = {}
WAudio.__index = WAudio

local storeChanges, handleChanges

local function createObject(_, id, url, owner, bass)
    local self = setmetatable({}, WAudio)
    self.id = id
    self.url = url
    self.owner = owner
    self.bass = bass

    -- Default values if WebAudio:Play()'d without any prior info set into the object
    self.pos = Vector()
    self.time = 0
    self.destroyed = false 
    self.playback_rate = 1
    self.volume = 1
    self.playing = false

    return self
end

setmetatable(WAudio, { __call = createObject })

local Common = include("autorun/wa_common.lua")
local printf, whitelisted = Common.printf, Common.isWhitelistedURL

net.Receive("wa_create", function(len)
    local id, url, flags, owner = net.ReadUInt(8), net.ReadString(), net.ReadString(), net.ReadEntity()
    if whitelisted(url) then
        printf(">> User %s(%d) created WebAudio object with url [\"%s\"]", owner:Nick(), owner:SteamID64(), url)
        sound.PlayURL(url, flags, function(bass, errid, errname)
            if errid ~= 0 then
                print("Loaded!", id, url)
                Audios[id].bass = bass

                local changes_awaiting = AwaitingChanges[id]
                if changes_awaiting then
                    handleChanges(id, changes_awaiting)
                end
            end
            print(errid, errname)
        end)
        Audios[id] = WAudio(id, url, owner)
    else
        printf(">> User %s(%d) tried to create unwhitelisted WebAudio object with url [\"%s\"]", owner, owner:SteamID64(), url)
    end
end)

local Modify = Common.Modify
local hasModifyFlag = Common.hasModifyFlag
function storeChanges(id, modify_enum, handle_bass)
    -- Object destroyed
    local self = Audios[id]
    local bass = self.bass

    if hasModifyFlag(modify_enum, Modify.destroyed) then
        self.destroyed = true

        print("Destroyed audio object!")
        if handle_bass then
            bass:Stop()
            Audios[ self.id ] = nil
            self = nil

        end
        return
    end

    -- Volume changed
    if hasModifyFlag(modify_enum, Modify.volume) then
        self.volume = net.ReadFloat()
        if handle_bass then
            bass:SetVolume(self.volume)
        end
    end

    -- Time changed
    if hasModifyFlag(modify_enum, Modify.time) then
        self.time = net.ReadUInt(16)
        if handle_bass then
            bass:SetTime(self.time) -- 18 hours max, if you need more, wtf..
        end
    end

    -- 3D Position changed
    if hasModifyFlag(modify_enum, Modify.pos) then
        self.pos = net.ReadVector()
        if handle_bass then
            bass:SetPos(self.pos)
        end
    end

    -- Playback rate changed
    if hasModifyFlag(modify_enum, Modify.playback_rate) then
        self.playback_rate = net.ReadFloat()
        if handle_bass then
            bass:SetPlaybackRate(self.playback_rate)
        end
    end

    -- Playing / Paused state changed
    if hasModifyFlag(modify_enum, Modify.playing) then
        self.playing = net.ReadBool()
        -- Should always be true so..
        if handle_bass then
            if self.playing then
                -- If changed to be playing, play. Else stop
                bass:Play()
            else
                bass:Stop()
            end
        end
    end
end

function handleChanges(id, modify_enum)
    -- Object destroyed
    local self = Audios[id]
    local bass = self.bass

    if hasModifyFlag(modify_enum, Modify.destroyed) then
        print("Destroyed audio object!")
        bass:Stop()

        Audios[ self.id ] = nil
        self = nil
        return
    end

    -- Volume changed
    if hasModifyFlag(modify_enum, Modify.volume) then
        bass:SetVolume(self.volume)
    end

    -- Time changed
    if hasModifyFlag(modify_enum, Modify.time) then
        bass:SetTime(self.time) -- 18 hours max, if you need more, wtf..
    end

    -- 3D Position changed
    if hasModifyFlag(modify_enum, Modify.pos) then
        bass:SetPos(self.pos)
    end

    -- Playback rate changed
    if hasModifyFlag(modify_enum, Modify.playback_rate) then
        bass:SetPlaybackRate(self.playback_rate)
    end

    -- Playing / Paused state changed
    if hasModifyFlag(modify_enum, Modify.playing) then
        print("Playing changed", self.playing)
        if self.playing then
            -- If changed to be playing, play. Else stop
            bass:Play()
        else
            bass:Stop()
        end
    end
end

net.Receive("wa_change", function(len)
    local id, modify_enum = net.ReadUInt(8), net.ReadUInt(8)
    local obj = Audios[id]

    if not obj then return end -- Hm..

    if obj.bass then
        -- Store and handle changes
        storeChanges(id, modify_enum, true)
    else
        -- We don't have the bass object yet. Store the changes to update the object with later.
        AwaitingChanges[id] = modify_enum
        storeChanges(id, modify_enum)
    end
end)