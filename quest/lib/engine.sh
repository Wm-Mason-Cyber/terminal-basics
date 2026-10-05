# shellcheck shell=bash
# shellcheck disable=SC2034  # TQ_* globals are shared with the track files
#
# Terminal Quest engine — sourced by quest.sh, never run directly.
#
# How it works:
#   * A track file (tracks/local.sh, tracks/server.sh) registers steps with
#     tq_chapter / tq_step and defines per-step functions:
#         _tq_intro_<id>    instructions shown when the step starts   (required)
#         _tq_check_<id>    return 0 when the student's last command completed it (required)
#         _tq_win_<id>      explanation shown right after success      (optional)
#         _tq_hint_<id>     shown by `quest hint`                      (optional)
#         _tq_oops_<id>     print a tip + return 0 for a recognised near-miss (optional)
#         _tq_verify_<id>   re-checkable end state, used for grading   (optional)
#         _tq_applies_<id>  return 1 to skip the step on this machine  (optional)
#   * _tq_hook runs from PROMPT_COMMAND after every command. It reads the
#     command from `history 1`, logs it, and runs the current step's check.
#   * Check functions see: TQ_CMD (full command line), TQ_EC (exit code),
#     TQ_W0 (first word, after any `sudo`), TQ_WORDS (array), TQ_SUDO, $PWD.
#   * State lives in ~/.terminal-quest/<track>/ : progress, log.tsv, paused.

TQ_VERSION="1.0"
# Report integrity: tamper-EVIDENT for beginners, not tamper-proof.
TQ_SALT="terminal-quest:wm-mason-cyber:v1"

declare -ga TQ_STEPS=()
declare -gA TQ_GOAL=() TQ_CHAP=() TQ_DONE=()
TQ__chapter=""

tq_chapter() { TQ__chapter=$1; }
tq_step()    { TQ_STEPS+=("$1"); TQ_GOAL[$1]=$2; TQ_CHAP[$1]=$TQ__chapter; }

# ── Setup ─────────────────────────────────────────────────────────────────────

_tq_init() {
    TQ_ME=${USER:-$(id -un)}
    TQ_HOST=${HOSTNAME:-$(hostname)}
    TQ_HOST=${TQ_HOST%%.*}
    TQ_HOME_DIR="$HOME/.terminal-quest"
    TQ_STATE="$TQ_HOME_DIR/$TQ_TRACK"
    TQ_IS_WSL=0
    grep -qi microsoft /proc/version 2>/dev/null && TQ_IS_WSL=1
    mkdir -p "$TQ_STATE" 2>/dev/null
    [[ -r $TQ_HOME_DIR/config ]] && TQ_SCHOOL_USER=$(sed -n 's/^school_user=//p' "$TQ_HOME_DIR/config" | head -1)
    TQ_SCHOOL_USER=${TQ_SCHOOL_USER:-$TQ_ME}
}

_tq_colors() {
    if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
        TQ_B=$'\e[1m' TQ_D=$'\e[2m' TQ_R=$'\e[0m' TQ_C=$'\e[1;36m'
        TQ_G=$'\e[32m' TQ_Y=$'\e[33m' TQ_M=$'\e[35m' TQ_RED=$'\e[31m'
    else
        TQ_B='' TQ_D='' TQ_R='' TQ_C='' TQ_G='' TQ_Y='' TQ_M='' TQ_RED=''
    fi
}

# ── Text rendering ────────────────────────────────────────────────────────────
# Step text is written in quoted heredocs. `backticks` render as cyan commands,
# **double stars** as bold, and {TOKENS} are replaced with this student's values.

_tq_fmt() {
    local t=$1 out='' on=0
    t=${t//'{USER}'/$TQ_ME}
    t=${t//'{HOST}'/$TQ_HOST}
    t=${t//'{HOME}'/$HOME}
    t=${t//'{SCHOOLUSER}'/$TQ_SCHOOL_USER}
    t=${t//'{GROUP}'/${TQ_GROUP:-}}
    t=${t//'{PERIOD}'/${TQ_PERIOD:-}}
    t=${t//'{DROPBOX}'/${TQ_DROPBOX:-}}
    t=${t//'{SHARED}'/${TQ_SHARED:-}}
    while [[ $t == *'`'* ]]; do
        out+=${t%%'`'*}; t=${t#*'`'}
        if (( on )); then out+=$TQ_R; on=0; else out+=$TQ_C; on=1; fi
    done
    t=$out$t; out=''; on=0
    while [[ $t == *'**'* ]]; do
        out+=${t%%'**'*}; t=${t#*'**'}
        if (( on )); then out+=$TQ_R; on=0; else out+=$TQ_B; on=1; fi
    done
    printf '%s' "$out$t"
}

# Render stdin as an indented block.
_tq_render() {
    local text line
    text=$(cat)
    text=$(_tq_fmt "$text")
    while IFS= read -r line; do printf '   %s\n' "$line"; done <<<"$text"
}

_tq_say() { _tq_colors; printf '   %s\n' "$(_tq_fmt "$*")"; }

# ── Step plumbing ─────────────────────────────────────────────────────────────

_tq_run() {  # _tq_run <kind> <id> [args...]
    local f="_tq_${1}_$2"
    declare -F "$f" >/dev/null || return 1
    "$f" "${@:3}"
}

_tq_applies() {
    declare -F "_tq_applies_$1" >/dev/null || return 0
    "_tq_applies_$1"
}

# Load progress; set TQ_CUR (current step), TQ_POS, TQ_TOTAL, TQ_NDONE, TQ_PREV.
_tq_refresh() {
    local id st _
    TQ_DONE=()
    TQ_CUR='' TQ_POS=0 TQ_TOTAL=0 TQ_NDONE=0 TQ_PREV=''
    if [[ -r $TQ_STATE/progress ]]; then
        while read -r id st _; do
            [[ -n $id ]] && TQ_DONE[$id]=$st
        done < "$TQ_STATE/progress"
    fi
    local last=''
    for id in "${TQ_STEPS[@]}"; do
        _tq_applies "$id" || continue
        TQ_TOTAL=$(( TQ_TOTAL + 1 ))
        if [[ -n ${TQ_DONE[$id]:-} ]]; then
            TQ_NDONE=$(( TQ_NDONE + 1 ))
        elif [[ -z $TQ_CUR ]]; then
            TQ_CUR=$id TQ_POS=$TQ_TOTAL TQ_PREV=$last
        fi
        last=$id
    done
}

_tq_mark() { printf '%s %s %(%s)T\n' "$1" "$2" -1 >> "$TQ_STATE/progress"; }

_tq_log() {  # _tq_log <step> <exit> <command>
    local c=${3//$'\t'/ }
    c=${c//$'\n'/ ⏎ }
    printf '%(%Y-%m-%d %H:%M:%S)T\t%s\t%s\t%s\t%s\n' -1 "$1" "$2" "$PWD" "$c" >> "$TQ_STATE/log.tsv"
}

# ── Check helpers (used by track files) ───────────────────────────────────────

_tq_ok()     { [[ ${TQ_EC:-1} -eq 0 ]]; }
_tq_re()     { [[ $TQ_CMD =~ $1 ]]; }
_tq_has()    { [[ $TQ_CMD == *"$1"* ]]; }
_tq_pipe()   { [[ $TQ_CMD == *'|'* ]]; }
_tq_append() { [[ $TQ_CMD == *'>>'* ]]; }
_tq_overwrite() { local t=${TQ_CMD//'>>'/}; [[ $t == *'>'* ]]; }

# _tq_flag l  → true if any short option word contains l (ls -l, ls -la, ls -al)
# _tq_flag --all → true if that exact long option is present
_tq_flag() {
    local w
    for w in "${TQ_WORDS[@]}"; do
        if [[ $1 == --* ]]; then [[ $w == "$1" ]] && return 0
        else [[ $w == -[!-]* && $w == *"$1"* ]] && return 0
        fi
    done
    return 1
}

_tq_perm()  { stat -c %a "$1" 2>/dev/null; }
_tq_owner() { stat -c %U "$1" 2>/dev/null; }
_tq_group() { stat -c %G "$1" 2>/dev/null; }
_tq_lines() { local n; n=$(grep -c . "$1" 2>/dev/null) || n=0; printf '%s' "${n:-0}"; }

# ── The hook ──────────────────────────────────────────────────────────────────

_tq_install_hook() {
    [[ -n ${__TQ_HOOKED:-} ]] && return
    __TQ_HOOKED=1
    # Record every command, even repeats and ones starting with a space,
    # so the tutor sees exactly what was typed.
    HISTCONTROL=
    HISTIGNORE=
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
        PROMPT_COMMAND=(_tq_hook "${PROMPT_COMMAND[@]}")
    else
        PROMPT_COMMAND="_tq_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi
}

_tq_hook() {
    local ec=$? hl num=0 cmd=''
    hl=$(HISTTIMEFORMAT='' builtin history 1)
    if [[ $hl =~ ^[[:space:]]*([0-9]+)[*]?[[:space:]]+(.*)$ ]]; then
        num=${BASH_REMATCH[1]} cmd=${BASH_REMATCH[2]}
    fi
    if [[ -z ${__TQ_LAST:-} ]]; then      # first prompt of this shell
        __TQ_LAST=$num
        [[ -e $TQ_STATE/paused ]] || _tq_greet
        return "$ec"
    fi
    [[ $num == "$__TQ_LAST" ]] && return "$ec"   # Enter on an empty line
    __TQ_LAST=$num
    [[ -e $TQ_STATE/paused ]] && return "$ec"
    _tq_on_command "$ec" "$cmd"
    return "$ec"
}

_tq_on_command() {
    local ec=$1 cmd=$2
    cmd=${cmd#"${cmd%%[![:space:]]*}"}
    cmd=${cmd%"${cmd##*[![:space:]]}"}
    [[ -z $cmd ]] && return
    _tq_refresh
    [[ -z $TQ_CUR ]] && return            # quest finished: stop watching/logging
    [[ $cmd == quest || $cmd == "quest "* ]] && return

    _tq_log "$TQ_CUR" "$ec" "$cmd"
    TQ_CMD=$cmd TQ_EC=$ec TQ_SUDO=0
    read -ra TQ_WORDS <<<"$cmd"
    if [[ ${TQ_WORDS[0]} == sudo ]]; then
        TQ_SUDO=1
        TQ_W0=${TQ_WORDS[1]:-}
    else
        TQ_W0=${TQ_WORDS[0]}
    fi

    _tq_colors
    if _tq_run check "$TQ_CUR"; then
        local done_id=$TQ_CUR
        _tq_mark "$done_id" done
        __TQ_MISS=0
        _tq_refresh
        _tq_celebrate "$done_id"
        if [[ -n $TQ_CUR ]]; then _tq_show; else _tq_run track finale; fi
    else
        __TQ_MISS=$(( ${__TQ_MISS:-0} + 1 ))
        _tq_feedback
        _tq_reminder
    fi
}

# ── Output ────────────────────────────────────────────────────────────────────

_tq_bar() {
    local w=24 filled
    filled=$(( TQ_TOTAL ? TQ_NDONE * w / TQ_TOTAL : 0 ))
    printf '%s   [' "$TQ_D"
    printf '%s%*s' "$TQ_R$TQ_G" "$filled" '' | tr ' ' '#'
    printf '%s%*s' "$TQ_R$TQ_D" $(( w - filled )) '' | tr ' ' '.'
    printf '] %d of %d tasks done%s\n' "$TQ_NDONE" "$TQ_TOTAL" "$TQ_R"
}

_tq_show() {  # show the current step's instructions
    local id=$TQ_CUR
    _tq_colors
    if [[ -z $TQ_PREV || ${TQ_CHAP[$id]} != "${TQ_CHAP[$TQ_PREV]:-}" ]]; then
        printf '\n%s━━━ %s ' "$TQ_M$TQ_B" "${TQ_CHAP[$id]}"
        printf '━%.0s' $(seq 1 $(( 60 - ${#TQ_CHAP[$id]} > 3 ? 60 - ${#TQ_CHAP[$id]} : 3 )))
        printf '%s\n' "$TQ_R"
    fi
    printf '\n%s ➜ Task %d of %d: %s%s\n\n' "$TQ_Y$TQ_B" "$TQ_POS" "$TQ_TOTAL" "$(_tq_fmt "${TQ_GOAL[$id]}")" "$TQ_R"
    _tq_run intro "$id"
    printf '\n%s   (type %squest%s%s to see this again · %squest hint%s%s if you are stuck)%s\n\n' \
        "$TQ_D" "$TQ_R$TQ_C" "$TQ_R" "$TQ_D" "$TQ_R$TQ_C" "$TQ_R" "$TQ_D" "$TQ_R"
}

_tq_celebrate() {
    local praise=("Nice!" "Nailed it." "Exactly right." "You got it." "Great work." "Correct!" "Well done." "Perfect.")
    printf '\n%s ✔ %s%s\n' "$TQ_G$TQ_B" "${praise[RANDOM % ${#praise[@]}]}" "$TQ_R"
    _tq_run win "$1"
    _tq_bar
}

_tq_reminder() {
    printf '%s   ↳ Task %d of %d: %s%s\n' "$TQ_D" "$TQ_POS" "$TQ_TOTAL" "$(_tq_fmt "${TQ_GOAL[$TQ_CUR]}")" "$TQ_R"
    if (( __TQ_MISS >= 3 && __TQ_MISS % 3 == 0 )); then
        printf '   %sStuck? Type %squest hint%s%s for help, or %squest%s%s to read the instructions again.%s\n' \
            "$TQ_Y" "$TQ_C" "$TQ_R" "$TQ_Y" "$TQ_C" "$TQ_R" "$TQ_Y" "$TQ_R"
    fi
}

# Friendly explanation when a command fails and the step has no specific tip.
_tq_feedback() {
    _tq_run oops "$TQ_CUR" && return
    case $TQ_EC in
        0)   return ;;
        127) _tq_say "${TQ_Y}🤔 Linux doesn't know a command called '${TQ_W0}'. Check the spelling — capital letters matter (\`LS\` is not \`ls\`).${TQ_R}" ;;
        126) _tq_say "${TQ_Y}🔒 That file exists but isn't allowed to run (permission denied).${TQ_R}" ;;
        130) _tq_say "${TQ_Y}⏹  You stopped that command with Ctrl+C.${TQ_R}" ;;
        148) _tq_say "${TQ_Y}⏸  Ctrl+Z *paused* that command in the background. Type \`fg\` to bring it back, then Ctrl+C to really stop it.${TQ_R}" ;;
        1) if [[ $TQ_W0 == grep ]]; then
               _tq_say "${TQ_Y}🔍 grep ran, but found no matching lines. Check spelling and capital letters in the word you searched for.${TQ_R}"
           else
               _tq_say "${TQ_Y}⚠  That command reported a problem. Read the message it printed — errors usually say exactly what went wrong.${TQ_R}"
           fi ;;
        *)   _tq_say "${TQ_Y}⚠  That command reported a problem (exit code ${TQ_EC}). Read the message it printed — errors usually say exactly what went wrong.${TQ_R}" ;;
    esac
}

# Prompt anatomy, built from this student's real prompt values.
_tq_prompt_tour() {
    local where=${PWD/#$HOME/\~} sign='$'
    (( EUID == 0 )) && sign='#'
    _tq_colors
    printf '   Your prompt looks like this:\n\n'
    printf '        %s%s%s@%s%s%s:%s%s%s%s\n\n' "$TQ_G$TQ_B" "$TQ_ME" "$TQ_R" "$TQ_G$TQ_B" "$TQ_HOST" "$TQ_R" "$TQ_C" "$where" "$TQ_R" "$sign"
    printf '     %s%-14s%s who you are — your %susername%s\n' "$TQ_G" "$TQ_ME" "$TQ_R" "$TQ_B" "$TQ_R"
    printf '     %-14s means "at"\n' "@"
    printf '     %s%-14s%s which computer you are on — the %shostname%s\n' "$TQ_G" "$TQ_HOST" "$TQ_R" "$TQ_B" "$TQ_R"
    printf '     %-14s a separator\n' ":"
    printf '     %s%-14s%s which folder you are in — the %spath%s (~ = your home folder)\n' "$TQ_C" "$where" "$TQ_R" "$TQ_B" "$TQ_R"
    printf '     %-14s "ready for a command" (a # here would mean you are root, the admin)\n\n' "$sign"
}

_tq_greet() {
    _tq_refresh
    [[ -z $TQ_CUR ]] && return
    _tq_colors
    if [[ ! -e $TQ_STATE/welcomed ]]; then
        : > "$TQ_STATE/welcomed"
        _tq_run track welcome
    else
        printf '\n%s ⚑ Terminal Quest%s — welcome back! You have finished %d of %d tasks.\n' "$TQ_M$TQ_B" "$TQ_R" "$TQ_NDONE" "$TQ_TOTAL"
    fi
    _tq_show
}

# ── Grading ───────────────────────────────────────────────────────────────────

# Prints one line per step. With --csv prints only "passed,failed".
_tq_verify() {
    local csv=0 id st p=0 f=0 lines=() goal
    local TQ_B='' TQ_C='' TQ_R=''   # plain text for reports
    [[ ${1:-} == --csv ]] && csv=1
    _tq_refresh
    for id in "${TQ_STEPS[@]}"; do
        goal=$(_tq_fmt "${TQ_GOAL[$id]}")
        if ! _tq_applies "$id"; then
            lines+=("  N/A   $id — $goal")
            continue
        fi
        st=${TQ_DONE[$id]:-}
        if [[ $st == done ]]; then
            if declare -F "_tq_verify_$id" >/dev/null && ! "_tq_verify_$id"; then
                f=$(( f + 1 )); lines+=("  FAIL  $id — $goal  (was done, but the result is now missing or changed)")
            else
                p=$(( p + 1 )); lines+=("  PASS  $id — $goal")
            fi
        elif [[ $st == skipped ]]; then
            f=$(( f + 1 )); lines+=("  FAIL  $id — $goal  (skipped)")
        else
            f=$(( f + 1 )); lines+=("  FAIL  $id — $goal  (not completed)")
        fi
    done
    if (( csv )); then
        printf '%d,%d\n' "$p" "$f"
    else
        printf '%s\n' "${lines[@]}"
        printf '\n  Score: %d / %d tasks passed\n' "$p" "$(( p + f ))"
    fi
}

_tq_report_body() {
    local school=$1
    printf '================================================================\n'
    printf '  Terminal Quest — %s track — Turn-in Report\n' "$TQ_TRACK"
    printf '================================================================\n'
    printf '  School username: %s\n' "$school"
    printf '  Linux username:  %s\n' "$TQ_ME"
    printf '  Computer:        %s\n' "$TQ_HOST"
    printf '  Generated:       %(%Y-%m-%d %H:%M:%S)T\n' -1
    printf '  Quest version:   %s\n' "$TQ_VERSION"
    printf '\n----- Tasks -----------------------------------------------------\n'
    _tq_verify
    printf '\n----- Command log (time, task, exit code, folder, command) ------\n'
    if [[ -r $TQ_STATE/log.tsv ]]; then
        cat "$TQ_STATE/log.tsv"
    else
        printf '(no commands recorded)\n'
    fi
    printf '\n----- Bash history ----------------------------------------------\n'
    if [[ -r $HOME/.bash_history ]]; then
        tail -n 500 "$HOME/.bash_history"
    else
        printf '(no history file)\n'
    fi
}

_tq_hash() { printf '%s\n%s' "$1" "$TQ_SALT" | sha256sum | cut -d' ' -f1; }

_tq_ask_school_user() {
    local u=''
    while [[ ! $u =~ ^[A-Za-z0-9._-]+$ ]]; do
        read -r -p "   What is your school username (the one your teacher gave you)? " u </dev/tty || return 1
    done
    TQ_SCHOOL_USER=$u
    mkdir -p "$TQ_HOME_DIR"
    printf 'school_user=%s\n' "$u" > "$TQ_HOME_DIR/config"
}

_tq_report() {
    local school body out
    [[ -r $TQ_HOME_DIR/config ]] || _tq_ask_school_user || return 1
    school=$TQ_SCHOOL_USER
    history -a 2>/dev/null   # flush this shell's history to ~/.bash_history first
    body=$(_tq_report_body "$school")
    out="$HOME/terminal_quest_report_${school}.txt"
    printf '%s\nVerification: %s\n' "$body" "$(_tq_hash "$body")" > "$out"
    _tq_colors
    printf '\n %s✔ Report saved:%s %s\n\n' "$TQ_G$TQ_B" "$TQ_R" "$out"
    _tq_run track report_help "$out"
}

# Run as root inside the server: verify every member of a group.
# Output: username,passed,failed  (one line per student)
_tq_grade_all() {
    local grp=${1:-${TQ_GROUP:-}} members u home res
    (( EUID == 0 )) || { echo "grade-all must run as root" >&2; return 1; }
    [[ -n $grp ]] || { echo "usage: quest.sh grade-all <group>" >&2; return 1; }
    members=$(getent group "$grp" | cut -d: -f4)
    for u in ${members//,/ }; do
        home=$(getent passwd "$u" | cut -d: -f6)
        res=$(cd / && runuser -u "$u" -- env -i HOME="$home" USER="$u" LOGNAME="$u" PATH=/usr/local/bin:/usr/bin:/bin:/usr/games \
              bash "$TQ_ROOT/quest.sh" verify --csv 2>/dev/null) || res="0,0"
        printf '%s,%s\n' "$u" "${res:-0,0}"
    done
}

# ── The `quest` command ───────────────────────────────────────────────────────

_tq_usage() {
    _tq_render <<'EOF'
**Terminal Quest commands**

  `quest`            show your current task again
  `quest hint`       get a hint for the current task
  `quest list`       see every task and your progress
  `quest skip`       skip a task you really can't do (it will count as not done)
  `quest report`     make your turn-in report file
  `quest pause`      stop the tutor watching (until `quest resume`)
  `quest resume`     turn the tutor back on
  `quest reset`      start over from the beginning
EOF
}

quest() {
    local sub=${1:-task}
    shift 2>/dev/null
    _tq_colors
    _tq_refresh
    case $sub in
        task|show)
            if [[ -e $TQ_STATE/paused ]]; then
                _tq_say "The tutor is paused. Type \`quest resume\` to turn it back on."
            elif [[ -n $TQ_CUR ]]; then _tq_show
            else _tq_run track finale
            fi ;;
        hint)
            [[ -z $TQ_CUR ]] && { _tq_say "You've finished every task!"; return; }
            _tq_log "$TQ_CUR" - "[quest hint]"
            printf '\n %s💡 Hint for task %d:%s\n' "$TQ_Y$TQ_B" "$TQ_POS" "$TQ_R"
            _tq_run hint "$TQ_CUR" || _tq_say "Read the instructions again carefully with \`quest\`. Type the command exactly as shown in color, then press Enter."
            echo ;;
        list)
            local id mark n=0
            printf '\n'
            for id in "${TQ_STEPS[@]}"; do
                _tq_applies "$id" || continue
                n=$(( n + 1 ))
                case ${TQ_DONE[$id]:-} in
                    done)    mark="$TQ_G✔$TQ_R" ;;
                    skipped) mark="$TQ_RED✘$TQ_R" ;;
                    *)       if [[ $id == "$TQ_CUR" ]]; then mark="$TQ_Y➜$TQ_R"; else mark="$TQ_D·$TQ_R"; fi ;;
                esac
                printf '  %s %2d. %s\n' "$mark" "$n" "$(_tq_fmt "${TQ_GOAL[$id]}")"
            done
            printf '\n'; _tq_bar; printf '\n' ;;
        skip)
            [[ -z $TQ_CUR ]] && { _tq_say "Nothing left to skip!"; return; }
            local ans
            read -r -p "   Skip task $TQ_POS? It will count as NOT done in your report. [y/N] " ans
            if [[ $ans == [Yy]* ]]; then
                _tq_log "$TQ_CUR" - "[quest skip]"
                _tq_mark "$TQ_CUR" skipped
                _tq_refresh
                if [[ -n $TQ_CUR ]]; then _tq_show; else _tq_run track finale; fi
            fi ;;
        report)  _tq_report ;;
        verify)  _tq_verify "$@" ;;
        pause)   : > "$TQ_STATE/paused"; _tq_say "Tutor paused. Type \`quest resume\` to turn it back on." ;;
        resume)  rm -f "$TQ_STATE/paused"; _tq_say "Tutor is back on!"; _tq_refresh; [[ -n $TQ_CUR ]] && _tq_show ;;
        reset)
            local ans
            read -r -p "   Erase ALL your quest progress and start over? [y/N] " ans
            if [[ $ans == [Yy]* ]]; then
                rm -rf "$TQ_STATE"
                mkdir -p "$TQ_STATE"
                _tq_run track reset
                _tq_say "Progress erased. Starting over…"
                _tq_refresh; _tq_show
            fi ;;
        grade-all) _tq_grade_all "$@" ;;
        version) echo "Terminal Quest $TQ_VERSION ($TQ_TRACK track)" ;;
        help|-h|--help) _tq_usage ;;
        *) _tq_say "Unknown quest command: $sub"; _tq_usage ;;
    esac
}
