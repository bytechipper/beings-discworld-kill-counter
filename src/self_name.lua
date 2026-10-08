local SelfName = {}

if not _G.bkc_self_name then
    _G.bkc_self_name = {
        name = nil,
        pending = nil,
    }
end
local state = _G.bkc_self_name

function SelfName.init()
    local saved = storage.get("bkc_my_name")
    if saved and saved ~= "" and saved ~= "You" then
        state.name = saved
    end
end

-- Best-known name for the player, or nil if still unknown.
function SelfName.get()
    if state.name then return state.name end
    local wc = mud.world.character
    if wc and wc ~= "" and wc ~= "You" then
        return wc
    end
    return nil
end

function SelfName.set(name)
    if not name or name == "" or name == "You" or name == "you" then return end
    if state.name == name then return end
    state.name = name
    storage.set("bkc_my_name", name)
end

-- Record a message we just published so its group-say echo can reveal our name.
function SelfName.expect_echo(message)
    state.pending = message
end

-- Handle an incoming group-say echo `[group] name: message`. If it is the echo
-- of our own publish, learn our name from the name prefix.
function SelfName.on_group_say(name, message)
    if state.pending and message == state.pending then
        SelfName.set(name)
        state.pending = nil
        return true
    end
    return false
end

-- Map "You" (Discworld's way of referring to the player) onto our real name.
function SelfName.resolve_killer(killer)
    if killer == "You" or killer == "you" then
        return SelfName.get() or "You"
    end
    return killer
end

return SelfName
