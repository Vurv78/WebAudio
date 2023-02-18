[h1]WebAudio[/h1]
[url=https://github.com/Vurv78/WebAudio/wiki]Wiki[/url]
This addon adds a serverside [b]WebAudio[/b] class which can be used to interact with clientside [b]IGmodAudioChannels[/b] asynchronously.
It also adds an extension for Expression2 to interact with these in a safe manner.

[i]This is essentially a safe and more robust replacement for the popular Streamcore addon, since it is [b]much[/b] more secure and customizable.[/i]

[h2]Why use this instead of Streamcore?[/h2]
[h3]Streamcore is a dangerous addon.[/h3]
It has no whitelist, meaning [b] anyone can force everyone on the server to download ILLEGAL CONTENT or grab everyone's IP Addresses through links like grabify.[/b]
Server owners aren't safe either, streamcore easily allows you to crash everyone on it through spamming net messages.

[b][i]In fact, this addon was made out of frustration over how low effort / terrible streamcore is and how the author does not care about the security of people's games whatsoever after years of reports over these vulnerabilities.[/i][/b]

[i]WebAudio easily solves this through a whitelist, active development and flexible but strong limits.[/i]

[h3] WebAudio has much more features. [/h3]
Have you ever wanted to pause a stream while it was playing?
Maybe turn up the volume higher because it was too quiet?
Maybe even getting the current playback time or FFT values of the stream?
[url=https://github.com/Vurv78/WebAudio/wiki/Features]You can easily do all of this + much more with WebAudio.[/url]

[h2]Features[/h2]
[list]
[*] Client and Serverside URL whitelists, both are customizable with simple patterns or more advanced lua patterns.
[*] The [b]WebAudio[/b] type in Expression 2 that adds the ability to change sounds in a 3D space, or change it's volume, position and time whilst the music is playing.
[*] Easy to use Lua api that tries to mirror the [b]IGModAudioChannel[/b] type.[/list]
[*] Find the rest here https://github.com/Vurv78/WebAudio/wiki/Features
[/list]

[h2]I want to contribute![/h2]
Then use the Github page! [url=https://github.com/Vurv78/WebAudio]https://github.com/Vurv78/WebAudio[/url]
Pull request anything you like, just make sure to see [b]CONTRIBUTING.md[/b]

[h2]I've found a bug![/h2]
You can report bugs by either posting a report on the [url=https://github.com/Vurv78/WebAudio]Github page[/url], or by starting a new conversation on this page.
Make sure to be [u]detailed and concise[/u] in your bug reports, so that they can be serviced easier!

[h2]ConVars[/h2]
This is a list of [b]ConVars[/b] that you can change to configure the addon to your liking.
[table]
[tr]
	[th]Realm[/th]
	[th]Name[/th]
	[th]Default Value[/th]
	[th]Description[/th]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_enable[/td]
	[td]1[/td]
	[td]Shared convar that allows you to disable WebAudio for the server or yourself depending on whether it is executed in the client or server console[/td]
[/tr]
[tr]
	[td]SERVER[/td]
	[td]wa_admin_only[/td]
	[td]0[/td]
	[td]Allows you to set WebAudio E2 access to only Admins or Only Super Admins. (0 for Everyone, 1 for Admins, 2 for Super Admins).[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_volume_max[/td]
	[td]300[/td]
	[td]
		Shared convar that allows you to set the maximum volume a WebAudio stream can play at.
		100 is 100%, 50 is 50% and so on.
		Helps to prevent nasty earrape music being played too loudly
	[/td]
[/tr]
[tr]
	[td]SERVER[/td]
	[td]wa_stream_max[/td]
	[td]5[/td]
	[td]Serverside convar that allows you to set the max amount of streams a player can have at once[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_radius_max[/td]
	[td]3000[/td]
	[td]Allows you to set the maximum distance a stream can be heard from. Works on your client.[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_fft_enable[/td]
	[td]1[/td]
	[td]Whether FFT data is enabled for the server / your client. You shouldn't need to disable it as it is very lightweight[/td]
[/tr]
[tr]
	[td]CLIENT[/td]
	[td]wa_verbosity[/td]
	[td]1[/td]
	[td]Verbosity of console notifications. 2 => URL/Logging + Extra Info, 1 => Only warnings/errors, 0 => Nothing (Avoid this)[/td]
[/tr]
[tr]
	[td]SERVER[/td]
	[td]wa_sc_compat[/td]
	[td]0[/td]
	[td]Whether streamcore-compatible functions should be generated for E2 (for backwards compat)[/td]
[/tr]
[/table]

[h2]Console Commands[/h2]
This is a list of Concommands to use with this addon as a server owner and a user.

[table]
[tr]
	[th]Realm[/th]
	[th]Name[/th]
	[th]Description[/th]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_purge[/td]
	[td]Purges all currently running streams and makes sure you don't get any useless net messages from them.[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_reload_whitelist[/td]
	[td]Reloads your whitelist at data/webaudio_whitelist.txt[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_list[/td]
	[td]Prints a list of currently playing WebAudio streams (As long as their owner IsValid) with their url, id & owner[/td]
[/tr]
[tr]
	[td]SHARED[/td]
	[td]wa_help[/td]
	[td]Prints the link to the github to your console[/td]
[/tr]
[tr]
	[td]CLIENT[/td]
	[td]wa_display[/td]
	[td]Displays active WebAudio streams to your screen w/ steamid and stream id[/td]
[/tr]
[/table]

[h2]Function Docs[/h2]
Function documentation has moved to only be on [url=https://github.com/Vurv78/WebAudio]Github[/url].