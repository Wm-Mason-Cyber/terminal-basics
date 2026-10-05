#!/usr/bin/env bash
# Terminal Quest — a guided, self-checking intro to the Linux terminal.
#
# Sourced from ~/.bashrc (WSL) or /etc/bash.bashrc (class server):
#     . /path/to/quest.sh        → loads the tutor into the interactive shell
# Run directly for non-interactive jobs:
#     bash quest.sh verify       → PASS/FAIL per task for the current user
#     bash quest.sh verify --csv → "passed,failed"
#     bash quest.sh grade-all p1 → (root, server) one CSV line per member of group p1

TQ_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ -z ${TQ_TRACK:-} ]]; then
    TQ_TRACK=local
    [[ -r $TQ_ROOT/track ]] && TQ_TRACK=$(head -1 "$TQ_ROOT/track")
fi
# Server settings (period, group, shared folders) written by the provisioner.
# shellcheck source=/dev/null
[[ -r $TQ_ROOT/server.conf ]] && . "$TQ_ROOT/server.conf"

# shellcheck source=lib/engine.sh
. "$TQ_ROOT/lib/engine.sh"
# shellcheck source=/dev/null
. "$TQ_ROOT/tracks/$TQ_TRACK.sh"
_tq_init

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    # Sourced: only hook into interactive shells.
    if [[ $- == *i* ]]; then
        _tq_run track init
        _tq_install_hook
    fi
else
    quest "$@"
fi
