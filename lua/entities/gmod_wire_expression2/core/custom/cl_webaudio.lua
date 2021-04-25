

local tbl = E2Helper.Descriptions
local function desc(name, description)
    tbl[name] = description
end

desc("webAudio(s)", "Creates and returns WebAudio type")
desc("webAudiosLeft()", "Returns the number of WebAudio objects you can create in total for your player")
desc("webAudioCanCreate()", "Returns whether you can create a WebAudio object. Only returns if the cooldown is done to create an object, use in conjunction with webAudiosLeft.")

-- Permissions
desc("webAudioEnabled()", "Returns whether WebAudio playing is enabled on the server for E2")
desc("webAudioAdminOnly()", "Returns whether WebAudio playing is restricted to admins or super admins. 0 for everyone, 1 for admins, 2 for superadmins")

-- WebAudio Methods
desc("setDirection(wxa:v)", "Sets the direction in which the WebAudio stream is playing towards without updating it. Remember to call ``self:update()`` when you are done modifying the object!")
desc("setPos(xwa:v)", "Sets the 3D Position of the WebAudio stream without updating it. Remember to call ``self:update()`` when you are done modifying the object!")
desc("setVolume(xwa:n)", "Sets the volume of the WebAudio stream, in percent format. 200 is 2x as loud as normal, 100 is default. Will error if it is past ``wa_volume_max``")
desc("setTime(xwa:n)", "Sets the time in which the WebAudio stream should seek to in playing the URL.")
desc("setPlaybackRate(xwa:n)", "Sets the playback speed of a webaudio stream. 2 is twice as fast, 0.5 being half, etc.")
desc("pause(xwa:)", "Pauses the stream where it is currently playing, Returns 1 or 0 if could successfully do so, because of quota. Automatically calls updates self internally.")
desc("play(xwa:)", "Starts the stream or continues where it left off after pausing, Returns 1 or 0 if could successfully do so from quota. Automatically updates self internally.")
desc("destroy(xwa:)", "Destroys the WebAudio object, rendering it useless. It will silently fail when trying to use it from here on! This gives you another slot to make a WebAudio object")
desc("update(xwa:)", "Updates and sends all of the new information changed about the WebAudio to the client. You need to call this when updating a WebAudio stream without playing or pausing it!")
