# Design: SSH Plus

Status: initial scaffold, not yet validated live.

## Problem

The registry `sshConnections` plugin only remembers hosts you type while the
launcher is open (it records on *execute*, before the connection succeeds), and
it loses that history unless the host is also in the configured server list. It
offers no per-host metadata (no timestamps or counts, no sorting), no way to
remove a host, and it launches via `Quickshell.execDetached` directly. Because
`dms.service` uses `KillMode=control-group`, any SSH process started that way is
a child of the DMS unit and is killed when DMS restarts.

Goals:

- `ssh: <host>` to connect to any host, recorded or not.
- Record hosts only after a *successful* connection.
- Track `lastConnected` and a connection `count` per host.
- Sort by recency or frequency.
- Remove hosts from the picker (`ssh: rm <host>` and context menu).
- Launch sessions so restarting DMS does not kill them.

## Architecture

Single launcher plugin, QML only. No helper binary: probing is a
`Quickshell.Io.Process`, launching is `Quickshell.execDetached` wrapped in
`systemd-run`, and state uses the DMS plugin state API.

### State vs settings

Recorded hosts are runtime data, so they use the **state API**
(`savePluginState` / `loadPluginState`), stored at
`~/.local/state/DankMaterialShell/plugins/sshPlus_state.json`. This keeps the
growing history out of the user-editable `plugin_settings.json`, and state
writes are atomic and debounced by the platform.

Each record: `{ "host": "docker.lan", "lastConnected": 1722743000123, "count": 5 }`

Settings (`plugin_settings.json`) hold only preferences: trigger, terminal,
ssh command, sort mode, probe toggle, timeouts, history cap, and the systemd
scope toggle.

### Success detection: pre-flight BatchMode probe

"Recorded only if the connection succeeded" is implemented as a probe run
before the terminal opens:

```
ssh -o BatchMode=yes -o ConnectTimeout=<N> <host> true
```

`BatchMode=yes` forbids interactive password prompts, so the probe either
completes (key-based auth, exit 0) or fails fast (exit 255) without hanging on
a prompt. Exit code alone cannot separate the failure causes — a typo, an
unreachable host, and a password-protected login all return 255. So the probe
captures stderr and classifies:

- **Record** when the probe exits 0, or when stderr shows the probe reached a
  real SSH server: `Permission denied`, `Host key verification failed`,
  `Remote host identification has changed`, or `userauth` errors. Password
  logins are therefore recorded — the gate is "a real server answered", not
  "key auth succeeded".
- **Do not record** for anything else: DNS resolution failures, connection
  refused, no route, timeouts. This is the typo guard the gate exists for.

Then the terminal opens regardless (the user asked to connect), with an
informative toast only when the host was not recorded.

Costs and trade-offs:

- Adds up to `ConnectTimeout` seconds (default 2) before the terminal appears.
- The stderr classification is heuristic. A genuine typo that resolves to a
  different real SSH server would be recorded (stderr shows host-key/auth
  markers); the terminal will prompt about the unknown host key on first
  connect, so the error is visible. The probe can be disabled in settings,
  which degrades to record-on-launch.

An alternative considered — watching the ssh process lifetime and recording if
it survives past a grace period — avoids the pre-open latency but conflates "the
user left the session open" with "the connection succeeded", cannot distinguish
a hung connection, and needs a watcher process. Rejected.

### Launch and process ownership

`dms.service` has `KillMode=control-group`, so a plain `execDetached` child is
torn down with the unit. To escape that, the terminal is launched through a
transient systemd user scope:

```
systemd-run --user --scope --collect --quiet -- <terminal> -e sh -lc "ssh <host>"
```

`--scope` starts the command as a scope unit owned by the systemd user manager
(`systemd --user`, which DMS already runs under), independent of `dms.service`.
Restarting or reloading DMS therefore leaves the SSH session running.
`systemd-run` availability is probed once at load; when absent the plugin falls
back to a plain detached launch (new session, but still in the DMS unit's
cgroup — no better option without systemd).

### Ordering

`sort_mode` selects between:

- `recency` — `lastConnected` descending (default).
- `frequency` — `count` descending, ties broken by `lastConnected`.

Hosts render with the count as a badge and a comment like `2h ago · 5 connects`
(order swaps under frequency sorting). The result list caps at 20 visible rows.

### Removal

Two surfaces:

1. `ssh: rm <host>` — textual command parsed in `getItems`/`executeItem`
   (`remove:` action). Also `ssh: clear` for a full wipe.
2. Context menu — recorded-host items carry `_host`; `getContextMenuActions`
   returns a *Remove from history* action.

## Out of scope

- SSH argument passthrough (per-host options, ports, jump hosts) beyond what
  `~/.ssh/config` already expresses.
- Editing host records (names/aliases) or pinning hosts so they cannot be
  removed.
- Discovery of configured `~/.ssh/config` Host entries — the history grows
  organically from successful connections.
