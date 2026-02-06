#!/bin/bash
# --- setup.sh ---

# --- Variable Definitions ---
repo_url="https://github.com/Drauku/dotcfg.git"
repo_dir="$HOME/dotcfg"
backup_dir="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
standard_pkgs=("common")
optional_pkgs=("docker" "server" "gaming")

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

    echo "${blu}Stowing ${cyn}$package${rst}..."
    (
        cd "$package" || exit
        # Iterate over all items (including hidden ones)
        for item in .??* *; do
            # Skip if the glob didn't match anything
            [ ! -e "$item" ] && continue

            target="$HOME/$item"
            # If target exists and is NOT a symlink, back it up
            if [ -e "$target" ] && [ ! -L "$target" ]; then
                echo "${mgn}Backing up $target to $backup_dir${rst}"
                mkdir -p "$backup_dir"
                mv "$target" "$backup_dir/"
            fi
        done
    )
    # Stow indicated package
    stow -v -R "$package"
}
# Initialize Core Plan
[ -f /etc/os-release ] && os_id=$(grep -w "ID" /etc/os-release | cut -d= -f2 | tr -d '"')

# Set selected packages:
selected_pkgs=("${standard_pkgs[@]}")

# Automatically add the OS-specific folder if it exists
if [ -d "$os_id" ]; then selected_pkgs+=("$os_id"); fi

# Package selection
echo "${mgn}${bld}Optional packages:${rst}"

# Optional packages
for pkg in "${optional_pkgs[@]}"; do
    [ ! -d "$pkg" ] && continue # Skip if folder isn't in repo
    read -p "${ylw}Stow ${cyn}$pkg${rst}${ylw}? (y/N): ${rst}" -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Only check CSM for the docker package
        if [[ "$pkg" == "docker" ]] && [ -d "$HOME/git/container-stack-manager" ]; then
            echo "${red}>> CSM detected. Skipping legacy docker stow.${rst}"
            continue
        fi
        selected_pkgs+=("$pkg")
    fi
done

# Final Confirmation
echo -e "\n${blu}${bld}--- Deployment Plan ---${rst}"
echo "${ylw}The following packages will be Stow(ed)${rst}:"
echo "  - ${grn}${selected_pkgs[*]}${rst}"
read -p "${mgn}Proceed with deployment? (y/N): ${rst}" -n 1 -r; echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "${red}Deployment aborted.${rst}"
    exit 0
fi

for pkg in "${selected_pkgs[@]}"; do
    safe_stow "$pkg"
done

echo "${grn}${bld}Deployment Complete!${rst}"
[ -d "$backup_dir" ] && echo "Backups saved to: ${ylw}$backup_dir${rst}"
echo "To finish: ${ylw}source ~/.bashrc${rst}"

# --- Final Cleanup (Self-Destruct) ---
if [[ "$(realpath "$0")" != "$repo_dir/setup.sh" ]] && [ -d "$repo_dir" ]; then
    echo # Move to a new line after the previous output
    read -p "${ylw}Clean up temporary setup script? (y/n): ${rst}" -n 1 -r
    echo # Move to a new line after the keypress
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -- "$0" && echo "${grn}Temporary script ${red}removed${rst}."
    else
        echo "${mgn}Skipping cleanup. Script preserved at: ${cyn}$(realpath "$0")${rst}"
    fi
fi
