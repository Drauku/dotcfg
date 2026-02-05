#!/bin/bash

# Define colors
red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
blu=$(tput setaf 4); bld=$(tput bold); rst=$(tput sgr0)

repo_url="https://github.com/Drauku/dotcfg.git"
repo_dir="$HOME/dotcfg"

echo "${blu}${bld}>> Launching Dotfile Bootstrap...${rst}"

# 1. Detect OS Flavor
if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_id=$ID
    os_like=$ID_LIKE
else
    os_id="unknown"
fi

# 2. Install Dependencies (git, stow)
echo "${ylw}Checking dependencies...${rst}"
if command -v dnf >/dev/null 2>&1; then
    pkg_mgr="sudo dnf install -y"
elif command -v apt-get >/dev/null 2>&1; then
    pkg_mgr="sudo apt-get update && sudo apt-get install -y"
fi

for pkg in git stow; do
    if ! command -v $pkg >/dev/null 2>&1; then
        echo "${ylw}Installing $pkg...${rst}"
        eval "$pkg_mgr $pkg"
    fi
done

# 3. Clone or Update Repo
if [ ! -d "$repo_dir" ]; then
    echo "${grn}Cloning repository to $repo_dir...${rst}"
    git clone "$repo_url" "$repo_dir"
else
    echo "${blu}Repository exists. Pulling latest changes...${rst}"
    cd "$repo_dir" && git pull
fi

cd "$repo_dir" || exit 1

# 4. Initialize Secrets (Security)
if [ ! -f "$HOME/.bash_secrets" ]; then
    touch "$HOME/.bash_secrets"
    echo "# Private environment variables" > "$HOME/.bash_secrets"
fi

# 5. Execute Stow Logic
echo "${grn}Applying configurations...${rst}"
stow -v -R common

# Check for Server flavors (Debian, Ubuntu, Proxmox)
if [[ "$os_id" =~ (debian|ubuntu|proxmox) ]] || [[ "$os_like" =~ (debian|ubuntu) ]]; then
    echo "${blu}Server/Debian-based flavor detected ($os_id). Stowing server configs...${rst}"
    stow -v -R server
fi

# Check for Nobara/Fedora
if [[ "$os_id" == "nobara" ]] || [[ "$os_id" == "fedora" ]]; then
    echo "${blu}Nobara/Fedora flavor detected. Stowing nobara configs...${rst}"
    stow -v -R nobara
fi

echo "${grn}${bld}Success!${rst} Dotfiles are linked."
echo "Run: ${ylw}source ~/.bashrc${rst}"
