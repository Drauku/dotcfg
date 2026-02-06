#!/bin/bash
# --- setup.sh ---

# --- Variable Definitions ---
repo_url="https://github.com/Drauku/dotcfg.git"
repo_dir="$HOME/dotcfg"
backup_dir="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

if [ -t 1 ] && command -v tput >/dev/null; then
    red=$(tput setaf 1); grn=$(tput setaf 2); ylw=$(tput setaf 3)
    blu=$(tput setaf 4); mgn=$(tput setaf 5); cyn=$(tput setaf 6)
    bld=$(tput bold); itx=$(tput sitm); uln=$(tput smul); rst=$(tput sgr0)
else
    red=""; grn=""; ylw=""; blu=""; mgn=""; bld=""; itx=""; uln=""; rst=""
fi

# Identify OS for recommendation
[ -f /etc/os-release ] && os_id=$(grep -w "ID" /etc/os-release | cut -d= -f2 | tr -d '"')

# Script Header
echo "${blu}${bld}>> Launching modular dotfile setup using Stow...${rst}"

# Dependency Check (Multi-Distro)
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

# Repo Management
if [ ! -d "$repo_dir" ]; then
    echo "${grn}Cloning repository to $repo_dir...${rst}"
    git clone "$repo_url" "$repo_dir"
else
    echo "${blu}Updating repository...${rst}"
    cd "$repo_dir" && git pull
fi
cd "$repo_dir" || exit 1

# Initialize Secrets (Local Only)
if [ ! -f "$HOME/.bash_secrets" ]; then
    echo "${ylw}Initializing .bash_secrets...${rst}"
    echo "# Private environment variables" > "$HOME/.bash_secrets"
fi

# Smart Backup & Stow Function
safe_stow() {
    local package=$1
    # Skip if folder doesn't exist
    [ ! -d "$package" ] && return
    # Backup existing files
    echo "${blu}Stowing ${cyn}$package${rst}..."
    (
        cd "$package" || exit
        find . -maxdepth 1 -type f -name ".*" | while read -r file; do
            target="$HOME/${file#./}"
            if [ -f "$target" ] && [ ! -L "$target" ]; then
                mkdir -p "$backup_dir"
                mv "$target" "$backup_dir/"
            fi
        done
    )
    # Stow indicated package
    stow -v -R "$package"
}

# Dynamic Feature Selection
# Build an array of available feature directories
features=("common")
for dir in */; do
    feat=$(basename "$dir")
    [[ "$feat" == "common" ]] && continue
    features+=("$feat")
done

echo "${mgn}${bld}Optional Features Detected:${rst}"
for feature in "${features[@]}"; do
    read -p "${ylw}Install config for [$feature]? (y/n): ${rst}" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check for specific CSM logic if feature is 'docker'
        if [[ "$feature" == "docker" && -d "$HOME/git/container-stack-manager" ]]; then
            echo "${red}CSM detected. Skipping legacy docker stow.${rst}"
        else
            safe_stow "$feature"
        fi
    fi
done

echo "${grn}${bld}Deployment Complete!${rst}"
[ -d "$backup_dir" ] && echo "Backups saved to: ${ylw}$backup_dir${rst}"
echo "To complete setup, run: ${ylw}source ~/.bashrc${rst}"
