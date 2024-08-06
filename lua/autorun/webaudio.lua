--[[
	Common Stuff
	(part 1)
]]

--- x86 branch is on LuaJIT 2.0.4 which doesn't support binary literals
local function b(s)
	return tonumber(s, 2)
end

-- Modification Flags
-- If you ever change a setting of the Interface object, will add one of these flags to it.
-- This will be sent to the client to know what to read in the net message to save networking
local Modify = {
	volume        = b"000000000001",
	time          = b"000000000010",
	pos           = b"000000000100",
	playing       = b"000000001000",
	playback_rate = b"000000010000",
	direction     = b"000000100000",
	parented      = b"000001000000",
	radius        = b"000010000000",
	looping       = b"000100000000",
	mode          = b"001000000000",
	reserved      = b"010000000000", -- pan maybe?

	destroyed     = b"100000000000",

	all           = b"111111111111"
}

-- Bits needed to send a bitflag of all the modifications
local MODIFY_LEN = math.ceil( math.log(Modify.all, 2) )

-- Max 1024 current streams
local ID_LEN = math.ceil( math.log(1024, 2) )

local FFTSAMP_LEN = 8

local function toBinary(n, bits)
	bits = bits or 32

	local t = {}
	for i = bits, 1, -1 do
		-- Basically go by each bit and use bit32.extract. Inlined the function here with width as 1.
		-- https://github.com/AlberTajuelo/bitop-lua/blob/8146f0b323f55f72eacbb2a8310922d50ae75ddf/src/bitop/funcs.lua#L92
		t[bits - i] = bit.band(bit.rshift(n, i), 1)
	end

	return "0b" .. table.concat(t)
end

local function hasModifyFlag(first, ...)
	return bit.band(first, ...) ~= 0
end

--- Debug function that's exported as well
local function getFlags(number)
	local out = {}
	for enum_name, enum_val in pairs(Modify) do
		if hasModifyFlag(number, enum_val) then
			table.insert(out, enum_name)
		end
	end
	return out
end

-- SERVER
local WAAdminOnly = CreateConVar("wa_admin_only", "0", FCVAR_REPLICATED, "Whether creation of WebAudio objects should be limited to admins. 0 for everyone, 1 for admins, 2 for superadmins. wa_enable_sv takes precedence over this", 0, 2)
local WASCCompat = CreateConVar("wa_sc_compat", "0", FCVAR_ARCHIVE, "Whether streamcore-compatible functions should be generated for E2.", 0, 1)

-- Max in total is ~1023 from ID_LEN writing a 10 bit uint. Assuming ~30 players max using webaudio, can only give ~30.
local WAMaxStreamsPerUser = CreateConVar("wa_stream_max", "5", FCVAR_REPLICATED, "Max number of streams a player can have at once.", 1, 30)

-- SHARED
local WAEnabled = CreateConVar("wa_enable", "1", FCVAR_ARCHIVE + FCVAR_USERINFO, "Whether webaudio should be enabled to play on your client/server or not.", 0, 1)
local WAMaxVolume = CreateConVar("wa_volume_max", "300", FCVAR_ARCHIVE, "Highest volume a webaudio sound can be played at, in percentage. 200 is 200%. SHARED Convar", 0, 100000)
local WAMaxRadius = CreateConVar("wa_radius_max", "3000", FCVAR_ARCHIVE, "Farthest distance a WebAudio stream can be heard from. Will clamp to this value. SHARED Convar", 0, 1000000)
local WAFFTEnabled = CreateConVar("wa_fft_enable", "1", FCVAR_ARCHIVE, "Whether FFT data is enabled for the server / your client. You shouldn't need to disable it as it is very lightweight.", 0, 1)

-- CLIENT

-- 0 is no prints, 1 is warnings/errors, 2 is additional logging
local WAVerbosity
if CLIENT then
	WAVerbosity = CreateConVar("wa_verbosity", "1", FCVAR_ARCHIVE, "Verbosity of WebAudio information & warnings printed to your console. 2 is warnings & stream logging, 1 is only warnings (default), 0 is nothing (Not recommended).", 0, 2)
end

local Black = Color(0, 0, 0, 255)
local Color_Warn = Color(243, 71, 41, 255)
local Color_Notify = Color(65, 172, 235, 255)
local White = Color(255, 255, 255, 255)

local function warn(...)
	local msg = string.format(...)
	MsgC(Black, "[", Color_Warn, "WA", Black, "]", White, ": ", msg, "\n")
end

local function notify(...)
	local msg = string.format(...)
	MsgC(Black, "[", Color_Notify, "WA", Black, "]", White, ": ", msg, "\n")
end

if WebAudio and WebAudio.disassemble then
	if SERVER then
		-- Make sure to also run wire_expression2_reload (after this) if working on this addon with hot reloading.
		notify("Reloaded!")
	end
	WebAudio.disassemble()
end

--[[
	OOP
]]

--- Initiate WebAudio struct for both realms
---@class WebAudio
---@field url string # SHARED
---@field stopwatch Stopwatch # SERVER
---@field radius number # SHARED
---@field radius_sqr number # SHARED
---@field looping boolean # SHARED
---@field parent GEntity # SHARED
---@field parented boolean # SHARED
---@field parent_pos GVector # CLIENT
---@field volume number # SHARED 0-1
---@field fft table<number, number> # SERVER. Array of numbers 0-255 representing the FFT data.
---@field bass GIGModAudioChannel # CLIENT. Bass channel.
---@field filename string # SHARED. Filename of the sound. Not necessarily URL. Requires client to network it first.
---@field length integer # SHARED. Playtime length of the sound. Requires client to network it first.
---@field owner GEntity # SERVER. Owner of the webaudio or NULL for lua-owned.
---@field pos GVector # SERVER. Position of stream
---@field id integer # Custom ID for webaudio stream allocated between 0-MAX
---@field ignored GCRecipientFilter # Players to ignore when sending net messages.
---@field mode WebAudioMode
---@field hook_destroy table<fun(self: WebAudio), boolean> # SHARED. Hooks to run before/when the stream is destroyed.
_G.WebAudio = {}
WebAudio.__index = WebAudio

WebAudio.MODIFY_LEN = MODIFY_LEN
WebAudio.ID_LEN = ID_LEN
WebAudio.FFTSAMP_LEN = FFTSAMP_LEN

---@alias WebAudioMode 0|1

---@type WebAudioMode
WebAudio.MODE_2D = 0
---@type WebAudioMode
WebAudio.MODE_3D = 1

local WebAudioCounter = 0
local WebAudios = {} -- TODO: See why weak kv doesn't work clientside for this

local MaxID = 1023 -- UInt10. Only 1024 concurrent webaudio streams are allowed, if you use more than that then you've probably already broken the server
local TopID = -1 -- Current top-most id. Set to -1 since we will increment first, having the ids start at 0.
local IsSequential = true -- Boost for initial creation when no IDs have been dropped.

local function register(id)
	-- id is set as occupied in the constructor through WebAudios
	WebAudioCounter = WebAudioCounter + 1
	TopID = id
	return id
end

--- Alloc an id for a webaudio stream & register it to WebAudios
-- Modified from https://gist.github.com/Vurv78/2de64f77d04eb409abed008ab000e5ef
--- @return integer? # ID or nil if reached max.
local function allocID()
	if WebAudioCounter > MaxID then return end

	if IsSequential then
		return register(TopID + 1)
	end

	local left_until_loop = MaxID - TopID

	-- Avoid constant modulo with two for loops

	for i = 1, left_until_loop do
		local i2 = TopID + i
		if not WebAudios[i2] then
			return register(i2)
		end
	end

	for i = 0, TopID do
		if not WebAudios[i] then
			return register(i)
		end
	end
end

debug.getregistry()["WebAudio"] = WebAudio

--- Returns whether the WebAudio object is valid and not destroyed.
--- @return boolean # If it's Valid
function WebAudio:IsValid()
	return not self.destroyed
end

--- Returns whether the WebAudio object is Null
--- @return boolean # Whether it's destroyed/null
function WebAudio:IsDestroyed()
	return self.destroyed
end

--- Calls the given function right before webaudio destruction.
---@param fun fun(self: WebAudio)
function WebAudio:OnDestroy(fun)
	self.hook_destroy[fun] = true
end

--- Destroys a webaudio object and makes it the same (value wise) as WebAudio.getNULL()
--- @param transmit boolean? If SERVER, should we transmit the destruction to the client? Default true
function WebAudio:Destroy(transmit)
	if self:IsDestroyed() then return end
	if transmit == nil then transmit = true end

	for callback in pairs(self.hook_destroy) do
		callback(self)
	end

	if CLIENT and self.bass then
		self.bass:Stop()
	elseif transmit then
		if self.AddModify then
			-- Bandaid fix for garbage with autorefresh
			-- 1. create stream
			-- 2. wire_expression2_reload
			-- 3. autorefresh this file
			-- AddModify won't exist.
			self:AddModify(Modify.destroyed)
			self:Transmit(true)
		end
	end

	local id = self.id
	if WebAudios[id] then
		-- Drop ID
		WebAudioCounter = WebAudioCounter - 1
		IsSequential = false

		WebAudios[id] = nil
	end

	for k in next, self do
		self[k] = nil
	end
	self.destroyed = true

	return true
end

--- Returns current time in URL stream.
-- Time elapsed is calculated on the server using playback rate and playback time.
-- Not perfect for the clients and there will be desync if you pause and unpause constantly.
--- @return number # Elapsed time
function WebAudio:GetTimeElapsed()
	if self:IsDestroyed() then return -1 end
	return self.stopwatch:GetTime()
end

--- Returns the volume of the object set by SetVolume
--- @return number # Volume from 0-1
function WebAudio:GetVolume()
	return self.volume
end

--- Returns the position of the WebAudio object.
--- @return GVector? # Position of the stream or nil if not set.
function WebAudio:GetPos()
	return self.pos
end

--- Returns the radius of the stream set by SetRadius
--- @return number # Radius
function WebAudio:GetRadius()
	return self.radius
end

--- Returns the playtime length of a WebAudio object.
--- @return number # Playtime Length
function WebAudio:GetLength()
	return self.length
end

--- Returns the file name of the WebAudio object. Not necessarily always the URL.
--- @return string # File name
function WebAudio:GetFileName()
	return self.filename
end

--- Returns the state of the WebAudio object
--- @return number # State, See STOPWATCH_* Enums
function WebAudio:GetState()
	if self:IsDestroyed() then return STOPWATCH_STOPPED end
	return self.stopwatch:GetState()
end

--- Returns whether the webaudio stream is looping (Set by SetLooping.)
--- @return boolean # Looping
function WebAudio:GetLooping()
	return self.looping
end

--- Returns whether the webaudio stream is 3D enabled (Set by Set3DEnabled.)
--- @return boolean # 3D Enabled
function WebAudio:Get3DEnabled()
	return self.mode == WebAudio.MODE_3D
end

--- Returns whether the stream is parented or not. If it is parented, you won't be able to set it's position.
--- @return boolean # # Whether it's parented
function WebAudio:IsParented()
	return self.parented
end

-- Static Methods
---@class WebAudio
local WebAudioStatic = {}
-- For consistencies' sake, Static functions will be lowerCamelCase, while object / meta methods will be CamelCase.

--- Returns an unusable WebAudio object that just has the destroyed field set to true.
--- @return WebAudio # The null stream
function WebAudioStatic.getNULL()
	return setmetatable({ destroyed = true }, WebAudio)
end

--- Same as net.ReadUInt but doesn't need the bit length in order to adapt our code more easily.
---- @return number # # UInt10
function WebAudioStatic.readID()
	return net.ReadUInt(ID_LEN)
end

--- Faster version of WebAudio.getFromID( WebAudio.readID() )
---- @return WebAudio? # # The stream or nil if it wasn't found
function WebAudioStatic.readStream()
	return WebAudios[ net.ReadUInt(ID_LEN) ]
end

--- Same as net.WriteUInt but doesn't need the bit length in order to adapt our code more easily.
---- @param number id UInt10 (max id is 1023)
function WebAudioStatic.writeID(id)
	net.WriteUInt(id, ID_LEN)
end

--- Same as net.WriteUInt but doesn't need the bit length in order to adapt our code more easily.
---- @param WebAudio stream The stream. This is the same as WebAudio.writeID( stream.id )
function WebAudioStatic.writeStream(stream)
	net.WriteUInt(stream.id, ID_LEN)
end

--- Reads a WebAudio Modify enum
---- @return number # UInt16
function WebAudioStatic.readModify()
	return net.ReadUInt(MODIFY_LEN)
end

--- Writes a WebAudio Modify enum
---- @param number modify UInt16
function WebAudioStatic.writeModify(modify)
	net.WriteUInt(modify, MODIFY_LEN)
end

---@return WebAudio
function WebAudioStatic.getFromID(id)
	return WebAudios[id]
end

function WebAudioStatic.getList()
	return WebAudios
end

local next = next

--- Returns an iterator for the global table of all webaudio streams. Use this in a for in loop
--- @return fun(): number, WebAudio # Iterator, should be the same as ipairs / next
--- @return table # Global webaudio table. Same as WebAudio.getList()
--- @return number # Origin index, will always be nil (0 would be ipairs)
function WebAudioStatic.getIterator()
	return next, WebAudios, nil
end

--- Returns the number of currently active streams
-- Cheaper than manually calling __len on the webaudio table as we keep track of it ourselves.
---@return integer
function WebAudioStatic.getCountActive()
	return WebAudioCounter
end

--- Returns if an object is a WebAudio object, even if Invalid/Destroyed.
---@return boolean?
local function isWebAudio(v)
	if not istable(v) then return end
	return debug.getmetatable(v) == WebAudio
end

WebAudioStatic.instanceOf = isWebAudio

--- If you want to extend the static functions
--- @return table # The WebAudio static function / var table.
function WebAudioStatic.getStatics()
	return WebAudioStatic
end

--- Used internally. Should be called both server and client as it doesn't send any net messages to destroy the ids to the client.
-- Called on WebAudio reload to stop all streams
function WebAudioStatic.disassemble()
	for _, stream in WebAudio.getIterator() do
		stream:Destroy(false)
	end
end

local function createWebAudio(_, url, owner, bassobj, id)
	assert( WebAudio.isWhitelistedURL(url), "'url' argument must be given a whitelisted url string." )
	-- assert( owner and isentity(owner) and owner:IsPlayer(), "'owner' argument must be a valid player." )
	-- Commenting this out in case someone wants a webaudio object to be owned by the world or something.

	local self = setmetatable({
		-- allocID will return nil if there's no slots left.
		id = assert( id or allocID(), "Reached maximum amount of concurrent WebAudio streams!" ),
		url = url,
		owner = owner,
		mode = WebAudio.MODE_3D,

		--#region mutable
		playing = false,
		destroyed = false,

		parented = false,
		parent = nil, -- Entity

		modified = 0,
		playback_rate = 1,
		volume = 1,
		time = 0,

		radius = math.min(200, WAMaxRadius:GetInt()), -- Default IGmodAudioChannel radius
		radius_sqr = math.min(200, WAMaxRadius:GetInt()) ^ 2,

		pos = nil,
		direction = Vector(0, 0, 0),
		looping = false,
		--#endregion mutable

		--#region net vars
		needs_info = SERVER, -- Whether this stream still needs information from the client.
		length = -1,
		filename = "",
		fft = {},

		hook_destroy = {}
		--#endregion net vars
	}, WebAudio)


	if CLIENT then
		self.bass = bassobj
		self.parent_pos = Vector(0, 0, 0) -- Parent pos being nil means we will go directly to the parent's position w/o calculating local pos.
	else
		-- Stream will be set to 100 second length until the length of the audio stream is determined by the client.
		self.stopwatch = StopWatch.new(100, function(watch)
			if not watch:GetLooping() then
				self:Pause()
			end
		end)

		self.ignored = RecipientFilter()

		net.Start("wa_create", true)
			WebAudio.writeID(self.id)
			net.WriteString(self.url)
			net.WriteEntity(self.owner)
		self:Broadcast(false) -- Defined in wa_interface
	end

	WebAudios[self.id] = self

	return self
end

setmetatable(WebAudio, {
	__index = WebAudioStatic,
	__call = createWebAudio
})

--- Creates a new webaudio object. Prefer this over the __call version
---@param url string
---@param owner GPlayer?
---@param bassobj GIGModAudioChannel?
---@param id number?
---@return WebAudio
function WebAudio.new(url, owner, bassobj, id)
	return createWebAudio(WebAudio, url, owner, bassobj, id)
end

--[[
	Whitelist handling
]]

-- Match, IsPattern
local function pattern(str) return { str, true } end
local function simple(str) return { string.PatternSafe(str), false } end
local registers = { ["pattern"] = pattern, ["simple"] = simple }

--[[
	Inspired / Taken from StarfallEx & Metastruct/gurl
	No blacklist for now, just don't whitelist anything that has any possible redir routes.

	## Guidelines
	Sites cannot track users / do any scummy shit with your data unless they're a massive corporation that you really can't avoid anyways.
	So don't think about PRing your own website
	Also these have to do with audio since this is an audio based addon.

	## Custom whitelist
		Create a file called webaudio_whitelist.txt in your data folder to overwrite this, works on the server box or on your client.
		Example file might look like this:
		```
		pattern %w+%.sndcdn%.com
		simple translate.google.com
		```
]]--

local Whitelist = {
	-- Soundcloud
	pattern [[[%w-_]+%.sndcdn%.com/.+]],

	-- Bandcamp
	pattern [[[%w-_]+%.bcbits%.com/.+]],

	-- Google Video (used by Youtube)
	pattern [[[%w-_]+%.googlevideo%.com/.+]],

	-- Google Translate Api, Needs an api key.
	simple [[translate.google.com]],

	-- Discord ( Disabled because discord blocked steam http headers :\ )
	-- pattern [[cdn[%w-_]*%.discordapp%.com/.+]],

	-- Reddit
	simple [[i.redditmedia.com]],
	simple [[i.redd.it]],
	simple [[preview.redd.it]],

	-- Shoutcast
	simple [[yp.shoutcast.com]],

	-- Dropbox
	simple [[dl.dropboxusercontent.com]],
	pattern [[%w+%.dl%.dropboxusercontent%.com/(.+)]],
	simple [[dropbox.com]],
	simple [[dl.dropbox.com]],

	-- Github
	simple [[raw.githubusercontent.com]],
	simple [[gist.githubusercontent.com]],
	simple [[raw.github.com]],
	simple [[cloud.githubusercontent.com]],

	-- Steam
	simple [[steamuserimages-a.akamaihd.net]],
	simple [[steamcdn-a.akamaihd.net]],

	-- Gitlab
	simple [[gitlab.com]],

	-- Onedrive
	simple [[onedrive.live.com/redir]],
	simple [[api.onedrive.com]],

	-- ytdl host. Requires 2d mode which we currently don't support.
	simple [[youtubedl.mattjeanes.com]],

	-- MyInstants
	simple [[myinstants.com]],

	-- TTS like moonbase alpha's
	simple [[tts.cyzon.us]],

	-- US Air Traffic Control radio host
	simple [[liveatc.net]],

	-- Star Trek Sounds
	simple [[trekcore.com/audio]],

	-- Broadcastify
	pattern [[broadcastify%.cdnstream1%.com/%d+]],

	-- Google Drive
	simple [[docs.google.com/uc]],
	simple [[drive.google.com/uc]]
}

local OriginalWhitelist = table.Copy(Whitelist)
local CustomWhitelist = false
local LocalWhitelist = {}

if SERVER then
	util.AddNetworkString("wa_sendcwhitelist") -- Receive server whitelist.

	local function sendCustomWhitelist(whitelist, ply)
		net.Start("wa_sendcwhitelist", false)
			if whitelist then
				net.WriteTable(whitelist)
			end
		if ply then
			net.Send(ply)
		else
			net.Broadcast()
		end
	end

	WebAudioStatic.sendCustomWhitelist = sendCustomWhitelist

	hook.Add("PlayerInitialSpawn", "wa_player_whitelist", function(ply)
		if ply:IsBot() then return end
		sendCustomWhitelist(Whitelist, ply)
	end)
elseif CLIENT then
	net.Receive("wa_sendcwhitelist", function(len)
		if len == 0 then
			Whitelist = OriginalWhitelist
			WebAudio.Common.Whitelist = OriginalWhitelist
		else
			Whitelist = net.ReadTable()
			WebAudio.Common.Whitelist = Whitelist
		end
	end)
end


local function loadWhitelist(reloading)
	if file.Exists("webaudio_whitelist.txt", "DATA") then
		CustomWhitelist = true

		local dat = file.Read("webaudio_whitelist.txt", "DATA")
		local new_list, ind = {}, 0

		for line in dat:gmatch("[^\r\n]+") do
			local type, match = line:match("(%w+)%s+(.*)")
			local reg = registers[type]
			if reg then
				ind = ind + 1
				new_list[ind] = reg(match)
			elseif type ~= nil then
				-- Make sure type isn't nil so we ignore empty lines
				warn("Invalid entry type found [\"", type, "\"] in webaudio_whitelist\n")
			end
		end

		notify("Whitelist from webaudio_whitelist.txt found and parsed with %d entries!", ind)
		if SERVER then
			Whitelist = new_list
			WebAudio.Common.Whitelist = new_list
			WebAudio.sendCustomWhitelist(Whitelist)
		else
			LocalWhitelist = new_list
		end
		WebAudio.Common.CustomWhitelist = true
		return true
	elseif reloading then
		notify("Couldn't find your whitelist file! %s", CLIENT and "Make sure to run this on the server if you want to reload the server's whitelist!" or "")
		return false
	end
	return false
end

local function checkWhitelist(wl, relative)
	for _, data in ipairs(wl) do
		local match, is_pattern = data[1], data[2]

		local haystack = is_pattern and relative or (relative:match("(.-)/.*") or relative)
		if haystack:find( "^" .. match .. (is_pattern and "" or "$") ) then
			return true
		end
	end

	return false
end

local function isWhitelistedURL(url)
	if not isstring(url) then return false end
	url = url:Trim()

	local isWhitelisted = hook.Run("WA_IsWhitelistedURL", url)
	if isWhitelisted ~= nil then return isWhitelisted end

	local relative = url:match("^https?://www%.(.*)") or url:match("^https?://(.*)")
	if not relative then return false end

	if CLIENT and CustomWhitelist then
		return checkWhitelist(LocalWhitelist, relative)
	end

	return checkWhitelist(Whitelist, relative)
end

concommand.Add("wa_reload_whitelist", function()
	if not loadWhitelist() then
		Whitelist = OriginalWhitelist
		CustomWhitelist = false
		WebAudio.Common.CustomWhitelist = false
		WebAudio.sendCustomWhitelist()
	end
end, nil, "Reload the whitelist", 0)

concommand.Add("wa_list", function()
	local stream_list, n = {}, 0
	for id, stream in WebAudio.getIterator() do
		local owner = stream.owner
		if IsValid(owner) and owner:IsPlayer() then
			n = n + 1
			---@diagnostic disable-next-line (Emmylua definitions don't cover the Player class well.)
			stream_list[n] = string.format("[%d] %s(%s): '%s'", stream.id, owner:GetName(), owner:SteamID64() or "multirun", stream.url)
		end
	end
	MsgC( White, "---------> WebAudio List <---------\n" )
	if n == 0 then
		MsgC( White, "None!\n")
	else
		MsgC( White, table.concat(stream_list, '\n'), "\n" )
	end
end, nil, "List all currently playing WebAudio streams", 0)

concommand.Add("wa_help", function()
	MsgC( White, "You can get help & report issues on the Github: ", Color_Notify, "https://github.com/Vurv78/WebAudio", White, "\n" )
end, nil, "Get help & report issues on the Github", 0)

if CLIENT then
	local Color_Aqua = Color(60, 240, 220, 255)

	local function DrawOwners()
		for id, stream in WebAudio.getIterator() do
			local owner = stream.owner
			if owner and owner:IsValid() and stream.pos then
				local pos = stream.pos:ToScreen()
				---@diagnostic disable-next-line (Emmylua definitions don't cover the Player class well.)
				local txt = string.format("[%u] %s (%s)", id, owner:GetName(), owner:SteamID64() or "multirun")
				draw.DrawText( txt, "DermaDefault", pos.x, pos.y, Color_Aqua, TEXT_ALIGN_CENTER)
			end
		end
	end

	local Display = false
	concommand.Add("wa_display", function()
		Display = not Display

		if Display then
			hook.Add("HUDPaint", "wa_draw_owners", DrawOwners)
		else
			hook.Remove("HUDPaint", "wa_draw_owners")
		end
	end, nil, "Draw owners of the currently playing WebAudio streams", 0)
end

WebAudioStatic.isWhitelistedURL = isWhitelistedURL

WebAudio.Common = {
	-- Object
	WebAudio = WebAudio,

	-- Common
	warn = warn,
	notify = notify,

	Modify = Modify,
	hasModifyFlag = hasModifyFlag,
	toBinary = toBinary,
	getFlags = getFlags,

	--- Convars

	-- Server
	WAAdminOnly = WAAdminOnly,
	WAMaxStreamsPerUser = WAMaxStreamsPerUser,
	WASCCompat = WASCCompat,

	-- Shared
	WAEnabled = WAEnabled,
	WAMaxVolume = WAMaxVolume,
	WAMaxRadius = WAMaxRadius,
	WAFFTEnabled = WAFFTEnabled,

	-- Client
	WAVerbosity = WAVerbosity,

	-- Whitelist
	loadWhitelist = loadWhitelist,
	CustomWhitelist = CustomWhitelist, -- If we're using a user supplied whitelist.
	Whitelist = Whitelist,
	OriginalWhitelist = OriginalWhitelist
}

loadWhitelist()

AddCSLuaFile("webaudio/receiver.lua")

if CLIENT then
	include("webaudio/receiver.lua")
else
	include("webaudio/interface.lua")
end

return WebAudio.Common
