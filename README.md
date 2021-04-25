# WebAudio [![Release Shield](https://img.shields.io/github/v/release/Vurv78/WebAudio)](https://github.com/Vurv78/VExtensions/releases/latest) [![License](https://img.shields.io/github/license/Vurv78/WebAudio?color=red)](https://opensource.org/licenses/MIT) [![Linter Badge](https://github.com/Vurv78/WebAudio/workflows/Linter/badge.svg)](https://github.com/Vurv78/WebAudio/actions) [![github/Vurv78](https://discordapp.com/api/guilds/824727565948157963/widget.png)](https://discord.gg/epJFC6cNsw)

This is an addon for garrysmod that adds a serverside ``WebAudio`` class which can be used to interact with clientside IGmodAudioChannels asynchronously.  
It also adds an extension for Expression2 to interact with these in a safe manner.  
You can consider this as a safe and more robust replacement for the popular Streamcore addon, and I advise you to replace it for the safety of your server and it's population.
``Documentation`` can be found at the bottom of this file

## Features
* Client and Serverside Whitelists, both are customizable with simple patterns or more advanced lua patterns.  
* The ``WebAudio`` type in Expression2 that adds the ability to manipulate sounds in 3D space to change it's volume, position and time in the song dynamically.   
* Easy to use lua api that tries to mirror the IGModAudioChannel type.

## Why use this over streamcore
If you do not know already, Streamcore is a dangerous addon in several ways.  
It allows for people to download anything to everyone's computers on the server.  
And they can't disable it.

You can also abuse it to crash the server relatively easily.  

WebAudio aims to easily solve these issues by having efficient safe code as well as the customizable whitelist (alongside a standard default whitelist that is flexible and doesn't permit malicious activity)

## Contributing
Pull request anything you want, just make sure you're ready to change things to make sure the code will remain efficient and along the same style as the rest of the codebase.  
You will also need to make sure you fix all linting errors.

## Convars
``wa_enable``  
Allows you to disable WebAudio for your server or for the client.

``wa_admin_only``  
Serverside convar that allows you to set WebAudio E2 access to only Admins or Only SuperAdmins. (0 for Everyone, 1 for Admins, 2 for SuperAdmins)

``wa_volume_max``  
Serverside convar that allows you to set the maximum volume a WebAudio stream can play at.

## Functions

``webaudio webAudio(string url)``  
Returns a WebAudio object of that URL as long as it is whitelisted by the server. Has a 150 ms cooldown between calls.

``number webAudiosLeft()``  
Returns how many WebAudios you can create.

``number webAudioCanCreate()``  
Returns whether you can call the webAudio function without getting an error from the cooldown.

``number webAudioEnabled()``  
Returns whether webAudio is enabled for use on the server.

``number webAudioAdminOnly()``  
Returns 0 if webAudio is available to everyone, 1 if only admins, 2 if only superadmins.

### WebAudio Type Methods

``void webaudio:setDirection(vector dir)``  
Sets the direction in which the WebAudio stream is playing towards. Does not update the object.

``void webaudio:setPos(vector pos)``  
Sets the 3D Position of the WebAudio stream without updating it. Does not update the object.

``void webaudio:setVolume(number volume)``  
Sets the volume of the WebAudio stream, in percent format. 200 is 2x as loud as normal, 100 is default. Will error if it is past ``wa_volume_max``.

``void webaudio:setTime(number time)``  
Sets the time in which the WebAudio stream should seek to in playing the URL. Does not update the object.

``void webaudio:setPlaybackRate(number rate)``  
Sets the playback speed of a webaudio stream. 2 is twice as fast, 0.5 being half, etc. Does not update the object.

``number webaudio:pause()``  
Pauses the stream where it is currently playing, Returns 1 or 0 if could successfully do so, because of quota. Automatically calls updates self internally.

``number webaudio:play()``  
Starts the stream or continues where it left off after pausing, Returns 1 or 0 if could successfully do so from quota. Automatically updates self internally.

``void webaudio:destroy()``  
Destroys the WebAudio object, rendering it useless. It will silently fail when trying to use it from here on! This gives you another slot to make a WebAudio object

``number webaudio:update()``  
Sends all of the information of the object given by functions like setPos and setTime to the client. You need to call this after running functions without running ``:play()`` or ``:pause()`` on them since those sync with the client. Returns 1 if could update, 0 if hit transmission quota

``number webaudio:isDestroyed()``  
Returns 1 or 0 for whether the webaudio object is destroyed or not

``void webaudio:setParent(entity e)``  
Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Returns 1 if successfully parented or 0 if prop wasn't valid. Does not update the object.

``void webaudio:setParent()``  
Unparents the stream from the currently parented entity. Does not update the object.

``void webaudio:parentTo(entity e)``  
Alias of webaudio:setParent(e) Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Does not update the object.

``void webaudio:unparent()``  
Alias of webaudio:setParent(), Unparents the stream from the currently parented entity. Does not update the object.