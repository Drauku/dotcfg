# .bash_profile

# Get the aliases and functions
src="~/.bashrc"; [ -f "$src" ] && . "$src"

# User specific environment and startup programs
export EDITOR="micro"
export VISUAL="codium"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/drauku/.lmstudio/bin"
# End of LM Studio CLI section

# PATH Deduplication Snippet
if [ -n "$PATH" ]; then
    export PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '!x[$0]++' | sed 's/:$//')
fi
