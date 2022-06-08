--[[
	WebAudio E2 Library

	If you notice ``if condition then return 1 else return 0`` yes that is intentional.
	It should be more efficient than lua's 'ternary'
]]

--#region prelude

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

local CREATE_REGEN = 0.3 -- 300ms to regenerate a stream
local NET_REGEN = 0.1 -- 100ms to regenerate net messages

E2Lib.registerConstant( "CHANNEL_STOPPED", STOPWATCH_STOPPED )
E2Lib.registerConstant( "CHANNEL_PLAYING", STOPWATCH_PLAYING )
E2Lib.registerConstant( "CHANNEL_PAUSED", STOPWATCH_PAUSED )
E2Lib.registerConstant( "WA_FFT_SAMPLES", 64 ) -- Default samples #
E2Lib.registerConstant( "WA_FFT_DELAY", 80 ) -- Delay in ms

local function makeAlias(alias_name, original)
	local alias = table.Copy(wire_expression2_funcs[original])
	alias[1] = alias_name
	wire_expression2_funcs[alias_name] = alias
end

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
	local stream = WebAudio.new(url, owner)

	local idx = table.insert(self.data.webaudio_streams, stream)
	StreamCounter[owner] = (StreamCounter[owner] or 0) + 1

	stream:OnDestroy(function(_)
		self.data.webaudio_streams[idx] = nil
		StreamCounter[owner] = StreamCounter[owner] - 1
	end)

	return stream
end

--#endregion prelude

--#region stringify

-- string toString(webaudio stream)
__e2setcost(2)
registerFunction("toString", "xwa", "s", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local stream = op1[1](self, op1)

	if IsValid(stream) then
		return string.format("WebAudio [%d]", stream.id)
	else
		return "WebAudio [null]"
	end
end)

makeAlias("toString(xwa:)", "toString(xwa)")

WireLib.registerDebuggerFormat("WEBAUDIO", function(stream)
	if IsValid(stream) then
		return string.format( "WebAudio [Id: %d, volume: %d%%, time: %.02f/%d]", stream.id, stream.volume * 100, stream.stopwatch:GetTime(), stream.length )
	else
		return "WebAudio [null]"
	end
end)

--#endregion stringify

--#region operators

__e2setcost(1)
registerOperator("ass", "xwa", "xwa", function(self, args)
	local op1, op2, scope = args[2], args[3], args[4]
	local rv2 = op2[1](self, op2)
	self.Scopes[scope][op1] = rv2
	self.Scopes[scope].vclk[op1] = true
	return rv2
end)

registerOperator("eq", "xwaxwa", "n", function(self, args) -- if(Wa == Wa)
	local op1, op2 = args[2], args[3]
	local v1, v2 = op1[1](self, op1), op2[1](self, op2)
	if v1 == v2 then return 1 else return 0 end
end)

registerOperator("neq", "xwaxwa", "n", function(self, args) -- if(Wa != Wa)
	local op1, op2 = args[2], args[3]
	local v1, v2 = op1[1](self, op1), op2[1](self, op2)
	if v1 ~= v2 then return 1 else return 0 end
end)

registerOperator("is", "xpng", "n", function(self, args) -- if(Wa)
	local op1 = args[2]

	--- @type WebAudio
	local v1 = op1[1](self, op1)
	if v1 and v1:IsValid() then return 1 else return 0 end
end)

--#endregion operators

--#region util

--- Checks if a player / chip has permissions to use webaudio.
--- @param self table 'self' from E2Functions.
--- @param ent GEntity? Optional entity to check if they have permissions to modify.
local function checkPermissions(self, ent)
	if not Enabled:GetBool() then E2Lib.raiseException("WebAudio is currently disabled on the server!", nil, self.trace) end
	local ply = self.player

	local required_lv = AdminOnly:GetInt()
	if required_lv == 1 then
		if not ply:IsAdmin() then E2Lib.raiseException("WebAudio is currently restricted to admins!", nil, self.trace) end
	elseif required_lv == 2 then
		if not ply:IsSuperAdmin() then E2Lib.raiseException("WebAudio is currently restricted to super-admins!", nil, self.trace) end
	end

	if ent and not E2Lib.isOwner(self, ent) then
		-- Checking if you have perms to modify this prop.
		E2Lib.raiseException("You do not have permissions to modify this prop!", nil, self.trace)
	end
end

--- Generic Burst limit until wiremod gets its own like Starfall.
-- Also acts as a limit on the number of something.
---@class Burst
---@field max number
---@field regen number
---@field tracker table<GPlayer, { stock: number, last: number }>
local Burst = {}
Burst.__index = Burst

---@param max number
---@param regen_time number
---@return Burst
function Burst.new(max, regen_time)
	return setmetatable({
		max = max, -- Will start full.

		regen = regen_time,
		tracker = WireLib.RegisterPlayerTable()
	}, Burst)
end

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

---@param ply GPlayer
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

local CreationBurst = Burst.new( MaxStreams:GetInt(), CREATE_REGEN ) -- Prevent too many creations at once. (To avoid Creation->Destruction net spam.)
local NetBurst = Burst.new( 10, NET_REGEN ) -- In order to prevent too many updates at once.

cvars.RemoveChangeCallback("wa_stream_max", "wa_stream_max")

cvars.AddChangeCallback("wa_stream_max", function(_cvar_name, _old, new)
	CreationBurst.max = new
end, "wa_stream_max")

local function checkCounter(ply)
	local count = StreamCounter[ply] or 0
	if count < MaxStreams:GetInt() then
		return true
	end
	return false
end

--#endregion util

-- webaudio webAudio(string url)
__e2setcost(50)
registerFunction("webAudio", "s", "xwa", function(self, args)
	local op1 = args[2]
	local url = op1[1](self, op1)

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
	if not checkCounter(ply) then
		E2Lib.raiseException("Reached maximum amount of WebAudio streams! Check webAudioCanCreate or webAudiosLeft before calling!", nil, self.trace)
	end

	return registerStream(self, url, ply)
end)

--#region ability check

-- number webAudioCanCreate()
__e2setcost(2)
registerFunction("webAudioCanCreate", "", "n", function(self, args)
	local ply = self.player

	return (
		CreationBurst:check(ply)
		and checkCounter(ply, false)
	) and 1 or 0
end)

-- number webAudioCanCreate(string url)
__e2setcost(4)
registerFunction("webAudioCanCreate", "s", "n", function(self, args)
	local op1 = args[2]
	local url = op1[1](self, op1)

	local ply = self.player

	return (
		CreationBurst:check(ply)
		and checkCounter(ply, false)
		and WebAudio.isWhitelistedURL(url)
	) and 1 or 0
end)

-- number webAudioEnabled()
__e2setcost(1)
registerFunction("webAudioEnabled", "", "n", function(self, args)
	return Enabled:GetInt()
end)

-- number webAudioAdminOnly()
registerFunction("webAudioAdminOnly", "", "n", function(self, args)
	return AdminOnly:GetInt()
end)

-- number webAudiosLeft()
registerFunction("webAudiosLeft", "", "n", function(self, args)
	return MaxStreams:GetInt() - (StreamCounter[self.player] or 0)
end)

-- number webAudioCanTransmit()
registerFunction("webAudioCanTransmit", "", "n", function(self, args)
	if NetBurst:check(self.player) then return 1 else return 0 end
end)

--#endregion ability check

-- number webaudio:isValid()
__e2setcost(4)
registerFunction("isValid", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this and this:IsValid() then return 1 else return 0 end
end)

-- webaudio nowebaudio()
__e2setcost(2)
registerFunction("nowebaudio", "", "xwa", WebAudio.getNULL)

--#region special

-- number webaudio:play()
__e2setcost(15)
registerFunction("play", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

	if this.did_set_pos == nil and not IsValid(this.parent) then
		-- They didn't set position nor parent it.
		-- Probably want to default to parenting on chip.
		this:SetParent( self.entity )
	end

	return this:Play() and 1 or 0
end)

-- number webaudio:pause()
registerFunction("pause", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

	if this:Pause() then return 1 else return 0 end
end)

-- void webaudio:destroy()
registerFunction("destroy", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)
	-- No limit here because they'd already have been limited by the creation burst.
	return this:Destroy() and 1 or 0
end)

-- void webaudio:update()
registerFunction("update", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	checkPermissions(self)
	if not NetBurst:use(self.player) then return self:throw("You are transmitting too fast, check webAudioCanTransmit!", 0) end

	if this:IsValid() then
		return this:Transmit(false) and 1 or 0
	else
		return self:throw("This WebAudio is not valid!", 0)
	end
end)

--#endregion special

--#region setters

-- void webaudio:setPos(vector pos)
__e2setcost(5)
registerFunction("setPos", "xwa:v", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	---@type GVector
	local pos = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		this.did_set_pos = true
		this:SetPos(pos)
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- void webaudio:setVolume(number vol)
__e2setcost(5)
registerFunction("setVolume", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local volume = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetVolume( math.min(volume, MaxVolume:GetInt()) / 100 ) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- number webaudio:setTime(number time)
registerFunction("setTime", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local time = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetTime(time) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- void webaudio:setPlaybackRate(number rate)
registerFunction("setPlaybackRate", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local rate = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetPlaybackRate(rate) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

registerFunction("setDirection", "xwa:v", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local dir = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetPlaybackRate(dir) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- void webaudio:setRadius(number radius)
registerFunction("setRadius", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local radius = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetRadius( math.min(radius, MaxRadius:GetInt()) ) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- void webaudio:setLooping(number loop)
registerFunction("setLooping", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local loop = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetLooping(loop ~= 0) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- number webaudio:setParent(entity parent)
__e2setcost(5)
registerFunction("setParent", "xwa:e", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local parent = op2[1](self, op2)

	if not IsValid(parent) then return self:throw("Parent is invalid!", 0) end
	checkPermissions(self)

	if this:IsValid() then
		return this:SetParent(parent) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- number webaudio:setParent()
registerFunction("setParent", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	checkPermissions(self)

	if this:IsValid() then
		return this:SetParent(nil)
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

makeAlias("parentTo(xwa:e)", "setParent(xwa:e)")
makeAlias("unparent(xwa:)", "setParent(xwa:)")

-- number webaudio:set3DEnabled(number enabled)
registerFunction("set3DEnabled", "xwa:n", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	local enabled = op2[1](self, op2)

	checkPermissions(self)

	if this:IsValid() then
		return this:Set3DEnabled(enabled ~= 0) and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

--#endregion setters

--#region ignore system

--[[
	NOTE: This ignore system is fine right now but if there's ever a way for the client to re-subscribe themselves it'll be a problem.

	For example WebAudio:Unsubscribe is called on wa_purge / wa_enable being set to 0.
	But what if wa_enable being set to 1 called Subscribe again in the future?
]]

-- void webaudio:setIgnored(entity ply, number ignored)
__e2setcost(25)
registerFunction("setIgnored", "xwa:en", "n", function(self, args)
	local op1, op2, op3 = args[2], args[3], args[4]
	---@type WebAudio
	local this = op1[1](self, op1)

	---@type GPlayer
	local ply = op2[1](self, op2)

	---@type number
	local ignored = op3[1](self, op3)

	checkPermissions(self)

	if not this:IsValid() then
		return self:throw("Invalid WebAudio instance!", 0)
	end

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
end)

-- void webaudio:setIgnored(array plys, number ignored)
__e2setcost(5)
registerFunction("setIgnored", "xwa:rn", "n", function(self, args)
	local op1, op2, op3 = args[2], args[3], args[4]
	---@type WebAudio
	local this = op1[1](self, op1)

	---@type table<number, GPlayer>
	local plys = op2[1](self, op2)

	---@type number
	local ignored = op3[1](self, op3)

	checkPermissions(self)

	if not this:IsValid() then
		return self:throw("Invalid WebAudio instance!", 0)
	end

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
end)

registerFunction("getIgnored", "xwa:e", "n", function(self, args)
	local op1, op2 = args[2], args[3]
	---@type WebAudio
	local this = op1[1](self, op1)
	---@type GPlayer
	local ply = op2[1](self, op2)

	checkPermissions(self)

	if not this:IsValid() then
		return self:throw("Invalid WebAudio instance!", 0)
	end

	if not IsValid(ply) then
		return E2Lib.raiseException("Invalid player to check if ignored", nil, self.trace)
	end

	if not ply:IsPlayer() then
		return E2Lib.raiseException("Expected Player, got Entity", nil, self.trace)
	end

	return this:IsSubscribed(ply) and 0 or 1
end)

--#endregion ignore system


--#region getters

__e2setcost(2)
-- number webaudio:isParented()
registerFunction("isParented", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:IsParented() and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- vector webaudio:getPos()
registerFunction("getPos", "xwa:", "v", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetPos() or Vector(0, 0, 0)
	else
		return self:throw("Invalid WebAudio instance!", Vector(0, 0, 0))
	end
end)

__e2setcost(4)
-- number webaudio:getTime()
registerFunction("getTime", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetTimeElapsed()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- number webaudio:getLength()
registerFunction("getLength", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetLength()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- string webaudio:getFileName()
registerFunction("getFileName", "xwa:", "s", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetFileName()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- number webaudio:getFileName()
registerFunction("getState", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetState()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- number webaudio:getVolume()
registerFunction("getVolume", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetVolume()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- number webaudio:getRadius()
registerFunction("getRadius", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetRadius()
	else
		return self:throw("Invalid WebAudio instance!", -1)
	end
end)

-- number webaudio:getLooping()
registerFunction("getLooping", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:GetLooping() and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- number webaudio:get3DEnabled()
registerFunction("get3DEnabled", "xwa:", "n", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		return this:Get3DEnabled() and 1 or 0
	else
		return self:throw("Invalid WebAudio instance!", 0)
	end
end)

-- array webaudio:getFFT()
__e2setcost(800)
registerFunction("getFFT", "xwa:", "r", function(self, args)
	local op1 = args[2]
	---@type WebAudio
	local this = op1[1](self, op1)

	if this:IsValid() then
		if not FFTEnabled:GetBool() then
			return self:throw("FFT is disabled on this server!", {})
		end

		return this:GetFFT(true, 0.08) or {}
	else
		return self:throw("Invalid WebAudio instance!", {})
	end
end)

--#endregion getters

--#region cleanup

registerCallback("construct", function(self)
	self.data.webaudio_streams = {}
end)

registerCallback("destruct", function(self)
	---@type table<number, WebAudio>
	local streams = self.data.webaudio_streams

	for k, stream in pairs(streams) do
		if stream:IsValid() then
			stream:Destroy(true)
		end
		streams[k] = nil
	end
end)

--#endregion cleanup