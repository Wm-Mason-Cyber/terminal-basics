#!/usr/bin/env bash
# grade_lxc.sh — grade Part 2 (the shared server) for every student, on a Proxmox node
#
# Usage (as root, on the node hosting the containers):
#   ./infra/proxmox/grade_lxc.sh infra/students.csv        # all periods
#   ./infra/proxmox/grade_lxc.sh infra/students.csv 3      # period 3 only
#
# For each period container it runs `quest.sh grade-all p<period>`, which checks
# each student's progress AND re-verifies the files they made (dropbox file
# group/permissions, about_me.txt, flag, …) as that student.
#
# Output: grades_report_server.csv (overwrites)
#   username,period,lab_id,passed_assertions,failed_assertions,grade_percentage
# ERR_OFFLINE = container not running on this node · ERR_NOACCOUNT = no account in the container

set -euo pipefail

ROSTER="${1:?Usage: $0 students.csv [period]}"
PERIOD_FILTER="${2:-}"
VMID_BASE="${VMID_BASE:-7000}"
LAB_ID="terminal_basics_server"
OUT="grades_report_server.csv"

declare -A RESULT     # username → "passed,failed"
declare -A CHECKED    # period → 1 (grade-all ran) | offline

echo "username,period,lab_id,passed_assertions,failed_assertions,grade_percentage" > "$OUT"

while IFS=, read -r username _ _ _ period _; do
    username="${username//[$'\r\xef\xbb\xbf ']/}"
    [[ "$username" == "username" || -z "$username" ]] && continue
    period="${period//[$'\r ']/}"
    [[ -n "$PERIOD_FILTER" && "$period" != "$PERIOD_FILTER" ]] && continue

    vmid=$(( VMID_BASE + period ))
    if [[ -z ${CHECKED[$period]:-} ]]; then
        if [[ $(pct status "$vmid" 2>/dev/null) == *running* ]]; then
            echo "[GRADE] period $period (CT $vmid)"
            while IFS=, read -r u p f; do
                [[ -n $u ]] && RESULT[$u]="$p,$f"
            done < <(pct exec "$vmid" -- bash /opt/terminal-quest/quest.sh grade-all "p$period" 2>/dev/null || true)
            CHECKED[$period]=1
        else
            echo "[SKIP]  period $period — CT $vmid not running on this node"
            CHECKED[$period]=offline
        fi
    fi

    if [[ ${CHECKED[$period]} == offline ]]; then
        echo "${username},${period},${LAB_ID},0,0,ERR_OFFLINE" >> "$OUT"
        continue
    fi
    if [[ -z ${RESULT[$username]:-} ]]; then
        echo "${username},${period},${LAB_ID},0,0,ERR_NOACCOUNT" >> "$OUT"
        continue
    fi

    IFS=, read -r passed failed <<<"${RESULT[$username]}"
    total=$(( passed + failed ))
    pct=$(awk -v p="$passed" -v t="$total" 'BEGIN { printf "%.1f", t ? p / t * 100 : 0 }')
    echo "${username},${period},${LAB_ID},${passed},${failed},${pct}" >> "$OUT"
done < "$ROSTER"

echo ""
echo "Compiled: $OUT"
column -t -s, "$OUT"
