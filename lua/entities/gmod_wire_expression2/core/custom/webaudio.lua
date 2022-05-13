E2Lib.RegisterExtension("webaudio", true, "Adds 3D Bass/IGmodAudioChannel web streaming to E2.")

local WebAudio = WebAudio
if not WebAudio then
	WebAudio = include("autorun/webaudio.lua")
end
local Common = WebAudio.Common

-- Convars
local Enabled, AdminOnly, FFTEnabled = Common.WAEnabled, Common.WAAdminOnly, Common.WAFFTEnabled
local MaxStreams, MaxVolume, MaxRadius = Common.WAMaxStreamsPerUser, Common.WAMaxVolume, Common.WAMaxRadius

local StreamCounter = WireLib.RegisterPlayerTable()
WebAudio.E2StreamCounter = StreamCounter

local CREATE_REGEN = 0.3 -- 300ms to regenerate a stream
local NET_REGEN = 0.1 -- 100ms to regenerate net messages

E2Lib.registerConstant( "CHANNEL_STOPPED", STOPWATCH_STOPPED )
E2Lib.registerConstant( "CHANNEL_PLAYING", STOPWATCH_PLAYING )
E2Lib.registerConstant( "CHANNEL_PAUSED", STOPWATCH_PAUSED )
E2Lib.registerConstant( "WA_FFT_SAMPLES", 64 ) -- Default samples #
E2Lib.registerConstant( "WA_FFT_DELAY", 80 ) -- Delay in ms


registerType("webaudio", "xwa", WebAudio.getNULL(),
	function(self, input)
		return input
	end,
	function(self, output)
		return output
	end,
	function(ret)
		-- For some reason we don't throw an error here.
		-- See https://github.com/wiremod/wire/blob/501dd9875ab1f6db37a795e1f9a946d382db4f1f/lua/entities/gmod_wire_expression2/core/entity.lua#L10

		if not ret then return end
		if not WebAudio.instanceOf(ret) then
			error("Return value is neither nil nor a WebAudio object, but a %s!", type(ret))
		end
	end,
	WebAudio.instanceOf
)

local function registerStream(self, url, owner)
	local stream = WebAudio(url, owner)
	table.insert(self.data.webaudio_streams, stream)
	return stream
end

e2function string toString(webaudio stream)
	if IsValid(stream) then
		return string.format("WebAudio [%d]", stream.id)
	else
		return "WebAudio [null]"
	end
end

e2function string webaudio:toString() = e2function string toString(webaudio stream)

WireLib.registerDebuggerFormat("WEBAUDIO", function(stream)
	if IsValid(stream) then
		return string.format( "WebAudio [Id: %d, volume: %d%%, time: %.02f/%d]", stream.id, stream.volume * 100, stream.stopwatch:GetTime(), stream.length )
	else
		return "WebAudio [null]"
	end
end)

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
	return IsValid(wa) and 1 or 0
end

--- Checks if a player / chip has permissions to use webaudio.
--- @param self table 'self' from E2Functions.
--- @param ent Entity? Optional entity to check if they have permissions to modify.
local function checkPermissions(self, ent)
	if not Enabled:GetBool() then E2Lib.raiseException("WebAudio is currently disabled on the server!", nil, self.trace) end
	local ply = self.player

	local required_lv = AdminOnly:GetInt()
	if required_lv == 1 then
		if not ply:IsAdmin() then E2Lib.raiseException("WebAudio is currently restricted to admins!", nil, self.trace) end
	elseif required_lv == 2 then
		if not ply:IsSuperAdmin() then E2Lib.raiseException("WebAudio is currently restricted to super-admins!", nil, self.trace) end
	end

	if ent then
		-- Checking if you have perms to modify this prop.
		if not E2Lib.isOwner(self, ent) then E2Lib.raiseException("You do not have permissions to modify this prop!", nil, self.trace) end
	end
end

--- Generic Burst limit until wiremod gets its own like Starfall.
-- Also acts as a limit on the number of something.
local Burst = setmetatable({}, {
	__call = function(self, max, regen_time)
		return setmetatable({
			max = max, -- Will start full.

			regen = regen_time,
			tracker = WireLib.RegisterPlayerTable()
		}, self)
	end
})
Burst.__index = Burst

function Burst:get(ply)
	local data = self.tracker[ply]
	if data then
		return data.stock
	else
		return self.max
	end
end

function Burst:check(ply)
	local data = self.tracker[ply]
	if data then
		local now = CurTime()
		local last = data.last

		local stock = data.stock
		if stock == 0 then
			stock = math.min( math.floor( (now - last) / self.regen), self.max)
			return stock > 0
		else
			return true
		end
	else
		return true
	end
end

function Burst:use(ply)
	local data = self.tracker[ply]
	if data then
		local now = CurTime()
		local last = data.last

		local stock = math.min( data.stock + math.floor( (now - last) / self.regen), self.max )

		if stock > 0 then
			data.stock = stock - 1
			data.last = CurTime()
			return true
		else
			return false
		end
	else
		self.tracker[ply] = {
			stock = self.max - 1, -- stockpile
			last = CurTime()
		}
		return true
	end
end

local CreationBurst = Burst( MaxStreams:GetInt(), CREATE_REGEN ) -- Prevent too many creations at once. (To avoid Creation->Destruction net spam.)
local NetBurst = Burst( 10, NET_REGEN ) -- In order to prevent too many updates at once.

cvars.AddChangeCallback("wa_stream_max", function(_cvar_name, _old, new)
	CreationBurst.max = new
end)

local function checkCounter(ply, use)
	local count = StreamCounter[ply] or 0
	if count < MaxStreams:GetInt() then
		if use then
			StreamCounter[ply] = count + 1
		end
		return true
	end
	return false
end

__e2setcost(50)
e2function webaudio webAudio(string url)
	local ply = self.player
	checkPermissions(self)

	if not WebAudio.isWhitelistedURL(url) then
		if WebAudio.Common.CustomWhitelist then
			E2Lib.raiseException("This URL is not whitelisted! The server has a custom whitelist.", nil, self.trace)
		else
			E2Lib.raiseException("This URL is not whitelisted! See github.com/Vurv78/WebAudio/blob/main/WHITELIST.md", nil, self.trace)
		end
	end

	-- Creation Time Quota
	if not CreationBurst:use(ply) then
		E2Lib.raiseException("You are creating WebAudios too fast. Check webAudioCanCreate before calling!", nil, self.trace)
	end

	-- Stream Count Quota
	if not checkCounter(ply, true) then
		E2Lib.raiseException("Reached maximum amount of WebAudio streams! Check webAudioCanCreate or webAudiosLeft before calling!", nil, self.trace)
	end

	return registerStream(self, url, ply)
end

__e2setcost(2)
e2function number webAudioCanCreate()
	local ply = self.player

	return (
		CreationBurst:check(ply)
		and checkCounter(ply, false)
	) and 1 or 0
end

__e2setcost(4)
e2function number webAudioCanCreate(string url)
	local ply = self.player

	return (
		CreationBurst:check(ply)
		and checkCounter(ply, false)
		and WebAudio.isWhitelistedURL(url)
	) and 1 or 0
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

e2function number webAudioCanTransmit()
	return NetBurst:check(self.player) and 1 or 0
end

__e2setcost(4)
e2function number webaudio:isValid()
	return IsValid(this) and 1 or 0
end

__e2setcost(2)
e2function webaudio nowebaudio()
	return WebAudio.getNULL()
end

__e2setcost(5)
e2function void webaudio:setPos(vector pos)
	checkPermissions(self)

	this.did_set_pos = true
	this:SetPos(pos)
end

__e2setcost(15)
e2function number webaudio:play()
	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

	if this.did_set_pos == nil and not IsValid(this.parent) then
		-- They didn't set position nor parent it.
		-- Probably want to default to parenting on chip.
		this:SetParent( self.entity )
	end

	return this:Play() and 1 or 0
end

e2function number webaudio:pause()
	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

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

e2function void webaudio:set3DEnabled(number enabled)
	checkPermissions(self)
	this:Set3DEnabled( enabled ~= 0 )
end

--[[
	NOTE: This ignore system is fine right now but if there's ever a way for the client to re-subscribe themselves it'll be a problem.

	For example WebAudio:Unsubscribe is called on wa_purge / wa_enable being set to 0.
	But what if wa_enable being set to 1 called Subscribe again in the future?
]]

__e2setcost(25)
e2function void webaudio:setIgnored(entity ply, number ignored)
	checkPermissions(self)

	if not IsValid(ply) then
		E2Lib.raiseException("Invalid player to ignore", nil, self.trace)
	end

	if not ply:IsPlayer() then
		E2Lib.raiseException("Expected Player, got Entity", nil, self.trace)
	end

	this.unsubbed_by_e2 = this.unsubbed_by_e2 or WireLib.RegisterPlayerTable()

	if ignored == 0 then
		-- Re-subscribe a user to the stream. (Only if they were unsubscribed by E2 previously.)
		if not this:IsSubscribed(ply) and this.unsubbed_by_e2[ply] then
			this:Subscribe(ply)
			this.unsubbed_by_e2[ply] = nil
		end
	else
		-- Ignore stream. Everyone can toggle this.
		if this:IsSubscribed(ply) then
			this.unsubbed_by_e2[ply] = true
			this:Unsubscribe(ply)
		end
	end
end

__e2setcost(5)
e2function void webaudio:setIgnored(array plys, number ignored)
	checkPermissions(self)

	this.unsubbed_by_e2 = this.unsubbed_by_e2 or WireLib.RegisterPlayerTable()

	for _, ply in ipairs(plys) do
		self.prf = self.prf + 5
		if IsValid(ply) and ply:IsPlayer() then
			if ignored == 0 then
				-- Re-subscribe a user to the stream. (Only if they were unsubscribed by E2 previously.)
				if not this:IsSubscribed(ply) and this.unsubbed_by_e2[ply] then
					this:Subscribe(ply)
					this.unsubbed_by_e2[ply] = nil
				end
			else
				-- Ignore stream. Everyone can toggle this.
				if this:IsSubscribed(ply) then
					this.unsubbed_by_e2[ply] = true
					this:Unsubscribe(ply)
				end
			end
		end
	end
end

e2function number webaudio:getIgnored(entity ply)
	if not IsValid(ply) then
		return E2Lib.raiseException("Invalid player to check if ignored", nil, self.trace)
	end

	if not ply:IsPlayer() then
		return E2Lib.raiseException("Expected Player, got Entity", nil, self.trace)
	end

	return this:IsSubscribed(ply) and 0 or 1
end

__e2setcost(15)
e2function void webaudio:destroy()
	-- No limit here because they'd already have been limited by the creation burst.
	local owner = this.owner or self.player
	-- Prevent people destroying others streams and getting more slots? Would be weird.
	if this:Destroy() then
		StreamCounter[owner] = StreamCounter[owner] - 1
	end
end

--- Updates the clientside IGmodAudioChannel object to pair with the WebAudio object.
--- @return number # Whether the WebAudio object successfully transmitted. Returns 0 if you are hitting quota.
e2function number webaudio:update()
	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

	return this:Transmit() and 1 or 0
end

__e2setcost(5)
e2function number webaudio:setParent(entity parent)
	if not IsValid(parent) then return self:throw("Parent is invalid!", 0) end
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

e2function number webaudio:get3DEnabled()
	return this:Get3DEnabled() and 1 or 0
end

__e2setcost(800)
e2function array webaudio:getFFT()
	return this:GetFFT(true, 0.08) or {}
end

registerCallback("construct", function(self)
	self.data.webaudio_streams = {}
end)

registerCallback("destruct", function(self)
	local owner, streams = self.player, self.data.webaudio_streams
	local count = StreamCounter[owner] or 0
	for k, stream in pairs(streams) do
		if stream:IsValid() then
			count = count - 1 -- Assume StreamCounter[owner] is not nil since we're looping through self.webaudio_streams. If it is nil, something really fucked up.
			stream:Destroy()
		end
		streams[k] = nil
	end
	StreamCounter[owner] = count
end)