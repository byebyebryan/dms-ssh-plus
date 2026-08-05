import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    id: root

    readonly property string pluginName: "sshPlus"
    readonly property string defaultTrigger: "ssh:"
    readonly property string defaultTerminal: Quickshell.env("TERMINAL") || "ghostty"
    readonly property string defaultSshCommand: "ssh"
    readonly property int defaultConnectTimeout: 2
    readonly property int defaultMaxHosts: 100

    property var pluginService: null
    property string trigger: defaultTrigger
    property string terminal: defaultTerminal
    property string sshCommand: defaultSshCommand
    property string sortMode: "recency"
    property bool probeEnabled: true
    property int connectTimeout: defaultConnectTimeout
    property int maxHosts: defaultMaxHosts
    property bool scopeLaunch: true
    property var hosts: []
    property bool hasSystemdRun: false

    signal itemsChanged()

    function _asInt(value, fallback) {
        const n = parseInt(value, 10);
        return isNaN(n) ? fallback : n;
    }

    function _asBool(value, fallback) {
        return value === undefined ? fallback : (value === true || value === "true");
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData(pluginName, "trigger", defaultTrigger);
        terminal = pluginService.loadPluginData(pluginName, "terminal", defaultTerminal);
        sshCommand = pluginService.loadPluginData(pluginName, "ssh_command", defaultSshCommand);
        sortMode = pluginService.loadPluginData(pluginName, "sort_mode", "recency");
        probeEnabled = _asBool(
            pluginService.loadPluginData(pluginName, "probe_enabled", true),
            true
        );
        connectTimeout = _asInt(
            pluginService.loadPluginData(pluginName, "connect_timeout", defaultConnectTimeout),
            defaultConnectTimeout
        );
        maxHosts = _asInt(
            pluginService.loadPluginData(pluginName, "max_hosts", defaultMaxHosts),
            defaultMaxHosts
        );
        scopeLaunch = _asBool(
            pluginService.loadPluginData(pluginName, "scope_launch", true),
            true
        );
        hosts = pluginService.loadPluginState(pluginName, "hosts", []);
        detectSystemdRun();
    }

    onTriggerChanged: {
        if (pluginService)
            pluginService.savePluginData(pluginName, "trigger", trigger);
    }

    Process {
        id: systemdCheck

        running: false

        onExited: (exitCode, exitStatus) => {
            root.hasSystemdRun = exitCode === 0;
        }
    }

    function detectSystemdRun() {
        if (systemdCheck.running)
            return;
        systemdCheck.command = ["sh", "-c", "command -v systemd-run >/dev/null 2>&1"];
        systemdCheck.running = true;
    }

    Process {
        id: probeProcess

        property string pendingHost: ""
        property string probeError: ""
        running: false

        stderr: StdioCollector {
            onStreamFinished: probeProcess.probeError = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            const host = probeProcess.pendingHost;
            probeProcess.pendingHost = "";
            if (!host)
                return;
            if (exitCode === 0 || reachedServer(probeProcess.probeError)) {
                recordSuccess(host);
            } else {
                showToast(
                    "SSH Plus",
                    "Could not reach " + host + "; opening anyway and not recording"
                );
            }
            launchTerminal(host);
        }
    }

    function getItems(query) {
        const items = [];
        const q = (query || "").trim();
        const lowerQ = q.toLowerCase();
        const recs = sortedHosts();

        if (/^rm(\s|$)/i.test(q)) {
            const target = q.replace(/^rm\s*/i, "").trim();
            if (!target) {
                items.push({
                    name: "rm <host>",
                    icon: "material:help_outline",
                    comment: "Remove a recorded host, e.g. rm docker.lan",
                    categories: ["SSH Plus"]
                });
                return items;
            }
            const rec = recs.find(h => h.host === target.toLowerCase());
            items.push({
                name: "Remove: " + target,
                icon: "material:delete",
                comment: rec ? commentFor(rec) + " — remove from history" : "Not in recorded history",
                action: "remove:" + target,
                categories: ["SSH Plus"],
                _preScored: 2000
            });
            return items;
        }

        if (/^clear$/i.test(q) && recs.length > 0) {
            items.push({
                name: "Clear all hosts (" + recs.length + ")",
                icon: "material:delete_sweep",
                comment: "Remove every recorded host",
                action: "clear:",
                categories: ["SSH Plus"],
                _preScored: 2000
            });
            return items;
        }

        const filtered = lowerQ ? recs.filter(h => h.host.includes(lowerQ)) : recs;
        for (let i = 0; i < Math.min(20, filtered.length); i++) {
            const h = filtered[i];
            items.push({
                name: h.host,
                icon: "material:terminal",
                badgeLabel: h.count > 1 ? String(h.count) : "",
                comment: commentFor(h),
                action: "connect:" + h.host,
                categories: ["SSH Plus"],
                _preScored: 3000 - i,
                _host: h.host
            });
        }

        if (q && !recs.some(h => h.host === lowerQ)) {
            items.push({
                name: "SSH to: " + q,
                icon: "material:login",
                comment: "Connect to " + q + " and record it on success",
                action: "connect:" + q,
                categories: ["SSH Plus"],
                _preScored: 1
            });
        }

        if (!q && recs.length === 0) {
            items.push({
                name: "SSH to a host",
                icon: "material:terminal",
                comment: "Type a hostname to connect, e.g. docker.lan",
                categories: ["SSH Plus"],
                _preScored: 0
            });
        }

        return items;
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        const colonIdx = item.action.indexOf(":");
        const actionType = item.action.substring(0, colonIdx);
        const actionData = item.action.substring(colonIdx + 1);

        switch (actionType) {
        case "connect":
            connectTo(actionData);
            break;
        case "remove":
            removeHost(actionData);
            break;
        case "clear":
            clearHosts();
            break;
        default:
            console.warn(pluginName + ": unknown action " + actionType);
        }
    }

    function getContextMenuActions(item) {
        if (!item || !item._host)
            return [];
        return [{
            icon: "delete",
            text: "Remove " + item._host + " from history",
            action: () => removeHost(item._host)
        }];
    }

    function sortedHosts() {
        const copy = hosts.slice();
        if (sortMode === "frequency") {
            copy.sort((a, b) =>
                (b.count || 0) - (a.count || 0) || (b.lastConnected || 0) - (a.lastConnected || 0)
            );
        } else {
            copy.sort((a, b) => (b.lastConnected || 0) - (a.lastConnected || 0));
        }
        return copy;
    }

    function commentFor(h) {
        const age = formatAge(h.lastConnected);
        const freq = (h.count || 0) > 1
            ? h.count + " connects"
            : (h.count || 0) === 1 ? "first connect" : "never connected";
        return sortMode === "frequency"
            ? freq + " · " + age
            : age + " · " + freq;
    }

    // The probe runs with BatchMode=yes, so password auth can never succeed and
    // reports exit 255. Distinguish "typo or unreachable" from "reached a real
    // SSH server that just needs a password" by what ssh wrote to stderr.
    function reachedServer(probeError) {
        const e = (probeError || "").toLowerCase();
        if (e.indexOf("permission denied") !== -1)
            return true;
        if (e.indexOf("host key verification") !== -1)
            return true;
        if (e.indexOf("remote host identification has changed") !== -1)
            return true;
        if (e.indexOf("userauth") !== -1)
            return true;
        return false;
    }

    function connectTo(host) {
        if (!host)
            return;
        if (probeProcess.running) {
            showToast("SSH Plus", "Another connection is still being checked");
            return;
        }
        if (probeEnabled) {
            probeProcess.pendingHost = host.toLowerCase();
            probeProcess.probeError = "";
            probeProcess.command = [
                sshCommand,
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=" + connectTimeout,
                host.toLowerCase(),
                "true"
            ];
            probeProcess.running = true;
        } else {
            recordSuccess(host);
            launchTerminal(host);
        }
    }

    function recordSuccess(host) {
        const h = host.toLowerCase();
        let rec = hosts.find(x => x.host === h);
        if (!rec) {
            rec = { host: h, lastConnected: 0, count: 0 };
            hosts.unshift(rec);
        }
        rec.lastConnected = Date.now();
        rec.count = (rec.count || 0) + 1;
        if (hosts.length > maxHosts)
            hosts = hosts.slice(0, maxHosts);
        saveHosts();
    }

    function removeHost(host) {
        const h = host.toLowerCase();
        const before = hosts.length;
        hosts = hosts.filter(x => x.host !== h);
        if (hosts.length !== before)
            saveHosts();
        showToast("SSH Plus", before === hosts.length ? h + " was not recorded" : "Removed " + h);
    }

    function clearHosts() {
        hosts = [];
        if (pluginService)
            pluginService.clearPluginState(pluginName);
        itemsChanged();
        showToast("SSH Plus", "History cleared");
    }

    function saveHosts() {
        if (pluginService)
            pluginService.savePluginState(pluginName, "hosts", hosts);
        itemsChanged();
    }

    function launchTerminal(host) {
        const command = terminal.split(" ").concat(
            "-e", "sh", "-lc", sshCommand + " " + host
        );
        const scoped = scopeLaunch && hasSystemdRun
            ? ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--"].concat(command)
            : command;
        console.info(pluginName + ": launching " + scoped.join(" "));
        Quickshell.execDetached(scoped);
    }

    function formatAge(timestamp) {
        if (!timestamp)
            return "never";
        const seconds = Math.floor((Date.now() - timestamp) / 1000);
        if (seconds < 60)
            return "just now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return minutes + "m ago";
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h ago";
        const days = Math.floor(hours / 24);
        return days + "d ago";
    }

    function showToast(title, message) {
        if (typeof ToastService !== "undefined")
            ToastService.showInfo(title, message);
    }
}
