# DMS SSH Plus

A DankMaterialShell launcher plugin for SSH that remembers the hosts you
actually connect to. Type `ssh:` in the launcher to connect to any host, and
the plugin records the ones that connect successfully with their last-used
time and connection count.

## Features

- `ssh: <host>` connects to any host, including ones never seen before.
- Successful connections are recorded automatically — the plugin runs a quick
  `BatchMode` check first, so typos and unreachable hosts are not saved.
- Each recorded host shows its last connection time and connection count.
- Sort recorded hosts by **most frequent** (default) or **most recent** connection.
- Remove hosts with `ssh: rm <host>`, or right-click/Tab a host in the results
  and choose *Remove from history*.
- `ssh: clear` wipes all recorded hosts.
- When enabled and available, SSH sessions run in a transient systemd user
  scope, so restarting DMS does not kill them; otherwise the plugin falls back
  to a detached launch.

## Requirements

- DankMaterialShell >= 1.5.0 (uses the plugin state API)
- `ssh`
- A terminal binary with `-e` support; `ghostty` is only the fallback default
- `systemd-run` (optional; the plugin falls back to a plain detached launch)

## Install

```sh
./install.sh
dms ipc call plugins reload sshPlus
```

`install.sh` is the development install: it creates a symlink from the DMS
plugins directory to this checkout. For a pinned deployment, copy or
version-pin the repository into the plugin directory yourself and update that
deployment separately. The script refuses to replace an existing real plugin
directory, so it cannot overwrite a pinned copy. The live deployment used for
the observations below is a manually pinned/copy deployment, not the
development symlink.

## Usage

| Query | Result |
| --- | --- |
| `ssh:` | Recorded hosts, most frequent first |
| `ssh: web` | Filtered recorded hosts matching `web` |
| `ssh: host.example` | "SSH to: host.example" — connect and record on success |
| `ssh: rm host.example` | Remove a host from history |
| `ssh: clear` | Remove all recorded hosts |

When the check confirms the host is reachable, it is recorded and the terminal
opens with `ssh <host>`. Key-based logins record because authentication
succeeded; password logins record because the probe reached a real SSH server
(after all, `BatchMode` can never satisfy a password prompt). Typos and
unreachable hosts are not recorded. If the check fails the terminal still
opens. Disable the check in settings to record every launch attempt.

Hosts are stored in `~/.local/state/DankMaterialShell/plugins/sshPlus_state.json`
via the DMS state API.

## Settings

- **Trigger Prefix** — launcher trigger (default `ssh:`)
- **Terminal** — terminal binary used to host the session
- **SSH Command** — binary used to connect
- **Sort Recorded Hosts** — `Most frequent` (default) or `Most recent`
- **Verify Before Recording** — run the BatchMode success check
- **Connect Timeout** — seconds allowed for the success check
- **Maximum Recorded Hosts** — cap on the history size
- **Launch in Systemd Scope** — keep sessions alive across DMS restarts

## Validation status

The implemented plugin was observed running under DMS 1.5.3 on 2026-08-18:
`sshPlus` loaded, the state file contained one host, the current boot loaded
the plugin cleanly, and journal evidence showed launches through systemd user
scopes. The deployed pinned/copy directory matched this checkout at the time
of those observations.

Those observations cover startup and ordinary use. They are not a fresh test
of surviving a deliberately triggered DMS restart, every probe failure
classification, or interactive password authentication. Run `./scripts/check`
for deterministic repository validation; it checks manifest structure and
paths, shell syntax, and diff whitespace. It does not provide QML semantic or
live DMS validation. When a DMS/Quickshell import environment is available,
run `qmllint` on both QML files separately.

See [docs/DESIGN.md](docs/DESIGN.md) for the design rationale.
