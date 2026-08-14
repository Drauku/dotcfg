# ~/.config/fish/aliases.fish  (managed by ~/.dotfiles/fish)
#
# Fish-native ls aliases. Fish is NOT POSIX-compatible, so it cannot source the
# shared ~/.bash_aliases (used by bash & zsh); it needs its own file.
#
# Sourced from config.fish AFTER `cachyos-config.fish` so these override the
# distro defaults (CachyOS defines its own `ls` alias). A conf.d/ file would
# load BEFORE config.fish and get clobbered, so it lives here instead.
#
# eza/exa use DIFFERENT single-letter flags than coreutils ls (e.g. eza -s ==
# --sort, NOT "size"; eza -h == header, sizes are human by default), so each
# alias is built with flags valid for the chosen binary.

set -l _ls_base "--group-directories-first --color=auto --time-style=long-iso"
set -e _ls   # drop any inherited global so detection below is authoritative

if type -q eza
    set -g _ls eza
else if type -q exa
    set -g _ls exa
end

if set -q _ls
    alias ls "$_ls $_ls_base"
    alias ll "$_ls -lh $_ls_base"    # long + header
    alias lh "$_ls -lh $_ls_base"    # long + header
    alias la "$_ls -lah $_ls_base"   # long + all (hidden) + header
    alias l  "$_ls -lah $_ls_base"   # long + all + header
    alias lt "$_ls -T $_ls_base"     # tree
    set -e _ls
else
    # `command ls` avoids fish re-entering this alias-function recursively.
    alias ls "command ls -F $_ls_base"
    alias ll "command ls -lh $_ls_base"
    alias lh "command ls -lh $_ls_base"
    alias la "command ls -lAh $_ls_base"
    alias l  "command ls -lAh $_ls_base"
    alias lt "command ls -R $_ls_base"
end
alias dir "ls"
