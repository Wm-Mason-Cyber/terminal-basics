#!/usr/bin/env bash
# create_period_lxc.sh — create + provision one Terminal Quest server per class period
#
# Run ON a Proxmox node, as root, from a copy of this repo:
#   ./infra/proxmox/create_period_lxc.sh infra/students.csv 1 3 5     # periods 1, 3 and 5
#   ./infra/proxmox/create_period_lxc.sh infra/students.csv all       # every period in the roster
#
# Re-running is safe: an existing container is started (if stopped) and re-provisioned.
# Student work inside it is kept.
#
# Settings (environment variables, defaults shown):
#   VMID_BASE=7000          container ID = VMID_BASE + period   (period 1 → 7001)
#   STORAGE=local-lvm       storage for the container disk
#   TEMPLATE_STORAGE=local  storage holding LXC templates
#   BRIDGE=vmbr0            network bridge
#   IP_TEMPLATE=dhcp        or a static address with {P} for the period, e.g. 10.20.0.1{P}/24
#   GATEWAY=                required when IP_TEMPLATE is static
#   MEMORY=2048  CORES=2  DISK=8   (GB)
#
# Output: infra/out/ssh_info_p<period>.txt (server address + per-student ssh commands)

set -euo pipefail

ROSTER="${1:?Usage: $0 students.csv <period...|all>}"
shift
[[ $# -gt 0 ]] || { echo "Usage: $0 students.csv <period...|all>"; exit 1; }
[[ -f $ROSTER ]] || { echo "Roster not found: $ROSTER"; exit 1; }
command -v pct >/dev/null || { echo "pct not found: run this on a Proxmox node"; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VMID_BASE="${VMID_BASE:-7000}"
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_TEMPLATE="${IP_TEMPLATE:-dhcp}"
GATEWAY="${GATEWAY:-}"
MEMORY="${MEMORY:-2048}"
CORES="${CORES:-2}"
DISK="${DISK:-8}"
OUT_DIR="$REPO/infra/out"
mkdir -p "$OUT_DIR"

# ── Which periods? ────────────────────────────────────────────────────────────
roster_periods() {
    tail -n +2 "$ROSTER" | cut -d, -f5 | tr -d '\r ' | grep -E '^[0-9]+$' | sort -un
}
if [[ $1 == all ]]; then
    mapfile -t PERIODS < <(roster_periods)
else
    PERIODS=("$@")
fi
echo "Periods: ${PERIODS[*]}"

# ── Debian 12 template ────────────────────────────────────────────────────────
pveam update >/dev/null || echo "WARN: pveam update failed; using cached template list"
TEMPLATE=$(pveam list "$TEMPLATE_STORAGE" | awk '{print $1}' | grep -o 'debian-12-standard[^ ]*' | sort -V | tail -1 || true)
if [[ -z $TEMPLATE ]]; then
    TEMPLATE=$(pveam available --section system | awk '{print $2}' | grep '^debian-12-standard' | sort -V | tail -1)
    [[ -n $TEMPLATE ]] || { echo "No debian-12-standard template available"; exit 1; }
    echo "Downloading $TEMPLATE ..."
    pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
fi
OSTEMPLATE="$TEMPLATE_STORAGE:vztmpl/$TEMPLATE"
echo "Template: $OSTEMPLATE"

# Bundle the repo bits the container needs.
BUNDLE=$(mktemp --suffix=.tgz)
trap 'rm -f "$BUNDLE"' EXIT
tar -czf "$BUNDLE" -C "$REPO" quest infra/lxc

for P in "${PERIODS[@]}"; do
    VMID=$(( VMID_BASE + P ))
    NAME="quest-p${P}"
    echo ""
    echo "════ Period $P → CT $VMID ($NAME) ════"

    if ! grep -q "^[^,]*,[^,]*,[^,]*,[^,]*,${P}," <(tr -d '\r' < "$ROSTER"); then
        echo "  No students in period $P — skipping."
        continue
    fi

    if pct status "$VMID" &>/dev/null; then
        echo "  Container exists."
    else
        if [[ $IP_TEMPLATE == dhcp ]]; then
            NET="name=eth0,bridge=$BRIDGE,ip=dhcp"
        else
            [[ -n $GATEWAY ]] || { echo "GATEWAY is required with a static IP_TEMPLATE"; exit 1; }
            NET="name=eth0,bridge=$BRIDGE,ip=${IP_TEMPLATE//\{P\}/$P},gw=$GATEWAY"
        fi
        echo "  Creating..."
        pct create "$VMID" "$OSTEMPLATE" \
            --hostname "$NAME" \
            --description "Terminal Quest shared server — period $P" \
            --cores "$CORES" --memory "$MEMORY" --swap 512 \
            --rootfs "$STORAGE:$DISK" \
            --net0 "$NET" \
            --unprivileged 1 --features nesting=1 \
            --onboot 1 \
            --password "$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
    fi

    [[ $(pct status "$VMID") == *running* ]] || pct start "$VMID"

    echo -n "  Waiting for network"
    for _ in $(seq 1 30); do
        pct exec "$VMID" -- getent hosts deb.debian.org &>/dev/null && break
        echo -n "."; sleep 2
    done
    echo ""

    pct push "$VMID" "$BUNDLE" /root/terminal-quest.tgz
    pct push "$VMID" "$ROSTER" /root/students.csv
    pct exec "$VMID" -- bash -c '
        set -e
        rm -rf /root/terminal-basics && mkdir -p /root/terminal-basics
        tar -xzf /root/terminal-quest.tgz -C /root/terminal-basics
        bash /root/terminal-basics/infra/lxc/provision_period.sh /root/students.csv '"$P"'
        rm -f /root/students.csv /root/terminal-quest.tgz   # roster holds passwords
    '

    IP=$(pct exec "$VMID" -- hostname -I | awk '{print $1}')
    INFO="$OUT_DIR/ssh_info_p${P}.txt"
    {
        echo "Terminal Quest server — period $P"
        echo "Container: $VMID ($NAME)   Address: $IP"
        echo ""
        while IFS=, read -r username _ first last period _; do
            username="${username//[$'\r\xef\xbb\xbf ']/}"
            period="${period//[$'\r ']/}"
            [[ "$username" == "username" || -z "$username" || "$period" != "$P" ]] && continue
            printf '  %-22s ssh %s@%s\n' "$first $last" "$username" "$IP"
        done < "$ROSTER"
    } > "$INFO"
    echo "  Ready at $IP  →  $INFO"
done
