#!/usr/bin/env bash
# grade_local_reports.sh — grade Part 1 (local / WSL) from the reports students upload
#
# Workflow:
#   1. Students finish the local quest, run `quest report`, and upload
#      terminal_quest_report_<username>.txt to Schoology.
#   2. Bulk-download the submissions into one folder (any file names are fine;
#      the username is read from inside each report).
#   3. ./infra/grading/grade_local_reports.sh ~/Downloads/quest_reports infra/students.csv
#
# Output: grades_report_local.csv (overwrites)
#   username,period,lab_id,passed_assertions,failed_assertions,grade_percentage
#   ERR_TAMPERED = report was edited after it was generated (verification code mismatch)
#   ERR_MISSING  = student on the roster with no report
#
# The verification code makes edits obvious; it does not make them impossible.
# Spot-check the command log section of any report that looks too perfect.

set -euo pipefail

REPORTS_DIR="${1:?Usage: $0 <reports_dir> students.csv}"
ROSTER="${2:?Usage: $0 <reports_dir> students.csv}"
LAB_ID="terminal_basics_local"
OUT="grades_report_local.csv"
SALT="terminal-quest:wm-mason-cyber:v1"   # must match TQ_SALT in quest/lib/engine.sh

declare -A period_of seen
while IFS=, read -r username _ _ _ period _; do
    username="${username//[$'\r\xef\xbb\xbf ']/}"
    [[ "$username" == "username" || -z "$username" ]] && continue
    period_of["$username"]="${period//[$'\r ']/}"
done < "$ROSTER"

echo "username,period,lab_id,passed_assertions,failed_assertions,grade_percentage" > "$OUT"

shopt -s nullglob
for report in "$REPORTS_DIR"/*.txt; do
    content=$(tr -d '\r' < "$report")
    grep -q '^  Terminal Quest — local track' <<<"$content" || continue

    username=$(sed -n 's/^  School username: *//p' <<<"$content" | head -1)
    period="${period_of[$username]:-unknown}"
    claimed=$(sed -n 's/^Verification: *//p' <<<"$content" | tail -1)
    body=$(sed '/^Verification: /,$d' <<<"$content")
    actual=$(printf '%s\n%s' "$body" "$SALT" | sha256sum | cut -d' ' -f1)

    passed=$(grep -c '^  PASS  ' <<<"$body" || true)
    failed=$(grep -c '^  FAIL  ' <<<"$body" || true)
    total=$(( passed + failed ))
    pct=$(awk -v p="$passed" -v t="$total" 'BEGIN { printf "%.1f", t ? p / t * 100 : 0 }')

    if [[ "$claimed" != "$actual" ]]; then
        pct="ERR_TAMPERED"
        echo "  !! $username: verification code does not match ($(basename "$report"))"
    fi
    if [[ -n ${seen[$username]:-} ]]; then
        echo "  !! $username: more than one report; using $(basename "$report")"
        sed -i "/^${username},/d" "$OUT"
    fi
    seen[$username]=1
    echo "${username},${period},${LAB_ID},${passed},${failed},${pct}" >> "$OUT"
    printf "  %-20s period %-8s %d/%d  (%s)\n" "$username" "$period" "$passed" "$total" "$pct"
done

for username in "${!period_of[@]}"; do
    [[ -n ${seen[$username]:-} ]] && continue
    echo "${username},${period_of[$username]},${LAB_ID},0,0,ERR_MISSING" >> "$OUT"
done

echo ""
echo "Compiled: $OUT"
column -t -s, "$OUT"
