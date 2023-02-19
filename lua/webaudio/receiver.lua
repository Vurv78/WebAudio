-- This file assumes ``autorun/webaudio.lua`` ran right before it.

local Common = WebAudio.Common
local wa_warn, wa_notify = Common.warn, Common.notify

local math_min = math.min

-- Convars
local Enabled, FFTEnabled = Common.WAEnabled, Common.WAFFTEnabled
local MaxVolume, MaxRadius = Common.WAMaxVolume, Common.WAMaxRadius
local Verbosity = Common.WAVerbosity

local AwaitingChanges = {}
local updateObject -- To be declared below

net.Receive("wa_fft", function(len)
	local stream = WebAudio.readStream()
	if not stream then return end
	if not FFTEnabled:GetBool() then return end

	local bass = stream.bass
	if not bass then return end
	if bass:GetState() ~= GMOD_CHANNEL_PLAYING then return end

	local t = {}
	local filled = math_min( bass:FFT(t, FFT_256), 128 )
	local samp_len = WebAudio.FFTSAMP_LEN

	net.Start("wa_fft", true)
		WebAudio.writeID(stream.id)
		for k = 2, filled, 2 do
			-- Multiply the small decimal to a number we will floor and write as a UInt.
			-- If the number is smaller, it will be more precise for higher numbers.
			-- If it's larger, it will be more precise for smaller number fft magnitudes.
			local v = math_min(t[k] * 1e4, 255)
			if v < 1 then break end -- Assume the rest of the data is 0.
			net.WriteUInt(v, samp_len)
		end
	net.SendToServer()
end)

timer.Create("wa_think", 100 / 1000, 0, function()
	local LocalPlayer = LocalPlayer()
	if not IsValid(LocalPlayer) then return end

	local player_pos = LocalPlayer:GetPos()
	for id, stream in pairs( WebAudio.getList() ) do
		local bass = stream.bass

		if bass then
			-- Handle Parenting
			local parent, parent_pos = stream.parent, stream.parent_pos
			if IsValid(parent) then
				if parent_pos then
					-- Offset from prop
					local position = parent:LocalToWorld(parent_pos)
					if stream.pos ~= position then
						bass:SetPos( position )
						stream.pos = position
					end
				else
					-- Origin of prop
					local position = parent:GetPos() + parent:GetVelocity() * 0.05
					if stream.pos ~= position then
						bass:SetPos( position )
						stream.pos = position
					end
				end
			end

			-- Manually handle volume as you go farther from the stream.
			if stream.pos then
				local dist_to_stream = player_pos:DistToSqr( stream.pos )

				-- Could also ( 1 - math_min(dist_to_stream / stream.radius, 1) )
				if dist_to_stream > stream.radius_sqr then
					-- Stream is too far away.
					bass:SetVolume( 0 )
				elseif stream.mode == WebAudio.MODE_2D then
					bass:SetVolume( stream.volume )
				elseif dist_to_stream > stream.radius_sqr * 0.5 then
					-- Stream is kinda far, now start smoothing
					bass:SetVolume( stream.volume - ( dist_to_stream / stream.radius_sqr ) * stream.volume * 1.5 + stream.volume / 2 )
				else
					-- Stream is pretty close. Slow smooth
					bass:SetVolume( stream.volume - ( dist_to_stream / stream.radius_sqr ) * stream.volume / 2 )
				end
			end
		end
	end
end)

net.Receive("wa_create", function(len)
	local id, url, owner = WebAudio.readID(), net.ReadString(), net.ReadEntity()
	local verbosity = Verbosity:GetInt()

	if not IsValid(owner) then return end -- Owner left ?

	local warn, notify
	if verbosity >= 2 then
		-- Very verbose (old default)
		warn = wa_warn
		notify = wa_notify
	elseif verbosity >= 1 then
		-- Warnings only (new default)
		warn = wa_warn
		function notify(...) end
	else
		function warn(...) end
		function notify(...) end
	end

	if not Enabled:GetBool() then
		-- Shouldn't happen anymore as net messages won't send to users who have webaudio disabled.
		return notify(
			"%s(%s) attempted to create a WebAudio object with url [%q], but you have WebAudio disabled!",
			owner:Nick(),
			owner:SteamID64() or "multirun",
			url
		)
	end

	if not WebAudio.isWhitelistedURL(url) then
		return warn("User %s(%s) tried to create unwhitelisted WebAudio object with url [%q]", owner:Nick(), owner:SteamID64() or "multirun", url)
	end

	local is_stream_owner = owner == LocalPlayer()

	-- If a stream failed to the point where it wouldn't be able to function for anyone,
	-- Send feedback to the server to destroy the object.
	local function streamFailed() end

	if is_stream_owner then
		function streamFailed()
			net.Start("wa_info", true)
				WebAudio.writeID(id)
				net.WriteBool(true)
			net.SendToServer()
		end
	end

	notify("User %s(%s) created WebAudio object with url [%q]", owner:Nick(), owner:SteamID64() or "multirun", url)

	http.Fetch(url, function(body, size, headers)
		if body:find("#EXTM3U", 1, true) then
			streamFailed()
			return warn("User %s(%s) tried to create WebAudio object with unwhitelisted file format (m3u)", owner:Nick(), owner:SteamID64() or "multirun")
		end

		sound.PlayURL(url, "3d noblock noplay", function(bass, errid, errname)
			if errid then
				streamFailed()
				return warn("Error when creating WebAudio receiver with id %d, Error [%s]", id, errname)
			end

			if not bass:IsValid() then
				streamFailed()
				return warn("WebAudio object with id [%d]'s IGModAudioChannel object was null!", id)
			end

			local self = WebAudio.getFromID(id)
			if not ( self and self:IsValid() ) then
				bass:Stop()
				bass = nil
				streamFailed()

				if is_stream_owner then
					-- Have it only warn for the owner in preparation for #33
					-- Shouldn't be possible right now unless some one sends a destroy net message to a random id with sv lua.
					warn("Invalid WebAudio with id [" .. id .. "], did you destroy it before it even loaded?")
				end
				return
			end

			if bass:IsBlockStreamed() then
				streamFailed()
				bass:Stop()
				bass = nil
				return warn("URL [%s] was incompatible for WebAudio; It is block-streamed!", url)
			end

			self.bass = bass
			self.length = bass:GetLength()
			self.filename = bass:GetFileName()

			local changes_awaiting = AwaitingChanges[id]
			if changes_awaiting then
				updateObject(id, changes_awaiting, true, false)
				AwaitingChanges[id] = nil
			end

			if owner == LocalPlayer() then
				if not self:IsValid() then
					-- It was destroyed inside of AwaitingChanges. Usually some dude spamming it.
					return
				end
				-- Only send WebAudio info if LocalPlayer is the owner of the WebAudio object. Will also check on server to avoid abuse.
				net.Start("wa_info", true)
					WebAudio.writeID(id)
					net.WriteBool(false)
					local continuous = self.length < 0
					net.WriteBool(continuous) -- If the stream is continuous, it should return something less than 0.
					if not continuous then
						net.WriteUInt(self.length, 16)
					end
					net.WriteString(self.filename)
				net.SendToServer()
			end
		end)
	end, function(err)
		streamFailed()
		return warn("HTTP error when creating WebAudio receiver with id %d, Error [%q]", id, err)
	end)

	WebAudio.new(url, owner, nil, id) -- Register object
end)

local Modify = Common.Modify
local hasModifyFlag = Common.hasModifyFlag

--- Stores changes on the Receiver object
--- @param id number ID of the Receiver Object, to be used to search the table of 'WebAudio.getList()'
--- @param modify_enum number Mixed bitwise flag that will be sent by the server to determine what changed in an object to avoid wasting a lot of bits for every piece of information.
--- @param handle_bass boolean Whether this object has a 'bass' object. If so, we can just immediately apply the changes to the object.
--- @param inside_net boolean Whether this function is inside the net message that contains the new information. If not, we're most likely just applying object changes to the receiver after waiting for the IGmodAudioChannel object to be created.
function updateObject(id, modify_enum, handle_bass, inside_net)
	-- Object destroyed
	local self = WebAudio.getFromID(id)
	local bass = self.bass

	-- Keep in mind that the order of these needs to sync with wa_interface's reading order.
	if hasModifyFlag(modify_enum, Modify.destroyed) then
		-- Don't destroy until we have the bass object.
		if handle_bass then
			self:Destroy(false)
			self = nil
		end
		return
	end

	-- Volume changed
	if hasModifyFlag(modify_enum, Modify.volume) then
		if inside_net then self.volume = math_min(net.ReadFloat(), MaxVolume:GetInt() / 100) end
		if handle_bass then
			bass:SetVolume(self.volume)
		end
	end

	-- Playback time changed
	if hasModifyFlag(modify_enum, Modify.time) then
		if inside_net then self.time = net.ReadUInt(16) end
		if handle_bass then
			bass:SetTime(self.time) -- 18 hours max, if you need more, wtf..
		end
	end

	-- 3D Position changed
	if hasModifyFlag(modify_enum, Modify.pos) then
		if inside_net then self.pos = net.ReadVector() end
		if handle_bass then
			bass:SetPos(self.pos, nil)
		end
	end

	-- Direction changed.
	if hasModifyFlag(modify_enum, Modify.direction) then
		if inside_net then self.direction = net.ReadVector() end
		if handle_bass then
			bass:SetPos(self.pos, self.direction)
		end
	end

	-- Playback rate changed
	if hasModifyFlag(modify_enum, Modify.playback_rate) then
		if inside_net then self.playback_rate = net.ReadFloat() end
		if handle_bass then
			bass:SetPlaybackRate(self.playback_rate)
		end
	end

	-- Radius changed
	if hasModifyFlag(modify_enum, Modify.radius) then
		if inside_net then
			self.radius = math_min(net.ReadUInt(16), MaxRadius:GetInt())
			self.radius_sqr = self.radius * self.radius
		end

		if handle_bass and self.pos then
			local dist_to_stream = LocalPlayer():GetPos():Distance( self.pos )
			bass:SetVolume( self.volume * ( 1 - math_min(dist_to_stream / self.radius, 1) ) )
		end
	end

	if hasModifyFlag(modify_enum, Modify.looping) then
		if inside_net then self.looping = net.ReadBool() end
		if handle_bass then
			bass:EnableLooping(self.looping)
		end
	end

	if hasModifyFlag(modify_enum, Modify.mode) then
		if inside_net then self.mode = net.ReadBit() end
		if handle_bass then
			bass:Set3DEnabled(self.mode == WebAudio.MODE_3D)
		end
	end

	-- Was parented or unparented
	if hasModifyFlag(modify_enum, Modify.parented) then
		if inside_net then
			self.parented = net.ReadBool()
			if self.parented then
				local ent = net.ReadEntity()
				self.parent = ent
				if self.pos ~= nil then
					-- We've initialized and received a changed position before
					self.parent_pos = ent:WorldToLocal(self.pos)
				else
					-- self.pos hasn't been touched, play the sound at the entity's position.
					self.parent_pos = nil
				end
			else
				self.parent = nil
			end
		end

		if handle_bass and self.parented then
			---@type GEntity (Absolutely sure it is parented)
			local parent = self.parent
			if IsValid(parent) then
				local parent_pos = self.parent_pos
				local position = parent_pos and parent:LocalToWorld(parent_pos) or parent:GetPos()
				bass:SetPos(position, nil)
				self.pos = position
			end
		end
	end

	-- Playing / Paused state changed. Should always be at the bottom here
	if hasModifyFlag(modify_enum, Modify.playing) then
		if inside_net then self.playing = net.ReadBool() end
		-- Should always be true so..
		if handle_bass then
			if self.playing then
				-- If changed to be playing, play. Else pause
				bass:Play()
			else
				bass:Pause()
			end
		end
	end
end

net.Receive("wa_change", function(len)
	local id, modify_enum = WebAudio.readID(), WebAudio.readModify()
	local obj = WebAudio.getFromID(id)

	if AwaitingChanges[id] == modify_enum then return end
	if not obj then return end -- Object was destroyed on the client for whatever reason. Most likely reason is wa_purge

	if obj.bass then
		-- Store and handle changes
		updateObject(id, modify_enum, true, true)
	else
		-- We don't have the bass object yet. Store the changes to update the object with later.
		AwaitingChanges[id] = modify_enum
		updateObject(id, modify_enum, false, true)
	end
end)

--- Stops every currently existing stream
--- @param write_ids boolean Whether to net write IDs or not while looping through the streams. Used for wa_ignore.
local function stopStreams(write_ids)
	for id, stream in WebAudio.getIterator() do
		if stream then
			stream:Destroy()
			if write_ids then
				-- If we are in wa_purge
				WebAudio.writeID(id)
			end
		end
	end
end

concommand.Add("wa_purge", function()
	local stream_count = WebAudio.getCountActive()
	if stream_count == 0 then return end

	net.Start("wa_ignore", true)
		net.WriteUInt(stream_count, 8)
		stopStreams(true)
	net.SendToServer()
end, nil, "Purges all of the currently playing WebAudio streams", 0)

cvars.RemoveChangeCallback("wa_enable", "wa_enable")

--- When the client toggles wa_enable send this info to the server to stop sending net messages to them.
cvars.AddChangeCallback("wa_enable", function(convar, old, new)
	local enabled = new ~= "0"
	if not enabled then
		stopStreams(false)
	end
	net.Start("wa_enable", true)
		net.WriteBool(enabled) -- Tell the server to subscribe/unsubscribe us from net messages
	net.SendToServer()
end, "wa_enable")