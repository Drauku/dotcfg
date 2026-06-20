# .bash_profile

# Get the aliases and functions
src="$HOME/.bashrc"; [ -f "$src" ] && . "$src"

# User specific environment and startup programs
export EDITOR="micro"
export VISUAL="codium"

# PATH Deduplication Snippet
if [ -n "$PATH" ]; then
    export PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!x[$0]++' | sed 's/:$//')
fi
