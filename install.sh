#!/usr/bin/env bash

DATA_DIR="${DATA_DIR:-/var/upaas}"

set -e

if [[ "`id -u`" == "0" && "$1" != "-f" ]]; then
    echo "WARNING: You are root; if you are not planning to use ports below 1024 you do not have to be root!"
    echo "Are you sure you want to continue as root? y/[n]"
    read -r -n 1 -s answer
    test "$answer" = "y"
fi

test -v DEBUG && set -x

mkdir -p "$DATA_DIR/src"

# check if nix is available
hash nix-env 2>/dev/null \
    || { echo "Nix is not available in PATH (Do you have it installed? To install Nix, execute as user: 'curl https://nixos.org/nix/install | sh')"; false; }

test -d "$DATA_DIR/src" || { echo "$DATA_DIR/src does not exist or is not a directory!"; false; }
test -w "$DATA_DIR/src" || { echo "$DATA_DIR/src is not writable by `id -un`!"; false; }

cp -fauv ./* "$DATA_DIR/src"

nix-env -f "$DATA_DIR/src/default.nix" -A env --argstr dataDir "$DATA_DIR" --argstr user "`id -un`" -i --show-trace \
    && echo -e "\nExecute 'upaas-rebuild ./some/config.nix' to rebuild the environment from config file"
