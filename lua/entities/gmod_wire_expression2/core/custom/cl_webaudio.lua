

local tbl = E2Helper.Descriptions
local function desc(name, description)
    tbl[name] = description
end

desc("update(xwa:)", "Updates and sends all of the new information changed about the WebAudio to the client. You need to call this whenever you change something like position or volume!")
desc("setPos(xwa:v)", "Sets the 3D Position of the WebAudio stream")
desc("setVolume(xwa:n)", "Sets the volume of the Stream, in percent format. 200 is 2x as loud as normal, 100 is default.")
desc("setTime(xwa:n)", "Sets the current time of the stream to play at in the audio file.")
desc("setPlaybackRate(xwa:n)", "Sets the playback speed of a webaudio stream. 2 is twice as fast, etc.")
desc("createWebAudio(s)", "Creates and returns WebAudio type")
desc("webAudiosLeft()", "Returns the number of WebAudio objects you can create in total for your player")
desc("canCreateWebAudio()", "Returns whether you can create a WebAudio object. Only returns if the cooldown is done to create an object, use in conjunction with webAudiosLeft.")