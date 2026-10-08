function renderPlayers(container, players) {
    container.innerHTML = "";
    if (players.length === 0) {
        const empty = document.createElement("div");
        empty.className = "empty-state";
        empty.textContent = "No kills recorded";
        container.appendChild(empty);
        return;
    }
    for (const p of players) {
        const el = document.createElement("div");
        el.className = "player-entry";

        const nameSpan = document.createElement("span");
        nameSpan.className = "player-name";
        nameSpan.textContent = p.name;
        nameSpan.title = p.name;

        const killsSpan = document.createElement("span");
        killsSpan.className = "player-kills";
        killsSpan.textContent = p.kills;

        const pctSpan = document.createElement("span");
        pctSpan.className = "player-pct";
        pctSpan.textContent = p.pct + "%";

        const kphSpan = document.createElement("span");
        kphSpan.className = "player-kph";
        kphSpan.textContent = p.kills_per_hour + "/h";

        el.appendChild(nameSpan);
        el.appendChild(killsSpan);
        el.appendChild(pctSpan);
        el.appendChild(kphSpan);
        container.appendChild(el);
    }
}

let currentInGroup = false;

function updateSummary(data) {
    const statusEl = document.getElementById("group-status");
    const summaryRow = statusEl.closest(".summary-row");
    const btnGroup = document.getElementById("btn-group");

    currentInGroup = data.in_group;

    if (data.in_group) {
        statusEl.textContent = "In group";
        summaryRow.className = "summary-row group-active";
        btnGroup.textContent = "Leave Group";
    } else {
        statusEl.textContent = "Not in group";
        summaryRow.className = "summary-row group-inactive";
        btnGroup.textContent = "In Group";
    }

    document.getElementById("total-kills").textContent = data.total_kills;
    document.getElementById("session-time").textContent = data.session_time;

    const kphEl = document.getElementById("group-kph");
    kphEl.textContent = data.group_kph + "k/h";
}

document.getElementById("btn-group").addEventListener("click", function () {
    window.panel.post("group", { in_group: !currentInGroup });
});

window.panel.on("update", function (data) {
    renderPlayers(document.getElementById("player-list"), data.players);
    updateSummary(data);
});

document.getElementById("btn-publish").addEventListener("click", function () {
    window.panel.post("publish", {});
});

document.getElementById("btn-reset").addEventListener("click", function () {
    window.panel.post("reset", {});
});

document.getElementById("btn-save").addEventListener("click", function () {
    window.panel.post("save", {});
});

window.panel.post("ready", {});
