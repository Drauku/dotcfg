# .bash_profile

# Get the aliases and functions
src="$HOME/.bashrc"; [ -f "$src" ] && . "$src"

# User specific environment and startup programs
export EDITOR="micro"
export VISUAL="codium"

# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# Rust/Cargo environment (prepends ~/.cargo/bin to PATH)
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# PATH Deduplication Snippet
if [ -n "$PATH" ]; then
    export PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!x[$0]++' | sed 's/:$//')
fi

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
