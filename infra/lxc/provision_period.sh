#!/usr/bin/env bash
# provision_period.sh — set up ONE class period's shared server (run INSIDE the LXC as root)
#
# Usually called for you by infra/proxmox/create_period_lxc.sh. To run by hand:
#   bash provision_period.sh /root/students.csv 1
#
# Safe to re-run: existing accounts get their roster password re-applied, and
# student work is never deleted.
#
# What it does:
#   * installs the tools the lab uses (ssh server, nano, less, man, ip, ps, …)
#   * creates group p<period>, one account per roster row in that period
#     (home folders chmod 700), plus a locked "instructor" account
#   * builds /srv/class/p<period> (shared dropbox) and /srv/class/shared (log + hidden flag)
#   * installs Terminal Quest to /opt/terminal-quest (server track) and hooks it
#     into every interactive bash via /etc/bash.bashrc
#   * sets the ssh login banner + MOTD and silences Debian's default MOTD
#
# Env:  SKIP_APT=1  skip package installation (offline testing)

set -euo pipefail

ROSTER="${1:?Usage: $0 students.csv <period>}"
PERIOD="${2:?Usage: $0 students.csv <period>}"
[[ $PERIOD =~ ^[0-9]+$ ]] || { echo "period must be a number"; exit 1; }
(( EUID == 0 )) || { echo "run as root"; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GROUP="p${PERIOD}"
CLASS=/srv/class
DROPBOX="$CLASS/$GROUP"
SHARED="$CLASS/shared"
INSTALL=/opt/terminal-quest
INSTRUCTOR_USER="${INSTRUCTOR_USER:-instructor}"

echo "[provision] Period $PERIOD → group $GROUP"

# ── Packages ──────────────────────────────────────────────────────────────────
if [[ -z ${SKIP_APT:-} ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get install -y -q \
        openssh-server sudo nano less man-db manpages \
        iproute2 procps findutils grep coreutils psmisc \
        bash-completion locales
    # keep /var/lib/apt/lists so students can `apt show` / `apt search` offline
fi

# ── Group + accounts ──────────────────────────────────────────────────────────
getent group "$GROUP" >/dev/null || groupadd "$GROUP"

created=0 updated=0
while IFS=, read -r username password first_name last_name period student_id grade_level; do
    username="${username//[$'\r\xef\xbb\xbf ']/}"
    [[ "$username" == "username" || -z "$username" ]] && continue
    period="${period//[$'\r ']/}"
    [[ "$period" == "$PERIOD" ]] || continue
    password="${password%$'\r'}"

    if id "$username" &>/dev/null; then
        updated=$(( updated + 1 ))
    else
        useradd -m -s /bin/bash -c "${first_name} ${last_name}" "$username"
        created=$(( created + 1 ))
    fi
    usermod -aG "$GROUP" "$username"
    printf '%s:%s\n' "$username" "$password" | chpasswd
    chmod 700 "/home/$username"
done < "$ROSTER"
echo "[provision] Accounts: $created created, $updated already existed"

# Locked account so every student has a private home to (fail to) peek into.
if ! id "$INSTRUCTOR_USER" &>/dev/null; then
    useradd -m -s /usr/sbin/nologin -c "Instructor" "$INSTRUCTOR_USER"
    passwd -l "$INSTRUCTOR_USER" >/dev/null
fi
chmod 700 "/home/$INSTRUCTOR_USER"

# New accounts made later (e.g. by hand) also get private homes.
sed -i 's/^#\?\s*HOME_MODE.*/HOME_MODE 0700/' /etc/login.defs
grep -q '^HOME_MODE' /etc/login.defs || echo 'HOME_MODE 0700' >> /etc/login.defs

# ── Shared class folders ──────────────────────────────────────────────────────
mkdir -p "$DROPBOX" "$SHARED/archive/.vault" "$SHARED/archive/locked"
chown root:root "$CLASS" "$SHARED"
chmod 755 "$CLASS" "$SHARED" "$SHARED/archive" "$SHARED/archive/.vault"

# Dropbox: group can add files; sticky bit (the 1) stops people deleting each other's.
chown root:"$GROUP" "$DROPBOX"
chmod 1770 "$DROPBOX"

cat > "$DROPBOX/welcome.txt" <<EOF
Hello, period ${PERIOD}!

If you can read this, group permissions are working:
this file belongs to root, its group is ${GROUP}, and its mode is 640 (rw-r-----).
Students in other periods can't read it. Only your group can.
EOF
chown root:"$GROUP" "$DROPBOX/welcome.txt"
chmod 640 "$DROPBOX/welcome.txt"

# A folder find can't enter, so students see a real "Permission denied".
printf 'admins only\n' > "$SHARED/archive/locked/readme.txt"
chmod 700 "$SHARED/archive/locked"

# Hidden flag; value made once per server and kept on re-runs.
if [[ ! -s $SHARED/archive/.vault/server.flag ]]; then
    printf 'You found the server flag!\nFLAG: QUEST{%s}\n' "$(head -c 64 /dev/urandom | sha256sum | cut -c1-10)" \
        > "$SHARED/archive/.vault/server.flag"
fi
chmod 644 "$SHARED/archive/.vault/server.flag"

# Server log with INFO/WARN/ALERT lines for tail/head/grep practice.
awk -v p="$PERIOD" 'BEGIN {
    svc[0]="sshd"; svc[1]="cron"; svc[2]="backup"; svc[3]="nginx"
    for (i = 0; i < 180; i++) {
        t = 7*3600 + i*97
        ts = sprintf("2026-10-01 %02d:%02d:%02d", int(t/3600), int(t%3600/60), t%60)
        if (i % 23 == 7)      lvl = "ALERT"
        else if (i % 9 == 4)  lvl = "WARN"
        else                  lvl = "INFO"
        s = svc[i % 4]
        if (lvl == "ALERT")     msg = "repeated failed logins from 203.0.113." (i%50)
        else if (lvl == "WARN") msg = "disk usage at " (70 + i%25) "%"
        else                    msg = "routine check ok (period " p ")"
        printf "%s %-5s %-6s %s\n", ts, lvl, s, msg
    }
}' > "$SHARED/server.log"
chmod 644 "$SHARED/server.log"

# ── Terminal Quest (server track) ─────────────────────────────────────────────
rm -rf "$INSTALL"
mkdir -p "$INSTALL"
cp -r "$REPO/quest/." "$INSTALL/"
echo server > "$INSTALL/track"
cat > "$INSTALL/server.conf" <<EOF
TQ_PERIOD=$PERIOD
TQ_GROUP=$GROUP
TQ_DROPBOX=$DROPBOX
TQ_SHARED=$SHARED
EOF
chmod -R a+rX "$INSTALL"
ln -sf "$INSTALL/quest.sh" /usr/local/bin/quest.sh

HOOK='[ -r /opt/terminal-quest/quest.sh ] && . /opt/terminal-quest/quest.sh   # Terminal Quest'
grep -qF 'Terminal Quest' /etc/bash.bashrc || printf '\n%s\n' "$HOOK" >> /etc/bash.bashrc

# ── Login banner + MOTD ───────────────────────────────────────────────────────
sed "s/__PERIOD__/$PERIOD/g" "$REPO/infra/lxc/login_banner" > /etc/ssh/login_banner
sed "s/__PERIOD__/$PERIOD/g" "$REPO/infra/lxc/motd" > /etc/motd
rm -f /etc/update-motd.d/* 2>/dev/null || true

# ── SSH ───────────────────────────────────────────────────────────────────────
if [[ -d /etc/ssh ]]; then
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/terminal-quest.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
PermitRootLogin no
Banner /etc/ssh/login_banner
PrintLastLog no
EOF
    if command -v systemctl >/dev/null && systemctl is-system-running &>/dev/null; then
        systemctl enable --now ssh >/dev/null 2>&1 || true
        systemctl restart ssh || true
    else
        service ssh restart >/dev/null 2>&1 || true
    fi
fi

echo "[provision] Done. Students in period $PERIOD can now: ssh <username>@$(hostname -I 2>/dev/null | awk '{print $1}')"
