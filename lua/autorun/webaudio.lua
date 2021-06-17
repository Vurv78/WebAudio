--[[
	Common Stuff
	(part 1)
]]

-- Modification Flags
-- If you ever change a setting of the Interface object, will add one of these flags to it.
-- This will be sent to the client to know what to read in the net message to save networking
local Modify = {
	volume = 0,
	time = 1,
	pos = 2,
	playing = 4,
	playback_rate = 8,
	direction = 16,
	parented = 32,
	radius = 64,
	looping = 128,

	destroyed = 256
}

local function hasModifyFlag(...) return bit.band(...) ~= 0 end

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
local WAMaxStreamsPerUser = CreateConVar("wa_stream_max", "5", FCVAR_REPLICATED, "Max number of streams a player can have at once.", 1)

-- SHARED
local WAEnabled = CreateConVar("wa_enable", "1", FCVAR_ARCHIVE + FCVAR_USERINFO, "Whether webaudio should be enabled to play on your client/server or not.", 0, 1)
local WAMaxVolume = CreateConVar("wa_volume_max", "300", FCVAR_ARCHIVE, "Highest volume a webaudio sound can be played at, in percentage. 200 is 200%. SHARED Convar", 0, 25500)
local WAMaxRadius = CreateConVar("wa_radius_max", "10000", FCVAR_ARCHIVE, "Farthest distance a WebAudio stream can be heard from. Will clamp to this value. SHARED Convar", 0)

local Black = Color(0, 0, 0)
local Color_Warn = Color(243, 71, 41)
local Color_Notify = Color(65, 172, 235)
local White = Color(255, 255, 255)

local function warn(...)
	local msg = string.format(...)
	MsgC(Black, "[", Color_Warn, "WA", Black, "]", White, ": ", msg, "\n")
end

local function notify(...)
	local msg = string.format(...)
	MsgC(Black, "[", Color_Notify, "WA", Black, "]", White, ": ", msg, "\n")
end

if WebAudio then
	if SERVER then
		notify("Reloaded!")
	end
	WebAudio:disassemble()
end

--[[
	OOP
]]

--- Initiate WebAudio struct for both realms
_G.WebAudio = {}
WebAudio.__index = WebAudio

local WebAudioCounter = 0
local WebAudios = setmetatable({}, {
	--__mode = "kv" -- TODO: See why weak kv doesn't work clientside.
})

debug.getregistry()["WebAudio"] = WebAudio

--- Returns whether the WebAudio object is valid and not destroyed.
-- @return boolean If it's Valid
function WebAudio:IsValid()
	return not self.destroyed
end

--- Returns whether the WebAudio object is Null
-- @return boolean Whether it's destroyed/null
function WebAudio:IsDestroyed()
	return self.destroyed
end

--- Destroys a webaudio object and makes it the same (value wise) as WebAudio:getNULL()
-- @param boolean transmit If SERVER, should we transmit the destruction to the client? Default true
function WebAudio:Destroy(transmit)
	if self:IsDestroyed() then return end
	if transmit == nil then transmit = true end

	if CLIENT then
		self.bass:Stop()
	elseif transmit then
		self:AddModify(Modify.destroyed)
		self:Transmit()
	end

	local id = self.id
	for k in next,self do
		self[k] = nil
	end
	self.destroyed = true
	WebAudios[id] = nil

	return true
end

--- Returns time elapsed in URL stream.
-- Time elapsed is calculated on the server using playback rate and playback time.
-- Not perfect for the clients and there will be desync if you pause and unpause constantly.
-- @return number Elapsed time
function WebAudio:GetTimeElapsed()
	return self.stopwatch:GetTime()
end

--- Returns the volume of the object set by SetVolume
-- @return number Volume from 0-1
function WebAudio:GetVolume()
	return self.volume
end

--- Returns the position of the WebAudio object.
-- @return vector? Position of the stream or nil if not set.
function WebAudio:GetPos()
	return self.pos
end

--- Returns the radius of the stream set by SetRadius
-- @return number Radius
function WebAudio:GetRadius()
	return self.radius
end

--- Returns the playtime length of a WebAudio object.
-- @return number Playtime Length
function WebAudio:GetLength()
	return self.length
end

--- Returns the file name of the WebAudio object. Not necessarily always the URL.
-- @return string File name
function WebAudio:GetFileName()
	return self.filename
end

--- Returns the state of the WebAudio object
-- @return number State, See STOPWATCH_* Enums
function WebAudio:GetState()
	return self.stopwatch:GetState()
end

--- Returns whether the webaudio stream is looping (Set by SetLooping.)
-- @return boolean Looping
function WebAudio:GetLooping()
	return self.looping
end

--- Returns whether the stream is parented or not. If it is parented, you won't be able to set it's position.
-- @return boolean Whether it's parented
function WebAudio:IsParented()
	return self.parented
end

-- Static Methods
local WebAudioStatic = {}
-- For consistencies' sake, Static functions will be lowerCamelCase, while object / meta methods will be CamelCase.

--- Returns an unusable WebAudio object that just has the destroyed field set to true.
-- @return webaudio The null stream
function WebAudioStatic:getNULL()
	return setmetatable({ destroyed = true }, WebAudio)
end

-- We have these functions so that maybe we can change the number of bits if we make a convar for the global number of WebAudios. Just a thought.

--- Same as net.ReadUInt but doesn't need the bit length in order to adapt our code more easily.
-- @return number UInt13
function WebAudioStatic:readID()
	return net.ReadUInt(13)
end

--- Same as net.WriteUInt but doesn't need the bit length in order to adapt our code more easily.
-- @param number id UInt13 (max 8191 id)
function WebAudioStatic:writeID(id)
	net.WriteUInt(id, 13)
end

--- Reads a WebAudio Modify enum
-- @return number UInt16
function WebAudioStatic:readModify()
	return net.ReadUInt(10)
end

--- Writes a WebAudio Modify enum
-- @param number UInt16
function WebAudioStatic:writeModify(modify)
	net.WriteUInt(modify, 10)
end

function WebAudioStatic:getFromID(id)
	return WebAudios[id]
end

function WebAudioStatic:getList()
	return WebAudios
end

function WebAudioStatic:getCountActive()
	return WebAudioCounter
end

local function isWebAudio(v)
	if not istable(v) then return end
	return debug.getmetatable(v) == WebAudio
end

function WebAudioStatic:instanceOf(v)
	return isWebAudio(v)
end

--- Reflection sorta
function WebAudioStatic:getStatics()
	return WebAudioStatic
end

--- Used internally. Should be called both server and client as it doesn't send any net messages to destroy the ids to the client.
function WebAudioStatic:disassemble()
	for k, stream in pairs( WebAudio:getList() ) do
		stream:Destroy(not SERVER)
	end
end

-- For now just increment ids, I think it'll be fine this way.
local current_id = 0
local function getID()
	current_id = current_id + 1
	return current_id
end

local function createWebAudio(_, url, owner, bassobj, id)
	assert( WebAudio:isWhitelistedURL(url), "'url' argument must be given a whitelisted url string." )
	-- assert( owner and isentity(owner) and owner:IsPlayer(), "'owner' argument must be a valid player." )
	-- Commenting this out in case someone wants a webaudio object to be owned by the world or something.

	local self = setmetatable({}, WebAudio)

	-- Mutable --
	self.playing = false
	self.destroyed = false

	self.parented = false
	self.parent = nil -- Entity

	self.modified = 0

	self.playback_rate = 1
	self.volume = 1
	self.time = 0
	self.radius = math.min(200, WAMaxRadius:GetInt()) -- Default IGmodAudioChannel radius

	self.pos = nil
	self.direction = Vector()
	self.looping = false
	-- Mutable --

	self.id = id or getID()
	self.url = url
	self.owner = owner

	-- Net vars
	self.needs_info = SERVER -- Whether this stream still needs information from the client.
	self.length = -1
	self.filename = ""

	if CLIENT then
		self.bass = bassobj
		self.parent_pos = Vector() -- Parent pos being nil means we will go directly to the parent's position w/o calculating local pos.
	else
		self.stopwatch = StopWatch(100, function(watch)
			if not watch:GetLooping() then
				self:Pause()
			end
		end)

		self.ignored = RecipientFilter()

		net.Start("wa_create", true)
			WebAudio:writeID(self.id)
			net.WriteString(self.url)
			net.WriteEntity(self.owner)
		self:Broadcast() -- Defined in wa_interface
	end

	WebAudioCounter = WebAudioCounter + 1
	WebAudios[self.id] = self

	return self
end

setmetatable(WebAudio, {
	__index = WebAudioStatic,
	__call = createWebAudio
})

--[[
	Whitelist handling
]]

-- Match, IsPattern
local function pattern(str) return { str, true } end
local function simple(str) return { string.PatternSafe(str), false } end
local registers = { ["pattern"] = pattern, ["simple"] = simple }

-- Inspired / Taken from StarfallEx & Metastruct/gurl
-- No blacklist for now, just don't whitelist anything that has weird other routes.

--- Note #1 (For PR Help)
-- Sites cannot track users / do any scummy shit with your data unless they're a massive corporation that you really can't avoid anyways.
-- So don't think about PRing your own website
-- Also these have to do with audio since this is an audio based addon.

--- Note #2
-- Create a file called webaudio_whitelist.txt in your data folder to overwrite this, works on the server box or on your client.
-- Example file might look like this:
-- ```
-- pattern %w+%.sndcdn%.com
-- simple translate.google.com
-- ```
local Whitelist = {
	-- Soundcloud
	pattern [[%w+%.sndcdn%.com/.+]],

	-- Google Translate Api, Needs an api key.
	simple [[translate.google.com]],

	-- Discord
	pattern [[cdn[%w-_]*%.discordapp%.com/.+]],

	-- Reddit
	simple [[i.redditmedia.com]],
	simple [[i.redd.it]],
	simple [[preview.redd.it]],

	-- Shoutcast
	simple [[yp.shoutcast.com]],

	-- Dropbox
	simple [[dl.dropboxusercontent.com]],
	pattern [[%w+%.dl%.dropboxusercontent%.com/(.+)]],
	simple [[www.dropbox.com]],
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

	-- ytdl host. Requires 2d mode which we currently don't support.
	simple [[youtubedl.mattjeanes.com]]
}

local CustomWhitelist = false

local function loadWhitelist(reloading)
	if file.Exists("webaudio_whitelist.txt", "DATA") then
		CustomWhitelist = true

		local dat = file.Read("webaudio_whitelist.txt", "DATA")
		local new_list, ind = {}, 1

		for line in dat:gmatch("[^\r\n]+") do
			local type, match = line:match("(%w+)%s+(.*)")
			local reg = registers[type]
			if reg then
				new_list[ind] = reg(match)
				ind = ind + 1
			elseif type ~= nil then
				-- Make sure type isn't nil so we ignore empty lines
				warn("Invalid entry type found [\"", type, "\"] in webaudio_whitelist\n")
			end
		end

		notify("Whitelist from webaudio_whitelist.txt found and parsed with %d entries!", ind)
		Whitelist = new_list
	elseif reloading then
		notify("Couldn't find your whitelist file! %s", CLIENT and "Make sure to run this on the server if you want to reload the server's whitelist!" or "")
	end
end

local function isWhitelistedURL(self, url)
	if not isstring(url) then return false end

	local relative = url:match("^https?://(.*)")
	if not relative then return false end

	for _, data in ipairs(Whitelist) do
		local match, is_pattern = data[1], data[2]

		local haystack = is_pattern and relative or (relative:match("(.-)/.*") or relative)
		if haystack:find( "^" .. match .. (is_pattern and "" or "$") ) then
			return true
		end
	end

	return false
end

concommand.Add("wa_reload_whitelist", loadWhitelist)
WebAudioStatic.isWhitelistedURL = isWhitelistedURL

WebAudio.Common = {
	-- Object
	WebAudio = WebAudio,

	-- Common
	warn = warn,
	notify = notify,

	Modify = Modify,
	hasModifyFlag = hasModifyFlag,
	getFlags = getFlags,

	-- Convars
	WAAdminOnly = WAAdminOnly,
	WAMaxStreamsPerUser = WAMaxStreamsPerUser,

	WAEnabled = WAEnabled,
	WAMaxVolume = WAMaxVolume,
	WAMaxRadius = WAMaxRadius,

	-- Whitelist
	loadWhitelist = loadWhitelist,
	CustomWhitelist = CustomWhitelist, -- If we're using a user supplied whitelist.
	Whitelist = Whitelist
}

AddCSLuaFile("webaudio/receiver.lua")

if CLIENT then
	include("webaudio/receiver.lua")
else
	include("webaudio/interface.lua")
end

return WebAudio.Common