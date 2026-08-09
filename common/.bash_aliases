#!/bin/bash

set_alias() { if command -v $1 >/dev/null 2>&1; then alias "$2"="$1"; fi; }
set_alias nala apt
set_alias bat cat
set_alias exa ls


# --- Settings ---
export ls_opts="--group-directories-first --time-style=long-iso --color=auto"

# --- Modern ls Aliases ---
# Use the 'ls' alias inside the others to stay DRY
# In your common/.bash_aliases
if command -v exa >/dev/null 2>&1; then
    # alias ls="exa --group-directories-first --time-style=long-iso"
    alias ls="exa ${ls_opts}"
    alias l="ls -lbhHigUmuSa"
    alias ll="ls -lbh"
else
    alias ls="/bin/ls -F ${ls_opts}"
fi
alias dir='ls'
alias l="ls -lAsh ${ls_opts}"
alias ll="ls -ahl ${ls_opts}"
alias lh="ls -hl ${ls_opts}"
alias la="ls -lash ${ls_opts}"

alias l="ls -lAsh ${ls_opts}"

# --- Navigation ---
# Using an array for "up" navigation is overkill, but keeping them concise is key
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cd..='cd ..'
alias ~='cd ~'
alias home='cd ~'

# --- Tools ---
alias port='netstat -tulpn | grep'
alias ping='ping -c 3'
alias lan='ip -c -br a'
alias cls='clear'

# --- Functions ---
# Creates directory and enters it
md() {
    if [ -n "$1" ]; then
        mkdir -p "$1" && cd "$1"
    else
        echo "Usage: md <directory>"
    fi
}

# Priority-based editor (The first one found becomes 'edit')
unalias edit 2>/dev/null
edit() {
    if [ -n "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
        command "$EDITOR" "$@"
        return
    fi
    local cmd
    for cmd in fresh micro nano vim vi; do
        if command -v "$cmd" >/dev/null 2>&1; then
            command "$cmd" "$@"
            return
        fi
    done
    echo "edit: no editor found" >&2
    return 1
}
alias e='edit'

# Copies stdin to the best available clipboard helper.
# If nothing is available, it prints stdin to stdout unchanged.
toclip() {
    if [ -t 0 ]; then
        if command -v wl-paste >/dev/null 2>&1; then
            wl-paste
            return $?
        fi
        if command -v xclip >/dev/null 2>&1; then
            xclip -selection clipboard -o
            return $?
        fi
        if command -v xsel >/dev/null 2>&1; then
            xsel --clipboard --output
            return $?
        fi
        if command -v pbpaste >/dev/null 2>&1; then
            pbpaste
            return $?
        fi
        printf '%s\n' "toclip: no clipboard tool found" >&2
        return 1
    else
        if command -v wl-copy >/dev/null 2>&1; then
            wl-copy
            return $?
        fi
        if command -v xclip >/dev/null 2>&1; then
            xclip -selection clipboard
            return $?
        fi
        if command -v xsel >/dev/null 2>&1; then
            xsel --clipboard --input
            return $?
        fi
        if command -v pbcopy >/dev/null 2>&1; then
            pbcopy
            return $?
        fi
        cat
    fi
}
cb() { toclip; } # Copy to clipboard
pb() { # Paste from clipboard
    if command -v wl-paste >/dev/null 2>&1; then
        wl-paste
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard --output
    elif command -v pbpaste >/dev/null 2>&1; then
        pbpaste
    else
        echo "No clipboard paste tool found" >&2
        return 1
    fi
}
# Creates a hashed sha256 key
genhash() {
    if [ -z "$1" ]; then
        local input
        read -rsp "Passphrase: " input
        echo
        printf '%s' "$input" | sha256sum | awk '{print $1}' | toclip
    else
        printf '%s' "$1" | sha256sum | awk '{print $1}' | toclip
    fi
}
# Creates a random hex or base64 string
genkey() {
    local mode="${1:-hex}"
    local bytes="${2:-32}"

    case "$mode" in
        hex|base64) ;;
        *)
            echo "Usage: genkey [hex|base64] [bytes]. Defaulting to 'hex'." >&2
            mode="hex"
            bytes="${1:-32}"
            ;;
    esac

    openssl rand "-$mode" "$bytes" | toclip
}
# Creates SSH key with unique name
genssh() {
    if [ -z "$1" ]; then
        echo "Usage: genssh <name> [comment]" >&2
        return 1
    fi
    local name="$1"
    shift
    local comment="${*:-$USER@$(hostname)}"
    local keyfile="$HOME/.ssh/id_ed25519-$name"
    if [ -e "$keyfile" ] || [ -e "$keyfile.pub" ]; then
        echo "Error: $keyfile (or .pub) already exists" >&2
        return 2
    fi
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen \
        -t ed25519 \
        -a 100 \
        -f "$keyfile" \
        -C "$comment"
}

# Function to add all keys in ~/.ssh (ignoring public keys and config)
ssh-add-all() {
    find ~/.ssh -type f -not -name "*.pub" -not -name "config" -not -name "known_hosts" -exec ssh-add {} +
}

# --- Git ---
alias gitlog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'

alias tmux='command tmux'
tmx() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed or not in PATH" >&2
    return 127
  fi

  if [ "$#" -gt 0 ]; then
    command tmux "$@"
    return
  fi

  local dir slug session socket conf
  dir="$PWD"
  conf="$dir/.tmux.conf.local"

  slug="$(printf '%s' "$dir" | shasum | awk '{print $1}' | cut -c1-12)"
  session="dir_$slug"
  socket="dir_$slug"

  if [ ! -f "$conf" ]; then
    printf '%s\n' \
      'set -g mouse on' \
      'set -g history-limit 100000' > "$conf"
  fi

  if command tmux -L "$socket" has-session -t "$session" 2>/dev/null; then
    command tmux -L "$socket" attach-session -t "$session"
  else
    command tmux -L "$socket" -f "$conf" new-session -s "$session" -c "$dir"
  fi
}
