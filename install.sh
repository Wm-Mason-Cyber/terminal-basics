#!/usr/bin/env bash
# install.sh — install Terminal Quest (local track) for the current user.
#
# Students run ONE of these in their WSL (Debian/Ubuntu) terminal:
#   bash ~/terminal-basics/install.sh                  # after git clone
#   curl -fsSL https://raw.githubusercontent.com/Wm-Mason-Cyber/terminal-basics/main/install.sh | bash
#
# It copies the tutor to ~/.terminal-quest/app, makes sure the commands the
# lab uses are installed, asks for the student's school username (used to
# name the turn-in report), and adds one line to ~/.bashrc.
#
# Uninstall: delete the "Terminal Quest" line from ~/.bashrc and rm -rf ~/.terminal-quest ~/quest

set -euo pipefail

REPO_TARBALL="${TQ_REPO_TARBALL:-https://github.com/Wm-Mason-Cyber/terminal-basics/archive/refs/heads/main.tar.gz}"
APP="$HOME/.terminal-quest/app"

say() { printf '\033[1;35m[quest]\033[0m %s\n' "$*"; }

# ── Find the quest files (next to this script, or download them) ──────────────
SRC=""
if [[ -n ${BASH_SOURCE[0]:-} && -f "$(dirname "${BASH_SOURCE[0]}")/quest/quest.sh" ]]; then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/quest"
else
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    say "Downloading Terminal Quest..."
    if command -v curl >/dev/null; then
        curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP"
    else
        wget -qO- "$REPO_TARBALL" | tar -xz -C "$TMP"
    fi
    SRC=$(find "$TMP" -maxdepth 2 -type d -name quest | head -1)
    [[ -f $SRC/quest.sh ]] || { say "Download failed. Ask your teacher for help."; exit 1; }
fi

# ── Make sure the lab's commands exist ────────────────────────────────────────
declare -A PKG=( [nano]=nano [less]=less [man]=man-db [ssh]=openssh-client
                 [ip]=iproute2 [ps]=procps [find]=findutils [hostname]=hostname )
missing=()
for cmd in "${!PKG[@]}"; do
    command -v "$cmd" >/dev/null || missing+=("${PKG[$cmd]}")
done
if (( ${#missing[@]} )); then
    say "Installing a few tools the quest needs: ${missing[*]}"
    say "Type your Linux password if asked (nothing shows while you type — that's normal)."
    if ! { sudo apt-get update -q && sudo apt-get install -y -q "${missing[@]}"; } </dev/tty; then
        say "Couldn't install ${missing[*]}. You can still start; some tasks may not work."
    fi
fi

# ── Copy the tutor ────────────────────────────────────────────────────────────
rm -rf "$APP"
mkdir -p "$APP"
cp -r "$SRC/." "$APP/"
echo local > "$APP/track"

# ── School username (names the turn-in report) ────────────────────────────────
CONFIG="$HOME/.terminal-quest/config"
if [[ ! -s $CONFIG ]]; then
    u=""
    while [[ ! $u =~ ^[A-Za-z0-9._-]+$ ]]; do
        read -r -p "$(printf '\033[1;35m[quest]\033[0m ')What is your school username (the one your teacher gave you)? " u </dev/tty
    done
    printf 'school_user=%s\n' "$u" > "$CONFIG"
fi

# ── Hook into bash ────────────────────────────────────────────────────────────
LINE='[ -r "$HOME/.terminal-quest/app/quest.sh" ] && . "$HOME/.terminal-quest/app/quest.sh"   # Terminal Quest'
touch "$HOME/.bashrc"
grep -qF '# Terminal Quest' "$HOME/.bashrc" || printf '\n%s\n' "$LINE" >> "$HOME/.bashrc"

say "Installed! Close this terminal window and open it again to start your quest."
