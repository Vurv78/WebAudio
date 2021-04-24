# WebAudio [![License](https://img.shields.io/github/license/Vurv78/WebAudio?color=red)](https://opensource.org/licenses/MIT) [![Linter Badge](https://github.com/Vurv78/WebAudio/actions/workflows/linter/badge.svg)](https://github.com/Vurv78/WebAudio/actions) [![github/Vurv78](https://discordapp.com/api/guilds/824727565948157963/widget.png)](https://discord.gg/epJFC6cNsw)

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

``void webaudio:setDirection(vector dir)``  
Sets the direction where the sound will play toward.

``void webaudio:update()``  
Updates all the information of the object and sends it to the client. You need to call this after running functions like ``play`` and ``setVolume``.

``void webaudio:setPos(vector pos)``  
Sets the position of the WebAudio stream.

``void webaudio:setVolume(number volume)``  
Sets the volume of the WebAudio stream, in a 0-100 range, 100 being 100%, 200 being 200%, etc. Will error if it is past ``wa_volume_max``.

``void webaudio:setTime(number time)``  
Sets the time in which the WebAudio stream should seek to in playing the URL.

``void webaudio:setPlaybackRate(number rate)``  
Sets how fast the stream will play the URL. 2 being twice as fast, 0.5 being half, etc.

``void webaudio:pause()``  
Pauses the Stream where it is currently playing, to be resumed with ``play``.

``void webaudio:play()``  
Sets the stream to play. Note you still need to call ``webaudio:update()`` after this, for this to work.

``void webaudio:destroy()``  
Destroys the WebAudio object, rendering it useless. Frees another slot to make a WebAudio stream.
