#!/bin/bash

# --- 1. Color Configuration ---
if [ -t 1 ] && command -v tput >/dev/null; then
    red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
    blu=$(tput setaf 4); mgn=$(tput setaf 5); bld=$(tput bold); rst=$(tput sgr0)
else
    red=""; grn=""; ylw=""; blu=""; mgn=""; bld=""; rst=""
fi

# --- 2. Variable Definitions ---
repo_url="https://github.com/Drauku/dotcfg.git"
repo_dir="$HOME/dotcfg"
backup_dir="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

echo "${blu}${bld}>> Launching Distro-Specific Bootstrap...${rst}"

# --- 3. Dependency Installation ---
if command -v dnf >/dev/null 2>&1; then
    pkg_mgr="sudo dnf install -y"
elif command -v apt-get >/dev/null 2>&1; then
    pkg_mgr="sudo apt-get update && sudo apt-get install -y"
elif command -v pacman >/dev/null 2>&1; then
    pkg_mgr="sudo pacman -S --noconfirm"
fi

for pkg in git stow; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        echo "${ylw}Installing $pkg...${rst}"
        eval "$pkg_mgr $pkg"
    fi
done

# --- 4. Repository Management ---
if [ ! -d "$repo_dir" ]; then
    echo "${grn}Cloning repository to $repo_dir...${rst}"
    git clone "$repo_url" "$repo_dir"
else
    echo "${blu}Updating repository...${rst}"
    cd "$repo_dir" && git pull
fi

cd "$repo_dir" || exit 1

# --- 5. Secrets Initialization ---
if [ ! -f "$HOME/.bash_secrets" ]; then
    touch "$HOME/.bash_secrets"
    echo "# Private environment variables" > "$HOME/.bash_secrets"
fi

# --- 6. Improved Backup & Stow Function ---
safe_stow() {
    local package=$1
    [ ! -d "$package" ] && return # Skip if folder doesn't exist

    echo "${ylw}Stowing $package...${rst}"
    (
        cd "$package" || exit
        find . -maxdepth 1 -type f -name ".*" | while read -r file; do
            target="$HOME/${file#./}"
            if [ -f "$target" ] && [ ! -L "$target" ]; then
                echo "${mgn}Backing up $target to $backup_dir${rst}"
                mkdir -p "$backup_dir"
                mv "$target" "$backup_dir/"
            fi
        done
    )
    stow -v -R "$package"
}

# --- 7. Distro Logic ---
# Always stow common
safe_stow common

# Detect OS ID (e.g., nobara, debian, arch)
if [ -f /etc/os-release ]; then
    os_id=$(grep -w "ID" /etc/os-release | cut -d= -f2 | tr -d '"')

    # Check for specific folder in repo matching OS ID
    if [ -d "$os_id" ]; then
        echo "${grn}Detected $os_id environment.${rst}"
        safe_stow "$os_id"
    fi
fi

# BSD Detection (Special Case)
if [[ "$OSTYPE" == *"bsd"* ]]; then
    safe_stow bsd
fi

echo "${grn}${bld}Success!${rst} Run: ${ylw}source ~/.bashrc${rst}"