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
- Sort recorded hosts by **most recent** or **most frequent** connection.
- Remove hosts with `ssh: rm <host>`, or right-click/Tab a host in the results
  and choose *Remove from history*.
- `ssh: clear` wipes all recorded hosts.
- SSH sessions run in a transient systemd user scope, so **restarting DMS does
  not kill them**.

## Requirements

- DankMaterialShell >= 1.5.0 (uses the plugin state API)
- `ssh`
- A terminal with `-e` support (ghostty, kitty, ...)
- `systemd-run` (optional; the plugin falls back to a plain detached launch)

## Install

```sh
./install.sh
dms ipc call plugins reload sshPlus
```

The script symlinks this repository into the DMS plugins directory. If you
prefer a pinned deployment, copy or version-pin the repo and update the symlink
yourself.

## Usage

| Query | Result |
| --- | --- |
| `ssh:` | Recorded hosts, most recent first |
| `ssh: docker` | Filtered recorded hosts matching `docker` |
| `ssh: newhost.lan` | "SSH to: newhost.lan" — connect and record on success |
| `ssh: rm newhost.lan` | Remove a host from history |
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
- **Sort Recorded Hosts** — `Most recent` or `Most frequent`
- **Verify Before Recording** — run the BatchMode success check
- **Connect Timeout** — seconds allowed for the success check
- **Maximum Recorded Hosts** — cap on the history size
- **Launch in Systemd Scope** — keep sessions alive across DMS restarts

See [docs/DESIGN.md](docs/DESIGN.md) for the design rationale.
