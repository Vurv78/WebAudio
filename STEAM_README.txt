[h1]WebAudio for Garry's Mod[/h1]
This is an addon for garrysmod that adds a serverside [b]WebAudio[/b] class which can be used to interact with clientside [b]IGmodAudioChannels[/b] asynchronously.
It also adds an extension for Expression2 to interact with these in a safe manner.
This is essentially a safe and more robust replacement for the popular Streamcore addon, since it is much more secure and customisable.


[h2]Features[/h2]
[list]
[*] Client and Serverside URL whitelists, both are customizable with simple patterns or more advanced lua patterns.
[*] The [b]WebAudio[/b] type in Expression 2 that adds the ability to change sounds in a 3D space, or change it's volume, position and time whilst the music is playing.
[*] Easy to use Lua api that tries to mirror the [b]IGModAudioChannel[/b] type.[/list]

[h2]Console Variables[/h2]
This is a list of console variables that you can change to configure the addon to your liking.

[table]
[tr]
	[th]Variable Name[/th]
	[th]Description[/th]
[/tr]
[tr]
	[td]wa_enable[/td]
	[td]Allows you to disable WebAudio server-wide or clientside depending on whether it is executed in the client or server console[/td]
[/tr]
[tr]
	[td]wa_admin_only[/td]
	[td]Serverside convar that allows you to set WebAudio E2 access to only Admins or Only Super Admins. (0 for Everyone, 1 for Admins, 2 for Super Admins).
[/td]
[/tr]
[tr]
	[td]wa_volume_max[/td]
	[td]Serverside convar that allows you to set the maximum volume a WebAudio stream can play at. Helps to prevent nasty earrape music being played too loudly
[/td]
[/tr]
[/table]

[h2]E2 Functions[/h2]

[table]
[tr]
	[th]Function name[/th]
	[th]Description[/th]
[/tr]
[tr]
	[td]webaudio webAudio(string url)[/td]
	[td]Returns a WebAudio object of that URL as long as it is whitelisted by the server. Has a 150 ms cooldown between calls to prevent spam.[/td]
[/tr]
[tr]
	[td]number webAudiosLeft()[/td]
	[td]Returns how many WebAudios you can create.[/td]
[/tr]
[tr]
	[td]number webAudioCanCreate()[/td]
	[td]Returns whether you can call the webAudio function without getting an error from the cooldown.
[/td]
[/tr]
[tr]
	[td]number webAudioEnabled()[/td]
	[td]Returns whether webAudio is enabled for use on the server.[/td]
[/tr]
[tr]
	[td]number webAudioAdminOnly()[/td]
	[td]Returns 0 if webAudio is available to everyone, 1 if only admins, 2 if only Super Admins. Basically replicates the value of the wa_admin_only convar[/td]
[/tr]
[/table]


[h1]WebAudio Type Methods[/h1]

[table]
[tr]
	[th]Type name[/th]
	[th]Description[/th]
[/tr]
[tr]
	[td]void webaudio:setDirection(vector dir)[/td]
	[td]Sets the direction in which the WebAudio stream is playing towards. Does not update the object.[/td]
[/tr]
[tr]
	[td]void webaudio:setPos(vector pos)[/td]
	[td]Sets the 3D Position of the WebAudio stream without updating it. Does not update the object.[/td]
[/tr]
[tr]
	[td]void webaudio:setVolume(number volume)[/td]
	[td]Sets the volume of the WebAudio stream, in percent format. 200 is 2x as loud as normal, 100 is default. Will error if it is past wa_volume_max.[/td]
[/tr]
[tr]
	[td]void webaudio:setTime(number time)[/td]
	[td]Sets the time in which the WebAudio stream should seek to in playing the URL. Does not update the object.[/td]
[/tr]
[tr]
	[td]void webaudio:setPlaybackRate(number rate)[/td]
	[td]Sets the playback speed of a webaudio stream. 2 is twice as fast, 0.5 being half, etc. Does not update the object.[/td]
[/tr]
[tr]
	[td]number webaudio:pause()[/td]
	[td]Pauses the stream where it is currently playing, Returns 1 or 0 if could successfully do so, because of quota. Automatically calls updates self internally.
[/td]
[/tr]
[tr]
	[td]number webaudio:play()[/td]
	[td]Starts the stream or continues where it left off after pausing, Returns 1 or 0 if could successfully do so from quota. Automatically updates self internally.
[/td]
[/tr]
[tr]
	[td]void webaudio:destroy()[/td]
	[td]Destroys the WebAudio object, rendering it useless. It will silently fail when trying to use it from here on! This gives you another slot to make a WebAudio object[/td]
[/tr]
[tr]
	[td]number webaudio:update()[/td]
	[td]Sends all of the information of the object given by functions like setPos and setTime to the client. You need to call this after running functions without running :play() or :pause() on them since those sync with the client. Returns 1 if could update, 0 if hit transmission quota
[/td]
[/tr]
[tr]
	[td]number webaudio:isDestroyed()[/td]
	[td]Returns 1 or 0 for whether the webaudio object is destroyed or not[/td]
[/tr]
[tr]
	[td]void webaudio:setParent(entity e)[/td]
	[td]Parents the stream position to e, local to the entity. If you've never set the position before, will be parented to the center of the prop. Returns 1 if successfully parented or 0 if prop wasn't valid. Does not update the object.
If entity is left out, this unparents the stream from the currently parented entity. This will not update the object either.
[/td]
[/tr]
[tr]
	[td]void webaudio:parentTo(entity e)[/td]
	[td]Alias of webaudio:setParent(entity e)[/td]
[/tr]
[tr]
	[td]void webaudio:unparent()
[/td]
	[td]Alias of webaudio:setParent() when the entity field is left blank. Unparents the stream from the currently parented entity. Does not update the object.[/td]
[/tr]
[/table]


[h1]Questions you may ask:[/h1]

[h2]Why use this instead of Streamcore?[/h2]
If you do not know already, [b]Streamcore is a dangerous addon[/b] in several ways. If someone makes an E2 code with a malicious URL in it, such as an illegal file, then [b]that file will be downloaded [u]to your PC[/u][/b], and there is [b]no way[/b] of stopping it on Streamcore enabled servers.
Also, due to the nature of the code, the addon can crash servers very easily.

WebAudio aims to easily solve these issues by having [b]efficient and safe code[/b] as well as having a customizable whitelist (alongside a standard default whitelist that is flexible and won't allow many common nasties to happen). It also contains features that Streamcore doesn't, such as the ability to play from certain points in a stream, and allows for far more flexibility than StreamCore does. It's also being actively developed, so should play better with newer Garry's Mod versions in future.

[h2]I want to contribute to the addon![/h2]
Then use the Github page! [url=https://github.com/Vurv78/WebAudio]https://github.com/Vurv78/WebAudio[/url]
Pull request anything you like, just make sure you're ready to change things so that the code will remain efficient and in a similar style to the rest of the codebase.
You will also need to make sure you fix all linting errors.

[h2]I've found a bug![/h2]
That's alright! This addon is in its early days, and as such bugs are going to be a fact of life.
You can report bugs by either posting a report on the [url=https://github.com/Vurv78/WebAudio]Github page[/url], or starting a new conversation on this page. Make sure to be [u]detailed and concise[/u] in your bug reports, so that they can be serviced easier!
