


-- Match, IsPattern
local function pattern(str) return { str, true } end
local function simple(str) return { str, false } end

WA_Circular_Include = true
local Common = include("autorun/wa_common.lua")
WA_Circular_Include = nil

local warn, notify = Common.warn, Common.notify

local registers = { ["pattern"] = pattern, ["simple"] = simple }

-- Inspired / Taken from StarfallEx & Metastruct/gurl
-- No blacklist for now, just don't whitelist anything that has weird other routes.

--- Note #1 (For PR Help)
-- Sites cannot track users / do any scummy shit with your data unless they're a massive corporation that you really can't avoid anyways.
-- So don't think about PRing your own website
-- Also these have to do with audio since this is a audio addon.

--- Note #2
-- Create a file called webaudio_whitelist.txt in your data folder to overwrite this, works on the server box or on your client.
-- Example file might look like this:
-- ```
-- pattern %w+%.sndcdn%.com
-- simple translate.google.com
-- ```
local Whitelist = {
    -- Soundcloud
    pattern [[%w+%.sndcdn%.com]],

    -- Google Translate Api
    simple [[translate.google.com]],

    -- Discord
    pattern [[cdn[%w-_]*%.discordapp%.com/.+]],

    -- Reddit
    simple [[i.redditmedia.com]],
    simple [[i.redd.it]],
    simple [[preview.redd.it]],

    -- Shoutcast
    simple [[yp.shoutcast.com]],

    -- Dropbox
    simple [[dl.dropboxusercontent.com]],
    pattern [[%w+%.dl%.dropboxusercontent%.com/(.+)]],
    simple [[www.dropbox.com]],
    simple [[dl.dropbox.com]],
}

local CustomWhitelist = false
local function loadWhitelist(reloading)
    if file.Exists("webaudio_whitelist.txt", "DATA") then
        CustomWhitelist = true
        local dat = file.Read("webaudio_whitelist.txt", "DATA")
        local new_list, ind = {}, 1
        for line in dat:gmatch("[^\r\n]+") do
            local type, match = line:match("(%w+)%s+(.*)")
            local reg = registers[type]
            if reg then
                new_list[ind] = reg(match)
                ind = ind + 1
            elseif type ~= nil then
                -- Make sure type isn't nil so we ignore empty lines
                warn("Invalid entry type found [\"", type, "\"] in webaudio_whitelist\n")
            end
        end
        notify("Whitelist from webaudio_whitelist.txt found and parsed with %d entries!", ind)
        Whitelist = new_list
    elseif reloading then
        notify("Couldn't find your whitelist file! %s", CLIENT and "Make sure to run this on the server if you want to reload the server's whitelist!" or "")
    end
end
loadWhitelist()

local function isWhitelistedURL(self, url)
    if not isstring(url) then return false end
    local relative = url:match("^https?://(.*)")
    if not relative then return false end
    for k, data in ipairs(Whitelist) do
        local match, is_pattern = data[1], data[2]

        local haystack = is_pattern and relative or (relative:match("(.-)/.*") or relative)
        local res = haystack:find( string.format("^%s%s", match, is_pattern and "" or "$"), 1, not is_pattern )
        if res then return true end
    end
    return false
end

concommand.Add("wa_reload_whitelist", loadWhitelist)
WebAudio.isWhitelistedURL = isWhitelistedURL -- Add static ``isWhitelistedURL`` function

return {
    Whitelist = Whitelist,
    CustomWhitelist
}