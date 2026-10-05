#!/usr/bin/env bash
# Runs INSIDE a throwaway Ubuntu/Debian container (repo mounted at /repo).
# Provisions period 1 from the example roster, plays the server track as
# jsmith, grades it, then plays the local track as a sudo-enabled user.
set -euo pipefail
cd /repo
# Test images may lack iproute2 (the real provisioner installs it).
command -v ip >/dev/null || { printf '#!/bin/sh\necho "2: eth0    inet 10.0.0.99/24"\n' > /usr/local/bin/ip; chmod +x /usr/local/bin/ip; }
SKIP_APT=1 bash infra/lxc/provision_period.sh infra/students.csv.example 1

echo; echo "════ server track as jsmith ════"
runuser -u jsmith -- env HOME=/home/jsmith USER=jsmith TQ_TEST_HOME=/home/jsmith \
    TQ_TEST_QUEST=/opt/terminal-quest/quest.sh python3 tests/drive.py server tests/solutions/server.txt

echo; echo "════ grade-all p1 (bwilliams never logged in) ════"
bash /opt/terminal-quest/quest.sh grade-all p1
runuser -u jsmith -- env HOME=/home/jsmith USER=jsmith bash /opt/terminal-quest/quest.sh verify | tail -8

echo; echo "════ local track as a sudo user ════"
useradd -m -s /bin/bash -G users student
echo 'student ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/student
sed -e "/^ls \/mnt\/c$/d" -e 's/^!<keys quest skip\\ny\\n>$/SKIPLINE/' tests/solutions/local.txt > /tmp/local.txt
python3 - <<'PY'
# replace the three root-only skips with the real commands; keep the apt skips (no network)
s = open('/tmp/local.txt').read()
real = ['sudo chown root evidence/failed.txt', '!echo "test" >> evidence/failed.txt',
        'sudo chown student evidence/failed.txt']
for r in real:
    s = s.replace('SKIPLINE', r, 1)
s = s.replace('!echo "test" >> evidence/failed.txt', 'echo "test" >> evidence/failed.txt')
s = s.replace('SKIPLINE', '!<keys quest skip\\ny\\n>')
open('/tmp/local.txt', 'w').write(s)
PY
runuser -u student -- env HOME=/home/student USER=student \
    TQ_TEST_RC_EXTRA='ssh() { echo "(fake ssh) $*"; return 0; }' python3 tests/drive.py local /tmp/local.txt | grep -E '^\[|completed'
