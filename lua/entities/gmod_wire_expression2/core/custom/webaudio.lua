


E2Lib.RegisterExtension("webaudio", true, "Adds 3D Bass/IGmodAudioChannel web streaming to E2.")

local Common = WebAudio.Common

-- Convars
local Enabled, AdminOnly, FFTEnabled = Common.WAEnabled, Common.WAAdminOnly, Common.WAFFTEnabled
local MaxStreams, MaxVolume, MaxRadius = Common.WAMaxStreamsPerUser, Common.WAMaxVolume, Common.WAMaxRadius

local StreamCounter = WireLib.RegisterPlayerTable() -- Prevent having more streams than wa_max_streams
local CreationTimeTracker = WireLib.RegisterPlayerTable() -- Prevent too many creations at once. (To avoid Creation->Destruction net spam.)
local LastTransmissions = WireLib.RegisterPlayerTable() -- In order to prevent too many updates at once.

E2Lib.registerConstant( "CHANNEL_STOPPED", STOPWATCH_STOPPED )
E2Lib.registerConstant( "CHANNEL_PLAYING", STOPWATCH_PLAYING )
E2Lib.registerConstant( "CHANNEL_PAUSED", STOPWATCH_PAUSED )


registerType("webaudio", "xwa", WebAudio:getNULL(),
    nil, -- TODO: webaudios in io?
    nil,
    function(ret)
        -- For some reason we don't throw an error here.
        -- See https://github.com/wiremod/wire/blob/501dd9875ab1f6db37a795e1f9a946d382db4f1f/lua/entities/gmod_wire_expression2/core/entity.lua#L10

        if not ret then return end
        if not WebAudio:instanceOf(ret) then throw("Return value is neither nil nor a WebAudio object, but a %s!", type(ret)) end
    end,
    function(v)
        return WebAudio:instanceOf(v)
    end
)

local function registerStream(self, url, owner)
    local stream = WebAudio(url, owner)
    table.insert(self.data.webaudio_streams, stream)
    return stream
end

__e2setcost(1)
e2function webaudio operator=(webaudio lhs, webaudio rhs) -- Wa = webAudio("...") (Rip Coroutine Core comments)
    local scope = self.Scopes[ args[4] ]
    scope[lhs] = rhs
    scope.vclk[lhs] = true
    return rhs
end

e2function number operator==(webaudio lhs, webaudio rhs) -- if(webAudio("...")==Wa)
    return lhs == rhs
end

e2function number operator!=(webaudio lhs, webaudio rhs) -- if(Wa!=Wa)
    return lhs ~= rhs
end

e2function number operator_is(webaudio wa)
    return wa and 1 or 0
end

--- Checks if a player / chip has permissions to use webaudio.
-- @param table self 'self' from E2Functions.
-- @param Entity? ent Optional entity to check if they have permissions to modify.
local function checkPermissions(self, ent)
    if not Enabled:GetBool() then error("WebAudio is currently disabled on the server!") end
    local ply = self.player

    local required_lv = AdminOnly:GetInt()
    if required_lv == 1 then
        if not ply:IsAdmin() then error("WebAudio is currently restricted to admins!") end
    elseif required_lv == 2 then
        if not ply:IsSuperAdmin() then error("WebAudio is currently restricted to super-admins!") end
    end

    if ent then
        -- Checking if you have perms to modify this prop.
        if not E2Lib.isOwner(self, ent) then error("You do not have permissions to modify this prop!") end
    end
end

local function canTransmit(ply)
    local now = SysTime()
    local last = LastTransmissions[ply] or 0
    if now - last > 0.1 then
        -- Every player has a 100ms delay between net transmissions
        LastTransmissions[ply] = now
        return true
    else
        return false
    end
end

__e2setcost(50)
e2function webaudio webAudio(string url)
    local owner = self.player
    checkPermissions(self)

    if not WebAudio:isWhitelistedURL(url) then
        error("This URL is not whitelisted on the server! See the default whitelist on github!")
    end

    -- Creation Time Quota
    local now, last = SysTime(), CreationTimeTracker[owner] or 0
    if now - last < 0.15 then
        error("You are creating WebAudios too fast. Check webAudioCanCreate before calling!")
        --return WebAudio:getNULL()
    end
    CreationTimeTracker[owner] = now

    -- Stream Count Quota
    local count = StreamCounter[owner] or 0
    if count + 1 > MaxStreams:GetInt() then
        error("Reached maximum amount of WebAudio streams! Check webAudioCanCreate or webAudiosLeft before calling!")
        --return WebAudio:getNULL()
    end
    StreamCounter[owner] = count + 1

    return registerStream(self, url, owner)
end

__e2setcost(2)
e2function number webAudioCanCreate()
    local now, last = SysTime(), CreationTimeTracker[owner] or 0
    if (now - last < 0.15) then return 0 end -- Creating too fast
    if (StreamCounter[self.player] or 0) >= MaxStreams:GetInt() then return 0 end
    return 1
end

__e2setcost(4)
e2function number webAudioCanCreate(string url)
    local now, last = SysTime(), CreationTimeTracker[owner] or 0
    if (now - last < 0.15) then return 0 end -- Creating too fast
    if (StreamCounter[self.player] or 0) >= MaxStreams:GetInt() then return 0 end
    if not WebAudio:isWhitelistedURL(url) then return 0 end
    return 1
end

__e2setcost(1)
e2function number webAudioEnabled()
    return Enabled:GetInt()
end

e2function number webAudioAdminOnly()
    return AdminOnly:GetInt()
end

e2function number webAudiosLeft()
    return MaxStreams:GetInt() - (StreamCounter[self.player] or 0)
end

__e2setcost(4)
e2function number webaudio:isValid()
    return IsValid(this) and 1 or 0
end

__e2setcost(2)
e2function webaudio nowebaudio()
    return WebAudio:getNULL()
end

__e2setcost(5)
e2function void webaudio:setPos(vector pos)
    checkPermissions(self)
    this:SetPos(pos)
end

__e2setcost(15)
e2function number webaudio:play()
    checkPermissions(self)
    if not canTransmit(self.player) then return 0 end

    return this:Play() and 1 or 0
end

e2function number webaudio:pause()
    checkPermissions(self)
    if not canTransmit(self.player) then return 0 end

    return this:Pause() and 1 or 0
end

__e2setcost(5)
e2function void webaudio:setVolume(number vol)
    checkPermissions(self)
    this:SetVolume( math.min(vol, MaxVolume:GetInt())/100 )
end

e2function number webaudio:setTime(number time)
    checkPermissions(self)
    this:SetTime(time)
end

e2function void webaudio:setPlaybackRate(number rate)
    checkPermissions(self)
    this:SetPlaybackRate(rate)
end

e2function void webaudio:setDirection(vector dir)
    checkPermissions(self)
    this:SetDirection(dir)
end

e2function void webaudio:setRadius(number radius)
    checkPermissions(self)
    this:SetRadius( math.min(radius, MaxRadius:GetInt()) )
end

e2function void webaudio:setLooping(number loop)
    checkPermissions(self)
    this:SetLooping( loop ~= 0 )
end

e2function void webaudio:setFFTEnabled(number enabled)
    local en = enabled ~= 0
    if en then
        checkPermissions(self)
        if not FFTEnabled:GetBool() then error("FFT is not enabled on this server!") end
    end
    this:SetFFTEnabled(en)
end

__e2setcost(15)
e2function void webaudio:destroy()
    if this:Destroy() then
        local ply = self.player
        StreamCounter[ply] = StreamCounter[ply] - 1
    end
end

--- Updates the clientside IGmodAudioChannel object to pair with the WebAudio object.
-- @return number Whether the WebAudio object successfully transmitted. Returns 0 if you are hitting quota.
e2function number webaudio:update()
    checkPermissions(self)
    if not canTransmit(self.player) then return 0 end

    return this:Transmit() and 1 or 0
end

__e2setcost(5)
e2function number webaudio:setParent(entity parent)
    checkPermissions(self, parent)
    this:SetParent(parent)
    return 1
end

e2function void webaudio:setParent() this:SetParent(nil) end

e2function void webaudio:parentTo(entity ent) = e2function void webaudio:setParent(entity parent) -- Alias
e2function void webaudio:unparent() = e2function void webaudio:setParent() -- Alias

__e2setcost(2)
e2function number webaudio:isParented()
    return this:IsParented() and 1 or 0
end

e2function vector webaudio:getPos()
    return this:GetPos() or Vector(0, 0, 0)
end

__e2setcost(4)

e2function number webaudio:getTime()
    return this:GetTimeElapsed()
end

e2function number webaudio:getLength()
    return this:GetLength()
end

e2function string webaudio:getFileName()
    return this:GetFileName()
end

e2function number webaudio:getState()
    return this:GetState()
end

e2function number webaudio:getVolume()
    return this:GetVolume()
end

e2function number webaudio:getRadius()
    return this:GetRadius()
end

e2function number webaudio:getLooping()
    return this:GetLooping() and 1 or 0
end

e2function number webaudio:getFFTEnabled()
    return this:GetFFTEnabled() and 1 or 0
end

e2function array webaudio:getFFT()
    return this:GetFFT()
end

registerCallback("construct", function(self)
    self.data.webaudio_streams = {}
end)

registerCallback("destruct", function(self)
    local owner, streams = self.player, self.data.webaudio_streams
    local count = StreamCounter[owner]
    for k, stream in ipairs(streams) do
        if stream:IsValid() then
            count = count - 1 -- Assume StreamCounter[owner] is not nil since we're looping through self.webaudio_streams. If it is nil, something really fucked up.
            stream:Destroy()
        end
        streams[k] = nil
    end
    StreamCounter[owner] = count or 0
end)