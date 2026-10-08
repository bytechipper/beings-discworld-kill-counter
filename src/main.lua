-- Mallard 0.27.0 loads sibling modules without caching. Share one instance
-- per VM so panel callbacks, commands, and lifecycle handlers see the same state.
local host_require = require
local modules = {}
require = function(name)
    if modules[name] == nil then modules[name] = host_require(name) end
    return modules[name]
end

local KillTracker = require("kill_tracker")
local GroupTracker = require("group_tracker")
local SelfName = require("self_name")
local Panel = require("panel")

KillTracker.init()
GroupTracker.init()
SelfName.init()
Panel.init()

-- If any kills were recorded earlier under the literal "You" (when the
-- character name wasn't known yet), fold them into the real name so the
-- published name and totals line up.
local function migrate_you_entries()
    local my_name = SelfName.get()
    if not my_name or my_name == "You" then return end
    KillTracker.merge_player("You", my_name)
end

-- ── Kill triggers ──────────────────────────────────────────────────────────
-- Discworld kill lines have one of these shapes:
--   "You kill Delbert."            (self, no third-person s)
--   "Bob kills the Triad boss."    (other player, third-person s)
--   "You deal the death blow to X."
--   "Bob deals the death blow to X."
-- One broad trigger avoids double-counting the same event.
mud.trigger("^(.+?) (?:kills?|deals? the death blow to) (.+?)[.!]$", function(m)
    if not GroupTracker.is_in_group() then return end
    local killer = SelfName.resolve_killer(m[1])
    if settings.get("track_all_players") == false
        and killer ~= SelfName.get() and killer ~= "You"
        and not GroupTracker.is_member(killer) then return end
    migrate_you_entries()
    KillTracker.record_kill(killer)
    Panel.update()
end, { name = "bkc_kill_event", priority = 40 })

-- ── Self-name detection ────────────────────────────────────────────────────
-- Group output echoes every member's message as `[group] name: text` (note:
-- Discworld emits "[<group> <name>: <text>" with no closing bracket). When the
-- message is the one we just published, the name prefix is ours, which
-- attributes our own kills correctly ("You" -> real name).
mud.trigger("^\\[([^ ]+) ([^:]+): (.+)$", function(m)
    SelfName.on_group_say(m[2], m[3])
end, { name = "bkc_group_say_echo", priority = 1 })

-- Group status lists every member as "<Name> is <cond> and <state>...". Parse
-- it to refresh the set of known names.
mud.trigger("^\\s+(\\w+) is .+\\.$", function(m)
    GroupTracker.remember_member(m[1])
end, { name = "bkc_group_status_member", priority = 1 })

-- If the server sends character info via GMCP it includes our name; use it.
gmcp.on("Char.Info", function(_, data)
    if data and data.name then
        SelfName.set(data.name)
    end
end)


-- ── Group detection triggers ───────────────────────────────────────────────
mud.trigger("^\\[(.+)\\] You have joined the group\\.$", function(m)
    GroupTracker.join()
    Panel.update()
end, { name = "bkc_group_join", priority = 10 })

mud.trigger("^\\[(.+)\\] You have left the group\\.$", function(m)
    GroupTracker.leave()
    Panel.update()
end, { name = "bkc_group_leave", priority = 10 })

mud.trigger("^\\[(.+)\\] You have been kicked out of the group\\.$", function(m)
    GroupTracker.leave()
    Panel.update()
end, { name = "bkc_group_kick", priority = 10 })

mud.trigger("^\\[(.+)\\] The current leader has left the group\\.  A new leader will be chosen randomly\\.$", function(m)
    GroupTracker.set_leader(nil)
    Panel.update()
end, { name = "bkc_leader_left", priority = 10 })

mud.trigger("^\\[(.+)\\] By the power vested in (\\w+), (\\w+) has been appointed as the new leader of the group\\.$", function(m)
    GroupTracker.set_leader(m[3])
    Panel.update()
end, { name = "bkc_leader_change", priority = 10 })

mud.trigger("^\\[(.+)\\] (\\w+) (?:is|are) now the leader of the group\\.$", function(m)
    GroupTracker.set_leader(m[2])
    Panel.update()
end, { name = "bkc_leader_random", priority = 10 })

-- ── Commands ───────────────────────────────────────────────────────────────
mud.command("kc", function(m)
    if m.args == "" or m.args == "help" then
        mud.note("[kill-counter] Kill counter commands:", { fg = "cyan", bold = true })
        mud.note("  /kc              - Show kill stats summary")
        mud.note("  /kc help         - Display this help")
        mud.note("  /kc reset        - Reset all kill counts")
        mud.note("  /kc save         - Force save kills to storage")
        mud.note("  /kc publish      - Send kill stats to group say")
        mud.note("  /kc group        - Toggle manual in-group status")
        return
    end

    if m.args == "reset" then
        KillTracker.reset()
        mud.note("[kill-counter] Kill counts reset", { fg = "green" })
        Panel.update()
    elseif m.args == "group" then
        GroupTracker.set_in_group(not GroupTracker.is_in_group())
        if GroupTracker.is_in_group() then
            mud.note("[kill-counter] Group status set to: in group", { fg = "green" })
        else
            mud.note("[kill-counter] Group status set to: not in group", { fg = "yellow" })
        end
        Panel.update()
    elseif m.args == "save" then
        KillTracker.force_save()
        mud.note("[kill-counter] Kills saved to storage", { fg = "green" })
    elseif m.args == "publish" then
        local str = KillTracker.build_publish_string()
        SelfName.expect_echo(str)
        mud.send("group say " .. str)
    else
        local data = KillTracker.get_display_data()
        mud.note(".:: Kill Counter ::.", { bold = true })
        mud.note(string.format("Total: %d kills in %s (%dk/h)",
            data.total_kills, data.session_time, data.group_kph))
        for _, p in ipairs(data.players) do
            mud.note(string.format(" - %s: %d (%d%%, %dk/h)",
                p.name, p.kills, p.pct, p.kills_per_hour))
        end
    end
end, { description = "Kill counter commands", aliases = { "kcs" } })

-- ── Lifecycle ──────────────────────────────────────────────────────────────
world.on("disconnect", function()
    KillTracker.save()
end)
