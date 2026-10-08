local GroupTracker = {}

if not _G.bkc_group_state then
    _G.bkc_group_state = {
        in_group = false,
        leader = nil,
        members = {},
    }
end
local state = _G.bkc_group_state

function GroupTracker.init()
    local saved = storage.get("bkc_group_state")
    if saved and saved.in_group ~= nil then
        state.in_group = saved.in_group
    end
    if saved and saved.members then
        state.members = saved.members
    end
end

function GroupTracker.is_member(name)
    return state.members[name] == true
end

function GroupTracker.is_in_group()
    return state.in_group
end

function GroupTracker.get_leader()
    return state.leader
end

function GroupTracker.remember_member(name)
    if not name or name == "" or name == "You" or name == "you" then return end
    state.members[name] = true
end

function GroupTracker.set_in_group(val)
    state.in_group = val and true or false
    if not state.in_group then
        state.leader = nil
    end
    storage.set("bkc_group_state", { in_group = state.in_group, members = state.members })
end

function GroupTracker.join()
    GroupTracker.set_in_group(true)
end

function GroupTracker.leave()
    GroupTracker.set_in_group(false)
end

function GroupTracker.set_leader(name)
    state.leader = name
end

return GroupTracker
