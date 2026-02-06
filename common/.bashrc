#!/bin/bash
# --- common/.bashrc ---

# Non-interactive check
[[ $- != *i* ]] && return

# Define base configs
configs=("aliases" "colors" "secrets" "vars")

# Append dynamic feature/distro configs from ~/dotcfg
if [ -d "$HOME/dotcfg" ]; then
    for dir in "$HOME/dotcfg"/*/; do
        # Extract folder name
        dirname=$(basename "$dir")
        # Skip 'common' and only add if not already in array
        [[ "$dirname" == "common" ]] && continue
        configs+=("$dirname")
    done
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
        export PS1="\[$u_clr\]\u\[$ylw\]@\[$blu\]\h\[$wht\]: \[$cyn\]\w\[$blk\] \[$mgn\]\$ \[$rst\]"
    else
        # Fallback for non-color terminals
        PS1='${debian_chroot:+($debian_chroot)}\u@\h: \w\$ '
    fi
fi

# PATH Deduplication Snippet
if [ -n "$PATH" ]; then
    export PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!x[$0]++' | sed 's/:$//')
fi

# Variable and prompt cleanup
unset configs conf dir src u_clr
echo -ne "${rst}"
