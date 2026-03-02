#!/bin/bash

set_alias() { if command -v $1 >/dev/null 2>&1; then alias "$2"="$1"; fi; }
set_alias nala apt
set_alias bat cat
set_alias exa ls

# Priority-based editor (The first one found becomes 'edit')
for cmd in fresh micro nano vim vi; do
    if command -v "$cmd" >/dev/null 2>&1; then
        edit() { "$cmd" "$@"; }
        break # Stop looking once we find our preferred editor
    fi
done

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
alias l="ls -clAsh ${ls_opts}"
alias ll="ls -ahl ${ls_opts}"
alias lh="ls -hl ${ls_opts}"
alias la="ls -clash ${ls_opts}"

alias l="ls -clAsh ${ls_opts}"

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
# Creates SSH key with unique name
mkkey() {
    if [ -z "$1" ]; then
        echo "Usage: mkkey <name> [comment]" >&2
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

# --- Git ---
alias gitlog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
