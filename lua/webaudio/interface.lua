-- This file assumes ``autorun/webaudio.lua`` ran right before it.

local Common = _G.WebAudio.Common
local Modify = Common.Modify

--- Object networking
util.AddNetworkString("wa_create") -- To send to the client to create a Clientside WebAudio struct
util.AddNetworkString("wa_change") -- To send to the client to modify Client WebAudio structs
util.AddNetworkString("wa_ignore") -- To receive from the client to make sure to ignore players to send to in WebAudio transmissions
util.AddNetworkString("wa_enable") -- To receive from the client to make sure people with wa_enable 0 don't get WebAudio transmissions
util.AddNetworkString("wa_info") -- To receive information about BASS / IGmodAudioChannel streams from clients that create them.
util.AddNetworkString("wa_fft") -- Receive fft data.

local WebAudio = Common.WebAudio

--- TODO: Make this nicer?
-- I would use a CRecipientFilter but I also need to add the people with wa_enable to 0 rather than just the people who used wa_purge to kill certain objects.
-- If you could merge two CRecipientFilters that'd be cool.
local StreamDisabledPlayers = { -- People who have wa_enabled set to 0
	__hash = {}, -- If __hash[ply] is false, the player is already subscribed. We use this to not add multiple players and get the subbed status
	__net = {} -- Net friendly array
}

--- Adds a modify flag to the payload to be sent on transmission
-- @param number n Modify flag from the Modify struct in wa_common
-- @return boolean Whether it modified. Will return nil if stream is destroyed.
function WebAudio:AddModify(n)
	if self:IsDestroyed() then return end
	self.modified = bit.bor(self.modified, n)
end

--- Sets the volume of the stream
-- Does not transmit
-- @param number vol Float Volume (1 is 100%, 2 is 200% ..)
-- @return boolean Successfully set time, will return nil if stream or 'vol' are invalid or 'vol' didn't change.
function WebAudio:SetVolume(vol)
	if self:IsDestroyed() then return end
	if isnumber(vol) and self.volume ~= vol then
		self.volume = vol
		self:AddModify(Modify.volume)
		return true
	end
end

--- Sets the current playback time of the stream.
-- Does not transmit
-- @param number time UInt16 Playback time
-- @return boolean Successfully set time, will return nil if stream is invalid.
function WebAudio:SetTime(time)
	if self:IsDestroyed() then return end
	if isnumber(time) then
		self.time = time
		self.stopwatch:SetTime(time)
		self:AddModify(Modify.time)
		return true
	end
end

--- Sets the position of the stream.
-- @param Vector pos Position
-- @return boolean Successfully set position, will return nil if stream or 'pos' are invalid or if 'pos' didn't change.
function WebAudio:SetPos(pos)
	if self:IsDestroyed() then return end
	if self:IsParented() then return end
	if isvector(pos) and self.pos ~= pos then
		self.pos = pos
		self:AddModify(Modify.pos)
		return true
	end
end

--- Sets the direction in which the stream will play
-- @param Vector dir Direction to set to
-- @return boolean Successfully set direction, will return nil if stream or 'dir' are invalid or if 'dir' didn't change.
function WebAudio:SetDirection(dir)
	if self:IsDestroyed() then return end
	if isvector(dir) and self.direction ~= dir then
		self.direction = dir
		self:AddModify(Modify.direction)
		return true
	end
end

--- Resumes or starts the stream.
-- @return boolean Successfully played, will return nil if the stream is destroyed or if already playing
function WebAudio:Play()
	if self:IsDestroyed() then return end

	if self.playing == false then
		self:AddModify(Modify.playing)
		self.playing = true
		self:Transmit()
		return true
	end
end

--- Pauses the stream and automatically transmits.
-- @return boolean Successfully paused, will return nil if the stream is destroyed or if already paused
function WebAudio:Pause()
	if self:IsDestroyed() then return end

	if self.playing then
		self:AddModify(Modify.playing)
		self.playing = false
		self:Transmit()

		return true
	end
end

--- Sets the playback rate of the stream.
-- @param number rate Playback rate. Float64 that clamps to 255.
-- @return boolean Successfully set rate, will return nil if stream or 'rate' are invalid or if 'rate' didn't change.
function WebAudio:SetPlaybackRate(rate)
	if self:IsDestroyed() then return end
	if not isnumber(rate) then return end

	rate = math.min(rate, 255)
	if self.playback_rate ~= rate then
		self.stopwatch:SetRate(rate)

		self.playback_rate = rate
		self:AddModify(Modify.playback_rate)
		return true
	end
end

--- Sets the radius of the stream. Uses Set3DFadeDistance internally.
-- @param number radius UInt16 radius
-- @return boolean Successfully set radius, will return nil if the stream or 'radius' are invalid or if radius didn't change.
function WebAudio:SetRadius(radius)
	if self:IsDestroyed() then return end
	if isnumber(radius) and self.radius ~= radius then
		self.radius = radius
		self:AddModify(Modify.radius)
		return true
	end
end

--- Sets the parent of the WebAudio object. Nil to unparent
-- @param entity? parent Entity to parent to or nil to unparent.
-- @return boolean Whether it was successfully parented. Returns nil if the stream is invalid.
function WebAudio:SetParent(ent)
	if self:IsDestroyed() then return end
	if isentity(ent) and ent:IsValid() then
		self.parented = true
		self.parent = ent
	else
		self.parented = false
		self.parent = nil
	end
	self:AddModify(Modify.parented)
	return true
end

--- Makes the stream loop or stop looping.
-- @param boolean loop Whether it should be looping
-- @return boolean If we set the value or not. Returns nil if the stream isn't valid or if the value didn't change.
function WebAudio:SetLooping(loop)
	if self:IsDestroyed() then return end
	if self.looping ~= loop then
		self.stopwatch:SetLooping(loop)
		self.looping = loop
		self:AddModify(Modify.looping)
		return true
	end
end

local LastUpdates = setmetatable({}, {
	__mode = "k"
})

--- Returns the fast fourier transform of the webaudio stream.
-- Returns nil if invalid.
-- @param boolean update Whether to update the fft values.
-- @return table FFT
function WebAudio:GetFFT(update, cooldown)
	if self:IsDestroyed() then return end
	if update and IsValid(self.owner) then
		if cooldown then
			local now = SysTime()
			local last = LastUpdates[self] or 0
			if now - last > cooldown then
				LastUpdates[self] = now
			else
				return self.fft
			end
		end
		net.Start("wa_fft", true)
			WebAudio.writeID( self.id )
		net.Send(self.owner)
	end
	return self.fft
end

local hasModifyFlag = Common.hasModifyFlag
--- Transmits all stored data on the server about the WebAudio object to the clients
-- @return boolean If successfully transmitted.
function WebAudio:Transmit()
	if self:IsDestroyed() then return end
	net.Start("wa_change", true)
		-- Always present values
		WebAudio.writeID(self.id)
		local modified = self.modified
		WebAudio.writeModify(modified)

		if not hasModifyFlag(modified, Modify.destroyed) then
			if hasModifyFlag(modified, Modify.volume) then
				net.WriteFloat(self.volume)
			end

			if hasModifyFlag(modified, Modify.time) then
				net.WriteUInt(self.time, 16)
			end

			if hasModifyFlag(modified, Modify.pos) then
				net.WriteVector(self.pos)
			end

			if hasModifyFlag(modified, Modify.direction) then
				net.WriteVector(self.direction)
			end

			if hasModifyFlag(modified, Modify.playback_rate) then
				net.WriteFloat(self.playback_rate)
			end

			if hasModifyFlag(modified, Modify.radius) then
				net.WriteUInt(self.radius, 16)
			end

			if hasModifyFlag(modified, Modify.looping) then
				net.WriteBool(self.looping)
			end

			if hasModifyFlag(modified, Modify.parented) then
				net.WriteBool(self.parented)
				if self.parented then
					net.WriteEntity(self.parent)
				end
			end

			if hasModifyFlag(modified, Modify.playing) then
				net.WriteBool(self.playing)
			end
		end
	self:Broadcast()
	self.modified = 0 -- Reset any modifications
	return true
end

--- Registers an object to not send any net messages to from WebAudio transmissions.
-- This is called by clientside destruction.
-- @param Player ply The player to stop sending net messages to
function WebAudio:Unsubscribe(ply)
	self.ignored:AddPlayer(ply)
end

--- Registers an object to send net messages to a chip after calling Unsubscribe on it.
-- @param Player ply The player to register to get messages again
function WebAudio:Subscribe(ply)
	self.ignored:RemovePlayer(ply)
end

--- Runs net.SendOmit for you, just broadcasts the webaudio to all players with the object enabled.
-- Does ❌ broadcast to people who have destroyed the object on their client
-- Does ❌ broadcast to people with wa_enable set to 0
function WebAudio:Broadcast()
	-- Todo: Manually build this table because table.Add here is pretty bad for perf
	net.SendOmit( table.Add(self.ignored:GetPlayers(), StreamDisabledPlayers.__net) )
end

--- Stop sending net messages to players who want to ignore certain streams.
net.Receive("wa_ignore", function(len, ply)
	if WebAudio.isSubscribed(ply) == false then return end -- They already have wa_enable set to 0
	local n_ignores = net.ReadUInt(8)
	for k = 1, n_ignores do
		local stream = WebAudio.readStream()
		if stream then
			stream:Unsubscribe(ply)
		end -- Doesn't exist anymore, maybe got removed when the net message was sending
	end
end)

--- This receives net messages when the SERVER wants information about a webaudio stream you created.
-- It gets stuff like average bitrate and length of the song this way.
-- You'll only be affecting your own streams and chip, so there's no point in "abusing" this.
net.Receive("wa_info", function(len, ply)
	local stream = WebAudio.readStream()
	if stream and stream.needs_info and stream.owner == ply then
		-- Make sure the stream exists, hasn't already received client info & That the net message sender is the owner of the WebAudio object.
		if net.ReadBool() then
			-- Failed to create. Doesn't support 3d, or is block streamed.
			stream:Destroy()
		else
			local length = net.ReadUInt(16)
			local file_name = net.ReadString()
			stream.length = length
			stream.filename = file_name
			stream.needs_info = false

			local watch = stream.stopwatch
			watch:SetDuration(length)
			watch:SetRate(stream.playback_rate)
			watch:SetTime(stream.time)
			watch:Start()
		end
	end
end)

net.Receive("wa_enable", function(len, ply)
	if net.ReadBool() then
		WebAudio.subscribe(ply)
	else
		WebAudio.unsubscribe(ply)
	end
end)


-- FFT will be an array of UInts (check FFTSAMP_LEN). It may not be fully filled to 64 samples, some may be nil to conserve bandwidth. Keep this in mind.
-- We don't have to care for E2 since e2 automatically gives you 0 instead of nil or an error.
net.Receive("wa_fft", function(len, ply)
	local stream = WebAudio.readStream()

	if stream and stream.owner == ply then
		local samp_len = WebAudio.FFTSAMP_LEN
		local samples = (len - WebAudio.ID_LEN) / samp_len
		local t = stream.fft
		for i = 1, 64 do
			t[i] = i > samples and 0 or net.ReadUInt(samp_len)
		end
	end
end)

hook.Add("PlayerDisconnected", "wa_player_cleanup", function(ply)
	if ply:IsBot() then return end
	table.RemoveByValue(StreamDisabledPlayers.__net, ply)
	StreamDisabledPlayers.__hash[ply] = nil
end)

hook.Add("PlayerInitialSpawn", "wa_player_init", function(ply, transition)
	if ply:IsBot() then return end

	if ply:GetInfoNum("wa_enable", 1) == 0 then
		WebAudio.unsubscribe(ply)
	end
end)

local WebAudioStatic = WebAudio.getStatics()

--- Unsubscribe a player from receiving WebAudio net messages
-- Like the non-static method but for all future Streams & Messages
-- @param Player ply Player to check
function WebAudioStatic.unsubscribe(ply)
	if WebAudio.isSubscribed(ply) then
		StreamDisabledPlayers.__hash[ply] = true
		table.insert(StreamDisabledPlayers.__net, ply)
	end
end

--- Resubscribe a player to receive WebAudio net messages
-- @param Player ply Player to subscribe
function WebAudioStatic.subscribe(ply)
	if not WebAudio.isSubscribed(ply) then
		StreamDisabledPlayers.__hash[ply] = false
		table.RemoveByValue(StreamDisabledPlayers.__net, ply)
	end
end

--- Returns whether the player is subscribed to receive WebAudio net messages or not.
-- @param Player ply Player to check
-- @return boolean If the player is subscribed.
function WebAudioStatic.isSubscribed(ply)
	return not StreamDisabledPlayers.__hash[ply]
end