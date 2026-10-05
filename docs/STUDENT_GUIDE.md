# Terminal Quest: Learn the Linux Command Line

**What you'll do:** Learn to control a computer by typing commands. A built-in tutor watches each command you type, tells you if it worked, and explains what happened.

**What you'll turn in:**

1. **Part 1 (your computer):** a report file the quest makes for you, uploaded to Schoology.
2. **Part 2 (the class server):** nothing to upload. Your teacher's script checks your work on the server.

**Time:** about 2–3 class periods. Your progress saves automatically, so you can stop and pick up where you left off.

---

## 1. What is a terminal?

Normally you use a computer by **clicking**: opening folders, double-clicking files, dragging things to the trash. A **terminal** does the same jobs by **typing**. You type a **command** and press **Enter**, and the computer does it.

Why bother? Typing is faster once you know how. It works on computers that have no screen (most servers on the internet). And it's the main tool for almost every job in cybersecurity.

You'll use **Linux** on your Windows laptop, through **WSL** (Windows Subsystem for Linux). It's a real Linux system that runs inside Windows.

### Open your terminal

* Click **Start**, type **Debian** (or **Ubuntu**, whichever your laptop has), and press Enter.
* You can also open **Windows Terminal** and pick Debian from the **⌄** drop-down menu next to the tabs.

---

## 2. Reading the prompt

When the terminal is ready for a command, it shows a **prompt**. Out of the box, it looks something like this:

```
jsmith@LAPTOP-7Q2K:~$
```

Every piece of it means something:

| Piece | Name | What it tells you |
|---|---|---|
| `jsmith` | **username** | *Who* you are logged in as |
| `@` | "at" | — |
| `LAPTOP-7Q2K` | **hostname** | *Which computer* you're typing on |
| `:` | separator | — |
| `~` | **path** | *Which folder* you're in right now. `~` means your home folder |
| `$` | prompt sign | Ready for a command. A `#` means you're **root** (the all-powerful admin). Be careful! |

**Read your prompt before every command.** In Part 2 you'll log into a different computer, and the hostname will change. That's how you'll know which computer your commands are going to.

---

## 3. Paths are just folders

You already know folders from File Explorer. Linux has exactly the same idea, written a little differently.

| Idea | Windows (File Explorer) | Linux (terminal) |
|---|---|---|
| A folder is called a… | folder | **directory** |
| Separator between folders | `\` backslash | `/` forward slash |
| The very top of everything | `C:\` | `/` (called **root**) |
| Your personal folder | `C:\Users\jsmith` | `/home/jsmith`, or just `~` |
| "The folder I'm looking at" | the window you have open | the **working directory** (shown in the prompt) |
| Go into a folder | double-click it | `cd foldername` |
| Go up one level | the ↑ Up arrow button | `cd ..` |
| Hidden files | "Show hidden items" checkbox | names that start with a dot, like `.bashrc` |

A **path** is the address of a file or folder, like the address bar in File Explorer:

```
/home/jsmith/quest/evidence/notes.txt
│ └──┬─┘└──┬─┘└─┬─┘└───┬──┘ └───┬───┘
│  home  you  quest  evidence  the file
└ root (the top)
```

* An **absolute** path starts with `/`. It's the full address, and it works from anywhere.
* A **relative** path doesn't start with `/`. It means "starting from the folder I'm in now." For example, `evidence/notes.txt`.
* `.` means "this folder." `..` means "the folder above this one." `~` means "my home folder."

**WSL bonus:** your Windows C: drive is inside Linux at `/mnt/c`. So `C:\Users` in Windows is `/mnt/c/Users` in Linux: the same files, reached two different ways.

---

## 4. Keyboard survival kit

| Key | What it does |
|---|---|
| **Enter** | Run the command you typed |
| **Tab** | Finish a file or folder name for you. Use it constantly: less typing, no typos |
| **↑ / ↓** | Scroll back through commands you already typed |
| **Ctrl+C** | **Stop** whatever is running. (In the terminal this does *not* mean copy!) |
| **q** | Quit a full-screen viewer like `man` or `less` |
| **Ctrl+Shift+C** / **Ctrl+Shift+V** | Copy / paste in Windows Terminal (right-click also pastes) |
| **Ctrl+L** or `clear` | Clean up the screen |

**Rules that trip everyone up at first:**

* **Spaces matter.** `cd ..` works and `cd..` doesn't. Put a space between the command and each thing after it.
* **Capitals matter.** `ls`, `LS` and `Ls` are three different things to Linux. Commands are almost always lowercase.
* **No news is good news.** Many commands print *nothing* when they succeed. If there's no error, it worked.
* **Passwords are invisible.** When you type a password in the terminal, *nothing* appears: no dots, no stars. Type it and press Enter anyway.

---

## 5. Install the quest

Copy this whole line, paste it into your terminal (**Ctrl+Shift+V** or right-click), and press **Enter**:

```
sudo apt update && sudo apt install -y git && git clone https://github.com/Wm-Mason-Cyber/terminal-basics.git ~/terminal-basics && bash ~/terminal-basics/install.sh
```

* It will ask for your **Linux password**. That's the one you made when you first set up Debian/Ubuntu, *not* your school password. Remember, nothing shows while you type it.
* It will ask for your **school username**. Type it exactly as your teacher gave it to you. It's used to name your turn-in file.
* When it says **Installed!**, **close the terminal window and open it again.** The quest starts automatically.

---

## 6. How the quest works

The tutor shows you one task at a time. Type the command shown in **color**, then press Enter. After every command, the tutor tells you what happened:

* **✔ Nice!** You finished the task. You'll get a short explanation of what you just saw, then the next task.
* **A yellow tip** You made a common mistake, and the tip tells you how to fix it.
* **↳ Task 12 of 57: …** A reminder of what you're working on. You're allowed to experiment! Try other commands any time.

Commands for controlling the tutor:

| Command | What it does |
|---|---|
| `quest` | Show the current task's instructions again |
| `quest hint` | Get a hint |
| `quest list` | See every task and your progress |
| `quest skip` | Skip a task you truly can't do. **It counts as not done** |
| `quest report` | Make your turn-in file |
| `quest pause` / `quest resume` | Turn the tutor off and on |

---

## 7. Part 1 — Your computer (11 chapters)

The story: you're a new security analyst. Someone has been trying to break into a web server, and you'll dig through its files to collect evidence. Everything happens inside a `quest` folder that the tutor makes for you.

| Chapter | You'll learn | Commands |
|---|---|---|
| 1. Who and where am I? | Reading the prompt | `whoami` `hostname` `pwd` `ls` |
| 2. Survival skills | Cleaning up, reading manuals, stopping runaway commands | `clear` `man` `--help` `yes` + **Ctrl+C** |
| 3. Moving around | Moving between folders, hidden files, absolute vs. relative paths | `cd` `ls -a` `ls -l` `cat` `..` `~` `/` |
| 4. Making things | Creating folders and files, writing to files | `mkdir` `touch` `echo` `>` `>>` `nano` |
| 5. Copy, move, delete | Managing files (there's no Recycle Bin!) | `cp` `mv` `rm` `rmdir` `*` |
| 6. Reading big files | Looking at log files | `head` `tail` `wc` `less` |
| 7. Searching and pipes | Finding text in files and finding files, chaining commands | `grep` `\|` `history` `find` |
| 8. Permissions | Who is allowed to read, change, or run a file | `chmod` `groups` `chgrp` `sudo` `chown` |
| 9. Processes and network | What's running, and your computer's network address | `ps` `ps aux` `ip addr` |
| 10. Installing software | The terminal's app store | `apt search` `sudo apt update` `sudo apt install` |
| 11. Going remote | Logging into another computer | `ssh` |

### Redirects and pipes, in one picture

```
echo "hi"  >  file.txt      >   send output INTO a file, REPLACING what's there
echo "hi"  >> file.txt      >>  send output to the END of a file (keeps what's there)
grep Failed auth.log | wc -l     |   send output INTO the next command (a "pipe")
```

### Permissions, in one picture

```
-rwxr-x---   1  jsmith  p1   2048  Oct 3 09:12  scan.sh
│└┬┘└┬┘└┬┘      └──┬─┘  └┬┘
│ │  │  └ others     owner group
│ │  └ group          r = read (4)   w = write (2)   x = execute/run (1)
│ └ owner             chmod 750 = rwx (4+2+1) · r-x (4+1) · --- (0)
└ - file, d directory
```

---

## 8. Part 2 — The class server

The last task in Part 1 sends you to the **class server**: a Linux computer you share with everyone in your class period. You'll connect to it with `ssh`.

Your teacher will give you:

* **Server address:** `______________________`
* **Your username:** your school username
* **Your server password:** `______________________`

To connect, type (replacing the parts in brackets):

```
ssh yourusername@serveraddress
```

1. The first time, ssh asks **"Are you sure you want to continue connecting (yes/no)?"** Type `yes` and press Enter.
2. Type your **server password**. Nothing will show as you type.
3. **Look at your prompt.** The hostname has changed: you're typing on a different computer now!
4. A second quest starts automatically. It teaches what changes when a computer is shared: private home folders, a shared dropbox for your period, groups, seeing other people's processes, and why you don't get `sudo` there.
5. When you finish, type `exit` to come back to your own computer.

You can log out and back in as many times as you like. Your progress is saved on the server.

---

## 9. Turning it in

### Part 1: upload your report

1. Run `quest report`. It creates **terminal_quest_report_*yourusername*.txt** in your home folder.
2. Go to your home folder: `cd ~`
3. Open it in File Explorer: `explorer.exe .` (don't forget the dot, which means "this folder")
4. Upload the report file to the Schoology assignment.

The report lists which tasks you finished, plus the commands you typed. It has a **verification code** at the bottom, so **don't edit it**. Editing it breaks the code, and your teacher will see that. If you finish more tasks later, just run `quest report` again and upload the new file.

### Part 2: nothing to upload

Your teacher's grading script checks your work on the server directly.

---

## 10. Command cheat sheet

| Command | Meaning | Example |
|---|---|---|
| `whoami` | Show your username | `whoami` |
| `hostname` | Show the computer's name | `hostname` |
| `pwd` | **P**rint **w**orking **d**irectory: where am I? | `pwd` |
| `ls` | **L**i**s**t files. `-l` long details, `-a` include hidden | `ls -la` |
| `cd` | **C**hange **d**irectory | `cd quest` · `cd ..` · `cd ~` · `cd /` |
| `clear` | Clear the screen | `clear` |
| `man` / `--help` | Read a command's manual | `man ls` · `ls --help` |
| `mkdir` | **M**a**k**e a **dir**ectory | `mkdir evidence` |
| `touch` | Create an empty file | `touch notes.txt` |
| `echo` | Print text | `echo hello` |
| `>` | Redirect output into a file (**replaces** it) | `echo hi > notes.txt` |
| `>>` | Redirect output to the end of a file (**appends**) | `echo more >> notes.txt` |
| `\|` | Pipe: send output into another command | `history \| grep cd` |
| `cat` | Print a whole file | `cat notes.txt` |
| `nano` | Edit a file (save **Ctrl+O**, exit **Ctrl+X**) | `nano notes.txt` |
| `cp` | **C**o**p**y: `cp from to` | `cp a.txt backup/` |
| `mv` | **M**o**v**e or rename: `mv from to` | `mv old.txt new.txt` |
| `rm` | **R**e**m**ove a file. **Gone forever!** | `rm junk.txt` |
| `rmdir` | Remove an **empty** folder | `rmdir junk` |
| `head` / `tail` | First / last 10 lines (`-n 5` for 5 lines) | `tail -n 20 auth.log` |
| `less` | Scroll through a file (`/` search, `q` quit) | `less auth.log` |
| `wc` | Count lines (`-l`), words (`-w`), characters (`-c`) | `wc -l auth.log` |
| `grep` | Search **inside** files for text (`-i` ignore case) | `grep Failed auth.log` |
| `find` | Search for **files** by name | `find ~ -name "*.key"` |
| `history` | List the commands you've typed | `history` |
| `chmod` | Change permissions | `chmod +x scan.sh` · `chmod 640 notes.txt` |
| `groups` | List your groups | `groups` |
| `chgrp` | Change a file's group | `chgrp users notes.txt` |
| `chown` | Change a file's owner (needs `sudo`) | `sudo chown root file.txt` |
| `sudo` | Run one command as the admin (root) | `sudo apt update` |
| `ps` | List running processes (`aux` = everyone's) | `ps aux` |
| `ip` | Network info: your IP address | `ip addr` |
| `apt` | Install and search for software | `apt search cowsay` · `sudo apt install cowsay` |
| `ssh` | Log into another computer | `ssh jsmith@10.0.0.50` |
| `exit` | Log out / close the terminal | `exit` |

---

## 11. Troubleshooting

| Problem | Fix |
|---|---|
| **"command not found"** | Check spelling and capitals. Make sure there's a space after the command. |
| **"No such file or directory"** | You're probably in the wrong folder. Run `pwd` to check, and `cd ~/quest` to get back. Use **Tab** to avoid typos. |
| **The screen is filling with text and won't stop** | Press **Ctrl+C**. |
| **I'm stuck in a screen and can't type commands** (`man`, `less`) | Press **q**. |
| **I'm stuck in nano** | **Ctrl+X** to exit. If it asks "Save modified buffer?", press **Y** then Enter. |
| **I see a `>` prompt and nothing happens** | You opened a quote (`"`) and didn't close it. Press **Ctrl+C** and retype the command. |
| **I forgot my Linux password** (needed for `sudo`) | Ask your teacher. It can be reset from Windows PowerShell with `wsl -u root passwd yourlinuxname`. |
| **The tutor disappeared** | Type `quest`. If it says paused, type `quest resume`. If `quest` is "not found", close the terminal and reopen it. |
| **ssh: "Connection refused" or "timed out"** | Check the server address, and make sure you're on the school network. |
| **ssh: "Permission denied, please try again"** | Wrong password, or a typo in the username. Remember, the password doesn't show as you type. |
| **I want to start over** | `quest reset` (erases your quest progress and resets the quest folder). |
