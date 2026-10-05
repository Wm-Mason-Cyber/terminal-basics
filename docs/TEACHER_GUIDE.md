# Terminal Quest — Teacher Guide

A guided, self-checking introduction to the Linux terminal for students starting from zero (regular Cybersecurity, not AP).

| | Part 1 · Local | Part 2 · Class server |
|---|---|---|
| Where | Each student's WSL (Debian/Ubuntu) | One Proxmox LXC **per period** (Debian 12) |
| Framework tier | Like Tier 3: student machine, self-graded, report to Schoology | Like Tier 2: shared multi-user container, `chmod 700` homes |
| Tasks | 57 (56 outside WSL — the `/mnt/c` task only appears under WSL) | 28 |
| Turn-in | `terminal_quest_report_<user>.txt` → Schoology | Nothing to upload: graded on the server |
| Grader | `infra/grading/grade_local_reports.sh` | `infra/proxmox/grade_lxc.sh` |
| Output | `grades_report_local.csv` | `grades_report_server.csv` |

Both CSVs use the framework schema: `username,period,lab_id,passed_assertions,failed_assertions,grade_percentage`.

---

## How the tutor works

`quest/quest.sh` is sourced into each interactive bash: `~/.bashrc` in WSL, `/etc/bash.bashrc` on the server. It adds a hook to `PROMPT_COMMAND`, so **after every command** it:

1. reads the command from `history 1`, along with its exit code and the current folder,
2. writes them to `~/.terminal-quest/<track>/log.tsv`,
3. runs the current task's check. Most checks look at **real state** (does `~/quest/evidence` exist? is `notes.txt` mode 640? who owns `failed.txt`?), not only at the typed text, so alternative correct answers also count,
4. on success, prints a short explanation of what the student just saw, then the next task's instructions,
5. on failure, prints a tip for a recognised mistake (`cd..`, `>` instead of `>>`, Ctrl+Z instead of Ctrl+C, `grep` with the wrong case, a missing `sudo`, nano not saved…), or a plain-English reading of the exit code (127 = typo, 126 = not executable, …), followed by a one-line reminder of the current task.

After 3 misses in a row it suggests `quest hint`. Hints and skips are recorded in the log, so you can see who needed help.

The tutor sets `HISTCONTROL=` so repeated commands are recorded too. Once every task is done it **stops logging**.

### Part 1 storyline (`quest/tracks/local.sh`)

The tutor builds `~/quest/` on first launch: an inbox with the mission briefing, a hidden `.secret_note`, a junk folder to delete, a 260-line `auth.log` that ends in a password-guessing burst (so `tail` reveals the attack), a non-executable `tools/scan.sh`, and a `vault.key` buried 5 folders deep in `archive/`.

| Ch. | Commands |
|---|---|
| 1 Who and where am I? | `whoami` `hostname` `pwd` `ls` |
| 2 Survival skills | `clear` `man`/`--help` `yes` + Ctrl+C |
| 3 Moving around | `cd` (relative, `..`, `/`, `~`, absolute), `ls -a`, `ls -l`, `cat`, Tab completion, `/mnt/c` (WSL only) |
| 4 Making things | `mkdir` `touch` `echo` `>` `>>` `nano` |
| 5 Copy, move, delete | `cp` `mv` `rm` + wildcard `rmdir` |
| 6 Reading big files | `head` `tail` `wc -l` `less` |
| 7 Searching and pipes | `grep`, `grep … \| wc -l`, `grep … > file`, `history \| grep`, `find` |
| 8 Permissions | `./script` (denied), `chmod +x`, `chmod 640`, `groups`, `chgrp`, `sudo chown root`, failed write, `sudo chown` back |
| 9 Processes and network | `ps`, `ps aux \| grep`, `ip addr` |
| 10 Installing software | `apt search`, `sudo apt update`, `sudo apt install cowsay`, `echo … \| cowsay` |
| 11 Going remote | `ssh user@server` (the check runs after they `exit` back) |

### Part 2 storyline (`quest/tracks/server.sh`)

Everything in Part 2 is about sharing a computer: comparing `whoami`/`hostname`/`ip` with the laptop, `ls /home` (classmates), `ls /home | wc -l`, `ls /home/instructor` (**Permission denied**), `ls -ld ~` (why: 700), `who`, `ps aux`, `ps -u`, `groups` (`p<N>`), `nano ~/mission2/about_me.txt`, `cp` into the period dropbox, `chgrp p<N>`, `chmod 640`, `chown` (**Operation not permitted**), reading a group-only file, `tail`/`head -n`/`grep ALERT | wc -l` on a shared log, `find` for a hidden flag (meeting a real "Permission denied" along the way), appending the flag with `>>`, `history | grep`, `apt show`, and `sudo` (**not in the sudoers file**).

---

## Before class

### 1. Make the repo reachable

Students install with `git clone https://github.com/Wm-Mason-Cyber/terminal-basics.git`, so **the repo must be public**. To install from the classroom Gitea instead, change the URL in `docs/STUDENT_GUIDE.md` §5. For the `curl | bash` form, set `TQ_REPO_TARBALL`.

`install.sh` checks for `nano less man ssh ip ps find hostname` and installs anything missing with `sudo apt-get`. Debian's WSL image is minimal, so expect it to install `man-db` and/or `openssh-client` on some laptops.

### 2. Roster

Use the framework roster format. Copy `infra/students.csv.example` to `infra/students.csv`; that path is git-ignored because it holds passwords.

```
username,password,first_name,last_name,period,student_id,grade_level
jsmith,CyberDefender2026!,Jane,Smith,1,010101,11
```

### 3. Create the period servers (Proxmox)

On a Proxmox node, as root:

```bash
git clone https://github.com/Wm-Mason-Cyber/terminal-basics.git && cd terminal-basics
cp /path/to/students.csv infra/students.csv
./infra/proxmox/create_period_lxc.sh infra/students.csv all        # or: … 1 3 5
```

For each period, this:

* downloads the newest `debian-12-standard` template (if needed),
* creates an **unprivileged** container `quest-p<N>` with ID `7000 + N` (`nesting=1`, `onboot=1`, random root password),
* pushes the repo in and runs `infra/lxc/provision_period.sh`, which installs packages, creates the `p<N>` group and the student accounts, makes homes `700`, adds a locked `instructor` account, builds `/srv/class/p<N>` (mode `1770 root:p<N>`: group-writable with the sticky bit) and `/srv/class/shared` (log + hidden flag + a locked folder), installs the tutor to `/opt/terminal-quest`, and sets the sshd banner/MOTD,
* deletes the roster from inside the container,
* writes `infra/out/ssh_info_p<N>.txt` with the server IP and one `ssh user@ip` line per student. Print it, or put the address in the student doc's blanks.

Settings are environment variables:

| Variable | Default | |
|---|---|---|
| `VMID_BASE` | `7000` | CT ID = base + period |
| `STORAGE` | `local-lvm` | rootfs storage |
| `TEMPLATE_STORAGE` | `local` | where templates live |
| `BRIDGE` | `vmbr0` | |
| `IP_TEMPLATE` | `dhcp` | static example: `IP_TEMPLATE='10.20.0.1{P}/24' GATEWAY=10.20.0.1` |
| `MEMORY` / `CORES` / `DISK` | `2048` / `2` / `8` (GB) | 30 students running bash need very little |

You don't control the classroom router, so DHCP addresses may change. Either give the containers static addresses, or re-run the script (it's idempotent) to regenerate `ssh_info`.

**Re-running is safe.** Existing containers are started and re-provisioned, roster passwords are re-applied, new roster rows become new accounts, and student files are never touched. Use this to add a late student.

**Multiple nodes:** `pct` only sees containers on the node it runs on. Run the create and grade scripts on whichever node hosts each period, or use a different `VMID_BASE` per node.

---

## During class

* Day 1: students install (§5 of the student guide). The tutor's welcome screen walks through the prompt using their own username and hostname.
* Watch for **the sudo password**. Many students won't remember the Linux password they created when they set up WSL. Reset it from PowerShell: `wsl -u root passwd <linuxuser>`.
* `quest skip` exists for genuine blockers, such as no internet for `apt`. Skipped tasks count as FAIL.
* `quest reset` starts a student over (and rebuilds `~/quest` locally).
* On the server you can watch progress live: `pct enter 7001`, then `bash /opt/terminal-quest/quest.sh grade-all p1`.

---

## Grading

### Part 1 — local reports

```bash
./infra/grading/grade_local_reports.sh ~/Downloads/quest_reports infra/students.csv
```

* The username comes from **inside** each report, so Schoology's renamed downloads are fine.
* `ERR_TAMPERED`: the report's SHA-256 verification code doesn't match its contents (for example, someone hand-edited a FAIL into a PASS). The salt is in `quest/lib/engine.sh`, so this is **tamper-evident, not tamper-proof**. It stops casual edits, not a student who reads the source.
* `ERR_MISSING`: on the roster, but no report was found.
* Every report also contains the full command log (time, task, exit code, folder, command) and the last 500 lines of `~/.bash_history`. That's the "history doc," and it's worth skimming for anything that looks copied.

### Part 2 — server

```bash
./infra/proxmox/grade_lxc.sh infra/students.csv        # all periods
./infra/proxmox/grade_lxc.sh infra/students.csv 3      # one period
```

This runs `quest.sh grade-all p<N>` in each container. For every student it reads their progress **and re-verifies their files as that user**: the dropbox file exists and is theirs, its group is `p<N>`, it's mode 640, `about_me.txt` has 3+ lines, and the flag is in it. If a student completed a task but later undid it, that task is a FAIL. `ERR_OFFLINE` means the container isn't running on this node; `ERR_NOACCOUNT` means the student is on the roster but has no account in the container.

---

## Changing or adding tasks

Each task is a handful of small functions in a track file:

```bash
tq_step mkdir 'Make a folder named evidence: `mkdir evidence`'   # id + one-line goal
_tq_intro_mkdir()  { _tq_render <<'EOF'                          # instructions
**mkdir** = **m**a**k**e **dir**ectory. …
    `mkdir evidence`
EOF
}
_tq_check_mkdir()  { [[ -d $Q/evidence ]]; }                     # did the last command complete it?
_tq_verify_mkdir() { [[ -d $Q/evidence ]]; }                     # optional: re-checked at grading time
_tq_win_mkdir()    { _tq_render <<'EOF' … EOF; }                 # optional: explanation after success
_tq_hint_mkdir()   { _tq_say '…'; }                              # optional: `quest hint`
_tq_oops_mkdir()   { …recognise a mistake… || return 1; _tq_say '…'; }   # optional
_tq_applies_mkdir(){ …; }                                        # optional: return 1 to hide the task
```

* In text, `` `command` `` renders in cyan and `**word**` in bold. `{USER}`, `{HOME}`, `{HOST}`, `{SCHOOLUSER}`, `{GROUP}`, `{DROPBOX}` and `{SHARED}` are filled in per student.
* Checks can use `$TQ_CMD` (the full line), `$TQ_EC` (exit code), `$TQ_W0` (the first word after any `sudo`), `$TQ_SUDO`, `$PWD`, and the helpers `_tq_ok`, `_tq_re <regex>`, `_tq_has <text>`, `_tq_flag l`, `_tq_pipe`, `_tq_append`, `_tq_overwrite`, `_tq_perm`, `_tq_owner`, `_tq_group`, `_tq_lines`.
* Tasks run in the order they're registered. Progress is stored by task **id**, so adding tasks doesn't break anyone's existing progress.
* Pushing changes: students re-run `bash ~/terminal-basics/install.sh` after a `git pull`. For the servers, re-run `create_period_lxc.sh`.

### Tests

```bash
python3 tests/drive.py local tests/solutions/local.txt          # plays Part 1 in a real pty (temp HOME)
docker run --rm --network none -v "$PWD":/repo:ro <ubuntu/debian image with python3+sudo+nano> \
    bash /repo/tests/run_in_container.sh                         # provisions a server, plays Part 2,
                                                                 # grades it, plays Part 1 with real sudo
```

The solution files list the correct command for each task, plus deliberate mistakes (lines starting with `!`) that must *not* complete a task.

---

## Security notes

* Each period gets its own container, so a student can't reach other periods' accounts or files, and a mess in one period can't break another.
* SSH password login is on (beginners), root login is off, and students are not in sudoers. Keep the containers on the classroom network only.
* By design, students **can** see each other's processes (`ps aux`) and logins (`who`). That's part of the lesson.
* The roster (with passwords) is deleted from each container after provisioning. `infra/students.csv` and `infra/out/` are git-ignored.
* Clean up at the end of the unit: `pct stop 7001 && pct destroy 7001`.
