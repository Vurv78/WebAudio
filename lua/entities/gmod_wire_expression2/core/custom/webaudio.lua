


E2Lib.RegisterExtension("webaudio", true, "Adds 3D Bass Audio playing to E2.")

local Common = include("autorun/wa_common.lua")
local isWebAudio = Common.isWebAudio

local Enabled = Common.WAEnabled
local AdminOnly = Common.WAAdminOnly
local MaxStreams = Common.WAMaxStreamsPerUser

local StreamCounter = WireLib.RegisterPlayerTable() -- Prevent having more streams than wa_max_streams
local CreationTimeTracker = WireLib.RegisterPlayerTable() -- Prevent too many creations at once. (To avoid Creation->Destruction net spam.)
local LastTransmissions = WireLib.RegisterPlayerTable() -- In order to prevent too many updates at once.

registerType("webaudio", "xwa", nil,
    nil,
    nil,
    function(ret)
        -- For some reason we don't throw an error here.
        -- See https://github.com/wiremod/wire/blob/501dd9875ab1f6db37a795e1f9a946d382db4f1f/lua/entities/gmod_wire_expression2/core/entity.lua#L10

        if not ret then return end
        if not isWebAudio(ret) then throw("Return value is neither nil nor a WebAudio object, but a %s!", type(ret)) end
    end,
    function(v)
        return isWebAudio(v)
    end
)

local function registerStream(self, obj, owner)
    table.insert(self.webaudio_streams, obj)
    return obj
end

__e2setcost(1)
e2function webaudio operator=(webaudio lhs, webaudio rhs) -- Co = coroutine("bruh(e:)")
    local scope = self.Scopes[ args[4] ]
    scope[lhs] = rhs
    scope.vclk[lhs] = true
    return rhs
end

e2function number operator==(webaudio lhs, webaudio rhs) -- if(coroutineRunning()==Co)
    return lhs == rhs
end

e2function number operator!=(webaudio lhs, webaudio rhs) -- if(coroutineRunning()!=Co)
    return lhs ~= rhs
end

e2function number operator_is(webaudio wa)
    return co and 1 or 0
end

local function checkPermissions(ply)
    if not Enabled:GetBool() then error("WebAudio is currently disabled on the server!") end

    local required_lv = AdminOnly:GetInt()
    if required_lv == 1 then
        if not ply:IsAdmin() then error("WebAudio is currently restricted to admins!") end
    elseif required_lv == 2 then
        if not ply:IsSuperAdmin() then error("WebAudio is currently restricted to super-admins!") end
    end
end

local function canTransmit(ply)
    local now = SysTime()
    local last = LastTransmissions[ply] or 0
    if now - last > 0.15 then
        -- Every player has a 150ms delay between updates for webaudios
        LastTransmissions[ply] = now
        return true
    else
        return false
    end
end

__e2setcost(50)
e2function webaudio webAudio(string url)
    local owner = self.player

    checkPermissions(owner)

    local now, last = SysTime(), CreationTimeTracker[owner] or 0
    if now - last < 0.15 then
        error("You are creating webaudios too fast.")
    end
    CreationTimeTracker[owner] = now

    local count = StreamCounter[owner] or 0
    if count+1 > MaxStreams:GetInt() then
        error("Reached maximum amount of WebAudio streams!")
    end
    StreamCounter[owner] = count + 1
    return registerStream(self, WebAudio(url, owner), owner)
end

__e2setcost(2)
e2function number webAudioCanCreate()
    local now, last = SysTime(), CreationTimeTracker[owner] or 0
    return (now - last > 0.15)
end

e2function number webAudioEnabled()
    return Enabled:GetInt()
end

e2function number webAudioAdminOnly()
    return AdminOnly:GetInt()
end

e2function number webAudiosLeft()
    return MaxStreams:GetInt() - (StreamCounter[self.player] or 0)
end

__e2setcost(5)
e2function void webaudio:setPos(vector pos)
    checkPermissions(self.player)
    this:SetPos(pos)
end

__e2setcost(15)
e2function number webaudio:play()
    checkPermissions(self.player)
    if canTransmit(self.player) then
        this:Play()
        return 1
    else
        return 0
    end
end

e2function number webaudio:pause()
    checkPermissions(self.player)
    if canTransmit(self.player) then
        this:Pause()
        return 1
    else
        return 0
    end
end

__e2setcost(5)
e2function void webaudio:setVolume(number vol)
    checkPermissions(self.player)
    local max = Common.WAMaxVolume:GetInt()
    if vol > max then error("Volume is too high, must be [0-" .. max .. "%] !") end
    this:SetVolume(vol/100)
end

e2function void webaudio:setTime(number time)
    checkPermissions(self.player)
    this:SetTime(time)
end

e2function void webaudio:setPlaybackRate(number rate)
    checkPermissions(self.player)
    this:SetPlaybackRate(rate)
end

e2function void webaudio:setDirection(vector dir)
    checkPermissions(self.player)
    this:SetDirection(dir)
end

__e2setcost(15)
e2function void webaudio:destroy()
    if this:Destroy() then
        StreamCounter[self.player] = StreamCounter[self.player] - 1
    end
end

--- Updates the clientside IGmodAudioChannel object to pair with the WebAudio object.
-- @return number Whether the WebAudio object successfully transmitted. Returns 0 if you are hitting quota.
e2function number webaudio:update()
    checkPermissions(self.player)
    if canTransmit(self.player) then
        this:Transmit()
        return 1
    else
        return 0
    end
end

__e2setcost(3)
e2function number webaudio:isDestroyed()
    return (not this or this:IsDestroyed()) and 1 or 0
end

__e2setcost(2)
e2function webaudio nowebaudio()
    return nil
end

registerCallback("construct", function(self)
    self.webaudio_streams = {}
end)

registerCallback("destruct", function(self)
    local owner = self.player
    local count = StreamCounter[owner]
    for _, stream in next, self.webaudio_streams do
        count = count - 1 -- Assume StreamCounter[owner] is not nil since we're looping through self.webaudio_streams. If it is nil, something really fucked up.
        stream:Destroy()
        stream = nil
    end
    StreamCounter[owner] = math.min(count, 0) -- Call min() on it just in case.
    self.webaudio_streams = nil
end)