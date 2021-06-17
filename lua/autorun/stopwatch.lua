

--[[
	StopWatch/TimerEx Library
	Author: Vurv
	This is an advanced version of gmod's timer library that allows for::
		* Speeding up and Slowing down timers
		* Looping them
		* Getting & Setting the current playback time
		* Pausing/Playing/Restarting them.
	All in a pretty tiny file.
]]

STOPWATCH_STOPPED, STOPWATCH_PLAYING, STOPWATCH_PAUSED = 0, 1, 2

local StopWatch = {}
StopWatch.__index = StopWatch

local timer_now = RealTime

--- Creates a StopWatch.
-- @param number duration How long the stopwatch will last
-- @param function callback What to run when the stopwatch finishes.
local function Initialize(_, duration, fn)
	local self = setmetatable({}, StopWatch)
	self.playback_rate = 1
	self.playback_now = timer_now()
	self.playback_elapsed = 0
	self.playback_duration = duration

	self.delay = duration -- Internal timer delay used in timer.Adjust.
	self.state = STOPWATCH_STOPPED

	local mangled = string.format("stopwatch_%p", self)
	timer.Create(mangled, duration, 1, function()
		if self.looping then
			-- Reset all stats and configure to current playback rate.
			self.playback_now = timer_now()
			self.playback_elapsed = 0
			self.playback_duration = duration
			self.delay = duration
			self:SetRate(self.playback_rate)
		else
			-- Same behavior as :Stop but we already know we hit the end of the timer, so set elapsed to duration.
			self.playback_elapsed = self.playback_duration
			self.state = STOPWATCH_STOPPED
		end
		fn(self)
	end)
	timer.Stop(mangled)

	self.timerid = mangled

	return self
end

setmetatable(StopWatch, {
	__call = Initialize
})

--- Pauses a stopwatch at the current time to be resumed with :Play
function StopWatch:Pause()
	if self.state == STOPWATCH_PLAYING then
		self.state = STOPWATCH_PAUSED
		timer.Pause(self.timerid)
	end
end

--- Resumes the stopwatch after it was paused. You can't :Play a :Stop(ped) timer, use :Start for that.
function StopWatch:Play()
	if self.state == STOPWATCH_PAUSED then
		self.playback_now = timer_now()
		self.state = STOPWATCH_PLAYING
		timer.UnPause(self.timerid)
	end
end

--- Used internally by GetTime, don't use.
function StopWatch:UpdateTime()
	if self.state == STOPWATCH_PLAYING then
		local now = timer_now()
		local elapsed = (now - self.playback_now) * self.playback_rate

		self.playback_elapsed = self.playback_elapsed + elapsed
		self.playback_now = now
	end
end

--- Stops the timer with the stored elapsed time.
-- Continue from here with :Start()
function StopWatch:Stop()
	if self.state ~= STOPWATCH_STOPPED then
		self:UpdateTime()
		self.state = STOPWATCH_STOPPED
		timer.Stop(self.timerid)
	end
end

--- (Re)starts the stopwatch.
function StopWatch:Start()
	if self.state == STOPWATCH_STOPPED then
		self.playback_now = timer_now()
		self.state = STOPWATCH_PLAYING
		timer.Start(self.timerid)
	end
	return self
end

--- Returns the playback duration of the stopwatch.
-- @return number Length
function StopWatch:GetDuration()
	return self.playback_duration
end

--- Returns the playback duration of the stopwatch.
-- @param number duration
-- @return StopWatch self
function StopWatch:SetDuration(duration)
	self.playback_duration = duration
	self.delay = duration
	timer.Adjust( self.timerid, duration )
	if self.playback_elapsed > duration then
		self:Stop()
	end
	return self
end

--- Sets the playback rate / speed of the stopwatch. 2 is twice as fast, etc.
-- @param number n Speed
-- @return StopWatch self
function StopWatch:SetRate(n)
	self:UpdateTime()
	self.playback_rate = n
	-- New Duration - Elapsed
	self.delay = (self.playback_duration / n) - self.playback_elapsed
	timer.Adjust( self.timerid, self.delay )
	return self
end

--- Returns the playback rate of the stopwatch. Default 1
-- @return number Playback rate
function StopWatch:GetRate()
	return self.playback_rate
end

--- Sets the playback time of the stopwatch.
-- @param number n Time
-- @return StopWatch self
function StopWatch:SetTime(n)
	self.playback_now = timer_now()
	self.playback_elapsed = n
	self.delay = (self.playback_duration - n) / self.playback_rate

	timer.Adjust( self.timerid, self.delay )
	return self
end

--- Returns the current playback time in seconds of the stopwatch
-- @return number Playback time
function StopWatch:GetTime()
	self:UpdateTime()
	return self.playback_elapsed
end

--- Returns the current playback state of the stopwatch. 0 for STOPWATCH_STOPPED, 1 for STOPWATCH_PLAYING, 2 for STOPWATCH_PAUSED
-- @return number Playback state
function StopWatch:GetState()
	return self.state
end

--- Sets the stopwatch to loop. Won't call the callback if it is looping.
-- @param boolean loop Whether it's looping
-- @return StopWatch self
function StopWatch:SetLooping(loop)
	if self.looping ~= loop then
		self.looping = loop
		timer.Adjust( self.timerid, self.delay, 0, nil )
	end
	return self
end

--- Returns if the stopwatch is looping
-- @return boolean Looping
function StopWatch:GetLooping()
	return self.looping
end

_G.StopWatch = StopWatch

return StopWatch