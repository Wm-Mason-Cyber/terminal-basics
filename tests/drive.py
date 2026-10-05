#!/usr/bin/env python3
"""
Drive a real interactive bash through a Terminal Quest track and report
which commands completed a task. Used to test the tutor after editing steps.

    python3 tests/drive.py local  tests/solutions/local.txt   [--show]
    python3 tests/drive.py server tests/solutions/server.txt  [--show]

Each non-blank, non-# line of the solution file is typed into the shell.
  - A line starting with "!" is typed verbatim but NOT expected to complete a task
    (used for deliberate mistakes, which should produce feedback instead).
  - "<ctrl-c>" sends Ctrl+C.   "<sleep N>" waits N seconds.
  - "<keys TEXT>" sends raw keystrokes (\\n, \\x0f etc. are interpreted) and waits for the prompt.
  - "<send TEXT>" sends raw keystrokes without waiting (e.g. to open nano/less).
The run uses a throwaway HOME unless TQ_TEST_HOME is set (server tests run as
real users). Exits non-zero if any expected completion did not happen.
"""

import os
import pty
import re
import select
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROMPT = "@@TQPROMPT@@"


def read_until(fd, marker, timeout=20.0):
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            if marker.encode() in buf:
                return buf.decode(errors="replace")
    return buf.decode(errors="replace") + "\n[TIMEOUT]"


def strip_ansi(s):
    return re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", s)


def main():
    track, solution = sys.argv[1], sys.argv[2]
    show = "--show" in sys.argv
    home = os.environ.get("TQ_TEST_HOME") or tempfile.mkdtemp(prefix="tq-home-")
    rc = os.path.join(home, ".tq_test_rc")
    with open(rc, "w") as f:
        f.write(f"""
export TQ_TRACK={track}
PS1='{PROMPT} '
{os.environ.get('TQ_TEST_RC_EXTRA', '')}
. "{os.environ.get('TQ_TEST_QUEST', ROOT + '/quest/quest.sh')}"
""")

    env = dict(os.environ, HOME=home, TERM="xterm-256color")
    env.pop("PROMPT_COMMAND", None)
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(home)
        os.execvpe("bash", ["bash", "--noprofile", "--rcfile", rc, "-i"], env)

    out = read_until(fd, PROMPT)
    if show:
        print(strip_ansi(out))

    failures = 0
    done = 0
    for raw in open(solution):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        expect = not line.startswith("!")
        cmd = line[1:] if line.startswith("!") else line

        if cmd.startswith("<sleep "):
            time.sleep(float(cmd[7:-1]))
            continue
        if cmd == "<ctrl-c>":
            os.write(fd, b"\x03")
            out = read_until(fd, PROMPT)
        elif cmd.startswith("<send "):     # raw keys, don't wait for a prompt
            os.write(fd, cmd[6:-1].encode().decode("unicode_escape").encode())
            time.sleep(0.6)
            continue
        elif cmd.startswith("<keys "):
            os.write(fd, cmd[6:-1].encode().decode("unicode_escape").encode())
            out = read_until(fd, PROMPT)
        else:
            os.write(fd, (cmd + "\n").encode())
            if cmd.startswith("yes"):
                time.sleep(0.4)
                continue          # next line will be <ctrl-c>
            out = read_until(fd, PROMPT)

        text = strip_ansi(out)
        completed = "✔" in text
        status = "ok " if completed == expect else "BAD"
        if completed:
            done += 1
        if completed != expect:
            failures += 1
        print(f"[{status}] {'done' if completed else '----'}  {cmd}")
        if show or completed != expect:
            print("      | " + "\n      | ".join(text.strip().splitlines()[-25:]))

    os.write(fd, b"exit\n")
    time.sleep(0.3)
    print(f"\nHOME={home}\ntasks completed: {done}   unexpected results: {failures}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
