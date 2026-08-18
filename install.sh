#!/usr/bin/env sh
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
plugin_dir=${HOME}/.config/DankMaterialShell/plugins

# This command intentionally installs a development symlink. Pinned or copied
# deployments are managed separately so this checkout can be iterated safely.
mkdir -p "$plugin_dir"
if [ -e "$plugin_dir/sshPlus" ] && [ ! -L "$plugin_dir/sshPlus" ]; then
    printf '%s\n' "sshPlus is an existing directory; update its pinned deployment instead" >&2
    exit 1
fi
ln -sfn "$repo_dir" "$plugin_dir/sshPlus"

printf 'Installed development symlink %s -> %s\n' "$plugin_dir/sshPlus" "$repo_dir"
