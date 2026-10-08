local KillTracker = {}

if not _G.bkc_kill_state then
    _G.bkc_kill_state = {
        players = {},
        session_start = 0,
        total_kills = 0,
        dirty = false,
    }
end
local state = _G.bkc_kill_state

function KillTracker.init()
    if state.session_start == 0 then
        state.session_start = os.time()
    end
    KillTracker.load()
end

function KillTracker.load()
    local saved = storage.get("kill_state")
    if saved then
        state.players = {}
        for name, data in pairs(saved.players or {}) do
            state.players[name] = {
                kills = data.kills or 0,
                first_kill = data.first_kill or 0,
                last_kill = data.last_kill or 0,
            }
        end
        state.total_kills = saved.total_kills or 0
        state.dirty = false
    end
end

function KillTracker.save(force)
    if not force and settings.get("auto_save") == false then return end
    if not state.dirty then return end
    storage.set("kill_state", {
        players = state.players,
        total_kills = state.total_kills,
    })
    state.dirty = false
end

function KillTracker.force_save()
    state.dirty = true
    KillTracker.save(true)
end

function KillTracker.record_kill(player_name)
    local now = os.time()
    if not state.players[player_name] then
        state.players[player_name] = { kills = 0, first_kill = now, last_kill = now }
    end
    state.players[player_name].kills = state.players[player_name].kills + 1
    state.players[player_name].last_kill = now
    state.total_kills = state.total_kills + 1
    state.dirty = true
end

-- Fold an old player entry (e.g. the literal "You") into the real name.
function KillTracker.merge_player(from_name, to_name)
    if from_name == to_name then return end
    local from = state.players[from_name]
    if not from or from.kills <= 0 then return end
    local to = state.players[to_name]
    if not to then
        state.players[to_name] = { kills = 0, first_kill = from.first_kill, last_kill = from.last_kill }
        to = state.players[to_name]
    end
    to.kills = to.kills + from.kills
    if from.first_kill and (to.first_kill == 0 or from.first_kill < to.first_kill) then
        to.first_kill = from.first_kill
    end
    if from.last_kill and from.last_kill > (to.last_kill or 0) then
        to.last_kill = from.last_kill
    end
    state.players[from_name] = nil
    state.dirty = true
end

function KillTracker.reset()
    state.players = {}
    state.session_start = os.time()
    state.total_kills = 0
    state.dirty = true
end

function KillTracker.get_session_duration()
    return os.time() - state.session_start
end

local function format_duration(secs)
    local hours = math.floor(secs / 3600)
    local mins = math.floor((secs % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

function KillTracker.get_display_data()
    local now = os.time()
    local session_secs = KillTracker.get_session_duration()
    local session_hours = session_secs / 3600

    local sorted_players = {}
    for name, data in pairs(state.players) do
        table.insert(sorted_players, {
            name = name,
            kills = data.kills,
            kills_per_hour = session_hours > 0 and math.floor(data.kills / session_hours) or 0,
            pct = state.total_kills > 0 and math.floor((data.kills / state.total_kills) * 100) or 0,
        })
    end
    table.sort(sorted_players, function(a, b) return a.kills > b.kills end)

    local group_kph = session_hours > 0 and math.floor(state.total_kills / session_hours) or 0

    return {
        players = sorted_players,
        total_kills = state.total_kills,
        session_time = format_duration(session_secs),
        group_kph = group_kph,
    }
end

function KillTracker.build_publish_string()
    local data = KillTracker.get_display_data()
    local parts = {}

    for _, p in ipairs(data.players) do
        table.insert(parts, string.format("%s: %d kills (%d%%)", p.name, p.kills, p.pct))
    end

    local summary = string.format("Group total: %d kills in %s @ %dk/h",
        data.total_kills, data.session_time, data.group_kph)

    if #parts > 0 then
        return table.concat(parts, " | ") .. " <|> " .. summary
    else
        return summary
    end
end

return KillTracker
