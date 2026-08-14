#!/bin/bash
# --- common/.bashrc ---

# Non-interactive check
[[ $- != *i* ]] && return

# Define base configs
configs=("aliases" "colors" "secrets" "vars")

# Append dynamic feature/distro configs from ~/.dotfiles
if [ -d "$HOME/.dotfiles" ]; then
    for dir in "$HOME/.dotfiles"/*/; do
        # Extract folder name
        dirname=$(basename "$dir")
        # Skip 'common' and only add if not already in array
        [[ "$dirname" == "common" ]] && continue
        configs+=("$dirname")
    done
fi

# --- PATH setup (must precede the source loop below, so tools installed under
# ~/.local/bin or ~/.cargo/bin — e.g. a cargo-installed eza — are on PATH when
# .bash_aliases runs its `command -v` checks) ---
# Added by LM Studio CLI tool (lms)
export PATH="$PATH:$HOME/.lmstudio/bin:$HOME/.local/bin"
# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"
# Rust/Cargo environment (prepends ~/.cargo/bin to PATH)
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# PATH Deduplication Snippet
if [ -n "$PATH" ]; then
    export PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!x[$0]++' | sed 's/:$//')
fi

# Source all identified conf
for conf in "${configs[@]}"; do
    src="$HOME/.bash_$conf"; [ -f "$src" ] && . "$src"
done

# Only set PS1 if no custom prompt engine is active
if [[ -z "$STARSHIP_SHELL$POSH_THEME$P9K_TTY" ]]; then
    # Set colorized prompt if tput color is supported
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # UID check for color coding
        [ "$(id -u)" -eq 0 ] && u_clr=$red || u_clr=$grn
        export PS1="\[$u_clr\]\u\[$ylw\]@\[$cyn\]\h\[$wht\]: \[$blu\]\w\[$blk\] \[$mgn\]\$ \[$rst\]"
    else
        # Fallback for non-color terminals
        PS1='${debian_chroot:+($debian_chroot)}\u@\h: \w\$ '
    fi
fi

# SSH Agent - Interactive Shell Only
if [[ $- == *i* ]]; then
    # Ensure the socket is available
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval "$(ssh-agent -s)" &>/dev/null
    fi

    # Load keys if the agent is currently empty
    if ssh-add -l &>/dev/null | grep -q "The agent has no identities"; then
        # Function to find and add private keys
        find ~/.ssh -type f -not -name "*.pub" -not -name "config" -not -name "known_hosts" -exec ssh-add {} + &>/dev/null
    fi
fi

# Variable and prompt cleanup
unset configs conf dir src u_clr
echo -ne "${rst}"

[[ $(which fastfetch) ]] && fastfetch

function ts(){ tailscale "$@"; }
