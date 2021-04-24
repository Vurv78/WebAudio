# WebAudio [![License](https://img.shields.io/github/license/Vurv78/WebAudio?color=red)](https://opensource.org/licenses/MIT) [![Linter Badge](https://github.com/Vurv78/WebAudio/actions/workflows/linter/badge.svg)](https://github.com/Vurv78/WebAudio/actions) [![github/Vurv78](https://discordapp.com/api/guilds/824727565948157963/widget.png)](https://discord.gg/epJFC6cNsw)

This is an addon for garrysmod that adds a serverside ``WebAudio`` class which can be used to interact with clientside IGmodAudioChannels asynchronously.  
It also adds an extension for Expression2 to interact with these in a safe manner.  
You can consider this as a safe and more robust replacement for the popular Streamcore addon, and I advise you to replace it for the safety of your server and it's population.

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