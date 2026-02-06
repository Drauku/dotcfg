#!/bin/bash

set_alias() { if command -v $1 >/dev/null 2>&1; then alias "$2"="$1"; fi; }
set_alias nala apt
set_alias bat cat
set_alias exa ls

# Priority-based editor (The first one found becomes 'edit')
for cmd in fresh micro nano vim vi; do
    if command -v "$cmd" >/dev/null 2>&1; then
        alias edit="$cmd"
        break # Stop looking once we find our preferred editor
    fi
done

# --- Settings ---
lsopts="--color=auto --group-directories-first --time-style=long-iso"

# --- Modern ls Aliases ---
# Use the 'ls' alias inside the others to stay DRY
# In your common/.bash_aliases
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first --time-style=long-iso'
    alias l='ls -lbhHigUmuSa'
    alias ll='ls -lbh'
else
    alias ls="/bin/ls -F $lsopts"
fi
alias dir='ls'
alias l='ls -clAsh'
alias ll='ls -ahl'
alias lh='ls -hl'
alias la='ls -Ahl'

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

# --- Git ---
alias gitlog='git log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
