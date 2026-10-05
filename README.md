# terminal-basics

Learn the tools you're going to need most frequently, and how to understand the default Debian prompt.

**Terminal Quest** is a guided, self-checking intro to the Linux command line for absolute beginners. A tutor runs inside the student's real bash shell, watches each command they type, gives instant feedback, and explains what just happened.

* **Part 1 (local / WSL):** 57 tasks across 11 chapters: the prompt, paths as folders, `pwd whoami hostname ls cd clear man mkdir touch echo > >> cat nano cp mv rm rmdir head tail wc less grep | history find chmod chgrp chown sudo groups ps ip apt ssh`. Turn-in: a generated report uploaded to Schoology.
* **Part 2 (class server):** 28 tasks on a shared Proxmox LXC per period: private homes, a group dropbox, `chgrp`/`chmod 640`, `who`, `ps aux`, `find`, and `sudo` being denied. Graded on the server.

| For | Read |
|---|---|
| Students (paste into the Google Doc) | [docs/STUDENT_GUIDE.md](docs/STUDENT_GUIDE.md) |
| Teacher setup, grading, editing tasks | [docs/TEACHER_GUIDE.md](docs/TEACHER_GUIDE.md) |

```
install.sh                         student installer (WSL)
quest/quest.sh                     entry point (sourced by bash, or run for verify/grade-all)
quest/lib/engine.sh                hook, feedback, progress, reports
quest/tracks/local.sh              Part 1 tasks + practice files
quest/tracks/server.sh             Part 2 tasks
infra/lxc/provision_period.sh      sets up one period's server (runs inside the LXC)
infra/proxmox/create_period_lxc.sh create + provision period LXCs (runs on a Proxmox node)
infra/proxmox/grade_lxc.sh         Part 2 grades → grades_report_server.csv
infra/grading/grade_local_reports.sh  Part 1 grades → grades_report_local.csv
tests/                             pty-driven playthroughs of both tracks
```
