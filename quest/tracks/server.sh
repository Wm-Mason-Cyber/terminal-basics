# shellcheck shell=bash
# shellcheck disable=SC2016  # step text is single-quoted on purpose
#
# Terminal Quest — SERVER track (the shared class LXC, one per period).
# Students SSH in from their own machine. Everything here is about sharing a
# computer with classmates: private homes, shared folders, groups, processes.
#
# Settings come from server.conf (written by infra/lxc/provision_period.sh):
#   TQ_PERIOD=1  TQ_GROUP=p1  TQ_DROPBOX=/srv/class/p1  TQ_SHARED=/srv/class/shared

: "${TQ_GROUP:=p${TQ_PERIOD:-0}}"
: "${TQ_DROPBOX:=/srv/class/$TQ_GROUP}"
: "${TQ_SHARED:=/srv/class/shared}"
M2="$HOME/mission2"

_tq_my_drop() { printf '%s/%s.txt' "$TQ_DROPBOX" "$TQ_ME"; }
_tq_flag_value() { sed -n 's/^FLAG: *//p' "$TQ_SHARED/archive/.vault/server.flag" 2>/dev/null | head -1; }

# ── Welcome / finale ──────────────────────────────────────────────────────────

_tq_track_welcome() {
    _tq_colors
    printf '\n%s' "$TQ_M$TQ_B"
    cat <<'EOF'
   ╔══════════════════════════════════════════════════════════╗
   ║       T E R M I N A L   Q U E S T  ·  P A R T   2        ║
   ║                  The Shared Class Server                 ║
   ╚══════════════════════════════════════════════════════════╝
EOF
    printf '%s\n' "$TQ_R"
    _tq_render <<'EOF'
You're not on your own computer anymore. Everything you type now runs on the
**class server** — a computer shared by everyone in your period.
EOF
    echo
    _tq_prompt_tour
    _tq_render <<'EOF'
Same rules as before: type the commands in **color**, and I'll check each one.
When you're done, type `exit` to go back to your own computer.
EOF
}

_tq_track_finale() {
    _tq_colors
    printf '\n%s   ★ ★ ★  SERVER QUEST COMPLETE  ★ ★ ★%s\n' "$TQ_G$TQ_B" "$TQ_R"
    _tq_render <<'EOF'
Your teacher's grading script checks your work on this server automatically.
Nothing to upload for Part 2.

Type `exit` to log out and return to your own computer.
EOF
    echo
}

_tq_track_report_help() { _tq_say "Your teacher grades the server part directly — no upload needed."; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 1 — A new computer
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 1 · A new computer"

tq_step s_whoami 'Who are you on this computer? `whoami`'
_tq_intro_s_whoami() { _tq_render <<'EOF'
Different computer, different account. Check who you are here:

    `whoami`
EOF
}
_tq_check_s_whoami() { [[ $TQ_W0 == whoami ]] && _tq_ok; }

tq_step s_hostname 'What computer is this? `hostname`'
_tq_intro_s_hostname() { _tq_render <<'EOF'
    `hostname`
EOF
}
_tq_check_s_hostname() { [[ $TQ_W0 == hostname ]] && _tq_ok; }
_tq_win_s_hostname() { _tq_render <<'EOF'
**{HOST}** — not your laptop. Always glance at the prompt before typing a
command, so you know *which* computer you're about to change.
EOF
}

tq_step s_pwd 'Where did you land? `pwd`'
_tq_intro_s_pwd() { _tq_render <<'EOF'
When you log in, you start in your home folder. Confirm it:

    `pwd`
EOF
}
_tq_check_s_pwd() { [[ $TQ_W0 == pwd ]] && _tq_ok; }

tq_step s_ip 'Find this server'"'"'s IP address: `ip addr`'
_tq_intro_s_ip() { _tq_render <<'EOF'
This is the address you typed into ssh to get here. Find it in the list
(look for **inet** under **eth0**):

    `ip addr`
EOF
}
_tq_check_s_ip() { [[ $TQ_W0 == ip && ${TQ_WORDS[1]:-} =~ ^(a|addr|address)$ ]] && _tq_ok; }
_tq_win_s_ip() { _tq_render <<'EOF'
It's different from your laptop's IP. Every computer on a network has its own address.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 2 — Neighbors
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 2 · Your neighbors"

tq_step s_ls_home 'See everyone'"'"'s home folder: `ls /home`'
_tq_intro_s_ls_home() { _tq_render <<'EOF'
Every user on this server has a home folder inside **/home**:

    `ls /home`
EOF
}
_tq_check_s_ls_home() { [[ $TQ_W0 == ls ]] && _tq_re '/home/?($|[[:space:]])' && _tq_ok; }
_tq_win_s_ls_home() { _tq_render <<'EOF'
Those are your classmates (and **instructor**). You all share this computer.
EOF
}

tq_step s_count 'Count the accounts with a pipe: `ls /home | wc -l`'
_tq_intro_s_count() { _tq_render <<'EOF'
Remember pipes? Send the list into wc to count it:

    `ls /home | wc -l`
EOF
}
_tq_check_s_count() { _tq_re 'ls.*/home.*\|[[:space:]]*wc' && _tq_ok; }

tq_step s_peek 'Try to snoop in someone else'"'"'s home: `ls /home/instructor`'
_tq_intro_s_peek() { _tq_render <<'EOF'
Can you look inside someone else's home folder? Try your teacher's, or pick
any classmate's name from the list:

    `ls /home/instructor`
EOF
}
_tq_check_s_peek() {
    [[ $TQ_W0 == ls || $TQ_W0 == cd || $TQ_W0 == cat ]] && _tq_has /home/ && ! _tq_has "/home/$TQ_ME" && [[ $TQ_EC -ne 0 ]]
}
_tq_win_s_peek() { _tq_render <<'EOF'
**Permission denied.** Good! Home folders on this server are private.
Let's see why.
EOF
}

tq_step s_ls_ld 'Check your own home folder'"'"'s permissions: `ls -ld ~`'
_tq_intro_s_ls_ld() { _tq_render <<'EOF'
`ls -l` normally lists what's *inside* a folder. Add **d** to see the folder
**itself**:

    `ls -ld ~`
EOF
}
_tq_check_s_ls_ld() { [[ $TQ_W0 == ls ]] && _tq_flag d && _tq_ok; }
_tq_win_s_ls_ld() { _tq_render <<'EOF'
**drwx------** — the owner (you) has rwx, and group and others have **nothing**.
In numbers that's **700**. Everyone's home is set up the same way, which is
why you couldn't look inside theirs.
EOF
}

tq_step s_who 'See who else is logged in right now: `who`'
_tq_intro_s_who() { _tq_render <<'EOF'
    `who`
EOF
}
_tq_check_s_who() { [[ $TQ_W0 == who || $TQ_W0 == w || $TQ_W0 == users ]] && _tq_ok; }
_tq_win_s_who() { _tq_render <<'EOF'
Each line is someone connected right now, with the time they logged in.
EOF
}

tq_step s_ps 'See everyone'"'"'s programs: `ps aux`'
_tq_intro_s_ps() { _tq_render <<'EOF'
Home folders are private, but running **processes** are not. On a shared
computer you can see what everyone is running:

    `ps aux`
EOF
}
_tq_check_s_ps() { [[ $TQ_W0 == ps ]] && _tq_re '^ps[[:space:]]+(-?[a-z]*[ae])' && _tq_ok; }   # ps aux, ps -e, ps -ef

tq_step s_ps_mine 'Show only your own processes: `ps -u {USER}`'
_tq_intro_s_ps_mine() { _tq_render <<'EOF'
That's a lot. **-u** filters by user:

    `ps -u {USER}`
EOF
}
_tq_check_s_ps_mine() { [[ $TQ_W0 == ps ]] && _tq_has "$TQ_ME" && _tq_ok; }
_tq_win_s_ps_mine() { _tq_render <<'EOF'
**sshd** is the program keeping your connection open, and **bash** is your shell.
EOF
}

tq_step s_groups 'Which groups are you in here? `groups`'
_tq_intro_s_groups() { _tq_render <<'EOF'
    `groups`
EOF
}
_tq_check_s_groups() { [[ $TQ_W0 == groups || $TQ_W0 == id ]] && _tq_ok; }
_tq_win_s_groups() { _tq_render <<'EOF'
**{GROUP}** is your class period's group. Everyone in your period is in it, and
you'll use it to share files with each other.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 3 — The class dropbox
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 3 · The class dropbox"

tq_step s_mkdir 'Make a folder for your work: `mkdir ~/mission2`'
_tq_intro_s_mkdir() { _tq_render <<'EOF'
    `mkdir ~/mission2`
EOF
}
_tq_check_s_mkdir() { [[ -d $M2 ]]; }
_tq_verify_s_mkdir() { [[ -d $M2 ]]; }

tq_step s_nano 'Write about yourself: `nano ~/mission2/about_me.txt`'
_tq_intro_s_nano() { _tq_render <<'EOF'
Create a file with **at least 3 lines**: your first name, your favorite
food, and one thing you want to learn in this class.

    `nano ~/mission2/about_me.txt`

Save with **Ctrl+O**, **Enter**. Exit with **Ctrl+X**.
EOF
}
_tq_check_s_nano() { [[ $TQ_W0 == nano ]] && (( $(_tq_lines "$M2/about_me.txt") >= 3 )); }
_tq_verify_s_nano() { (( $(_tq_lines "$M2/about_me.txt") >= 3 )); }
_tq_oops_s_nano() {
    [[ $TQ_W0 == nano ]] || return 1
    _tq_say "${TQ_Y}The file needs at least 3 lines. Did you save with **Ctrl+O**, **Enter**? Open it again and finish.${TQ_R}"
}

tq_step s_ls_drop 'Look at your period'"'"'s shared dropbox: `ls -l {DROPBOX}`'
_tq_intro_s_ls_drop() { _tq_render <<'EOF'
Your period has a shared folder, the **dropbox**. Everyone in **{GROUP}** can
add files to it:

    `ls -l {DROPBOX}`
EOF
}
_tq_check_s_ls_drop() { [[ $TQ_W0 == ls ]] && { _tq_has "$TQ_DROPBOX" || [[ $PWD == "$TQ_DROPBOX" ]]; } && _tq_ok; }

tq_step s_cp_drop 'Copy your file into the dropbox: `cp ~/mission2/about_me.txt {DROPBOX}/{USER}.txt`'
_tq_intro_s_cp_drop() { _tq_render <<'EOF'
Share your about_me file. Name the copy after yourself so nobody's files
collide:

    `cp ~/mission2/about_me.txt {DROPBOX}/{USER}.txt`
EOF
}
_tq_check_s_cp_drop() { [[ -f $(_tq_my_drop) && $(_tq_owner "$(_tq_my_drop)") == "$TQ_ME" ]]; }
_tq_verify_s_cp_drop() { _tq_check_s_cp_drop; }

tq_step s_chgrp 'Hand your file to your period'"'"'s group: `chgrp {GROUP} {DROPBOX}/{USER}.txt`'
_tq_intro_s_chgrp() { _tq_render <<'EOF'
Look at your file with `ls -l {DROPBOX}`. Its group is **{USER}** — your
personal group, which only you are in. Change it to the class group:

    `chgrp {GROUP} {DROPBOX}/{USER}.txt`
EOF
}
_tq_check_s_chgrp() { [[ $(_tq_group "$(_tq_my_drop)") == "$TQ_GROUP" ]]; }
_tq_verify_s_chgrp() { _tq_check_s_chgrp; }

tq_step s_chmod 'Let the group read it, but not change it: `chmod 640 {DROPBOX}/{USER}.txt`'
_tq_intro_s_chmod() { _tq_render <<'EOF'
Remember the numbers: **r=4 w=2 x=1**, in the order owner · group · others.
640 = you can read+write, your period can read, nobody else can do anything:

    `chmod 640 {DROPBOX}/{USER}.txt`
EOF
}
_tq_check_s_chmod() { [[ $(_tq_perm "$(_tq_my_drop)") == 640 ]]; }
_tq_verify_s_chmod() { _tq_check_s_chmod; }
_tq_win_s_chmod() { _tq_render <<'EOF'
Now `ls -l {DROPBOX}` shows **-rw-r----- {USER} {GROUP}** for your file.
EOF
}

tq_step s_chown_try 'Try to give your file away: `chown instructor {DROPBOX}/{USER}.txt`'
_tq_intro_s_chown_try() { _tq_render <<'EOF'
On your laptop, you used sudo to change a file's owner. What happens here?

    `chown instructor {DROPBOX}/{USER}.txt`
EOF
}
_tq_check_s_chown_try() { [[ $TQ_W0 == chown && $TQ_EC -ne 0 ]]; }
_tq_win_s_chown_try() { _tq_render <<'EOF'
**Operation not permitted.** Only root can change a file's owner. Otherwise
people could "give" files to others to frame them, or to use up their space.
EOF
}

tq_step s_cat_peer 'Read a file someone shared with your group: `cat {DROPBOX}/welcome.txt`'
_tq_intro_s_cat_peer() { _tq_render <<'EOF'
Your teacher left a file in the dropbox that only your group can read. Then try
a classmate's file, once they've done the chgrp and chmod steps!

    `cat {DROPBOX}/welcome.txt`
EOF
}
_tq_check_s_cat_peer() {
    [[ $TQ_W0 == cat || $TQ_W0 == less || $TQ_W0 == head || $TQ_W0 == tail ]] || return 1
    { _tq_has "$TQ_DROPBOX" || [[ $PWD == "$TQ_DROPBOX" ]]; } && ! _tq_has "$TQ_ME.txt" && _tq_ok
}
_tq_win_s_cat_peer() { _tq_render <<'EOF'
That file is **-rw-r----- root {GROUP}**: someone in another period couldn't read it.
Groups let you share with exactly the right people.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 4 — Server detective
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 4 · Server detective"

tq_step s_tail 'Check the latest server events: `tail {SHARED}/server.log`'
_tq_intro_s_tail() { _tq_render <<'EOF'
The server keeps a log in the shared folder. Look at the most recent events:

    `tail {SHARED}/server.log`
EOF
}
_tq_check_s_tail() { [[ $TQ_W0 == tail ]] && _tq_has server.log && _tq_ok; }

tq_step s_grep_count 'Count the ALERT lines: `grep ALERT {SHARED}/server.log | wc -l`'
_tq_intro_s_grep_count() { _tq_render <<'EOF'
Some lines say **ALERT**. How many? Search and count in a single command:

    `grep ALERT {SHARED}/server.log | wc -l`
EOF
}
_tq_check_s_grep_count() { _tq_re 'grep.*ALERT.*\|[[:space:]]*wc' && _tq_ok; }
_tq_hint_s_grep_count() { _tq_say 'grep (search) | wc -l (count lines). Capitals matter: ALERT.'; }

tq_step s_head_n 'See just the first 3 lines: `head -n 3 {SHARED}/server.log`'
_tq_intro_s_head_n() { _tq_render <<'EOF'
**-n** tells head (and tail) how many lines to show:

    `head -n 3 {SHARED}/server.log`
EOF
}
_tq_check_s_head_n() { [[ $TQ_W0 == head ]] && _tq_flag n && _tq_ok; }

tq_step s_find 'Find the hidden flag file: `find {SHARED} -name "*.flag"`'
_tq_intro_s_find() { _tq_render <<'EOF'
Somewhere in the shared folder is a hidden **.flag** file. Hunt it down:

    `find {SHARED} -name "*.flag"`

(You may see some "Permission denied" lines — those are folders you aren't
allowed into. find just skips them.)
EOF
}
_tq_check_s_find() { [[ $TQ_W0 == find ]] && _tq_has flag; }
_tq_hint_s_find() { _tq_say 'Notice the folder names that start with a dot — they are hidden from a plain `ls`, but find still searches them.'; }

tq_step s_flag 'Add the flag to your about_me file: `cat <flag path> >> ~/mission2/about_me.txt`'
_tq_intro_s_flag() { _tq_render <<'EOF'
Prove you found it: **append** the flag file to your about_me file. Use the
path that find printed, and remember: **>>** adds, **>** would erase!

    `cat ` ... `server.flag >> ~/mission2/about_me.txt`
EOF
}
_tq_flag_ok() { local v; v=$(_tq_flag_value); [[ -n $v ]] && grep -qF "$v" "$M2/about_me.txt" 2>/dev/null; }
_tq_check_s_flag() { _tq_flag_ok; }
_tq_verify_s_flag() { _tq_flag_ok; }
_tq_oops_s_flag() {
    _tq_overwrite && ! _tq_append && _tq_has about_me || return 1
    _tq_say "${TQ_Y}Uh oh — a single > replaced your whole about_me file. Fix it with \`nano ~/mission2/about_me.txt\` (it needs 3+ lines again), then try >> .${TQ_R}"
}
_tq_hint_s_flag() { _tq_say '`cat {SHARED}/archive/.vault/server.flag >> ~/mission2/about_me.txt`'; }

tq_step s_history 'Find the chmod you ran earlier: `history | grep chmod`'
_tq_intro_s_history() { _tq_render <<'EOF'
    `history | grep chmod`
EOF
}
_tq_check_s_history() { _tq_re '^history.*\|[[:space:]]*grep' && _tq_ok; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 5 — Who's in charge?
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 5 · Who's in charge?"

tq_step s_apt_show 'Look up a package (no install): `apt show nano`'
_tq_intro_s_apt_show() { _tq_render <<'EOF'
Anyone can **look** at packages with apt:

    `apt show nano`
EOF
}
_tq_check_s_apt_show() { [[ $TQ_W0 == apt || $TQ_W0 == apt-cache ]] && _tq_re '(show|search|list)' && _tq_ok; }

tq_step s_sudo_try 'Try to install something: `sudo apt install sl`'
_tq_intro_s_sudo_try() { _tq_render <<'EOF'
On your laptop you're the admin. Here? Let's find out:

    `sudo apt install sl`

(Type your server password when it asks.)
EOF
}
_tq_check_s_sudo_try() { (( TQ_SUDO )) && [[ $TQ_EC -ne 0 ]]; }
_tq_win_s_sudo_try() { _tq_render <<'EOF'
**"{USER} is not in the sudoers file."** On a shared server, only admins get sudo.
Otherwise anyone could read everyone's private files, or break the server for
the whole class. Your failed attempt was also written to a security log. 😉
EOF
}
