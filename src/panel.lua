local KillTracker = require("kill_tracker")
local GroupTracker = require("group_tracker")
local SelfName = require("self_name")

local Panel = {}

local panel_handle = nil
local update_timer = nil

function Panel.init()
    panel_handle = mud.panel("beings-discworld-kill-counter")

    panel_handle:on_message("ready", function(_)
        Panel.update()
    end)

    panel_handle:on_message("publish", function(_)
        local str = KillTracker.build_publish_string()
        SelfName.expect_echo(str)
        mud.send("group say " .. str)
    end)

    panel_handle:on_message("reset", function(_)
        KillTracker.reset()
        mud.note("[kill-counter] Kill counts reset", { fg = "green" })
        Panel.update()
    end)

    panel_handle:on_message("save", function(_)
        KillTracker.force_save()
        mud.note("[kill-counter] Kills saved to storage", { fg = "green" })
    end)

    panel_handle:on_message("group", function(data)
        if data and data.in_group then
            GroupTracker.join()
        else
            GroupTracker.leave()
        end
        Panel.update()
    end)

    update_timer = mud.every(1000, function()
        Panel.update()
    end)
end

function Panel.update()
    if not panel_handle then return end
    local data = KillTracker.get_display_data()
    data.in_group = GroupTracker.is_in_group()
    panel_handle:post("update", data)
end

return Panel
