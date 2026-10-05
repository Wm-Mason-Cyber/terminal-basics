# shellcheck shell=bash
# shellcheck disable=SC2016  # step text is single-quoted on purpose
#
# Terminal Quest — LOCAL track (the student's own WSL / Linux machine).
# Story: the student is a new security analyst collecting evidence about
# break-in attempts on a web server. Everything happens inside ~/quest.

Q="$HOME/quest"

# ── Practice world ────────────────────────────────────────────────────────────

_tq_track_init() {
    [[ -e $Q/.world ]] && return
    mkdir -p "$Q"/{inbox,logs,junk,tools} || return
    local m
    for m in jan feb mar apr may jun jul aug sep oct nov dec; do
        mkdir -p "$Q/archive/2024/$m"
        printf 'Monthly server report — %s 2024\nStatus: normal. Nothing to see here.\n' "$m" > "$Q/archive/2024/$m/report.txt"
    done
    mkdir -p "$Q/archive/2024/sep/old/backup" "$Q/archive/2023/misc"
    printf 'Nope, not here either.\n' > "$Q/archive/2023/misc/notes.txt"
    printf 'VAULT KEY: QUEST-%s\nKeep this secret. Copy it into your evidence folder.\n' \
        "$(printf '%s' "$TQ_ME" | sha256sum | cut -c1-8 | tr a-f A-F)" > "$Q/archive/2024/sep/old/backup/vault.key"

    cat > "$Q/inbox/welcome.txt" <<EOF
==============================================================
  WELCOME, ANALYST $TQ_ME
==============================================================
Someone has been trying to break into our web server.

Your mission:
  1. Make an evidence folder and take notes.
  2. Dig through the server's login log for failed logins.
  3. Find the vault key that the intruder was after.
  4. Lock down your evidence with the right permissions.

Everything you need is inside the quest folder.
Good luck.            -- The Security Team
EOF

    cat > "$Q/.secret_note" <<'EOF'
You found a hidden file!
Any file or folder whose name starts with a dot (.) is hidden.
Linux uses hidden files for settings — for example, ~/.bashrc
holds the settings for your terminal.
EOF

    printf 'BUY CHEAP SUNGLASSES!!!\n' > "$Q/junk/spam1.txt"
    printf 'You have WON a free cruise. Click here.\n' > "$Q/junk/spam2.txt"
    printf 'Your account is suspended. Send us your password.\n' > "$Q/junk/spam3.txt"

    cat > "$Q/tools/scan.sh" <<'EOF'
#!/bin/bash
# Evidence scanner — lists what is in your evidence folder.
echo "[scan] Scanning ~/quest/evidence ..."
mkdir -p ~/quest/evidence
for f in ~/quest/evidence/*; do
    [ -e "$f" ] && echo "[scan]   found: $(basename "$f")"
done
echo "Scan run by $(whoami) on $(date)" > ~/quest/evidence/scan_results.txt
echo "[scan] Done. Results saved to ~/quest/evidence/scan_results.txt"
EOF
    chmod 644 "$Q/tools/scan.sh"

    # A web server login log: normal traffic, a few scattered failures, and an
    # attack burst at the end so `tail` reveals it.
    awk 'BEGIN {
        users[0]="jdoe"; users[1]="mlopez"; users[2]="akim"; users[3]="backup"
        pid = 2200
        for (i = 0; i < 260; i++) {
            t = 6*3600 + i*53
            ts = sprintf("Oct  3 %02d:%02d:%02d", int(t/3600), int(t%3600/60), t%60)
            pid += 7
            if (i >= 236) {
                printf "%s webserver sshd[%d]: Failed password for root from 203.0.113.66 port %d ssh2\n", ts, pid, 40000+i
            } else if (i % 17 == 5) {
                printf "%s webserver sshd[%d]: Failed password for invalid user admin from 198.51.100.23 port %d ssh2\n", ts, pid, 50000+i
            } else if (i % 13 == 0) {
                printf "%s webserver sshd[%d]: Failed password for %s from 10.0.0.%d port %d ssh2\n", ts, pid, users[i%4], 10+i%5, 52000+i
            } else if (i % 5 == 0) {
                printf "%s webserver CRON[%d]: pam_unix(cron:session): session opened for user root\n", ts, pid
            } else {
                printf "%s webserver sshd[%d]: Accepted password for %s from 10.0.0.%d port %d ssh2\n", ts, pid, users[i%4], 10+i%5, 52000+i
            }
        }
    }' > "$Q/logs/auth.log"

    : > "$Q/.world"
}

_tq_track_reset() {
    rm -rf "$Q"
    _tq_track_init
}

# Count of failed-login lines in the log (used in messages and checks).
_tq_failed_count() { grep -c 'Failed' "$Q/logs/auth.log" 2>/dev/null; }

_tq_cowsay_installed() { command -v cowsay >/dev/null 2>&1 || [[ -x /usr/games/cowsay ]]; }

# ── Welcome / finale / report ─────────────────────────────────────────────────

_tq_track_welcome() {
    _tq_colors
    printf '\n%s' "$TQ_M$TQ_B"
    cat <<'EOF'
   ╔══════════════════════════════════════════════════════════╗
   ║                 T E R M I N A L   Q U E S T              ║
   ║        Learn the Linux command line, one step at a time  ║
   ╚══════════════════════════════════════════════════════════╝
EOF
    printf '%s\n' "$TQ_R"
    _tq_render <<'EOF'
This window is a **terminal**. Instead of clicking, you type **commands**
and press **Enter**. The line where you type is called the **prompt**.
EOF
    echo
    _tq_prompt_tour
    _tq_render <<'EOF'
I'm your tutor. I'll watch each command you type and tell you how it went.
Type the commands shown in **color** exactly as written (spaces matter!).

Keyboard tips that will save you:
  **Tab**       finish a file or folder name for you
  **↑ / ↓**     bring back commands you typed before
  **Ctrl+C**    stop a command that is running
  **q**         quit a screen like `man` or `less`
EOF
}

_tq_track_finale() {
    _tq_colors
    printf '\n%s' "$TQ_G$TQ_B"
    cat <<'EOF'
   ★ ★ ★  QUEST COMPLETE  ★ ★ ★
EOF
    printf '%s' "$TQ_R"
    _tq_render <<'EOF'
You used more than 30 Linux commands. That's a real skill.

**Turn it in:**
  1. Make your report:              `quest report`
  2. Go to your home folder:        `cd ~`
  3. Open it in Windows File Explorer:   `explorer.exe .`
  4. Upload **terminal_quest_report_{SCHOOLUSER}.txt** to Schoology.

The tutor has stopped watching your commands. You can keep exploring!
EOF
    echo
}

_tq_track_report_help() {
    _tq_render <<'EOF'
To turn it in:
  1. Go to your home folder:   `cd ~`
  2. Open it in Windows File Explorer:   `explorer.exe .`
     (yes, with the dot — the dot means "this folder")
  3. Upload the report file to the Schoology assignment.

Don't edit the report — it has a verification code, and editing it breaks the code.
If you do more tasks later, just run `quest report` again and re-upload.
EOF
    echo
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 1 — Who and where am I?
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 1 · Who and where am I?"

tq_step whoami 'Ask the computer who you are: `whoami`'
_tq_intro_whoami() { _tq_render <<'EOF'
Every command runs as some **user**. Let's ask the computer which user you
are. Type this and press **Enter**:

    `whoami`
EOF
}
_tq_check_whoami() { [[ $TQ_W0 == whoami ]] && _tq_ok; }
_tq_win_whoami() { _tq_render <<'EOF'
That's your **username** — the same as the first part of your prompt, before the **@**.
EOF
}
_tq_hint_whoami() { _tq_say 'Type the letters `whoami` (no spaces), then press Enter.'; }

tq_step hostname 'Ask the computer its name: `hostname`'
_tq_intro_hostname() { _tq_render <<'EOF'
The part of your prompt after the **@** is the **hostname** — the name of
the computer. Every computer on a network has one, the same way every
student on a roster has a name.

    `hostname`
EOF
}
_tq_check_hostname() { [[ $TQ_W0 == hostname ]] && _tq_ok; }
_tq_win_hostname() { _tq_render <<'EOF'
Same as your prompt: **{HOST}**. Later you'll log into a different computer,
and this part of the prompt will change. That's how you'll know where you are!
EOF
}

tq_step pwd 'Find out which folder you are in: `pwd`'
_tq_intro_pwd() { _tq_render <<'EOF'
A terminal is always "standing" inside one folder — just like a File
Explorer window always shows one folder. Linux calls folders **directories**,
and the one you're standing in is your **working directory**.

**pwd** = **p**rint **w**orking **d**irectory:

    `pwd`
EOF
}
_tq_check_pwd() { [[ $TQ_W0 == pwd ]] && _tq_ok; }
_tq_win_pwd() { _tq_render <<'EOF'
That's a **path** — an address for a folder. Read it like the address bar in File Explorer:

    Windows:   C:\Users\you        folders separated by  \
    Linux:     {HOME}         folders separated by  /

The first **/** is the **root**: the top folder that holds everything (like C:\).
**{HOME}** is your **home folder**. The prompt shortens it to **~** .
EOF
}

tq_step ls 'List what is in this folder: `ls`'
_tq_intro_ls() { _tq_render <<'EOF'
**ls** = **l**i**s**t. It shows the files and folders where you're standing —
like looking at the contents of a File Explorer window.

    `ls`
EOF
}
_tq_check_ls() { [[ $TQ_W0 == ls ]] && _tq_ok; }
_tq_win_ls() { _tq_render <<'EOF'
Folders usually show in **blue**, files in white. See the folder named **quest**?
I made it for you. Your mission takes place in there.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 2 — Survival skills
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 2 · Survival skills"

tq_step clear 'Clean up the screen: `clear`'
_tq_intro_clear() { _tq_render <<'EOF'
The screen is getting busy. Wipe it clean:

    `clear`

(Keyboard shortcut: **Ctrl+L** does the same thing.)
EOF
}
_tq_check_clear() { [[ $TQ_W0 == clear ]]; }
_tq_win_clear() { _tq_render <<'EOF'
Clean! Nothing is lost — press **↑** (up arrow) to bring back commands you typed earlier.
EOF
}

tq_step man 'Read the manual for ls: `man ls`  (press q to quit)'
_tq_intro_man() { _tq_render <<'EOF'
Almost every command has a built-in **manual** (instructions). Open the one for ls:

    `man ls`

Scroll with the **arrow keys** or **Space**. Press **q** to **q**uit and come back.
Don't worry about understanding it all — nobody reads the whole thing.
EOF
}
_tq_check_man() { { [[ $TQ_W0 == man ]] || _tq_flag --help; } && _tq_ok; }
_tq_oops_man() {
    [[ $TQ_W0 == man ]] || return 1
    _tq_say "${TQ_Y}No manual? Some computers don't have them installed. Try the short version instead: \`ls --help\`${TQ_R}"
}
_tq_win_man() { _tq_render <<'EOF'
When you forget how a command works, `man <command>` or `<command> --help` is the first place to look.
EOF
}

tq_step ctrlc 'Start a never-ending command with `yes`, then stop it with Ctrl+C'
_tq_intro_ctrlc() { _tq_render <<'EOF'
Some commands run forever, or you'll start one by accident. The
emergency stop button is **Ctrl+C** (hold Ctrl, press C).

Try it. This command prints the same words forever and floods your screen:

    `yes I am learning Linux`

Don't panic! Press **Ctrl+C** to stop it.
EOF
}
_tq_check_ctrlc() { [[ $TQ_W0 == yes && $TQ_EC -eq 130 ]]; }
_tq_oops_ctrlc() {
    [[ $TQ_W0 == yes && $TQ_EC -eq 148 ]] || return 1
    _tq_say "${TQ_Y}That was Ctrl+**Z** — it hides the command but doesn't stop it. Type \`fg\` to bring it back, then press Ctrl+**C**.${TQ_R}"
}
_tq_win_ctrlc() { _tq_render <<'EOF'
Ctrl+C is the "stop!" button. Note: in the terminal, Ctrl+C does **not** mean copy.
In Windows Terminal, copy is **Ctrl+Shift+C** and paste is **Ctrl+Shift+V** (or right-click).
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 3 — Moving around
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 3 · Moving around"

tq_step cd_quest 'Move into the quest folder: `cd quest`'
_tq_intro_cd_quest() { _tq_render <<'EOF'
**cd** = **c**hange **d**irectory. It's like double-clicking a folder.

    `cd quest`

Watch your prompt as you press Enter — the path part will change.
EOF
}
_tq_check_cd_quest() { [[ $TQ_W0 == cd && $PWD == "$Q" ]]; }
_tq_oops_cd_quest() {
    [[ $TQ_W0 == cd && $TQ_EC -ne 0 ]] || return 1
    _tq_say "${TQ_Y}\`cd quest\` only works from your home folder, because that's where quest is. Type \`cd\` by itself to go home, then try again.${TQ_R}"
}
_tq_win_cd_quest() { _tq_render <<'EOF'
Look at your prompt: it now ends in **~/quest$**. The prompt always shows where you're standing.
EOF
}

tq_step ls_a 'Show hidden files too: `ls -a`'
_tq_intro_ls_a() { _tq_render <<'EOF'
A word that starts with **-** after a command is an **option** (also called a
**flag**). Options change how a command behaves. **-a** means **all**, which
includes **hidden** files.

    `ls -a`

(The space between `ls` and `-a` is required.)
EOF
}
_tq_check_ls_a() { [[ $TQ_W0 == ls ]] && { _tq_flag a || _tq_flag --all; } && _tq_ok; }
_tq_win_ls_a() { _tq_render <<'EOF'
See **.secret_note**? Names starting with a dot are hidden from a plain `ls`.
Also notice **.** and **..** —  **.** means "this folder" and **..** means "the folder above."
EOF
}

tq_step cat_secret 'Read the hidden note: `cat .secret_note`  (try Tab!)'
_tq_intro_cat_secret() { _tq_render <<'EOF'
**cat** prints a file's contents onto the screen.

Try **Tab completion**: type `cat .se` and press **Tab** — the terminal
finishes the name for you. Then press Enter.

    `cat .secret_note`

Tab saves typing *and* prevents typos. Use it constantly.
EOF
}
_tq_check_cat_secret() { [[ $TQ_W0 == cat ]] && _tq_has secret_note && _tq_ok; }

tq_step cd_inbox 'Go into the inbox folder: `cd inbox`'
_tq_intro_cd_inbox() { _tq_render <<'EOF'
There's a message waiting for you in the **inbox** folder. Go in there:

    `cd inbox`
EOF
}
_tq_check_cd_inbox() { [[ $TQ_W0 == cd && $PWD == "$Q/inbox" ]]; }

tq_step cat_welcome 'Read your mission briefing: `cat welcome.txt`'
_tq_intro_cat_welcome() { _tq_render <<'EOF'
Use `ls` to see what's here if you like, then read the message:

    `cat welcome.txt`
EOF
}
_tq_check_cat_welcome() { [[ $TQ_W0 == cat ]] && _tq_has welcome && _tq_ok; }
_tq_win_cat_welcome() { _tq_render <<'EOF'
Now you know the mission. Let's learn to get around so you can carry it out.
EOF
}

tq_step cd_up 'Go up one folder: `cd ..`'
_tq_intro_cd_up() { _tq_render <<'EOF'
**..** always means "the folder above this one" — like the **↑ Up** arrow
button in File Explorer.

    `cd ..`
EOF
}
_tq_check_cd_up() { [[ $TQ_W0 == cd && $PWD == "$Q" ]] && _tq_has '..'; }
_tq_oops_cd_up() {
    [[ $TQ_CMD == cd.. ]] || return 1
    _tq_say "${TQ_Y}Close! Linux needs a **space** between the command and the folder: \`cd ..\`${TQ_R}"
}

tq_step cd_root 'Jump to the very top of the file system: `cd /`'
_tq_intro_cd_root() { _tq_render <<'EOF'
A single **/** is the **root** — the top folder that holds every other
folder on the computer, like **C:\** on Windows.

    `cd /`
EOF
}
_tq_check_cd_root() { [[ $TQ_W0 == cd && $PWD == / ]]; }

tq_step ls_root 'Look around the root folder: `ls`'
_tq_intro_ls_root() { _tq_render <<'EOF'
Your prompt shows **/** now. Look around:

    `ls`
EOF
}
_tq_check_ls_root() { [[ $TQ_W0 == ls ]] && { [[ $PWD == / ]] || _tq_re '^ls( -[a-zA-Z]+)* /$'; } && _tq_ok; }
_tq_win_ls_root() { _tq_render <<'EOF'
Every path on this computer starts from here. A few to know:
  **home**   users' home folders live here (yours is {HOME})
  **etc**    settings for the whole system
  **bin**    programs (commands like ls live in /bin or /usr/bin)
  **tmp**    temporary files
  **mnt**    other drives get connected ("mounted") here
EOF
}

tq_step ls_mnt_c 'Find your Windows C: drive: `ls /mnt/c`'
_tq_applies_ls_mnt_c() { (( TQ_IS_WSL )) && [[ -d /mnt/c ]]; }
_tq_intro_ls_mnt_c() { _tq_render <<'EOF'
You're using **WSL** (Windows Subsystem for Linux): Linux running inside
Windows. WSL connects your Windows drives under **/mnt**. Peek at your C: drive:

    `ls /mnt/c`
EOF
}
_tq_check_ls_mnt_c() { [[ $TQ_W0 == ls ]] && { _tq_has /mnt/c || [[ $PWD == /mnt/c* ]]; } && _tq_ok; }
_tq_win_ls_mnt_c() { _tq_render <<'EOF'
Those are your Windows files! **C:\Users** in Windows is **/mnt/c/Users** in Linux.
Same files, two ways to reach them.
EOF
}

tq_step cd_home 'Go back to your home folder: `cd ~`'
_tq_intro_cd_home() { _tq_render <<'EOF'
**~** (tilde — Shift + the key left of 1) is a shortcut for your home
folder, **{HOME}**. Wherever you are, this takes you home:

    `cd ~`

(Typing `cd` all by itself does the same thing.)
EOF
}
_tq_check_cd_home() { [[ $TQ_W0 == cd && $PWD == "$HOME" ]]; }

tq_step cd_abs 'Use a full path: `cd {HOME}/quest`'
_tq_intro_cd_abs() { _tq_render <<'EOF'
Two kinds of paths:
  **relative**  `cd quest`  "quest, inside the folder I'm in now"
  **absolute**  `cd {HOME}/quest`  starts with **/**, the full address from the root.
                Works no matter where you are.

Type it using **Tab** to finish each folder name (`/ho` Tab, and so on):

    `cd {HOME}/quest`
EOF
}
_tq_check_cd_abs() { [[ $TQ_W0 == cd && $PWD == "$Q" ]] && _tq_has /; }
_tq_hint_cd_abs() { _tq_say 'The path must contain slashes. `cd ~/quest` also counts — ~ is short for {HOME}.'; }

tq_step ls_l 'Get the long listing: `ls -l`'
_tq_intro_ls_l() { _tq_render <<'EOF'
**-l** means **long** listing: more details about each item.

    `ls -l`
EOF
}
_tq_check_ls_l() { [[ $TQ_W0 == ls ]] && _tq_flag l && _tq_ok; }
_tq_win_ls_l() { _tq_render <<'EOF'
Each line tells you a lot. For example:

    drwxr-xr-x 2 {USER} {USER} 4096 Oct  3 09:12 inbox
    │└───┬───┘   └──┬─┘ └──┬─┘ └┬─┘ └─────┬────┘ └─┬─┘
    │ permissions  owner group size  last changed  name
    └ d = directory (folder),  - = regular file

You'll learn to read and change **permissions**, **owner** and **group** later.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 4 — Making things
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 4 · Making things"

tq_step mkdir 'Make a folder named evidence: `mkdir evidence`'
_tq_intro_mkdir() { _tq_render <<'EOF'
**mkdir** = **m**a**k**e **dir**ectory. Like right-click → New → Folder.

    `mkdir evidence`

Tip: avoid spaces in file and folder names. Use - or _ instead (my_notes, not my notes).
EOF
}
_tq_check_mkdir() { [[ -d $Q/evidence ]]; }
_tq_verify_mkdir() { [[ -d $Q/evidence ]]; }
_tq_oops_mkdir() {
    [[ $TQ_W0 == mkdir && $PWD != "$Q" ]] || return 1
    _tq_say "${TQ_Y}Make it inside quest. Go there first with \`cd ~/quest\`.${TQ_R}"
}
_tq_win_mkdir() { _tq_render <<'EOF'
Check it with `ls` — you'll see **evidence** in blue.
EOF
}

tq_step touch 'Create an empty file: `touch evidence/notes.txt`'
_tq_intro_touch() { _tq_render <<'EOF'
**touch** creates an empty file. (If the file already exists, it just
updates its "last changed" time.)

    `touch evidence/notes.txt`

Notice the path **evidence/notes.txt**: folder, slash, file. You don't have
to `cd` into a folder to work with what's inside it.
EOF
}
_tq_check_touch() { [[ $TQ_W0 == touch && -f $Q/evidence/notes.txt ]]; }

tq_step echo 'Make the terminal say something: `echo Hello, I am {USER}`'
_tq_intro_echo() { _tq_render <<'EOF'
**echo** repeats whatever you give it back onto the screen:

    `echo Hello, I am {USER}`
EOF
}
_tq_check_echo() { [[ $TQ_W0 == echo ]] && ! _tq_has '>' && ! _tq_pipe; }
_tq_win_echo() { _tq_render <<'EOF'
Not very useful on its own… until you **redirect** where the words go. That's next.
EOF
}

tq_step redirect_write 'Write into a file with >: `echo "Analyst: {USER}" > evidence/notes.txt`'
_tq_intro_redirect_write() { _tq_render <<'EOF'
The **>** symbol **redirects** output: instead of printing on the screen,
the text goes into a file.

    `echo "Analyst: {USER}" > evidence/notes.txt`

⚠ **>** **overwrites**: anything already in the file is erased and replaced.
EOF
}
_tq_check_redirect_write() {
    _tq_overwrite && ! _tq_append && _tq_has notes.txt && [[ -s $Q/evidence/notes.txt ]]
}
_tq_win_redirect_write() { _tq_render <<'EOF'
Nothing printed on the screen this time — the text went into the file instead.
EOF
}

tq_step redirect_append 'Add a line with >>: `echo "Case: web server break-in" >> evidence/notes.txt`'
_tq_intro_redirect_append() { _tq_render <<'EOF'
**>>** (two of them) **appends**: it adds to the end of the file and keeps
what's already there.

    `echo "Case: web server break-in" >> evidence/notes.txt`
EOF
}
_tq_check_redirect_append() { _tq_append && _tq_has notes.txt && (( $(_tq_lines "$Q/evidence/notes.txt") >= 2 )); }
_tq_oops_redirect_append() {
    _tq_overwrite && ! _tq_append && _tq_has notes.txt || return 1
    _tq_say "${TQ_Y}That was a single > — it replaced the whole file! Use **two**: >> . (Then you may need to add the Analyst line back.)${TQ_R}"
}

tq_step cat_notes 'Check your notes: `cat evidence/notes.txt`'
_tq_intro_cat_notes() { _tq_render <<'EOF'
Let's see what's in the file now:

    `cat evidence/notes.txt`
EOF
}
_tq_check_cat_notes() { [[ $TQ_W0 == cat ]] && _tq_has notes.txt && _tq_ok; }
_tq_win_cat_notes() { _tq_render <<'EOF'
Remember:   **>**  = replace the file      **>>** = add to the end
EOF
}

tq_step nano 'Edit your notes in nano: `nano evidence/notes.txt`'
_tq_intro_nano() { _tq_render <<'EOF'
**nano** is a text editor that runs right in the terminal.

    `nano evidence/notes.txt`

In nano:
  1. Use the **arrow keys** to move to the end, then press Enter for a new line.
  2. Type a line, for example:  **Started investigation today**
  3. Save:  **Ctrl+O**, then **Enter**     ("O" for Output)
  4. Exit:  **Ctrl+X**

The shortcuts are listed at the bottom of nano. **^** means Ctrl.
EOF
}
_tq_check_nano() { [[ $TQ_W0 == nano ]] && (( $(_tq_lines "$Q/evidence/notes.txt") >= 3 )); }
_tq_verify_nano() { (( $(_tq_lines "$Q/evidence/notes.txt") >= 3 )); }
_tq_oops_nano() {
    [[ $TQ_W0 == nano ]] || return 1
    _tq_say "${TQ_Y}The file still has fewer than 3 lines. Did you save with **Ctrl+O** then **Enter** before **Ctrl+X**? Open it again and add a line.${TQ_R}"
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 5 — Copy, move, delete
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 5 · Copy, move, delete"

tq_step cp 'Copy your briefing into evidence: `cp inbox/welcome.txt evidence/`'
_tq_intro_cp() { _tq_render <<'EOF'
**cp** = **c**o**p**y. The pattern is:  cp  **from**  **to**

    `cp inbox/welcome.txt evidence/`

The original stays where it was; a copy appears in evidence.
EOF
}
_tq_check_cp() { [[ -f $Q/evidence/welcome.txt ]]; }

tq_step mv 'Rename the copy: `mv evidence/welcome.txt evidence/briefing.txt`'
_tq_intro_mv() { _tq_render <<'EOF'
**mv** = **m**o**v**e. It moves files *and* renames them. (Renaming is just
moving a file to a new name.) Same pattern:  mv  **from**  **to**

    `mv evidence/welcome.txt evidence/briefing.txt`
EOF
}
_tq_check_mv() { [[ -f $Q/evidence/briefing.txt && ! -e $Q/evidence/welcome.txt ]]; }
_tq_verify_mv() { [[ -f $Q/evidence/briefing.txt ]]; }
_tq_win_mv() { _tq_render <<'EOF'
Check with `ls evidence` — welcome.txt is gone from there, and briefing.txt took its place.
EOF
}

tq_step rm_files 'Delete the junk files: `rm junk/*.txt`'
_tq_intro_rm_files() { _tq_render <<'EOF'
The **junk** folder is full of spam. Look first:  `ls junk`

**rm** = **r**e**m**ove. ⚠ There is **no Recycle Bin** in the terminal.
Deleted means gone forever.

The ***** is a **wildcard**: ***.txt** means "every name that ends in .txt".

    `rm junk/*.txt`
EOF
}
_tq_check_rm_files() { ! compgen -G "$Q/junk/*.txt" >/dev/null; }

tq_step rmdir 'Remove the empty folder: `rmdir junk`'
_tq_intro_rmdir() { _tq_render <<'EOF'
**rmdir** removes a folder — but only if it's **empty**. That's a safety
feature, so you can't wipe out a folder full of files by accident.

    `rmdir junk`

(You may see `rm -r folder` online. It deletes a folder **and everything
inside it**. Be very careful with it.)
EOF
}
_tq_check_rmdir() { [[ ! -e $Q/junk ]]; }
_tq_verify_rmdir() { [[ ! -e $Q/junk ]]; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 6 — Reading big files
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 6 · Reading big files"

tq_step head 'See the first 10 lines of the log: `head logs/auth.log`'
_tq_intro_head() { _tq_render <<'EOF'
Computers keep **logs**: records of what happened and when. **logs/auth.log**
records every login attempt on the web server. It's long — `cat` would flood
your screen. **head** shows just the top:

    `head logs/auth.log`
EOF
}
_tq_check_head() { [[ $TQ_W0 == head ]] && _tq_has auth.log && _tq_ok; }
_tq_win_head() { _tq_render <<'EOF'
Each line is one event: date and time, computer name, program, and what happened.
"Accepted password" = someone logged in successfully.
EOF
}

tq_step tail 'See the last 10 lines: `tail logs/auth.log`'
_tq_intro_tail() { _tq_render <<'EOF'
**tail** shows the **end** of a file — the most recent events:

    `tail logs/auth.log`
EOF
}
_tq_check_tail() { [[ $TQ_W0 == tail ]] && _tq_has auth.log && _tq_ok; }
_tq_win_tail() { _tq_render <<'EOF'
🚨 "Failed password for root from 203.0.113.66" — over and over. Somebody is
guessing the admin password! Tip: `tail -n 25 logs/auth.log` shows 25 lines.
EOF
}

tq_step wc 'Count the lines in the log: `wc -l logs/auth.log`'
_tq_intro_wc() { _tq_render <<'EOF'
**wc** = **w**ord **c**ount. With **-l** it counts **l**ines:

    `wc -l logs/auth.log`
EOF
}
_tq_check_wc() { [[ $TQ_W0 == wc ]] && _tq_has auth.log && _tq_ok; }
_tq_win_wc() { _tq_render <<'EOF'
That's way too many to read one by one. You need better tools…
EOF
}

tq_step less 'Scroll through the whole log: `less logs/auth.log`'
_tq_intro_less() { _tq_render <<'EOF'
**less** opens a file in a scrollable viewer.

    `less logs/auth.log`

Inside less:
  **↑ ↓** or **Space**   scroll
  **/Failed** + Enter   search for "Failed"  (press **n** for the next match)
  **q**                 quit
EOF
}
_tq_check_less() { [[ $TQ_W0 == less ]] && _tq_has auth.log; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 7 — Searching and pipes
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 7 · Searching and pipes"

tq_step grep 'Find every failed login: `grep "Failed" logs/auth.log`'
_tq_intro_grep() { _tq_render <<'EOF'
**grep** searches **inside** files and prints only the lines that match.

    `grep "Failed" logs/auth.log`

Capital letters matter: "failed" won't match "Failed". (Add **-i** to ignore case.)
EOF
}
_tq_check_grep() { [[ $TQ_W0 == grep ]] && _tq_re '[Ff]ailed' && _tq_has auth.log && ! _tq_pipe && _tq_ok; }

tq_step pipe_wc 'Count them with a pipe: `grep "Failed" logs/auth.log | wc -l`'
_tq_intro_pipe_wc() { _tq_render <<'EOF'
The **|** symbol is a **pipe** (Shift + the \ key, above Enter). It sends the
output of the left command **into** the command on the right, like an
assembly line.

    `grep "Failed" logs/auth.log | wc -l`

grep finds the lines → wc counts them.
EOF
}
_tq_check_pipe_wc() { _tq_re 'grep.*\|[[:space:]]*wc' && _tq_ok; }
_tq_win_pipe_wc() {
    _tq_say "$(_tq_failed_count) failed logins. One command found them, the next counted them — that's the power of pipes."
}

tq_step redirect_grep 'Save the evidence: `grep "Failed" logs/auth.log > evidence/failed.txt`'
_tq_intro_redirect_grep() { _tq_render <<'EOF'
**>** works with **any** command's output, not just echo. Save the failed
logins as evidence:

    `grep "Failed" logs/auth.log > evidence/failed.txt`
EOF
}
_tq_failed_ok() {
    local f=$Q/evidence/failed.txt n
    [[ -s $f ]] || return 1
    n=$(_tq_lines "$f")
    [[ $n -eq $(_tq_failed_count) ]] && [[ $(grep -c 'Failed' "$f") -eq $n ]]
}
_tq_check_redirect_grep() { _tq_failed_ok; }
_tq_verify_redirect_grep() { _tq_failed_ok; }
_tq_hint_redirect_grep() { _tq_say 'The file should contain exactly the Failed lines — nothing else. If you made a mistake, just run the command again: > replaces the whole file.'; }

tq_step history 'Search your own command history: `history | grep cd`'
_tq_intro_history() { _tq_render <<'EOF'
**history** lists every command you've typed. It's long, so pipe it into
grep to find just the ones you want:

    `history | grep cd`
EOF
}
_tq_check_history() { _tq_re '^history.*\|[[:space:]]*grep' && _tq_ok; }
_tq_win_history() { _tq_render <<'EOF'
Your history is part of what you'll turn in at the end of this quest.
EOF
}

tq_step find 'Search for the hidden vault key: `find ~/quest -name "*.key"`'
_tq_intro_find() { _tq_render <<'EOF'
grep searches **inside** files. **find** searches for **files themselves** —
by name, size, date, and more. The intruder was after a key file hidden
somewhere in the archive. Track it down:

    `find ~/quest -name "*.key"`

(Translation: look in ~/quest and everything under it for names ending in .key)
EOF
}
_tq_check_find() { [[ $TQ_W0 == find ]] && _tq_has key && _tq_ok; }
_tq_win_find() { _tq_render <<'EOF'
Found it! find printed the key's full path. It was buried 5 folders deep —
imagine clicking through all of those in File Explorer.
EOF
}

tq_step cp_key 'Copy the key into evidence: `cp <the path you found> evidence/`'
_tq_intro_cp_key() { _tq_render <<'EOF'
Copy the key file into your evidence folder. Use the path that find printed.
Use **Tab** to fill in each folder name as you type, or select the path with
your mouse and paste it (**Ctrl+Shift+V** or right-click).

    `cp archive/` ... `/vault.key evidence/`
EOF
}
_tq_key_ok() { cmp -s "$Q/evidence/vault.key" "$Q/archive/2024/sep/old/backup/vault.key"; }
_tq_check_cp_key() { _tq_key_ok; }
_tq_verify_cp_key() { _tq_key_ok; }
_tq_hint_cp_key() { _tq_say '`cp archive/2024/sep/old/backup/vault.key evidence/`'; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 8 — Permissions
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 8 · Permissions"

tq_step run_denied 'Try to run the scanner tool: `./tools/scan.sh`'
_tq_intro_run_denied() { _tq_render <<'EOF'
There's a scanner program in **tools**. To run a program in a folder, type
its path. **./** means "starting right here".

    `./tools/scan.sh`

Something is going to go wrong. That's the point. 😉
EOF
}
_tq_check_run_denied() { _tq_has scan.sh && { [[ $TQ_EC -eq 126 ]] || { [[ -x $Q/tools/scan.sh ]] && _tq_ok; }; }; }
_tq_oops_run_denied() {
    _tq_has scan.sh && [[ $TQ_EC -eq 127 ]] || return 1
    _tq_say "${TQ_Y}No such file from here. Go to the quest folder first: \`cd ~/quest\`${TQ_R}"
}
_tq_win_run_denied() { _tq_render <<'EOF'
**Permission denied.** Linux won't run a file unless it has **x** (execute)
permission. Look with `ls -l tools`:  **-rw-r--r--**  — there's r and w, but no x.

Permissions come in 3 sets of rwx:
    -  rw-   r--   r--
       │     │     └ **others** (everyone else)
       │     └ **group**
       └ **owner** (you)
    **r** = read   **w** = write (change)   **x** = execute (run)
EOF
}

tq_step chmod_x 'Add execute permission: `chmod +x tools/scan.sh`'
_tq_intro_chmod_x() { _tq_render <<'EOF'
**chmod** = **ch**ange **mod**e (mode = permissions). **+x** adds execute:

    `chmod +x tools/scan.sh`
EOF
}
_tq_check_chmod_x() { [[ $TQ_W0 == chmod && -x $Q/tools/scan.sh ]]; }
_tq_verify_chmod_x() { [[ -x $Q/tools/scan.sh ]]; }
_tq_win_chmod_x() { _tq_render <<'EOF'
`ls -l tools` now shows **-rwxr-xr-x**, and the name is probably green (green = runnable).
EOF
}

tq_step run_scan 'Run the scanner again: `./tools/scan.sh`'
_tq_intro_run_scan() { _tq_render <<'EOF'
Now try again:

    `./tools/scan.sh`

Tip: press **↑** twice to bring the command back instead of retyping it.
EOF
}
_tq_check_run_scan() { _tq_has scan.sh && _tq_ok && [[ -f $Q/evidence/scan_results.txt ]]; }
_tq_verify_run_scan() { [[ -f $Q/evidence/scan_results.txt ]]; }

tq_step chmod_640 'Lock down your notes: `chmod 640 evidence/notes.txt`'
_tq_intro_chmod_640() { _tq_render <<'EOF'
chmod also takes **numbers**. Each digit adds up:  **r = 4   w = 2   x = 1**

    7 = rwx    6 = rw-    5 = r-x    4 = r--    0 = ---

The three digits are **owner**, **group**, **others**. So 640 means:
owner can read+write (6), group can read (4), everyone else gets nothing (0).

    `chmod 640 evidence/notes.txt`
EOF
}
_tq_check_chmod_640() { [[ $TQ_W0 == chmod && $(_tq_perm "$Q/evidence/notes.txt") == 640 ]]; }
_tq_verify_chmod_640() { [[ $(_tq_perm "$Q/evidence/notes.txt") == 640 ]]; }
_tq_win_chmod_640() { _tq_render <<'EOF'
Check it: `ls -l evidence/notes.txt` shows **-rw-r-----**.
EOF
}

tq_step groups 'See which groups you belong to: `groups`'
_tq_intro_groups() { _tq_render <<'EOF'
Every file has one **owner** and one **group**. A user can belong to many
groups — like being in several clubs at school. Groups let you share files
with a team.

    `groups`
EOF
}
_tq_check_groups() { [[ $TQ_W0 == groups || $TQ_W0 == id ]] && _tq_ok; }
_tq_win_groups() { _tq_render <<'EOF'
The first one, **{USER}**, is your personal group. The others are groups your account joined.
EOF
}

tq_step chgrp 'Give your notes to a team: `chgrp users evidence/notes.txt`'
_tq_intro_chgrp() { _tq_render <<'EOF'
**chgrp** = **ch**ange **gr**ou**p**. Your notes are set to 640, so whatever
group owns the file can **read** it. Pick one of the groups from the list
`groups` printed (not your own name). **users** works on most computers:

    `chgrp users evidence/notes.txt`
EOF
}
_tq_notes_grouped() { local g; g=$(_tq_group "$Q/evidence/notes.txt"); [[ -n $g && $g != "$(id -gn)" ]]; }
_tq_check_chgrp() { [[ $TQ_W0 == chgrp ]] && _tq_notes_grouped; }
_tq_verify_chgrp() { _tq_notes_grouped; }
_tq_oops_chgrp() {
    [[ $TQ_W0 == chgrp && $TQ_EC -ne 0 ]] || return 1
    _tq_say "${TQ_Y}You can only chgrp to a group you're in. Run \`groups\` and pick a name from that list, or use \`sudo chgrp users evidence/notes.txt\`.${TQ_R}"
}
_tq_win_chgrp() { _tq_render <<'EOF'
`ls -l evidence/notes.txt` — the group column changed. Members of that group can now read it.
EOF
}

tq_step sudo_chown 'Give a file to root: `sudo chown root evidence/failed.txt`'
_tq_intro_sudo_chown() { _tq_render <<'EOF'
**chown** = **ch**ange **own**er. Only the administrator, called **root**, can
give files away. **sudo** ("superuser do") runs one command as root:

    `sudo chown root evidence/failed.txt`

sudo asks for **your** Linux password (the one you made when you set up
Linux). ⚠ When you type a password, **nothing shows up** — no dots, no
stars. That's normal. Type it and press Enter.
EOF
}
_tq_check_sudo_chown() { [[ $(_tq_owner "$Q/evidence/failed.txt") == root ]]; }
_tq_hint_sudo_chown() { _tq_say 'Forgot your Linux password? Tell your teacher — it can be reset from Windows PowerShell.'; }
_tq_win_sudo_chown() { _tq_render <<'EOF'
`ls -l evidence/failed.txt` — the owner column now says **root**.
EOF
}

tq_step denied_write 'Try to add to it: `echo "test" >> evidence/failed.txt`'
_tq_intro_denied_write() { _tq_render <<'EOF'
The file is in **your** folder. Can you still change it?

    `echo "test" >> evidence/failed.txt`
EOF
}
_tq_check_denied_write() { _tq_append && _tq_has failed.txt && [[ $TQ_EC -ne 0 ]]; }
_tq_win_denied_write() { _tq_render <<'EOF'
**Permission denied!** The owner is root, and the permissions (rw-r--r--) only
let the owner write. This is how Linux protects system files from regular
users — and from malware running as a regular user.
EOF
}

tq_step chown_back 'Take the file back: `sudo chown {USER} evidence/failed.txt`'
_tq_intro_chown_back() { _tq_render <<'EOF'
Make yourself the owner again:

    `sudo chown {USER} evidence/failed.txt`
EOF
}
_tq_check_chown_back() { [[ $(_tq_owner "$Q/evidence/failed.txt") == "$TQ_ME" ]]; }
_tq_verify_chown_back() { [[ $(_tq_owner "$Q/evidence/failed.txt") == "$TQ_ME" ]]; }

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 9 — Processes and network
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 9 · Processes and network"

tq_step ps 'List the programs running in this terminal: `ps`'
_tq_intro_ps() { _tq_render <<'EOF'
Every running program is a **process**, and each one has an ID number called
a **PID**. It's the terminal's version of Task Manager.

    `ps`
EOF
}
_tq_check_ps() { [[ $TQ_W0 == ps ]] && _tq_ok; }
_tq_win_ps() { _tq_render <<'EOF'
You'll see **bash** (your terminal's shell) and **ps** itself — it caught itself running!
EOF
}

tq_step ps_aux 'See every process, then filter: `ps aux | grep bash`'
_tq_intro_ps_aux() { _tq_render <<'EOF'
`ps aux` lists **every** process on the computer, from every user. That's a
lot, so pipe it into grep to filter:

    `ps aux | grep bash`
EOF
}
_tq_check_ps_aux() { _tq_re '^ps .*\|[[:space:]]*grep' && _tq_ok; }
_tq_win_ps_aux() { _tq_render <<'EOF'
Columns: **USER** (who runs it), **PID** (its ID), **%CPU**, **%MEM**, … **COMMAND**.
Each bash line is a terminal that's open.
EOF
}

tq_step ip 'Find your network address: `ip addr`'
_tq_intro_ip() { _tq_render <<'EOF'
An **IP address** is a computer's address on a network, like a street
address for mail.

    `ip addr`
EOF
}
_tq_check_ip() { [[ $TQ_W0 == ip && ${TQ_WORDS[1]:-} =~ ^(a|addr|address)$ ]] && _tq_ok; }
_tq_hint_ip() { _tq_say 'Type `ip addr` (or the short version, `ip a`).'; }
_tq_win_ip() { _tq_render <<'EOF'
Find the line that starts with **inet** under **eth0** — that number is your IP.
**127.0.0.1** under **lo** is "loopback": the computer talking to itself.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 10 — Installing software
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 10 · Installing software"

tq_step apt_search 'Search for a program: `apt search cowsay`'
_tq_intro_apt_search() { _tq_render <<'EOF'
**apt** is the **package manager** — an app store for the terminal. Searching
doesn't need admin rights:

    `apt search cowsay`
EOF
}
_tq_check_apt_search() { [[ $TQ_W0 == apt || $TQ_W0 == apt-cache ]] && _tq_re '(search|show)' && _tq_ok; }

tq_step apt_update 'Refresh the package list: `sudo apt update`'
_tq_intro_apt_update() { _tq_render <<'EOF'
Before installing, download the newest catalog of available software.
Installing software changes the whole system, so it needs **sudo**:

    `sudo apt update`
EOF
}
_tq_check_apt_update() { (( TQ_SUDO )) && [[ $TQ_W0 == apt || $TQ_W0 == apt-get ]] && _tq_re 'update' && _tq_ok; }
_tq_oops_apt_update() {
    [[ $TQ_W0 == apt || $TQ_W0 == apt-get ]] && _tq_re 'update' || return 1
    if (( ! TQ_SUDO )); then
        _tq_say "${TQ_Y}Permission denied — put \`sudo\` in front: \`sudo apt update\`${TQ_R}"
    else
        _tq_say "${TQ_Y}apt couldn't finish. Check that you're connected to the internet, then try again.${TQ_R}"
    fi
}

tq_step apt_install 'Install cowsay: `sudo apt install cowsay`'
_tq_intro_apt_install() { _tq_render <<'EOF'
Now install it:

    `sudo apt install cowsay`

If it asks **Do you want to continue? [Y/n]**, press **Y** then Enter.
EOF
}
_tq_check_apt_install() { _tq_cowsay_installed; }
_tq_verify_apt_install() { _tq_cowsay_installed; }

tq_step pipe_cowsay 'Make the cow talk: `echo "I am a Linux hacker" | cowsay`'
_tq_intro_pipe_cowsay() { _tq_render <<'EOF'
Pipe echo's words into your new program:

    `echo "I am a Linux hacker" | cowsay`
EOF
}
_tq_check_pipe_cowsay() { _tq_re '\|[[:space:]]*(/usr/games/)?cowsay' && _tq_ok; }
_tq_oops_pipe_cowsay() {
    _tq_has cowsay && [[ $TQ_EC -eq 127 ]] || return 1
    _tq_say "${TQ_Y}On Debian, cowsay lives in /usr/games. Close and reopen the terminal, or use the full path: \`echo hi | /usr/games/cowsay\`${TQ_R}"
}
_tq_win_pipe_cowsay() { _tq_render <<'EOF'
Same idea as grep | wc: the output of one program became the input of another.
EOF
}

# ══════════════════════════════════════════════════════════════════════════════
#  Chapter 11 — Going remote
# ══════════════════════════════════════════════════════════════════════════════
tq_chapter "Chapter 11 · Going remote"

tq_step ssh 'Log in to the class server: `ssh {SCHOOLUSER}@<server address>`'
_tq_intro_ssh() { _tq_render <<'EOF'
**ssh** (**s**ecure **sh**ell) opens a terminal on **another computer** over
the network. Get the server address and your password from your teacher,
then:

    `ssh {SCHOOLUSER}@`**server-address**

  • The first time, ssh asks **Are you sure you want to continue connecting?**
    Type **yes**. (ssh is checking the server's ID card, its "fingerprint".)
  • Type your password. Nothing will show as you type — that's normal.
  • Look at your prompt — the **hostname** changed! You're on another computer now.
  • The server has its own quest. Follow it there.
  • When you finish, type `exit` to come back to this computer.
EOF
}
_tq_check_ssh() { [[ $TQ_W0 == ssh ]] && _tq_has @ && [[ $TQ_EC -ne 255 ]]; }
_tq_oops_ssh() {
    [[ $TQ_W0 == ssh && $TQ_EC -eq 255 ]] || return 1
    _tq_say "${TQ_Y}ssh couldn't connect, or the password was wrong too many times. Check the address and your username, and make sure you're on the school network.${TQ_R}"
}
_tq_win_ssh() { _tq_render <<'EOF'
Welcome back! Your prompt says **{HOST}** again — you're on your own computer.
EOF
}
