

local tbl = E2Helper.Descriptions
local function desc(name, description)
    tbl[name] = description
end

desc("webAudio(s)", "Returns a WebAudio object of that URL as long as it is whitelisted by the server. Has a 150 ms cooldown between calls. If you can't create a webAudio object, will error, so check webAudioCanCreate before calling this!")
desc("webAudiosLeft()", "Returns the number of WebAudio objects you can create in total for your player")
desc("webAudioCanCreate()", "Returns whether you can create a WebAudio object. Checks cooldown and whether you have another slot for a webaudio stream left.")
desc("webAudioCanCreate(s)", "Same as webAudioCanCreate() but also checks if a URL is whitelisted on the server to use.")

--- Misc
desc("nowebaudio()", "Returns an invalid webaudio object")

--- Permissions
desc("webAudioEnabled()", "Returns whether WebAudio playing is enabled on the server for E2")
desc("webAudioAdminOnly()", "Returns whether WebAudio playing is restricted to admins or super admins. 0 for everyone, 1 for admins, 2 for superadmins")

--- WebAudio Methods
desc("update(xwa:)", "Sends all of the information of the object given by functions like setPos and setTime to the client. You need to call this after running functions without running ``:play()`` or ``:pause()`` on them since those sync with the client. Returns 1 if could update, 0 if hit transmission quota")
desc("destroy(xwa:)", "Destroys the WebAudio object, rendering it useless. It will silently fail when trying to use it from here on! This gives you another slot to make a WebAudio object. Check if an object is destroyed with isValid!")

-- Modify Object
desc("setDirection(wxa:v)", "Sets the direction in which the WebAudio stream is playing towards without updating it. Remember to call ``self:update()`` when you are done modifying the object!")
desc("setPos(xwa:v)", "Sets the 3D Position of the WebAudio stream without updating it. Remember to call ``self:update()`` when you are done modifying the object!")
desc("setVolume(xwa:n)", "Sets the volume of the WebAudio stream, in percent format. 200 is 2x as loud as normal, 100 is default. Will error if it is past ``wa_volume_max``")
desc("setTime(xwa:n)", "Sets the time in which the WebAudio stream should seek to in playing the URL.")
desc("setPlaybackRate(xwa:n)", "Sets the playback speed of a webaudio stream. 2 is twice as fast, 0.5 being half, etc.")
desc("pause(xwa:)", "Pauses the stream where it is currently playing, Returns 1 or 0 if could successfully do so, because of quota. Automatically calls updates self internally.")
desc("play(xwa:)", "Starts the stream or continues where it left off after pausing, Returns 1 or 0 if could successfully do so from quota. Automatically updates self internally.")
desc("setParent(xwa:e)", "Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Returns 1 if successfully parented or 0 if prop wasn't valid")
desc("setParent(xwa:)", "Unparents the stream")
desc("setRadius(xwa:n)", "Sets the radius in which to the stream will be heard in. Default is 200 and (default) max is 1500.")

-- is* Getters
desc("isValid(xwa:)", "Returns 1 or 0 for whether the webaudio object is valid (If it is not destroyed & Not invalid from quota)")
desc("isParented(xwa:)", "Returns 1 or 0 for whether the webaudio object is parented or not. Note that if the stream is parented, you cannot set it's position!")

--- Getters
desc("getPos(xwa:)", "Returns the current position of the WebAudio object. This does not work with parenting.")
desc("getVolume(xwa:)", "Returns the volume of the WebAudio object set by setVolume")
desc("getRadius(xwa:)", "Returns the radius of the WebAudio object set by setRadius")

-- Replicated Clientside behavior on server
desc("getTime(xwa:)", "Returns the playback time of the stream in seconds.")
desc("getState(xwa:)", "Returns the state of the stream. 0 is Stopped, 1 is Playing, 2 is Paused. See the CHANNEL_* constants")

-- Info received from client
desc("getLength(xwa:)", "Returns the playback duration of the stream in seconds. Will return -1 if couldn't get length.")
desc("getFileName(xwa:)", "Returns the file name of the WebAudio stream. Will usually be the URL you give, but not always. Will return \"\" if we haven't received the name yet.")


-- Aliases
desc("unparent(xwa:)", "Alias of xwa:setParent(), Unparents the stream")
desc("parentTo(xwa:e)", "Alias of xwa:setParent(), Parents the stream to entity e")