


E2Lib.RegisterExtension("webaudio", true, "Adds 3D Bass Audio playing to E2.")

local Common = include("autorun/wa_common.lua")
local isWebAudio = Common.isWebAudio

local MaxStreams = Common.WAMaxStreamsPerUser

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

__e2setcost(50)
local stream_count = WireLib.RegisterPlayerTable()
local creationtime_tracker = WireLib.RegisterPlayerTable()
e2function webaudio createWebAudio(string url)
    local owner = self.player

    local now, last = SysTime(), creationtime_tracker[owner] or 0
    if now - last < 0.15 then
        error("You are creating webaudios too fast.")
    end
    creationtime_tracker[owner] = now

    local count = stream_count[owner] or 0
    if count+1 > MaxStreams:GetInt() then
        error("Reached maximum amount of WebAudio streams!")
    end
    stream_count[owner] = count + 1
    return registerStream(self, WebAudio(url, owner), owner)
end

e2function number canCreateWebAudio()
    local now, last = SysTime(), creationtime_tracker[owner] or 0
    return now - last > 0.15
end

__e2setcost(2)
e2function number webAudiosLeft()
    local ct = stream_count[self.player]
    return MaxStreams:GetInt() - ct
end

--- Expects a WebAudio object to not be destroyed, else throws an error.
local function expect_audio(this)
    if this:IsDestroyed() then
        error("Invalid WebAudio stream!")
    end
    return this
end

__e2setcost(5)
e2function void webaudio:setPos(vector pos)
    local this = expect_audio(this)
    this:SetPos(pos)
end

__e2setcost(15)
e2function void webaudio:play()
    local this = expect_audio(this)
    this:Play()
end

__e2setcost(15)
e2function void webaudio:stop()
    local this = expect_audio(this)
    this:Stop()
end

__e2setcost(5)
e2function void webaudio:setVolume(number vol)
    local this = expect_audio(this)
    local max = Common.WAMaxVolume:GetInt()
    if vol > max then error("Volume is too high, must be [0-" .. max .. "%] !") end
    this:SetVolume(vol/100)
end

e2function void webaudio:setTime(number time)
    local this = expect_audio(this)
    this:SetTime(time)
end

e2function void webaudio:setPlaybackRate(number rate)
    local this = expect_audio(this)
    this:SetPlaybackRate(rate)
end

__e2setcost(15)
e2function void webaudio:destroy()
    local this = expect_audio(this)
    stream_count[self.player] = stream_count[self.player] - 1
    this:Destroy()
end

-- In order to prevent too many updates at once.
local last_transmissions = WireLib.RegisterPlayerTable()

--- Updates the clientside IGmodAudioChannel object to pair with the WebAudio object.
-- @return number Whether the WebAudio object successfully transmitted. Returns 0 if you are hitting quota.
e2function number webaudio:update()
    local now = SysTime()
    local last = last_transmissions[self.player] or 0
    if now - last > 0.15 then
        -- Every player has a 150ms delay between updates for webaudios
        this:Transmit()
        last_transmissions[self.player] = now
        return 1
    else
        return 0
    end
end

registerCallback("construct", function(self)
    self.webaudio_streams = {}
end)

registerCallback("destruct", function(self)
    local owner = self.player
    local count = stream_count[owner]
    for _, stream in next, self.webaudio_streams do
        count = count - 1 -- Assume stream_count[owner] is not nil since we're looping through self.webaudio_streams. If it is nil, something really fucked up.
        stream:Destroy()
        stream = nil
    end
    stream_count[owner] = count
    self.webaudio_streams = nil
end)