-- This file assumes ``autorun/webaudio.lua`` ran right before it.

local Common = WebAudio.Common
local Modify = Common.Modify

util.AddNetworkString("wa_create") -- To send to the client to create a Clientside WebAudio struct
util.AddNetworkString("wa_change") -- To send to the client to modify Client WebAudio structs
util.AddNetworkString("wa_ignore") -- To receive from the client to make sure to ignore players to send to in WebAudio transmissions
util.AddNetworkString("wa_enable") -- To receive from the client to make sure people with wa_enable 0 don't get WebAudio transmissions
util.AddNetworkString("wa_info") -- To receive information about BASS / IGmodAudioChannel streams from clients that create them.

local WebAudio = Common.WebAudio

-- TODO: Make this table + hash table version cancer an object or just do this another way. I'm not sure how to do it.
-- I would use a CRecipientFilter but I also need to add the people with wa_enable to 0 rather than just the people who used wa_purge to kill certain objects.
-- If you could merge two CRecipientFilters that'd be cool
local StreamDisabledPlayers = { -- People who have wa_enabled set to 0
	__hash = {},
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
-- @param number n Float Volume (1 is 100%, 2 is 200% ..)
-- @return boolean Whether volume was set. Will return nil if stream is destroyed or n is not number
function WebAudio:SetVolume(n)
	if self:IsDestroyed() then return end
	if isnumber(n) then
		self.volume = n
		self:AddModify(Modify.volume)
	end
end

--- Sets the current playback time of the stream.
-- Does not transmit
-- @param number time UInt16 Playback time
-- @return boolean Whether playback time was successfully set. Will return nil if stream is destroyed or time is not number
function WebAudio:SetTime(time)
	if self:IsDestroyed() then return end
	if isnumber(time) then
		self.time = time

		self.stopwatch:SetTime(time)

		self:AddModify(Modify.time)
	end
end

--- Sets the position of the stream.
-- @param Vector v Position
-- @return boolean Whether the position was set. Will return nil if stream is destroyed, v is not vector, or if the stream is parented.
function WebAudio:SetPos(v)
	if self:IsDestroyed() then return end
	if self:IsParented() then return end
	if isvector(v) then
		self.pos = v
		self:AddModify(Modify.pos)
	end
end

--- Sets the direction in which the stream will play
-- @param Vector dir Direction to set to
-- @return boolean Whether the direction was successfully set. Will return nil if stream is destroyed or dir is not vector.
function WebAudio:SetDirection(dir)
	if self:IsDestroyed() then return end
	if isvector(dir) then
		self.direction = dir
		self:AddModify(Modify.direction)
		return true
	end
end

--- Resumes or starts the stream.
-- @return boolean Successfully played, will return nil if the stream is destroyed
function WebAudio:Play()
	if self:IsDestroyed() then return end
	self:AddModify(Modify.playing)
	self.playing = true
	self:Transmit()

	return true
end

--- Pauses the stream and automatically transmits.
-- @return boolean Successfully paused, will return nil if the stream is destroyed
function WebAudio:Pause()
	if self:IsDestroyed() then return end
	self:AddModify(Modify.playing)
	self.playing = false
	self:Transmit()

	return true
end

--- Sets the playback rate of the stream.
-- @param number rate Playback rate. Float64 that clamps to 255.
-- @return boolean Successfully set rate, will return false if rate is not a number or if the stream is destroyed
function WebAudio:SetPlaybackRate(rate)
	if self:IsDestroyed() then return end
	if isnumber(rate) then
		rate = math.min(rate, 255)
		self.stopwatch:SetRate(rate)

		self.playback_rate = rate
		self:AddModify(Modify.playback_rate)
		return true
	end
end

--- Sets the radius of the stream. Uses Set3DFadeDistance internally.
-- @param number radius UInt16 radius
-- @return boolean Successfully set radius, will return false if radius is not a number or if the stream is destroyed
function WebAudio:SetRadius(radius)
	if self:IsDestroyed() then return end
	if isnumber(radius) then
		self.radius = radius
		self:AddModify(Modify.radius)
		return true
	end
end

--- Returns whether the stream is parented or not. If it is parented, you won't be able to set it's position.
-- @return boolean Whether it's parented
function WebAudio:IsParented()
	return self.parented
end

--- Sets the parent of the WebAudio object. Nil to unparent
-- @param entity? parent Entity to parent to or nil to unparent.
-- @return boolean Whether it was successfully destroyed. Returns false if it was already destroyed.
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

local hasModifyFlag = Common.hasModifyFlag
--- Transmits all stored data on the server about the WebAudio object to the clients
-- @return boolean If successfully transmitted.
function WebAudio:Transmit()
	if self:IsDestroyed() then return end
	net.Start("wa_change", true)
		-- Always present values
		WebAudio:writeID(self.id)
		local modified = self.modified
		WebAudio:writeModify(modified)

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
-- Does not broadcast to people who have destroyed the object on their client
-- Does not broadcast to people with wa_enable set to 0.
function WebAudio:Broadcast()
	net.SendOmit( table.Add(self.ignored:GetPlayers(), StreamDisabledPlayers.__net) )
end

--- Returns time elapsed in URL stream.
-- Time elapsed is calculated on the server using playback rate and playback time.
-- Not perfect for the clients and there will be desync if you pause and unpause constantly.
-- @return number Elapsed time
function WebAudio:GetTimeElapsed()
	return self.stopwatch:GetTime()
end

--- Client paired getters

--- Returns the playtime length of a WebAudio object.
-- @return number Playtime Length
function WebAudio:GetLength()
	return self.i_length
end

--- Returns the file name of the WebAudio object. Not necessarily always the URL.
-- @return string File name
function WebAudio:GetFileName()
	return self.i_filename
end

--- Returns the state of the WebAudio object
-- @return number State, See STOPWATCH_* Enums
function WebAudio:GetState()
	return self.stopwatch:GetState()
end

--- Returns the volume of the object set by SetVolume
-- @return number Volume from 0-1
function WebAudio:GetVolume()
	return self.volume
end

--- Returns the radius of the stream set by SetRadius
-- @return number Radius
function WebAudio:GetRadius()
	return self.radius
end

--- Stop sending net messages to players who want to ignore certain streams.
net.Receive("wa_ignore", function(len, ply)
	if WebAudio:isSubscribed(ply) == false then return end -- They already have wa_enable set to 0
	local n_ignores = net.ReadUInt(8)
	for k = 1, n_ignores do
		local stream = WebAudio:getFromID(WebAudio:readID())
		if stream then
			stream:Unsubscribe(ply)
		end -- Doesn't exist anymore, maybe got removed when the net message was sending
	end
end)

--- This receives net messages when the SERVER wants information about a webaudio stream you created.
-- It gets stuff like average bitrate and length of the song this way.
-- You'll only be affecting your own streams and chip, so there's no point in "abusing" this.
net.Receive("wa_info", function(len, ply)
	local id = WebAudio:readID()
	local stream = WebAudio:getFromID(id)
	if stream and stream.needs_info and stream.owner == ply then
		-- Make sure the stream exists, hasn't already received client info & That the net message sender is the owner of the WebAudio object.
		local length = net.ReadUInt(16)
		local file_name = net.ReadString()
		stream.i_length = length
		stream.i_filename = file_name
		stream.needs_info = false

		local watch = stream.stopwatch
		watch:SetDuration(length)
		watch:SetRate(stream.playback_rate)
		watch:SetTime(stream.time)
		watch:Start()
	end
end)

net.Receive("wa_enable", function(len, ply)
	local enabled = net.ReadBool()
	print("wa_enable", ply, enabled)
	if enabled then
		WebAudio:subscribe(ply)
	else
		WebAudio:unsubscribe(ply)
	end
end)

hook.Add("PlayerDisconnected", "wa_player_cleanup", function(ply)
	if ply:IsBot() then return end
	table.RemoveByValue(StreamDisabledPlayers, ply)
end)

hook.Add("PlayerInitialSpawn", "wa_player_init", function(ply, transition)
	if ply:IsBot() then return end

	if ply:GetInfoNum("wa_enable", 1) == 0 then
		WebAudio:unsubscribe(ply)
	end
end)

local WebAudioStatic = WebAudio:getStatics()

--- Unsubscribe a player from receiving WebAudio net messages
-- Like the non-static method but for all future Streams & Messages
-- @param Player ply Player to check
function WebAudioStatic:unsubscribe(ply)
	if WebAudio:isSubscribed(ply) then
		StreamDisabledPlayers.__hash[ply] = false
		table.insert(StreamDisabledPlayers.__net, ply)
	end
end

--- Resubscribe a player to receive WebAudio net messages
-- @param Player ply Player to subscribe
function WebAudioStatic:subscribe(ply)
	if not WebAudio:isSubscribed(ply) then
		StreamDisabledPlayers.__hash[ply] = true
		table.RemoveByValue(StreamDisabledPlayers.__net, ply)
	end
end

--- Returns whether the player is subscribed to receive WebAudio net messages or not.
-- @param Player ply Player to check
-- @return boolean If the player is subscribed.
function WebAudioStatic:isSubscribed(ply)
	return (not StreamDisabledPlayers.__hash[ply])
end