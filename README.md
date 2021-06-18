# WebAudio [![Release Shield](https://img.shields.io/github/v/release/Vurv78/WebAudio)](https://github.com/Vurv78/WebAudio/releases/latest) [![License](https://img.shields.io/github/license/Vurv78/WebAudio?color=red)](https://opensource.org/licenses/MIT) [![Linter Badge](https://github.com/Vurv78/WebAudio/workflows/Linter/badge.svg)](https://github.com/Vurv78/WebAudio/actions) [![github/Vurv78](https://img.shields.io/discord/824727565948157963?color=7289DA&label=chat&logo=discord)](https://discord.gg/epJFC6cNsw) [![Workshop Subscribers](https://img.shields.io/steam/subscriptions/2466875474?color=yellow&logo=steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2466875474)


This is an addon for garrysmod that adds a serverside ``WebAudio`` class which can be used to interact with clientside IGmodAudioChannels asynchronously.  
It also adds an extension for Expression2 to interact with these in a safe manner.  
You can consider this as a safe and more robust replacement for the popular Streamcore addon, and I advise you to replace it for the safety of your server and it's population.
``Documentation`` can be found at the bottom of this file

To convert your Streamcore contraptions to *WebAudio*, see [from Streamcore to WebAudio](https://github.com/Vurv78/WebAudio/wiki/From-StreamCore-To-WebAudio)

## Features
* Client and Serverside Whitelists, both are customizable with simple patterns or more advanced lua patterns.  
* The ``WebAudio`` class and api for that allows for interfacing with IGModAudioChannels from the server, changing the volume, position and time of the audio streams dynamically.  
  * Comes with an Expression2 type that binds to the WebAudio lua class.  

## Why use this over streamcore
If you do not know already, Streamcore is a dangerous addon in several ways.
* Allows for ANYONE to download ANYTHING to everyone on the server's computers.
* Allows for people to crash / lag everyone easily.
* ~~Doesn't allow you to disable it.~~ (There is apparently a way to disable streamcore through ``streamcore_disabled``. It was added ~4 years after the addon was created only after people kept bugging the creator that maybe it isn't a good idea to allow people to download ANYTHING to your computer with no shut off switch.)

WebAudio aims to easily solve these issues by:
* Having proper net limits
* Using a customizable whitelist for both your server & it's clients.
* Containing a flexible but safe default whitelist that only allows for large or trusted domains as to not allow for malicious requests.

## Contributing
See CONTRIBUTING.md

## Convars
| Realm  | Name          | Default Value | Description                                                                                                                |
|--------|---------------|---------------|----------------------------------------------------------------------------------------------------------------------------|
| SHARED | wa_enable     | 1             | Whether WebAudio is enabled for you or the whole server. If you set this to 0, it will purge all currently running streams |
| SERVER | wa_admin_only | 0             | Restrict E2 WebAudio access to admins. 0 is everyone, 1 is >=admin, 2 is super admins only.                                |
| SERVER | wa_stream_max | 5             | Max number of E2 WebAudio streams a player can have                                                                        |
| SHARED | wa_volume_max | 300           | Max volume of streams, will clamp the volume of streams to this on both the client and on the server                       |
| SHARED | wa_radius_max | 10000         | Max distance where WebAudio streams can be heard from their origin.                                                        |
| SHARED | wa_fft_enable | 1             | Whether FFT data is enabled for the server / your client. You shouldn't need to disable it as it is very lightweight       |

## Concommands
| Realm  | Name                | Description                                                                                                    |
|--------|---------------------|----------------------------------------------------------------------------------------------------------------|
| CLIENT | wa_purge            | Purges all currently running WebAudio streams and does not receive any further net updates with their objects. |
| SHARED | wa_reload_whitelist | Refreshes your whitelist located at data/webaudio_whitelist.txt                                                |

## Functions

``webaudio webAudio(string url)``  
Returns a **WebAudio** object of that URL as long as it is whitelisted by the server.  
Has a 150 ms cooldown between calls. If you can't create a webAudio object, will error, so check ``webAudioCanCreate`` before calling this!

``number webAudiosLeft()``  
Returns how many WebAudios you can create.

``number webAudioCanCreate()``  
Returns whether you can create a webaudio stream. Checks cooldown and whether you have a slot for another stream left.

``number webAudioCanCreate(string url)``  
Same as ``webAudioCanCreate()``, but also checks if the url given is whitelisted so you don't error on webAudio calls.

``number webAudioEnabled()``  
Returns whether webAudio is enabled for use on the server.

``number webAudioAdminOnly()``  
Returns 0 if webAudio is available to everyone, 1 if only admins, 2 if only superadmins.

### WebAudio Type Methods

## Setters

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

``void webaudio:setParent(entity e)``  
Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Returns 1 if successfully parented or 0 if prop wasn't valid. Does not update the object.

``void webaudio:setParent()``  
Unparents the stream from the currently parented entity. Does not update the object.

``void webaudio:parentTo(entity e)``  
Alias of webaudio:setParent(e) Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Does not update the object.

``void webaudio:unparent()``  
Alias of webaudio:setParent(), Unparents the stream from the currently parented entity. Does not update the object.

``void webaudio:setRadius(number radius)``  
Sets the radius in which to the stream will be heard in. Default is 200 and (default) max is 1500. Does not update the object.

``void webaudio:setLooping(number looping)``  
Sets the stream to loop if n ~= 0, else stops looping.

## Special

``number webaudio:pause()``  
Pauses the stream where it is currently playing, Returns 1 or 0 if could successfully do so, because of quota. Automatically calls updates self internally.

``number webaudio:play()``  
Starts the stream or continues where it left off after pausing, Returns 1 or 0 if could successfully do so from quota. Automatically updates self internally.

``void webaudio:destroy()``  
Destroys the WebAudio object, rendering it useless. It will silently fail when trying to use it from here on! This gives you another slot to make a WebAudio object

``number webaudio:update()``  
Sends all of the information of the object given by functions like setPos and setTime to the client. You need to call this after running functions without running ``:play()`` or ``:pause()`` on them since those sync with the client. Returns 1 if could update, 0 if hit transmission quota

## Getters

``number webaudio:isValid()``  
Returns 1 or 0 for whether the stream is valid and not destroyed.

``number webaudio:isParented()``  
Returns 1 or 0 for whether the stream is parented

``vector webaudio:getPos()``  
Returns the position of the stream set by setPos. Doesn't work with parented streams since they do that math on the client.

``vector webaudio:getVolume()``  
Returns the volume of the stream set by setVolume

``number webaudio:getRadius()``  
Returns the radius of the stream set by setRadius

``number webaudio:getTime()``  
Returns the current playback time of the stream in seconds.

``number webaudio:getState()``  
Returns the state of the stream, 0 = STOPPED, 1 = PLAYING, 2 = PAUSED, Use the _CHANNEL* constants to get these values easily. (_CHANNEL_STOPPED is 0 for example)

``number webaudio:getLength()``  
Returns the playback duration / length of the stream. Returns -1 if we haven't received the length yet.

``string webaudio:getFileName()``  
Returns the file name of the webaudio stream. Usually but not always returns the URL of the stream, and will return "" if we haven't received the filename yet.

``number webaudio:getLooping()``  
Returns if the stream is looping, set by setLooping

``array webaudio:getFFT()``  
Returns an array of 64 FFT values from 0-255.